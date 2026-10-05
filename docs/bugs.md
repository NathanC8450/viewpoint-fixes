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
