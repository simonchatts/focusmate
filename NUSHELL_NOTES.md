# Introduction

This repo represents my first Nushell program. I kept some notes as I went
through, on what parts of the on-ramp were a bit bumpy.

Overall, the experience was positive! The result is deployed (running every
minute on a server via systemd) and seems to work flawlessly and pretty
efficiently. The documentation, VS Code extension, and interactive shell meant I
could fairly quickly get bits of logic working and build up.

But there were also some sharp edges. I'm aware it may be pushing the boundaries
a little, to use Nushell more as "programming language" than "interactive
environment", but it's so close! So I've tried to relate my experience below
(all for 0.35.0, on both macOS and linux).

## How to do things

### Errors

How to catch errors? I saw `do -i` can ignore them, but how, for example, would
I try to read in my `state.json` file, and if not present or invalid JSON,
create a default one?

In the absence of catching errors, I fell back to checking for existence of the
file, but the best I got was:
```nush
test -e state.json && echo true || echo false | from json
```
and I only thought of this after learning (see below) that `sh` is used to spawn
external programs. Is there a better way?

### Empty lists

I found handling "lists that might be empty" harder than I expected, because of
behavior like this:
```nush
> def length [] { reduce -f 0 { $acc + 1 } }
> seq 1 5 | length
5
> ls | where $false | length
0
> let e = (ls | where $false)
> $e | empty?
true
> $e | length
1
```

I still don't have a mental model for why the final line is correct, and it
required explicit `empty?` checks in more places than I expected. There is also
a potentially deeper question of other processing of zero-length lists. For
example:

```nush
> let e = (ls | first 3)
> $e.name
───┬────
 0 │ foo
 1 │ bar
 2 │ baz
───┴────

> let e = (ls | first 0)
> $e.name
error: Type Error
  ┌─ shell:1:1
  │
1 │ echo 42
  │ ^ Expected row or table, found nothing

```

(The choice of error message is separated out below - the fact it's an error at
all is the focus here.) But even spelling it out as an iteration still seems
problematic:
```nush
> for f in (ls | first 3) { $f.name }
───┬────
 0 │ foo
 1 │ bar
 2 │ baz
───┴────

> for f in (ls | first 0) { $f.name }
error: Type Error
  ┌─ shell:1:1
  │
1 │ echo 42
  │ ^ Expected row or table, found nothing

```

### Singleton lists

Related to the above, how do I semantically create a JSON file with a list of
one element?
```nush
> [ 1 2 3 ] | to json
[1,2,3]
> [ 1 2 ] | to json
[1,2]
> [ 1 ] | to json
1
```

### Modular scripts

Suppose I have a `script.nu` that uses `lib.nu`. Both scripts reside in the
`/my/app` directory.

If `script.nu` just does `source lib.nu`, then that works if I first `cd
/my/app` and then run `script.nu` from there.

But suppose I want to be able to run `/my/app/script.nu` from anywhere (eg by
adding `/my/app` to my `PATH`), without hard-coding `/my/app` into the script?

Just adding `/my/app` to `PATH` doesn't seem enough (reasonably enough), but
neither does
```nush
let lib = ($'($nu.env.BIN_DIR)/lib.nu' | into path)
source $lib
```
since it says `Expected a filepath constant, found $lib`. Is there a way to do
this?

### Equality for lists/tables

Is there a way to test two lists or tables for equality?

## Error messages

A lot of effort has clearly been poured into Nushell's error messages! Some
examples where the results were still perplexing:

### Dereferencing empty list variables

```nush
> cat ex1.nu
#!/usr/bin/env nu

let files = (ls | first 0)
for file in $files {
  echo $file.name
}

> ./ex1.nu
error: Type Error
  ┌─ shell:1:1
  │
1 │ #!/usr/bin/env nu
  │ ^ Expected row or table, found nothing

```
I couldn't say any way to associate the error with the problematic line of the
script. I tried looking for some equivalent of bash's `set -x`, but could not
find anything in the debug/logging.

### Missing `sh`

