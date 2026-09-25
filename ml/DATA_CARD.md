# DATA CARD — NutriSense MVP v1

Durum: **not collected / not approved / not evaluated**  
Kapsam: `nutrisense-mvp-tr-10-v1`  
Son gözden geçirme: 2026-07-17

## Amaç ve kapsam dondurma

Veri, tek bir tabak fotoğrafından 10 önceden belirlenmiş sınıfı araştırma prototipi düzeyinde ayırt etmek için planlanmıştır. Porsiyon hacmi, kalori tahmini, içerik/alerjen tanısı, çoklu yemek segmentasyonu ve “her yiyeceği tanıma” kapsam dışıdır. Görme engelli kullanıcıya kesinlik izlenimi verilmez; düşük güven, OOD ve çoklu tabak manuel onaya gider.

PDF’de “sınırlı sayıda besin” sınırı, 10 aylık proje süresi ve Türkçe/sesli erişilebilirlik hedefi vardır. Bu yüzden sık karşılaşılabilecek ve kontrollü veri toplanabilecek beş genel sınıf ile beş Türkiye odaklı sınıf seçilmiştir.

## Önceden belirlenmiş sınıflar ve veri hedefi

| Sınıf | Hedef kabul edilmiş görsel | En az çekim grubu | Planlanan kaynak | Lisans durumu | Çeşitlilik planı | Başlıca karışma riski |
|---|---:|---:|---|---|---|---|
| baklava | 1.000 | 60 | Food-101 + yerel çekim | Food-101 beklemede; yerel onam gerekli | dilim/tepsi, fıstık/ceviz, tabak/ambalaj, iç/dış ışık | börek |
| hamburger | 1.000 | 60 | Food-101 | Resmi sayfada lisans yok; onay bekliyor | paket/tabak, açı, tek/çift kat, farklı arka plan | sandviç, OOD |
| pizza | 1.000 | 60 | Food-101 | Onay bekliyor | bütün/dilim, ince/kalın hamur, kutu/tabak | lahmacun |
| omelette | 1.000 | 60 | Food-101 + yerel çekim | Food-101 beklemede; yerel onam gerekli | sade/sebzeli, tava/tabak, farklı pişme | menemen |
| french_fries | 1.000 | 60 | Food-101 | Onay bekliyor | kutu/tabak, ince/kalın, soslu/sossuz | OOD atıştırmalık |
| simit | 300 | 60 | onamlı yerel çekim | proje onamı + telif izni | susam yoğunluğu, bütün/parça, poşet/tabak | OOD halka ekmek |
| lahmacun | 300 | 60 | onamlı yerel çekim | proje onamı + telif izni | açık/katlı, yeşillik, tabak/kağıt | pizza |
| manti | 300 | 60 | onamlı yerel çekim | proje onamı + telif izni | yoğurt/sos, yakın/uzak, farklı kap | OOD makarna |
| mercimek_corbasi | 300 | 60 | onamlı yerel çekim | proje onamı + telif izni | kase rengi, limon/kruton, kıvam/ışık | diğer çorbalar (OOD) |
| menemen | 300 | 60 | onamlı yerel çekim | proje onamı + telif izni | tava/tabak, soğanlı/soğansız görünüm, kıvam | omlet |
| OOD | 500 | 100 | onamlı desteklenmeyen yemek + yiyecek olmayan sahne | proje onamı + telif izni | boş tabak, paket, el/masa, çoklu yemek, bulanık/koyu görüntü | yanlış yüksek güven |

Sayılar **veri toplama hedefidir; mevcut örnek sayısı değildir**. Her Türkiye sınıfı için en az 10 bağımsız katkıcı, katkıcı başına birden fazla çekim oturumu, iç/dış mekân, düşük/yüksek aydınlatma, farklı telefon, kap, açı ve arka plan hedeflenir. Demografik özellik yalnız etik protokol açıkça gerektirirse, ayrı ve toplulaştırılmış biçimde tutulur.

## Kaynaklar ve lisans

- Food-101 resmi sayfası 101 sınıf, sınıf başına 750 gürültülü train ve 250 elle incelenmiş test görseli bildirir; fakat sayfa veri seti lisansı belirtmez. Yazılı kullanım onayı olmadan indirme/eğitim/yeniden dağıtım kapalıdır.
- UEC-Food-256 resmi koşulu yalnız ticari olmayan araştırma kullanımına izin verir. Türkiye MVP’siyle alan uyumsuzluğu ve çoklu yemek kopyaları nedeniyle v1’e alınmamıştır.
- Yerel fotoğraflar `docs/data_collection_protocol.md` uyarınca açık rıza ve fotoğraf telif izniyle toplanır. Varsayılan yeniden dağıtım yoktur.
- Bing/Google/kafe menüsü/sosyal medya kazıması yapılmaz.

## Bölme ve sızıntı kontrolü

Train/validation/test oranı 70/15/15’tir. `group_id` aynı tabak ve çekim serisini bir arada tutar. SHA-256 birebir kopyayı; dHash yakın kopyayı saptar ve grupları birleştirir. Aynı byte içeriğinin iki etiketi varsa hazırlama kapanır. Food-101 resmi test kullanılırsa `split_hint=test` ile kilitlenir; bu görseller geliştirme kararında kullanılmaz.

Food-101 çekim serisi kimliği sağlamadığından algısal kopya kümesi yalnız risk azaltımıdır; gerçek çekim ilişkisini garanti etmez. Bu sınırlılık sonuç raporunda yer almalıdır.

## Kalite, kişisel veri ve saklama

Bozuk dosyalar eğitime alınmaz. Yüz, plaka, adres, fiş, ekran, konum metadatası ve ayırt edici kişisel nesne içeren kare reddedilir veya onaylı redaksiyon sürecinden geçer. EXIF dağıtım kopyasından silinir. Onam kayıtları görsel manifestten ayrı, erişim kontrollü tutulur. Katılımcı/hesap UUID’si yerine rastgele çekim grubu kullanılır. Geri çekme talebi veri sürümünü değiştirir ve etkilenen modeller yeniden eğitilene kadar kullanım dışına alınır.

## Bilinen sınırlılıklar

Planlanan veri gerçek kullanım popülasyonunu, bölgesel sunum çeşitliliğini veya tüm yardımcı teknoloji kullanıcılarını temsil etmeyebilir. Tek etiketli sınıflandırma karışık tabaklarda uygun değildir. Fotoğraftan kalori ve porsiyon çıkarımı bu veri kartının doğruladığı bir görev değildir.
