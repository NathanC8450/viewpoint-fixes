--[[
VPF-004: dropped / placed items always show unrotated in first and third person.

Bug:   an item placed at 90° (inventory "Place item", R / Shift+R) lies at 0° in Viewpoint's view; in 2D it's right.
Cause: Viewpoint draws world items with WorldItemModelDrawer.renderMain(..., 0f, 0f, false). A forced rotation
       >= 0 makes ItemModelRenderer use that angle instead of the item's worldX/Y/ZRotation; vanilla passes -1.
       (Read from Viewpoint.jar / projectzomboid.jar bytecode, 2026-10-05.)
Fix:   Java (java/src/viewpointfixes/Patch_ItemRotation.java): while Viewpoint is drawing a world item, a forced
       rotation of 0 becomes -1. This file only owns the toggle.
Seen:  Viewpoint 0.1.5a-hotfix, game 42.21.
Retire when Viewpoint draws world items with their own rotation.
]]
require "ViewpointFixes/ViewpointFixes"

local VF = ViewpointFixes
local ID = "VPF_004"

VF.register({ id = ID, label = "UI_ViewpointFixes_VPF004", tooltip = "UI_ViewpointFixes_VPF004_Tooltip" })

local sent

local function sync()
    local on = VF.isEnabled(ID)
    if on ~= sent then
        sent = on
        ViewpointFixesJava.setItemRotation(on)
        VF.debug(ID, "item rotation " .. (on and "on" or "off"))
    end
end

local function install()
    if not ViewpointFixesJava then
        VF.log(ID, "Java part not loaded (ZombieBuddy approval?); fix inactive")
        return
    end
    VF.log(ID, "installed; java status: " .. tostring(ViewpointFixesJava.status()))
    sync()
    Events.OnTick.Add(function() VF.guard(ID, sync) end)
end

Events.OnGameStart.Add(install)
