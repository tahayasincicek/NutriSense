# ==============================================================================
# backend/run_dev.ps1
# NutriSense — yerel geliştirme sunucusu (Android Studio Terminal icin)
#
# Migration'lari uygular ve uvicorn'u reload modunda baslatir.
# Kullanim:  .\run_dev.ps1
# ==============================================================================

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

$python = Join-Path $PSScriptRoot "venv\Scripts\python.exe"
if (-not (Test-Path $python)) {
    throw "venv bulunamadi: $python"
}

Write-Host "[1/2] Migration'lar uygulaniyor..." -ForegroundColor Cyan
& $python -m alembic upgrade head
if ($LASTEXITCODE -ne 0) { throw "alembic upgrade head basarisiz." }

Write-Host "[2/2] Uvicorn baslatiliyor (http://127.0.0.1:8000)..." -ForegroundColor Cyan
& $python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
