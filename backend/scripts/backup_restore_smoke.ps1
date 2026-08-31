$ErrorActionPreference = "Stop"

$backendDirectory = Split-Path -Parent $PSScriptRoot
$runtimeEnvFile = Join-Path $backendDirectory ".runtime\staging.env"
$composeFile = Join-Path $backendDirectory "compose.staging.yml"
$containerScript = Join-Path $PSScriptRoot "backup_restore_smoke.sh"

if (-not (Test-Path -LiteralPath $runtimeEnvFile)) {
    throw "Run scripts\staging_up.ps1 before this check."
}

docker compose --env-file $runtimeEnvFile -f $composeFile `
    cp $containerScript db:/tmp/backup_restore_smoke.sh
if ($LASTEXITCODE -ne 0) { throw "Backup smoke script copy failed." }

try {
    docker compose --env-file $runtimeEnvFile -f $composeFile `
        exec -T db sh /tmp/backup_restore_smoke.sh
    if ($LASTEXITCODE -ne 0) {
        throw "Synthetic backup/restore integrity check failed."
    }
}
finally {
    docker compose --env-file $runtimeEnvFile -f $composeFile `
        exec -T db rm -f /tmp/backup_restore_smoke.sh
}
