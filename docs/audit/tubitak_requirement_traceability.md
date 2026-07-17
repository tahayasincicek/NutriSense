# TÜBİTAK 2209-A Gereksinim İzlenebilirlik Matrisi

> **Snapshot notu:** Bu matris API kanonikleştirmesinden önceki denetim
> durumunu kaydeder. Kamera/backend sözleşmesinin güncel uygulama ve test
> kanıtı için `docs/api_contract.md` ve ADR-001'e bakılmalıdır.

**Denetim tarihi:** 17 Temmuz 2026  
**Kaynak:** `C:\Users\TAHA\Desktop\2209\Tübitak-2209-a_rapor 1 (1).pdf` (10 sayfa; görsel ve metinsel olarak bütünüyle incelendi)  
**Denetlenen ürün:** `C:\Users\TAHA\Desktop\2209\nutrisense`  
**Kapsam dışı:** Aynı çalışma dizinindeki `NutriSense_New`; bu denetim promptu ana uygulamayı açıkça `nutrisense` olarak tanımladığı için kanıtlar iki proje arasında karıştırılmadı.

## Değerlendirme kuralı

- **Tam:** Uygulama kodu, gerçek çağrı zinciri, yapılandırma, çalışan test ve/veya çıktı artefaktı birlikte yeterli kanıt sağlıyor.
- **Kısmi:** Gereksinimin bir bölümü uygulanmış; uçtan uca kanıt veya zorunlu alt bileşen eksik.
- **Eksik:** Gerekli uygulama veya artefakt yok.
- **Kanıtsız:** Tamamlanmış olduğuna dair yazı/kod var; fakat çalıştırma sonucu, ham veri, model, paket veya dış servis kanıtı yok.
- **Çelişkili:** PDF, rapor, mobil istemci, backend ya da artefaktlar birbiriyle uyuşmuyor.

Bir dosyanın veya sınıfın varlığı tek başına “Tam” sayılmadı. Gerçek sır değerleri okunabilir biçimde kayda alınmadı; `.env` yalnızca `EMPTY/PLACEHOLDER/SET` olarak değerlendirildi.

## Yönetici özeti

Proje; erişilebilir arayüz, kamera akışı, TTS/STT servisleri, FastAPI şemaları ve araştırma belge taslakları bakımından kayda değer bir iskelete sahiptir. Buna karşılık denetim anında ürün **uçtan uca doğrulanabilir durumda değildir**. Başlangıç ekranı kimlik doğrulamayı atlıyor; aktif geçmiş ekranı sahte veri gösteriyor; aktif kamera çağrısının URL/gövde/yanıt sözleşmesi backend ile uyuşmuyor; refresh/logout backend uçları yok; iOS platformu ve gerçek model dosyası yok; Android release izinleri ve imzası hazır değil; testler bağımlılık çözümünde başlamıyor. Saha çalışması, etik kurul kararı, ham veri ve analiz artefaktları bulunmadığından nicel sonuçlar doğrulanmış araştırma sonucu değildir.

## 1. Özet ve özgün değer taahhütleri

