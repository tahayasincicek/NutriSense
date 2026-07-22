# Anket araç kaydı ve puanlama yönü

**Kod sürümü:** `NS-SURVEY-1.0-DRAFT`

**Durum:** Araştırmacı tarafından geliştirilmiş taslak; doğrulanmış SUS, UEQ veya başka bir standart ölçek değildir. “SUS skoru” üretilemez.

| ID | Yapı | Tip/seçenek | Yön | Kaynak/durum |
|---|---|---|---|---|
| q1 | Önceki yöntem | 5 kategorili tek seçim | Nominal; puanlanmaz | Araştırmacı taslağı |
| q2 | Sesli geri bildirim yeterliliği | 1 hiç yeterli değil – 5 çok yeterli | Yüksek=olumlu | Araştırmacı taslağı |
| q3 | Tarama kolaylığı | 1 çok zor – 5 çok kolay | Yüksek=olumlu | Araştırmacı taslağı |
| q4 | Sonuca güven | 1 hiç güvenmedim – 5 tamamen güvendim | Yüksek=olumlu; doğruluk değildir | Araştırmacı taslağı |
| q5 | Diyetisyen özelliği niyeti | Evet/Hayır/Belki | Nominal; puanlanmaz | Araştırmacı taslağı |
| q6 | Beğenilen özellik | Açık uçlu | Tematik; kişisel veri yok | Araştırmacı taslağı |
| q7 | İstenen özellik | Açık uçlu | Tematik; kişisel veri yok | Araştırmacı taslağı |
| q8 | Genel değerlendirme | 1 çok kötü – 5 çok iyi | Yüksek=olumlu | Araştırmacı taslağı |

Toplam puan hesaplanmaz. q2/q3/q4/q8 ayrı maddeler olarak medyan, dağılım ve güven aralığıyla verilir. q4 öznel güven, model doğruluğunun kanıtı değildir. q6/q7 yanıtlarından doğrudan alıntı yapılacaksa onam metninde alıntı/yeniden tanınma riski ayrıca açıklanır; aksi halde yalnız tematik özet kullanılır.

## Sürümleme

Madde metni, seçenek, sıra veya ölçek yönü değişirse yeni sürüm oluşturulur; eski yanıtlar sessizce yeniden kodlanmaz. `survey_versions.schema_json` tam madde metni, seçenek, kaynak ve yön içermelidir. Mevcut seed yalnız `seed` alanı içerdiğinden gerçek saha öncesi tam şema migration'ı gereklidir.

## Uygulama kuralları

- Sorular ekranda ve TTS ile aynı metinde sunulur.
- Ekran okuyucu/TTS çakışması erişilebilirlik ayarına göre yönetilir.
- “Yanıtlamak istemiyorum” seçeneği etik kurulca belirlenip required politikasına yansıtılmalıdır.
- Açık uçlu maddeler “ad, telefon, e-posta veya başka kişisel bilgi yazmayın” uyarısını içerir.
- Araştırmacı yanıtı yorumlamaz, önermez veya olumlu cevaba yönlendirmez.

## Araştırmacı kararları

Standart bir ölçek gerekiyorsa lisans, doğrulanmış Türkçe sürüm ve erişilebilir uygulama izni birincil kaynaktan doğrulanmalıdır. Bu karar verilmeden mevcut maddeler bilimsel olarak doğrulanmış ölçek gibi sunulamaz.
