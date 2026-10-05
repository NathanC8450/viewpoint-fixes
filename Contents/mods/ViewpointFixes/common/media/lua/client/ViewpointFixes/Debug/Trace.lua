--[[
Developer call tracer (inert unless "Debug logging" is ticked).

Wraps methods on a Lua table so that, while armed, every call is logged with readable arguments and return
values, indented by call depth:
    [ViewpointFixes] TRACE: > ISMoveableSpriteProps:pickUpMoveable(props(appliances_cooking_01_25), char, sq(5562,6060,0), true, true)
    [ViewpointFixes] TRACE:   < findOnSquare -> nil
Wrapping is cheap when disarmed (one boolean check per call). Used to follow vanilla code paths at runtime
instead of guessing from source.

    ViewpointFixes.Trace.wrap(ISMoveableSpriteProps, "ISMoveableSpriteProps", { "pickUpMoveable", ... })
    ViewpointFixes.Trace.during("label", fn, ...)   -- arm for the duration of fn(...)
]]
require "ViewpointFixes/ViewpointFixes"

local VF = ViewpointFixes
local Trace = VF.Trace or {}
VF.Trace = Trace

local armed = 0
local depth = 0
local MAX_LINES = 400 -- per armed window, so a runaway loop can't flood the log
local lines = 0

local function describe(v)
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t ~= "userdata" and t ~= "table" then return tostring(v) end
    if t == "table" then
        if v.spriteName then return "props(" .. tostring(v.spriteName) .. ")" end
        if v.Type then return "<" .. tostring(v.Type) .. ">" end
        local n = 0
        for _ in pairs(v) do n = n + 1 end
        return "table[" .. n .. "]"
    end
    if instanceof(v, "IsoGridSquare") then
        return "sq(" .. v:getX() .. "," .. v:getY() .. "," .. v:getZ() .. ")"
    end
    if instanceof(v, "IsoGameCharacter") then return "char" end
    if instanceof(v, "IsoObject") then
        local sprite = v:getSprite()
        return "obj(" .. (sprite and tostring(sprite:getName()) or "?") .. ")"
    end
    if instanceof(v, "InventoryItem") then return "item(" .. tostring(v:getFullType()) .. ")" end
    if instanceof(v, "IsoSprite") then return "sprite(" .. tostring(v:getName()) .. ")" end
    local s = tostring(v)
    return #s > 60 and string.sub(s, 1, 60) .. "..." or s
end

local function list(n, ...)
    local parts = {}
    for i = 1, n do parts[i] = describe((select(i, ...))) end
    return table.concat(parts, ", ")
end

-- {n = count, ...}: keeps trailing/embedded nils, which {...} with # would lose.
local function pack(...) return { n = select("#", ...), ... } end

local function emit(text)
    if lines >= MAX_LINES then return end
    lines = lines + 1
    if lines == MAX_LINES then text = text .. "  (trace line limit reached)" end
    VF.log("TRACE", string.rep("  ", depth) .. text)
end

function Trace.isArmed() return armed > 0 end

-- Wraps each named method of `tbl` once. `label` prefixes the log lines.
function Trace.wrap(tbl, label, methods)
    if type(tbl) ~= "table" then return end
    Trace.wrapped = Trace.wrapped or {}
    for _, name in ipairs(methods) do
        local key = label .. ":" .. name
        local original = tbl[name]
        if type(original) == "function" and not Trace.wrapped[key] then
            Trace.wrapped[key] = original
            tbl[name] = function(...)
                if armed == 0 then return original(...) end
                emit("> " .. key .. "(" .. list(select("#", ...), ...) .. ")")
                depth = depth + 1
                local r = pack(pcall(original, ...))
                depth = depth - 1
                if not r[1] then
                    emit("! " .. name .. " raised " .. tostring(r[2]))
                    error(r[2], 0)
                end
                emit("< " .. name .. " -> " .. (r.n > 1 and list(r.n - 1, unpack(r, 2, r.n)) or "(nothing)"))
                return unpack(r, 2, r.n)
            end
        end
    end
end

-- Arms the tracer for the duration of fn(...) when debug logging is on, otherwise just calls fn.
function Trace.during(label, fn, ...)
    if not VF.debugEnabled() then return fn(...) end
    if armed == 0 then
        lines = 0
        VF.log("TRACE", "---- begin " .. label)
    end
    armed = armed + 1
    local r = pack(pcall(fn, ...))
    armed = armed - 1
    if armed == 0 then VF.log("TRACE", "---- end " .. label) end
    if not r[1] then error(r[2], 0) end
    return unpack(r, 2, r.n)
end
