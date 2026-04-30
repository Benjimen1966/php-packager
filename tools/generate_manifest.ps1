param(
    [string]$PackagerYml = "..\staging\packager.yml",
    [string]$OutputManifest = "..\staging\manifest.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $PackagerYml)) {
    throw "packager.yml not found: $PackagerYml"
}

$raw = Get-Content -LiteralPath $PackagerYml -Encoding UTF8
$config = @{}
$phpExtensions = New-Object System.Collections.Generic.List[string]
$excludePatterns = New-Object System.Collections.Generic.List[string]
$phpIni = [ordered]@{}
$activeSection = ""

function Unquote-Value {
    param([string]$Value)

    if (($Value.StartsWith('"') -and $Value.EndsWith('"')) -or ($Value.StartsWith("'") -and $Value.EndsWith("'"))) {
        return $Value.Substring(1, $Value.Length - 2)
    }

    return $Value
}

foreach ($line in $raw) {
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0) { continue }
    if ($trimmed.StartsWith("#")) { continue }

    if ($activeSection -eq "php_extensions_required" -and $trimmed.StartsWith("- ")) {
        $ext = Unquote-Value ($trimmed.Substring(2).Trim())
        if (-not [string]::IsNullOrWhiteSpace($ext)) {
            $phpExtensions.Add($ext)
        }
        continue
    }

    if ($activeSection -eq "exclude" -and $trimmed.StartsWith("- ")) {
        $pattern = Unquote-Value ($trimmed.Substring(2).Trim())
        if (-not [string]::IsNullOrWhiteSpace($pattern)) {
            $excludePatterns.Add($pattern)
        }
        continue
    }

    if ($activeSection -eq "php_ini") {
        $iniMatch = [regex]::Match($line, '^\s+([A-Za-z0-9_]+)\s*:\s*(.*)$')
        if ($iniMatch.Success) {
            $iniKey = $iniMatch.Groups[1].Value
            $iniValue = Unquote-Value ($iniMatch.Groups[2].Value.Trim())
            if (-not [string]::IsNullOrWhiteSpace($iniValue)) {
                $phpIni[$iniKey] = $iniValue
            }
            continue
        }
    }

    $match = [regex]::Match($line, '^\s*([A-Za-z0-9_]+)\s*:\s*(.*)$')
    if (-not $match.Success) { continue }

    $key = $match.Groups[1].Value
    $value = $match.Groups[2].Value.Trim()

    if ($value.Length -eq 0) {
        if (($key -eq "php_extensions_required") -or ($key -eq "php_ini") -or ($key -eq "exclude")) {
            $activeSection = $key
            continue
        }

        $activeSection = ""
        continue
    }

    $activeSection = ""
    $value = Unquote-Value $value
    $config[$key] = $value
}

function Get-ConfigValue {
    param(
        [hashtable]$Map,
        [string]$Key,
        [string]$DefaultValue = ""
    )

    if ($Map.ContainsKey($Key) -and $null -ne $Map[$Key] -and $Map[$Key] -ne "") {
        return [string]$Map[$Key]
    }

    return $DefaultValue
}

$appName = Get-ConfigValue -Map $config -Key "app_name" -DefaultValue "Mywbstd"
$appVersion = Get-ConfigValue -Map $config -Key "app_version" -DefaultValue "1.0.0"
$appDir = Get-ConfigValue -Map $config -Key "app_dir" -DefaultValue ""
$documentRoot = Get-ConfigValue -Map $config -Key "document_root" -DefaultValue "public"
$entrypoint = Get-ConfigValue -Map $config -Key "entrypoint" -DefaultValue "index.php"
$healthcheckPath = Get-ConfigValue -Map $config -Key "healthcheck_path" -DefaultValue "public/healthz.php"
$phpRuntime = Get-ConfigValue -Map $config -Key "php_runtime" -DefaultValue "runtime/php80"
$outputDirValue = Get-ConfigValue -Map $config -Key "output_dir" -DefaultValue "dist"
$workDirValue = Get-ConfigValue -Map $config -Key "work_dir" -DefaultValue "work"
$openMode = Get-ConfigValue -Map $config -Key "open_mode" -DefaultValue "browser"

$defaultPhpExtensions = @(
    "bcmath",
    "curl",
    "mbstring",
    "mysqli",
    "openssl",
    "pdo_mysql"
)
if ($phpExtensions.Count -eq 0) {
    foreach ($ext in $defaultPhpExtensions) {
        $phpExtensions.Add($ext)
    }
}

if ($phpIni.Count -eq 0) {
    $phpIni["memory_limit"] = "256M"
    $phpIni["max_execution_time"] = "60"
    $phpIni["post_max_size"] = "32M"
    $phpIni["upload_max_filesize"] = "32M"
}

$phpRuntime = $phpRuntime -replace '\\', '/'
$phpRuntimeName = Split-Path -Path $phpRuntime -Leaf
if ([string]::IsNullOrWhiteSpace($phpRuntimeName)) {
    $phpRuntimeName = "php80"
}

$appDirNormalized = ($appDir -replace '\\', '/').Trim('/')
$documentRoot = ($documentRoot -replace '\\', '/').Trim('/')
$healthcheckPath = ($healthcheckPath -replace '\\', '/')
$outputDirValue = ($outputDirValue -replace '\\', '/').Trim('/')
$workDirValue = ($workDirValue -replace '\\', '/').Trim('/')
$openMode = $openMode.Trim().ToLowerInvariant()

$entrypointNormalized = $entrypoint -replace '\\', '/'
$documentRootNormalized = $documentRoot.Trim('/')
if (-not [string]::IsNullOrWhiteSpace($documentRootNormalized)) {
    $prefix = "$documentRootNormalized/"
    if ($entrypointNormalized.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $entrypointNormalized = $entrypointNormalized.Substring($prefix.Length)
    }
}

$manifest = [ordered]@{
    manifest_version = 1
    app_name = $appName
    app_version = $appVersion
    app_dir = $appDirNormalized
    php_runtime = $phpRuntimeName
    document_root = $documentRoot
    entrypoint = $entrypointNormalized
    healthcheck_path = $healthcheckPath
    open_mode = $openMode
    output_dir = $outputDirValue
    work_dir = $workDirValue
    php_extensions_required = @($phpExtensions)
    php_ini = $phpIni
    exclude = @($excludePatterns)
}

$outputDir = Split-Path -Parent $OutputManifest
if (-not [string]::IsNullOrWhiteSpace($outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputManifest -Encoding UTF8
Write-Host "Manifest generated: $OutputManifest"