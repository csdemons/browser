[CmdletBinding()]
param(
    [string]$BuildDir = 'D:\Project\cr\chromium\src\out\AtomWin',
    [string]$InstallerRoot = 'D:\Project\cr\installer'
)
$ErrorActionPreference = 'Stop'
$ScriptRoot = $PSScriptRoot
$RepoRoot = (Resolve-Path (Join-Path $ScriptRoot '..\..')).Path
$ISCCCandidates = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)
$ISCC = $ISCCCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (!$ISCC) { throw 'ISCC.exe not found; install Inno Setup 6.7.x' }
New-Item -ItemType Directory -Force -Path "$InstallerRoot\assets","$InstallerRoot\output" | Out-Null
Copy-Item (Join-Path $ScriptRoot 'AtomBrowser.iss') "$InstallerRoot\AtomBrowser.iss" -Force
Copy-Item (Join-Path $ScriptRoot 'assets\atom_browser.ico') "$InstallerRoot\assets\atom_browser.ico" -Force
& (Join-Path $ScriptRoot 'prepare-staging.ps1') -BuildDir $BuildDir -StageRoot "$InstallerRoot\staging" -Version '156.0.8078.79' -GrantStagingAcl
if ($LASTEXITCODE -ne 0) { throw 'Staging preparation failed' }
Push-Location $InstallerRoot
try {
    & $ISCC "$InstallerRoot\AtomBrowser.iss"
    if ($LASTEXITCODE -ne 0) { throw "ISCC failed: $LASTEXITCODE" }
} finally { Pop-Location }
$Setup = "$InstallerRoot\output\AtomBrowserSetup-0.1.0-alpha-x64.exe"
$Hash = (Get-FileHash $Setup -Algorithm SHA256).Hash.ToLowerInvariant()
"$Hash  $(Split-Path $Setup -Leaf)" | Set-Content "$Setup.sha256" -Encoding ascii
Get-Item $Setup | Select-Object Name,Length,FullName
Get-FileHash $Setup -Algorithm SHA256
