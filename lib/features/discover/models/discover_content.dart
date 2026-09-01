// =============================================================================
// lib/features/discover/models/discover_content.dart
// NutriSense — Keşfet içeriği (tarifler, kategoriler, ipuçları)
//
// İçerik uygulama içinde tanımlıdır; backend gerektirmez. Yeni tarif/ipucu
// eklemek için aşağıdaki listelere kayıt eklemek yeterlidir.
//
// Metinler ekran okuyucuyla dinlenmek üzere yazılmıştır: kısaltma yerine tam
// kelime, madde madde adımlar, ölçüler açık yazılır ("2 yemek kaşığı" gibi).
// =============================================================================

import 'package:flutter/material.dart';

/// Bir tarif ya da beslenme ipucu.
class DiscoverArticle {
  const DiscoverArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.icon,
    required this.color,
    this.category,
    this.ingredients = const [],
    this.steps = const [],
    this.prepMinutes,
    this.calories,
  });

  final String id;
  final String title;
  final String summary;

  /// Giriş paragrafı. Tarif değilse içeriğin tamamı burada durur.
  final String body;

  final IconData icon;
  final Color color;

  /// Kategori kimliği; kategori listelerinde süzmek için kullanılır.
  final String? category;

  final List<String> ingredients;
  final List<String> steps;
  final int? prepMinutes;
  final int? calories;

  bool get isRecipe => ingredients.isNotEmpty || steps.isNotEmpty;

  /// Kart için tek parça ekran okuyucu etiketi.
  String get semanticLabel {
    final buffer = StringBuffer('$title. $summary');
    if (prepMinutes != null) buffer.write(' Hazırlık $prepMinutes dakika.');
    if (calories != null) buffer.write(' Porsiyon başına $calories kalori.');
    return buffer.toString();
  }

  /// Detay ekranında baştan sona dinlenecek metin.
  String get spokenArticle {
    final buffer = StringBuffer('$title. $summary. $body');
    if (prepMinutes != null) {
      buffer.write(' Hazırlık süresi $prepMinutes dakika.');
    }
    if (calories != null) {
      buffer.write(' Porsiyon başına yaklaşık $calories kalori.');
    }
    if (ingredients.isNotEmpty) {
      buffer.write(' Malzemeler: ${ingredients.join(', ')}.');
    }
    if (steps.isNotEmpty) {
      buffer.write(' Yapılışı: ');
      for (var i = 0; i < steps.length; i++) {
        buffer.write('${i + 1}. adım: ${steps[i]} ');
      }
    }
    return buffer.toString();
  }
}

/// Kategori tanımı.
class DiscoverCategory {
  const DiscoverCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final IconData icon;
  final Color color;
}

const discoverCategories = <DiscoverCategory>[
  DiscoverCategory(
    id: 'kahvaltilik',
    title: 'Kahvaltılık',
    icon: Icons.wb_twilight_rounded,
    color: Colors.amber,
  ),
  DiscoverCategory(
    id: 'fit_tatli',
    title: 'Fit Tatlılar',
    icon: Icons.icecream_rounded,
    color: Colors.pink,
  ),
  DiscoverCategory(
    id: 'ara_ogun',
    title: 'Ara Öğün',
    icon: Icons.apple_rounded,
    color: Colors.green,
  ),
  DiscoverCategory(
    id: 'smoothie',
    title: 'Smoothie',
    icon: Icons.blender_rounded,
    color: Colors.purple,
  ),
  DiscoverCategory(
    id: 'corba',
    title: 'Çorbalar',
    icon: Icons.soup_kitchen_rounded,
    color: Colors.orange,
  ),
  DiscoverCategory(
    id: 'salata',
    title: 'Salatalar',
    icon: Icons.eco_rounded,
    color: Colors.teal,
  ),
];

