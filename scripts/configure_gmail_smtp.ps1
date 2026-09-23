param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')]
    [string]$GmailAddress,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')]
    [string]$TestRecipient,
    [switch]$SkipTest
)

$ErrorActionPreference = "Stop"
$backendDir = Join-Path $PSScriptRoot "..\backend"
$envPath = Join-Path $backendDir ".env"

if (-not (Test-Path -LiteralPath $envPath)) {
    Copy-Item -LiteralPath (Join-Path $backendDir ".env.example") -Destination $envPath
}

Write-Host "Google uygulama parolasını girin (ekranda görünmez)."
$securePassword = Read-Host -AsSecureString
$credential = [System.Net.NetworkCredential]::new("", $securePassword)
$appPassword = ($credential.Password -replace "\s", "")
if ($appPassword.Length -ne 16) {
    throw "Google uygulama parolası boşluklar çıkarıldıktan sonra 16 karakter olmalıdır."
}

$updates = [ordered]@{
    NOTIFICATION_MODE = "sandbox"
    NOTIFICATION_SANDBOX_EMAIL_ALLOWLIST = $TestRecipient
    SMTP_HOST = "smtp.gmail.com"
    SMTP_PORT = "587"
    SMTP_USER = $GmailAddress
    SMTP_PASSWORD = $appPassword
    SMTP_FROM_NAME = "NutriSense"
    SMTP_FROM_EMAIL = $GmailAddress
    SMTP_USE_TLS = "false"
    SMTP_START_TLS = "true"
}

$lines = [System.Collections.Generic.List[string]]::new()
$seen = @{}
foreach ($line in Get-Content -LiteralPath $envPath) {
    if ($line -match '^\s*([^#][^=]*)=') {
        $key = $matches[1].Trim()
        if ($updates.Contains($key)) {
            $lines.Add("$key=$($updates[$key])")
            $seen[$key] = $true
            continue
        }
    }
    $lines.Add($line)
}
foreach ($key in $updates.Keys) {
    if (-not $seen.ContainsKey($key)) {
        $lines.Add("$key=$($updates[$key])")
    }
}
[System.IO.File]::WriteAllLines($envPath, $lines, [System.Text.UTF8Encoding]::new($false))

if (-not $SkipTest) {
    $message = [System.Net.Mail.MailMessage]::new()
    try {
        $message.From = [System.Net.Mail.MailAddress]::new($GmailAddress, "NutriSense")
        $message.To.Add($TestRecipient)
        $message.Subject = "NutriSense gerçek e-posta testi"
        $message.Body = "NutriSense Gmail SMTP bağlantısı başarıyla çalışıyor. Bu ileti yalnızca doğrulanmış test adresine gönderildi."
        $message.IsBodyHtml = $false

        $smtp = [System.Net.Mail.SmtpClient]::new("smtp.gmail.com", 587)
        try {
            $smtp.EnableSsl = $true
            $smtp.UseDefaultCredentials = $false
            $smtp.Credentials = [System.Net.NetworkCredential]::new($GmailAddress, $appPassword)
            $smtp.Send($message)
        }
        finally {
            $smtp.Dispose()
        }
    }
    finally {
        $message.Dispose()
    }
}

$appPassword = $null
$credential = $null
[GC]::Collect()

Write-Host "Gmail SMTP ayarlandı. Test alıcısı: $TestRecipient"
if (-not $SkipTest) {
    Write-Host "Gerçek test e-postası Gmail SMTP tarafından kabul edildi."
}
