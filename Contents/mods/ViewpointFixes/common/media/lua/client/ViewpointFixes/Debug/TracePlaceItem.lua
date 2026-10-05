--[[
Developer trace for VPF-003 (inventory "Place item"). Inert unless "Debug logging" is ticked.
Arms the tracer around the cursor's create() and the queued ISDropWorldItemAction's complete(), so the first
test shows whether the item is walked to, transferred and dropped where aimed. Remove once VPF-003 is verified.
]]
require "ViewpointFixes/ViewpointFixes"
require "ViewpointFixes/Debug/Trace"

local VF = ViewpointFixes

local function armAround(tbl, method, label)
    local original = tbl[method]
    tbl[method] = function(self, ...) return VF.Trace.during(label, original, self, ...) end
end

local function install()
    if VF.tracePlaceItemInstalled or not (ISPlace3DItemCursor and ISDropWorldItemAction) then return end
    VF.tracePlaceItemInstalled = true
    VF.Trace.wrap(luautils, "luautils", { "walkAdj", "walkAdjAltTest" })
    VF.Trace.wrap(ISWorldObjectContextMenu, "ISWorldObjectContextMenu", { "transferIfNeeded" })
    VF.Trace.wrap(ISDropWorldItemAction, "ISDropWorldItemAction", { "new", "isValid" })
    armAround(ISPlace3DItemCursor, "create", "ISPlace3DItemCursor:create")
    armAround(ISDropWorldItemAction, "complete", "ISDropWorldItemAction:complete")
    VF.log("TRACE", "place-item trace installed (active while Debug logging is ticked)")
end

Events.OnGameStart.Add(install)
