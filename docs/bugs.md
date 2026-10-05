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
- Status: **fixed (ours), verified in game 2026-10-05.** Pick up (radio, mattress), place (mattress, radio) and rotate (mattress `carpentry_02_78→76` E, `76→79` S) all traced to completion in 3D. Fridge rotate is greyed out (`canCreate=false`), which is vanilla's rule against rotating a container with items in it. Diagnostic watcher and trace hook removed after verification; the generic `Debug/Trace.lua` stays.
- Not yet tested: controller (`OnDoTileBuilding3`), scrap/repair modes, multiplayer.
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
- **Test 2 (2026-10-05, v2)**: the label and facing update worked (rotate even showed the example image), but there was still no way to perform anything. Re-entering the mode showed the old facing again, because nothing had been applied. Probe: `rawDown=true` in every sample, and zero `clicked=true`. **The raw left button `isMouseButtonDown(0)` also reads as permanently held under Viewpoint**, so no mouse-click detection is possible from Lua.
- **v3 design (user's direction: behave as a Viewpoint extension, consistent with its UI)**: wrap `ViewpointInteract.harvest`. While a moveable cursor is out, return the cursor's choices as Viewpoint's interaction menu (`{title, labels, enabled, seen}` plus `ViewpointInteract.actions` entries `{name, fn, args, n, enabled}` that `ViewpointInteract.run` executes). Choices: pickup/scrap/repair give one entry per object on the square (`objectIndex`); rotate gives one per facing (`objectIndex` into `getIndexedFaces`, current facing disabled); place gives one per facing (`cursorFacing`). Each is evaluated with vanilla `isValid`; accepting one runs `isValid` + `tryBuild` (`skipBuildAction` → walk + `ISMoveablesAction`). Fallback when Viewpoint shows no menu: a label plus Viewpoint's loot-take key (read via `Viewpoint.Keys.trigger(Viewpoint.Keys.get("lootTake"))`, default F; unverified API) accepts the current choice. It's suppressed while the menu is fresh (<300 ms), so there's no double action.
- To verify (v3): the log has `installed (with Viewpoint interaction menu)`; `menu mode=… entries=N` lines appear, i.e. Java calls the *current* global `ViewpointInteract.harvest` rather than a reference cached at startup; accepting logs `perform … canCreate=true` and the character walks over and acts.
- **Test 3 (2026-10-05, v3)**: the user saw the state "reset when you accept", plus errors. Log:
  - **The Viewpoint menu integration works.** `menu mode=pickup … entries=2` and `menu mode=rotate … entries=4` show that Java calls our wrapped `ViewpointInteract.harvest` (it looks the function up at call time). Accepting reaches `perform … canCreate=true` through both the menu and F.
  - **Errors (ours):** `Viewpoint.Keys.get("lootTake")` → `IllegalArgumentException: no key binding lootTake` (Keys.find). Our pcall caught it, but **Kahlua still logs Java exceptions raised inside pcall**, and it ran every frame. Lesson: never probe Java APIs with guessed arguments per frame.
  - Nothing happened after `perform`. Vanilla `ISMoveablesAction:waitToStart` returns `character:shouldBeTurning()` after `faceThisObject` / `faceLocation`. **Hypothesis (inferred):** Viewpoint drives the character's facing from the camera, so the turn never completes and the action never starts, then gets dropped.
- **v4**: watches the `ISMoveablesAction` that `tryBuild` queued (instance-level wraps of `waitToStart` / `isValid` / `start` / `perform`). If it's stuck turning for more than 1.5 s it's allowed to start, logged as `stuck turning … starting it anyway`. With Debug logging on, it logs the queue after accept, per-second `state=… shouldBeTurning=…`, any invalidation (`playerZ`, `targetZ`, `adjacent`), and the final state after 6 s. The accept key is now discovered once from `Viewpoint.Keys.count/id` (ids only from Viewpoint itself) and cached; the discovered ids are logged.
- **Test 4 (2026-10-05, v4)**: the user says rotate still does nothing visible. Log: `queue after accept: [ISMoveablesAction]` → `shouldBeTurning=false` throughout → `action rotate performed` (twice) → final state `performed`. So **the turn-wait hypothesis was wrong**: the action starts and performs normally. The fallback F also worked (`perform` with an empty queue, i.e. extra presses). Vanilla `perform()` only plays the sound. The world change happens in `complete()` → `ISMoveableSpriteProps:rotateMoveable`, which picks up the original and places the faced sprite.
- **v4.1**: logs `complete()` with orig/target sprite, direction, cursorFacing and the square's sprites before/after. The open question: (A) the sprite changed but Viewpoint's 3D view didn't redraw it (a separate Viewpoint render-cache bug, and VPF-002's own job would be done), or (B) it rotated to the same facing. Quick check: after rotating, press O to go back to iso view and see whether the microwave faces the new way.
- **Test 5 (2026-10-05, v4.1)**: no visible change, and **the user reports rotate is also broken in vanilla 2D view.** The `complete()` log is decisive. Three rotates ran with correct targets (`appliances_cooking_01_25` → `_26` W, `_24` E, `_27` N) and `result=true`, **but the square's sprites were identical before and after.** So vanilla's rotate itself no-ops; it isn't a 3D redraw problem. Path (single-tile): `ISMoveablesAction:complete` → `rotateMoveableViaCursor` → `rotateMoveable` → `origProps:pickUpMoveable(char, sq, true, true)` then `self:placeMoveable(char, sq, orig, true)` (pick the original up into the inventory, place the faced sprite from it). The object stayed, so pickup no-op'd. Candidate: `pickUpMoveableInternal` does nothing at all if `instanceItem(spriteName)` returns nil (line 1381 `if item or …`). Unverified.
- **Investigation tooling added**: `Debug/Trace.lua` (generic call tracer) and `Debug/TraceMoveables.lua` (arms it around every `ISMoveablesAction:complete`, vanilla or ours, and traces the pickup/place/rotate functions on `ISMoveableSpriteProps`).
- **Next test**: Debug logging on. (1) VPF-002 **unticked**, 2D view: rotate the microwave the vanilla way (the baseline, so we know whether this is vanilla/Viewpoint without us). (2) VPF-002 ticked, 3D: rotate once. Compare the two traces.
- **Test 6 (2026-10-05, baseline: VPF-002 OFF, 2D view, vanilla rotate of the microwave)**: still "fails". The trace settled it:
  - `pickUpMoveable(_25)` → `findOnSquare` → `obj(_25)`; `instanceItem` → `item(Base.appliances_cooking_01_25)`
  - `placeMoveable(_26)` → `findInInventory` → item; `canPlaceMoveableInternal` → true; **`placeMoveableInternal(item, "_26")` → `obj(appliances_cooking_01_25)`**
  - Cause: **vanilla design.** `placeMoveableInternal` (ISMoveableSpriteProps.lua ~2225) says that if the item `isTableTop` (sprite prop `IsTableTop`) and not `ignoreSurfaceSnap`, and it sits on a table with a `Facing` (here `furniture_tables_high_01_52`, facing S), then `getFaceSpriteFromParentObject` replaces the requested sprite with the item's face matching the table. A microwave on a faced table always snaps back to the table's facing, so "rotate" is a visual no-op in vanilla 2D too. **Not a Viewpoint bug and not ours.**
