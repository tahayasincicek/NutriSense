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
