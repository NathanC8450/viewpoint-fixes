# Packages the Workshop item (workshop.txt, preview.png, Contents/ with the built jar, LICENSE, README) into
# dist\ViewpointFixes-<modversion>.zip. The zip's top folder is "ViewpointFixes", so unzipping it into
# %USERPROFILE%\Zomboid\Workshop\ gives a local Workshop item the game loads, and the same folder is what the
# in-game uploader (Main menu > Workshop > Create and update items) takes for the Steam Workshop.
#
# Build the jar first (game closed):  cd java; .\gradlew deploy
# Usage:  .\tools\package.ps1
$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot
$mod = Join-Path $project "Contents\mods\ViewpointFixes"
$jar = Join-Path $mod "42\media\java\client\ViewpointFixes.jar"

if (-not (Test-Path $jar)) {
    Write-Error "No jar at $jar. Build it first: cd java; .\gradlew deploy"
    exit 1
}
$version = (Select-String -Path (Join-Path $mod "42\mod.info") -Pattern '^modversion=(.+)$').Matches[0].Groups[1].Value.Trim()

$dist = Join-Path $project "dist"
$stage = Join-Path $dist "stage"
$item = Join-Path $stage "ViewpointFixes"
$zip = Join-Path $dist "ViewpointFixes-$version.zip"

if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
if (Test-Path $zip) { Remove-Item -Force $zip }
New-Item -ItemType Directory -Force $item | Out-Null
foreach ($f in "workshop.txt", "preview.png", "LICENSE", "README.md") {
    Copy-Item (Join-Path $project $f) $item
}
Copy-Item -Recurse (Join-Path $project "Contents") (Join-Path $item "Contents")

# bsdtar writes proper forward-slash zip entries (Compress-Archive in Windows PowerShell 5.1 does not).
& (Join-Path $env:SystemRoot "System32\tar.exe") -a -c -f $zip -C $stage ViewpointFixes
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Remove-Item -Recurse -Force $stage
Write-Output "packaged $zip"
