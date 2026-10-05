# Project Zomboid mod: MyFirstMod

- Target: Build 42 (installed 42.21). Game install: `C:\SteamLibrary\steamapps\common\ProjectZomboid`. Use `media/lua` and `media/scripts/generated` there as the reference for vanilla APIs and script syntax. They are large, so grep specific paths and don't search the whole game folder.
- B42 layout: `Contents/mods/MyFirstMod/42/mod.info` + `common/media/...`. Don't use the B41 flat `media/` layout.
- Translations are JSON (`Translate/EN/ItemName.json` etc.), not the old `*_EN.txt` format. Item keys are `Module.ItemId`.
- Item icons: `Icon = X` → `common/media/textures/Item_X.png`.
- Lua is 5.1 (Kahlua). No `goto`, no integer division `//`, no `string.format('%q')` quirks. Avoid globals except the `MyFirstMod` table.
- Logs: `%USERPROFILE%\Zomboid\console.txt`. The project is linked into `%USERPROFILE%\Zomboid\Workshop\MyFirstMod` via a junction (`tools/link.ps1`).
