$ErrorActionPreference = "Stop"

$backendDirectory = Split-Path -Parent $PSScriptRoot
$runtimeEnvFile = Join-Path $backendDirectory ".runtime\staging.env"
$composeFile = Join-Path $backendDirectory "compose.staging.yml"

if (-not (Test-Path -LiteralPath $runtimeEnvFile)) {
    Write-Output "STAGING_LOCAL=ALREADY_STOPPED"
    exit 0
}

docker compose --env-file $runtimeEnvFile -f $composeFile down
if ($LASTEXITCODE -ne 0) { throw "Local staging environment could not stop." }
Write-Output "STAGING_LOCAL=STOPPED data_volume=preserved"
