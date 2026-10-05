# Viewpoint fix mods (Project Zomboid B42)

This repo holds **unofficial fix mods for Project Viewpoint**, the first/third-person 3D mod by ellu (workshop 3809306528, mod id `Viewpoint`). It is *not* PZ3D. The user plays with Viewpoint, finds bugs, and brings them here one at a time.

Read first: [docs/viewpoint.md](docs/viewpoint.md), which covers how Viewpoint works, its Lua/Java API surface and ecosystem. Then [docs/bugs.md](docs/bugs.md) for the bug log and status. Update both as you learn more.

**Shape (decided 2026-10-05):** one mod, `ViewpointFixes` ("Viewpoint Fixes (Unofficial)"), with **a toggle per fix** on its Mod Options page. Project folder, mod id and Workshop junction are all `ViewpointFixes`.

- Core: `Contents/mods/ViewpointFixes/common/media/lua/client/ViewpointFixes/ViewpointFixes.lua`. It provides `ViewpointFixes.register{id,label,tooltip}`, `isEnabled(id)`, `guard(id, fn, ...)` (pcall; an error switches the fix off for the session), `log`, `debug`, and `debugEnabled()` (the "Debug logging" tickbox).
- Each fix: `client/ViewpointFixes/fixes/VPF_NNN_Name.lua`. It requires the core, registers itself, checks `isEnabled` at call time (so toggles apply live), and runs risky work through `guard`. Option labels go in `shared/Translate/EN/UI.json` as `UI_ViewpointFixes_VPFNNN` / `_Tooltip`.
- Add a debug-only probe (throttled log of the values the fix depends on) to any fix built on unverified assumptions, so the user's first test run produces evidence.
- Run `tools/luacheck.ps1` after every Lua edit. It compiles with the game's own Kahlua compiler.
- **Understand the full vanilla path before changing code** (user feedback after VPF-002 v1–v4 each fixed one visible symptom and then hit the next). Read the whole vanilla flow end to end, and **trace it at runtime** rather than inferring: `client/ViewpointFixes/Debug/Trace.lua` provides `ViewpointFixes.Trace.wrap(tbl, label, {methods})` and `Trace.during(label, fn, ...)`, which logs nested calls with readable args/returns (`[ViewpointFixes] TRACE:`), only while Debug logging is ticked. Example hook (removed after use, see git history `27056dc`): `Debug/TraceMoveables.lua` armed it around every `ISMoveablesAction:complete` and wrapped the `ISMoveableSpriteProps` pickup/place/rotate functions. For Java-side calls, ZombieBuddy's experimental mode adds `ZombieBuddy.Watches.Add(class, method)` and `zbinspect` / `zbmethods` (see its doc/LuaAPI.md, doc/DevDebugFunctions.md).
- Before blaming Viewpoint or our fix, get a **baseline**: does the behaviour also fail in 2D/iso view, and with our fix's toggle off?
- Server-folder vanilla Lua (e.g. `BuildingObjects/*`) loads *after* client files. Don't `require` it from client files; reference it at runtime (OnGameStart or later).

## Hard rules (licence)

Viewpoint is proprietary: no copying, modifying, redistributing, or "decompiling for reuse".
- Never copy Viewpoint code, shaders or assets into this repo, not even "patched" copies of its Lua files. Fixes are separate code that wraps or hooks from outside.
- Don't decompile `Viewpoint.jar` (no javap/CFR/etc.). Listing class names and reading its shipped Lua to understand how to interoperate is fine. Ask the user before anything deeper.
- Reference Viewpoint only by name at runtime (Lua globals, `Class.forName`/reflection), so our mod loads and stays harmless if Viewpoint changes or is absent.
- Credit and disclaim in workshop text: unofficial, not affiliated, requires Viewpoint.

## How to build a fix

