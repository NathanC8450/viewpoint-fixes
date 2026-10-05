--[[
VPF-002: furniture pick up / place / rotate cursor (ISMoveableCursor) does nothing with Viewpoint's view on.

Bug:   no tile outline, and clicks never pick up, place or rotate. Happens in first and third person.
Cause: the game validates and draws the cursor only from its iso world render, via
       IsoCell.DoBuilding(player, true) -> OnDoTileBuilding2(drag, true, ...). Viewpoint replaces that render,
       so only UIManager.update's DoBuilding(0, false) arrives. Vanilla DoTileBuilding sets canBeBuild only
       on render calls, so tryBuild never runs, and its tile comes from the iso screen->tile mapping.
Fix:   when render calls stop arriving, take over the non-render call. Pick the tile from Viewpoint's
       3D mouse point (or the tile in front of the player), validate it, and draw our own marker.
       Vanilla runs untouched whenever render calls arrive (iso view, or if Viewpoint fixes this itself).
Seen:  Viewpoint 0.1.5a-hotfix, game 42.21.
Retire when Viewpoint drives DoBuilding's render pass (or validation) itself.
]]
require "ViewpointFixes/ViewpointFixes"
-- ISMoveableCursor and DoTileBuilding live in the server Lua folder, which loads after client files,
-- so they are only referenced at runtime (from OnGameStart on).

local VF = ViewpointFixes
local ID = "VPF_002"

VF.register({ id = ID, label = "UI_ViewpointFixes_VPF002", tooltip = "UI_ViewpointFixes_VPF002_Tooltip" })

-- Render calls newer than this mean the game is drawing the cursor itself, so we stay out of the way.
local RENDER_STALE_MS = 500

local lastRenderCall = {} -- playerNum -> timestamp of the last isRender=true call
local shown = {}          -- playerNum -> what to draw this frame
local lastProbe = 0

local function noRotateMouse() end

local function isMoveableCursor(drag)
    local mt = getmetatable(drag)
    while mt do
        if mt == ISMoveableCursor then return true end
        mt = getmetatable(mt)
    end
    return false
end

local function vanillaIsRendering(playerNum)
    local t = lastRenderCall[playerNum]
    return t ~= nil and getTimestampMs() - t < RENDER_STALE_MS
end

-- Viewpoint's 3D mouse point (the same one its ISCoordConversion.ToWorld wrap uses). Falls back to
-- the tile in front of the player when Viewpoint doesn't offer one.
local function targetTile(player)
    local z = math.floor(player:getZ())
    local mouse = Viewpoint and Viewpoint.Mouse
    local wx = mouse and mouse.worldX()
    local wy = mouse and mouse.worldY()
    if wx and wy then return math.floor(wx), math.floor(wy), z, "viewpoint", wx, wy end
    local dir = player:getForwardDirection()
    return math.floor(player:getX() + dir:getX()), math.floor(player:getY() + dir:getY()), z, "facing"
end

local function probe(playerNum, player, drag, tx, ty, tz, source, wx, wy)
    if not VF.debugEnabled() then return end
    local now = getTimestampMs()
    if now - lastProbe < 1000 then return end
    lastProbe = now
    VF.log(ID, string.format(
        "mode=%s source=%s tile=%d,%d,%d viewpointMouse=%s,%s player=%.2f,%.2f,%.2f mouse=%d,%d " ..
        "screenOfTile=%.0f,%.0f canBeBuild=%s canCreate=%s buttonDown=%s",
        tostring(ISMoveableCursor.mode[playerNum]), source, tx, ty, tz, tostring(wx), tostring(wy),
        player:getX(), player:getY(), player:getZ(), getMouseX(), getMouseY(),
        isoToScreenX(playerNum, tx + 0.5, ty + 0.5, tz), isoToScreenY(playerNum, tx + 0.5, ty + 0.5, tz),
        tostring(drag.canBeBuild), tostring(drag.canCreate), tostring(player:isBuildButtonDown())))
end