| ID | Atomik gereksinim | PDF bölümü | İlgili proje dosyası | Durum | Kanıt | Risk | Önerilen çözüm | Kabul ölçütü |
|---|---|---|---|---|---|---|---|---|
| OZ-01 | Görme engelli bireyler için mobil kalori ölçümü sunulmalı. | Özet, s.2 | `lib/main.dart`; `lib/features/food_scan/`; `lib/shared/services/food_analysis_service.dart` | Kısmi | Mobil ekranlar ve analiz servisi var; çalışan ürün testi yok. | Temel proje çıktısı gösterilemez. | Tek bir üretim akışı seçip cihaz-backend entegrasyon testi ekle. | Gerçek cihazda erişilebilir biçimde fotoğraf çekilip doğrulanmış kalori sonucu alınır. |
| OZ-02 | Kamera görüntüsü görüntü işleme/YZ ile besin olarak tanınmalı. | Özet; Özgün Değer, s.2-3 | `lib/features/food_scan/screens/camera_screen.dart`; `backend/app/services/google_vision_service.py`; `ai_model/` | Çelişkili | Mobil kamera `/v1/food/recognize` çağırıyor; backend `/api/v1/analyze-food` bekliyor. Depoda model yok. | Ana fonksiyon 404/422 veya yanıt ayrıştırma hatası verir. | Tek OpenAPI sözleşmesi üret; mobil istemciyi üretilen sözleşmeye bağla; gerçek model/servis yolu seç. | Sözleşme testi ve gerçek cihaz E2E testi aynı örnek için 2xx ve şemaya uygun yanıt üretir. |
| OZ-03 | Sonuç kullanıcıya sesli geri bildirimle iletilmeli. | Özet; Amaç ve Hedefler, s.2-3 | `lib/shared/services/tts_service.dart`; `camera_screen.dart` | Kısmi | TTS kodu var; gerçek cihaz ve TalkBack/VoiceOver test kaydı yok. | Hedef kitle sonucu algılayamayabilir. | TTS akışını hata/orta/yüksek güven durumlarında cihaz üzerinde test et. | Ekran kapalı/okuyucu açık senaryolarında sonuç ve hata mesajları anlaşılır biçimde seslendirilir; test tutanağı vardır. |
| OZ-04 | Besin adı, miktar, tarih-saat ve kalori kaydedilmeli. | Özet, s.2 | `backend/app/models/database.py`; `food_router.py`; `lib/features/history/` | Kısmi | DB modeli kayıt alanları içeriyor; aktif geçmiş ekranı `_MockFoodLog`; mobil kamera aktif backend sözleşmesine ulaşmıyor. | Kayıt ve geçmiş taahhüdü sahte veriyle karışır. | Kamera-kayıt-geçmiş zincirini tek servis üzerinden birleştir. | Aynı kullanıcı için taranan kayıt DB’de oluşur ve aktif geçmiş ekranında doğru tarih/saat/miktarla görünür. |
| OZ-05 | Kayıt/rapor e-posta veya SMS ile diyetisyene iletilmeli. | Özet; Amaç ve Hedefler, s.2-3 | `backend/app/services/notification_service.py`; `food_router.py`; `send_report_wizard.dart` | Kanıtsız | SMTP değişkenleri `SET`; Twilio değişkenleri `.env` içinde yok. Sandbox teslimat çıktısı/mesaj kimliği yok. | Rapor gönderildi denirken teslimat gerçekleşmeyebilir. | Mail/SMS sandbox kullan; teslimat kimliğini ve redakte edilmiş logu sakla. | Test diyetisyenine e-posta ve seçildiyse SMS ulaşır; sağlayıcı kimliği, zaman damgası ve hata senaryosu kanıtlanır. |
| OZ-06 | Sistem etiketli veri setleri ve makine öğrenmesi teknikleri kullanmalı. | Özet, s.2 | `ai_model/01_data_preparation.py`; `02_model_training.py` | Kanıtsız | Pipeline kodu var; veri seti, manifest, lisans kaydı, checkpoint, metrik ve grafik yok. | YZ başarımı ve özgün değer doğrulanamaz. | Veri manifesti, hash, lisans, split ve eğitim çalıştırma kaydı üret. | Veri seti sürümü ve eğitim komutu deterministik olarak model/checkpoint/metrik üretir. |
| OZ-07 | Arayüz erişilebilir ve sesli yönlendirmeli olmalı. | Özet; Yöntem, s.2-4 | `lib/shared/services/tts_service.dart`; `stt_service.dart`; `test/accessibility/` | Kısmi | Erişilebilirlik yardımcıları/test taslakları var; testler gerçek uygulamayı bütünüyle çalıştırmıyor ve cihaz kanıtı yok. | WCAG/TalkBack uyumsuzluğu fark edilmeyebilir. | Semantics ağacı, odak sırası, ölçekleme ve kontrastı gerçek ekranlarda test et. | TalkBack ve VoiceOver kontrol listesi; otomatik semantics/kontrast testleri; kritik akışlarda sıfır engelleyici hata. |
| OZ-08 | Uzman ve kullanıcı geri bildirimiyle iteratif geliştirme yapılmalı. | Özet, s.2 | `lib/features/survey/`; `backend/app/routers/survey_router.py`; `docs/etik_kvkk_belgeleri.md` | Kanıtsız | Form ve saklama kodu var; ham yanıt, oturum kaydı, sürüm karşılaştırması ve etik izin yok. | İterasyon iddiası kanıtlanamaz; insan katılımcı riski doğar. | Etik onaydan sonra sürümlü protokol ve değişiklik günlüğü oluştur. | Her iterasyon için katılımcı/uzman geri bildirimi, anonim ham veri, karar ve ürün değişikliği izlenebilir. |
| OD-01 | Çözüm besin tanıma, kalori hesaplama ve sesli geri bildirimi tek akışta birleştirmeli. | Özgün Değer, s.2-3 | Kamera, TTS ve backend servisleri | Çelişkili | Bileşenler var; aktif URL ve şema ayrışıyor. | Özgün bütünleşik çözüm fiilen çalışmayabilir. | Tek mimari karar kaydı ve sözleşme testi. | Kamera → analiz → kalori → TTS zinciri CI’da ve gerçek cihazda geçer. |
| OD-02 | Diyetisyene otomatik veri iletimi sağlanmalı. | Özgün Değer, s.3 | `dietitian_screen.dart`; `notification_service.py`; `food_router.py` | Kısmi | Gönderim servisi var; diyetisyen bağlama ekranında `Future.delayed` simülasyonu var; atama endpoint’i bulunmadı. | Yetkili alıcı belirlenemez veya yanlış alıcıya veri gidebilir. | Doğrulanmış diyetisyen davet/atama/onay akışı ve erişim kontrolü kur. | Hasta yalnızca onayladığı diyetisyene rapor yollar; iptal ve audit log testlidir. |
| OD-03 | Araştırma hipotezi: YZ destekli sesli geri bildirim kalori öğrenmeyi daha hızlı ve etkili yapmalı. | Özgün Değer, s.3 | `docs/tubitak_sonuc_raporu.md`; `docs/akademik_makale_taslak.md` | Kanıtsız | Hipotez sonucu yazılmış; ham veri, ön-kayıtlı analiz ve yeniden üretim kodu yok. | Araştırma bütünlüğü ihlali. | Sonuçları taslak olarak karantinaya al; etik onaylı yeni çalışma ve analiz planı yürüt. | Anonim ham veri + veri sözlüğü + kilitli analiz betiği aynı istatistikleri üretir. |

## 2. Amaç ve hedefler

