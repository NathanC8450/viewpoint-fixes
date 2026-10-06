-- Shared plumbing for every fix (Viewpoint itself is only touched through Adapter.lua): registration, the Mod Options page (one player-facing option: the placement
-- helper text), logging, and an error guard that switches a misbehaving fix off instead of breaking the game.
ViewpointFixes = ViewpointFixes or { fixes = {}, order = {} }
local VF = ViewpointFixes

VF.ID = "ViewpointFixes"

function VF.log(fixId, msg)
    print("[ViewpointFixes] " .. (fixId and (fixId .. ": ") or "") .. tostring(msg))
end

-- Debug logging follows the game's own -debug launch flag; there's no option for players to wade through.
function VF.debugEnabled()
    return isDebugEnabled() == true
end

-- The "placement helper text" option (off by default): item name, rotation and key hints drawn on screen.
function VF.helperTextEnabled()
    return VF.helperOption ~= nil and VF.helperOption:getValue() == true
end

function VF.now() return getTimestampMs() end

function VF.debug(fixId, msg)
    if VF.debugEnabled() then VF.log(fixId, msg) end
end

-- fix = { id = "VPF_002" }. Fixes are always on; one that errors switches itself off for the session (guard).
function VF.register(fix)
    if VF.fixes[fix.id] then return VF.fixes[fix.id] end
    fix.failed = false
    VF.fixes[fix.id] = fix
    table.insert(VF.order, fix)
    return fix
end

-- True when the fix exists and hasn't failed this session.
function VF.isEnabled(id)
    local fix = VF.fixes[id]
    if not fix or fix.failed then return false end
    return true
end

-- Calls fn(...) under pcall. On error the fix is switched off for the session and the error logged once.
-- Returns ok, then fn's first two results.
function VF.guard(id, fn, ...)
    local ok, a, b = pcall(fn, ...)
    if ok then return true, a, b end
    local fix = VF.fixes[id]
    if fix and not fix.failed then
        fix.failed = true
        VF.log(id, "switched off for this session after an error: " .. tostring(a))
    end
    return false
end

-- One line of helper text under the crosshair, green when `ok`, red otherwise. Drawn only when the player has
-- ticked the helper-text option.
function VF.drawHelperText(text, ok)
    if not VF.helperTextEnabled() then return end
    local r, g, b = ok and 0.4 or 1, ok and 1 or 0.35, ok and 0.4 or 0.35
    getTextManager():DrawStringCentre(UIFont.Medium, getCore():getScreenWidth() / 2,
        getCore():getScreenHeight() / 2 + 40, text, r, g, b, 1)
end

local function installOptions()
    if VF.page or not (PZAPI and PZAPI.ModOptions) then return end
    VF.page = PZAPI.ModOptions:create(VF.ID, getText("UI_ViewpointFixes_Page"))
    VF.page:addDescription("UI_ViewpointFixes_Description")
    VF.helperOption = VF.page:addTickBox("helperText", getText("UI_ViewpointFixes_HelperText"), false,
        getText("UI_ViewpointFixes_HelperText_Tooltip"))
    PZAPI.ModOptions:load()
end

Events.OnGameBoot.Add(installOptions)
-- Saved values are only read when the options screen is built, so read them again on entering a game.
Events.OnGameStart.Add(function() if VF.page then PZAPI.ModOptions:load() end end)