- **So VPF-002's actual work is likely done.** The cursor now drives Viewpoint's menu, actions queue, start, perform and complete (all traced). Still to confirm: rotate a *free-standing* object (not a table-top item on a faced table), and pick up / place in 3D.
- Possible follow-up (UX, needs the user's say-so): in the menu, disable or annotate rotate facings that will snap back (table-top item on a faced table), since vanilla offers them misleadingly.
- Earlier verification list (v2), kept for reference: `rawDown` toggles with real clicks (if it's also stuck, raw mouse input is captured too); `clicked=true` leads to the action running; whether a click also makes the character attack; whether the rotate key reaches the cursor (Viewpoint binds R to loot "take all").
- Open questions (need an in-game probe): does `Viewpoint.Mouse.worldX/worldY` give the aimed world point in first person (crosshair) and third person? Is `isoToScreenX/Y` projected by Viewpoint into 3D screen space (usable to outline the tile)? Is `RenderGhostTileColor` visible at all? Does the B42 build/craft placement cursor (also `ISBuildingObject`) break the same way?
- Retire when: Viewpoint drives `DoBuilding` render/validation itself.
- Reported upstream: no

## VPF-003: inventory "Place item" (free 3D placement) does nothing
- Status: v4 written, untested. Test 1: placing works (cursor mode only, test 2); rotation and preview missing
- Viewpoint version seen: 0.1.5a-hotfix
- Repro: inventory → right-click an item (e.g. a radio) → Place Item. In 2D this gives a cursor where the item follows the mouse at sub-tile precision, R / Shift+R rotate it 360° (5° steps), Tab cycles surface heights, and a click places it. With Viewpoint's view on, the mode starts but nothing happens and there's no way to place.
- Vanilla flow (`server/BuildingObjects/ISPlace3DItemCursor.lua`, 491 lines, read in full):
  - It's an `ISBuildingObject` drag cursor (`getCell():setDrag`), so `DoTileBuilding` / `isValid` / `tryBuild` → `create()` apply, like VPF-002 (`skipBuildAction`, `dragNilAfterPlace`, `walkTo` → true).
  - **`renderOpaqueObjectsInWorld(x, y, z, square)` does almost everything.** It reads R / Shift+R (`checkRotateKey` → `isKeyDown(ROTATE_BUILDING)`, held = smooth, tap = 5°) and Tab (`checkSelectSurfaceKey`); takes the sub-tile point from `screenToIsoX/Y(getMouseX/Y)`, locking to the square while `isLeftDown`; sets `selectedSqDrop`, `render3DItemX/Y/ZOffset` and `itemSq`; and draws the preview with `Render3DItem(...)`.
  - `create()` reads `isShiftKeyDown()` (place all) and queues `ISDropWorldItemAction(item, selectedSqDrop, xOff, yOff, zOff, rot)` after `luautils.walkAdjAltTest`.
  - `renderOpaqueObjectsInWorld` is called only by vanilla's `Events.RenderOpaqueObjectsInWorld` handler (ISBuildingObject.lua ~722). That event is fired **only** by `FBORenderCell.renderOpaqueObjectsEvent` ← `FBORenderCell.performRenderTiles` (javap), the iso world render that Viewpoint replaces.
- Root cause: under Viewpoint none of the per-frame cursor logic runs, so there's no position, rotation, surface or preview, and `selectedSqDrop` stays nil. Same as VPF-002, `isValid` never runs and clicks never register (left button reads as held).
- Fix plan (Lua, the same pattern as VPF-002, kept as a separate toggle): while `RenderOpaqueObjectsInWorld` isn't firing, call the cursor's own `renderOpaqueObjectsInWorld` each frame from the still-running `UIManager.update` → `OnDoTileBuilding2(drag, false, …)`. During that call, swap `screenToIsoX/Y` for Viewpoint's 3D aim point (`Viewpoint.Mouse.worldX/Y`), force `isLeftDown=false` (the stuck button would lock it to one square), and stub `Render3DItem` (a render call outside the render pass). So vanilla still handles rotation keys, surfaces, offsets and range. Accept through Viewpoint's interaction menu (wrap `ViewpointInteract.harvest`, as in VPF-002), with F as the fallback. Shift held at accept = place all (vanilla). A label shows item, rotation and validity, since the 3D preview can't be drawn (unverified whether `Render3DItem` could show under Viewpoint).
- Open questions for the first test: does R / Shift+R / Tab reach `isKeyDown` under Viewpoint; does Viewpoint offer a menu when aiming at a table top / bare floor with this cursor out; does the item land where aimed?
- Test 1 (2026-10-05, fix b10fa23): **placing works.** F queued `ISDropWorldItemAction` with the aimed square and sub-tile offsets (e.g. aim 5560.30,6058.51 → sq 5560,6058 offset 0.30,0.51), `complete()` ran, and the radio landed where aimed. **Rotation never changed** (`rot=0` in every probe and both drops, though the user pressed R). **No preview is visible**: expected, since `Render3DItem` is stubbed and the iso renderer it draws through isn't shown in 3D.
- Rotation analysis: `checkRotateKey` reads `isKeyDown(KeybindId.ROTATE_BUILDING)` → `GameKeyboard.isKeyDown(int)`, which just returns `down[key]` (javap). Viewpoint binds R (`keys.lootTakeAll`) and ships a `Patch_KeyDown` class (name only; not decompiled), so it likely hides its own keys from the game (inferred). `GameKeyboard.update` raises `OnKeyStartPressed` / `OnKeyKeepPressed` / `OnKeyPressed` straight from the keyboard state, independent of `isKeyDown`. v2: track the rotate key through those events and pass `isKeyDown or events` to vanilla `handleRotate` (instance override of `checkRotateKey` for the driven call only). The debug probe logs `rotate key: isKeyDown=… events=… shift=…` on change, to confirm which source is blocked.
- Known side effect to check: R is also Viewpoint's "take all" loot key, and Tab (surface cycle) is its loot window key.
- Preview: drawing the item model in 3D would need Viewpoint to render it (no Lua API for that). Candidate upstream request.
- Test 2 (2026-10-05, v2 927449d): placing **only worked with the middle-click cursor shown**; still no preview; rotation still 0, and the probe never saw R (`isKeyDown=false events=false` once). The user allowed reading Viewpoint.jar for debugging, which explained all three (details in viewpoint.md, "Internals"):
  - `Viewpoint.Mouse` is the cursor pick only, nil in crosshair mode, so `drive` returned early in normal play. The crosshair pick (`MousePick.aimHit`) is Java-only.
  - Viewpoint draws world items only from `Frame.modelItems` while capturing, so no Lua-side preview can show.
  - `Patch_KeyDown` patches `KeyboardState.isKeyDown`, so the key events see what `isKeyDown` sees (the v2 event workaround could never help). In practice the loot menu only takes R/Tab while it's showing (crosshair mode); in cursor mode R should have reached the cursor, so the R test is still open. Also, even a correct rotation wouldn't have shown: see VPF-004.
- v3 (user chose the Java helper): `java/src/viewpointfixes`.
  - `ViewpointFixesJava.aimX/Y/Z` reads `MousePick.aim/aimHit` (crosshair). Lua prefers `Viewpoint.Mouse` (cursor mode), then the crosshair.
  - Preview: `Patch_PreviewItem` (OnEnter `viewpoint.models.Models.snapshot`) adds a preview `IsoWorldInventoryObject` to `frame.modelItems`. It's built on a throwaway `instanceItem(fullType)` copy (the constructor rewrites the item's rotation/container) and never added to a square, so it can't be saved, looted or synced. Its rotation is `setWorldZRotation(clamp(rot))`, shown thanks to VPF-004.
  - Viewpoint's loot menu is paused (`Viewpoint.Loot.setEnabled(false)`) while the cursor is out and restored to the user's `lootMenu` option afterwards, so R/Tab/F reach the game. The v2 key-event workaround and the harvest-menu entry were removed (the menu can't show while paused). F places, Shift+F places all.
  - Untested.
- Test 3 (2026-10-05, ae1f4f9): the Java part loaded (both patches applied, status ok), but the radio model didn't render in 3D at all (VPF-004's double rotation, now withdrawn; the preview is unconfirmed either way). The aim came from the mouse (cursor mode). The rotate key never read as down (`down=false` once), even with the loot menu paused.
- v4:
  - VPF-004 removed.
  - Rotation: vanilla `handleRotate` gets `isKeyDown(binding) or raw` (`ViewpointFixesJava.rawKeyDown`, the lwjgl keyboard below Viewpoint's patch), and the same for Shift.
  - Debug probes: a Lua line on key-state change (`rotate key R: game=… raw=…`), and Java lines `preview added to Viewpoint's world items (…)` and `preview renderMain -> <status | threw …>` (`Patch_PreviewProbe`, temporary).

## VPF-004: (withdrawn) "world items drawn unrotated"
- Status: **wontfix: misdiagnosis.** I read only the call site (`renderMain(..., 0f, 0f, false)`) and missed that Viewpoint's `RigidCapture.item` applies the item's own rotation itself. The patch (forced `-1`) double-rotated items. In test 3 the radio didn't render at all. Removed.
