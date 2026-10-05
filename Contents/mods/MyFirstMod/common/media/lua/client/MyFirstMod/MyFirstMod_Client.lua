-- Client code: UI, input, context menus. Runs for each local player.
require "MyFirstMod/MyFirstMod_Shared"

local function onGameStart()
    MyFirstMod.log("loaded (client)")
end

local function flipCoin(player)
    local result = ZombRand(2) == 0 and getText("IGUI_MyFirstMod_Heads") or getText("IGUI_MyFirstMod_Tails")
    player:Say(result)
end

-- Adds "Flip Coin" when right-clicking a Lucky Coin in the inventory.
local function onFillInventoryContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    for _, entry in ipairs(items) do
        -- entries are either InventoryItems or stacks { items = {...} }
        local item = instanceof(entry, "InventoryItem") and entry or entry.items[1]
        if item and item:getFullType() == MyFirstMod.COIN_TYPE then
            context:addOption(getText("ContextMenu_MyFirstMod_FlipCoin"), player, flipCoin)
            return
        end
    end
end

Events.OnGameStart.Add(onGameStart)
Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryContextMenu)
