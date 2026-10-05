--[[
VPF-003: inventory "Place item" (ISPlace3DItemCursor, free 3D placement) does nothing with Viewpoint's view on.

Bug:   the place-item mode starts, but the item never follows the aim, can't be rotated, and can't be placed.
Cause: the vanilla cursor does almost all of its work in renderOpaqueObjectsInWorld() (rotation keys, sub-tile
       position from the mouse, surface height, selectedSqDrop, preview). That's only called from
       Events.RenderOpaqueObjectsInWorld, which only FBORenderCell.performRenderTiles fires: the iso world
       render Viewpoint replaces. Like VPF-002, isValid only runs on the render pass and clicks can't be read
       (the left button reads as held under Viewpoint).
Fix:   while that event isn't firing, run the cursor's own renderOpaqueObjectsInWorld each frame from the
       still-running non-render OnDoTileBuilding2 call, with screenToIsoX/Y answering Viewpoint's 3D aim point,
       isLeftDown cleared (else it locks to one square) and Render3DItem skipped (a render call outside the render
       pass). Vanilla then still handles the surface key, offsets and range. R / Shift+R go through vanilla
       handleRotate, but the held state also comes from the key events, since isKeyDown(Rotate building) never
       saw R in 3D (first test). Placing is
       offered in Viewpoint's interaction menu (F accepts); where Viewpoint shows no menu, F accepts directly.
       Holding Shift when accepting places all (vanilla). A label shows item, rotation and validity, since the
       3D preview can't be drawn.
Seen:  Viewpoint 0.1.5a-hotfix, game 42.21.
Retire when Viewpoint fires (or replaces) RenderOpaqueObjectsInWorld for placement cursors.
]]
require "ViewpointFixes/ViewpointFixes"
-- ISPlace3DItemCursor lives in the server Lua folder (loads after client files): referenced at runtime only.

local VF = ViewpointFixes
local ID = "VPF_003"

VF.register({ id = ID, label = "UI_ViewpointFixes_VPF003", tooltip = "UI_ViewpointFixes_VPF003_Tooltip" })

local EVENT_STALE_MS = 500 -- RenderOpaqueObjectsInWorld newer than this: vanilla is driving the cursor
local MENU_FRESH_MS = 300  -- Viewpoint asked for menu entries this recently: its menu is showing

local lastRenderEvent = {} -- playerNum -> timestamp of the last RenderOpaqueObjectsInWorld
local lastMenu = {}        -- playerNum -> timestamp Viewpoint last asked us for menu entries
local driven = {}          -- playerNum -> cursor we drove this frame (for the label / key fallback)
local lastProbe = 0

local function now() return getTimestampMs() end

local function isPlaceCursor(drag)
    return type(drag) == "table" and drag.isPlace3DCursor == true
end

local function vanillaIsDriving(playerNum)
    local t = lastRenderEvent[playerNum]
    return t ~= nil and now() - t < EVENT_STALE_MS
end

local function menuShowing(playerNum)
    return lastMenu[playerNum] ~= nil and now() - lastMenu[playerNum] < MENU_FRESH_MS
end

-- The place-item cursor we should be driving for this player, or nil.
local function activeCursor(playerNum)
    if not VF.isEnabled(ID) or vanillaIsDriving(playerNum) then return nil end
    local drag = getCell():getDrag(playerNum)
    if isPlaceCursor(drag) and drag.items and drag.items[1] then return drag end
    return nil
end

-- Viewpoint's 3D aim point as fractional world coordinates, or nil.
local function aimPoint()
    local mouse = Viewpoint and Viewpoint.Mouse
    local wx = mouse and mouse.worldX()
    local wy = mouse and mouse.worldY()
    if wx and wy then return wx, wy end
    return nil
end

-- Rotate key held, from the game's key events (OnKeyStartPressed / OnKeyKeepPressed / OnKeyPressed), which are
-- raised from the raw keyboard state. In 3D, isKeyDown(Rotate building) stayed false while R was held (test
-- 2026-10-05: rot never left 0); the probe below logs both sources so the blocked one is on record.
local rotateKey = { held = false, seen = 0 }
local KEY_HELD_STALE_MS = 200 -- no keep-pressed event for this long: treat as released (e.g. focus lost)

