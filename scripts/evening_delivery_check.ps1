$ErrorActionPreference = "Continue"
$repositoryRoot = Split-Path -Parent $PSScriptRoot

Push-Location $repositoryRoot
try {
    Write-Output "=== 1. Yerel kanıt dosyaları ==="
    & .\scripts\initialize_tubitak_evidence.ps1

    Write-Output "=== 2. Araştırma toplama hazırlığı ==="
    & .\scripts\check_research_readiness.ps1

    Write-Output "=== 3. SMS hariç TÜBİTAK teslim kapısı ==="
    & .\scripts\verify_tubitak_delivery.ps1

    Write-Output "=== Akşam kullanılacak komutlar ==="
    Write-Output "VoiceOver: .\scripts\record_voiceover_acceptance.ps1"
    Write-Output "Yaygınlaştırma: .\scripts\record_dissemination_evidence.ps1"
    Write-Output "Gerçek analiz: .\scripts\run_real_field_analysis.ps1"
    Write-Output "Son kontrol: .\scripts\verify_tubitak_delivery.ps1"
}
finally {
    Pop-Location
}
