# NutriSense Erişilebilirlik Uygunluk Raporu

## Rapor durumu

- Sürüm tarihi: 19 Temmuz 2026
- Kapsam: Flutter mobil istemci; kayıt/girişten tarama, geçmiş ve diyetisyen raporuna kadar ana görevler
- Hedef: WCAG 2.1 AA ve mobil erişilebilirlik iyi uygulamaları
- Mevcut beyan: **Kısmi uygunluk hedefleniyor. “WCAG 2.1 AA uyumlu” iddiası kullanılmamalıdır.**
- Kanıt sınırı: Otomatik testler Windows üzerinde çalıştırıldı. Android 16 emülatörü bağlıdır; bu çalışmada fiziksel cihaz/TalkBack oturumu tamamlanmamıştır. Depoda `ios/` platformu yoktur; VoiceOver testi engellidir.

Bu rapor otomatik kontrolleri gerçek kullanıcı testi yerine koymaz. Özellikle kamera hizalama, ortam gürültüsü, kulaklık/Bluetooth yönlendirmesi ve TalkBack ile uçtan uca görev tamamlaması fiziksel cihazda doğrulanmadan tam uygunluk iddia edilemez.

## Uygulanan erişilebilirlik mimarisi

### Tek konuşma koordinatörü

Uygulamadaki iki paralel TTS motoru tek `AccessibilityService` altında birleştirildi. Servis:

- kritik, yüksek, normal ve düşük öncelikli bir konuşma kuyruğu kullanır;
- aynı anda eklenen mesajları monoton sıra numarasıyla kayıpsız sıralar;
- uygulama arka plana geçtiğinde konuşmayı durdurur;
- STT başlamadan TTS'yi ve bekleyen kuyruğu iptal eder;
- STT bitince konuşma çıkışını tekrar kullanılabilir hale getirir;
- `MediaQuery.accessibleNavigation` etkin olduğunda otomatik TTS'yi susturarak ekran okuyucuyla çift konuşmayı azaltır;
- kullanıcı tarafından açıkça istenen “sonucu/özeti dinle” eylemlerine ekran okuyucu açıkken de izin verir;
- Türkçe ses bulunmadığında başarı varmış gibi davranmaz ve hata durumunu servis durumunda tutar;
- iOS ses kategorisinde Bluetooth ve Bluetooth A2DP seçeneklerini tanımlar.

`accessibleNavigation`, işletim sistemindeki yardımcı teknoloji tercihinin Flutter'a yansıyan bir göstergesidir; tüm cihazlarda yalnız TalkBack/VoiceOver etkinliğini kesin olarak kanıtlamaz. Bu nedenle gerçek cihaz kontrolü zorunludur.

### Bağlama duyarlı sesli komut güvenliği

Komut yorumlama; global navigasyon, kamera hazır, tarama onayı, porsiyon düzenleme, geçmiş, silme onayı, rapor önizleme, rapor onayı ve gönderim onayı bağlamlarına ayrıldı.

- “Evet”, “hayır” ve “iptal” yalnız etkin onay bağlamında kabul edilir.
- “Tara”, “geri” ve “bugün ne yedim” gibi geri alınabilir navigasyon eylemlerinde sınırlı fuzzy eşleşme kullanılabilir.
- “Rapor gönder” ve “kaydı sil” için fuzzy eşleşme kabul edilmez.
- Rapor gönderiminde ilk kesin komuttan sonra 12 saniyelik, tek kullanımlık ikinci kesin “evet” onayı gerekir.
- Aday seçimi ve `porsiyon 150 gram` gibi değer taşıyan komutlar yalnız ilgili tarama bağlamında çalışır.
- Mikrofon izni veya STT hatasında dokunma/klavye alternatifi görünür kalır.

Silme komutu güvenlik motorunda tanımlanmış ve test edilmiştir; geçmiş ekranındaki sesli girişe henüz bağlanmamıştır. Bu nedenle sesle silme tamamlanmış sayılmaz.

## Erişilebilirlik görev haritası

Durumlar: **Uygulandı** kod ve otomatik kanıt var; **Kısmi** bazı yollar var fakat fiziksel cihaz veya bağ eksik; **Eksik** görev bağımsız tamamlanamıyor; **Bloklu** platform/harici önkoşul yok.