/// Haftanın öne çıkan tarifi.
const featuredRecipe = DiscoverArticle(
  id: 'kinoa_salatasi',
  title: 'Avokadolu ve Nohutlu Kinoa Salatası',
  summary: 'Yüksek protein, glutensiz ve ferah.',
  body: 'Kinoa bitkisel protein açısından zengin, glutensiz bir tahıldır. '
      'Nohut ile birleştiğinde tam bir protein profili oluşturur; avokado ise '
      'sağlıklı yağ ve tokluk hissi katar. Öğle öğünü ya da akşam hafif bir '
      'ana yemek olarak tüketilebilir.',
  icon: Icons.eco_rounded,
  color: Colors.green,
  category: 'ara_ogun',
  prepMinutes: 25,
  calories: 420,
  ingredients: [
    '1 su bardağı kinoa',
    '1 su bardağı haşlanmış nohut',
    '1 adet olgun avokado',
    '2 yemek kaşığı zeytinyağı',
    '1 adet limonun suyu',
    'Yarım demet maydanoz',
    'Tuz ve karabiber',
  ],
  steps: [
    'Kinoayı bol suyla durulayın, iki su bardağı suda yaklaşık 15 dakika '
        'kısık ateşte pişirin.',
    'Pişen kinoayı geniş bir kaba alıp soğumaya bırakın.',
    'Avokadoyu küp küp doğrayın, üzerine limon suyu gezdirin.',
    'Haşlanmış nohut, avokado ve ince kıyılmış maydanozu kinoaya ekleyin.',
    'Zeytinyağı, tuz ve karabiberi ekleyip nazikçe karıştırın.',
  ],
);

