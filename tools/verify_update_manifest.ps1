param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestJson,

    [Parameter(Mandatory = $true)]
    [string]$SignatureFile,

    [string]$ExpectedSignerThumbprint = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ManifestJson)) {
    throw "Manifest file not found: $ManifestJson"
}
if (-not (Test-Path -LiteralPath $SignatureFile)) {
    throw "Manifest signature not found: $SignatureFile"
}

$manifestPath = (Resolve-Path -LiteralPath $ManifestJson).Path
$signaturePath = (Resolve-Path -LiteralPath $SignatureFile).Path

[byte[]]$contentBytes = [System.IO.File]::ReadAllBytes($manifestPath)
[byte[]]$signatureBytes = [System.IO.File]::ReadAllBytes($signaturePath)

$contentInfo = [System.Security.Cryptography.Pkcs.ContentInfo]::new($contentBytes)
$signedCms = [System.Security.Cryptography.Pkcs.SignedCms]::new($contentInfo, $true)
$signedCms.Decode($signatureBytes)
$signedCms.CheckSignature($true)

if ($signedCms.SignerInfos.Count -lt 1) {
    throw "Signature does not contain signer info."
}

$thumb = ($signedCms.SignerInfos[0].Certificate.Thumbprint -replace '\\s', '').ToUpperInvariant()
if ([string]::IsNullOrWhiteSpace($thumb)) {
    throw "Unable to resolve signer thumbprint from signature."
}

if (-not [string]::IsNullOrWhiteSpace($ExpectedSignerThumbprint)) {
    $expected = ($ExpectedSignerThumbprint -replace '\\s', '').ToUpperInvariant()
    if ($thumb -ne $expected) {
        throw "Signer thumbprint mismatch. Expected=$ExpectedSignerThumbprint Actual=$thumb"
    }
}

Write-Output $thumb
