[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$BuildDir,
    [string]$StageRoot = 'D:\Project\cr\installer\staging',
    [string]$Version = '156.0.8078.79',
    [switch]$GrantStagingAcl
)
$ErrorActionPreference = 'Stop'
$BuildDir = (Resolve-Path -LiteralPath $BuildDir).Path
$App = Join-Path $StageRoot 'AtomBrowser'
$VersionDir = Join-Path $App $Version
$ManifestSource = Join-Path $BuildDir "$Version.manifest"
if (!(Test-Path "$BuildDir\chrome.exe")) { throw 'BuildDir\chrome.exe missing' }
if (!(Test-Path $ManifestSource)) { throw "Version manifest missing: $ManifestSource" }
$StageFull = [IO.Path]::GetFullPath($App)
$AllowedRoot = [IO.Path]::GetFullPath('D:\Project\cr\installer\staging\AtomBrowser')
if (!$StageFull.Equals($AllowedRoot,[StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean unexpected staging path: $StageFull"
}
if (Test-Path $App) { Remove-Item $App -Recurse -Force }
New-Item -ItemType Directory -Force -Path $VersionDir | Out-Null

Copy-Item "$BuildDir\chrome.exe" $App -Force
if (Test-Path "$BuildDir\chrome_proxy.exe") {
    Copy-Item "$BuildDir\chrome_proxy.exe" $App -Force
}
if (Test-Path "$BuildDir\chrome.exe.manifest") {
    Copy-Item "$BuildDir\chrome.exe.manifest" $App -Force
}
$SourceRoot = Split-Path $BuildDir -Parent
$License = Join-Path $SourceRoot 'LICENSE'
if (Test-Path $License) { Copy-Item $License (Join-Path $App 'LICENSE.chromium.txt') -Force }

# Runtime DLLs, helper executables and data files belong to the versioned assembly.
Get-ChildItem $BuildDir -File | Where-Object {
    $_.Name -notmatch '^siso_' -and
    (
        $_.Extension -in @('.dll','.pak','.bin','.dat') -or
        ($_.Extension -eq '.json' -and $_.Name -notmatch '^(siso_|.*\.(metrics|trace|result)\.)') -or
        ($_.Extension -eq '.exe' -and $_.Name -notin @('chrome.exe','chrome_proxy.exe'))
    )
} | Copy-Item -Destination $VersionDir -Force

Copy-Item $ManifestSource (Join-Path $VersionDir "$Version.manifest") -Force

# Locales and MEIPreload are versioned; resources and swiftshader remain beside chrome.exe.
foreach ($Name in @('locales','MEIPreload','Extensions','IwaKeyDistribution','VisualElements','WidevineCdm')) {
    $Source = Join-Path $BuildDir $Name
    if (Test-Path $Source -PathType Container) {
        Copy-Item $Source -Destination $VersionDir -Recurse -Force
    }
}
foreach ($Name in @('resources','swiftshader')) {
    $Source = Join-Path $BuildDir $Name
    if (Test-Path $Source -PathType Container) {
        Copy-Item $Source -Destination $App -Recurse -Force
    }
}

# Add every staged DLL to the private version assembly manifest.
$Xml = [xml](Get-Content (Join-Path $VersionDir "$Version.manifest") -Raw)
$Assembly = $Xml.DocumentElement
$Existing = @{}
foreach ($Node in $Assembly.ChildNodes) {
    if ($Node.LocalName -eq 'file') { $Existing[$Node.GetAttribute('name')] = $true }
}
foreach ($Dll in Get-ChildItem $VersionDir -File -Filter '*.dll') {
    if (!$Existing.ContainsKey($Dll.Name)) {
        $Node = $Xml.CreateElement('file', $Assembly.NamespaceURI)
        $Node.SetAttribute('name',$Dll.Name)
        [void]$Assembly.AppendChild($Node)
    }
}
$Xml.Save((Join-Path $VersionDir "$Version.manifest"))

if ($GrantStagingAcl) {
    foreach ($Parent in @('D:\','D:\Project','D:\Project\cr','D:\Project\cr\installer','D:\Project\cr\installer\staging')) {
        & icacls.exe $Parent /grant '*S-1-15-2-1:(X)' /grant '*S-1-15-2-2:(X)' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not set traversal ACL on $Parent" }
    }
    & icacls.exe $App /grant '*S-1-15-2-1:(OI)(CI)(RX)' /T /C | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not set AppContainer ACL' }
    & icacls.exe $App /grant '*S-1-15-2-2:(OI)(CI)(RX)' /T /C | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not set restricted AppContainer ACL' }
}
Write-Host "Prepared staging: $App"
Write-Host "Version directory: $VersionDir"
