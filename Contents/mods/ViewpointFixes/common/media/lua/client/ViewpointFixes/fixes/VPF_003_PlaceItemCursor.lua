--[[
VPF-003: inventory "Place item" (ISPlace3DItemCursor, free 3D placement) does nothing with Viewpoint's view on.

Bug:   the place-item mode starts, but the item never follows the aim, can't be rotated, and can't be placed.
Cause: the vanilla cursor does almost all of its work in renderOpaqueObjectsInWorld() (rotation keys, sub-tile
       position from the mouse, surface height, selectedSqDrop, preview). That's only called from
       Events.RenderOpaqueObjectsInWorld, which only FBORenderCell.performRenderTiles fires: the iso world
       render Viewpoint replaces. Like VPF-002, isValid only runs on the render pass and clicks can't be read
       (the left button reads as held under Viewpoint). The preview (Render3DItem) goes to the hidden iso
       renderer, and while Viewpoint's loot menu shows on a container it takes R (take all) and Tab (loot
       window) from the game (LootMenu.keyDown/asks).
Fix:   while that event isn't firing, run the cursor's own renderOpaqueObjectsInWorld each frame from the
       OnPreUIDraw (every frame; OnDoTileBuilding2 only fires once), with screenToIsoX/Y answering the aim point (Viewpoint's
       mouse pick in cursor mode, else the crosshair hit from our Java bridge), isLeftDown cleared (else it locks
       to one square) and Render3DItem skipped. Vanilla then still handles the surface key, offsets and range.
       R / Shift+R go through vanilla handleRotate with the game's key state or the raw keyboard's (Java
       rawKeyDown): Viewpoint hides keys from the game below isKeyDown. The preview is a throwaway copy of the item handed to Viewpoint's world-item drawing (Java,
       Patch_PreviewItem), never added to the world. Viewpoint's loot menu is paused while placing so R and Tab
       reach the cursor; F (Viewpoint's take key) places, Shift+F places all (vanilla). A label shows the
       rotation and whether it can be placed.
Seen:  Viewpoint 0.1.5a-hotfix, game 42.21.
Retire when Viewpoint fires (or replaces) RenderOpaqueObjectsInWorld for placement cursors.
]]
require "ViewpointFixes/ViewpointFixes"
-- ISPlace3DItemCursor lives in the server Lua folder (loads after client files): referenced at runtime only.

local VF = ViewpointFixes
local ID = "VPF_003"

VF.register({ id = ID, label = "UI_ViewpointFixes_VPF003", tooltip = "UI_ViewpointFixes_VPF003_Tooltip" })

local EVENT_STALE_MS = 500 -- RenderOpaqueObjectsInWorld newer than this: vanilla is driving the cursor

local lastRenderEvent = {} -- playerNum -> timestamp of the last RenderOpaqueObjectsInWorld
local placing = {}         -- playerNum -> cursor we're handling (aim or not)
local driven = {}          -- playerNum -> cursor we drove this frame (has a position)
local ghost = {}           -- playerNum -> { source = item, copy = item } shown as the preview
local lootPaused = false
local lastProbe, lastKeyProbe, lastSkip = 0, "", 0

local function now() return getTimestampMs() end

local function isPlaceCursor(drag)
    return type(drag) == "table" and drag.isPlace3DCursor == true
end

local function vanillaIsDriving(playerNum)
    local t = lastRenderEvent[playerNum]
    return t ~= nil and now() - t < EVENT_STALE_MS
end

-- The place-item cursor we should be handling for this player, or nil.
local function activeCursor(playerNum)
    if not VF.isEnabled(ID) or vanillaIsDriving(playerNum) then return nil end
    local drag = getCell():getDrag(playerNum)
    if isPlaceCursor(drag) and drag.items and drag.items[1] then return drag end
    return nil
end

-- The aimed world point: Viewpoint's mouse pick in cursor mode, else the point under the crosshair.
local function pickedPoint()
    local mouse = Viewpoint and Viewpoint.Mouse
    local wx = mouse and mouse.worldX()
    local wy = mouse and mouse.worldY()
    if wx and wy then return wx, wy end
    if ViewpointFixesJava then
        wx, wy = ViewpointFixesJava.aimX(), ViewpointFixesJava.aimY()
        if wx and wy then return wx, wy end
    end
    return nil
end

