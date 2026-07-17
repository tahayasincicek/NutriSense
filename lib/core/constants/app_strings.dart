// =============================================================================
// lib/core/constants/app_strings.dart
// NutriSense — Türkçe TTS Mesaj Sabitleri
//
// Uygulama genelinde kullanılan TTS mesajları.
// Tüm mesajlar doğal Türkçe cümle yapısında, görme engelli kullanıcılar
// için anlaşılır ve net.
// =============================================================================

/// NutriSense uygulama içi Türkçe mesaj sabitleri
class AppStrings {
  AppStrings._(); // Instance oluşturulmasın

  // ═══════════════════════════════════════════════════════════════════════════
  // KARŞILAMA VE GENEL
  // ═══════════════════════════════════════════════════════════════════════════

  static const welcome = 'NutriSense\'e hoş geldiniz. '
      'Besin taramak için ortadaki büyük butona basın veya '
      '"Tara" komutunu söyleyin.';

  static const welcomeBack = 'Tekrar hoş geldiniz. '
      'Bugün toplam kalori hedefinize ulaşmak için hazır mısınız?';

  static const appDescription =
      'NutriSense, görme engelli bireyler için yapay zekâ destekli '
      'besin tanıma ve kalori takip uygulamasıdır.';

  // ═══════════════════════════════════════════════════════════════════════════
  // BESİN TARAMA YÖNERGELERİ
  // ═══════════════════════════════════════════════════════════════════════════

  static const cameraReady = 'Kamera aktif. Yiyeceği kameranın önüne getirin. '
      'Hazır olduğunuzda "Tara" deyin veya ekrana dokunun.';

  static const cameraInitializing = 'Kamera başlatılıyor, lütfen bekleyin.';

  static const cameraPermissionDenied = 'Kamera erişimi reddedildi. '
      'Lütfen ayarlardan kamera iznini açın.';

  static const scanStarting = 'Tarama başlıyor. Lütfen yiyeceği sabit tutun.';

  static const scanInProgress = 'Görüntü analiz ediliyor, lütfen bekleyin.';

  static const scanHoldSteady = 'Lütfen telefonu biraz daha sabit tutun.';

  static const scanLowLight =
      'Ortam çok karanlık. Lütfen daha aydınlık bir yere geçin.';

  static const scanTooBlurry =
      'Görüntü bulanık. Lütfen telefonu sabit tutun ve netleşmesini bekleyin.';

  static const scanTooBright =
      'Ortam çok parlak. Lütfen gölgeli bir alana geçin.';

  static const scanNoFood = 'Görüntüde yiyecek tespit edilemedi. '
      'Lütfen kamerayı yiyeceğe doğru tutun ve tekrar deneyin.';

  // ═══════════════════════════════════════════════════════════════════════════
  // SONUÇ MESAJLARı
  // ═══════════════════════════════════════════════════════════════════════════

  /// Besin tanındı — parametreli
  static String foodRecognized({
    required String foodName,
    required double calories,
    required double portionG,
  }) =>
      '$foodName tanındı. '
      '${portionG.toStringAsFixed(0)} gram, '
      '${calories.toStringAsFixed(0)} kalori.';

  /// Detaylı sonuç
  static String foodRecognizedDetailed({
    required String foodName,
    required double calories,
    required double portionG,
    required double protein,
    required double carb,
    required double fat,
  }) =>
      '$foodName tanındı. '
      '${portionG.toStringAsFixed(0)} gram porsiyon, '
      '${calories.toStringAsFixed(0)} kalori. '
      '${protein.toStringAsFixed(0)} gram protein, '
      '${carb.toStringAsFixed(0)} gram karbonhidrat, '
      '${fat.toStringAsFixed(0)} gram yağ.';

  /// Kayıt onayı sor
  static String confirmSave(String foodName) =>
      'Analiz tamamlandı. $foodName, kaydetmek ister misiniz? '
      '"Evet" veya "Hayır" deyin.';

  static const savedSuccessfully = 'Besin kaydedildi.';

  static const saveCancelled = 'Kayıt iptal edildi.';

  /// Güven düşük uyarısı
  static String lowConfidence(String foodName, int confidencePercent) =>
      '$foodName olabilir ancak emin değilim. '
      'Güven yüzdesi $confidencePercent. '
      'Tekrar taramak ister misiniz?';

  // ═══════════════════════════════════════════════════════════════════════════
  // GÜNLÜK ÖZETİ
  // ═══════════════════════════════════════════════════════════════════════════

  static String dailySummary({
    required double totalCalories,
    required double targetCalories,
    required int mealCount,
  }) {
    final remaining = targetCalories - totalCalories;
    final buffer = StringBuffer('Günlük özet: ');
    buffer
        .write('Toplam ${totalCalories.toStringAsFixed(0)} kalori tüketildi. ');
    buffer.write('$mealCount öğün kaydedildi. ');

    if (remaining > 0) {
      buffer.write('Hedefinize ${remaining.toStringAsFixed(0)} kalori kaldı.');
    } else if (remaining == 0) {
      buffer.write('Günlük hedefinize tam olarak ulaştınız, tebrikler!');
    } else {
      buffer.write(
        'Günlük hedefinizi ${(-remaining).toStringAsFixed(0)} kalori aştınız. '
        'Dikkatli olmanızı öneririm.',
      );
    }
    return buffer.toString();
  }

