--[[
VPF-002: furniture pick up / place / rotate cursor (ISMoveableCursor) can't be used with Viewpoint's view on.

Bug:   no usable outline, and nothing can be picked up, placed or rotated. Happens in first and third person.
Cause: 1. The game validates and draws the cursor only from its iso world render
          (IsoCell.DoBuilding(player, true) -> OnDoTileBuilding2(drag, true, ...)), which Viewpoint replaces.
       2. Clicks are read through IsoPlayer:isBuildButtonDown/Released (the Attack binding), and under Viewpoint
          both that and the raw left mouse button (isMouseButtonDown(0)) read as held all the time (seen in
          testing), so a click can never be detected.
       3. The ghost sprite is drawn in iso screen space; isoToScreenX/Y is not 3D-aware under Viewpoint.
       4. ViewpointInteract.harvest deliberately shows no interaction menu while a placement cursor is out.
Fix:   while the game's render calls are missing, drive the cursor ourselves and fill Viewpoint's own
       interaction menu with the cursor's choices (objects to pick up, facings to rotate/place to), so they're
       picked with Viewpoint's scroll + accept, like any other Viewpoint interaction. If Viewpoint shows no menu
       for the target, a label under the crosshair shows the current choice and Viewpoint's loot-take key (F)
       accepts it. Vanilla runs untouched whenever the game's render calls arrive.
Note:  "rotate does nothing" on a table-top item (microwave, radio…) sitting on a table with a facing is vanilla
       design, not this bug: placeMoveableInternal snaps IsTableTop items to the table's Facing. Rotating a
       container with items in it is also refused by vanilla (canCreate=false, entry greyed out).
Seen:  Viewpoint 0.1.5a-hotfix, game 42.21. Verified in game 2026-10-05: pick up, place and rotate all work.
Retire when Viewpoint handles placement cursors itself.
]]
require "ViewpointFixes/ViewpointFixes"
-- ISMoveableCursor lives in the server Lua folder, which loads after client files,
-- so it is only referenced at runtime (from OnGameStart on).

local VF = ViewpointFixes
local ID = "VPF_002"

VF.register({ id = ID, label = "UI_ViewpointFixes_VPF002", tooltip = "UI_ViewpointFixes_VPF002_Tooltip" })

-- Render calls newer than this mean the game is drawing the cursor itself, so we stay out of the way.
local RENDER_STALE_MS = 500
-- Viewpoint's menu counts as showing if it asked us for entries this recently.
local MENU_FRESH_MS = 300

local lastRenderCall = {} -- playerNum -> timestamp of the last isRender=true call
local lastMenu = {}       -- playerNum -> timestamp Viewpoint last asked for menu entries during a takeover
local target = {}         -- playerNum -> { drag, x, y, z } the cursor is on (fallback path)
local lastProbe = {}

local function now() return getTimestampMs() end

local function probe(key, fmt, ...)
    if not VF.debugEnabled() then return end
    if lastProbe[key] and now() - lastProbe[key] < 1000 then return end
    lastProbe[key] = now()
    VF.log(ID, string.format(fmt, ...))
end

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
    return t ~= nil and now() - t < RENDER_STALE_MS
end

local function menuShowing(playerNum)
    return lastMenu[playerNum] ~= nil and now() - lastMenu[playerNum] < MENU_FRESH_MS
end

-- The moveable cursor we should be driving for this player, or nil.
local function activeCursor(playerNum)
    if not VF.isEnabled(ID) or vanillaIsRendering(playerNum) then return nil end
    local drag = getCell():getDrag(playerNum)
    if drag and isMoveableCursor(drag) then return drag end
    return nil
end

local function squareAt(x, y, z)
    local square = getCell():getGridSquare(x, y, z)
    if not square and getWorld():isValidSquare(x, y, z) then
        square = getCell():createNewGridSquare(x, y, z, true)
    end
    return square
end

-- Viewpoint's 3D mouse point (the same one its ISCoordConversion.ToWorld wrap uses), else the tile in
-- front of the player.
local function aimedTile(player)
    local z = math.floor(player:getZ())
    local mouse = Viewpoint and Viewpoint.Mouse
    local wx = mouse and mouse.worldX()
    local wy = mouse and mouse.worldY()
    if wx and wy then return math.floor(wx), math.floor(wy), z end
    local dir = player:getForwardDirection()
    return math.floor(player:getX() + dir:getX()), math.floor(player:getY() + dir:getY()), z
end

local function modeTitle(mode)
    for i, tag in ipairs(ISMoveableCursor.modes.tags) do
        if tag == mode then return ISMoveableCursor.modes.titles[i] end
    end
    return tostring(mode)
