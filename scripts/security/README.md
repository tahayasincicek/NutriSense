# Güvenlik tarama araçları

Secret taraması eşleşen değerleri veya kaynak satırlarını hiçbir zaman yazdırmaz:

```powershell
python scripts/security/secret_scan.py --history
```

Bir bulgu varsa yalnız kural kimliği, dosya yolu ve kısaltılmış commit kimliği
gösterilir. Bulgu değerini terminale çıkarmadan ilgili sağlayıcının anahtarını
iptal edin ve `docs/runbooks/security_incident_and_secret_rotation.md`
prosedürünü uygulayın.
