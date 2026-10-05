# Project Viewpoint: reference notes

What we know about the mod we're fixing. Researched 2026-10-05 against Viewpoint **0.1.5a-hotfix**. Viewpoint updates often, so re-check anything version-sensitive (see "Re-checking after a Viewpoint update").

## Identity

| | |
|---|---|
| Name | Project Viewpoint ("Viewpoint"). Not PZ3D, which is a different mod |
| Author | ellu (Steam). Community: Discord `discord.gg/g83XvPhEgQ` |
| Workshop | https://steamcommunity.com/sharedfiles/filedetails/?id=3809306528 |
| Mod id | `Viewpoint` |
| Game | Build 42.21 only (`versionMin=42.21`, `versionMax=42.21`) |
| Requires | `ZombieBuddy` ≥ 2.3.0 (Java mod loader). On 42.21 it also needs `ZombieBuddyFix` (workshop 3809837933) |
| Released | 2026-09-27. Seven updates in the first four days, so expect fast churn |
| Licence | **Proprietary.** No copying, modifying, redistributing, re-uploading, or "decompiled for reuse". The Workshop page says external Java add-ons are "use at your own risk" |

## Files on disk

```
C:\SteamLibrary\steamapps\workshop\content\108600\3809306528\mods\Viewpoint\
├─ common\mod.info, poster.png
├─ LICENSE
└─ 42\media\
   ├─ java\client\Viewpoint.jar          ~800 classes + GLSL shaders, ~5 MB
   └─ lua\client\
      ├─ Viewpoint_Interact.lua          builds the crosshair interaction list
      ├─ Viewpoint_Loot.lua              loot take / take-all / loot window
      ├─ Viewpoint_Options.lua           Mod Options page + keybind dialog
      ├─ Viewpoint_Mouse.lua             world-coordinate override for the cursor
      └─ Viewpoint_FrameCapOptions.lua   splits the framerate option into game/menu
```

The Lua ships as plain source, so read it to understand how to interoperate. **Do not decompile the jar.** Listing class *names* (`unzip -l`) is fine and is how the architecture below was inferred.

## Architecture (inferred from class names, logs and stack traces)

- **The Java side does almost everything**: the rendering engine, camera, movement, input and interaction targeting. It hooks the game through ZombieBuddy `@Patch` classes (`viewpoint/Patch_*.class`). Notable targets by name: ContextPick, Pick{Corpse,Door,Hoppable,Thumpable,Tree,Vehicle,Window,WindowFrame}, Movement, Running, Sprinting, Strafing, MoveVector, LookAngle, AimFromReticle, LineOfSight, VisionCone, ZombieCull, CullAnimals, SoundListener, Thunder, WeatherFX, Window{Glass,Smash,Sync,Toggle}, SwitchPower, ViewDistance, LockFps, FramerateUncapped, Save/LoadOptions, KeyDown, MouseUpdate, IsoCursor, IsoReticle.
- **Render entry point**: `zombie.iso.IsoCell.render` → `viewpoint.Hooks.skipIsoCellRender` → `viewpoint.FP.renderWorld`. It replaces the isometric world draw while the view is on.
- **View-on flag**: `viewpoint.core.View.enabled` (public static boolean). Controller Aim reads this by reflection. It's the cleanest "is Viewpoint active?" check from Java.
- **Packages**: `core` (View, Frame, CameraSquares), `input` (Camera, Look, Locomotion, FreeCam, ThirdPerson, CrosshairAim…), `interact` (LootMenu, InteractActions, LootActions, MouseTargets…), `light`, `models` (Characters, Corpses…), `far` (distant world/LOD), `render`, `iris` (Minecraft Iris shader support), `packs` (model packs), `platform` (Settings, Keys, SettingsWindow, Onboarding…), `environment` (sky/weather), `game` (GameFixes, Hearing, Teleport, WorldToScreen…).

### Interaction flow (Java → Lua)

Each frame while the view is on:
`FP.renderWorld` → `FP.snapshot` → `interact.LootMenu.snapshot/show` → `InteractActions.update/gather` → `LootActions.call` → `LuaCaller.pcall` → **`ViewpointInteract.harvest(player, object)`** or **`ViewpointInteract.harvestVehicle(player, vehicle)`**

- `harvest` builds the **vanilla right-click menu off-screen** (`ISWorldObjectContextMenu.createMenu`), walks its options, keeps the ones that belong to the aimed object, then hides the menu. So bugs in vanilla or other mods' context-menu code surface here.
- `harvestVehicle` runs `ISVehicleMenu.showRadialMenuOutside` against a stand-in radial menu.
- Lua errors are caught and logged as `[Viewpoint] loot and interaction menu: <fn> <error>`.
- `ViewpointInteract.run(player, index)` executes the chosen entry from `ViewpointInteract.actions`.

## Lua API surface

**Globals defined in Viewpoint's Lua**
- `ViewpointInteract`: `harvest(player, obj)`, `harvestVehicle(player, vehicle)`, `run(player, index)`, `actions`
- `ViewpointLoot`: `explore(player, container)`, `take(player, item)`, `takeAll(player, items)`, `openWindow(player, container)`, `closeWindow(player)`, `shown`
- `ViewpointOptions`: `page` (its `PZAPI.ModOptions` page)

