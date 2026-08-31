# VoiceOver manuel test raporu

Rapor tarihi: 2026-07-27  
Durum: **BLOCKED / NOT RUN — gerçek iPhone ve Xcode yok**

Otomatik Flutter semantics testleri VoiceOver kullanım kanıtı değildir. Bu
rapor gerçek cihazda doldurulmadan “VoiceOver uyumlu” veya “iOS tamamlandı”
denemez.

## Ortam kaydı

| Alan | Değer |
|---|---|
| Commit SHA | NOT RUN |
| App version/build | NOT RUN |
| iPhone modeli | NOT RUN |
| iOS build | NOT RUN |
| VoiceOver sürüm/dil | NOT RUN |
| Türkçe TTS voice | NOT RUN |
| Türkçe speech locale | NOT RUN |
| Kulaklık/Bluetooth | NOT RUN |
| Backend/sandbox sürümü | NOT RUN |
| Test gözlemcisi/tarih | NOT RUN |

Gerçek sağlık veya katılımcı verisi kullanılmaz. Sentetik hesap, fixture yemek
ve sandbox sağlayıcılar kullanılır.

## Otomatik kaynak ön kontrolü

Windows'ta iOS platform dalı zorlanarak gerçek `LoginScreen` ve `CameraScreen`
widget'ları üzerinde route/form semantiği, kamera live region'ı ve dokunmatik
alternatifler test edildi. Locale seçimi dahil tam Flutter paketi 128/128
geçti; iOS kaynak checker'ı da PASS verdi. Bu sonuçlar yalnız test ön koşuludur:
VoiceOver motorunu, iOS izin diyaloglarını, AVAudioSession'ı veya iPhone
kamerasını çalıştırmaz.

## P0 görev matrisi

Her adım için PASS/FAIL/BLOCKED, süre, yardım düzeyi, odak hatası ve kişisel veri
içermeyen kanıt referansı yazılır.

| Görev | Başarı ölçütü | Durum |
|---|---|---|
| Kayıt/giriş | Route adı duyulur; alanlar sıralı; hata ve loading anlaşılır | NOT RUN |
| İzin ve kamera | Kamera/mikrofon gerekçesi okunur; ret ve Ayarlar/manuel alternatif çalışır | NOT RUN |
| Tara–dinle–onayla | Hizalama, yükleme ve güven durumu spam olmadan duyulur; düzeltme mümkündür | NOT RUN |
| Geçmiş | Kayıt tek anlamlı cümle okunur; tarih/porsiyon/kalori anlaşılır | NOT RUN |
| Düzelt/sil | Modal odağı içeride kalır; silme ikinci kesin onay ve geri alma sunar | NOT RUN |
| Diyetisyen raporu | Alıcı/dönem/kanal önizlenir; açık onam ve partial failure doğru duyurulur | NOT RUN |
| Ayarlar/çıkış | Picker değeri/seçimi okunur; çıkış ikinci onay olmadan çalışmaz | NOT RUN |

## VoiceOver ayrıntılı kontroller

### Route ve odak

- Yeni ekranın route adı bir kez duyulur.
- Geri dönüşte odak mantıklı önceki kontrole döner.
- Tab bar seçili durumu ve sekme adı tekrarsız okunur.
- Kamera açıldığında odak görsel preview'a kilitlenmez; ana eyleme erişilebilir.

### Modal, picker ve tarih seçici

- Dialog açıldığında odak başlığa/ilk anlamlı kontrole taşınır.
- Odak modal dışına kaçmaz; İptal her zaman erişilebilir.
- Porsiyon, öğün ve tarih picker'larında label, mevcut value ve ayarlanabilir
  eylem duyulur.
- Kapatınca odak modalı açan kontrole döner.

### Kamera guidance ve live region

- “Kamera açılıyor”, kalite yönlendirmesi, yükleme, sonuç ve hata durumları
  doğru sırada ve bir kez duyurulur.
- Sadece kalite geçince “yiyecek bulundu” denmez.
- Live region güncellemeleri TTS ile üst üste binmez.
- Düşük güven/OOD kesin yemek veya kalori olarak okunmaz.

### Actions

- Standart activate ve adjustable eylemleri etikete uygun çalışır.
- Karttaki dinle/düzelt/sil eylemleri ayrı ve keşfedilebilirdir.
- Custom action kullanılacaksa adı eylemi açıklar; aynı işlem hem kart hem alt
  kontrol olarak iki kez okunmaz.
- Tehlikeli custom/rotor action tek hareketle gönderim veya silme yapmaz.

## TTS/STT ve interruption

| Senaryo | Beklenen | Durum |
|---|---|---|
| VoiceOver açık + otomatik TTS | Çift konuşma yok; kritik durum live region ile duyulur | NOT RUN |
| Türkçe TTS voice yok | Görsel/VoiceOver uyarısı ve dokunmatik alternatif | NOT RUN |
| Türkçe STT locale yok | Başka dile düşmez; klavye/dokunmatik alternatif | NOT RUN |
| STT başlatma | Önce TTS kesilir; dinleme durumu haptic/görsel olarak belirgin | NOT RUN |
| Mikrofon/Speech ayrı ret | Her ret doğru izin adıyla açıklanır | NOT RUN |
| Telefon/Siri interruption | TTS/STT güvenli durur; dönüşte otomatik tehlikeli eylem yok | NOT RUN |
| Kulaklık çıkarma | Hassas içerik beklenmedik şekilde hoparlörden devam etmez | NOT RUN |
| Bluetooth route değişimi | Durum bozulmaz; kullanıcı tekrar deneyebilir | NOT RUN |
| Background/lock | Ses ve mikrofon durur; background audio çalışmaz | NOT RUN |

## Görsel ve motor erişilebilirliği

| Kontrol | Durum |
|---|---|
| Dynamic Type %200 ve en büyük erişilebilir boyut | NOT RUN |
| Koyu mod ve Increase Contrast | NOT RUN |
| Reduce Motion | NOT RUN |
| Dikey/yatay yön ve safe area | NOT RUN |
| Switch Control/Voice Control temel smoke | NOT RUN |
| En az 48×48 dokunma hedefi | NOT RUN |

## Kamera ve performans

- Dört cihaz yönünde JPEG/EXIF sonucu doğru mu: NOT RUN.
- HEIC veya beklenmeyen format güvenli reddediliyor mu: NOT RUN.
- Background/foreground sonrası kamera tekrar açılıyor mu: NOT RUN.
- 20 ardışık taramada bellek trendi/crash: NOT RUN.
- Cold/warm p50/p95 tarama latency: NOT RUN.
- Görüntü/token/e-posta/telefon log sızıntısı: NOT RUN.

## Kabul kararı

**REJECT / iOS tamamlanmadı.** Bu rapordaki P0 görevlerin tamamı PASS olmadan,
engelleyici VoiceOver odağı kalmadan ve Mac archive/TestFlight kanıtı
eklenmeden iOS release kabulü verilemez.