| ID | Atomik gereksinim | PDF bölümü | İlgili proje dosyası | Durum | Kanıt | Risk | Önerilen çözüm | Kabul ölçütü |
|---|---|---|---|---|---|---|---|---|
| AH-01 | Uygulama Türkçe olmalı. | Amaç ve Hedefler, s.3 | `lib/core/constants/app_strings.dart`; Türkçe ekran metinleri | Kısmi | Türkçe metinler yoğun; tam yerelleştirme ve dil kapsam testi yok. | Karma/bozuk metinler erişilebilirliği düşürür. | Tüm kullanıcı metinlerini ARB/l10n kaynağına taşı ve tarama testi ekle. | Kullanıcıya görünen tüm akışlar Türkçe; eksik anahtar ve bozuk kodlama testi sıfır hata. |
| AH-02 | Kamera ile besin tanıma yapılmalı. | Amaç ve Hedefler, s.3 | `camera_screen.dart`; `food_router.py` | Çelişkili | İstek URL ve gövde sözleşmeleri uyuşmuyor. | Ana hedef çalışmaz. | `/api/v1/analyze-food` veya seçilen nihai endpoint üzerinde birleştir. | İstek `image_base64` ve `meal_type` ile, JWT üzerinden 2xx döner. |
| AH-03 | Kalori bilgisi hızlı ve erişilebilir verilmelidir. | Amaç ve Hedefler, s.3 | Kamera/TTS kodu; sonuç raporu | Kanıtsız | Performans benchmark artefaktı yok; rapordaki 4,2/12,7 saniye çelişkili ve ham verisiz. | Hız iddiası savunulamaz. | Cihaz, ağ ve örneklem tanımlı performans testi çalıştır. | P50/P95 süreleri ve hata oranı ham logdan yeniden üretilebilir. |
| AH-04 | Uygulama görsel öğelere bağımlı olmadan tamamen erişilebilir olmalı. | Amaç ve Hedefler, s.3 | Semantics/TTS kodu; erişilebilirlik testleri | Kısmi | Yardımcı bileşenler var; gerçek kritik ekranların tümü test edilmiyor. | “Tamamen erişilebilir” aşırı iddia olur. | Kritik görev bazlı erişilebilirlik kabul planı. | Login, tarama, onay, geçmiş ve rapor gönderme yalnız ekran okuyucuyla tamamlanır. |
| AH-05 | Rapor e-posta/SMS ile otomatik iletilmeli. | Amaç ve Hedefler, s.3 | Bildirim servisi ve wizard | Kanıtsız | Gerçek/sandbox gönderim kanıtı yok. | Kullanıcı sağlık verisi kaybolabilir veya sızabilir. | Açık onay, alıcı doğrulama, sandbox entegrasyon testi. | Redakte edilmiş uçtan uca teslim kanıtı ve hata geri bildirimi vardır. |
| AH-06 | Sesli komutlarla kullanım sağlanmalı. | Amaç ve Hedefler, s.3 | `voice_command_service.dart`; `stt_service.dart` | Kısmi | Komut ayrıştırıcı kodu ve bazı unit testleri var; cihaz mikrofon izni ve gerçek STT kanıtı yok. | Android release’de mikrofon çalışmayabilir. | `RECORD_AUDIO` izni, izin reddi senaryosu, cihaz testi. | Desteklenen komut kümesi gerçek cihazda başarı oranı ve hata günlüğüyle doğrulanır. |
| AH-07 | Kullanıcı sonucu onayladıktan sonra rapor oluşturulmalı/gönderilmeli. | Amaç ve Hedefler, s.3 | Kamera orta güven onayı; rapor sihirbazı | Kısmi | Parçalı ekranlar var; onaydan rapora kalıcı zincir kanıtı yok. | Yanlış tanı kullanıcı onayı olmadan paylaşılabilir. | Explicit confirmation state ve audit kaydı ekle. | Onaysız kayıt rapora giremez; onay/red entegrasyon testleri geçer. |
| AH-08 | Kullanıcının bağımsızlığı ve sağlıklı beslenme takibi desteklenmeli. | Amaç ve Hedefler, s.3 | Ürün tasarımı; sonuç raporu | Kanıtsız | Etkiyi ölçen doğrulanmış veri yok. | Sosyal etki sonuç gibi sunulabilir. | Bunu araştırma çıktısı olarak ölç; ürün özelliği ile etki iddiasını ayır. | Etik onaylı ölçüm, önceden tanımlı ölçek ve anonim veri etkiyi destekler. |

## 3. Yöntem ve araştırma tasarımı

