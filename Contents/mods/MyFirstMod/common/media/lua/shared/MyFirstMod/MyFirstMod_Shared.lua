-- Shared code: loaded on both client and server. Put constants and helpers here.
MyFirstMod = MyFirstMod or {}

MyFirstMod.ID = "MyFirstMod"
MyFirstMod.COIN_TYPE = "MyFirstMod.LuckyCoin"

function MyFirstMod.log(msg)
    print("[" .. MyFirstMod.ID .. "] " .. tostring(msg))
end
