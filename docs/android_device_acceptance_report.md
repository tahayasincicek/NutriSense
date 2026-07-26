# Android gerçek cihaz kabul raporu

Rapor tarihi: 2026-07-26

Durum: **MANUAL EVIDENCE NOT RUN**

Bu dosya sentetik emulator testini gerçek cihaz sonucu gibi göstermez. Model,
staging sağlayıcıları, kurum application ID'si ve iki fiziksel cihaz henüz
sağlanmadığı için production kabulü verilmemiştir.

## Otomatik/yerel kanıt

| Kontrol | Sonuç | Kanıt |
|---|---|---|
| Flutter production widget suite | Geçti | 122 test, yerel `flutter test --coverage` |
| Static release boundaries | Bekliyor | `python scripts/qa/android_release_checks.py` |
| Dev debug APK | Geçti | `app-dev-debug.apk`; sentetik/veri içermeyen artefakt |
| APK kimliği | Geçti | `com.example.nutrisense.dev`, version `1.0.0-dev` |
| SDK/izin merge | Geçti | min 24, target/compile 36; INTERNET/CAMERA/AUDIO |
| Signed prod AAB | Beklendiği gibi bloke | Kurum ID ve upload key yok |
| Android P0 fixture integration | CI bekleniyor | API 35 emulator workflow |

## Zorunlu fiziksel cihaz matrisi

Her hücreye cihaz modeli/build, saat, gözlemci ve kişisel veri içermeyen kanıt
referansı yazılmalıdır.

| Senaryo | Düşük sınıf API 24–28 | Orta sınıf API 33–36 |
|---|---|---|
| Temiz kurulum, login/register | NOT RUN | NOT RUN |
| Kamera geçici ret/tekrar | NOT RUN | NOT RUN |
| Kamera kalıcı ret/Ayarlar dönüşü | NOT RUN | NOT RUN |
| Mikrofon ret/dokunmatik alternatif | NOT RUN | NOT RUN |
| Yüksek/orta/düşük güven tarama | NOT RUN | NOT RUN |
| Porsiyon sesli/dokunmatik düzeltme | NOT RUN | NOT RUN |
| Onay -> geçmişte görünme | NOT RUN | NOT RUN |
| Rapor önizleme/açık onam/partial | NOT RUN | NOT RUN |
| TalkBack odak ve çift konuşma | NOT RUN | NOT RUN |
| %200 font, koyu/yüksek kontrast | NOT RUN | NOT RUN |
| Uçak modu/yavaş ağ/retry | NOT RUN | NOT RUN |
| Background, kill, kamera dönüşü | NOT RUN | NOT RUN |
| Türkçe TTS/STT, kulaklık | NOT RUN | NOT RUN |
| Logout/cache ve hesap silme | NOT RUN | NOT RUN |

## Ölçülecek değerler

- Cold/warm tarama latency: p50/p95; recognition ve nutrition süreleri ayrı.
- 20 ardışık fixture/sandbox taramada crash/ANR; uydurma crash-free yüzdesi yok.
- Android Studio Profiler ile başlangıç/scan/history sonrası bellek ve
  tekrarlı taramada büyüme.
- Logcat PII kontrolü: token, parola, e-posta, telefon, base64, görüntü yolu.
- Kamera geçici dosyasının ekran kapanışı/process lifecycle sonrası durumu.

## Kabul kararı

Şu anda **REJECT / NOT READY FOR STORE**. Aşağıdakiler tamamlanınca karar
yeniden verilir:

1. İki fiziksel cihaz satırlarının kanıtla doldurulması.
2. Doğrulanmış staging API ve provider sandbox.
3. Kurum application ID, upload key ve internal-track signed AAB.
4. Gizlilik politikası/Data Safety hukuk onayı.
5. Gerçek model varsa model kartı, checksum, parity ve cihaz latency kanıtı;
   yoksa offline AI iddiasının release metninden çıkarılması.