local function takeOver(drag, playerNum)
    local player = getSpecificPlayer(playerNum)
    if not player then return false end
    local tx, ty, tz, source, wx, wy = targetTile(player)
    local square = getCell():getGridSquare(tx, ty, tz)
    if not square and getWorld():isValidSquare(tx, ty, tz) then
        square = getCell():createNewGridSquare(tx, ty, tz, true)
    end

    -- Dragging the mouse to rotate maps the 2D mouse onto the iso grid, which is meaningless in 3D.
    -- The rotate key still works.
    drag.rotateMouse = noRotateMouse

    -- What vanilla's render pass would have done: validate the square DoTileBuilding will use
    -- (it keeps the clicked square while the button is held).
    local check = ((drag.isLeftDown or drag.build) and drag.square) or square
    drag.canBeBuild = check ~= nil and drag:isValid(check, drag.north) == true
    if check then
        drag.renderX, drag.renderY, drag.renderZ = check:getX(), check:getY(), check:getZ()
    end
    shown[playerNum] = check and { x = check:getX(), y = check:getY(), z = check:getZ(), drag = drag } or nil

    probe(playerNum, player, drag, tx, ty, tz, source, wx, wy)
    -- The non-render call reads the mouse button and runs tryBuild when canBeBuild is set.
    DoTileBuilding(drag, false, tx, ty, tz, square)
    return true
end

local function onDoTileBuilding(drag, isRender, x, y, z, square)
    local playerNum = drag.player or 0
    if isRender then
        lastRenderCall[playerNum] = getTimestampMs()
        shown[playerNum] = nil
        if drag.rotateMouse == noRotateMouse then drag.rotateMouse = nil end
    elseif VF.isEnabled(ID) and isMoveableCursor(drag) and not vanillaIsRendering(playerNum) then
        local ok, handled = VF.guard(ID, takeOver, drag, playerNum)
        if ok and handled then return end
        shown[playerNum] = nil
        if drag.rotateMouse == noRotateMouse then drag.rotateMouse = nil end
    end
    return DoTileBuilding(drag, isRender, x, y, z, square)
end

-- Screen-space feedback: the tile projected to the screen, and a label under the crosshair.
local function drawMarker(playerNum, s)
    local drag = s.drag
    if getCell():getDrag(playerNum) ~= drag then
        shown[playerNum] = nil
        return
    end
    local valid = drag.canBeBuild == true
    local r, g, b = valid and 0.3 or 1, valid and 1 or 0.25, valid and 0.3 or 0.25
    local renderer = getRenderer()
    local function sx(x, y) return isoToScreenX(playerNum, x, y, s.z) end
    local function sy(x, y) return isoToScreenY(playerNum, x, y, s.z) end
    local x, y = s.x, s.y
    renderer:renderPoly(sx(x, y), sy(x, y), sx(x + 1, y), sy(x + 1, y),
        sx(x + 1, y + 1), sy(x + 1, y + 1), sx(x, y + 1), sy(x, y + 1), r, g, b, 0.35)

    local mode = ISMoveableCursor.mode[playerNum]
    local title = mode
    for i, tag in ipairs(ISMoveableCursor.modes.tags) do
        if tag == mode then title = ISMoveableCursor.modes.titles[i] end
    end
    local text = tostring(title)
    if drag.currentMoveProps and drag.currentMoveProps.name then
        text = text .. ": " .. drag.currentMoveProps.name
    end
    getTextManager():DrawStringCentre(UIFont.Medium, getCore():getScreenWidth() / 2,
        getCore():getScreenHeight() / 2 + 40, text, r, g, b, 1)
end

local function onPreUIDraw()
    for playerNum, s in pairs(shown) do
        if not VF.guard(ID, drawMarker, playerNum, s) then shown[playerNum] = nil end
    end
end

-- Vanilla registers DoTileBuilding directly on the event, so swap our handler in for it.
local function install()
    if VF.vpf002Installed or not DoTileBuilding then return end
    VF.vpf002Installed = true
    Events.OnDoTileBuilding2.Remove(DoTileBuilding)
    Events.OnDoTileBuilding2.Add(onDoTileBuilding)
    Events.OnPreUIDraw.Add(onPreUIDraw)
    VF.log(ID, "installed")
end

Events.OnGameStart.Add(install)
