# NutriSense etik ve KVKK belge dizini

Bu dosya bir etik kurul kararı, hukuk görüşü veya tamamlanmış saha çalışması kanıtı değildir. Kurum, veri sorumlusu, danışman, saklama süresi, hukuki dayanak, başvuru/karar numarası ve iletişim bilgileri bilinmediği için uydurulmamıştır.

## Kanonik taslaklar

- [Araştırma protokolü](research/research_protocol.md)
- [Erişilebilir onam ve geri çekilme](research/accessible_consent_and_withdrawal.md)
- [Veri yönetim planı ve sözlük](research/data_management_plan.md)
- [İşe alım ve ücret/masraf](research/recruitment_and_compensation.md)
- [Araştırmacı oturum scripti](research/researcher_session_script.md)
- [Altı görev spesifikasyonu](research/usability_task_specification.md)
- [Anket araç kaydı](research/survey_instrument_register.md)
- [Hazırlık ve karar durumu](research/readiness_and_decisions.md)

## Düzeltilen çelişkiler

Eski metindeki “ses kaydı yapılmaz” ve “sesli onam kaydedilebilir” ifadeleri tek prosedüre bağlandı: kullanılabilirlik oturumu kaydedilmez; varsayılan sözlü yöntem tanıklı ve ses kayıtsızdır. Yalnız etik kurulun açıkça onayladığı onam ses kaydı, ayrı depo/retention/erişim prosedürü ve teknik feature gate ile kullanılabilir.

“Bilinen risk yoktur”, “AES-256/TLS 1.3/Firebase uygulanır”, sabit “2 yıl saklanır” ve örnek e-posta gibi doğrulanmamış iddialar çıkarıldı. Bunlar ancak teknik kanıt, kurum politikası ve kurul kararıyla doldurulabilir.

## Etik başvuru kontrolü

| Belge/karar | Durum |
|---|---|
| Protokol, risk, onam, görev, anket, DMP taslakları | Hazır; kurum alanları bekliyor |
| Kurum etik kurul formu ve dilekçesi | Etik kuruldan/kurumdan bekleniyor |
| Danışman ve sorumlu araştırmacı onayı | Araştırmacı kararı gerekiyor |
| Örneklem/güç parametreleri | Araştırmacı kararı ve hesap betiği gerekiyor |
| Veri sorumlusu, hukuki dayanak, retention | Kurum/hukuk birimi kararı gerekiyor |
| İşe alım kurumu ve kurum izni | Bekleniyor |
| Ücret/masraf tutarı | Araştırmacı/kurum kararı gerekiyor |
| Etik kurul approval reference | Bekleniyor; boş kalmalı |
| Gerçek katılımcı toplama | Teknik olarak kilitli |

Etik onay çıkmadan `RESEARCH_MODE=approved` yapılmaz. Örnek/uydurma numara kullanmak protokol ihlalidir; geliştirmede yalnız `synthetic` fixture kullanılır.
