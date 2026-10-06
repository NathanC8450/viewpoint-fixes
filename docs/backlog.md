# Backlog

Known issues and things to look at later. Move an item to docs/bugs.md (as a VPF-NNN entry) when work on it starts; delete it when done.

## Known issues

- **VPF-003: Tab doesn't cycle surface heights** while placing an item (vanilla `checkSelectSurfaceKey`, `isKeyPressed(TOGGLE_MODE)`). Probably the same key hiding as R was (Viewpoint's `KeyboardState.isKeyDown` patch), but press-edge detection needs a raw-key fallback. Accepted for now.
- **VPF-003: Shift+F "place all"** works (vanilla place-all) but its purpose in this flow is unclear. Revisit.
- **VPF-002: cursor-mode quirks** reported ("a bit bugged", unspecified). The log showed rotate-mode menus with 0 entries on some squares (5560,6060). Needs a repro: which mode (pick up / rotate / place) and view.
- **VPF-002: duplicate facings in the rotate menu** (mattress listed S/E twice): fix written (each facing listed once), needs confirming in game.

## To do

- **Controller support**: VPF-002 first pass written (pad cursor follows the crosshair tile; untested). VPF-003 on the pad not started. d-pad tile nudging, multi-object selection on one tile and an on-screen prompt are not handled.
- Rebuild the jar with the game closed (`tools/build-java.ps1`) so the committed jar no longer contains the removed probe patches; commit it.
- Report to Viewpoint upstream (Discord / Steam discussions): `Viewpoint.Mouse.worldX/Y` is nil while the pointer moves; no API for custom 3D cursors or previews; the place-item and move cursors don't work at all under Viewpoint.
- VPF-001 (optional, see docs/bugs.md).
- Delete the old `Projects\MyFirstMod` folder (only with the user's confirmation).
