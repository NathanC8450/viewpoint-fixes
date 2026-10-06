# Backlog

Known issues and things to look at later. Move an item to docs/bugs.md (as a VPF-NNN entry) when work on it starts; delete it when done.

## Known issues

- **VPF-003: Tab doesn't cycle surface heights** while placing an item (vanilla `checkSelectSurfaceKey`, `isKeyPressed(TOGGLE_MODE)`). Probably the same key hiding as R was (Viewpoint's `KeyboardState.isKeyDown` patch), but press-edge detection needs a raw-key fallback. Accepted for now.
- **VPF-003: Shift+F "place all"** works (vanilla place-all) but its purpose in this flow is unclear. Revisit.
- **VPF-002: cursor-mode quirks** reported ("a bit bugged", unspecified). The log showed rotate-mode menus with 0 entries on some squares (5560,6060). Needs a repro: which mode (pick up / rotate / place) and view.
- **VPF-002: duplicate facings in the rotate menu** (mattress listed S/E twice): fix written (each facing listed once), needs confirming in game.

## To do

- **Controller support**: VPF-002 first pass written (pad cursor follows the crosshair tile; untested). VPF-003 pad: A now places (untested). VPF-002 place mode keeps vanilla buttons (RB cycles objects, X rotates). Furniture place mode has no 3D preview on the pad (vanilla draws a 2D ghost only); a 3D furniture preview would be a new feature, not a fix. d-pad tile nudging, multi-object selection on one tile and an on-screen prompt are not handled.
- Report to Viewpoint upstream (Discord / Steam discussions): `Viewpoint.Mouse.worldX/Y` is nil while the pointer moves; no API for custom 3D cursors or previews; the place-item and move cursors don't work at all under Viewpoint.
- VPF-001 (optional, see docs/bugs.md).
- Delete the old `Projects\MyFirstMod` folder (only with the user's confirmation).

## Controller known issues

- **VPF-002 pad, rotate mode:** pressing A to rotate a mattress to the facing it already has ends in the character sitting on the ground (log 2026-10-06: A at `canBeBuild=true canCreate=true`, `sitonground` nine frames later). An attempt to swallow A in that case (and when the cursor can't apply) did not behave as intended and risked blocking A elsewhere, so it was removed. Revisit after the 3D furniture preview, which may change what the pad cursor reports.
- **VPF-002 pad, place/rotate preview:** only vanilla's 2D ghost overlay is drawn, and it disappears after X rotates in place mode. Needs a 3D furniture preview (investigate how Viewpoint draws furniture first).