local function isRotateKey(key)
    local core = getCore()
    return key == core:getKey(KeybindId.ROTATE_BUILDING) or key == core:getAltKey(KeybindId.ROTATE_BUILDING)
end

local function onRotateKeyDown(key)
    if isRotateKey(key) then rotateKey.held, rotateKey.seen = true, now() end
end

local function rotateKeyHeld()
    return rotateKey.held and now() - rotateKey.seen < KEY_HELD_STALE_MS
end

local lastKeyProbe = ""

-- One frame of the vanilla cursor's own logic, aimed where Viewpoint aims.
local function drive(drag, playerNum)
    local player = getSpecificPlayer(playerNum)
    local wx, wy = aimPoint()
    if not (player and wx) then return false end
    local z = math.floor(player:getZ())
    local square = getCell():getGridSquare(math.floor(wx), math.floor(wy), z)

    -- Vanilla checkRotateKey, with the key state also taken from the key events.
    local gameDown, eventDown, shift = isKeyDown(KeybindId.ROTATE_BUILDING), rotateKeyHeld(), isShiftKeyDown()
    drag.checkRotateKey = function(self)
        if self.chr:getPlayerNum() ~= 0 or self.chr:getJoypadBind() ~= -1 then return end
        self:handleRotate(gameDown or eventDown, shift)
    end
    if VF.debugEnabled() then
        local state = string.format("rotate key: isKeyDown=%s events=%s shift=%s", tostring(gameDown),
            tostring(eventDown), tostring(shift))
        if state ~= lastKeyProbe then
            lastKeyProbe = state
            VF.log(ID, state .. " rot=" .. tostring(drag.render3DItemRot))
        end
    end

    local toX, toY, render3D = screenToIsoX, screenToIsoY, Render3DItem
    screenToIsoX = function() return wx end
    screenToIsoY = function() return wy end
    Render3DItem = function() end
    drag.isLeftDown = false
    local ok, err = pcall(drag.renderOpaqueObjectsInWorld, drag, math.floor(wx), math.floor(wy), z, square)
    screenToIsoX, screenToIsoY, Render3DItem = toX, toY, render3D
    drag.checkRotateKey = nil
    if not ok then error(err, 0) end

    local drop = drag.selectedSqDrop
    drag.canBeBuild = drop ~= nil and drag:isValid(drop) == true
    driven[playerNum] = drag

    if VF.debugEnabled() and now() - lastProbe > 1000 then
        lastProbe = now()
        VF.log(ID, string.format("aim=%.2f,%.2f drop=%s offset=%.2f,%.2f,%.2f rot=%s surface=%s/%d valid=%s items=%d",
            wx, wy, drop and (drop:getX() .. "," .. drop:getY() .. "," .. drop:getZ()) or "nil",
            drag.render3DItemXOffset or -1, drag.render3DItemYOffset or -1, drag.render3DItemZOffset or -1,
            tostring(drag:clamp(drag.render3DItemRot or 0)), tostring(drag.surfaceSelected),
            drag.surfacesPossible and #drag.surfacesPossible or 0, tostring(drag.canBeBuild), #drag.items))
    end
    return true
end

local function onDoTileBuilding(drag, isRender)
    if isRender or not isPlaceCursor(drag) then return end
    local playerNum = drag.player or 0
    if activeCursor(playerNum) ~= drag then
        driven[playerNum] = nil
        return
    end
    local ok, handled = VF.guard(ID, drive, drag, playerNum)
    if not (ok and handled) then driven[playerNum] = nil end
end

local function onRenderOpaqueObjectsInWorld(playerIndex)
    lastRenderEvent[playerIndex] = now()
end

-- Places the current item where the cursor is (vanilla tryBuild -> create -> ISDropWorldItemAction).
local function place(drag)
    local drop = drag.selectedSqDrop
    if not drop or not drag:isValid(drop) then return end
    VF.debug(ID, string.format("place %s at %d,%d,%d offset=%.2f,%.2f,%.2f rot=%s shift=%s",
        tostring(drag.items[1] and drag.items[1]:getFullType()), drop:getX(), drop:getY(), drop:getZ(),
        drag.render3DItemXOffset or -1, drag.render3DItemYOffset or -1, drag.render3DItemZOffset or -1,
        tostring(drag.render3DItemRot), tostring(isShiftKeyDown())))
    drag:tryBuild(drop:getX(), drop:getY(), drop:getZ())
end

local function itemName(drag)
    local item = drag.items[1]
    return item and item:getDisplayName() or "?"
end

-- Viewpoint's interaction menu while the cursor is out: one entry that places the item.
local function cursorMenu(player, drag)
    local playerNum = player:getPlayerNum()
    lastMenu[playerNum] = now()
    local name = getText("UI_ViewpointFixes_PlaceItem", itemName(drag))
    local valid = drag.canBeBuild == true
    ViewpointInteract.actions = {
        { name = name, fn = function() VF.guard(ID, place, drag) end, args = {}, n = 0, enabled = valid },
    }
    return { title = getText("ContextMenu_PlaceItemOnGround"), labels = { name }, enabled = { valid }, seen = 1 }
end

local function onKeyPressed(key)
    if isRotateKey(key) then rotateKey.held = false end
    local playerNum = 0
    local drag = driven[playerNum]
    if not drag or menuShowing(playerNum) or activeCursor(playerNum) ~= drag then return end
    if key == VF.viewpointKey("keys.lootTake", Keyboard.KEY_F) then
        VF.guard(ID, place, drag)
    end
end

-- "Place: Radio  45°  [F] place (Shift: all)", green when it can be placed.
local function drawLabel(playerNum, drag)
    if activeCursor(playerNum) ~= drag then
        driven[playerNum] = nil
        return
    end
    local text = getText("UI_ViewpointFixes_PlaceItem", itemName(drag)) .. "  " ..
        tostring(drag:clamp(drag.render3DItemRot or 0)) .. getText("UI_ViewpointFixes_Degrees")
    if drag.surfacesPossible and #drag.surfacesPossible > 1 then
        text = text .. "  " .. getText("UI_ViewpointFixes_Surface", drag.surfaceSelected, #drag.surfacesPossible)
    end
    local ok = drag.canBeBuild == true
    if ok and not menuShowing(playerNum) then
        text = text .. "  " .. getText("UI_ViewpointFixes_PlaceKeys",
            Keyboard.getKeyName(VF.viewpointKey("keys.lootTake", Keyboard.KEY_F)))
    end
    local r, g, b = ok and 0.4 or 1, ok and 1 or 0.35, ok and 0.4 or 0.35
    getTextManager():DrawStringCentre(UIFont.Medium, getCore():getScreenWidth() / 2,
        getCore():getScreenHeight() / 2 + 40, text, r, g, b, 1)
end

local function onPreUIDraw()
    for playerNum, drag in pairs(driven) do
        if not VF.guard(ID, drawLabel, playerNum, drag) then driven[playerNum] = nil end
    end
end

local function install()
    if VF.vpf003Installed or not ISPlace3DItemCursor then return end
    VF.vpf003Installed = true
    Events.OnDoTileBuilding2.Add(onDoTileBuilding)
    Events.RenderOpaqueObjectsInWorld.Add(onRenderOpaqueObjectsInWorld)
    Events.OnPreUIDraw.Add(onPreUIDraw)
    Events.OnKeyPressed.Add(onKeyPressed)
    Events.OnKeyStartPressed.Add(onRotateKeyDown)
    Events.OnKeyKeepPressed.Add(onRotateKeyDown)

    if ViewpointInteract and ViewpointInteract.harvest then
        local harvest = ViewpointInteract.harvest
        ViewpointInteract.harvest = function(player, object)
            local drag = player and activeCursor(player:getPlayerNum())
            if drag then
                local ok, result = VF.guard(ID, cursorMenu, player, drag)
                if ok and result then return result end
            end
            return harvest(player, object)
        end
        VF.log(ID, "installed (with Viewpoint interaction menu)")
    else
        VF.log(ID, "installed (ViewpointInteract.harvest not found; key fallback only)")
    end
end

Events.OnGameStart.Add(install)