| ID | Atomik gereksinim | PDF bölümü | İlgili proje dosyası | Durum | Kanıt | Risk | Önerilen çözüm | Kabul ölçütü |
|---|---|---|---|---|---|---|---|---|
| YN-01 | Görme engelli bireyler ve ailelerine ihtiyaç anketi uygulanmalı. | Yöntem, s.3-4 | `lib/features/survey/`; `survey_router.py` | Kanıtsız | Form/saklama kodu var; ham veri yok. | İhtiyaç analizi yapılmış sayılamaz. | Etik izin sonrası veri sözlüğü ve anonim dışa aktarım ile uygula. | Zaman damgalı, anonim ham veri; katılım/onam kayıtları; analiz çıktısı vardır. |
| YN-02 | Görme engelli kullanıcılarla kullanılabilirlik testi yapılmalı. | Yöntem, s.3-4 | `usability_test_screen.dart`; `survey_router.py`; sonuç raporu | Kanıtsız | Uygulama ekranı ve sonuç metni var; oturum dosyası, video/log, görev kayıtları yok. | 20 katılımcı ve %90 gibi iddialar doğrulanamaz. | Etik kurul kararı olmadan saha çalışması başlatma; protokolü önceden sabitle. | İmzalı/sesli onam referansları, anonim oturum ham verisi ve sapma günlüğü mevcuttur. |
| YN-03 | Nicel analiz SPSS veya Excel ile yapılmalı. | Yöntem, s.4 | Projede `.sav`, `.xlsx`, `.csv`, notebook veya analiz scripti yok | Eksik | Tarama sonucu analiz artefaktı bulunmadı. | Sonuçlar yeniden üretilemez. | Tercihen sürümlenebilir R/Python betiği; gerekirse SPSS syntax dosyası ekle. | Tek komut temiz ortamda tabloları ve grafikleri ham veriden üretir. |
| YN-04 | Frekans analizi yapılmalı. | Yöntem, s.4 | Sonuç raporunda oranlar | Kanıtsız | Yüzdeler var; ham sayımlar ve betik yok. | Hesap hatası/uydurma riski. | Frekans tablolarını betikle üret. | Her yüzde pay/payda ile izlenebilir ve test edilir. |
| YN-05 | Ki-kare analizi, uygun varsayımlar sağlanıyorsa yapılmalı. | Yöntem, s.4 | Analiz artefaktı yok | Eksik | Sonuç raporu ki-kare çıktısı sunmuyor. | Taahhüt karşılanmaz; küçük örneklemde yanlış test riski. | Değişkenleri/varsayımları önceden belirle; gerekirse Fisher exact kullan. | Beklenen hücre sayıları, test istatistiği, df, p ve etki büyüklüğü betikten çıkar. |
| YN-06 | t-testi, uygun varsayımlar sağlanıyorsa yapılmalı. | Yöntem, s.4 | Sonuç raporu Mann–Whitney U iddia ediyor | Çelişkili | PDF t-testi söylerken taslak rapor Mann–Whitney kullanıyor; seçim gerekçesi ve veri yok. | HARKing/analiz sonrası test seçimi riski. | Ön analiz planında dağılım, eşleşme ve test seçimi kurallarını yaz. | Test seçimi gerekçesi, varsayım kontrolleri ve duyarlılık analizi mevcuttur. |
| YN-07 | Nitel ve nicel kullanılabilirlik verileri birlikte analiz edilmeli. | Yöntem, s.4 | Sonuç raporunda tema/alıntı metinleri | Kanıtsız | Kodlama kitabı, anonim transkript/not ve nicel veri yok. | Alıntı ve temalar doğrulanamaz. | Nitel kodlama şeması, ikinci kodlayıcı/uzlaşma ve kaynak referansı ekle. | Her tema anonim veri parçalarına izlenir; kodlama süreci raporlanır. |
| YN-08 | Mobil geliştirmede Kotlin veya Flutter kullanılmalı. | Yöntem, s.4 | `pubspec.yaml`; `lib/`; `android/` | Tam | Flutter proje yapısı ve debug APK mevcut. | Yalnız teknoloji seçimi kanıtlandı; ürün kalitesi değil. | Flutter yolunu nihai teknoloji olarak belgele. | README’de SDK sürümü ve kurulum adımları açık; temiz build tekrarlanır. |
| YN-09 | Android ve iOS desteklenmeli. | Yöntem, s.4 | `android/` var; `ios/` yok | Çelişkili | iOS platform klasörü/IPA yok; sonuç raporu iOS’u tamamlanmış yazıyor. | PDF hedefi ve sonuç iddiası karşılanmıyor. | iOS hedefi korunacaksa platformu oluştur, imzalı test build ve VoiceOver testi üret; değilse kapsam değişikliğini gerekçelendir. | iOS CI build’i ve gerçek cihaz VoiceOver kabul kaydı vardır. |
| YN-10 | Backend/veri katmanında MySQL kullanılmalı. | Yöntem, s.4 | `backend/app/models/database.py`; `.env` DB değişkenleri `SET` | Kanıtsız | SQLAlchemy/MySQL tasarımı var; migrasyon, temiz DB kurulumu ve entegrasyon testi yok. | Şema yeniden üretilemez; ortam bağımlılığı. | Alembic migrasyonları ve container tabanlı test DB ekle. | Boş DB’ye migrasyon uygulanır, entegrasyon testleri geçer, geri dönüş planı vardır. |
| YN-11 | Python/TensorFlow ile YZ geliştirilmelidir. | Yöntem, s.4 | `ai_model/*.py` | Kısmi | Eğitim kodu ve AST geçişi var; TensorFlow çalıştırma/model çıktısı yok. | Kod, gerçekleştirilmiş eğitim gibi sunulabilir. | Kilitli Python ortamı, veri manifesti ve eğitim raporu ekle. | Eğitim komutu checksum’lı model ve metrik JSON’u üretir. |
| YN-12 | TalkBack ve VoiceOver ile erişilebilirlik doğrulanmalıdır. | Yöntem, s.4 | Android kodu; `ios/` yok | Kısmi | TalkBack’e yönelik kod var; cihaz kanıtı yok; VoiceOver platformu yok. | Yöntem taahhüdü tamamlanamaz. | Her platform için ekran okuyucu test matrisi. | Kritik görevler iki platformda test edilir; sorun/çözüm kayıtları eklenir. |
| YN-13 | Online anket yöntemi kullanılmalıdır. | Yöntem, s.4 | Mobil/REST anket akışı | Kısmi | Anket gönderme kodu var; dağıtım bağlantısı, yanıt kanıtı ve erişilebilirlik testi yok. | Online örneklem iddiası doğrulanamaz. | Erişilebilir anket formu, sürüm ve dağıtım günlüğü tut. | Form sürümü, davet yöntemi ve anonim cevap export’u mevcuttur. |
| YN-14 | Katılımcı araştırması etik kurul kararı ve aydınlatılmış onamdan sonra yürütülmelidir. | Yöntemin zorunlu etik önkoşulu | `docs/etik_kvkk_belgeleri.md` | Eksik | Yalnız taslak onam/KVKK metni var; etik başvuru maddeleri “Hazırlanacak”; karar/numara ve imzalı onam yok. | İnsan araştırmasının hukuki/etik geçerliliği yoktur. | Kurumsal etik kurul ve kurum izinlerini tamamla; veri toplamayı onay tarihinden sonra başlat. | Tarih/karar numaralı onay, protokol sürümü, kurum izni ve onam kayıtları güvenli saklanır. |

