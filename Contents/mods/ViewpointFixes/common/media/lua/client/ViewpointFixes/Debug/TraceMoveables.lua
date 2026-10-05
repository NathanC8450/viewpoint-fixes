--[[
Developer trace for furniture actions (VPF-002 investigation). Inert unless "Debug logging" is ticked.

Arms the tracer around every ISMoveablesAction:complete(), whoever queued it (our VPF-002 or vanilla's own
2D cursor), and traces the vanilla ISMoveableSpriteProps functions that pickup / place / rotate go through.
Remove once VPF-002 is understood.
]]
require "ViewpointFixes/ViewpointFixes"
require "ViewpointFixes/Debug/Trace"

local VF = ViewpointFixes

local PROPS_METHODS = {
    "rotateMoveableViaCursor", "rotateMoveable", "rotateMoveableInternal",
    "pickUpMoveableViaCursor", "pickUpMoveable", "pickUpMoveableInternal",
    "placeMoveableViaCursor", "placeMoveable", "placeMoveableInternal",
    "findOnSquare", "instanceItem", "findInInventory",
    "canPickUpMoveable", "canPlaceMoveable", "canPlaceMoveableInternal", "canRotateMoveable",
}

local function install()
    if VF.traceMoveablesInstalled or not (ISMoveablesAction and ISMoveableSpriteProps) then return end
    VF.traceMoveablesInstalled = true

    VF.Trace.wrap(ISMoveableSpriteProps, "ISMoveableSpriteProps", PROPS_METHODS)

    local complete = ISMoveablesAction.complete
    ISMoveablesAction.complete = function(self, ...)
        local label = string.format("ISMoveablesAction:complete mode=%s orig=%s target=%s sq=%s",
            tostring(self.mode), tostring(self.origSpriteName),
            tostring(self.moveProps and self.moveProps.spriteName),
            self.square and (self.square:getX() .. "," .. self.square:getY() .. "," .. self.square:getZ()) or "nil")
        return VF.Trace.during(label, complete, self, ...)
    end
    VF.log("TRACE", "moveables trace installed (active while Debug logging is ticked)")
end

Events.OnGameStart.Add(install)
