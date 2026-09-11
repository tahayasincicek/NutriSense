# Kişisel veri ihlali müdahale prosedürü

Kapsam: NutriSense hesap, besin günlüğü, sağlık ölçümleri, diyetisyen
raporları, rıza kayıtları ve araştırma verisinin yetkisiz kişilerce elde
edilmesi, değiştirilmesi, silinmesi veya erişilemez hâle gelmesi.

Teknik müdahale adımları (secret rotasyonu, erişim kapatma, log inceleme)
`docs/runbooks/security_incident_and_secret_rotation.md` içindedir. Bu belge
KVKK bildirim yükümlülüğünü tamamlar.

## Roller

| Rol | Görev | Kişi |
|---|---|---|
| Olay sorumlusu | Olayı açar, kararları kaydeder | `[KURUM KARARI]` |
| Teknik sorumlu | Sızıntıyı durdurur, kanıtı korur, etkiyi ölçer | `[KURUM KARARI]` |
| Veri sorumlusu irtibatı | Kurula ve ilgili kişilere bildirimi yapar | `[KURUM KARARI]` |
| Hukuk danışmanı | Bildirim metnini ve ihlal değerlendirmesini onaylar | `[KURUM KARARI]` |

## Süreler

- Kişisel Verileri Koruma Kurulunun 2019/10 sayılı kararına göre ihlal,
  veri sorumlusunun öğrendiği andan itibaren **en geç 72 saat** içinde
  Kurula bildirilir. Bütün bilgiler bu sürede toplanamazsa bildirim eldeki
  bilgilerle yapılır, eksikler sonradan tamamlanır. Gecikme varsa gerekçesi
  bildirime yazılır.
- Etkilenen kişiler belirlendikten sonra **en kısa sürede** bilgilendirilir.
  İletişim adresi biliniyorsa doğrudan (e-posta), bilinmiyorsa uygulama ve
  web sitesi üzerinden duyurulur.
- Saat sayımı olayın ilk öğrenildiği andan başlar; olay kaydına bu zaman
  yazılır.

## Adımlar

1. **Tespit ve kayıt (0. saat).** Olay kaydı açılır: öğrenilme zamanı, kaynağı,
   ilk gözlem. Ekran görüntüsü, log ve istek kimlikleri değiştirilmeden saklanır.
2. **Sınırlama.** Etkilenen anahtarlar döndürülür, açık uç kapatılır, gerekirse
   ilgili dış sağlayıcı (bildirim, SMS, görüntü tanıma) devre dışı bırakılır.
3. **Değerlendirme (24 saat içinde).** Etkilenen veri kategorileri (özellikle
   sağlık verisi), kişi sayısı, olası sonuçlar ve ihlalin devam edip etmediği
   belirlenir. Sağlık verisi özel nitelikli kişisel veri olduğu için risk
   yüksek kabul edilir.
4. **Kurula bildirim (72 saat içinde).** Kurulun ihlal bildirim formu
   doldurulur. Taslak hukuk danışmanına onaylatılır.
5. **İlgili kişilere bildirim.** Aşağıdaki şablon kullanılır; ekran okuyucuyla
   okunabilir düz metin olarak gönderilir.
6. **Sağlayıcı zinciri.** Veri işleyen bir sağlayıcıdan kaynaklanan ihlalde
   sağlayıcının bildirimi istenir ve dosyaya eklenir.
7. **Kapanış.** Kök neden, alınan önlemler ve tekrarını önleyecek değişiklik
   kaydedilir. İhlal kaydı en az üç yıl saklanır.

## İlgili kişi bildirimi şablonu

> Konu: NutriSense hesabınızla ilgili güvenlik bildirimi
>
> [Tarih] tarihinde [ihlalin kısa ve anlaşılır tanımı] tespit ettik. Bu olayda
> hesabınıza ait [etkilenen veri kategorileri] etkilenmiş olabilir. Olası
> sonuçlar: [sonuçlar]. Aldığımız önlemler: [önlemler]. Sizin için önerimiz:
> [parola değiştirme vb.]. Sorularınız için [veri sorumlusu iletişim adresi]
> adresine yazabilirsiniz. KVKK kapsamındaki haklarınız: [/kvkk-basvuru adresi]

## Tatbikat

Yayından sonraki ilk 30 gün içinde ve sonra yılda bir kez, sentetik veriyle
masa başı tatbikat yapılır; 72 saat sayacının işlediği doğrulanır.