Pick the lowest layer that works:
1. **Lua wrap** of a Viewpoint global (`ViewpointInteract`, `ViewpointLoot`, …) or of a vanilla function it calls. No compile step, easy to retire. Default choice.
2. **Java patch of a game class** through ZombieBuddy `@Patch`, checking `viewpoint.core.View.enabled` by reflection. Follow the Controller Aim pattern described in docs/viewpoint.md.
3. **Java patch of a Viewpoint class**: last resort. It's fragile across updates and closer to the licence line, so discuss it with the user first.

Every fix must:
- **Diagnose first.** Get evidence (a console.txt trace, repro steps) and write the VPF entry in docs/bugs.md before writing code. Don't guess at Viewpoint internals; say what's verified vs inferred.
- **Be self-contained.** One file per fix, named `VPF_NNN_ShortName.lua` (or a Java class `VPF_NNN_*`), toggleable, with a header comment covering the bug, cause, Viewpoint version and retire condition.
- **Guard and degrade.** Check that the target exists before wrapping, wrap only once (a guard flag), call the original, and use pcall where a failure could cascade. After an unexpected error the fix turns itself off and logs once, rather than spamming or breaking Viewpoint.
- **Apply at the right time.** Viewpoint's Lua is in `42/media/lua/client` and installs some wraps at OnGameBoot/OnGameStart. Don't rely on file load order. Apply our wraps in an event after Viewpoint's, or lazily.
- **Log** through `ViewpointFixes.log/debug` (prefix `[ViewpointFixes] VPF_NNN:`), so `tools/logs.ps1` picks it up.
- **Game bytecode is fair game for diagnosis.** `javap -p`/`-c` on `projectzomboid.jar` classes (an extracted copy may be in `/tmp/pzj`) is how VPF-002 was found. This rule is about the game's own code only; it does not cover Viewpoint's.
- **Be minimal.** Fix the bug, not the design. No feature work unless the user asks.

When a fix is confirmed working, suggest reporting the bug upstream (Viewpoint Discord / Steam discussions) so it can be retired later.

## Environment

- Game: `C:\SteamLibrary\steamapps\common\ProjectZomboid` (B42.21, its own Java runtime is **25.0.1**). The vanilla Lua is in `media/lua`, scripts in `media/scripts/generated`. These are large, so grep specific paths and never the whole game folder.
- Workshop content: `C:\SteamLibrary\steamapps\workshop\content\108600\<id>`. Viewpoint is 3809306528, ZombieBuddy 3619862853, ZombieBuddyFix 3809837933, Controller Aim 3811577340.
- Java fixes need **JDK 25** (only JDK 17 is installed at `C:\Program Files\Eclipse Adoptium`). Compile with `--release 25` against `projectzomboid.jar` + `ZombieBuddy.jar` (in the workshop `libs/` folder, or the game folder). The jar path should be `42/media/java/client/` for a client-only fix, and mod.info needs `require=\ZombieBuddy,\Viewpoint`, `javaJarFile` and `javaPkgName`. ZombieBuddy asks the user to approve new Java mods.
- Logs: `%USERPROFILE%\Zomboid\console.txt` (overwritten each launch; older runs are in `Zomboid\Logs\logs_<date>`). **Read it yourself after the user says they tested. Never ask them to paste logs or run tools/logs.ps1.** Grep for `[ViewpointFixes]`, `[Viewpoint]`, `ERROR`, `(MOD:`. The project is junction-linked into `%USERPROFILE%\Zomboid\Workshop\ViewpointFixes` (`tools/link.ps1`).

## Project Zomboid B42 conventions

- Layout: `Contents/mods/<Mod>/42/mod.info` + `common/media/...`. No B41 flat `media/`.
- Translations are JSON (`Translate/EN/ItemName.json` etc.); item keys are `Module.ItemId`. Item icon `Icon = X` → `textures/Item_X.png`.
- Lua 5.1 (Kahlua): no `goto`, no `//`. Keep globals to one mod table.
- The user wants **structure only, no example or demo content**. Don't add sample items or test code they didn't ask for.
