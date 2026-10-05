# Follows the game's console log live, filtered to our fixes, Viewpoint, ZombieBuddy and Lua errors.
# Viewpoint's periodic perf summary is dropped unless -Perf is given.
# Usage:  .\tools\logs.ps1          filtered
#         .\tools\logs.ps1 -Perf    filtered, including Viewpoint perf lines
#         .\tools\logs.ps1 -All     everything
param([switch]$All, [switch]$Perf)

$log = Join-Path $env:USERPROFILE "Zomboid\console.txt"
$pattern = "\[ViewpointFixes\]|\[Viewpoint\]|\[ZB\]|ERROR|Exception|STACK TRACE|attempted index|non-table|\(MOD:"
$perfLine = "\[Viewpoint\] \d+ fps \|"

if ($All) {
    Get-Content $log -Wait -Tail 50
} else {
    Get-Content $log -Wait -Tail 200 | Where-Object { $_ -match $pattern -and ($Perf -or $_ -notmatch $perfLine) }
}
