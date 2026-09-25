$Mode = if ($args.Count -gt 0) { $args[0] } else { "Project" }
if ($Mode -notin @("Project", "ExternalEvidence")) {
    throw "Mod Project veya ExternalEvidence olmalıdır."
}
$gateMode = if ($Mode -eq "ExternalEvidence") { "external-evidence" } else { "project" }

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$env:PYTHONIOENCODING = "utf-8"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$venvPython = Join-Path $repositoryRoot "analysis/.venv/Scripts/python.exe"

Push-Location $repositoryRoot
try {
    if (Test-Path -LiteralPath $venvPython) {
        & $venvPython "scripts/qa/tubitak_delivery_gate.py" --mode $gateMode
    }
    elseif (Get-Command py -ErrorAction SilentlyContinue) {
        & py -3 "scripts/qa/tubitak_delivery_gate.py" --mode $gateMode
    }
    elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
        & python3 "scripts/qa/tubitak_delivery_gate.py" --mode $gateMode
    }
    else {
        throw "Python bulunamadı. Önce analysis/README.md kurulumunu uygulayın."
    }
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
