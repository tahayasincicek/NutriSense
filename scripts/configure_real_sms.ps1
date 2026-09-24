param(
    [ValidateSet("twilio", "iletimerkezi")]
    [string]$Provider = "twilio",
    [string]$TrialPhone
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$environmentPath = Join-Path $repositoryRoot "backend/.env"

if (-not (Test-Path -LiteralPath $environmentPath)) {
    throw "backend/.env bulunamadı. Önce 'py -3 scripts/dev_setup.py' çalıştırın."
}
if ([string]::IsNullOrWhiteSpace($TrialPhone)) {
    $TrialPhone = (Read-Host "Doğrulanmış deneme telefonu (+905...)").Trim()
}
if ($TrialPhone -notmatch '^\+[1-9][0-9]{7,14}$') {
    throw "Telefon E.164 biçiminde olmalıdır; ör. +905xxxxxxxxx."
}

function Read-Secret([string]$Prompt) {
    $secure = Read-Host $Prompt -AsSecureString
    return [System.Net.NetworkCredential]::new("", $secure).Password
}

function Set-EnvValue([string]$Key, [string]$Value) {
    $lines = [System.Collections.Generic.List[string]]::new()
    Get-Content -LiteralPath $environmentPath | ForEach-Object { [void]$lines.Add($_) }
    $found = $false
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match "^$([regex]::Escape($Key))=") {
            $lines[$index] = "$Key=$Value"
            $found = $true
        }
    }
    if (-not $found) { [void]$lines.Add("$Key=$Value") }
    $lines | Set-Content -LiteralPath $environmentPath -Encoding utf8
}

Set-EnvValue "NOTIFICATION_MODE" "sandbox"
Set-EnvValue "SMS_PROVIDER_MODE" $Provider
Set-EnvValue "NOTIFICATION_SANDBOX_PHONE_ALLOWLIST" $TrialPhone

if ($Provider -eq "twilio") {
    $sid = (Read-Host "Twilio Account SID (AC ile başlayan 34 karakter)").Trim()
    $token = Read-Secret "Twilio Auth Token"
    $from = (Read-Host "Twilio gönderici numarası (+ ile başlayan)").Trim()
    if ($sid -notmatch '^AC[0-9a-fA-F]{32}$') { throw "Twilio Account SID biçimi geçersiz." }
    if ($token -notmatch '^[0-9a-fA-F]{32}$') { throw "Twilio Auth Token biçimi geçersiz." }
    if ($from -notmatch '^\+[1-9][0-9]{7,14}$') {
        throw "Twilio gönderici numarası E.164 biçiminde olmalıdır."
    }
    Set-EnvValue "TWILIO_ACCOUNT_SID" $sid
    Set-EnvValue "TWILIO_AUTH_TOKEN" $token
    Set-EnvValue "TWILIO_PHONE_NUMBER" $from
}
else {
    $apiKey = Read-Secret "iletiMerkezi API key"
    $apiHash = Read-Secret "iletiMerkezi API hash"
    $sender = (Read-Host "iletiMerkezi gönderici başlığı").Trim()
    if ([string]::IsNullOrWhiteSpace($apiKey) -or [string]::IsNullOrWhiteSpace($apiHash)) {
        throw "iletiMerkezi API key ve hash boş olamaz."
    }
    if ([string]::IsNullOrWhiteSpace($sender) -or $sender.Length -gt 11) {
        throw "Gönderici başlığı 1-11 karakter olmalıdır."
    }
    Set-EnvValue "ILETIMERKEZI_API_KEY" $apiKey
    Set-EnvValue "ILETIMERKEZI_API_HASH" $apiHash
    Set-EnvValue "ILETIMERKEZI_SENDER" $sender
}

Write-Output "SMS_CONFIG_WRITTEN=PASS provider=$Provider"
Write-Output "Secret değerler yalnız backend/.env dosyasına yazıldı ve Git'e eklenmez."
Write-Output "Sonraki adım: docker compose -f backend/docker-compose.yml up -d --build --wait"
Write-Output "Deneme: cd backend; `$env:PYTHONPATH='.'; .\venv\Scripts\python.exe scripts\send_sms_smoke.py --trial --phone '$TrialPhone' --confirm SEND_REAL_SMS"
