# My First Mod

A Project Zomboid **Build 42** mod. It adds a Lucky Coin item, a recipe that turns a Button into a coin, and a "Flip Coin" option in the coin's right-click menu.

## Layout

```
MyFirstMod/                     ← Workshop item root (upload this folder)
├─ workshop.txt                 Steam Workshop title/description/tags
├─ preview.png                  Workshop thumbnail (256×256)
├─ tools/
│  ├─ link.ps1                  Links the project into Zomboid\Workshop
│  └─ logs.ps1                  Follows console.txt, filtered to this mod
└─ Contents/mods/MyFirstMod/
   ├─ 42/mod.info               Mod metadata (id, name, versionMin). B42 requires this folder
   └─ common/                   Files shared by every game version
      ├─ poster.png, icon.png
      └─ media/
         ├─ lua/client/         UI, context menus, input (runs per player)
         ├─ lua/server/         World/game-state logic
         ├─ lua/shared/         Loaded by both, plus Translate/EN/*.json
         ├─ scripts/            Item and craftRecipe definitions (*.txt)
         └─ textures/           Item_<Icon>.png icons
```

Keep your Lua inside a `MyFirstMod/` subfolder of each lua dir so the file names can't collide with other mods.

## Dev loop

1. Link once: `.\tools\link.ps1` creates `%USERPROFILE%\Zomboid\Workshop\MyFirstMod` pointing here.
2. Launch PZ with `-debug` (Steam → Properties → Launch Options) to get the debug menu, the Lua console, and error popups.
3. Main menu → **Mods** → enable *My First Mod* → start a sandbox game.
4. Follow the log in a terminal: `.\tools\logs.ps1`
5. After editing Lua, you can reload a single file from the debug Lua console. Script `.txt`, translation, and texture changes need a return to the main menu.

Quick test: in debug mode, open the Items List cheat, spawn `MyFirstMod.LuckyCoin`, right-click it, and choose **Flip Coin**.

## Renaming the mod

Replace `MyFirstMod` in the folder names, `mod.info` `id=`, the Lua folder names and `require` paths, the `module` in scripts, and the translation keys.

## Publishing

Main menu → **Workshop** → *Create and update items* → select *MyFirstMod*. Replace the placeholder `preview.png`/`poster.png` first. `workshop.txt` starts as `visibility=unlisted`; change it to `public` when you're ready.