/// Günün ipuçları ve kategori tarifleri.
const discoverArticles = <DiscoverArticle>[
  DiscoverArticle(
    id: 'bagisiklik',
    title: 'Bağışıklık Güçlendirici',
    summary: 'C vitamini deposu besinler listesi.',
    body: 'C vitamini bağışıklık hücrelerinin çalışmasını destekler ve '
        'bitkisel kaynaklı demirin emilimini artırır. Günlük ihtiyaç yetişkin '
        'bir kişi için yaklaşık 75 ile 90 miligram arasındadır. '
        'En zengin kaynaklar: kırmızı biber, maydanoz, kivi, portakal, '
        'brokoli, çilek ve kuşburnu. C vitamini ısıya duyarlı olduğu için bu '
        'besinleri mümkün olduğunca çiğ ya da az pişmiş tüketmek daha '
        'faydalıdır.',
    icon: Icons.security_rounded,
    color: Colors.orange,
  ),
  DiscoverArticle(
    id: 'uyku',
    title: 'Uyku ve Beslenme',
    summary: 'Daha iyi bir uyku için akşam ne yemeli?',
    body: 'Akşam öğünü uyku kalitesini doğrudan etkiler. Yatmadan iki ile üç '
        'saat önce yemeyi bitirmek reflü ve hazımsızlık riskini azaltır. '
        'Triptofan içeren besinler, örneğin süt, yoğurt, hindi eti, muz, '
        'ceviz ve badem, vücudun melatonin üretimini destekler. '
        'Kafein etkisi altı saate kadar sürebildiği için öğleden sonra kahve '
        've koyu çaydan kaçınmak iyi olur. Alkol uykuya dalmayı '
        'kolaylaştırıyor gibi görünse de gece boyu uykuyu böler. '
        'Ağır ve yağlı yemekler sindirimi uzatarak gece uyanmalarına yol '
        'açabilir.',
    icon: Icons.bedtime_rounded,
    color: Colors.indigo,
  ),
  DiscoverArticle(
    id: 'menemen',
    title: 'Protein Yüklü Menemen',
    summary: 'Klasik kahvaltıya protein takviyesi.',
    body: 'Menemen, yumurtanın yüksek kaliteli proteini ile sebzelerin lifini '
        'bir araya getirir. Lor peyniri eklemek protein miktarını artırır ve '
        'öğün sonrası tokluk süresini uzatır.',
    icon: Icons.egg_alt_rounded,
    color: Colors.amber,
    category: 'kahvaltilik',
    prepMinutes: 15,
    calories: 310,
    ingredients: [
      '3 adet yumurta',
      '2 adet orta boy domates',
      '1 adet yeşil sivri biber',
      '2 yemek kaşığı lor peyniri',
      '1 yemek kaşığı zeytinyağı',
      'Tuz ve pul biber',
    ],
    steps: [
      'Biberleri ince doğrayıp zeytinyağında iki dakika kavurun.',
      'Kabuğu soyulmuş ve küp doğranmış domatesleri ekleyin, suyunu '
          'çekene kadar pişirin.',
      'Yumurtaları kırıp karıştırın; çok katı olmadan ocaktan alın.',
      'Lor peynirini üzerine serpip sıcak servis yapın.',
    ],
  ),
  DiscoverArticle(
    id: 'muzlu_dondurma',
    title: 'Tek Malzemeli Muz Dondurması',
    summary: 'Şeker ilavesiz, iki dakikada hazır.',
    body: 'Donmuş muz blenderdan geçtiğinde dondurma kıvamı alır. İlave şeker '
        'gerekmez; muzun kendi doğal şekeri yeterlidir.',
    icon: Icons.icecream_rounded,
    color: Colors.pink,
    category: 'fit_tatli',
    prepMinutes: 5,
    calories: 150,
    ingredients: [
      '2 adet olgun muz',
      '1 yemek kaşığı fıstık ezmesi',
      'İsteğe bağlı bir tutam tarçın',
    ],
    steps: [
      'Muzları dilimleyip en az dört saat derin dondurucuda bekletin.',
      'Donmuş dilimleri fıstık ezmesiyle birlikte blenderdan geçirin.',
      'Kremamsı kıvam alınca hemen servis yapın.',
    ],
  ),
  DiscoverArticle(
    id: 'yesil_smoothie',
    title: 'Ispanaklı Yeşil Smoothie',
    summary: 'Demir ve C vitamini bir arada.',
    body: 'Ispanaktaki bitkisel demirin emilimi C vitamini ile artar; bu '
        'yüzden portakal ya da kivi eklemek besleyiciliği yükseltir.',
    icon: Icons.blender_rounded,
    color: Colors.purple,
    category: 'smoothie',
    prepMinutes: 5,
    calories: 180,
    ingredients: [
      '2 avuç taze ıspanak',
      '1 adet muz',
      '1 adet portakalın suyu',
      'Yarım su bardağı su ya da süt',
    ],
    steps: [
      'Tüm malzemeleri blendera koyun.',
      'Pürüzsüz kıvam alana kadar yaklaşık bir dakika çekin.',
      'Hemen tüketin; bekledikçe vitamin kaybı olur.',
    ],
  ),
  DiscoverArticle(
    id: 'yogurtlu_ara_ogun',
    title: 'Cevizli Yoğurt Kâsesi',
    summary: 'Tok tutan, hazırlığı bir dakika süren ara öğün.',
    body: 'Yoğurdun proteini ile cevizin sağlıklı yağı birleşince kan şekeri '
        'daha yavaş yükselir ve tokluk uzar. Öğün aralarında acıkmayı '
        'geciktirir.',
    icon: Icons.apple_rounded,
    color: Colors.green,
    category: 'ara_ogun',
    prepMinutes: 2,
    calories: 220,
    ingredients: [
      '1 su bardağı süzme yoğurt',
      '3 adet ceviz içi',
      '1 tatlı kaşığı bal',
      'İsteğe bağlı yarım elma',
    ],
    steps: [
      'Yoğurdu kâseye alın.',
      'Cevizleri iri iri kırıp üzerine ekleyin.',
      'Balı gezdirin, isterseniz doğranmış elma ekleyin.',
    ],
  ),
  // ── Kahvaltılık ──────────────────────────────────────────────────────────
  DiscoverArticle(
    id: 'yulaf_kasesi',
    title: 'Muzlu Yulaf Kâsesi',
    summary: 'Akşamdan hazırlanır, sabah pişirme gerektirmez.',
    body: 'Yulaf, yavaş sindirilen karbonhidratı sayesinde kan şekerini ani '
        'yükseltmez. Gece boyunca sütte bekleyen yulaf yumuşar; sabah sadece '
        'meyveyi eklemek yeterlidir. Pişirme gerektirmediği için ocak '
        'kullanmadan hazırlanabilir.',
    icon: Icons.breakfast_dining_rounded,
    color: Colors.amber,
    category: 'kahvaltilik',
    prepMinutes: 5,
    calories: 340,
    ingredients: [
      '5 yemek kaşığı yulaf ezmesi',
      '1 su bardağı süt veya yoğurt',
      '1 adet muz',
      '1 yemek kaşığı ceviz içi',
      '1 tatlı kaşığı bal',
    ],
    steps: [
      'Yulafı bir kâseye koyup sütü üzerine dökün ve karıştırın.',
      'Kâsenin ağzını kapatıp buzdolabında en az altı saat bekletin.',
      'Sabah muzu dilimleyip üzerine ekleyin.',
      'Cevizi kırıp serpin ve balı gezdirin.',
    ],
  ),
  DiscoverArticle(
    id: 'avokadolu_ekmek',
    title: 'Yumurtalı Avokadolu Ekmek',
    summary: 'Sağlıklı yağ ve protein bir arada.',
    body: 'Avokadonun tekli doymamış yağı ile yumurtanın proteini birleşince '
        'öğün uzun süre tok tutar. Tam buğday ekmeği tercih etmek lif '
        'miktarını artırır.',
    icon: Icons.bakery_dining_rounded,
    color: Colors.amber,
    category: 'kahvaltilik',
    prepMinutes: 10,
    calories: 380,
    ingredients: [
      '2 dilim tam buğday ekmeği',
      '1 adet olgun avokado',
      '2 adet yumurta',
      'Yarım limonun suyu',
      'Tuz ve karabiber',
    ],
    steps: [
      'Yumurtaları yedi dakika haşlayıp soğuk suya alın.',
      'Avokadonun içini çatalla ezip limon suyu, tuz ve karabiber ekleyin.',
      'Ekmekleri kızartıp avokado karışımını sürün.',
      'Haşlanmış yumurtaları dilimleyip üzerine yerleştirin.',
    ],
  ),
  DiscoverArticle(
    id: 'peynirli_gozleme',
    title: 'Yulaflı Peynir Gözlemesi',
    summary: 'Tavada beş dakika, hamur açmadan.',
    body: 'Yulaf ve yoğurdun karışımı hamur açma gerektirmeden gözleme '
        'kıvamı verir. Peynir proteini artırır; maydanoz ise demir ve C '
        'vitamini katar.',
    icon: Icons.local_dining_rounded,
    color: Colors.amber,
    category: 'kahvaltilik',
    prepMinutes: 15,
    calories: 290,
    ingredients: [
      '4 yemek kaşığı yulaf ezmesi',
      '3 yemek kaşığı yoğurt',
      '1 adet yumurta',
      '3 yemek kaşığı beyaz peynir',
      'Yarım demet maydanoz',
    ],
    steps: [
      'Yulaf, yoğurt ve yumurtayı karıştırıp beş dakika bekletin.',
      'Yapışmaz tavayı orta ateşte ısıtın ve karışımı yayın.',
      'Bir tarafı kızarınca çevirin.',
      'Peynir ve doğranmış maydanozu ekleyip ikiye katlayın.',
    ],
  ),

  // ── Fit Tatlılar ─────────────────────────────────────────────────────────
  DiscoverArticle(
    id: 'firinda_elma',
    title: 'Fırında Tarçınlı Elma',
    summary: 'İlave şeker olmadan sıcak tatlı.',
    body: 'Elma fırında piştiğinde doğal şekeri yoğunlaşır ve tatlı ihtiyacını '
        'karşılar. Tarçın tatlılık algısını artırdığı için ek şekere gerek '
        'kalmaz.',
    icon: Icons.local_fire_department_rounded,
    color: Colors.pink,
    category: 'fit_tatli',
    prepMinutes: 30,
    calories: 160,
    ingredients: [
      '2 adet elma',
      '1 tatlı kaşığı tarçın',
      '1 yemek kaşığı ceviz içi',
      '1 tatlı kaşığı bal',
    ],
    steps: [
      'Elmaların çekirdek kısmını kaşıkla oyun.',
      'Ceviz ve tarçını karıştırıp oyulan boşluğa doldurun.',
      'Fırın kabına dizip yüz seksen derecede yirmi beş dakika pişirin.',
      'Ilıdıktan sonra balı gezdirip servis yapın.',
    ],
  ),
  DiscoverArticle(
    id: 'chia_puding',
    title: 'Chia Pudingi',
    summary: 'Kaşıkla karıştırın, gece kendi kendine kıvam alır.',
    body: 'Chia tohumu sıvıyı emerek jel kıvamı alır; pişirme gerektirmez. '
        'Omega üç yağ asidi ve lif bakımından zengindir.',
    icon: Icons.icecream_rounded,
    color: Colors.pink,
    category: 'fit_tatli',
    prepMinutes: 5,
    calories: 210,
    ingredients: [
      '3 yemek kaşığı chia tohumu',
      '1 su bardağı süt',
      '1 tatlı kaşığı bal',
      'Yarım su bardağı yaban mersini veya çilek',
    ],
    steps: [
      'Chia tohumunu sütle karıştırın ve on dakika bekletip tekrar karıştırın.',
      'Kâsenin ağzını kapatıp buzdolabında dört saat bekletin.',
      'Kıvam alınca balı ekleyip karıştırın.',
      'Meyveleri üzerine ekleyip servis yapın.',
    ],
  ),
  DiscoverArticle(
    id: 'hurma_toplari',
    title: 'Kakaolu Hurma Topları',
    summary: 'Fırın gerektirmeyen, üç malzemeli atıştırmalık tatlı.',
    body: 'Hurma hem tatlandırıcı hem bağlayıcı görevi görür. Kakao ve ceviz '
        'eklenince küçük porsiyonla tatlı isteği karşılanır.',
    icon: Icons.cookie_rounded,
    color: Colors.pink,
    category: 'fit_tatli',
    prepMinutes: 15,
    calories: 180,
    ingredients: [
      '10 adet çekirdeksiz hurma',
      'Yarım su bardağı ceviz içi',
      '2 yemek kaşığı kakao',
      '2 yemek kaşığı hindistan cevizi rendesi',
    ],
    steps: [
      'Hurma ve cevizi rondodan geçirip macun kıvamına getirin.',
      'Kakaoyu ekleyip karıştırın.',
      'Ceviz büyüklüğünde toplar yapın.',
      'Hindistan cevizine bulayıp yarım saat buzdolabında bekletin.',
    ],
  ),

  // ── Ara Öğün ─────────────────────────────────────────────────────────────
  DiscoverArticle(
    id: 'humus_tabagi',
    title: 'Humus ve Sebze Çubukları',
    summary: 'Bitkisel protein ve lif dolu ara öğün.',
    body: 'Nohut bitkisel protein ve lif kaynağıdır. Çiğ sebzelerle birlikte '
        'tüketildiğinde öğün arası açlığı uzun süre bastırır.',
    icon: Icons.rice_bowl_rounded,
    color: Colors.green,
    category: 'ara_ogun',
    prepMinutes: 10,
    calories: 220,
    ingredients: [
      '1 su bardağı haşlanmış nohut',
      '2 yemek kaşığı tahin',
      'Yarım limonun suyu',
      '1 diş sarımsak',
      '2 adet havuç ve 1 adet salatalık',
    ],
    steps: [
      'Nohut, tahin, limon suyu ve sarımsağı blenderdan geçirin.',
      'Koyu gelirse bir iki yemek kaşığı su ekleyip tekrar çekin.',
      'Havuç ve salatalığı çubuk şeklinde doğrayın.',
      'Humusu kâseye alıp sebzelerle birlikte servis yapın.',
    ],
  ),
  DiscoverArticle(
    id: 'firin_nohut',
    title: 'Fırınlanmış Baharatlı Nohut',
    summary: 'Cips yerine çıtır alternatif.',
    body: 'Fırında kurutulan nohut çıtır bir dokuya kavuşur. Kızartma '
        'olmadığından yağ oranı düşük kalır, lif ve protein yüksektir.',
    icon: Icons.grain_rounded,
    color: Colors.green,
    category: 'ara_ogun',
    prepMinutes: 35,
    calories: 190,
    ingredients: [
      '2 su bardağı haşlanmış nohut',
      '1 yemek kaşığı zeytinyağı',
      '1 tatlı kaşığı kimyon',
      '1 tatlı kaşığı tatlı toz biber',
      'Tuz',
    ],
    steps: [
      'Nohudu süzüp kâğıt havluyla iyice kurulayın.',
      'Zeytinyağı ve baharatlarla harmanlayın.',
      'Fırın tepsisine tek sıra hâlinde yayın.',
      'İki yüz derecede otuz dakika, arada karıştırarak pişirin.',
    ],
  ),
  DiscoverArticle(
    id: 'peynir_meyve',
    title: 'Peynir ve Meyve Tabağı',
    summary: 'Pişirme gerektirmeyen dengeli ara öğün.',
    body: 'Peynirin proteini meyvenin şekerinin kana geçişini yavaşlatır. '
        'Hazırlığı ocak veya fırın gerektirmediği için en pratik seçeneklerden '
        'biridir.',
    icon: Icons.apple_rounded,
    color: Colors.green,
    category: 'ara_ogun',
    prepMinutes: 5,
    calories: 200,
    ingredients: [
      '1 dilim beyaz peynir veya lor',
      '1 adet elma ya da armut',
      '5 adet badem',
      '2 adet tam buğday kraker',
    ],
    steps: [
      'Meyveyi dilimleyin.',
      'Peyniri küp şeklinde doğrayın.',
      'Bademlerle birlikte tabağa yerleştirin.',
      'Krakerlerle servis yapın.',
    ],
  ),

  // ── Smoothie ─────────────────────────────────────────────────────────────
  DiscoverArticle(
    id: 'muzlu_smoothie',
    title: 'Muzlu Fıstık Ezmeli Smoothie',
    summary: 'Antrenman sonrası için protein desteği.',
    body: 'Muz hızlı kullanılabilir karbonhidrat, fıstık ezmesi ve süt ise '
        'protein sağlar. Fiziksel aktivite sonrası toparlanmayı destekler.',
    icon: Icons.blender_rounded,
    color: Colors.purple,
    category: 'smoothie',
    prepMinutes: 5,
    calories: 320,
    ingredients: [
      '1 adet muz',
      '1 su bardağı süt',
      '1 yemek kaşığı fıstık ezmesi',
      '1 tatlı kaşığı yulaf ezmesi',
    ],
    steps: [
      'Muzu parçalara ayırın.',
      'Tüm malzemeleri blendere koyun.',
      'Bir dakika, pürüzsüz kıvam alana kadar çekin.',
      'Hemen servis yapın.',
    ],
  ),
  DiscoverArticle(
    id: 'yaban_mersini_smoothie',
    title: 'Yaban Mersinli Yoğurt Smoothie',
    summary: 'Probiyotik ve antioksidan bir arada.',
    body: 'Yoğurt bağırsak florasını destekleyen probiyotik içerir. Yaban '
        'mersini ise antioksidan bakımından zengindir. Donmuş meyve '
        'kullanmak buz eklemeden soğukluk sağlar.',
    icon: Icons.local_drink_rounded,
    color: Colors.purple,
    category: 'smoothie',
    prepMinutes: 5,
    calories: 210,
    ingredients: [
      '1 su bardağı yoğurt',
      'Yarım su bardağı donmuş yaban mersini',
      'Yarım muz',
      '1 tatlı kaşığı bal',
    ],
    steps: [
      'Tüm malzemeleri blendere koyun.',
      'Kırk saniye çekin.',
      'Koyu gelirse biraz su ekleyip tekrar karıştırın.',
      'Bardağa alıp servis yapın.',
    ],
  ),
  DiscoverArticle(
    id: 'havuc_portakal_smoothie',
    title: 'Havuçlu Portakallı Smoothie',
    summary: 'A ve C vitamini yüklü, şeker eklenmeden.',
    body: 'Havuçtaki beta karoten yağla birlikte daha iyi emilir; bu yüzden '
        'yarım avokado veya bir tatlı kaşığı zeytinyağı eklemek faydalıdır. '
        'Portakal C vitamini katar.',
    icon: Icons.emoji_food_beverage_rounded,
    color: Colors.purple,
    category: 'smoothie',
    prepMinutes: 8,
    calories: 180,
    ingredients: [
      '2 adet havuç',
      '2 adet portakalın suyu',
      'Yarım avokado',
      '1 santimetre taze zencefil',
    ],
    steps: [
      'Havuçları soyup küçük parçalara doğrayın.',
      'Portakalları sıkın.',
      'Tüm malzemeleri blenderdan geçirin.',
      'İsterseniz süzerek servis yapın.',
    ],
  ),

  // ── Çorbalar ─────────────────────────────────────────────────────────────
  DiscoverArticle(
    id: 'mercimek_corbasi',
    title: 'Klasik Mercimek Çorbası',
    summary: 'Bitkisel protein ve demir kaynağı.',
    body: 'Kırmızı mercimek hem protein hem demir içerir. Yanında limon '
        'sıkmak, bitkisel demirin emilimini artırır.',
    icon: Icons.soup_kitchen_rounded,
    color: Colors.orange,
    category: 'corba',
    prepMinutes: 35,
    calories: 190,
    ingredients: [
      '1 su bardağı kırmızı mercimek',
      '1 adet soğan',
      '1 adet havuç',
      '1 yemek kaşığı zeytinyağı',
      '6 su bardağı su',
      'Tuz ve limon',
    ],
    steps: [
      'Soğan ve havucu doğrayıp zeytinyağında kavurun.',
      'Yıkanmış mercimeği ekleyip suyu ilave edin.',
      'Kısık ateşte yirmi beş dakika pişirin.',
      'Blenderdan geçirip tuzunu ayarlayın, limonla servis yapın.',
    ],
  ),
  DiscoverArticle(
    id: 'brokoli_corbasi',
    title: 'Kremasız Brokoli Çorbası',
    summary: 'Krema yerine patatesle kıvam.',
    body: 'Patates çorbaya kremamsı kıvamı krema eklemeden verir. Brokoli C '
        'vitamini ve lif bakımından zengindir; fazla pişirmemek besin '
        'kaybını azaltır.',
    icon: Icons.ramen_dining_rounded,
    color: Colors.orange,
    category: 'corba',
    prepMinutes: 30,
    calories: 150,
    ingredients: [
      '1 adet brokoli',
      '1 adet patates',
      '1 adet soğan',
      '4 su bardağı su veya sebze suyu',
      '1 yemek kaşığı zeytinyağı',
    ],
    steps: [
      'Soğanı zeytinyağında pembeleştirin.',
      'Doğranmış patatesi ekleyip suyu ilave edin ve on beş dakika pişirin.',
      'Brokoli çiçeklerini ekleyip sekiz dakika daha pişirin.',
      'Blenderdan geçirip tuzunu ayarlayın.',
    ],
  ),
  DiscoverArticle(
    id: 'yayla_corbasi',
    title: 'Yayla Çorbası',
    summary: 'Yoğurtlu, hafif ve doyurucu.',
    body: 'Yoğurt çorbaya protein katar. Yoğurdun kesilmemesi için yumurta ile '
        'çırpılıp sıcak suyla yavaş yavaş ılıtılması gerekir.',
    icon: Icons.dinner_dining_rounded,
    color: Colors.orange,
    category: 'corba',
    prepMinutes: 30,
    calories: 170,
    ingredients: [
      '2 su bardağı yoğurt',
      '1 adet yumurta',
      'Yarım su bardağı pirinç',
      '1 yemek kaşığı un',
      '5 su bardağı su',
      'Kuru nane',
    ],
    steps: [
      'Pirinci suda on beş dakika haşlayın.',
      'Yoğurt, yumurta ve unu ayrı kapta çırpın.',
      'Sıcak sudan bir kepçe alıp yoğurt karışımına yavaşça ekleyin.',
      'Karışımı tencereye dökün, karıştırarak kaynatın ve naneyi ekleyin.',
    ],
  ),

  // ── Salatalar ────────────────────────────────────────────────────────────
  DiscoverArticle(
    id: 'mevsim_salata',
    title: 'Bol Yeşillikli Mevsim Salatası',
    summary: 'Öğünün yanına lif ve su desteği.',
    body: 'Yeşil yapraklılar düşük kalorili, yüksek lifli besinlerdir. '
        'Zeytinyağı eklemek yağda çözünen vitaminlerin emilimini artırır.',
    icon: Icons.eco_rounded,
    color: Colors.teal,
    category: 'salata',
    prepMinutes: 10,
    calories: 120,
    ingredients: [
      '1 demet marul',
      '2 adet domates',
      '1 adet salatalık',
      '1 yemek kaşığı zeytinyağı',
      'Limon ve tuz',
    ],
    steps: [
      'Marulu yıkayıp süzün ve elinizle koparın.',
      'Domates ve salatalığı küp doğrayın.',
      'Hepsini kâsede birleştirin.',
      'Zeytinyağı, limon ve tuzu ekleyip karıştırın.',
    ],
  ),
  DiscoverArticle(
    id: 'ton_balikli_salata',
    title: 'Ton Balıklı Fasulye Salatası',
    summary: 'Tek başına öğün olacak kadar doyurucu.',
    body: 'Ton balığı ve kuru fasulye birlikte yüksek protein sağlar. '
        'Pişirme gerektirmeyen bu salata, hazır konserve kullanıldığında on '
        'dakikada hazırlanır.',
    icon: Icons.set_meal_rounded,
    color: Colors.teal,
    category: 'salata',
    prepMinutes: 10,
    calories: 310,
    ingredients: [
      '1 kutu suyu süzülmüş ton balığı',
      '1 su bardağı haşlanmış kuru fasulye',
      '1 adet kırmızı soğan',
      'Yarım demet maydanoz',
      '1 yemek kaşığı zeytinyağı ve limon',
    ],
    steps: [
      'Fasulyeyi süzüp kâseye alın.',
      'Soğanı ince yarım ay doğrayın, maydanozu kıyın.',
      'Ton balığını ekleyip hafifçe karıştırın.',
      'Zeytinyağı ve limonu gezdirip servis yapın.',
    ],
  ),
  DiscoverArticle(
    id: 'bulgur_salatasi',
    title: 'Nar Ekşili Bulgur Salatası',
    summary: 'Tam tahıl ve sebze bir arada.',
    body: 'Bulgur tam tahıl olduğu için lif oranı yüksektir ve tokluk süresini '
        'uzatır. Bol maydanoz eklemek C vitamini katar.',
    icon: Icons.spa_rounded,
    color: Colors.teal,
    category: 'salata',
    prepMinutes: 20,
    calories: 260,
    ingredients: [
      '1 su bardağı ince bulgur',
      '1 su bardağı sıcak su',
      '1 demet maydanoz',
      '3 adet taze soğan',
      '2 yemek kaşığı nar ekşisi ve zeytinyağı',
    ],
    steps: [
      'Bulguru sıcak suyla ıslatıp on beş dakika demlendirin.',
      'Maydanoz ve taze soğanı ince kıyın.',
      'Bulgura sebzeleri ekleyin.',
      'Nar ekşisi ve zeytinyağını ilave edip karıştırın.',
    ],
  ),

  // ── İpuçları (tarif değil) ───────────────────────────────────────────────
  DiscoverArticle(
    id: 'porsiyon_tahmini',
    title: 'Porsiyonu Elinizle Tahmin Edin',
    summary: 'Tartı olmadan miktar belirlemenin pratik yolu.',
    body: 'Uygulama porsiyonu tahmin ettiğinde bunu kendi ölçünüzle '
        'doğrulayabilirsiniz. Avuç içiniz kadar et yaklaşık yüz gramdır. '
        'Yumruğunuz kadar pilav veya makarna bir porsiyondur. Başparmağınızın '
        'boyu kadar peynir yaklaşık otuz gramdır. Avuç içi dolusu kuruyemiş '
        'bir porsiyondur. Bu ölçüler tartı gerektirmediği için mutfakta hızlı '
        'karar vermeyi kolaylaştırır.',
    icon: Icons.back_hand_rounded,
    color: Colors.indigo,
  ),
  DiscoverArticle(
    id: 'su_aliskanligi',
    title: 'Su İçmeyi Unutmamak İçin',
    summary: 'Susama hissini beklemeden düzenli içmek.',
    body: 'Susama hissi genellikle vücut su kaybetmeye başladıktan sonra '
        'ortaya çıkar; bu yüzden hissi beklemek geç kalmak demektir. Her '
        'öğünün başında bir bardak su içmek günlük miktarın önemli kısmını '
        'karşılar. Çalışma masanızda dolu bir şişe bulundurmak da hatırlatıcı '
        'görevi görür. Uygulamadaki su takibi bölümünden her bardağı '
        'kaydederek gün içindeki ilerlemenizi sesli olarak dinleyebilirsiniz.',
    icon: Icons.water_drop_rounded,
    color: Colors.blue,
  ),
  DiscoverArticle(
    id: 'ogun_duzeni',
    title: 'Öğün Saatleri Neden Önemli',
    summary: 'Düzenli aralıklar kan şekerini dengeler.',
    body: 'Uzun süre aç kalmak sonraki öğünde fazla yemeye yol açar. Öğünleri '
        'üç dört saat aralıklarla planlamak kan şekerini daha dengeli tutar. '
        'Kahvaltıyı atlamamak gün içindeki toplam alımı azaltmaya yardımcı '
        'olur. Uygulamada her kaydın saati tutulduğu için öğün düzeninizi '
        'geçmiş ekranından takip edebilirsiniz.',
    icon: Icons.schedule_rounded,
    color: Colors.deepOrange,
  ),
  DiscoverArticle(
    id: 'lif_tuketimi',
    title: 'Lifi Artırmanın Kolay Yolları',
    summary: 'Küçük değişikliklerle günlük lif miktarını yükseltin.',
    body: 'Beyaz ekmek yerine tam buğday ekmeği tercih etmek günlük lif '
        'miktarını belirgin şekilde artırır. Meyveyi suyunu sıkmak yerine '
        'olduğu gibi tüketmek lifin korunmasını sağlar. Çorbalara mercimek '
        'veya nohut eklemek hem lif hem protein katar. Lif alımını artırırken '
        'su tüketimini de artırmak gerekir; aksi hâlde sindirim zorlaşabilir.',
    icon: Icons.grass_rounded,
    color: Colors.lightGreen,
  ),
];

/// Verilen kategoriye ait tarifler.
List<DiscoverArticle> articlesForCategory(String categoryId) {
  final matches = <DiscoverArticle>[
    if (featuredRecipe.category == categoryId) featuredRecipe,
    ...discoverArticles.where((a) => a.category == categoryId),
  ];
  return matches;
}

/// Ana ekranda "Günün İpuçları" altında listelenenler (tarif olmayanlar).
List<DiscoverArticle> get dailyTips =>
    discoverArticles.where((article) => !article.isRecipe).toList();
