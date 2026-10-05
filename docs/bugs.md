# Viewpoint bug log

One entry per bug. Keep an entry after it's fixed, and record when our fix can be retired.

Status: `observed` → `diagnosed` → `fixing` → `fixed (ours)` → `retired (fixed upstream in X)` / `wontfix`

Template:

```
## VPF-NNN: short title
- Status:
- Viewpoint version seen: 
- Repro: steps to trigger it
- Evidence: console.txt excerpt / screenshot
- Root cause: where it happens (file:line, or the game/Viewpoint class name)
- Fix layer: Lua wrap | Java game patch | none possible
- Fix: what we change, and the file it lives in
- Retire when: the condition that makes our fix unnecessary
- Reported upstream: link or date, or "no"
```

---

## VPF-001: vehicle interaction error while quitting to the main menu
- Status: observed (low priority, cosmetic)
- Viewpoint version seen: 0.1.5a-hotfix
- Repro: be near or looking at a vehicle in first person, then quit to the main menu.
- Evidence: `attempted index: inventoryPane of non-table: null` at vanilla `Vehicles.lua:1017 getContainers` ← `ISVehicleMenu.lua:314 showRadialMenuOutside` ← `Viewpoint_Interact.lua:296 radialEntries` ← `harvestVehicle`. The Java caller is `IngameState.exit → IsoWorld.render → FP.renderWorld`, so Viewpoint renders one more frame after the player's inventory UI has been torn down (`removing all player data`).
- Root cause: `ViewpointInteract.harvestVehicle` runs during `IngameState.exit` when `getPlayerLoot(playerNum)` is already nil.
- Fix layer: Lua wrap. Skip harvesting when `getPlayerLoot(player:getPlayerNum())` is nil.
- Retire when: Viewpoint guards this itself.
- Reported upstream: no

## VPF-002: furniture pick up / place / rotate cursor doesn't work
- Status: fixing. v2 written after the first in-game test, **v2 not yet tested**
- Viewpoint version seen: 0.1.5a-hotfix
- Repro: enter Pick up / Place / Rotate (the moveables cursor, `ISMoveableCursor`) with the view on. User confirmed: no outline at all, clicks do nothing, broken in third person too.
- Evidence (game bytecode, method names and call sites via `javap` on `projectzomboid.jar`):
  - `IsoCell.DoBuilding(int player, boolean isRender)` → `doBuildingInternal` fires Lua `OnDoTileBuilding2(drag, isRender, x, y, z, square)`. The tile comes from `UIManager.getPickedTile()` and z from `IsoCamera.getCameraCharacterZ()`.
  - It's called with `isRender=true` only from `IsoCell.renderInternal` and `FBORenderCell.renderInternal` (the iso world render), and with `isRender=false` from `UIManager.update`.
  - Vanilla `DoTileBuilding` (`server/BuildingObjects/ISBuildingObject.lua:97`) computes `canBeBuild = isValid(...)` and draws the ghost **only when isRender**. The non-render call reads the click and runs `tryBuild` only `if canBeBuild and build`.
- Root cause: Viewpoint replaces the world render (`IsoCell.render` → `viewpoint.Hooks.skipIsoCellRender`), so the `isRender=true` call never happens. `canBeBuild` is never set, nothing is drawn, and clicks do nothing. The picked tile also comes from an isometric screen→tile mapping that doesn't match a 3D camera.
- Fix layer: Lua. Replace the `OnDoTileBuilding2` handler while Viewpoint's view is on: feed it a tile chosen from the 3D view, run validation each frame, and draw our own indicator, since vanilla `RenderGhostTileColor` draws in iso screen space.
- Fix: `fixes/VPF_002_MoveableCursor.lua`. It swaps vanilla `DoTileBuilding` on `OnDoTileBuilding2` for a wrapper, which only acts for `ISMoveableCursor` drags, and only while no `isRender=true` call has arrived in the last 500 ms. That makes it self-disabling in iso view or if Viewpoint fixes this upstream. For each non-render call it:
  - takes the tile from `Viewpoint.Mouse.worldX/Y`, falling back to the tile in front of the player;
  - validates it with `drag:isValid`;
  - calls vanilla `DoTileBuilding(drag, false, …)` with that tile, so the click → `tryBuild` path runs.
  It disables mouse-drag rotation (an iso screen mapping); the rotate key still works. Feedback is drawn on `OnPreUIDraw`: a tile quad projected with `isoToScreenX/Y`, plus a "Mode: object" label under the crosshair, green when valid and red otherwise. Controller (`OnDoTileBuilding3`) isn't handled yet.
- **Test 1 (2026-10-05, v1)**: user saw a crude pick-up indication but couldn't execute anything, and rotate worked badly. The probe (21 lines) showed:
  - `source=viewpoint` every time; `Viewpoint.Mouse.worldX/Y` tracks the aim and `canBeBuild=true`. **Targeting works.**
  - `buttonDown=true` in *every* sample, even with the mouse still for seconds. `IsoPlayer:isBuildButtonDown()` = `CharacterInputComponent.isBuildButtonDown` → `CharacterInputKeyBinding.Attack.isKeyDownInWorld()` (keyboard/mouse mode), and it reads as permanently held under Viewpoint. `isBuildButtonReleased` uses a separate `TimedInputHandler build`, which never fires. So vanilla never builds, and `isLeftDown` stays true, pinning the cursor to its first square (hence bad rotate). *Why* Attack reads as held is inferred (Viewpoint drives attack input itself), not verified.
  - `screenOfTile` (from `isoToScreenX/Y`) doesn't match the mouse position Viewpoint's 3D point came from. **`isoToScreenX/Y` is not 3D-projected under Viewpoint**, so the projected quad was in the wrong place.
- **v2 changes**: no longer calls vanilla `DoTileBuilding` during takeover. Instead it sets `isLeftDown/build=false`, sets `square`, runs `isValid`, detects a click itself with `isMouseButtonDown(0)` edges (the press must start while this cursor is out, so the menu click that opened the mode doesn't count, and clicks over UI are ignored), then calls `drag:tryBuild`. The quad is removed. The label now adds the facing for place/rotate (`currentMoveProps:getFaceDirectionFromSpriteName`) and goes red when `canCreate` is false. Rotate direction cycles with the vanilla rotate key (`ISMoveableCursor:rotateKey`, which bumps `objectIndex`).
- To verify (v2 probe logs every click plus once a second): `rawDown` toggles with real clicks (if it's also stuck, raw mouse input is captured too); `clicked=true` leads to the action running; whether a click also makes the character attack; whether the rotate key reaches the cursor (Viewpoint binds R to loot "take all").
- Open questions (need an in-game probe): does `Viewpoint.Mouse.worldX/worldY` give the aimed world point in first person (crosshair) and third person? Is `isoToScreenX/Y` projected by Viewpoint into 3D screen space (usable to outline the tile)? Is `RenderGhostTileColor` visible at all? Does the B42 build/craft placement cursor (also `ISBuildingObject`) break the same way?
- Retire when: Viewpoint drives `DoBuilding` render/validation itself.
- Reported upstream: no
