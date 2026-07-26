# NutriSense — iOS App Store Listesi ve Info.plist Yapılandırması

> **Yayın kapısı:** Bu dosyadaki kapsam, model başarısı ve uyumluluk iddiaları kanıt envanteriyle doğrulanmadan mağazada kullanılmamalıdır. Gerçek iOS cihaz E2E testi henüz çalıştırılmamıştır.

## Info.plist Gizlilik Açıklamaları

Aşağıdaki anahtarları `ios/Runner/Info.plist` dosyasına ekleyin:

```xml
<!-- ═══ KAMERA ═══ -->
<key>NSCameraUsageDescription</key>
<string>NutriSense yiyecekleri tanımak ve kalori bilgisi sağlamak için kameraya erişir. Çekim analiz için güvenli sunucuya gönderilebilir; görüntü varsayılan olarak saklanmaz.</string>

<!-- ═══ MİKROFON ═══ -->
<key>NSMicrophoneUsageDescription</key>
<string>NutriSense sesli komutlarınızı algılayabilmek için mikrofon erişimi gerektirir. Ses kaydı saklanmaz veya paylaşılmaz.</string>

<!-- ═══ KONUŞMA TANIMA ═══ -->
<key>NSSpeechRecognitionUsageDescription</key>
<string>NutriSense sesli komutlarınızı metne dönüştürmek için konuşma tanıma özelliğini kullanır.</string>

<!-- ═══ FOTOĞRAF KİTAPLIĞI ═══ -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Taranan besin fotoğraflarını kaydetmek için fotoğraf kitaplığına erişim gerektirir.</string>

<!-- ═══ ARKA PLAN SES ═══ -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

## Xcode Accessibility Capability Ayarları

1. Xcode'da projeyi açın: `ios/Runner.xcworkspace`
2. Runner target → Signing & Capabilities
3. **Background Modes** → Audio (TTS arka planda devam etsin)
4. VoiceOver uyumluluğu için özel ayar gerekmez (Flutter Semantics yeterli)

## App Store Connect Bilgileri

### Uygulama Adı
NutriSense — Akıllı Besin Tanıma

### Alt Başlık
Görme Engelliler İçin Kalori Takibi

### Açıklama

NutriSense, görme engelli bireyler için yapay zeka destekli besin tanıma ve kalori takip prototipidir. Uygulama çekilen görüntüyü yapılandırılmış çevrimiçi servisle analiz eder; sonuç ve veri kaynağını sesli bildirir ve geçmişe yazmadan önce kullanıcı onayı ister. Hizmet kullanılamıyorsa sahte sonuç üretmez, manuel giriş sunar.

**Öne Çıkan Özellikler:**

• Yapay zeka ile otomatik besin tanıma (1000+ besin)
• Türkçe sesli geri bildirim — ekrana bakmaya gerek yok
• Sesli komutlarla kontrol: "Tara", "Bugün ne yedim", "Gönder"
• Günlük/haftalık kalori ve makro takibi
• Diyetisyene otomatik rapor gönderme
• VoiceOver ve WCAG 2.1 AA hedefleniyor; gerçek iOS cihaz doğrulaması tamamlanmadı
• Yüksek kontrast modu ve ayarlanabilir yazı boyutu
• Türk mutfağına özel yemek veritabanı
• Kamera görüntüsü varsayılan olarak saklanmaz; diyetisyen paylaşımı açık onay gerektirir

> **Hukuki ve teknik yayın kapısı:** Depoda iOS platform projesi ve gerçek cihaz
> kanıtı yoktur. “VoiceOver ile tam uyumlu”, “WCAG 2.1 AA uyumlu” veya “KVKK
> uyumlu” ifadeleri; cihaz testi, kurum veri sorumlusu/hukuk incelemesi ve
> production altyapı kanıtı olmadan mağazada kullanılmamalıdır.

TÜBİTAK 2209-A desteğiyle geliştirilmiştir.

### Anahtar Kelimeler (100 karakter)
besin,kalori,görme engelli,erişilebilirlik,yapay zeka,diyetisyen,sesli,TalkBack,sağlık

### Kategori
Ana: Sağlık ve Fitness
İkincil: Tıp

### Yaş Sınırı
4+ (Uygunsuz içerik yok)

### Gizlilik Politikası
https://nutrisense.app/privacy

### Destek URL
https://nutrisense.app/support
