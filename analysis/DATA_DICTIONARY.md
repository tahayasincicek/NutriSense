# Analiz veri sözlüğü

Girdi, backend `/api/v1/usability/export/tidy` ve `/api/v1/survey/export/tidy` JSON çıktılarıdır. JSON kökünde `rows` listesi bulunur. CSV eşdeğeri de kabul edilir.

## Usability zorunlu alanları

| Alan | Tip/kural | Analiz rolü |
|---|---|---|
| session_id | UUID/string | Tek oturum audit kimliği |
| participant_id | UUID/string | Yüklemede körlenir; çıktıya yazılmaz |
| schema_version | string | Şema izlenebilirliği |
| protocol_version | gerçek modda placeholder olamaz | Protokol kapısı |
| approval_reference | gerçek modda placeholder olamaz | Etik onay kapısı |
| data_origin | participant/synthetic | Gerçek-sentetik ayrımı |
| counterbalance_sequence | AB/BA | Sıra etkisi |
| task_id | t1…t6 | Görev katmanı |
| condition | nutrisense/standardized_assistance | Eşleştirilmiş koşul |
| status | completed/failed/aborted vb. | Tutarlılık kontrolü |
| duration_seconds | sayı ≥0 | Monotonik görev süresi |
| success | boolean | Protokol başarı kriteri |
| error_count | integer ≥0 | İkincil sonuç |
| assistance_level | none/prompt/partial/full | Bağımsız başarı tanımı |
| abort_reason | nullable kontrollü kod | Missing/exclusion nedeni |
| timing_source | monotonic/manual | Duyarlılık analizi |
| manually_edited | boolean | Audit/duyarlılık |
| edit_reason | manuel değişiklikte zorunlu | Audit |

Her gerçek katılımcı için 6 görev × 2 koşul = 12 benzersiz satır beklenir.

## Survey zorunlu alanları

| Alan | Tip/kural | Analiz rolü |
|---|---|---|
| submission_id | UUID/string | Form kimliği |
| participant_id | UUID/string | Usability ile eşleştirilir, sonra körlenir |
| protocol_version / approval_reference | string | Onay kapısı |
| survey_version | string | Araç sürümü |
| data_origin | participant/synthetic | Kaynak kapısı |
| question_id | q1…q8 | Madde kimliği |
| answer | tipe bağlı | Yanıt |
| answered_at / submitted_at | ISO-8601 | Audit |
| completion_seconds | integer ≥0 | Tanımlayıcı kalite ölçüsü |

q2/q3/q4/q8 1–5; q1/q5 nominal; q6/q7 açık metindir. Açık metin ham olarak analiz artefaktına kopyalanmaz.

## Çıktı alanları

Her CSV `analysis_run_id`, `data_checksum_sha256`, `generated_at_utc`, `analysis_plan_version`, `synthetic` metadata kolonlarını taşır. Her sonuç satırı `result_id` ile `results_manifest.json` kaydına bağlanır. PNG metadata'sında aynı run bilgileri bulunur.