## 4. İş-zaman çizelgesi ve başarı ölçütleri

| ID | Atomik gereksinim | PDF bölümü | İlgili proje dosyası | Durum | Kanıt | Risk | Önerilen çözüm | Kabul ölçütü |
|---|---|---|---|---|---|---|---|---|
| IZ-01 | Ay 0–2’de en az 20 akademik çalışma/rapor incelenmeli. | İş-Zaman Çizelgesi, s.5 | PDF kaynakçası; proje dokümanları | Kanıtsız | PDF’de yaklaşık 12 kaynak girdisi var; sistematik tarama tablosu ve 20 kaynak kanıtı yok. | Başarı ölçütü karşılanmaz. | Arama dizgileri, veri tabanları, dahil/dışla kriterleri ve en az 20 doğrulanmış kaynakla literatür matrisi oluştur. | Kaynak künyeleri doğrulanır; tarama tarihi ve kararları yeniden izlenir. |
| IZ-02 | Literatür iş paketinde en az %90 tamamlanma sağlanmalı. | İş-Zaman Çizelgesi, s.5 | Kanıt yok | Kanıtsız | Payda/tamamlanma tanımı yok. | Keyfi yüzde üretimi. | Önceden tanımlı görev listesi ve hesap formülü kullan. | %90 değeri görev kayıtlarından otomatik hesaplanır. |
| IZ-03 | Ay 2–6’da kullanıcı dostu beta mobil uygulama tamamlanmalı. | İş-Zaman Çizelgesi, s.5 | Flutter kaynakları; debug APK | Kısmi | Eski debug APK var; analyzer hataları, auth bypass, mock geçmiş ve API uyuşmazlığı var. | APK beta olarak yanlış sunulabilir. | P0 entegrasyonları düzelt; sürümlü beta ve kabul raporu üret. | Temiz build, sürüm/commit kimliği, kritik akış E2E ve erişilebilirlik kabulü geçer. |
| IZ-04 | Beta test edilip kullanılabilirlik sorunları giderilmeli. | İş-Zaman Çizelgesi, s.5 | Test dizini; CI dosyası | Kanıtsız | Testler bağımlılık çözümünde başlamıyor; bazı widget testleri üretim ekranını içe aktarmıyor. | Düzeltildi iddiası kanıtsızdır. | Gerçek ürün ekranlarını test eden unit/widget/integration paketleri ekle. | CI hata maskelemeden yeşil; test raporu ve düzeltme bağlantıları vardır. |
| IZ-05 | Ay 6–8’de gerçek görme engelli kullanıcılarla saha testi yapılmalı. | İş-Zaman Çizelgesi, s.5 | Sonuç raporu; araştırma ekranları | Kanıtsız | Ham veri/onam/etik karar yok. | Saha testi yapılmış sayılamaz. | Etik onay ve örneklem planı sonrası uygula. | Katılımcı akış şeması, anonim oturum verisi ve protokol sapmaları vardır. |
| IZ-06 | Saha testinde sürekli, hızlı ve başarılı çalışma ölçülmeli. | İş-Zaman Çizelgesi, s.5 | Sonuç raporundaki süre/oranlar | Kanıtsız | Telemetri ve ham görev logları yok. | Performans sonuçları yeniden üretilemez. | Ölçüm tanımı, cihaz/ağ koşulu, başarısızlık sınıfları ve loglama ekle. | P50/P95, başarı oranı ve kesinti oranı ham logdan üretilir. |
| IZ-07 | Ay 8–9’da kapsamlı sonuç raporu hazırlanmalı. | İş-Zaman Çizelgesi, s.5 | `docs/tubitak_sonuc_raporu.md` | Çelişkili | Taslak rapor mevcut; doğrulanmamış ve kendi içinde çelişkili nicel sonuçlar içeriyor. | Yanlış bilimsel beyan. | Sonuç bölümlerini veri gelene kadar “doğrulanmamış taslak” olarak işaretle; gerçek analizle yeniden üret. | Rapordaki her tablo/iddia claims register ve artefakta bağlanır. |
| IZ-08 | Ay 9–10’da ulusal/uluslararası konferans paylaşımı yapılmalı. | İş-Zaman Çizelgesi, s.5 | `akademik_makale_taslak.md` | Kanıtsız | Taslak makale var; gönderim/onay/sunum kanıtı yok. | Yaygınlaştırma tamamlanmış gibi gösterilebilir. | Uygun etkinlik, gönderim kaydı ve sunum artefaktı oluştur. | DOI/proceedings veya gönderim kimliği ve sunum dosyası/kayıt kanıtı vardır. |
| IZ-09 | Çıktılar kurumlar, üniversiteler ve kamu ile paylaşılmalı. | İş-Zaman Çizelgesi, s.5 | Store listing taslakları, kullanıcı el kitabı | Kanıtsız | Yayın URL’si, dağıtım kaydı veya paydaş geri bildirimi yok. | Yaygın etki doğrulanamaz. | Paydaş listesi, paylaşım paketi ve erişim/geri bildirim ölçümü oluştur. | Tarihli paylaşım kayıtları ve erişilebilir materyaller vardır. |

