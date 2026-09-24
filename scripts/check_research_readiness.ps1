param(
    [string]$BaseUrl = "http://127.0.0.1:8000"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$environmentPath = Join-Path $repositoryRoot "backend/.env"
$required = @(
    "RESEARCH_MODE",
    "RESEARCH_PROTOCOL_VERSION",
    "RESEARCH_CONSENT_VERSION",
    "RESEARCH_APPROVAL_REFERENCE",
    "RESEARCH_PSEUDONYMIZATION_KEY",
    "RESEARCH_EXPORT_TOKEN"
)

if (-not (Test-Path -LiteralPath $environmentPath)) {
    Write-Output "[BLOCKED] backend/.env bulunamadı."
    exit 2
}

$values = @{}
Get-Content -LiteralPath $environmentPath | ForEach-Object {
    if ($_ -match '^\s*([^#][A-Z0-9_]+)\s*=\s*(.*)\s*$') {
        $values[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'")
    }
}

$blocked = $false
foreach ($key in $required) {
    $value = [string]$values[$key]
    $placeholder = [string]::IsNullOrWhiteSpace($value) -or
        $value -match '(?i)^(todo|changeme|placeholder|example|draft|pending)$'
    if ($key -eq "RESEARCH_MODE") {
        $placeholder = $value -ne "approved"
    }
    if ($placeholder) {
        Write-Output "[BLOCKED] $key gerçek ve onaylı değer bekliyor."
        $blocked = $true
    }
    else {
        Write-Output "[PASS] $key yapılandırıldı."
    }
}

try {
    $health = Invoke-RestMethod -Uri "$BaseUrl/health/ready" -TimeoutSec 5
    Write-Output "[PASS] Backend hazırlık endpointi yanıt verdi."
}
catch {
    Write-Output "[BLOCKED] Backend hazır değil: $BaseUrl/health/ready"
    $blocked = $true
}

if ($blocked) {
    Write-Output "RESEARCH_COLLECTION_READINESS=BLOCKED"
    exit 2
}

Write-Output "RESEARCH_COLLECTION_READINESS=PASS"
