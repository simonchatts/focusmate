# FocusMate notifications

[FocusMate](https://www.focusmate.com) is an online service that pairs you up
with someone on the Internet for a scheduled 50 minute session.

One shortcoming is that it does not provide notifications to your phone when a
pre-booked session is about to start. This repo provides that. It polls once a
minute, and sends 5-minute and 1-minute notifications for any upcoming session.

The notifications are sent using [Pushover](https://pushover.net), where you
need to [create a free app token and user token](https://pushover.net/api) for
use here.

## Deployment with NixOS

The easiest way to deploy is with NixOS: just add the `module.nix` from this
repo to your `imports`, and then specify:

```nix
  services.focusmate-notify = {
    enable = true;
    focusmate-email = "focusmate@email.address";
    focusmate-password = "focusmate-password";
    pushover-app-token = "u8qgdt9afs5jp2yy9ruw1g3juylp1n";
    pushover-user-token = "y82q8aofzkbfsbtp41sw65vuueiqy0";
  };
```
where you should obviously substitute real values for all these fields. (These
have been [randomized](https://github.com/simonchatts/hashmash).)

That's it.

## Deployment manually

If you aren't using NixOS, then set the `STATE_DIR` environment variable to a
read-write directory (for the `state.json` file). Then set the `SECRETS_FILE`
environment variable to the path of a file like below, and run
`focusmate-notify.nu` as often as desired.

```json
{
    "focusmate_auth": {
        "email":"focusmate@email.address",
        "password":"focusmate-password"
    },
    "pushover_tokens": {
        "app_token": "u8qgdt9afs5jp2yy9ruw1g3juylp1n",
        "user_token": "y82q8aofzkbfsbtp41sw65vuueiqy0"
    }
}
```