## 5. Riskler ve B planları

| ID | Atomik gereksinim | PDF bölümü | İlgili proje dosyası | Durum | Kanıt | Risk | Önerilen çözüm | Kabul ölçütü |
|---|---|---|---|---|---|---|---|---|
| RK-01 | Sesli komut tanınmazsa farklı algoritma ve daha büyük veri seti denenmeli. | Risk Yönetimi, s.6 | `voice_command_service.dart`; STT servisi | Kısmi | Komut servisi var; benchmark/veri seti ve alternatif algoritma deneyi yok. | B planı uygulanabilirliği bilinmiyor. | Gürültü/aksan/cihaz kırılımlı test seti ve fallback komut UI’ı ekle. | Önceden tanımlı eşik altında otomatik fallback çalışır; karşılaştırma raporu vardır. |
| RK-02 | Kalori verileri güncelliğini yitirirse veri setleri güncellenmeli. | Risk Yönetimi, s.6 | `calorie_database.json`; Nutritionix fallback | Kısmi | Yerel veri var; kaynak, sürüm, güncelleme tarihi ve doğrulama süreci yok. | Yanlış sağlık bilgisi. | Her besin için kaynak/sürüm/tarih ekle; otomatik tazelik kontrolü kur. | Süresi geçen kayıtlar işaretlenir; uzman doğrulaması ve değişiklik geçmişi vardır. |
| RK-03 | Sesli yönlendirme yetersizse alternatif erişilebilirlik ve kişiselleştirilmiş ton/hız sunulmalı. | Risk Yönetimi, s.6 | Erişilebilirlik ayar ekranları | Kısmi | Ayar kodları var; analyzer hatası ve kullanıcı testi yok. | B planı cihazda çalışmayabilir. | Ayarları gerçek TTS motorlarıyla test et; metinsel/haptik fallback ekle. | Kullanıcı ton/hız/yöntemi değiştirebilir; ayar kalıcı ve testlidir. |
| RK-04 | Teknik ve araştırma riskleri izlenip tetikleyicilerle yönetilmeli. | Risk Yönetimi, s.6 | Projede risk günlüğü yok | Eksik | PDF tablosu dışında yaşayan risk kaydı yok. | Riskler gerçekleştiğinde kararlar izlenemez. | Sahip, olasılık, etki, tetikleyici ve durum içeren risk register oluştur. | Her kritik riskin sahibi, gözden geçirme tarihi ve kapanış kanıtı vardır. |

## 6. Araştırma olanakları ve bütçe

| ID | Atomik gereksinim | PDF bölümü | İlgili proje dosyası | Durum | Kanıt | Risk | Önerilen çözüm | Kabul ölçütü |
|---|---|---|---|---|---|---|---|---|
| AO-01 | Android tablet araştırmada kullanılmalı. | Araştırma Olanakları, s.6 | Donanım envanteri/test kaydı yok | Kanıtsız | Depoda cihaz kimliği veya test matrisi yok. | Cihaz olanağı ve uyumluluk kanıtlanamaz. | Redakte edilmiş cihaz envanteri ve test tutanağı ekle. | Model/OS/uygulama sürümüyle test sonuçları kayıtlıdır. |
| AO-02 | Kocaeli Üniversitesi laboratuvar/STAR-LAB GPU olanağı kullanılmalı. | Araştırma Olanakları, s.6 | Eğitim logu/job kaydı yok | Kanıtsız | GPU eğitim çıktısı veya kullanım belgesi yok. | Eğitim yapılmış gibi yorumlanabilir. | Job logu, GPU bilgisi, süre ve model checksum sakla. | Eğitim raporu laboratuvar koşullarını ve çıktı hash’ini içerir. |
| AO-03 | Açık kaynak kütüphaneler kullanılmalı ve lisansları izlenmeli. | Araştırma Olanakları, s.6 | `pubspec.yaml`; `requirements.txt` | Kısmi | Bağımlılıklar var; SBOM/lisans raporu ve kilitli yeniden üretim yok. | Lisans ve tedarik zinciri riski. | SBOM, lisans taraması ve sürüm kilidi ekle. | CI lisans/SCA raporu üretir; yasaklı lisans yoktur. |
| BT-01 | 16 GB RAM için 4.500 TL sarf bütçesi kullanılmalı/belgelenmeli. | Bütçe, s.8 | Fatura/teslim/takip artefaktı yok | Kanıtsız | Proje ağacında harcama kanıtı yok. | Bütçe raporlaması desteklenemez. | TÜBİTAK kurallarına uygun fatura ve demirbaş/sarf sınıflamasını danışmanla doğrula. | Fatura, ödeme ve teslim kanıtı; bütçe kalemiyle eşleştirme vardır. |
| BT-02 | 1 TB SSD için 4.500 TL sarf bütçesi kaleminde açıklanan toplamla tutarlı olmalı. | Bütçe, s.8 | Fatura/teslim artefaktı yok | Çelişkili | PDF açıklaması 16 GB RAM ve 1 TB SSD’yi tek 4.500 TL sarf satırında birlikte anıyor; birim dağılımı belirsiz. | Bütçe yanlış yorumlanabilir. | Kalem/birim/adet/birim fiyat ayrımını resmi bütçede netleştir. | Resmi onaylı bütçe ve faturalar aynı toplam ve kalemleri gösterir. |
| BT-03 | Android ve iOS geliştirme için 4.500 TL hizmet alımı belgelenmeli. | Bütçe, s.8 | Sözleşme/fatura/teslim/IPA yok | Kanıtsız | iOS çıktısı da yok. | Harcama ve teslimat doğrulanamaz. | Hizmet kapsamı, teslim kriteri ve mali belgeyi arşivle. | Fatura/sözleşme ile teslim edilen Android+iOS artefaktları eşleşir. |
| BT-04 | Toplam bütçe 9.000 TL olmalı. | Bütçe, s.8 | Yalnız PDF bütçe tablosu | Kanıtsız | Gerçekleşen harcama dökümü yok. | Planlanan ve gerçekleşen bütçe karışır. | Plan/gerçekleşen karşılaştırma tablosu oluştur. | Harcamalar belgelere dayanır ve toplam mutabakatı yapılır. |

