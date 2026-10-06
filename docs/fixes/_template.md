# VPF-NNN: short title

Copy this file to `docs/fixes/VPF-NNN.md`. Keep it in plain language: it is the brief a Viewpoint maintainer would read to adopt the fix, so it should make sense without our code. The longer investigation history stays in `docs/bugs.md`.

- **Status:** observed | fixed (ours) | adopted upstream in vX | retired
- **Seen on:** Viewpoint version, game version
- **Code:** the files that implement it (Lua fix, Java patch, adapter calls it uses)

## Symptom
What the player sees, and how to trigger it.

## Cause
Why it happens, in terms of the game's flow and what Viewpoint changes. Mark what was verified (traced or read) and what is inferred.

## What the fix does
The behaviour, step by step, at the level of "what the game is told and when".

## If Viewpoint handled this itself
What the upstream change would be instead of our workaround, and which of our Adapter calls would disappear.

## Check list
Manual steps a maintainer can run to confirm it works (mode, view, input, expected result).

## Retire when
The condition that makes the fix unnecessary, and how it detects it (if it can).

## Known issues
Things that still don't work, with a link to `docs/backlog.md`.
