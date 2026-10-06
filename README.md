# Viewpoint Fixes (Unofficial)

Unofficial fixes for [Project Viewpoint](https://steamcommunity.com/sharedfiles/filedetails/?id=3809306528) (Project Zomboid **Build 42.21**). One mod; the fixes are always on. **Options → Mods → Viewpoint Fixes** has one option, the placement helper text (off by default). Not affiliated with the Viewpoint authors, and contains no Viewpoint code.

- [docs/viewpoint.md](docs/viewpoint.md): how Viewpoint works and what we can hook
- [docs/bugs.md](docs/bugs.md): bug log (VPF-NNN) and fix status
- [docs/backlog.md](docs/backlog.md): known issues and to-do list

## Fixes

| ID | Fix | File |
|---|---|---|
| VPF-002 | Furniture pick up / place / rotate cursor works in first and third person | `fixes/VPF_002_MoveableCursor.lua` |
| VPF-003 | Inventory "Place item" (free 3D placement, R / Shift+R rotation) works in first and third person, with the item shown where you aim | `fixes/VPF_003_PlaceItemCursor.lua` + Java (aim, preview) |

## Layout

```
├─ workshop.txt, preview.png    Steam Workshop item
├─ docs/                        Viewpoint notes and bug log
├─ java/src/viewpointfixes/     Java part (ZombieBuddy patches + Lua bridge `ViewpointFixesJava`)
├─ tools/
│  ├─ link.ps1                  Links the project into Zomboid\Workshop\ViewpointFixes
│  ├─ build-java.ps1            Builds java/src into 42/media/java/client/ViewpointFixes.jar
│  ├─ logs.ps1                  Follows console.txt (fixes, Viewpoint, ZombieBuddy, errors)
│  └─ luacheck.ps1              Syntax-checks all Lua with the game's own compiler
└─ Contents/mods/ViewpointFixes/
   ├─ 42/mod.info               id=ViewpointFixes, require=\ZombieBuddy,\Viewpoint, javaJarFile
   ├─ 42/media/java/client/     ViewpointFixes.jar (built, committed)
   └─ common/media/lua/
      ├─ client/ViewpointFixes/
      │  ├─ ViewpointFixes.lua  registration, options page, logging, error guard
      │  └─ fixes/VPF_NNN_*.lua one file per fix
      └─ shared/Translate/EN/   UI.json (option labels)
```

## Dev loop

1. Link once: `.\tools\link.ps1`.
2. Before launching: `.\tools\luacheck.ps1` (needs `javac` on PATH; uses the game's bundled Java to run). After Java changes: `.\tools\build-java.ps1`, then restart the game (Java doesn't reload at the main menu). ZombieBuddy asks once to approve a changed jar.
3. Launch PZ with `-debug`, then enable **Viewpoint Fixes (Unofficial)** under Mods, alongside Viewpoint.
4. Debug logging follows the `-debug` launch flag (per-fix probe lines). Everything lands in `%USERPROFILE%\Zomboid\console.txt`; `.\tools\logs.ps1` is optional, for watching it live.
5. Lua changes need the game back at the main menu (or a restart) to reload.

## Publishing

Main menu → **Workshop** → *Create and update items* → *ViewpointFixes*. Replace the placeholder `preview.png`/`poster.png` first. `workshop.txt` starts as `visibility=unlisted`.

## Licence

MIT, plus an explicit grant letting the Project Viewpoint authors adopt any part of this repository into Viewpoint with no conditions (see [LICENSE](LICENSE)). Project Viewpoint is a separate, proprietary mod by its own authors; none of its code or assets are in this repository.
