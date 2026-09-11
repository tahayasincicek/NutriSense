# Araştırma veri yönetim planı ve veri sözlüğü

## 1. İlkeler ve veri akışı

Veri minimizasyonu, amaçla sınırlılık, least privilege, sürümleme ve audit uygulanır. Hesap UUID'si araştırma kimliği değildir. Backend onam sırasında rastgele UUID pseudonym üretir; ad/e-posta/telefonla eşleme sonuç sisteminde tutulmaz. Dışa aktarım sırasında veritabanındaki katılımcı, form ve oturum UUID'leri ayrıca HMAC-SHA-256 ile kararlı takma kodlara çevrilir. Böylece aynı katılımcının satırları analizde eşleşir, fakat veritabanı kimlikleri araştırma paketine çıkmaz.

Akış: erişilebilir onam → ayrı `research_consents` kaydı → görev/anket → mobil güvenli kasa geçici kuyruğu → TLS üzerinden backend → yetkili tidy export → sürümlü analiz alanı → kurulca onaylanan tarihte imha/anonymization.

Mobilde bekleyen payload `flutter_secure_storage` içindedir. Başarılı senkronizasyonda kuyruktan çıkar; yeniden deneme aynı kayıt UUID'sini `Idempotency-Key` yapar. Gerçek katılımcı modunda cihazdan yerel export engellenir. Uygulama silme, cihaz yedekleme ve platform secure-storage davranışı gerçek cihaz doğrulamasına tabidir.

## 2. Veri sınıfları ve sahiplik

| Sınıf | Örnek | Sahip/erişim | Son işlem |
|---|---|---|---|
| Onam kanıtı | sürüm, yöntem, tanık/kanıt ref. | sorumlu araştırmacı; ayrı depo | kurul takvimine göre imha/minimal audit |
| Araştırma sonucu | görev, süre, hata, anket | yetkili araştırma ekibi | geri çekilmede sil; dönem sonunda anonimleştir/imha |
| Ürün hesabı | e-posta, besin geçmişi | ürün kullanıcısı/operasyon | araştırma pseudonym'ine bağlanmaz |
| Teknik audit | export, manuel düzenleme, çekilme | veri sorumlusu/denetçi | kurul/kurum politikası |
| Sentetik fixture | test UUID ve örnek yanıt | geliştiriciler | sonuç analizine alınmaz |

Kesin saklama süreleri uydurulmaz. Veri sorumlusu, hukuki dayanak, amaç ve kurul kararıyla her sınıf için süreyi **[doldurmalıdır]**. “2 yıl” varsayılan değildir.

## 3. Veri sözlüğü — oturum/görev tidy export

| Alan | Tip | Tanım / kural |
|---|---|---|
| session_id | string | `U-` önekli, yalnız dışa aktarıma ait kararlı oturum kodu |
| participant_id | string | `P-` önekli, anahtarlı ve kararlı export pseudonym'i; hesap kimliği değil |
| schema_version | string | Usability şema sürümü |
| protocol_version | string | Etik kurulca onaylanan protokol |
| approval_reference | string | Sunucu yapılandırmasından; istemci belirleyemez |
| data_origin | enum | `synthetic` veya `participant` |
| condition | enum | `nutrisense` / `standardized_assistance`; uygulamaya eklenmesi araştırmacı kararı |
| sequence | enum | `AB` / `BA`; deterministik atama |
| task_id | string | t1…t6, sürümlü tanım |
| started_at / ended_at | ISO-8601 | UTC, duvar saati audit sınırı |
| duration_seconds | decimal | Monotonik sayaç; analiz değeri |
| timing_source | enum | `monotonic` / `manual` |
| success | boolean/null | Görev kriterine göre |
| error_count | integer ≥0 | Önceden tanımlı hataların sayısı |
| assistance_level | enum | none/prompt/partial/full |
| abort_reason | string/null | Kontrollü kod tercih edilir |
| manually_edited | boolean | Süre/sonuç düzeltildi mi |
| edit_reason | string/null | Manuel değişiklikte zorunlu; audit edilir |
| researcher_note | ≤1000 char | Kişisel veri yazılmaz |

