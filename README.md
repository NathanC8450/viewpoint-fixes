# Viewpoint Fixes (Unofficial)

Unofficial fixes for [Project Viewpoint](https://steamcommunity.com/sharedfiles/filedetails/?id=3809306528) (Project Zomboid **Build 42.21**). One mod, with each fix toggleable under **Options → Mods → Viewpoint Fixes**. Not affiliated with the Viewpoint authors, and contains no Viewpoint code.

- [docs/viewpoint.md](docs/viewpoint.md): how Viewpoint works and what we can hook
- [docs/bugs.md](docs/bugs.md): bug log (VPF-NNN) and fix status

## Fixes

| ID | Fix | File |
|---|---|---|
| VPF-002 | Furniture pick up / place / rotate cursor works in first and third person | `fixes/VPF_002_MoveableCursor.lua` |
| VPF-003 | Inventory "Place item" (free 3D placement, R / Shift+R rotation) works in first and third person, with the item shown where you aim | `fixes/VPF_003_PlaceItemCursor.lua` + Java (aim, preview) |
| VPF-004 | Dropped / placed items show their rotation in first and third person | `fixes/VPF_004_ItemRotation.lua` + Java `Patch_ItemRotation` |

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
      │  ├─ ViewpointFixes.lua  registration, per-fix toggles, logging, error guard
      │  └─ fixes/VPF_NNN_*.lua one file per fix
      └─ shared/Translate/EN/   UI.json (option labels)
```

## Dev loop

1. Link once: `.\tools\link.ps1`.
2. Before launching: `.\tools\luacheck.ps1` (needs `javac` on PATH; uses the game's bundled Java to run). After Java changes: `.\tools\build-java.ps1`, then restart the game (Java doesn't reload at the main menu). ZombieBuddy asks once to approve a changed jar.
3. Launch PZ with `-debug`, then enable **Viewpoint Fixes (Unofficial)** under Mods, alongside Viewpoint.
4. Tick **Debug logging** on the mod's options page for per-fix probe lines. Everything lands in `%USERPROFILE%\Zomboid\console.txt`; `.\tools\logs.ps1` is optional, for watching it live.
5. Lua changes need the game back at the main menu (or a restart) to reload.

## Publishing

Main menu → **Workshop** → *Create and update items* → *ViewpointFixes*. Replace the placeholder `preview.png`/`poster.png` first. `workshop.txt` starts as `visibility=unlisted`.
