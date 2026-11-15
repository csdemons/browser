[CmdletBinding()]
param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
$Tag = 'v0.1.0-alpha'
$Setup = 'D:\Project\cr\installer\output\AtomBrowserSetup-0.1.0-alpha-x64.exe'
$Notes = Join-Path $RepoRoot 'docs\releases\v0.1.0-alpha.md'
$Manifest = Join-Path $RepoRoot 'releases\v0.1.0-alpha\release-manifest.json'
$HashFile = "$Setup.sha256"
if (!(Get-Command gh -ErrorAction SilentlyContinue)) { throw 'GitHub CLI (gh) is not installed' }
if (!(Test-Path $Setup) -or !(Test-Path $Notes) -or !(Test-Path $Manifest) -or !(Test-Path $HashFile)) {
    throw 'Release asset or release metadata is missing'
}
& gh auth status
if ($LASTEXITCODE -ne 0) { throw 'Run gh auth login first' }
$Branch = (& git -C $RepoRoot branch --show-current).Trim()
if ($Branch -ne 'main') { throw "Release tag must be created from main, current branch is $Branch" }
& git -C $RepoRoot diff --quiet
if ($LASTEXITCODE -ne 0) { throw 'Working tree has unstaged changes' }
& git -C $RepoRoot diff --cached --quiet
if ($LASTEXITCODE -ne 0) { throw 'Working tree has staged changes' }
& git -C $RepoRoot tag -a $Tag -m 'Atom Browser 0.1.0 Alpha'
if ($LASTEXITCODE -ne 0) { throw "Tag creation failed or tag already exists: $Tag" }
& git -C $RepoRoot push origin $Tag
if ($LASTEXITCODE -ne 0) { throw 'Tag push failed' }
& gh release create $Tag $Setup $HashFile $Manifest --repo csdemons/browser --title 'Atom Browser 0.1.0 Alpha' --notes-file $Notes --prerelease
if ($LASTEXITCODE -ne 0) { throw 'GitHub Release creation failed' }