`condition` görev satırında, `counterbalance_sequence` oturum satırında ayrı ve doğrulanan alanlardır. Hangi görev eşleştirmesinin A/B olduğu protokol sürümünde sabitlenmeden karşılaştırmalı hipotez analizi başlatılamaz.

## 4. Veri sözlüğü — anket tidy export

| Alan | Tip | Tanım |
|---|---|---|
| submission_id | string | `S-` önekli, yalnız dışa aktarıma ait kararlı form kodu |
| participant_id | string | `P-` önekli, anahtarlı ve kararlı export pseudonym'i |
| survey_version | string | `NS-SURVEY-1.0-DRAFT` kurul öncesi taslak |
| question_id | string | Sürüm içindeki sabit madde kimliği |
| answer | scalar/list/null | Madde tipine uygun yanıt |
| answered_at | ISO-8601 | Yanıt zamanı; UTC offset zorunlu |
| completion_seconds | integer | Tamamlama süresi |
| submitted_at | ISO-8601 | Sunucuya gönderim |
| protocol_version / approval_reference / data_origin | string | Onay ve kaynak izlenebilirliği |

## 5. Kalite, bütünlük ve audit

- UUID ve foreign key kontrolleri; süre ≥0; hata ≥0; yardım enum'u.
- Başlangıç/bitiş duvar saatiyle, süre monotonik saatle kaydedilir.
- Manuel düzenleme gerekçesiz kabul edilmez; `AuditEvent` oluşur.
- Survey/usability tekrar gönderimi participant + idempotency key unique constraint ile tekilleştirilir.
- Tidy export yetkili token ister ve export satır sayısını audit eder.
- Sentetik kayıtlar `data_origin=synthetic`; araştırma istatistiği endpointine girmez.
- Açık uçlu alan 1000 karakterle sınırlı ve kişisel veri uyarılıdır. İhlal görülürse erişim sınırlanır, olay kaydedilir ve onaylı redaksiyon prosedürü uygulanır; ham metin geliştirici loguna yazılmaz.

## 6. Yetkilendirme ve güvenlik doğrulaması

Secret değerleri repoya/rapora yazılmaz. Export token ve `RESEARCH_PSEUDONYMIZATION_KEY` yalnız server secret store'dadır ve birbirinden farklı üretilir. Pseudonimleştirme anahtarı araştırma boyunca korunur; değiştirilirse eski ve yeni export kimlikleri eşleşmez. Yetkili araştırmacı rolleri, kurum kimlik yönetimi ve veri erişim onayı **[kurum kararı]** ile belirlenir. Backup şifreleme, anahtar saklama, restore testi ve breach bildirim prosedürü saha öncesi doğrulanır; mevcut kod bunların gerçekleştiğini kanıtlamaz.

## 7. Geri çekilme ve silme

Geri çekilme kodunun düz metni yalnız katılımcıya gösterilir ve mobil güvenli kasada tutulabilir; sunucuda SHA-256 özeti vardır. Doğrulanan talep survey/usability kayıtlarını ve onam kanıt referanslarını siler, minimal çekilme audit kaydını bırakır. Export/backup kopyalarından silmenin gecikme ve prosedürü kurum backup politikasında **[doldurulmalıdır]**.

## 8. Analiz teslim paketi

Her dondurulmuş analiz paketi: tidy CSV/JSON, veri sözlüğü, protokol/anket/görev sürümü, dışlama günlüğü, analiz kodu/lock, seed, ortam bilgisi, checksum ve salt okunur sonuç artefaktı içermelidir. Ham veri Git'e konmaz. Hiçbir metrik ham veri ve yeniden üretim komutu olmadan rapora yazılmaz.
