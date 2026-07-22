# Altı kullanılabilirlik görevi — sürümlü spesifikasyon

**Sürüm:** NS-USABILITY-1.0-DRAFT. Kurul onayı öncesi yalnız sentetik pilotta kullanılabilir.

Ortak başarı: belirtilen bitiş noktasına maksimum sürede ulaşma. “Bağımsız başarı” ek olarak `assistance_level=none` gerektirir. Hata, yardım ve abort tanımları [araştırmacı scriptindedir](researcher_session_script.md).

| ID | Görev | Başlangıç | Bitiş | Başarı ölçütü | Maks. |
|---|---|---|---|---|---:|
| t1 | Giriş | Uygulama kapalı | Ana sayfa başlığı duyulur | Doğru sentetik hesapla ana sayfaya ulaşır | 180 sn |
| t2 | Tarama/doğrulama | Ana sayfa; yiyecek masada | Sonuç dinlenmiş, porsiyon doğrulanmış, kayıt onaylanmış | Yanlış/düşük güven sonucunu kesin kabul etmeden tamamlar | 300 sn |
| t3 | Geçmiş | Ana sayfa; t2 kaydı var | Doğru kaydın ad/porsiyon/saatini söyler | Bugünkü doğru kaydı bulur ve dinler | 180 sn |
| t4 | Rapor | Sentetik doğrulanmış diyetisyen/geçmiş | Önizleme, alıcı, kanal doğrulanıp sandbox sonucu alınır | Açık onaydan önce göndermez | 300 sn |
| t5 | Erişilebilirlik ayarı | Ana sayfa | TTS hızı değişmiş ve örnek dinlenmiş | Ayarı bulur, değiştirir, doğrular | 180 sn |
| t6 | Günlük özet | Ana sayfa; mikrofon hazır | Özet duyulur veya dokunma alternatifi tamamlanır | Sesli komut ya da eşdeğer erişilebilir alternatif | 180 sn |

## Koşul eşdeğerliği

NutriSense ve standartlaştırılmış yardım koşulunda bilgi hedefi aynı olmalıdır. Kamera/uygulama özgü t2, kontrol koşulunda “yardımcıdan test yiyeceğinin adı ve standart porsiyon bilgisini öğren”; t3–t6 için kontrol görevi aynı bilgi/eylem hedefini sağlayan önceden tanımlı kart veya yardımcı yanıtıyla eşleştirilir. Eşdeğerlik danışman ve erişilebilir HCI uzmanı tarafından pilot öncesi onaylanmalıdır.

Her task satırında `condition` (`nutrisense`/`standardized_assistance`) bulunmalı; oturumda AB/BA sırası kaydedilmelidir. Aynı yiyecek iki koşulda kullanılmaz; zorluk eşleştirmesi sınıf, porsiyon karmaşıklığı ve sesli yanıt uzunluğuna göre yapılır.

## Abort kodları

`participant_abort`, `timeout`, `technical_failure`, `safety_intervention`, `protocol_deviation`, `not_attempted`. Serbest açıklama yalnız gerekliyse ve kişisel veri içermeden `researcher_note` alanına yazılır.

## Manuel düzenleme

Monotonik süre kanoniktir. Sayaç arızasında `timing_source=manual`, `manually_edited=true`, zorunlu `edit_reason` kullanılır. Tahmini süre uydurulmaz; güvenilir başlangıç/bitiş yoksa süre null ve `technical_failure` olur.
