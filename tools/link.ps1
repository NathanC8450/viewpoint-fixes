# Links this project into %USERPROFILE%\Zomboid\Workshop so the game loads it
# straight from here. Uses a directory junction (no admin rights needed).
# Usage:  .\tools\link.ps1          create the link
#         .\tools\link.ps1 -Remove  remove the link (project files are untouched)
param([switch]$Remove)

$project = Split-Path -Parent $PSScriptRoot
$name = Split-Path -Leaf $project
$link = Join-Path $env:USERPROFILE "Zomboid\Workshop\$name"

if ($Remove) {
    if (Test-Path $link) {
        # Deletes only the junction itself, not its target
        (Get-Item $link).Delete()
        Write-Host "Removed link $link"
    } else {
        Write-Host "No link at $link"
    }
    return
}

if (Test-Path $link) {
    $item = Get-Item $link
    if ($item.LinkType -eq "Junction" -and $item.Target -contains $project) {
        Write-Host "Already linked: $link -> $project"
        return
    }
    Write-Error "$link already exists and is not a link to this project. Move it aside first."
    exit 1
}

New-Item -ItemType Junction -Path $link -Target $project | Out-Null
Write-Host "Linked $link -> $project"
