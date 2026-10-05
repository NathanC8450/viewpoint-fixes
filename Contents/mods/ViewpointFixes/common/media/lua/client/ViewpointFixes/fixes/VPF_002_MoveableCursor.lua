--[[
VPF-002: furniture pick up / place / rotate cursor (ISMoveableCursor) does nothing with Viewpoint's view on.

Bug:   no tile outline, and clicks never pick up, place or rotate. Happens in first and third person.
Cause: 1. The game validates and draws the cursor only from its iso world render, via
          IsoCell.DoBuilding(player, true) -> OnDoTileBuilding2(drag, true, ...). Viewpoint replaces that
          render, so only UIManager.update's DoBuilding(0, false) arrives, and canBeBuild is never set.
       2. Vanilla reads clicks through IsoPlayer:isBuildButtonDown/Released, i.e. the Attack binding
          "in world". Under Viewpoint it reads as held the whole time (seen in testing), so a release
          never comes, and the held state pins the cursor to one square.
       3. The ghost sprite and rotate arrow are drawn in iso screen space; isoToScreenX/Y is not 3D-aware
          under Viewpoint (seen in testing), so they can't be shown in the 3D view.
Fix:   while render calls are missing, handle the cursor ourselves: tile from Viewpoint's 3D mouse point
       (else the tile in front of the player), vanilla isValid for it, our own click detection on the raw
       left mouse button, then vanilla tryBuild. A label under the crosshair names the mode, object, facing
       and whether it can be done. Vanilla runs untouched whenever render calls arrive.
Seen:  Viewpoint 0.1.5a-hotfix, game 42.21.
Retire when Viewpoint drives DoBuilding's render pass and build-button input itself.
]]
require "ViewpointFixes/ViewpointFixes"
-- ISMoveableCursor lives in the server Lua folder, which loads after client files,
-- so it is only referenced at runtime (from OnGameStart on).

local VF = ViewpointFixes
local ID = "VPF_002"

VF.register({ id = ID, label = "UI_ViewpointFixes_VPF002", tooltip = "UI_ViewpointFixes_VPF002_Tooltip" })

-- Render calls newer than this mean the game is drawing the cursor itself, so we stay out of the way.
local RENDER_STALE_MS = 500

local lastRenderCall = {} -- playerNum -> timestamp of the last isRender=true call
local shown = {}          -- playerNum -> drag to label this frame
local wasDown = {}        -- playerNum -> left button state last frame
local pressedOn = {}      -- playerNum -> drag that was active when the button went down
local lastProbe = 0

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

-- Same test vanilla's ISMoveableCursor uses to ignore clicks on UI.
local function mouseOverUI()
    local uis = UIManager.getUI()
    for i = 1, uis:size() do
        if uis:get(i - 1):isMouseOver() then return true end
    end
    return false
end

-- Viewpoint's 3D mouse point (the same one its ISCoordConversion.ToWorld wrap uses). Falls back to
-- the tile in front of the player when Viewpoint doesn't offer one.
local function targetTile(player)
    local z = math.floor(player:getZ())
    local mouse = Viewpoint and Viewpoint.Mouse
    local wx = mouse and mouse.worldX()
    local wy = mouse and mouse.worldY()
    if wx and wy then return math.floor(wx), math.floor(wy), z, "viewpoint" end
    local dir = player:getForwardDirection()
    return math.floor(player:getX() + dir:getX()), math.floor(player:getY() + dir:getY()), z, "facing"
end

local function probe(player, drag, playerNum, tx, ty, tz, source, down, clicked, overUI)
    if not VF.debugEnabled() then return end
    local now = getTimestampMs()
    if not clicked and now - lastProbe < 1000 then return end
    lastProbe = now
    VF.log(ID, string.format(
        "mode=%s source=%s tile=%d,%d,%d canBeBuild=%s canCreate=%s rawDown=%s attackDown=%s clicked=%s overUI=%s",
        tostring(ISMoveableCursor.mode[playerNum]), source, tx, ty, tz, tostring(drag.canBeBuild),
        tostring(drag.canCreate), tostring(down), tostring(player:isBuildButtonDown()), tostring(clicked),
        tostring(overUI)))
end

local function takeOver(drag, playerNum)
    local player = getSpecificPlayer(playerNum)
    if not player then return false end
    local tx, ty, tz, source = targetTile(player)
    local square = getCell():getGridSquare(tx, ty, tz)
    if not square and getWorld():isValidSquare(tx, ty, tz) then
        square = getCell():createNewGridSquare(tx, ty, tz, true)
    end

    -- Vanilla state that its own (stuck) button handling would otherwise drive.
    drag.isLeftDown = false
    drag.build = false
    drag.square = square
    drag.canBeBuild = square ~= nil and drag:isValid(square, drag.north) == true
    if square then drag.renderX, drag.renderY, drag.renderZ = tx, ty, tz end
    shown[playerNum] = drag

    -- A click is a press and release of the left button that both happen while this cursor is out,
    -- so the click that chose "Pick up" in a menu doesn't count.
    local down = isMouseButtonDown(0)
    if down and not wasDown[playerNum] then pressedOn[playerNum] = drag end
    local clicked = wasDown[playerNum] and not down and pressedOn[playerNum] == drag
    wasDown[playerNum] = down
    local overUI = clicked and mouseOverUI()

    probe(player, drag, playerNum, tx, ty, tz, source, down, clicked, overUI)
    if clicked and not overUI and drag.canBeBuild then
        drag:tryBuild(tx, ty, tz)
    end
    return true
end

local function onDoTileBuilding(drag, isRender, x, y, z, square)
    local playerNum = drag.player or 0
    if isRender then
        lastRenderCall[playerNum] = getTimestampMs()
        shown[playerNum] = nil
    elseif VF.isEnabled(ID) and isMoveableCursor(drag) and not vanillaIsRendering(playerNum) then
        local ok, handled = VF.guard(ID, takeOver, drag, playerNum)
        if ok and handled then return end
        shown[playerNum] = nil
    end
    return DoTileBuilding(drag, isRender, x, y, z, square)
end

local function modeTitle(mode)
    for i, tag in ipairs(ISMoveableCursor.modes.tags) do
        if tag == mode then return ISMoveableCursor.modes.titles[i] end
    end
    return tostring(mode)
end

-- "Rotate: Wooden Chair (facing N)", green when it can be done, red when not.
local function drawLabel(playerNum, drag)
    if getCell():getDrag(playerNum) ~= drag then
        shown[playerNum] = nil
        return
    end
    local mode = ISMoveableCursor.mode[playerNum]
    local props = drag.currentMoveProps
    local text = modeTitle(mode)
    if props and props.name then text = text .. ": " .. props.name end
    if props and props.sprite and (mode == "place" or mode == "rotate") then
        local facing = props:getFaceDirectionFromSpriteName(props.sprite:getName())
        if facing then text = text .. " (facing " .. tostring(facing) .. ")" end
    end
    local ok = drag.canBeBuild == true and drag.canCreate ~= false
    local r, g, b = ok and 0.4 or 1, ok and 1 or 0.35, ok and 0.4 or 0.35
    getTextManager():DrawStringCentre(UIFont.Medium, getCore():getScreenWidth() / 2,
        getCore():getScreenHeight() / 2 + 40, text, r, g, b, 1)
end

local function onPreUIDraw()
    for playerNum, drag in pairs(shown) do
        if not VF.guard(ID, drawLabel, playerNum, drag) then shown[playerNum] = nil end
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
