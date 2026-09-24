param(
    [string]$DeviceModel,
    [string]$IosVersion,
    [string]$EvidenceFile
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$evidenceDirectory = Join-Path $repositoryRoot "delivery_evidence"
$filesDirectory = Join-Path $evidenceDirectory "files"
$target = Join-Path $evidenceDirectory "voiceover_acceptance.json"

& (Join-Path $PSScriptRoot "initialize_tubitak_evidence.ps1") | Out-Null

if ([string]::IsNullOrWhiteSpace($DeviceModel)) {
    $DeviceModel = Read-Host "Test edilen iPhone modeli"
}
if ([string]::IsNullOrWhiteSpace($IosVersion)) {
    $IosVersion = Read-Host "iOS sürümü"
}
if ([string]::IsNullOrWhiteSpace($EvidenceFile)) {
    $EvidenceFile = Read-Host "Oturum notu veya ekran kaydı dosyasının tam yolu"
}
if (-not (Test-Path -LiteralPath $EvidenceFile -PathType Leaf)) {
    throw "Kanıt dosyası bulunamadı: $EvidenceFile"
}

$scenarioNames = [ordered]@{
    first_launch_consent = "İlk açılış ve aydınlatma"
    registration_login = "Kayıt ve giriş"
    camera_permission_denied = "Kamera izni reddi"
    gallery_analysis = "Galeriden fotoğraf ve analiz"
    food_confirmation = "Besin ve porsiyon onayı"
    history_and_undo = "Geçmiş ve geri alma"
    dietitian_sharing = "Diyetisyen paylaşımı"
    tts_stt_interruption = "TTS/STT ekran geçişi"
    large_text_dark_theme = "%200 metin ve koyu tema"
}

$scenarios = @()
foreach ($item in $scenarioNames.GetEnumerator()) {
    do {
        $answer = (Read-Host "$($item.Value) sonucu (pass/fail)").Trim().ToLowerInvariant()
    } while ($answer -notin @("pass", "fail"))
    $scenarios += [ordered]@{ id = $item.Key; result = $answer }
}

New-Item -ItemType Directory -Path $filesDirectory -Force | Out-Null
$extension = [IO.Path]::GetExtension($EvidenceFile)
$storedName = "voiceover-{0}{1}" -f (Get-Date -Format "yyyyMMdd-HHmmss"), $extension
$storedPath = Join-Path $filesDirectory $storedName
Copy-Item -LiteralPath $EvidenceFile -Destination $storedPath

$revision = (git -C $repositoryRoot rev-parse HEAD).Trim()
$record = [ordered]@{
    device_model = $DeviceModel.Trim()
    ios_version = $IosVersion.Trim()
    app_revision = $revision
    tested_at = (Get-Date).ToString("o")
    scenarios = $scenarios
    evidence_files = @("delivery_evidence/files/$storedName")
}
$record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $target -Encoding utf8
Write-Output "VOICEOVER_ACCEPTANCE_RECORDED=$target"
