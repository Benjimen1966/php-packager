param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestJson,

    [Parameter(Mandatory = $true)]
    [string]$CertThumbprint,

    [string]$SignatureFile = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ManifestJson)) {
    throw "Manifest file not found: $ManifestJson"
}

if ([string]::IsNullOrWhiteSpace($SignatureFile)) {
    $SignatureFile = "$ManifestJson.sig"
}

$manifestPath = (Resolve-Path -LiteralPath $ManifestJson).Path

$thumb = ($CertThumbprint -replace '\\s', '').ToUpperInvariant()
$cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $thumb } | Select-Object -First 1
if ($null -eq $cert) {
    throw "Certificate not found in CurrentUser\\My for thumbprint: $CertThumbprint"
}
if (-not $cert.HasPrivateKey) {
    throw "Certificate does not have a private key: $CertThumbprint"
}

[byte[]]$contentBytes = [System.IO.File]::ReadAllBytes($manifestPath)
$contentInfo = [System.Security.Cryptography.Pkcs.ContentInfo]::new($contentBytes)
$signedCms = [System.Security.Cryptography.Pkcs.SignedCms]::new($contentInfo, $true)
$cmsSigner = [System.Security.Cryptography.Pkcs.CmsSigner]::new($cert)
$cmsSigner.IncludeOption = [System.Security.Cryptography.X509Certificates.X509IncludeOption]::EndCertOnly
$signedCms.ComputeSignature($cmsSigner)

[byte[]]$encoded = $signedCms.Encode()
$sigDir = Split-Path -Parent $SignatureFile
if (-not [string]::IsNullOrWhiteSpace($sigDir)) {
    New-Item -ItemType Directory -Force -Path $sigDir | Out-Null
}
$resolvedSignaturePath = Resolve-Path -LiteralPath $SignatureFile -ErrorAction SilentlyContinue
if ($null -ne $resolvedSignaturePath) {
    [System.IO.File]::WriteAllBytes($resolvedSignaturePath.Path, $encoded)
} else {
    [System.IO.File]::WriteAllBytes($SignatureFile, $encoded)
}

Write-Host "Manifest signature created: $SignatureFile"