end

local function facingOf(props)
    if props and props.sprite then
        return props:getFaceDirectionFromSpriteName(props.sprite:getName())
    end
    return nil
end

-- Re-validates the cursor on a square and, if the game allows it, starts the action (walk there, then the
-- vanilla ISMoveablesAction). `choose` sets which option (object or facing) is used.
local function perform(drag, square, choose)
    -- isValid resets the chosen object/facing when the square changes, so settle on the square first.
    drag:isValid(square, drag.north)
    choose(drag)
    drag.isLeftDown, drag.build = false, false
    drag.canBeBuild = drag:isValid(square, drag.north) == true
    if drag.canBeBuild and drag.canCreate then
        drag:tryBuild(square:getX(), square:getY(), square:getZ())
    end
    VF.debug(ID, string.format("perform mode=%s at %d,%d,%d canBeBuild=%s canCreate=%s",
        tostring(ISMoveableCursor.mode[drag.player]), square:getX(), square:getY(), square:getZ(),
        tostring(drag.canBeBuild), tostring(drag.canCreate)))
end

-- The cursor's choices on a square, as { name, choose, enabled, current }. Each choice is evaluated with the
-- game's own isValid, then the cursor is put back on its original choice.
local function choices(drag, square)
    local mode = ISMoveableCursor.mode[drag.player]
    local list = {}
    local savedIndex, savedFacing = drag.objectIndex, drag.cursorFacing
    drag:isValid(square, drag.north) -- fills objectListCache / origMoveProps for this square

    local function add(choose, current)
        choose(drag)
        drag:isValid(square, drag.north)
        local props = drag.currentMoveProps
        if props then
            local name = props.name or modeTitle(mode)
            local facing = facingOf(props)
            if facing and (mode == "rotate" or mode == "place") then
                name = name .. " " .. getText("UI_ViewpointFixes_Facing", tostring(facing))
            end
            if current then name = name .. " " .. getText("UI_ViewpointFixes_Current") end
            table.insert(list, { name = name, choose = choose, enabled = drag.canCreate == true and not current })
        end
    end

    if mode == "rotate" then
        local props = drag.origMoveProps
        local faces = props and props:hasFaces() and props:getIndexedFaces() or {}
        local currentFace = props and props.getFaceIndex and props:getFaceIndex()
        for i = 1, #faces do
            add(function(d) d.objectIndex, d.cursorFacing = i, nil end, i == currentFace)
        end
    elseif mode == "place" then
        local props = drag.origMoveProps
        local faces = props and props:hasFaces() and props:getIndexedFaces() or {}
        if #faces > 0 then
            for i = 1, #faces do add(function(d) d.cursorFacing = i end) end
        else
            add(function(d) d.cursorFacing = nil end)
        end
    else -- pickup, scrap, repair: one entry per object on the square
        local objects = drag.objectListCache
        local count = type(objects) == "table" and #objects or 0
        for i = 1, count do add(function(d) d.objectIndex = i end) end
    end

    drag.objectIndex, drag.cursorFacing = savedIndex, savedFacing
    drag:isValid(square, drag.north)
    return list
end