| Görev | TalkBack | VoiceOver | Yalnız TTS + STT | Az gören kullanıcı | Durum ve kanıt |
|---|---|---|---|---|---|
| Kayıt | Form alanları ve dokunma eylemleri mevcut; gerçek cihaz sırası bekliyor | `ios/` yok | Sesle form doldurma yok; klavye alternatifi var | Kaydırılabilir form; 200% ayrı fiziksel kontrol bekliyor | Kısmi |
| Giriş | Route adı, alan etiketleri, şifre görünürlüğü ve odak sırası otomatik testli | `ios/` yok | Sesle kimlik bilgisi girişi yok; klavye kullanılabilir | 200% widget testi geçti | Kısmi; `test/widget/login_accessibility_test.dart` |
| Kamera/mikrofon izinleri | Durum ve dokunma alternatifleri var; sistem izin diyaloğu gerçek cihazda bekliyor | `ios/` yok | Mikrofon reddinde butonlar kullanılabilir | Kalıcı ret ve yeniden deneme görünür | Kısmi |
| Taramayı başlatma | Büyük semantik tarama kontrolü var | `ios/` yok | Global “tara” navigasyonu ve kamera eylemleri kısmi | En az 48dp hedef, yüksek görünürlük | Kısmi |
| Kamera hizalama/kalite | Görsel olmayan durum metni ve duyurular var; gerçek sahne kalibrasyonu bekliyor | `ios/` yok | Kısa TTS/haptic mevcut; ortam testi yok | Metinsel kalite yönergeleri var | Kısmi |
| Sonucu dinleme | Tek birleşik sonuç semantiği ve kullanıcı tetiklemeli dinleme var | `ios/` yok | Sonuç TTS ile dinlenebilir | Metin ve durum etiketi görünür | Uygulandı; gerçek cihaz kanıtı bekliyor |
| Aday seçme | En fazla üç adayın dokunma kontrolleri var | `ios/` yok | “Birinci/ikinci/üçüncü seçenek” bağlama bağlı | Metin seçenekleri görünür | Kısmi; parser ve kamera testleri geçti |
| Porsiyon düzeltme | Dokunma seçenekleri ve değer bilgisi var | `ios/` yok | `porsiyon N gram` 0–2000 g aralığında kabul edilir | Büyüyebilen kontrol/metin | Kısmi |
| Onaylama/kaydetme | Evet/hayır/yeniden çek dokunma alternatifleri mevcut | `ios/` yok | Evet/hayır yalnız tarama onayında çalışır | Renk dışı metin ve ikon kullanılır | Kısmi; gerçek backend E2E ayrı önkoşul |
| Geçmişi dinleme | Kayıt tek anlamlı cümle; günlük özet butonu | `ios/` yok | Global “bugün ne yedim” geçmişe gider; kayıt bazlı ses komutu yok | Loading/empty/offline/error açık durumları | Kısmi |
| Kaydı düzeltme/öğün değiştirme | Gerçek kart eylemleri mevcut | `ios/` yok | Sesle düzenleme bağlı değil | Dokunma alternatifleri ve diyalog | Kısmi |
| Kaydı silme | Onay diyaloğu ve dokunma yolu mevcut | `ios/` yok | Güvenli parser var, geçmiş STT bağlantısı eksik | Açık onaylı eylem | Kısmi |
| Diyetisyen atama | E-posta alanı, bulma/onay/iptal kontrolleri | `ios/` yok | Sesli atama yok | Kaydırılabilir kartlar | Kısmi; doğrulanmış sandbox verisi gerekir |
| Rapor önizleme | Alıcı, dönem, kayıt ve kanal özeti semantik | `ios/` yok | Kullanıcı “özeti dinle” ile TTS ister | Metin ve maskeli alıcı gösterilir | Uygulandı; gerçek cihaz bekliyor |
| Rapor onayı/gönderme | Checkbox ve gönder butonu; live region sonucu | `ios/` yok | Kesin komut + ikinci kesin onay; fuzzy reddedilir | 200% widget testi geçti | Kısmi; sandbox backend önkoşulu |
| Anket | Soru grupları ve dokunma cevapları var | `ios/` yok | Açık metinde sesli giriş var; tüm soru tipleri sesle tamamlanmıyor | Reduce motion dikkate alınıyor | Kısmi |
| Ayarlar | Gruplar, switch/slider semantiği var | `ios/` yok | Sesli “ayarlar” navigasyonu var | Yüksek kontrast ve konuşma tercihleri var | Kısmi |
| Çıkış | Dokunma yolu ve auth temizliği mevcut | `ios/` yok | Sesli çıkış komutu yok | Açık etiketli kontrol | Kısmi |

## Altı ana araştırma görevi için kabul durumu