-- Viewpoint's pick is nil for a few frames while the pointer moves (the preview flickered and was rebuilt each
-- time), so keep the last point for a short grace period.
local AIM_GRACE_MS = 300
local lastAimX, lastAimY, lastAimAt = nil, nil, 0

local function aimPoint()
    local wx, wy = pickedPoint()
    if wx then
        lastAimX, lastAimY, lastAimAt = wx, wy, now()
        return wx, wy
    end
    if lastAimX and now() - lastAimAt < AIM_GRACE_MS then return lastAimX, lastAimY end
    lastAimX = nil
    return nil
end

-- Viewpoint's loot menu takes R and Tab while it shows; pause it while placing, then restore the user's choice.
local function viewpointLootSetting()
    local options = PZAPI and PZAPI.ModOptions and PZAPI.ModOptions:getOptions("Viewpoint")
    local option = options and options:getOption("lootMenu")
    if option then return option:getValue() == true end
    return true
end

local function pauseLoot(paused)
    if paused == lootPaused or not (Viewpoint and Viewpoint.Loot and Viewpoint.Loot.setEnabled) then return end
    lootPaused = paused
    Viewpoint.Loot.setEnabled(not paused and viewpointLootSetting())
    VF.debug(ID, paused and "Viewpoint loot menu paused while placing" or "Viewpoint loot menu restored")
end

