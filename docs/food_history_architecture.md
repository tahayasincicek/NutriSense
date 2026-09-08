# Beslenme günlüğü mimarisi

## Kapsam ve kaynak gerçek

Aktif geçmiş özelliği yalnız `FoodHistoryScreen` üzerinden çalışır. `AppShell` içindeki Geçmiş sekmesi bu ekranı açar; mock kayıt veya ikinci bir geçmiş ekranı yoktur. Ürün verisinin kaynak gerçeği veritabanı ve `/api/v1/food-history/{user_id}` sözleşmesidir. Mobil uygulama özetleri farklı bir formülle yeniden hesaplamaz; backend'in döndürdüğü günlük ve dönem toplamlarını sunar.

Yalnız kullanıcı tarafından onaylanmış ve silinmemiş kayıtlar geçmişte ve diyetisyen raporunda görünür. Modelin ilk tahmini düzeltildiğinde `original_food_name` ile `original_food_name_tr` araştırma bütünlüğü için ayrı tutulur; kullanıcı arayüzü düzeltilmiş değeri esas alır.

## Durum modeli

Riverpod `HistoryController` aşağıdaki açık durumları yönetir:

| Durum | Kullanıcı davranışı |
|---|---|
| `initial` | Provider henüz yüklenmedi. |
| `loading` | İlk ağ isteği sürüyor. |
| `data` | Sunucudan alınan onaylı kayıtlar gösteriliyor. |
| `empty` | Seçilen dönemde kayıt yok; çalışan “Besin tara” eylemi sunuluyor. |
| `offlineCache` | Ağ başarısız; tarih aralığı eşleşen son güvenli cache açıkça etiketleniyor. |
| `refreshing` | Mevcut veri korunurken pull-to-refresh veya sayfalama sürüyor. |
| `error` | Kullanılabilir veri/cache yok; hata ve yeniden deneme gösteriliyor. |

Oturum kimliği yoksa controller `AUTH_REQUIRED` üretir ve repository/API çağrısı yapmaz. Kimlik request gövdesinden değil güvenli oturumdan gelir. Backend ayrıca token sahibinin URL'deki kullanıcıyla eşleşmesini ve her kayıt mutasyonunun sahipliğini doğrular.

## Tarih, özet ve sayfalama

- Günlük, son 7 gün ve son 30 gün aralıkları mobilde yalnız sorgu aralığı olarak seçilir.
- Backend kayıt tarihini UTC timestamp'ten `Europe/Istanbul` takvim gününe dönüştürür.
- `from_date` ve `to_date` kapsayıcıdır; ters veya 366 günden büyük aralık reddedilir.
- Sayfalama kayıt sayısıyla değil yerel takvim günüyle yapılır; aynı güne ait kayıtlar bölünmez.
- Kalori hedefi “kullanıcının takip hedefi” olarak yazılır ve tıbbi öneri sayılmaz. Negatif kalan değer “hedefin üzerinde” şeklinde güvenli dille sunulur.

## Düzeltme, silme ve audit

Besin etiketi, porsiyon ve öğün türü `PATCH /food-logs/{log_id}` ile değiştirilir. Porsiyon değişince kalori ve makrolar backend'deki kanonik besin hesabıyla yeniden hesaplanır. Silme soft-delete'tir, açık kullanıcı onayı ister ve Snackbar içindeki “Geri al” eylemi restore endpointini çağırır. Update, delete ve restore işlemlerinin tamamı `audit_events` kaydı üretir. Başka kullanıcıya ait kayıt mutasyonlarda bulunamadı gibi davranır.

## Çevrim dışı ve yerel veri güvenliği

MVP çevrim dışı modu salt okunurdur. Son başarılı response kullanıcı kimliğine göre ayrılmış JSON olarak `flutter_secure_storage` üzerinden Android Keystore/iOS Keychain korumalı depoya yazılır. Beslenme verisi Hive veya SharedPreferences içine yazılmaz. Cache yalnız istenen tarih aralığı birebir eşleşirse kullanılır ve arayüzde çevrim dışı olduğu belirtilir.

Çevrim dışı edit/silme kuyruğu bu sürümde yoktur; ağ gerektiren mutasyon başarısızsa yerel veri başarılıymış gibi değiştirilmez. Bu seçim sessiz çatışma ve çift mutasyon riskini önler. Başarılı mutasyondan sonra sunucu yeniden okunur (server-wins). Logout, geçersiz oturum, kilit açma ve hesap silmede tüm geçmiş cacheleri temizlenir.

## Erişilebilirlik

Her besin kaydının görünür ayrıntıları `ExcludeSemantics` içindedir ve tek bir `Semantics` cümlesi; Türkçe ad, porsiyon, kalori, makrolar, öğün, yerel tarih-saat, tanıma kaynağı ve tahmini/düzeltilmiş durumunu okur. Dinle, düzelt, öğün değiştir ve sil düğmeleri ayrı ve bağlama özgü erişilebilir etiketlere sahiptir. Tarih seçici, pull-to-refresh, sayfalama ve boş durum eylemi ekran okuyucuyla kullanılabilir.

## Yeniden üretim

```powershell
cd C:\projeler\NutriSense
flutter test test\widget\food_history_screen_test.dart
flutter test test\unit\food_entry_test.dart test\unit\history_cache_store_test.dart
flutter test test\contract\api_contract_test.dart

cd backend
$env:DATABASE_URL='sqlite+pysqlite:///:memory:'
.\venv\Scripts\python.exe -m pytest tests\test_food_history_lifecycle.py -q
```

Widget testleri ürün `FoodHistoryScreen` sınıfını doğrudan import eder. Loading, empty, data, error, offline cache, auth kapısı, edit, delete/undo ve tek-cümle semantics senaryolarında yalnız repository provider override edilir; test içinde sahte kart ağacı kurulmaz.