## 7. Yaygın etki ve kaynaklar

| ID | Atomik gereksinim | PDF bölümü | İlgili proje dosyası | Durum | Kanıt | Risk | Önerilen çözüm | Kabul ölçütü |
|---|---|---|---|---|---|---|---|---|
| YE-01 | Algoritma ve kullanıcı deneyimi sonuçları akademik sunuma dönüşmeli. | Yaygın Etki, s.7 | `akademik_makale_taslak.md` | Kanıtsız | Taslak metin var; sonuç verisi ve sunum/gönderim yok. | Akademik çıktı iddiası erken olur. | Önce doğrulanmış sonuç, sonra etkinlik gönderimi. | Kaynak veriye bağlı makale/sunum ve gönderim kaydı vardır. |
| YE-02 | Kullanılabilir mobil prototip üretilmeli. | Yaygın Etki, s.7 | Debug APK; kaynak kod | Kısmi | Debug APK mevcut; release, CI ve kritik akışlar başarısız/kanıtsız. | Prototip “tam ürün” diye sunulabilir. | Sürüm etiketi, bilinen sınırlamalar ve kabul raporu ile beta üret. | Temiz ortamda yeniden build edilir ve kritik senaryolar geçer. |
| YE-03 | Medya farkındalığı ve toplumsal görünürlük sağlanmalı. | Yaygın Etki, s.7 | Store listing taslakları | Kanıtsız | Yayın/medya bağlantısı veya erişim metriği yok. | Yaygın etki ölçülemez. | İletişim planı ve erişim metrikleri tut. | Tarihli yayınlar ve doğrulanabilir erişim/katılım çıktıları vardır. |
| YE-04 | Bağımsızlık ve yaşam kalitesi artışı sağlanmalı. | Yaygın Etki, s.7 | Sonuç raporu | Kanıtsız | Doğrulanmış ölçek/ham veri yok. | Nedensel etki aşırı yorumlanır. | Uygun validasyonlu ölçek ve karşılaştırmalı araştırma tasarımı kullan. | Önceden tanımlı analiz, güven aralığı ve sınırlamalarla sonuç raporlanır. |
| YE-05 | Tezlere ve yeni ulusal projelere temel oluşturmalı. | Yaygın Etki, s.7 | Kanıt yok | Kanıtsız | Tez/proje başvurusu/referans kaydı yok. | Potansiyel etki sonuç gibi yazılır. | Bunu beklenen etki olarak bırak; gerçekleşince kayıt ekle. | Tez künyesi veya başvuru numarasıyla doğrulanır. |
| YE-06 | Genç araştırmacı yetişmesine katkı sağlamalı. | Yaygın Etki, s.7 | Proje öğrenci bilgileri | Kısmi | Öğrenci yürütücüler mevcut; eğitim/mentorluk çıktısı yok. | Katkı ölçülemez. | Yetkinlik hedefleri ve eğitim günlüğü tut. | Tamamlanan eğitimler, görevler ve ürün/araştırma katkıları izlenir. |
| YE-07 | Sorumlu üretim ve tüketim hedefiyle ilişki kurulmalı. | Diğer Konular, s.8 | PDF beyanı | Kanıtsız | Etki göstergesi veya ölçüm yok. | Sürdürülebilirlik iddiası yüzeysel kalır. | İsraf azaltma gibi ölçülebilir gösterge tanımla. | Gösterge, veri kaynağı ve sınırlar raporlanır. |
| KY-01 | Kaynakça en az 20 çalışmalık literatür taahhüdünü desteklemeli. | Kaynaklar, s.9-10; İş paketi 1 | PDF kaynakçası | Eksik | Görsel incelemede yaklaşık 12 kayıt var; 20 eşiği karşılanmıyor. | Literatür başarı ölçütü karşılanmaz. | En az 20 ilgili ve doğrulanmış kaynağa tamamla. | DOI/URL/kütüphane kaydı doğrulanmış 20+ kaynak ve literatür matrisi vardır. |
| KY-02 | Kaynak künyeleri doğrulanabilir ve metin içi iddialarla eşleşmeli. | Kaynaklar, s.9-10 | PDF kaynakçası | Kanıtsız | Bağımsız bibliyografik doğrulama ve atıf eşlemesi yapılmamış. | Hatalı/uydurma kaynak riski. | Her kaynağı DOI, yayıncı veya indeks üzerinden doğrula; metin içi atıf haritası çıkar. | Her kayıt gerçek yayına bağlanır ve desteklediği iddia belirtilir. |

## 8. İstenen özel teknik doğrulamalar