-- The preview: a throwaway copy of the item (the world-object constructor rewrites the item it's given).
local function showPreview(playerNum, drag)
    if not ViewpointFixesJava then return end
    local item = drag.items[1]
    local g = ghost[playerNum]
    if not g or g.source ~= item then
        g = { source = item, copy = instanceItem(item:getFullType()) }
        ghost[playerNum] = g
    end
    if not g.copy then return end
    g.copy:setWorldZRotation(drag:clamp(drag.render3DItemRot or 0))
    ViewpointFixesJava.setPreview(g.copy, drag.selectedSqDrop, drag.render3DItemXOffset or 0.5,
        drag.render3DItemYOffset or 0.5, drag.render3DItemZOffset or 0)
end

local function hidePreview(playerNum)
    if ghost[playerNum] and ViewpointFixesJava then ViewpointFixesJava.clearPreview() end
    ghost[playerNum] = nil
end

-- One frame of the vanilla cursor's own logic, aimed where Viewpoint aims.
local function drive(drag, playerNum)
    local player = getSpecificPlayer(playerNum)
    local wx, wy = aimPoint()
    if not (player and wx) then return false end
    local z = math.floor(player:getZ())
    local square = getCell():getGridSquare(math.floor(wx), math.floor(wy), z)

    -- Vanilla checkRotateKey, with the keyboard's own state added: in 3D the game never saw R held (tests 1-3),
    -- even with Viewpoint's loot menu paused. Viewpoint hides keys in KeyboardState.isKeyDown.
    local core = getCore()
    local rotateKey, rotateAlt = core:getKey(KeybindId.ROTATE_BUILDING), core:getAltKey(KeybindId.ROTATE_BUILDING)
    local gameDown, gameShift = isKeyDown(KeybindId.ROTATE_BUILDING), isShiftKeyDown()
    local rawDown, rawShift = false, false
    if ViewpointFixesJava then
        local raw = ViewpointFixesJava.rawKeyDown
        rawDown = raw(rotateKey) or raw(rotateAlt)
        rawShift = raw(Keyboard.KEY_LSHIFT) or raw(Keyboard.KEY_RSHIFT)
    end
    drag.checkRotateKey = function(self)
        if self.chr:getPlayerNum() ~= 0 or self.chr:getJoypadBind() ~= -1 then return end
        self:handleRotate(gameDown or rawDown, gameShift or rawShift)
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
    if not drop then return false end
    drag.canBeBuild = drag:isValid(drop) == true
    driven[playerNum] = drag
    showPreview(playerNum, drag)

    if ViewpointFixesJava then ViewpointFixesJava.setDebug(VF.debugEnabled()) end
    if VF.debugEnabled() then
        local held = {}
        if ViewpointFixesJava then
            for k = 1, 237 do
                if ViewpointFixesJava.rawKeyDown(k) then held[#held + 1] = k end
            end
        end
        local keys = string.format("rotate key %s (%s/%s): game=%s raw=%s shift game=%s raw=%s; raw keys down: %s",
            Keyboard.getKeyName(rotateKey), tostring(rotateKey), tostring(rotateAlt), tostring(gameDown),
            tostring(rawDown), tostring(gameShift), tostring(rawShift), table.concat(held, ","))
        if keys ~= lastKeyProbe then
            lastKeyProbe = keys
            VF.log(ID, keys .. " rot=" .. tostring(drag.render3DItemRot))
        end
        if now() - lastProbe > 1000 then
            lastProbe = now()
            VF.log(ID, string.format("aim=%.2f,%.2f (%s) drop=%d,%d,%d offset=%.2f,%.2f,%.2f rot=%s surface=%s/%d valid=%s",
                wx, wy, (Viewpoint and Viewpoint.Mouse and Viewpoint.Mouse.worldX()) and "mouse" or "crosshair", drop:getX(), drop:getY(), drop:getZ(),
                drag.render3DItemXOffset or -1, drag.render3DItemYOffset or -1, drag.render3DItemZOffset or -1,
                tostring(drag:clamp(drag.render3DItemRot or 0)), tostring(drag.surfaceSelected),
                drag.surfacesPossible and #drag.surfacesPossible or 0, tostring(drag.canBeBuild)))
        end
    end
    return true
end

-- One frame for the player's place cursor. Driven from OnPreUIDraw: the non-render OnDoTileBuilding2 call only
-- came once when the cursor started (test 4 log), so position, rotation and preview never updated.
local function step(playerNum)
    local drag = activeCursor(playerNum)
    if not drag then return end
    placing[playerNum] = drag
    pauseLoot(true)
    local ok, handled = VF.guard(ID, drive, drag, playerNum)
    if not (ok and handled) then
        driven[playerNum] = nil
        hidePreview(playerNum)
        if ok and VF.debugEnabled() and now() - lastSkip > 1000 then
            lastSkip = now()
            VF.log(ID, "place cursor active but no aim point (mouse and crosshair both nil)")
        end
    end
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

local function onKeyPressed(key)
    local drag = driven[0]
    if drag and activeCursor(0) == drag and key == VF.viewpointKey("keys.lootTake", Keyboard.KEY_F) then
        VF.guard(ID, place, drag)
    end
end

-- "Radio  45°  [F] place (Shift: all)", green when it can be placed.
local function drawLabel(drag)
    local text = drag.items[1]:getDisplayName() .. "  " ..
        tostring(drag:clamp(drag.render3DItemRot or 0)) .. getText("UI_ViewpointFixes_Degrees")
    if drag.surfacesPossible and #drag.surfacesPossible > 1 then
        text = text .. "  " .. getText("UI_ViewpointFixes_Surface", drag.surfaceSelected, #drag.surfacesPossible)
    end
    local ok = drag.canBeBuild == true
    if ok then
        text = text .. "  " .. getText("UI_ViewpointFixes_PlaceKeys",
            Keyboard.getKeyName(VF.viewpointKey("keys.lootTake", Keyboard.KEY_F)))
    end
    local r, g, b = ok and 0.4 or 1, ok and 1 or 0.35, ok and 0.4 or 0.35
    getTextManager():DrawStringCentre(UIFont.Medium, getCore():getScreenWidth() / 2,
        getCore():getScreenHeight() / 2 + 40, text, r, g, b, 1)
end

-- Every frame: notice the cursor going away (placed, cancelled, fix switched off) and undo our side effects.
local function onPreUIDraw()
    step(0)
    local any = false
    for playerNum, drag in pairs(placing) do
        if activeCursor(playerNum) ~= drag then
            placing[playerNum], driven[playerNum] = nil, nil
            hidePreview(playerNum)
        else
            any = true
            if driven[playerNum] and not VF.guard(ID, drawLabel, driven[playerNum]) then driven[playerNum] = nil end
        end
    end
    if not any then pauseLoot(false) end
end

local function install()
    if VF.vpf003Installed or not ISPlace3DItemCursor then return end
    VF.vpf003Installed = true
    Events.RenderOpaqueObjectsInWorld.Add(onRenderOpaqueObjectsInWorld)
    Events.OnPreUIDraw.Add(onPreUIDraw)
    Events.OnKeyPressed.Add(onKeyPressed)
    if ViewpointFixesJava then
        VF.log(ID, "installed; java status: " .. tostring(ViewpointFixesJava.status()))
    else
        VF.log(ID, "installed without the Java part (ZombieBuddy approval?): cursor mode only, no preview")
    end
end

Events.OnGameStart.Add(install)
