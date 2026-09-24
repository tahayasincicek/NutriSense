param(
    [string]$Title,
    [string]$Venue,
    [string]$Date,
    [ValidateSet("presented", "published")]
    [string]$Status,
    [string]$PublicUrl,
    [string]$EvidenceFile
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$evidenceDirectory = Join-Path $repositoryRoot "delivery_evidence"
$filesDirectory = Join-Path $evidenceDirectory "files"
$target = Join-Path $evidenceDirectory "dissemination.json"

& (Join-Path $PSScriptRoot "initialize_tubitak_evidence.ps1") | Out-Null

if ([string]::IsNullOrWhiteSpace($Title)) { $Title = Read-Host "Sunum/yayın başlığı" }
if ([string]::IsNullOrWhiteSpace($Venue)) { $Venue = Read-Host "Etkinlik/yayın adı" }
if ([string]::IsNullOrWhiteSpace($Date)) { $Date = Read-Host "Tarih (YYYY-MM-DD)" }
if ([string]::IsNullOrWhiteSpace($Status)) {
    $Status = (Read-Host "Durum (presented/published)").Trim().ToLowerInvariant()
}
if ($Status -notin @("presented", "published")) {
    throw "Durum yalnız presented veya published olabilir."
}
try { [void][datetime]::ParseExact($Date, "yyyy-MM-dd", $null) }
catch { throw "Tarih YYYY-MM-DD biçiminde olmalı." }

if ([string]::IsNullOrWhiteSpace($PublicUrl) -and [string]::IsNullOrWhiteSpace($EvidenceFile)) {
    $PublicUrl = Read-Host "Herkese açık kanıt URL'si (yoksa boş bırakın)"
    if ([string]::IsNullOrWhiteSpace($PublicUrl)) {
        $EvidenceFile = Read-Host "Katılım/sunum kanıtı dosyasının tam yolu"
    }
}

$storedRelative = ""
if (-not [string]::IsNullOrWhiteSpace($EvidenceFile)) {
    if (-not (Test-Path -LiteralPath $EvidenceFile -PathType Leaf)) {
        throw "Kanıt dosyası bulunamadı: $EvidenceFile"
    }
    New-Item -ItemType Directory -Path $filesDirectory -Force | Out-Null
    $extension = [IO.Path]::GetExtension($EvidenceFile)
    $storedName = "dissemination-{0}{1}" -f (Get-Date -Format "yyyyMMdd-HHmmss"), $extension
    Copy-Item -LiteralPath $EvidenceFile -Destination (Join-Path $filesDirectory $storedName)
    $storedRelative = "delivery_evidence/files/$storedName"
}

$record = [ordered]@{
    events = @([ordered]@{
        title = $Title.Trim()
        venue = $Venue.Trim()
        date = $Date
        status = $Status
        public_url = $PublicUrl.Trim()
        evidence_file = $storedRelative
    })
}
$record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $target -Encoding utf8
Write-Output "DISSEMINATION_EVIDENCE_RECORDED=$target"
