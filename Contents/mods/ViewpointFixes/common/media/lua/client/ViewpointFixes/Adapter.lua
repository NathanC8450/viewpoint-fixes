--[[
The only place the fixes touch Project Viewpoint (its Lua globals and Mod Options) and our own Java part. Everything
is reached by name at runtime, so a missing or changed Viewpoint makes these functions return nil/false instead of
breaking the game.

If Viewpoint adopts a fix, this is the seam: the fix's logic stays, and the calls below become direct calls into
Viewpoint (or disappear, when Viewpoint handles the case itself). Fixes must not read `Viewpoint*` globals or
`ViewpointFixesJava` directly.
]]
require "ViewpointFixes/ViewpointFixes"

local VF = ViewpointFixes
local A = VF.Adapter or {}
VF.Adapter = A

local function point(x, y)
    if x and y then return x, y end
    return nil
end

-- ---- our Java part (nil when ZombieBuddy hasn't approved the jar) ----

function A.hasJava() return ViewpointFixesJava ~= nil end

function A.javaStatus() return ViewpointFixesJava and ViewpointFixesJava.status() or nil end

-- The keyboard's own state for a key code, below Viewpoint's hiding of keys from the game.
function A.rawKeyDown(code)
    return ViewpointFixesJava ~= nil and ViewpointFixesJava.rawKeyDown(code) == true
end

-- Shows a throwaway item at square + offsets in Viewpoint's world-item drawing until clearPreview.
function A.setPreview(item, square, xoff, yoff, zoff)
    return ViewpointFixesJava ~= nil and ViewpointFixesJava.setPreview(item, square, xoff, yoff, zoff) == true
end

function A.clearPreview()
    if ViewpointFixesJava then ViewpointFixesJava.clearPreview() end
end

-- ---- where the player is aiming (world tile coordinates, or nil) ----

-- Viewpoint's Lua mouse pick (cursor mode, only while the pointer is still).
function A.mousePoint()
    local mouse = Viewpoint and Viewpoint.Mouse
    if not mouse then return nil end
    return point(mouse.worldX(), mouse.worldY())
end

-- Viewpoint's latest cursor pick, read from Java; also valid while the pointer moves.
function A.cursorPoint()
    if not ViewpointFixesJava then return nil end
    return point(ViewpointFixesJava.cursorX(), ViewpointFixesJava.cursorY())
end

-- The point under Viewpoint's crosshair (crosshair mode).
function A.crosshairPoint()
    if not ViewpointFixesJava then return nil end
    return point(ViewpointFixesJava.aimX(), ViewpointFixesJava.aimY())
end

-- Best available aim: mouse pick, then the latest cursor pick, then the crosshair.
function A.aimPoint()
    local x, y = A.mousePoint()
    if x then return x, y end
    x, y = A.cursorPoint()
    if x then return x, y end
    return A.crosshairPoint()
end

-- ---- Viewpoint's keys ----

-- Key code bound to one of Viewpoint's keybinds (ids look like "keys.lootTake"), or `default`.
-- Only ids that Viewpoint itself lists are queried: the game logs Java exceptions even inside pcall.
local keyCache = {}
function A.key(id, default)
    if keyCache[id] then return keyCache[id] end
    local code = default
    local keys = Viewpoint and Viewpoint.Keys
    if keys and keys.count and keys.id and keys.get and keys.trigger then
        for i = 0, keys.count() - 1 do
            if tostring(keys.id(i)) == id then
                local c = keys.trigger(keys.get(id))
                if type(c) == "number" and c > 0 then code = c end
                break
            end
        end
    end
    keyCache[id] = code
    return code
end

-- Viewpoint's take / accept key (F by default).
function A.acceptKey()
    return A.key("keys.lootTake", Keyboard.KEY_F)
end

-- ---- Viewpoint's loot menu (it takes R, Tab and F while it shows) ----

function A.canSetLootMenu()
    return Viewpoint ~= nil and Viewpoint.Loot ~= nil and Viewpoint.Loot.setEnabled ~= nil
end

-- The player's own loot-menu setting (true when unknown).
function A.lootMenuSetting()
    local options = PZAPI and PZAPI.ModOptions and PZAPI.ModOptions:getOptions("Viewpoint")
    local option = options and options:getOption("lootMenu")
    if option then return option:getValue() == true end
    return true
end

function A.setLootMenu(enabled)
    if A.canSetLootMenu() then Viewpoint.Loot.setEnabled(enabled) end
end

-- ---- Viewpoint's interaction menu ----

function A.hasInteractMenu()
    return ViewpointInteract ~= nil and ViewpointInteract.harvest ~= nil
end

-- Replaces harvest(player, object) with wrapper(original, player, object).
function A.wrapInteractHarvest(wrapper)
    local original = ViewpointInteract.harvest
    ViewpointInteract.harvest = function(player, object) return wrapper(original, player, object) end
end

-- The entries Viewpoint's menu runs: { name, fn, args, n, enabled }.
function A.setInteractActions(actions)
    ViewpointInteract.actions = actions
end
