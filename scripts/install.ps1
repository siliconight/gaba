# Install gaba into the current Godot project.
#
# One-liner:
#   irm https://raw.githubusercontent.com/siliconight/gaba/main/scripts/install.ps1 | iex
#
# Pin a version:
#   $env:GABA_TAG = "v0.4.0"; irm https://raw.githubusercontent.com/siliconight/gaba/main/scripts/install.ps1 | iex
#
# Local invocation:
#   .\install.ps1 [-ProjectDir <path>] [-Tag <tag>]

[CmdletBinding()]
param(
	[string]$ProjectDir = $(if ($env:GABA_PROJECT_DIR) { $env:GABA_PROJECT_DIR } else { "." }),
	[string]$Tag = $(if ($env:GABA_TAG) { $env:GABA_TAG } else { "main" })
)

$ErrorActionPreference = "Stop"

# Resolve to absolute so error messages are unambiguous.
try {
	$ProjectDir = (Resolve-Path -Path $ProjectDir).Path
} catch {
	Write-Error "gaba install: project path '$ProjectDir' does not exist."
	exit 1
}

$projectFile = Join-Path $ProjectDir "project.godot"
if (-not (Test-Path $projectFile)) {
	Write-Error "gaba install: no project.godot found in '$ProjectDir'.`nRun this from your Godot project root, or pass -ProjectDir."
	exit 1
}

$addonDir = Join-Path $ProjectDir "addons/gaba"
if (Test-Path $addonDir) {
	Write-Error "gaba install: '$addonDir' already exists.`nRemove it first if you want to reinstall."
	exit 1
}

$addonsParent = Join-Path $ProjectDir "addons"
if (-not (Test-Path $addonsParent)) {
	New-Item -ItemType Directory -Path $addonsParent | Out-Null
}

$tmpDir = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) "gaba-install-$(Get-Random)")
try {
	# GitHub's /archive/<ref>.zip handles both branch names and tag names.
	$zipUrl = "https://github.com/siliconight/gaba/archive/$Tag.zip"
	$zipPath = Join-Path $tmpDir.FullName "gaba.zip"

	Write-Host "gaba install: downloading $Tag..."
	Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing

	Expand-Archive -Path $zipPath -DestinationPath $tmpDir.FullName -Force

	# GitHub names the extracted directory gaba-<ref>. Find it without guessing.
	$extracted = Get-ChildItem -Path $tmpDir.FullName -Directory -Filter "gaba-*" | Select-Object -First 1
	if (-not $extracted) {
		Write-Error "gaba install: could not find extracted gaba-* directory."
		exit 1
	}

	$sourceAddon = Join-Path $extracted.FullName "addons/gaba"
	if (-not (Test-Path $sourceAddon)) {
		Write-Error "gaba install: extracted archive doesn't contain addons/gaba — check the tag '$Tag'."
		exit 1
	}

	Copy-Item -Path $sourceAddon -Destination $addonDir -Recurse

	Write-Host ""
	Write-Host "gaba install: copied to $addonDir"
	Write-Host ""
	Write-Host "Next steps:"
	Write-Host "  1. Open your project in Godot 4."
	Write-Host "  2. Project -> Project Settings -> Plugins -> enable 'Gaba'."
	Write-Host "  3. Look for the 'Gaba' tab in the right-side editor docks."
}
finally {
	Remove-Item -Recurse -Force $tmpDir.FullName -ErrorAction SilentlyContinue
}
