# Contributing

Issues and pull requests are welcome.

**Reporting a bug.** Say what you did, what you saw, and attach `console.txt` from `%USERPROFILE%\Zomboid` (launch with `-debug` for extra lines). Include your Viewpoint version and game build.

**Proposing a fix.** Fixes here are workarounds for Project Viewpoint behaviour, so each one has a short spec in `docs/fixes/` (copy `_template.md`): symptom, cause (say what was verified and what is inferred), what the fix does, and when it can be retired.

**Ground rules**
- Don't copy Project Viewpoint's code, shaders or assets into this repo. Reading its files to understand a bug is fine; fixes hook in from outside, by name or reflection, so they keep working if Viewpoint changes or is absent.
- Lua touches Viewpoint and the Java part only through `ViewpointFixes/Adapter.lua`.
- Java: the patch advice is inlined into the patched class, so anything it calls must be a public class with public members. Reach game and Viewpoint classes by reflection; the build only sees `ZombieBuddy.jar`.
- Keep the Mod Options page player-facing. No developer toggles.
- A fix should be self-contained (one `VPF_NNN` file, plus a Java patch if needed) and stand down by itself when Viewpoint handles the case.

**Building and checking**
- Java: `cd java`, then `.\gradlew deploy` (close the game first).
- Lua: `.\tools\luacheck.ps1` compiles every Lua file with the game's own compiler.
- Try it in game, and read `console.txt` for `[ViewpointFixes]` lines and errors.

By contributing you agree your work is released under this repository's licence (see `LICENSE`, including the adoption grant for the Viewpoint authors).