If you try to spawn an external program without `sh` in the `PATH`, the error
message looks like this (for `curl` in this example):
```nush
error: No such file or directory (os error 2)
   ┌─ shell:99:7
   │
99 │       curl -sH $'Authorization: ($login_token)' $session_url
   │       ^^^^ failed to spawn

```
This was perplexing to debug, as it looked like `curl` is the program that's
missing. (This came up when operationalizing the script as a NixOS service,
since NixOS is pretty hygenic about dependencies.)

Once I knew that `sh` was involved, this was actually enlightening (eg how to do
file descriptor assignment such as `command 2>&1`) - should this be documented
somewhere?

### Running as a system user

Another normal aspect of running as a service is assigning a unique user/group
to own the service, that has minimal permissions. This fails (using the standard
NixOS defaults) because `HOME` for the user is set to `/var/empty`, and Nushell
tries to create `/var/empty/.config/nu`, and aborts when it cannot. So I've had
to run my service as a real user for now.

### to sqlite

For some reason, `to sqlite` seems to cite, as the problematic command listed as
line 1, some earlier command in the history:

```
% rm ~/Library/Application\ Support/org.nushell.nu/history.txt
% nu
Welcome to Nushell 0.35.0 (type 'help' for more info)
> echo 42
42
> echo [[id count]; [1 42] [2 52] [3 62]] | to sqlite
error: Expected a table with SQLite-compatible structure from pipeline
  ┌─ shell:1:1
  │
1 │ echo 42
  │ ^ requires SQLite-compatible input


```

(FWIW `to sqlite` also seems to squash multiple potential error sources into one
message, but the "getting the input line wrong" seems more potentially interesting.)


## Documentation

I couldn't find documentation for `if` expressions in the book anywhere.

In general, the book (and search field across all the documentation sources) is
really good, but often contains important information only once, and I found it
easy to miss, even after reading it through twice (separated by quite a few
weeks). Some intentional repetition would help reinforce the learning. For
example, things that would have accelerated my path:

 - When explaining [&& and ||](https://www.nushell.sh/book/operators.html) say
   that there isn't a boolean `not`, but you can write your own if you want
   using `if condition { $false } { $true }`.

 - When [explaining
   blocks](https://www.nushell.sh/book/types_of_data.html#blocks), say you can
   evaluate them using `do`.

 - Not sure where or how this is best explained, but it took me a while to
   figure out that variable scoping is neither purely lexical or purely dynamic,
   but sort of "lexical for writes, dynamic for reads":
```nush
> def read_x [] { echo $x }
> def write_x [] { let x = 42; read_x }
> write_x
42
```

`help commands` doesn't list `query json` at all.

I wasn't totally clear whether the more recent "[natural pipeline
output](https://www.nushell.sh/blog/2021-06-22-nushell_0_33.html#more-natural-pipeline-output-jt)"
was still consistent with the
"[groups](https://www.nushell.sh/book/types_of_data.html#groups)" documentation?

The `chart` commands sound intriguing, but some "hello world"-style examples or
documentation would be very helpful.

## Known issues

A couple of issues that tripped me up, but then found were known limitations:

 - history file corruption (hopefully
   [#3916](https://github.com/nushell/nushell/pull/3916) will help)

 - inability to process command-line arguments in Nushell scripts (eg issue
   [#3762](https://github.com/nushell/nushell/issues/3762))

 - can't specify custom command argument types that are booleans, dates, lists,
   or durations (or indeed the return type)

 - some built-ins like `flatten` and `empty?` take input via a piped stream,
   but I tried providing them as arguments first. It's not much hardship to
   write `my_list | flatten` rather than `flatten my_list`, but I haven't yet
   internalized the reason why it's better to always require the pipe. (I can
   imagine consistency is a good explanation.)

 ## Desirable features

 One thing I expected: in regular shells, `ESC .` pastes in the final argument
 of the previous line, and eg `ESC 3 ESC .` pastes in argument 3 of the previous
 line. I miss this a lot - not sure if reedline will do this.

 (Finally, well into the realm of just desirable featurettes, it would be great
 if `post`/`fetch` could accept custom headers, and `post` send form URL-encoded
 parameters, but this is well into "submit a PR if you care" territory :)

# Final thoughts

As I say, my experience was very positive overall, and I'm happy with the
result! In an ideal world I would submit PRs for at least some of the easy
things here, but realistically I won't have sufficient time for that for a
while, so hopefully this is better than nothing.
