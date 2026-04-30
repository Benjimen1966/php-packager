param(
    [string]$ManifestPath = ".\staging\manifest.json",
    [switch]$SkipLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Manifest not found: $ManifestPath"
}

$manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
$outputDir = if ($manifest.output_dir) { [string]$manifest.output_dir } else { "dist" }
$appName = if ($manifest.app_name) { [string]$manifest.app_name } else { "Mywbstd" }

if ([System.IO.Path]::IsPathRooted($outputDir)) {
    $artifactDir = $outputDir
} else {
    $artifactDir = Join-Path (Resolve-Path ".").Path $outputDir
}

$appExe = Join-Path $artifactDir "$appName.exe"
$updaterExe = Join-Path $artifactDir "updater.exe"

if (-not (Test-Path -LiteralPath $appExe)) {
    throw "Packaged EXE missing: $appExe"
}
if (-not (Test-Path -LiteralPath $updaterExe)) {
    throw "Updater EXE missing: $updaterExe"
}

Write-Host "Artifacts found in: $artifactDir"
Write-Host "- $appExe"
Write-Host "- $updaterExe"

if ($SkipLaunch) {
    Write-Host "Smoke test passed (artifact checks only)."
    exit 0
}

$localAppData = [Environment]::GetEnvironmentVariable("LOCALAPPDATA")
if ([string]::IsNullOrWhiteSpace($localAppData)) {
    throw "LOCALAPPDATA is not set."
}

$startupLog = Join-Path (Join-Path (Join-Path $localAppData $appName) "logs") "startup.log"
$preLogTime = if (Test-Path -LiteralPath $startupLog) { (Get-Item -LiteralPath $startupLog).LastWriteTimeUtc } else { [datetime]::MinValue }

$proc = Start-Process -FilePath $appExe -PassThru
$deadline = (Get-Date).AddSeconds(20)
$logUpdated = $false

while ((Get-Date) -lt $deadline) {
    if (Test-Path -LiteralPath $startupLog) {
        $ts = (Get-Item -LiteralPath $startupLog).LastWriteTimeUtc
        if ($ts -gt $preLogTime) {
            $logUpdated = $true
            break
        }
    }

    if ($proc.HasExited) {
        if ($proc.ExitCode -ne 0) {
            throw "Application exited with code $($proc.ExitCode)."
        }
    }

    Start-Sleep -Milliseconds 400
}

if (-not $logUpdated) {
    throw "Startup log was not updated within timeout: $startupLog"
}

Write-Host "Smoke test passed: launcher started and startup.log updated."
