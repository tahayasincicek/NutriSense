# ==============================================================================
# backend/run_dev.ps1
# NutriSense — yerel geliştirme yığını (Android Studio Terminal / Run icin)
#
# MySQL, Mailpit ve backend'i Docker Compose ile ayaga kaldirir. Proje raporu
# geregi veritabani MySQL'dir; SQLite kullanilmaz.
#
# Kullanim:  .\run_dev.ps1
# ==============================================================================

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

Write-Host "[1/3] Docker calisiyor mu kontrol ediliyor..." -ForegroundColor Cyan
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Docker Desktop calismiyor. Once Docker Desktop'i acin."
}

Write-Host "[2/3] MySQL, Mailpit ve backend baslatiliyor..." -ForegroundColor Cyan
docker compose up -d --build backend
if ($LASTEXITCODE -ne 0) { throw "docker compose up basarisiz." }

Write-Host "[3/3] Backend hazir olana kadar bekleniyor..." -ForegroundColor Cyan
$ready = $false
foreach ($attempt in 1..30) {
    Start-Sleep -Seconds 2
    try {
        $response = Invoke-RestMethod -Uri "http://127.0.0.1:8000/health" -TimeoutSec 3
        if ($response.status -eq "ready") { $ready = $true; break }
    } catch {
        # Container henuz acilmadi; beklemeye devam.
    }
}
if (-not $ready) {
    docker compose logs --tail 40 backend
    throw "Backend 60 saniyede hazir olmadi. Yukaridaki loglara bakin."
}

Write-Host ""
Write-Host "Hazir." -ForegroundColor Green
Write-Host "  API      : http://127.0.0.1:8000"
Write-Host "  Dokuman  : http://127.0.0.1:8000/docs"
Write-Host "  Mailpit  : http://localhost:8025"
Write-Host "  Emulator : http://10.0.2.2:8000/api/v1"
Write-Host ""
Write-Host "Durdurmak icin: docker compose stop" -ForegroundColor DarkGray
