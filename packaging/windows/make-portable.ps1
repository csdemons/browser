# Package an already built native Windows x64 Atom Browser as a portable ZIP.
# This is NOT an installer and does NOT claim Windows GOST testing or signing.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$BuildDir,
    [string]$Destination = '.\dist'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$BuildDir = (Resolve-Path -LiteralPath $BuildDir).Path
if (!(Test-Path -LiteralPath (Join-Path $BuildDir 'chrome.exe'))) {
    throw 'No chrome.exe found. Build the Windows target first.'
}
New-Item -ItemType Directory -Force -Path $Destination | Out-Null
$Destination = (Resolve-Path -LiteralPath $Destination).Path
$stage = Join-Path $env:TEMP ('atom-browser-win-' + [Guid]::NewGuid().ToString('N'))
$app = Join-Path $stage 'Atom Browser'
New-Item -ItemType Directory -Force -Path $app | Out-Null
try {
    # Chromium component DLLs must be distributed with chrome.exe.
    $types = @('.dll', '.pak', '.bin', '.dat', '.json')
    Get-ChildItem -LiteralPath $BuildDir -File | ForEach-Object {
        $name = $_.Name
        $copy = ($types -contains $_.Extension.ToLowerInvariant()) -or
                ($name -match '^chrome.*\.exe$') -or
                ($name -eq 'notification_helper.exe')
        if ($copy) { Copy-Item -LiteralPath $_.FullName -Destination $app }
    }
    foreach ($subdir in @('locales', 'resources', 'swiftshader', 'MEIPreload')) {
        $src = Join-Path $BuildDir $subdir
        if (Test-Path -LiteralPath $src -PathType Container) {
            Copy-Item -LiteralPath $src -Destination $app -Recurse
        }
    }
    if (!(Test-Path -LiteralPath (Join-Path $app 'icudtl.dat'))) {
        throw 'Chromium ICU data is missing in Windows build output.'
    }
    @'
@echo off
set "ATOM_USER_DATA=%LOCALAPPDATA%\Atom Browser\User Data"
"%~dp0chrome.exe" --user-data-dir="%ATOM_USER_DATA%" %*
'@ | Set-Content -LiteralPath (Join-Path $app 'Atom Browser.cmd') -Encoding ascii
    $zip = Join-Path $Destination 'Atom-Browser-0.1.0-alpha-windows-x64-portable.zip'
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    Compress-Archive -LiteralPath $app -DestinationPath $zip -CompressionLevel Optimal
    $sha = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    "$sha  $(Split-Path -Leaf $zip)" | Set-Content -LiteralPath "$zip.sha256" -Encoding ascii
    Write-Host "Created $zip"
    Write-Host 'Windows compatibility, binary signing and GOST runtime verification remain pending.'
}
finally { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
