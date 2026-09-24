$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$evidenceDirectory = Join-Path $repositoryRoot "delivery_evidence"
$filesDirectory = Join-Path $evidenceDirectory "files"

New-Item -ItemType Directory -Path $filesDirectory -Force | Out-Null

$templates = @(
    @{
        Source = Join-Path $evidenceDirectory "voiceover_acceptance.example.json"
        Target = Join-Path $evidenceDirectory "voiceover_acceptance.json"
    },
    @{
        Source = Join-Path $evidenceDirectory "dissemination.example.json"
        Target = Join-Path $evidenceDirectory "dissemination.json"
    }
)

foreach ($template in $templates) {
    if (-not (Test-Path -LiteralPath $template.Target)) {
        Copy-Item -LiteralPath $template.Source -Destination $template.Target
        Write-Output "CREATED=$($template.Target)"
    }
    else {
        Write-Output "PRESERVED=$($template.Target)"
    }
}

Write-Output "EVIDENCE_FILES_DIRECTORY=$filesDirectory"
Write-Output "TUBITAK_EVIDENCE_INITIALIZED=PASS"
