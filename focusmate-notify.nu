#!/usr/bin/env nu
#
# Send a phone notification if we have an imminent FocusMate session
#
# Simon, August 2021
#
# Expect these environment variables:
#  - SECRETS_FILE: path to read-only secrets.json file
#  - STATE_DIR: path to directory containing read-write state.json file
#
# The state.json file simply lists all previously sent notifications (with
# either a 5-minute or 1-minute warning). This has O(n) lookup, but we limit
# it to a small number of entries. (In reality, a maximum of 1 would often
# suffice - it's really there just to make sure we get only a single 5-minute
# warning, not 5 of them - but with rescheduling from either party, you can get
# multiple within that 5 minute window.)

# Go and camp out somewhere we have read-write access to a state file
cd $nu.env.STATE_DIR
let STATE_FILE = 'state.json'
create_state_if_missing

# Get initial state
let secrets = (open $nu.env.SECRETS_FILE)
let state = (open $STATE_FILE)
let now = (date now)

# Fetch the sessions
let sessions = (get_sessions)

# Early exit if sessions are empty, because of the nushell empty vec problem
# (filtering empty session list causes a type eror later on). The `any?` means
# the expression works whether we have zero, one, or more sessions - a second
# helping of the same issue.
if (any? ($sessions | empty?)) {
  exit --now
} { }

# Process 5- and 1-minute limits
let sent_5min_nfn = (process_and_update 5min "in a few minutes" $state.sent_5min_nfn)
let sent_1min_nfn = (process_and_update 1min "RIGHT AWAY!" $state.sent_1min_nfn)

# Update our state and write it out safely-ish
let TEMP_FILE = $STATE_FILE + '~'
(   $state
  | update sent_1min_nfn $sent_1min_nfn
  | update sent_5min_nfn $sent_5min_nfn
  | to json -p 4
  | save $TEMP_FILE
)
mv $TEMP_FILE $STATE_FILE

#-----------------------------------------------------------------------------

# Process notifications for one time limit, and return the updated list of
# uids for which a notification has been sent.
def process_and_update [ limit message prev_sent ] {
  # Filter out the imminent sessions that have not been already notified as such
  let sessions_within_limit = (
      $sessions
    | where (within $limit $it.session_time)
    | where { $it.uid not-in $prev_sent }
  )

  # Have to handle an empty list here explicitly, since an empty `where` appears
  # to be treated like an empty string (vec of length 1) not a vec of length 0.
  if ($sessions_within_limit | empty?) {
    $prev_sent
  } {
    # Send any needed notifications
    for sess in $sessions_within_limit {
      notify $sess.user $message
    }

    # Update state of sent notifications, by concatenating the old with the new.
    # Limit to a maximum of 5 entries (unrelated to the 5-minute warning).
    [ $prev_sent $sessions_within_limit.uid ] | flatten | last 5
  }
}

#-----------------------------------------------------------------------------

# Create the `state.json` file if it's missing
def create_state_if_missing [] {
  let absent = (sh -c 'test -e $STATE_FILE && echo false || echo true' | from json)
  if $absent {
    # Need to provide two seed values for each list, to avoid Nushell
    # "simplifying" them into a scalar.
    let seed_data = [
      [  sent_1min_nfn   sent_5min_nfn   ];
      [ [ seed1 seed2 ] [ seed1 seed2  ] ]
    ]
    $seed_data | save $STATE_FILE
  } { } # No 'else' case
}

#-----------------------------------------------------------------------------

# Is a datetime in the future, but within a specified limit from now?
def within [ limit time ] {
  let delta = $time - $now
  ($delta > 0sec && $delta < $limit)
}

#-----------------------------------------------------------------------------

# Send a notification using the pushover API
def notify [ peer how_soon ] {
  echo (
    curl -s
      --form-string $'token=($secrets.pushover_tokens.app_token)'
      --form-string $'user=($secrets.pushover_tokens.user_token)'
      --form-string $'message=Your session with ($peer) is about to begin ($how_soon)'
      --form-string 'url=https://www.focusmate.com/sessions'
      --form-string 'url_title=Join now'
      https://api.pushover.net/1/messages.json
  )
}

#-----------------------------------------------------------------------------

# Get all FocusMate sessions
def get_sessions [] {
  let session_url = 'https://focusmate-api.herokuapp.com/v1/session/'
  let login_token = (get_login_token)
  echo (
      curl -sH $'Authorization: ($login_token)' $session_url
    | from json
    | get sessions                    # focus on just session data
    | reject group title state status # drop the uninteresting columns
    | update session_time {           # translate from "ms since epoch"
        ($'($it.session_time / 1000)' | str to-datetime -z 'UTC')
      }
  )
}

#-----------------------------------------------------------------------------

# Log in and get an authorisation token. The token is good for an hour, but
# the API is so fast, and we're nowhere close to rate limits, that we can just
# keep things simple, and fetch every time.
def get_login_token [] {
  # The "key" in login_url is the public API key for FocusMate itself.
  let key = 'AIzaSyBd7gm2iFZ8ksJRZ' + 'fjKGf0j_UcLVFSQbWc' # avoid notifications
  let op = 'relyingparty/verifyPassword?key=' + $key
  let login_url = 'https://www.googleapis.com/identitytoolkit/v3/' + $op
  let login_auth = ($secrets.focusmate_auth | insert returnSecureToken $true)
  (post $login_url $login_auth).idToken
}
