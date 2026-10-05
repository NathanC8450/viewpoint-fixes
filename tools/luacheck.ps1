# Syntax-checks every .lua file in the mod with the game's own Lua compiler.
# Usage:  .\tools\luacheck.ps1
$ErrorActionPreference = "Stop"
$game = "C:\SteamLibrary\steamapps\common\ProjectZomboid"
$project = Split-Path -Parent $PSScriptRoot
$src = Join-Path $PSScriptRoot "luacheck\LuaCheck.java"
$out = Join-Path $env:TEMP "pz-luacheck"

New-Item -ItemType Directory -Force $out | Out-Null
& javac --release 17 -d $out $src
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$game\jre64\bin\java.exe" -cp "$out;$game\projectzomboid.jar" LuaCheck (Join-Path $project "Contents")
exit $LASTEXITCODE
