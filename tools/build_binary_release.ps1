<#
.SYNOPSIS
    Assembles a distributable binary release archive of the PHP Packager.

.DESCRIPTION
    Copies pre-built binaries from dist\ and source/template files into a
    staging folder, then zips everything into dist\php-packager-<version>.zip.

    Run tools\build_release.bat first to ensure binaries are up to date.

.PARAMETER Version
    Release version string. Defaults to the app_version in staging\packager.yml
    if not provided.

.PARAMETER OutputDir
    Directory where the final zip is written. Defaults to dist\.

.EXAMPLE
    .\tools\build_binary_release.ps1
    .\tools\build_binary_release.ps1 -Version 1.2.0
#>
param(
    [string]$Version = "",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"

$Root = Split-Path $PSScriptRoot -Parent
$DistDir = Join-Path $Root "dist"

# --- Resolve version -----------------------------------------------------------
if ($Version -eq "") {
    $ManifestPath = Join-Path $Root "staging\manifest.json"
    $YmlPath      = Join-Path $Root "staging\packager.yml"
    if (Test-Path $ManifestPath) {
        $Version = (Get-Content $ManifestPath -Raw | ConvertFrom-Json).app_version
    } elseif (Test-Path $YmlPath) {
        $line = Get-Content $YmlPath | Where-Object { $_ -match "^app_version:" } | Select-Object -First 1
        if ($line -match ":\s*(.+)$") { $Version = $Matches[1].Trim() }
    }
}
if ($Version -eq "" -or $null -eq $Version) { $Version = "0.0.0" }

# --- Resolve output dir -------------------------------------------------------
if ($OutputDir -eq "") { $OutputDir = $DistDir }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

$ZipName = "php-packager-$Version.zip"
$ZipPath = Join-Path $OutputDir $ZipName

# --- Required binaries --------------------------------------------------------
$RequiredBinaries = @(
    "embed_cli.exe",
    "launcher_stub.exe",
    "updater.exe"
)
foreach ($bin in $RequiredBinaries) {
    $p = Join-Path $DistDir $bin
    if (-not (Test-Path $p)) {
        Write-Error "Missing required binary: $p`nRun tools\build_release.bat first."
        exit 1
    }
}

# --- Assemble staging area ----------------------------------------------------
$TempDir = Join-Path $env:TEMP "php-packager-release-$([System.IO.Path]::GetRandomFileName())"
$PkgDir  = Join-Path $TempDir "php-packager-$Version"
New-Item -ItemType Directory -Path $PkgDir | Out-Null

# Binaries
$BinDir = Join-Path $PkgDir "bin"
New-Item -ItemType Directory -Path $BinDir | Out-Null
foreach ($bin in $RequiredBinaries) {
    Copy-Item (Join-Path $DistDir $bin) (Join-Path $BinDir $bin)
}

# Source folders (no compiled artifacts, no backup folders, no staging/dist)
$SourceFolders = @("builder", "launcher", "updater", "shared", "installer", "examples", "docs", "tools")
foreach ($folder in $SourceFolders) {
    $src = Join-Path $Root $folder
    if (-not (Test-Path $src)) { continue }
    $dst = Join-Path $PkgDir $folder
    # Copy recursively, then prune unwanted files
    Copy-Item $src $dst -Recurse
    # Remove compiled artifacts
    Get-ChildItem $dst -Recurse -Include "*.compiled","*.ppu","*.o","*.res","*.lps" | Remove-Item -Force
    # Remove backup subfolders
    Get-ChildItem $dst -Recurse -Directory -Filter "backup" | Remove-Item -Recurse -Force
}

# Root files
foreach ($f in @("README.md", "Build.bat", "packager.yml")) {
    $fp = Join-Path $Root $f
    if (Test-Path $fp) { Copy-Item $fp (Join-Path $PkgDir $f) }
}

# --- Zip ----------------------------------------------------------------------
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($TempDir, $ZipPath)

# --- Cleanup ------------------------------------------------------------------
Remove-Item $TempDir -Recurse -Force

# --- Done ---------------------------------------------------------------------
$SizeMB = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)
Write-Host "Binary release archive ready: $ZipPath ($SizeMB MB)"
Write-Host ""
Write-Host "Contents of php-packager-$Version\:"
Write-Host "  bin\embed_cli.exe        <- packaging tool"
Write-Host "  bin\launcher_stub.exe    <- launcher template"
Write-Host "  bin\updater.exe          <- updater helper"
Write-Host "  builder\src\             <- source (reference)"
Write-Host "  launcher\src\            <- source (reference)"
Write-Host "  updater\src\             <- source (reference)"
Write-Host "  installer\setup.iss      <- Inno Setup template"
Write-Host "  tools\                   <- build scripts"
Write-Host "  examples\                <- example packager.yml / manifest"
Write-Host "  docs\                    <- documentation"
Write-Host "  README.md"
