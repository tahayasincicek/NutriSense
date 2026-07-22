# Saha araştırması hazırlık ve karar durumu

## Hazır

- Gerçek ve sentetik kaynağı ayıran server-controlled etik kapı.
- Onamın sonuçlardan ayrı DB modeli; rastgele pseudonym ve hash'li geri çekilme kodu.
- Onaysız gerçek veri toplamayı engelleyen backend ve mobil yapılandırma kontrolü.
- Ses kaydı olmayan tanıklı sözlü onam varsayılanı; kayıtlı onam için ayrı kapı.
- Survey/usability sürüm, idempotency, güvenli mobil kuyruk ve yetkili tidy export temeli.
- Monotonik görev süresi; hata, yardım, abort, manuel düzenleme ve audit alanları.
- Survey/usability/çekilme için sentetik otomatik testler.
- Protokol, onam, DMP, işe alım, script, altı görev ve anket taslakları.

“Hazır”, saha çalışmasının yapılmış veya etik olarak onaylanmış olduğu anlamına gelmez.

## Etik kuruldan / kurumdan bekleniyor

- Başvuru ve karar referansı; protokol/onam onaylı sürümleri.
- Sorumlu araştırmacı, danışman, kurum, veri sorumlusu ve bağımsız iletişim kanalı.
- Reşitlik/yaş politikası, dahil-dışlama ve hassas grup ek güvenceleri.
- Onam ses kaydına izin verilip verilmediği.
- Her veri sınıfının retention, backup silme ve breach prosedürü.
- İşe alım kurumu/izin yazısı; ücret/ulaşım/refakatçi prosedürü.
- Veri aktarımı, üçüncü taraf servisler ve hukuki dayanak değerlendirmesi.

## Araştırmacı ve danışman kararı gerekiyor

- Birincil anlamlı fark, alfa, güç, kayıp varsayımı ve örneklem hesabı. Katılımcı sayısı henüz yoktur.
- Geleneksel koşulun nihai uygulanması ve eşdeğer görev materyalleri.
- AB/BA koşul sırası ile yiyecek seti eşleştirmesi.
- Standart ölçek kullanılıp kullanılmayacağı; mevcut anket taslaktır.
- İsteğe bağlı demografiler: yalnız analiz için zorunlu olan görme düzeyi, ekran okuyucu ve teknoloji deneyimi kategorileri.
- “Yanıtlamak istemiyorum” ve eksik veri politikası.
- Geri çekilme kodu kaybolduğunda kimlik ifşa etmeyen alternatif doğrulama.
- Manuel not redaksiyon ve nitel alıntı politikası.

## Saha öncesi teknik kabul kapıları

1. Yeni Alembic migration temiz DB ve mevcut DB kopyasında up/down testini geçer.
2. `survey_versions.schema_json` onaylı tam araç tanımını içerir.
3. Usability kayıtları koşul (`nutrisense`/`standardized_assistance`) ve AB/BA sırasını ayrı alanlarda taşır.
4. Gerçek cihazda secure storage, offline tekrar gönderim ve başarılı geri çekilme sonrası yerel silme doğrulanır.
5. Export rolü ve token rotasyonu kurum ortamında test edilir.
6. Sentetik E2E: onam → altı görev → anket → tidy export → çekilme → DB ve cihaz silme kanıtı alınır.
7. `RESEARCH_MODE=approved` yalnız gerçek kurul referansıyla deployment secret/config üzerinden açılır.

Bu kapılardan biri başarısızsa gerçek katılımcı oturumu başlatılmaz.