1. **Kayıt/giriş:** Gerçek ekran otomatik testli; TalkBack ve fiziksel klavye testi yapılmadı — kısmi.
2. **Tara → sonucu dinle → aday/porsiyon onayı → kaydet:** Gerçek kamera ekranı ve güvenli komut parser'ı testli; fiziksel kamera/backend uçtan uca kanıtı yok — kısmi.
3. **Geçmişi dinle → düzelt/sil:** Gerçek geçmiş uygulamada aktif; sesle düzeltme/silme bağlanmadı — kısmi.
4. **Diyetisyen ata:** Dokunma yolu var; doğrulanmış sandbox diyetisyen ve TalkBack kanıtı gerekiyor — kısmi.
5. **Raporu önizle → açık onay → gönder:** Gerçek wizard testli ve sesli kritik eylem çift onaylı; sandbox + ekran okuyucu uçtan uca koşusu gerekiyor — kısmi.
6. **Anket → ayarlar → çıkış:** Dokunma ve bazı sesli yollar var; yalnız STT ile tam görev yok — kısmi.

Sonuç: Altı görevin hiçbiri bu rapor tarihinde “ekranı görmeden gerçek cihazda bağımsız tamamlandı” şeklinde raporlanmamalıdır. Kod tabanı bu doğrulamaya hazırlanmıştır; insan test kanıtı `docs/manual_screen_reader_test_plan.md` ile toplanmalıdır.

## WCAG 2.1 / mobil kriter değerlendirmesi

| Kriter | Durum | Kanıt / açık boşluk |
|---|---|---|
| 1.1.1 Metin Olmayan İçerik | Kısmi | Ana görev ikonlarında etiketler, dekoratif alt öğelerde `ExcludeSemantics`; tüm ekran envanteri manuel taranmalı |
| 1.3.1 Bilgi ve İlişkiler | Kısmi | Başlık, alan, seçili/durum semantiği; form hata ilişkilendirmesi gerçek ekran okuyucuda doğrulanmalı |
| 1.3.2 Anlamlı Sıra | Kısmi | Giriş odak sırası widget testli; tüm route'lar manuel test bekliyor |
| 1.3.4 Yönlendirme | Kısmi | Uygulama yön kilidi kaldırıldı; kamera ve tüm ekranlar yatay fiziksel test bekliyor |
| 1.4.3 Kontrast (Minimum) | Kısmi | Ana tema çifti 4.5:1 otomatik testi geçti; her durum/gradient/disabled rengi ölçülmedi |
| 1.4.4 Metni Yeniden Boyutlandırma | Kısmi | AppShell, giriş, kamera ve rapor gerçek widget'larında 200% testleri geçti; tüm ekranlar tamamlanmadı |
| 1.4.10 Yeniden Akış | Kısmi | Sabit tarama kartı içerikle büyür; 320 CSS px eşdeğer genişlik ve tüm ekranlar bekliyor |
| 1.4.11 Metin Dışı Kontrast | Değerlendirilmedi | Odak, sınır ve ikon kontrastlarının tam envanteri yok |
| 2.1.1 Klavye | Kısmi | Formlar ve dokunma alternatifleri var; harici klavye odağı fiziksel test edilmedi |
| 2.2.1 Zamanlama Ayarlanabilir | Kısmi | Kritik sesli onay 12 saniye sonra güvenle iptal olur; kullanıcı ayarı yok, dokunma yolu süresiz |
| 2.3.3 Etkileşim Animasyonu | Kısmi | Anket animasyonları `disableAnimations` tercihine uyar; tüm animasyonlar taranmalı |
| 2.4.2 Sayfa Başlıklı | Kısmi | Giriş, kamera ve rapor route adları var; tam route envanteri bekliyor |
| 2.4.3 Odak Sırası | Kısmi | Giriş testi var; dinamik live region sonrası odak davranışı cihazda bekliyor |
| 2.4.6 Başlıklar ve Etiketler | Kısmi | Ana görev kontrolleri açıklayıcı etiketli; manuel tarama gerekli |
| 2.4.7 Görünür Odak | Değerlendirilmedi | Switch Access/harici klavye odağı ölçülmedi |
| 2.5.3 İsimde Etiket | Kısmi | Görünür eylem adları çoğu semantik etikette bulunur; tam otomatik kural yok |
| 3.2.2 Girişte | Kısmi | Alan değişiklikleri kendiliğinden kritik eylem başlatmaz; tüm formlar taranmalı |
| 3.3.1 Hata Tanımlama | Kısmi | Form ve ağ hataları metin/live region ile gösterilir; zamanlama cihazda bekliyor |
| 3.3.2 Etiketler/Talimatlar | Kısmi | Giriş, kamera ve rapor yönergeleri mevcut |
| 4.1.2 Ad, Rol, Değer | Kısmi | Gerçek ana ekran semantik testleri var; tüm özel kontrollerin snapshot'ı yok |
| 4.1.3 Durum Mesajları | Kısmi | Kamera, global STT, rapor ve yükleme durumlarında live region kullanılır; TalkBack zamanlaması bekliyor |

