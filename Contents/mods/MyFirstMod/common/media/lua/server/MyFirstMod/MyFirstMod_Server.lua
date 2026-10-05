-- Server code: world/game-state logic. In singleplayer this runs locally too.
require "MyFirstMod/MyFirstMod_Shared"

local function onInitGlobalModData(isNewGame)
    local data = ModData.getOrCreate(MyFirstMod.ID)
    data.loads = (data.loads or 0) + 1
    MyFirstMod.log("server init, save loaded " .. data.loads .. " time(s)")
end

Events.OnInitGlobalModData.Add(onInitGlobalModData)
