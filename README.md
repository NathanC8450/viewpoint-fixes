# Viewpoint Fixes (Unofficial)

Unofficial fixes for [Project Viewpoint](https://steamcommunity.com/sharedfiles/filedetails/?id=3809306528) (Project Zomboid **Build 42.21**). One mod; the fixes are always on. **Options → Mods → Viewpoint Fixes** has one option, the placement helper text (off by default). Not affiliated with the Viewpoint authors, and contains no Viewpoint code.

- [docs/viewpoint.md](docs/viewpoint.md): how Viewpoint works and what we can hook
- [docs/bugs.md](docs/bugs.md): bug log (VPF-NNN) and fix status
- [docs/backlog.md](docs/backlog.md): known issues and to-do list
- [docs/fixes/](docs/fixes/): one plain-language spec per fix (symptom, cause, what the fix does, how Viewpoint could adopt it)

## Fixes

| ID | Fix | File |
|---|---|---|
| VPF-002 | Furniture pick up / place / rotate cursor works in first and third person | `fixes/VPF_002_MoveableCursor.lua` |
| VPF-003 | Inventory "Place item" (free 3D placement, R / Shift+R rotation) works in first and third person, with the item shown where you aim | `fixes/VPF_003_PlaceItemCursor.lua` + Java (aim, preview) |

## Layout

```
├─ workshop.txt, preview.png    Steam Workshop item
├─ docs/                        Viewpoint notes, bug log, backlog, per-fix specs
├─ java/                        Java part: Gradle project, sources in src/main/java/viewpointfixes
│                               (ZombieBuddy patches + Lua bridge `ViewpointFixesJava`)
├─ tools/
│  ├─ link.ps1                  Links the project into Zomboid\Workshop\ViewpointFixes
│  ├─ logs.ps1                  Follows console.txt (fixes, Viewpoint, ZombieBuddy, errors)
│  └─ luacheck.ps1              Syntax-checks all Lua with the game's own compiler
└─ Contents/mods/ViewpointFixes/
   ├─ 42/mod.info               id=ViewpointFixes, require=\ZombieBuddy,\Viewpoint, javaJarFile
   ├─ 42/media/java/client/     ViewpointFixes.jar (built by `./gradlew deploy`, not committed)
   └─ common/media/lua/
      ├─ client/ViewpointFixes/
      │  ├─ ViewpointFixes.lua  registration, options page, logging, error guard
      │  ├─ Adapter.lua         the only place fixes touch Viewpoint and the Java part
      │  └─ fixes/VPF_NNN_*.lua one file per fix
      └─ shared/Translate/EN/   UI.json (option labels)
```

## Dev loop

1. Link once: `.\tools\link.ps1`.
2. Build the Java part (needs JDK 17 and `ZombieBuddy.jar`; the Gradle wrapper fetches Gradle itself): `cd java`, then `.\gradlew deploy`. This puts `ViewpointFixes.jar` in the mod folder, so close the game first (it holds the jar open). If `ZombieBuddy.jar` isn't at the default Steam path, pass `-PzombieBuddyJar=<path>`. Restart the game after Java changes (Java doesn't reload at the main menu); ZombieBuddy asks once to approve a changed jar.
3. After Lua edits: `.\tools\luacheck.ps1` (needs `javac` on PATH; uses the game's bundled Java to run).
4. Launch PZ with `-debug`, then enable **Viewpoint Fixes (Unofficial)** under Mods, alongside Viewpoint.
5. Debug logging follows the `-debug` launch flag (per-fix probe lines). Everything lands in `%USERPROFILE%\Zomboid\console.txt`; `.\tools\logs.ps1` is optional, for watching it live.
6. Lua changes need the game back at the main menu (or a restart) to reload.

## Releases and contributing

The jar is not in git. Each release is a GitHub Release carrying `ViewpointFixes-<version>.zip` (the Workshop item with the built jar inside); see [CHANGELOG.md](CHANGELOG.md). Contributions: see [CONTRIBUTING.md](CONTRIBUTING.md).

## Publishing

A Workshop item is a folder holding `workshop.txt`, `preview.png` and `Contents/mods/<id>/...` (what this repo's root already is). With the jar built (`cd java; .\gradlew deploy`), either:
- upload from the game: main menu → **Workshop** → *Create and update items* → *ViewpointFixes* (the folder linked by `tools\link.ps1`). `workshop.txt` starts as `visibility=unlisted`; replace the placeholder `preview.png`/`poster.png` first; or
- run `.\tools\package.ps1` to make `dist\ViewpointFixes-<version>.zip` with that same layout (jar included), which is what a GitHub Release carries. Unzipping it into `%USERPROFILE%\Zomboid\Workshop\` gives a local Workshop item the game loads.

## Licence

MIT, plus an explicit grant letting the Project Viewpoint authors adopt any part of this repository into Viewpoint with no conditions (see [LICENSE](LICENSE)). Project Viewpoint is a separate, proprietary mod by its own authors; none of its code or assets are in this repository.
