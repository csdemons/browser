# Requires native Windows x64, depot_tools on PATH, Visual Studio 2026 + required SDK.
# Reuses a source snapshot exported from the successful Linux checkout.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ChromiumSrc,
    [Parameter(Mandatory=$true)][string]$SnapshotZip,
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program returned exit code $LASTEXITCODE"
    }
}

$ChromiumSrc = (Resolve-Path -LiteralPath $ChromiumSrc).Path
$SnapshotZip = (Resolve-Path -LiteralPath $SnapshotZip).Path
$BoringSsl = Join-Path $ChromiumSrc 'third_party\boringssl\src'
if (!(Test-Path -LiteralPath $BoringSsl)) {
    throw 'BoringSSL checkout missing. Run gclient sync for the pinned Chromium tag first.'
}
$staging = Join-Path $env:TEMP ('atom-browser-src-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $staging | Out-Null
try {
    Expand-Archive -LiteralPath $SnapshotZip -DestinationPath $staging -Force
    $manifest = Get-Content -LiteralPath (Join-Path $staging 'manifest.json') -Raw | ConvertFrom-Json
    foreach ($item in $manifest.files) {
        $rel = [string]$item.path
        $sourcePath = Join-Path $staging $rel
        $hash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne [string]$item.sha256) {
            throw "SHA256 mismatch in source snapshot: $rel"
        }
    }
    $currentChromium = (& git -C $ChromiumSrc rev-parse HEAD).Trim()
    $currentBoring = (& git -C $BoringSsl rev-parse HEAD).Trim()
    if ($currentChromium -ne [string]$manifest.chromium_sha) {
        throw "Unexpected Chromium commit $currentChromium (wanted $($manifest.chromium_sha))"
    }
    if ($currentBoring -ne [string]$manifest.boringssl_sha) {
        throw "Unexpected BoringSSL commit $currentBoring (wanted $($manifest.boringssl_sha))"
    }
    Invoke-Checked 'git' @('-C', $ChromiumSrc, 'diff', '--quiet')
    Invoke-Checked 'git' @('-C', $BoringSsl, 'diff', '--quiet')
    $chromePatch = Join-Path $staging 'patches\chromium.patch'
    $boringPatch = Join-Path $staging 'patches\boringssl.patch'
    Invoke-Checked 'git' @('-C', $ChromiumSrc, 'apply', '--check', $chromePatch)
    Invoke-Checked 'git' @('-C', $BoringSsl, 'apply', '--check', $boringPatch)
    # Do not overwrite existing untracked files. Prevent path escapes.
    $copies = @()
    foreach ($item in $manifest.files) {
        $rel = [string]$item.path
        if (!$rel.StartsWith('files/')) { continue }
        if ($rel -notmatch '^files/(chromium|boringssl)/(.+)$') {
            throw "Unrecognized source file path: $rel"
        }
        $targetRoot = if ($Matches[1] -eq 'chromium') { $ChromiumSrc } else { $BoringSsl }
        $subpath = $Matches[2]
        if ($subpath -match '(^|/)\.\.(/|$)' -or $subpath.StartsWith('/')) {
            throw "Unsafe file path: $subpath"
        }
        $target = Join-Path $targetRoot $subpath.Replace('/', '\')
        if (Test-Path -LiteralPath $target) {
            throw "Refusing to overwrite pre-existing file: $target"
        }
        $copies += [PSCustomObject]@{Source=(Join-Path $staging $rel); Target=$target}
    }
    Invoke-Checked 'git' @('-C', $ChromiumSrc, 'apply', $chromePatch)
    Invoke-Checked 'git' @('-C', $BoringSsl, 'apply', $boringPatch)
    foreach ($copy in $copies) {
        $dir = Split-Path -Parent $copy.Target
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Copy-Item -LiteralPath $copy.Source -Destination $copy.Target -ErrorAction Stop
    }
    Write-Host 'Atom Browser GOST source snapshot applied successfully.'
    if ($SkipBuild) { return }

    # Existing checkout must already have all Windows platform dependencies and hooks.
    $env:DEPOT_TOOLS_WIN_TOOLCHAIN = '0'
    $out = Join-Path $ChromiumSrc 'out\AtomWin'
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    @'
is_debug = false
is_component_build = true
symbol_level = 0
target_cpu = "x64"
use_remoteexec = false
'@ | Set-Content -LiteralPath (Join-Path $out 'args.gn') -Encoding ascii
    Push-Location $ChromiumSrc
    try {
        Invoke-Checked 'gn' @('gen', 'out/AtomWin')
        Invoke-Checked 'autoninja' @('-C', 'out/AtomWin', '-j', '6', 'chrome')
        Invoke-Checked (Join-Path $out 'chrome.exe') @('--version')
    }
    finally { Pop-Location }
}
finally { Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue }
