# Güvenlik olayı ve secret rotasyon runbook'u

Sürüm: 1.0

Tarih: 2026-07-26

Gerçek secret değeri ticket, terminal çıktısı, commit mesajı, ekran görüntüsü
veya bu runbook'a yazılmaz. Yalnız secret adı, sahibi, durum ve rotasyon zamanı
kaydedilir.

## Roller

| Rol | Sorumluluk | Atanacak kişi |
|---|---|---|
| Olay yöneticisi | Kapsam, karar ve iletişim | `[KURUM KARARI]` |
| Teknik müdahale | Revoke/rotate/deploy | `[DEVOPS]` |
| Veri sorumlusu irtibatı | KVKK ve ilgili kişi değerlendirmesi | `[KURUM KARARI]` |
| Araştırma sorumlusu | Etik kurul/katılımcı etkisi | `[ARAŞTIRMACI]` |
| Hukuk/iletişim | Bildirim metni ve zorunluluk | `[KURUM KARARI]` |

## İlk 60 dakika

1. Olay kimliği ve UTC başlangıç zamanı oluşturun; secret değerini kopyalamayın.
2. Etkilenen sistemi salt okunur kanıtla belirleyin: secret adı, dosya yolu,
   commit kısa SHA, provider audit zamanı, etkilenen hesap sayısı.
3. Açık yayın/CI/deploy'i durdurun; kullanıcı verisini silmeyin.
4. Etkilenen credential'ı sağlayıcı panelinden revoke edin. Önce yeni
   credential üretin, secret store'a koyun, tüketiciyi deploy edin; sonra eskiyi
   kapatın. Aktif kötüye kullanım varsa eskiyi beklemeden kapatın.
5. JWT signing secret etkilenmişse tüm refresh tokenları revoke edin ve
   kullanıcıları yeniden girişe zorlayın.
6. Log, DB ve provider audit kayıtlarını erişim kontrollü olarak koruyun.
7. Veri sorumlusu/hukuk/etik araştırma sorumlusuna olay sınıfını bildirin.

## Rotasyon sırası

| Secret/anahtar | Rotasyon eylemi | Ek etki |
|---|---|---|
| JWT signing secret | Yeni güçlü değer, deploy, tüm refresh token revoke | Tüm oturumlar kapanır |
| Application secret | Yeni değer ve rolling deploy | İmzalı/veri türevi kullanımı ayrıca incelenir |
| DB credential | Yeni sınırlı kullanıcı/parola, bağlantı testi, eski revoke | Aktif connection pool yenilenir |
| Google service account | Yeni key/workload identity, eski key delete | Provider audit ve proje IAM incelemesi |
| Nutritionix | Yeni app key, backend secret store, eski revoke | Mobil binary/repo taranır |
| Twilio | Auth token/API key rotate, messaging audit | Yanlış alıcı/mesaj geçmişi incelenir |
| SMTP | App password/credential rotate | Mail provider sent/audit kayıtları incelenir |
| Research export token | Yeni token, export erişim logu incelemesi | Tüm araştırmacı erişimleri yeniden yetkilendirilir |
| Android/iOS signing | Platform sağlayıcı prosedürü | Uygulama güncelleme zinciri etkilenebilir; uzman onayı gerekir |

## Git geçmişinde secret

1. `python scripts/security/secret_scan.py --history` çalıştırın. Çıktı yalnız
   kural/yol/kısa revision göstermelidir.
2. Önce credential'ı revoke/rotate edin; yalnız dosyadan silmek yeterli değildir.
3. Geçmiş yeniden yazımı gerekiyorsa depo sahibi ve tüm katkıcılarla koordine
   edin. `git filter-repo` gibi işlem force-push ve clone yenilemesi gerektirir;
   otomatik veya tek başına yapılmaz.
4. GitHub cache, Actions artefaktı, package/container registry ve fork
   kopyalarını ayrıca değerlendirin.
5. Secret scanner kuralına güvenli regresyon fixture'ı ekleyin; değeri fixture'a
   kopyalamayın.

## Olay sınıflandırması

| Seviye | Örnek | Teknik hedef |
|---|---|---|
| SEV-1 Kritik | Aktif token/DB/provider secret sızıntısı; sağlık verisi erişimi | Derhal revoke/izolasyon, olay ekibi |
| SEV-2 Yüksek | IDOR, yanlış rapor alıcısı, görüntü/log sızıntısı şüphesi | Aynı gün containment ve kapsam |
| SEV-3 Orta | Exploit kanıtı olmayan yüksek bağımlılık açığı | Risk bazlı hızlı patch |
| SEV-4 Düşük | Hardening/yanlış dokümantasyon | Planlı düzeltme |

Yasal bildirim süresi bu teknik belge tarafından uydurulmaz; veri sorumlusu ve
hukuk birimi somut olayda güncel mevzuata göre karar verir.

## Kurtarma ve kapanış

- Yeni credential ile health/readiness, auth, IDOR, report consent ve
  log-redaction testleri geçmelidir.
- `pip-audit`, secret scan ve Trivy temiz olmalıdır.
- Etkilenen provider audit'inde yetkisiz çağrı/mesaj/alıcı aranmalıdır.
- Backup ve downstream kopyalara silme/rotasyon işlemi uygulanmalıdır.
- Olay özeti; kök neden, zaman çizelgesi, veri sınıfları, kararlar, düzeltme
  commit'i ve tekrar önleme maddelerini içermelidir; secret/PII içermez.
- Olay yöneticisi, veri sorumlusu ve gerekirse etik kurul kapanışı onaylar.
