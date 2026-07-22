# Erişilebilir aydınlatılmış onam ve geri çekilme prosedürü

**Taslak:** Etik kurul ve kurum alanları tamamlanmadan kullanılamaz.

## Katılımcıya okunacak kısa bilgilendirme

Araştırmanın adı: NutriSense görme engelli kullanıcı deneyimi çalışması. Araştırmacı, danışman, kurum, iletişim ve bağımsız şikâyet kanalı: **[doldurulacak]**.

Bu çalışma, bir mobil uygulamadaki altı görevin kullanılabilirliğini değerlendirir. Uygulamanın söylediği besin ve kalori bilgileri tahmindir; tıbbi tavsiye değildir ve yeme/tedavi kararı için kullanılmamalıdır. Oturum yaklaşık **[kurulca onaylanan süre]** sürer. Görev süresi, başarı, hata, yardım düzeyi, bırakma nedeni, anket yanıtları ve sınırlı cihaz bilgisi toplanır. Ad, e-posta ve telefon sonuç verisine bağlanmaz.

Katılım gönüllüdür. İstediğiniz soruyu yanıtlamayabilir, mola verebilir veya gerekçe göstermeden ayrılabilirsiniz. Katılmamak hizmet, eğitim veya ilişkilere zarar vermez. Olası riskler yorgunluk, performans kaygısı, yanlış uygulama sonucu ve mahremiyet ihlalidir; güvenlik önlemleri açıklanmıştır. Doğrudan yarar garanti edilmez.

Veriler rastgele katılımcı koduyla saklanır. Kodunuzu bulmayı sağlayan geri çekilme kodu size verilir. Kodla **[kurulca onaylanan son tarihe]** kadar verinizin silinmesini isteyebilirsiniz. Anonimleştirilmiş/toplulaştırılmış veri yayımlandıktan sonra geri çekmenin teknik sınırı varsa burada açıkça yazılır; belirsiz bırakılmaz.

Sorularınız yanıtlandı mı? Katılmayı özgür iradenizle kabul ediyor musunuz?

## Onam kontrol listesi

Her madde ayrı doğrulanır:

- Araştırmanın amacı ve işlemleri açıklandı.
- Uygulama sonucunun tahmini ve tıbbi karar amacı taşımadığı açıklandı.
- Riskler, mola, atlama ve çekilme hakkı açıklandı.
- Toplanan/toplanmayan veri ve alıcılar açıklandı.
- Saklama süresi ve silme tarihi kurul kararıyla dolduruldu.
- Onam yöntemi katılımcı tarafından seçildi.
- Katılımcının soruları yanıtlandı.
- Onam verilmeden görev veya anket başlatılmadı.
- Tek kullanımlık geri çekilme kodu erişilebilir formatta teslim edildi.

## İzin verilen onam yöntemleri

### 1. Erişilebilir yazılı/e-imzalı onam

HTML/Word, ekran okuyucu uyumlu başlıklar; en az 16 punto basılı alternatif; yüksek kontrast; Braille veya tercih edilen erişilebilir format imkânı. İmza belgesi araştırma sonuç verisinden ayrı, kurumun onaylı sisteminde tutulur. Uygulama veritabanında yalnız kanıt referansı bulunur.

### 2. Tanıklı sözlü onam — varsayılan ses kayıtsız alternatif

Katılımcı, bilgilendirme metnini dinledikten sonra sözlü kabul verir. Bağımsız veya kurulca uygun görülen tanık tarih/saat, form sürümü, katılımcı pseudonym'i ve “özgür onam duyuldu” beyanını imzalar. Ses kaydı yapılmaz. Uygulamada `consent_method=witnessed_verbal` ve kişisel veri içermeyen `witness_reference` tutulur.

### 3. Kayıtlı sözlü onam — varsayılan olarak yasak

Yalnız etik kurul kararı açıkça ses kaydını, amacını ve saklama süresini onaylarsa kullanılabilir. Teknik kapı `RESEARCH_AUDIO_CONSENT_APPROVED=false` varsayılanıyla bunu engeller. Onaylanırsa:

- Kayıt yalnız onam beyanını içerir; kullanılabilirlik oturumu kaydedilmez.
- Amaç onam kanıtıdır; araştırma sonucu analizi değildir.
- Dosya uygulama/repo/veritabanına konmaz; kurumun şifreli, erişim loglu deposunda tutulur.
- Araştırma DB'sinde yalnız rastgele `evidence_reference` bulunur.
- Erişim sorumlu araştırmacı ve yetkili denetçiyle sınırlıdır.
- Saklama ve imha tarihi kurul kararına aynen bağlanır.
- Katılımcıya kayıt yapılmadan tanıklı sözlü veya yazılı alternatif sunulur.
- Geri çekilmede hukuken saklanması zorunlu değilse kayıt silinir; işlem audit edilir.

Bu düzenleme “ses kaydı yapılmaz” ile “sesli onam kaydedilebilir” çelişkisini çözer: çalışma oturumu hiçbir durumda kaydedilmez; onam sesi ise ayrıca onaylanan istisnadır.

## Onam kaydı alanları

`participant_pseudonym`, `protocol_version`, `consent_version`, `approval_reference`, `consent_method`, isteğe bağlı kanıt/tanık referansı, `granted_at`, `withdrawn_at`, `data_origin`, geri çekilme kodunun yalnız SHA-256 özeti. Ad/e-posta/telefon bu tabloya yazılmaz.

## Geri çekilme formu/metni

“NutriSense araştırmasından çekilmek ve araştırma verilerimin silinmesini istiyorum. Katılımcı kodum: [pseudonym]. Geri çekilme kodum: [kod]. Talebin ulaştığı tarih/saat: [otomatik].”

Kimlik doğrulama geri çekilme koduyla yapılır; e-posta adresiyle sonuç araması yapılmaz. Kod kaybedilirse kurulca onaylanan alternatif doğrulama prosedürü **[araştırmacı kararı gerekiyor]**.

Backend `/api/v1/research/withdraw` şu işlemleri tek transaction içinde yapar: kod özetini doğrular, survey ve usability sonuçlarını siler, kanıt/tanık referansını temizler, minimal onam/çekilme audit kaydını tutar. Yanlış kod, bir katılımcının varlığını ayrıntılı biçimde ifşa etmez. Mobil güvenli kasadaki kuyruk ve kimlik de başarılı çekilmeden sonra temizlenir.

## İmzalanacak kurum alanları

- Katılımcı pseudonym'i: **[sistem üretir]**
- Protokol / onam sürümü: **[atanacak]**
- Onam yöntemi: **[seçilecek]**
- Tarih/saat: **[otomatik UTC + yerel gösterim]**
- Araştırmacı ve gerekirse tanık adı/imzası: **[ayrı güvenli form]**
- Etik kurul referansı: **[karar sonrası]**
