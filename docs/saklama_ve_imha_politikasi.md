# Saklama ve imha politikası 

**Durum: teknik taslak — hukuki/kurumsal onay bekliyor.** Tablodaki teknik
mekanizmalar uygulanmıştır; süreler ayarlardan değiştirilebilir. Kurum ve
hukukçu, özellikle yedekler ile sağlayıcı kopyalarının sürelerini yayın öncesi
karara bağlamalıdır.

| Veri | Saklama süresi | Süre sonunda | Mekanizma |
|---|---|---|---|
| Hesap bilgileri (ad, e-posta, telefon, parola özeti, tercihler) | Hesap açık olduğu sürece | Silme | Uygulamada Hesabı Sil veya `/hesap-silme` başvurusu |
| Besin kayıtları | Hesap açık olduğu sürece | Silme | Hesap silmede birlikte |
| Su, adım, uyku, ruh hâli ve kilo ölçümleri | Hesap açık olduğu sürece | Silme | Hesap silmede birlikte |
| İlaç ve takviye listesi | Yalnız cihazda; kullanıcı silene, çıkış yapana veya hesabını silene kadar | Silme | Cihazın şifreli deposu; sunucuya gönderilmez |
| Çevrim dışı beslenme geçmişi | Son yazımdan sonra 7 gün veya çıkış/hesap silmeye kadar | Silme | Cihazın şifreli deposunda süre denetimi ve oturum temizliği |
| İzinli yanlış tahmin fotoğrafları | Kullanıcı Ayarlar'dan silene, çıkış yapana veya hesabını silene kadar | Silme | Yalnız küçültülmüş/EXIF'siz yerel kopya; sunucuya gönderilmez |
| Diyetisyen raporları, diyetisyen notları, rıza kayıtları | Hesap açık olduğu sürece | Silme | Hesap silmede birlikte |
| Doğrulanmamış kayıt başvuruları (e-posta, ad, parola özeti, kod özeti) | 30 dakika | Silme | Periyodik imha |
| Karara bağlanmamış tanıma denemeleri | 7 gün | Silme | Periyodik imha |
| Süresi dolmuş veya iptal edilmiş oturum anahtarları | Süre dolduktan sonra 7 gün | Silme | Periyodik imha |
| Kullanılmış veya süresi dolmuş parola sıfırlama kodları | 7 gün | Silme | Periyodik imha |
| Güvenlik kayıtlarındaki IP adresi | 90 gün | Alan boşaltılır | Periyodik imha |
| Güvenlik kayıtları (olay türü, anahtarlı e-posta özeti) | 365 gün | Silme | Periyodik imha; hesap silmede kullanıcı bağlantısı hemen kaldırılır |
| İmha kayıtları | En az 3 yıl | — | Periyodik imha bu kayıtları silmez |
| Veritabanı yedekleri | `[KURUM KARARI]` | Yedek döngüsüyle silme | `docs/backup_restore_plan.md` |
| E-posta ve SMS sağlayıcısındaki bildirim kopyaları (sağlık verisi içermez) | Sağlayıcı sözleşmesine göre `[HUKUK İNCELEMESİ]` | — | `docs/yurt_disi_aktarim_matrisi.md` |
| Araştırma verisi (takma kimlikli) | Etik kurul onaylı protokoldeki süre | Silme veya anonimleştirme | Çekilme kodu; `docs/research/data_management_plan.md` |
| Paylaşılan CSV ve JSON dosyaları | Paylaşım bitene kadar | Silme | Uygulama geçici dosyayı paylaşımdan sonra siler |

## Periyodik imha

Backend klasöründe:

```bash
python scripts/purge_expired_data.py
```

Günlük çalıştırılması önerilir; KVKK'da periyodik imha aralığı altı ayı
geçemez. Her çalıştırma, silinen ve boşaltılan kayıt sayılarını içeren ve
kişisel veri taşımayan bir `retention_purge` imha kaydı yazar.

| Ayar | Varsayılan |
|---|---|
| `AUDIT_IP_RETENTION_DAYS` | 90 |
| `AUDIT_EVENT_RETENTION_DAYS` | 365 |
| `STALE_RECORD_RETENTION_DAYS` | 7 |