-- Builds the result Viewpoint's interaction menu expects from ViewpointInteract.harvest, and the matching
-- ViewpointInteract.actions that ViewpointInteract.run executes.
local function cursorMenu(player, object, drag)
    local playerNum = player:getPlayerNum()
    local square = object and object.getSquare and object:getSquare()
    if not square then
        local x, y, z = aimedTile(player)
        square = squareAt(x, y, z)
    end
    if not square then return nil end
    lastMenu[playerNum] = now()

    local actions, labels, enabled = {}, {}, {}
    for _, c in ipairs(choices(drag, square)) do
        local choose = c.choose
        table.insert(actions, { name = c.name, fn = function() perform(drag, square, choose) end,
                                args = {}, n = 0, enabled = c.enabled })
        table.insert(labels, c.name)
        table.insert(enabled, c.enabled)
    end
    ViewpointInteract.actions = actions
    probe("menu", "menu mode=%s square=%d,%d,%d entries=%d", tostring(ISMoveableCursor.mode[playerNum]),
        square:getX(), square:getY(), square:getZ(), #actions)
    if #actions == 0 then return { why = "nothing for this cursor here" } end
    return { title = modeTitle(ISMoveableCursor.mode[playerNum]), labels = labels, enabled = enabled,
             seen = #actions }
end

-- The game's non-render cursor call. While we're driving the cursor, keep it on the aimed tile and stop
-- vanilla's (stuck) button handling from running.
local function onDoTileBuilding(drag, isRender, x, y, z, square)
    local playerNum = drag.player or 0
    if isRender then
        lastRenderCall[playerNum] = now()
        target[playerNum] = nil
    elseif activeCursor(playerNum) == drag then
        -- Viewpoint's menu owns the cursor's square while it's showing.
        if menuShowing(playerNum) then return end
        local ok = VF.guard(ID, function()
            local player = getSpecificPlayer(playerNum)
            local tx, ty, tz = aimedTile(player)
            local sq = squareAt(tx, ty, tz)
            drag.isLeftDown, drag.build, drag.square = false, false, sq
            drag.canBeBuild = sq ~= nil and drag:isValid(sq, drag.north) == true
            target[playerNum] = sq and { drag = drag, square = sq } or nil
        end)
        if ok then return end
        target[playerNum] = nil
    end
    return DoTileBuilding(drag, isRender, x, y, z, square)
end

-- Viewpoint's "take" key (F by default). Looked up once from Viewpoint's own keybind list, using only ids it
-- reports itself: the game logs Java exceptions even inside pcall, so we never guess an id.
local cachedAcceptKey
local function acceptKey()
    if cachedAcceptKey then return cachedAcceptKey end
    cachedAcceptKey = Keyboard.KEY_F
    local keys = Viewpoint and Viewpoint.Keys
    if not (keys and keys.count and keys.id and keys.get and keys.trigger) then return cachedAcceptKey end
    local ids = {}
    for i = 0, keys.count() - 1 do
        local id = tostring(keys.id(i))
        table.insert(ids, id)
        local lower = string.lower(id)
        if string.find(lower, "take", 1, true) and not string.find(lower, "all", 1, true) then
            local code = keys.trigger(keys.get(id))
            if type(code) == "number" and code > 0 then cachedAcceptKey = code end
        end
    end
    VF.debug(ID, "Viewpoint key ids: " .. table.concat(ids, ", ") .. "; accept key " ..
        Keyboard.getKeyName(cachedAcceptKey))
    return cachedAcceptKey
end

-- Fallback when Viewpoint shows no menu for the target: the key accepts the cursor's current choice.
local function onKeyPressed(key)
    local playerNum = 0
    local t = target[playerNum]
    if not t or key ~= acceptKey() or menuShowing(playerNum) then return end
    if activeCursor(playerNum) ~= t.drag then return end
    VF.guard(ID, perform, t.drag, t.square, function() end)
end

-- Fallback label, only while Viewpoint's menu isn't showing.
local function drawLabel(playerNum, t)
    if activeCursor(playerNum) ~= t.drag or menuShowing(playerNum) then return end
    local drag = t.drag
    local mode = ISMoveableCursor.mode[playerNum]
    local props = drag.currentMoveProps
    local text = modeTitle(mode)
    if props and props.name then text = text .. ": " .. props.name end
    local facing = facingOf(props)
    if facing and (mode == "place" or mode == "rotate") then
        text = text .. " " .. getText("UI_ViewpointFixes_Facing", tostring(facing))
    end
    local ok = drag.canBeBuild == true and drag.canCreate == true
    if ok then text = text .. "  " .. getText("UI_ViewpointFixes_Accept", Keyboard.getKeyName(acceptKey())) end
    local r, g, b = ok and 0.4 or 1, ok and 1 or 0.35, ok and 0.4 or 0.35
    getTextManager():DrawStringCentre(UIFont.Medium, getCore():getScreenWidth() / 2,
        getCore():getScreenHeight() / 2 + 40, text, r, g, b, 1)
end

local function onPreUIDraw()
    for playerNum, t in pairs(target) do
        if not VF.guard(ID, drawLabel, playerNum, t) then target[playerNum] = nil end
    end
end

local function install()
    if VF.vpf002Installed or not DoTileBuilding then return end
    VF.vpf002Installed = true

    -- Vanilla registers DoTileBuilding directly on the event, so swap our handler in for it.
    Events.OnDoTileBuilding2.Remove(DoTileBuilding)
    Events.OnDoTileBuilding2.Add(onDoTileBuilding)
    Events.OnPreUIDraw.Add(onPreUIDraw)
    Events.OnKeyPressed.Add(onKeyPressed)

    if ViewpointInteract and ViewpointInteract.harvest then
        local harvest = ViewpointInteract.harvest
        ViewpointInteract.harvest = function(player, object)
            local drag = player and activeCursor(player:getPlayerNum())
            if drag then
                local ok, result = VF.guard(ID, cursorMenu, player, object, drag)
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
