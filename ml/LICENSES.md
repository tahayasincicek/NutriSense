# Veri ve yazılım kaynak envanteri

| Kaynak | Resmi sayfa | Resmi koşulun doğrulanan özeti | MVP kararı |
|---|---|---|---|
| Food-101 | https://data.vision.ee.ethz.ch/cvl/datasets_extra/food-101/ | Sayfa veri boyutu ve bölmeyi açıklar; veri lisansı yayımlamaz. | **2 Eylül 2026'da proje sahibinin kararıyla açıldı**: yalnız ticari olmayan akademik araştırma. Yeniden dağıtım yok. Sayfa hâlâ lisans metni yayımlamıyor; yazılı kurum onayı almak doğru kanıt olmaya devam ediyor. Bossard, Guillaumin ve Van Gool (2014) atfı zorunludur. |
| UEC-Food-256 | https://foodcam.mobi/dataset256.html | Yalnız ticari olmayan araştırma; diğer kullanım için iletişim gerekir. | Alan uyumsuzluğu nedeniyle MVP v1’de kullanılmıyor. |
| NutriSense kontrollü çekim | `docs/data_collection_protocol.md` | Açık rıza, fotoğraf telif izni, kişisel veri içermeme ve geri çekme süreci. | Onay kaydı doğrulanmış örnekler kullanılabilir; yeniden dağıtım varsayılan kapalı. |
| TensorFlow/Keras | https://github.com/tensorflow/tensorflow | Apache-2.0 yazılım lisansı; pretrained ağırlık provenance’i deney kaydında tutulmalıdır. | Kilitli bağımlılık olarak kullanılabilir. |

`sources/licenses.json` makine tarafından okunan kapıdır. `allowed_for_training=false` olan kaynak, dosyası mevcut olsa bile manifest oluşturamaz. Lisans metninin yokluğu izin sayılmaz. Bu envanter hukuki görüş değildir; kurum onayı gereken satırlar açıkça kapalı tutulur.
