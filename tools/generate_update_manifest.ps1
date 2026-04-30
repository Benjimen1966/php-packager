param(
    [Parameter(Mandatory = $true)]
    [string]$AppExe,

    [Parameter(Mandatory = $true)]
    [string]$AppVersion,

    [string]$OutputManifest = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $AppExe)) {
    throw "App EXE not found: $AppExe"
}
if ([string]::IsNullOrWhiteSpace($AppVersion)) {
    throw "AppVersion is required"
}

if ([string]::IsNullOrWhiteSpace($OutputManifest)) {
    $OutputManifest = "$AppExe.update-manifest.json"
}

$appExePath = (Resolve-Path -LiteralPath $AppExe).Path
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $appExePath).Hash.ToLowerInvariant()

$manifest = [ordered]@{
    manifest_version = 1
    app_version = $AppVersion
    app_exe_sha256 = $hash
    app_exe_name = [System.IO.Path]::GetFileName($appExePath)
    created_utc = [DateTime]::UtcNow.ToString("o")
}

$outDir = Split-Path -Parent $OutputManifest
if (-not [string]::IsNullOrWhiteSpace($outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutputManifest -Encoding UTF8
Write-Host "Update manifest generated: $OutputManifest"
