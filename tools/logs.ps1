# Follows the game's console log live, filtered to this mod's output and Lua errors.
# Usage:  .\tools\logs.ps1          mod lines + errors
#         .\tools\logs.ps1 -All     everything
param([switch]$All)

$log = Join-Path $env:USERPROFILE "Zomboid\console.txt"
$pattern = "\[MyFirstMod\]|ERROR|Exception|STACK TRACE|attempted index|non-table"

if ($All) {
    Get-Content $log -Wait -Tail 50
} else {
    Get-Content $log -Wait -Tail 200 | Select-String -Pattern $pattern
}