48×48 dp hedef, bu projede mobil dokunma güvenliği hedefidir. WCAG 2.1'de 2.5.5 AAA seviyesindedir; bu ölçü tek başına AA uygunluk kanıtı olarak sunulmaz.

## Otomatik kanıt

Bu değişiklik setinde kullanılan gerçek uygulama testleri:

```powershell
flutter test test/unit/contextual_voice_command_test.dart
flutter test test/widget/camera_screen_test.dart
flutter test test/widget/login_accessibility_test.dart
flutter test test/widget/dietitian_report_wizard_test.dart
flutter test test/accessibility/accessibility_test.dart
```

Kapsanan kanıtlar:

- bağlam dışı evet/hayır reddi;
- kritik eylemde fuzzy komut reddi, tek kullanımlık ikinci onay ve timeout;
- gerçek `CameraScreen` üzerinde izin/dokunma alternatifleri ve 200% yatay düzen;
- gerçek `LoginScreen` route, alan, eylem, odak sırası, 200% ve 48dp kontrol;
- gerçek rapor wizard'ında açık onay, sesli komut kontrolü ve 200%;
- gerçek `AppShell` sekme adları, sesli komut kontrolü, 200% ve ana kontrast hesabı.

Otomatik testlerde sahte widget ağacı kurulmamıştır. Platform kamera, TTS, STT ve sağlayıcı çağrıları testte başlatılmadan gerçek ekranlar pump edilmiştir.

Tam `flutter test` koşusunda 104 test geçti. `flutter analyze --no-pub --no-fatal-infos` sıfır error ve sıfır warning ile tamamlandı; 52 adet mevcut info düzeyi bulgu (çoğunlukla Flutter API deprecation ve `prefer_const`) ayrı teknik temizlik işi olarak kalmıştır. Eski çoklu-pencere uyumsuz `SemanticsService.announce` kullanımları bu çalışmada güncel `sendAnnouncement` API'sine taşındı.

## Açık engeller ve riskler

- P0: Fiziksel Android cihazda TalkBack ile altı görev tamamlanmış değildir.
- P0: `ios/` platformu yoktur; VoiceOver, iOS mikrofon/kamera izinleri ve iOS ses yönlendirmesi test edilemez.
- P0: Fiziksel kamera + kanonik backend + sandbox rapor gönderimi aynı senaryoda kanıtlanmamıştır.
- P1: Geçmişte sesli düzeltme/silme, diyetisyen atama ve çıkış komutları gerçek eylemlere bağlı değildir.
- P1: Tüm ekranların 200%, yatay, yüksek kontrast ve azaltılmış hareket matrisi tamamlanmamıştır.
- P1: Türkçe TTS sesi bulunamama durumu servis tarafından saptanır; kullanıcıya merkezi ve kalıcı ayar uyarısı henüz gösterilmez.
- P1: TalkBack açıkken çift konuşmayı bastırma `accessibleNavigation` göstergesine dayanır ve cihazlar arasında doğrulanmalıdır.
- P1: Gürültü, kısmi STT sonucu, Bluetooth kulaklık geçişi ve çağrı/medya kesintileri test edilmemiştir.
- P2: Tüm özel widget'lar için odak sırası/semantik snapshot ve non-text contrast otomasyonu yoktur.

## Uygunluk beyan kapısı

“WCAG 2.1 AA uyumlu” ifadesi ancak aşağıdakilerin tümü sağlandıktan sonra değerlendirilebilir:

1. Manuel plandaki P0 Android/TalkBack senaryoları iki Android sürümünde geçer.
2. iOS platformu eklenir ve en az bir desteklenen iPhone/VoiceOver koşusu geçer veya iOS açıkça ürün kapsamından çıkarılır.
3. Tüm ana ekranlarda 200%, yatay, yüksek kontrast, reduce motion ve odak görünürlüğü matrisi tamamlanır.
4. Otomatik testler CI'da geçer ve sonuç artefaktı saklanır.
5. En az görme engelli katılımcılarla etik/onamlı kullanılabilirlik testi yapılır; ham veri olmadan başarı yüzdesi üretilmez.
6. Bulguların P0/P1 olanları kapatılır ve kalan istisnalar sürüm notunda açıklanır.
