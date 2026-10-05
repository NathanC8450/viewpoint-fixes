# Builds the Java part of the mod (java/src) into 42/media/java/client/ViewpointFixes.jar.
# Compiles against ZombieBuddy.jar only: game and Viewpoint classes are reached by reflection, so JDK 17 is enough.
# Usage:  .\tools\build-java.ps1
$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot
$zb = "C:\SteamLibrary\steamapps\workshop\content\108600\3619862853\mods\ZombieBuddy\libs\ZombieBuddy.jar"
$src = Join-Path $project "java\src"
$out = Join-Path $env:TEMP "pz-viewpointfixes-classes"
$jar = Join-Path $project "Contents\mods\ViewpointFixes\42\media\java\client\ViewpointFixes.jar"

if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out, (Split-Path $jar) | Out-Null
$files = Get-ChildItem -Recurse -Filter *.java $src | ForEach-Object { $_.FullName }
& javac --release 17 -Xlint:all -cp $zb -d $out $files
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& jar --create --file $jar -C $out .
if ($LASTEXITCODE -ne 0) {
    Write-Output "jar not written: if the game is running it holds the jar open; close it and build again"
    exit $LASTEXITCODE
}
Write-Output "built $jar"