**Java classes exposed to Lua (via ZombieBuddy, from the log)**
- `Viewpoint.Keys`: get, set, id, count, group, label, trigger, fallback, tooltip, holds, display, captured, without, loot
- `Viewpoint.Loot`: setEnabled
- `Viewpoint.Mouse`: worldX, worldY (nil when not overriding)
- `Viewpoint.FrameCaps`: isFramerateUncapped, getGameFramerate, setGameFramerate, getMenuFramerateIndex, setMenuFramerateIndex
- `Viewpoint.ModelPacks`: `register(modId, manifestPath)`. Used by model-pack mods. The Voxel Studio pack mentions a "MODEL-PACK-GUIDE"

These names are only what Viewpoint's own Lua calls. Treat anything else as unverified until checked in-game, e.g. with ZombieBuddy's `zbmethods(Viewpoint.Keys)` in experimental mode.

### Vanilla functions Viewpoint replaces (compatibility hotspots)

Permanent wraps:
- `ISCoordConversion.ToWorld`, on OnGameStart, guarded by `ISCoordConversion.viewpointWrapped`
- `MainOptions:addModOptionsPanel`, `MainOptions:onKeyboardLayoutChanged`
- `MainOptions:addCombo` (framerate combo), guarded by `MainOptions.viewpointMenuFramerate`
- `ISSetKeybindDialog:onKeyRelease/onDefault/onClear/onMouseButtonDown`

Temporary swaps, restored after a pcall:
- `DebugContextMenu.doDebugMenu`, `getPlayerRadialMenu`, `ISVehicleMenu.getVehicleToInteractWith`, `ISTimedActionQueue.add`

### Input quirks (observed in testing, 0.1.5a-hotfix)

- With the view on, the left mouse button reads as **permanently held** both through the game (`IsoPlayer:isBuildButtonDown()`, i.e. the Attack binding) and raw (`isMouseButtonDown(0)`). Lua can't detect left clicks. Use Viewpoint's interaction menu (wrap `ViewpointInteract.harvest`) or a key.
- `isoToScreenX/Y` is **not** 3D-projected: it still maps to iso screen space. Lua can't draw world-anchored overlays with it.
- `Viewpoint.Mouse.worldX/worldY` returns the aimed world point (tracked the crosshair/mouse correctly in testing).

## Config and logs

- `%USERPROFILE%\Zomboid\viewpoint-live.properties`: everything in the settings window (Delete key), including keys, graphics packs, memory pools, LOD and mouse. Edit by hand only with the game closed.
- `%USERPROFILE%\Zomboid\viewpoint-framecap.properties`: game/menu frame caps.
- `%USERPROFILE%\Zomboid\viewpoint.properties`: `dev=true` turns on developer mode; `shaderDir` sets where shaders are read from in dev mode.
- Custom shader packs go in `%USERPROFILE%\Zomboid\viewpoint-shaderpacks`.
- `console.txt` lines start with `[Viewpoint]`. It writes a periodic perf summary (`N fps | gpu ms …`), `slow frame on the main/render thread` lines, and `action state <state> moving=… aiming=…` lines.
- ZombieBuddy lines start with `[ZB]`. They show which Java mods loaded and which classes were exposed to Lua.

## Default controls

O: first person. Shift+O: third person. Insert+O: free cam. Shift+Insert+O: physical free cam. Delete: settings. Middle mouse: cursor on/off. F9: screenshot. Loot: F take, R take all, Tab loot window.

## Ecosystem (installed here)

- **ZombieBuddy** (3619862853, v2.3.4, MIT, source included). Java bytecode patching plus Lua exposure. Docs are in its `doc/` folder (ModdingGuide, LuaAPI, DevDebugFunctions). It loads as a Java agent through `-agentlib:zbNative` in `ProjectZomboid64.json`. Java mods need a one-time approval, stored in `%USERPROFILE%\.zombie_buddy\mod_approvals.json`.
- **ZombieBuddyFix** (3809837933, MIT). Makes ZombieBuddy work on 42.21.
- **Controller Aim for Viewpoint** (3811577340, MIT, ships its source). **This is the reference pattern for a Java add-on.** It patches *game* classes rather than Viewpoint's, reads `viewpoint.core.View.enabled` by reflection so it still loads if Viewpoint is missing or renamed, disables itself after its first error, and writes `[ModName]` log lines. It's built with `javac --release 25` against `projectzomboid.jar` and `ZombieBuddy.jar`.
- **6261 3D models for Viewpoint** (3810302175). A model pack registered through `Viewpoint.ModelPacks.register`.

## Known issues

Our own observations are tracked in [bugs.md](bugs.md). Steam discussion topics as of 2026-10-05 (not verified by us): first person randomly stops working; Viewpoint forced off until restart; stops working after long multiplayer sessions; stuck on the "welcome to Project Viewpoint" screen; corpse interaction shows a safehouse-permission message; free-cam speed; shaders not loading; AMD Ryzen compatibility; Steam Deck. Most install problems come from ZombieBuddy setup, not Viewpoint.

## Re-checking after a Viewpoint update

1. `common/mod.info`: check `modversion`, `versionMin/Max` and `ZBVersionMin`.
2. Diff the five Lua files against what our fixes assume (function names, global names, guard flags).
3. `unzip -l Viewpoint.jar`: check that the classes we reference by name still exist.
4. Check whether any open entry in `bugs.md` is now fixed upstream. If so, retire our fix.
