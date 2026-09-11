$ErrorActionPreference = "Stop"

$backendDirectory = Split-Path -Parent $PSScriptRoot
$runtimeDirectory = Join-Path $backendDirectory ".runtime"
$runtimeEnvFile = Join-Path $runtimeDirectory "staging.env"
$composeFile = Join-Path $backendDirectory "compose.staging.yml"

function New-RandomHex([int]$byteCount) {
    $bytes = New-Object byte[] $byteCount
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
    }
    finally {
        $generator.Dispose()
    }
    return ([BitConverter]::ToString($bytes) -replace "-", "").ToLowerInvariant()
}

if (-not (Test-Path -LiteralPath $runtimeDirectory)) {
    New-Item -ItemType Directory -Path $runtimeDirectory | Out-Null
}

if (-not (Test-Path -LiteralPath $runtimeEnvFile)) {
    $revision = (git -C (Split-Path -Parent $backendDirectory) rev-parse --short=12 HEAD 2>$null)
    if (-not $revision) { $revision = "local" }
    $created = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    $values = @(
        "APP_VERSION=0.0.0-staging",
        "BUILD_REVISION=$revision",
        "BUILD_CREATED=$created",
        "DB_PASSWORD=$(New-RandomHex 24)",
        "DB_ROOT_PASSWORD=$(New-RandomHex 24)",
        "SECRET_KEY=$(New-RandomHex 32)",
        "JWT_SECRET_KEY=$(New-RandomHex 32)",
        "RESEARCH_EXPORT_TOKEN=$(New-RandomHex 32)",
        "RESEARCH_PSEUDONYMIZATION_KEY=$(New-RandomHex 32)",
        "OPERATIONS_TOKEN=$(New-RandomHex 32)"
    )
    [System.IO.File]::WriteAllLines($runtimeEnvFile, $values)
}

docker compose --env-file $runtimeEnvFile -f $composeFile up --build --detach --wait
if ($LASTEXITCODE -ne 0) { throw "Local staging Compose could not start." }

$operationsToken = (
    Get-Content -LiteralPath $runtimeEnvFile |
    Where-Object { $_.StartsWith("OPERATIONS_TOKEN=") } |
    Select-Object -First 1
).Substring("OPERATIONS_TOKEN=".Length)
$env:NUTRISENSE_OPERATIONS_TOKEN = $operationsToken
try {
    py -3 (Join-Path $PSScriptRoot "smoke_staging.py") `
        --base-url "http://127.0.0.1:8000"
    if ($LASTEXITCODE -ne 0) { throw "Local staging smoke test failed." }
}
finally {
    Remove-Item Env:NUTRISENSE_OPERATIONS_TOKEN -ErrorAction SilentlyContinue
}

Write-Output "STAGING_LOCAL=READY url=http://127.0.0.1:8000 mail=http://127.0.0.1:8025"
