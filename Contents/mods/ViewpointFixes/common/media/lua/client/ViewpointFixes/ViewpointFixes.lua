-- Shared plumbing for every fix: registration, one toggle per fix on the Mod Options page,
-- logging, and an error guard that switches a misbehaving fix off instead of breaking the game.
ViewpointFixes = ViewpointFixes or { fixes = {}, order = {} }
local VF = ViewpointFixes

VF.ID = "ViewpointFixes"

function VF.log(fixId, msg)
    print("[ViewpointFixes] " .. (fixId and (fixId .. ": ") or "") .. tostring(msg))
end

function VF.debugEnabled()
    return VF.debugOption ~= nil and VF.debugOption:getValue() == true
end

function VF.debug(fixId, msg)
    if VF.debugEnabled() then VF.log(fixId, msg) end
end

local function addOption(fix)
    fix.option = VF.page:addTickBox(fix.id, getText(fix.label), fix.default ~= false, getText(fix.tooltip))
end

-- fix = { id = "VPF_002", label = "<translation key>", tooltip = "<translation key>", default = true }
function VF.register(fix)
    if VF.fixes[fix.id] then return VF.fixes[fix.id] end
    fix.failed = false
    VF.fixes[fix.id] = fix
    table.insert(VF.order, fix)
    if VF.page then addOption(fix) end
    return fix
end

-- True when the fix exists, is ticked, and hasn't failed this session.
function VF.isEnabled(id)
    local fix = VF.fixes[id]
    if not fix or fix.failed then return false end
    if fix.option then return fix.option:getValue() == true end
    return fix.default ~= false
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

local function installOptions()
    if VF.page or not (PZAPI and PZAPI.ModOptions) then return end
    VF.page = PZAPI.ModOptions:create(VF.ID, getText("UI_ViewpointFixes_Page"))
    VF.page:addDescription("UI_ViewpointFixes_Description")
    for _, fix in ipairs(VF.order) do addOption(fix) end
    VF.page:addSeparator()
    VF.debugOption = VF.page:addTickBox("debug", getText("UI_ViewpointFixes_Debug"), false,
        getText("UI_ViewpointFixes_Debug_Tooltip"))
    PZAPI.ModOptions:load()
end

Events.OnGameBoot.Add(installOptions)
-- Saved values are only read when the options screen is built, so read them again on entering a game.
Events.OnGameStart.Add(function() if VF.page then PZAPI.ModOptions:load() end end)