  static const noFoodToday = 'Bugün henüz bir besin kaydı yok. '
      'İlk öğününüzü kaydetmek için "Tara" deyin.';

  // ═══════════════════════════════════════════════════════════════════════════
  // DİYETİSYEN
  // ═══════════════════════════════════════════════════════════════════════════

  static String dietitianReportSending(String dietitianName) =>
      'Beslenme raporunuz $dietitianName\'a gönderiliyor.';

  static String dietitianReportSent(String dietitianName) =>
      'Rapor başarıyla $dietitianName\'a gönderildi.';

  static const dietitianNotAssigned = 'Henüz bir diyetisyen atanmamış. '
      'Lütfen ayarlardan diyetisyen bilgilerinizi ekleyin.';

  static const dietitianReportFailed =
      'Rapor gönderilemedi. Lütfen daha sonra tekrar deneyin.';

  // ═══════════════════════════════════════════════════════════════════════════
  // HATA MESAJLARI
  // ═══════════════════════════════════════════════════════════════════════════

  static const errorNetwork = 'İnternet bağlantısı bulunamadı. '
      'Lütfen bağlantınızı kontrol edip tekrar deneyin.';

  static const errorServer = 'Sunucuya bağlanılamadı. '
      'Lütfen birkaç dakika sonra tekrar deneyin.';

  static const errorTimeout = 'İstek zaman aşımına uğradı. '
      'İnternet bağlantınızı kontrol edin.';

  static const errorUnknown = 'Beklenmeyen bir hata oluştu. '
      'Lütfen uygulamayı kapatıp tekrar açın.';

  static const errorMicrophonePermission = 'Mikrofon erişimi reddedildi. '
      'Sesli komut kullanabilmek için ayarlardan mikrofon iznini açın.';

  static const errorSessionExpired =
      'Oturumunuz sona erdi. Lütfen tekrar giriş yapın.';

  // ═══════════════════════════════════════════════════════════════════════════
  // SESLİ KOMUT
  // ═══════════════════════════════════════════════════════════════════════════

  static const listeningStarted = 'Dinliyorum. Komutunuzu söyleyin.';

  static const listeningStopped = 'Dinleme durduruldu.';

  static const commandNotRecognized =
      'Komutu anlayamadım. "Yardım" diyerek kullanılabilir komutları öğrenebilirsiniz.';

  static const commandHelp = 'Kullanılabilir komutlar: '
      '"Tara" — besin taramaya başla. '
      '"Geçmiş" — kalori geçmişini göster. '
      '"Bugün" — günlük özeti oku. '
      '"Gönder" — diyetisyene rapor gönder. '
      '"İptal" — mevcut işlemi iptal et. '
      '"Ayarlar" — uygulama ayarlarını aç. '
      '"Yardım" — bu mesajı tekrar dinle.';

  static String commandRecognized(String command) => '$command komutu alındı.';

  // ═══════════════════════════════════════════════════════════════════════════
  // EKRAN OKUMA
  // ═══════════════════════════════════════════════════════════════════════════

  static const screenScan = 'Besin tarama ekranı. '
      'Kamerayı açmak için tara butonuna basın veya sesli komut verin.';

  static const screenHistory = 'Yemek geçmişi ekranı. '
      'Son yemekleriniz ve günlük kalori özetiniz burada.';

  static const screenDietitian = 'Diyetisyen ekranı. '
      'Raporlarınızı görebilir ve diyetisyeninize gönderebilirsiniz.';

  static const screenSettings = 'Ayarlar ekranı. '
      'Ses hızı, ses tonu, titreşim ve diğer tercihleri buradan değiştirebilirsiniz.';

  static const screenLogin = 'Giriş ekranı. '
      'E-posta ve şifrenizi girerek devam edin.';

  // ═══════════════════════════════════════════════════════════════════════════
  // AYARLAR
  // ═══════════════════════════════════════════════════════════════════════════

  static const settingsSpeechRate = 'Konuşma hızı';
  static const settingsPitch = 'Ses tonu';
  static const settingsVolume = 'Ses seviyesi';
  static const settingsVibration = 'Titreşim';
  static const settingsAutoReadDelay = 'Otomatik okuma gecikmesi';
  static const settingsHighContrast = 'Yüksek kontrast';
  static const settingsSaved = 'Ayarlarınız kaydedildi.';

  static String settingsSpeedPreview(String label) =>
      'Konuşma hızı $label olarak ayarlandı. Bu bir test cümlesidir.';

  static String settingsPitchPreview(String label) =>
      'Ses tonu $label olarak ayarlandı. Bu bir test cümlesidir.';

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB NAVİGASYON
  // ═══════════════════════════════════════════════════════════════════════════

  static const tabScan = 'Tarama sekmesi seçildi.';
  static const tabHistory = 'Geçmiş sekmesi seçildi.';
  static const tabDietitian = 'Diyetisyen sekmesi seçildi.';
  static const tabSettings = 'Ayarlar sekmesi seçildi.';
}
