# TMUX 3.2a - The New Normal - AKA All My Crap's Broken...

2021-10-20: I've been running tmux with custom startup scripts for
years, but the recent upgrade to 3.2a has broken everything and an
hour of researching couldn't sort it out. I have a painful workaround
(hopefully temporary) where I manually execute all of the stuff done
in my scripts. Ouch.

TODO: Investigate tmuxinator. Our intern Mark H was using it, and I
dismissed it at the time because I had these elaborate, decade-old
scripts that were "ain't broke" at the time. That has changed.

## The Workaround

1. Open ~/bin/tshare-start in an editor, we'll need it for reference.
2. Open a new terminal, and run `tmux`.
3. `C-j $` to rename current session. Set the name to "work".
4. Look for the "work" section in tshare-start and find all the crap I
open up in there.
5. Window by window, `C-j c` to create, `C-j ,` to rename, then cd
into that project's directory and run `bin/start` or whatever.
6. Repeat steps 2-5 with a blue terminal, and name the session "services".
7. Repeat steps 2-5 with a green terminal, and name the session "queues".

## Start Multiple Sessions With Startup Magic Like I've Had Working Since 2012

- Yeah, no. Not anymore. No idea why. More research is required. And the real
  bear is that it all worked under 3.1.

## Multiple sessions

- Start tmux with "tmux", possibly with -L /tmp/work or -L /tmp/services, not
  sure if that's strictly necessary anymore.
- C-j $ -- rename current session

## Start TMux attached to a specific session

- ???
- I figured this out just a few days ago, but forgot it
- man tmux probably has the answer

## Change Sessions

C-j ( and C-J ): switch the current tmux between attached sessions
