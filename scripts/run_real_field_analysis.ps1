param(
    [string]$BaseUrl = "http://127.0.0.1:8000/api/v1",
    [string]$PythonExecutable = "analysis/.venv/Scripts/python.exe"
)

$ErrorActionPreference = "Stop"

$exportToken = [Environment]::GetEnvironmentVariable("RESEARCH_EXPORT_TOKEN")
if ([string]::IsNullOrWhiteSpace($exportToken)) {
    throw "RESEARCH_EXPORT_TOKEN ortam değişkeni tanımlı değil. Tokeni komut satırına yazmayın."
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$realDataDirectory = Join-Path $repositoryRoot "analysis/data/real"
$pythonPath = Join-Path $repositoryRoot $PythonExecutable

if (-not (Test-Path -LiteralPath $pythonPath)) {
    throw "Analiz Python çalıştırıcısı bulunamadı: $pythonPath"
}

$headers = @{ "X-Research-Export-Token" = $exportToken }
$survey = Invoke-RestMethod `
    -Uri "$BaseUrl/survey/export/tidy" `
    -Headers $headers `
    -Method Get
$usability = Invoke-RestMethod `
    -Uri "$BaseUrl/usability/export/tidy" `
    -Headers $headers `
    -Method Get

if ([int]$survey.row_count -le 0 -or [int]$usability.row_count -le 0) {
    throw "Gerçek anket ve kullanılabilirlik kayıtları birlikte bulunmadan analiz başlatılmaz."
}

$invalidOrigins = @($survey.rows + $usability.rows) | Where-Object {
    $_.data_origin -ne "participant"
}
if ($invalidOrigins.Count -gt 0) {
    throw "Dışa aktarım participant dışında veri içeriyor; gerçek analiz durduruldu."
}

New-Item -ItemType Directory -Path $realDataDirectory -Force | Out-Null
$surveyPath = Join-Path $realDataDirectory "survey_tidy.json"
$usabilityPath = Join-Path $realDataDirectory "usability_tidy.json"

$survey | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $surveyPath -Encoding utf8
$usability | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $usabilityPath -Encoding utf8

Push-Location $repositoryRoot
try {
    & $pythonPath "analysis/run_analysis.py" --mode real
    if ($LASTEXITCODE -ne 0) {
        throw "Gerçek analiz kalite kapısında başarısız oldu."
    }
}
finally {
    Pop-Location
}

Write-Output "REAL_FIELD_ANALYSIS=PASS"
Write-Output "Survey rows: $($survey.row_count)"
Write-Output "Usability rows: $($usability.row_count)"