| Kontrol | Sonuç | Kanıt ve yorum |
|---|---|---|
| Gerçek başlangıç ekranı | **Çelişkili** | `lib/main.dart:93` doğrudan `AppShell` açıyor; `LoginScreen` başlangıç akışında değil. |
| Login/register | **Kısmi/Çelişkili** | Backend register/login uçları var; görünen login ekranı `Future.delayed` ile simülasyon yapıyor. İki ayrı istemci mimarisi var. |
| Refresh/logout | **Eksik** | Mobil `/api/v1/auth/refresh` çağrısı ve yerel logout kodu var; backend router’da refresh/logout endpoint’i yok. |
| Kamera URL/gövde/yanıt | **Çelişkili** | Aktif ekran `https://api.nutrisense.app/v1/food/recognize`, `{image,timestamp}` ve `calories` bekliyor. Backend `POST /api/v1/analyze-food`, `{image_base64,meal_type}`, JWT ve `total_calories` sunuyor. |
| Aktif geçmiş ekranı | **Çelişkili** | `app.dart:37` `HistoryScreen` seçiyor; ekran sabit `_MockFoodLog` listesi gösteriyor. Gerçek servis kullanan `FoodHistoryScreen` aktif değil. |
| Gerçek model dosyaları | **Eksik** | `assets/models/` yalnız `.gitkeep`; `.keras/.h5/.tflite/checkpoint` yok. |
| Model eğitim çıktıları | **Eksik** | Kod var; veri, checkpoint, metrik JSON, `training_results.png`, confusion matrix ve run log yok. Dönüştürücü gerçek model yoksa ImageNet tabanlı “demo model” üretebiliyor; bu eğitim başarısı değildir. |
| iOS platformu | **Eksik** | `ios/` ve `.ipa` yok. |
| Android izinleri | **Eksik** | Ana manifestte `uses-permission` yok; Internet yalnız debug/profile manifestlerinde. Kamera/mikrofon/release ağ erişimi kanıtlanmıyor. |
| Android release | **Çelişkili** | `applicationId=com.example.nutrisense`; release debug anahtarıyla imzalanıyor; release APK/AAB yok. |
| Google Vision | **Kanıtsız** | Servis kodu ve `.env.example` anahtarları var; gerçek `.env` içinde ilgili değişkenler yok; çağrı/sandbox sonucu yok. |
| Nutritionix | **Kanıtsız** | Servis ve yerel fallback var; gerçek `.env` içinde ilgili değişkenler yok; API kanıtı yok. |
| Twilio | **Eksik/Kanıtsız** | Servis kodu var; gerçek `.env` içinde Twilio değişkenleri yok; sandbox mesaj kanıtı yok. |
| SMTP | **Kanıtsız** | İlgili gerçek `.env` değişkenleri `SET`; değerler raporlanmadı. Teslimat/sandbox kanıtı yok. |
| Diyetisyen atama | **Eksik** | Ekran bağlantıyı gecikmeyle simüle ediyor; diyetisyen oluşturma/atama/doğrulama endpoint’i bulunmadı. |
| Anket/kullanılabilirlik ham verisi | **Eksik** | `backend/data` yok; beklenen JSON’lar ve dışa aktarım artefaktı yok. |
| İstatistik analiz betikleri | **Eksik** | `.sav/.xlsx/.csv/.ipynb/R/Python analiz çıktısı yok. AI eğitim kodu araştırma istatistik analizi değildir. |
| Etik kurul/onam | **Eksik** | Taslak form var; etik karar/numara, kurum izni ve imzalı/sesli onam kaydı yok. Form ayrıca “ses kaydı yapılmaz” ve “sesli onam kaydedilebilir” ifadelerini uzlaştırmıyor. |
| Testlerin ürün kodunu sınaması | **Kısmi/Çelişkili** | Bazı unit testler gerçek modelleri içe aktarıyor; geçmiş widget testi sahte widget kuruyor; varsayılan test olmayan `MyApp`/Counter bekliyor. |
| README/yeniden üretilebilirlik | **Eksik** | README varsayılan Flutter metni; SDK, backend, DB, env, model, test, build ve araştırma yeniden üretim adımları yok. |

## 9. Sır ve sürüm kontrolü güvenliği

Gerçek `.env` dosyasındaki değerler kayda alınmadı. Sınıflandırma şöyledir:

| Grup | Durum |
|---|---|
| Uygulama/DEBUG/DB/JWT temel değişkenleri | `SET` |
| SMTP host/port/user/password/from-name | `SET` |
| Google Vision değişkenleri | `EMPTY`/dosyada yok |
| Nutritionix değişkenleri | `EMPTY`/dosyada yok |
| Twilio değişkenleri | `EMPTY`/dosyada yok |

`.gitignore` gerçek `.env` ve `backend/venv` için açık kural içermiyor. Projede denetim anında `.git` dizini bulunmasa da gelecekte sürüm kontrolüne eklenme riski vardır. Eğer bu sırlar daha önce herhangi bir uzak depoya, mesajlaşma kanalına veya rapora girdiyse **rotasyon** yapılmalıdır. Değerler hiçbir audit belgesine kopyalanmamalıdır.

## 10. Denetim sınırları

- Eski debug APK’nın varlığı, mevcut kaynak kodun derlenebildiğini veya APK’nın bu kaynakla aynı olduğunu kanıtlamaz; commit/build provenance yoktur.
- Dış servislerde gerçek mesaj, e-posta veya faturalandırılabilir çağrı yapılmadı.
- Kullanıcı verisi oluşturulmadı, değiştirilmedi veya silinmedi.
- Etik kurul onayı yokken saha çalışması yapılmış varsayılmadı.
- PDF kaynakçası bibliyografik veri tabanlarında bu turda bağımsız doğrulanmadı; bu nedenle kaynaklar yalnız “belgede yazılı” kanıtıdır.
