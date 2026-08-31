// =============================================================================
// lib/shared/services/turkish_number_parser.dart
// NutriSense — Türkçe sesli sayı ayrıştırma
//
// Tam görme kaybı olan kullanıcı için klavyeyle sayı yazmak en zahmetli
// işlerden biridir. Bu ayrıştırıcı, "yedi buçuk", "yetmiş dört nokta iki",
// "sekiz saat" gibi doğal söyleyişleri sayıya çevirir; böylece uyku süresi,
// kilo gibi değerler konuşarak girilebilir.
// =============================================================================

const _digits = <String, double>{
  'sıfır': 0,
  'bir': 1,
  'iki': 2,
  'üç': 3,
  'dört': 4,
  'beş': 5,
  'altı': 6,
  'yedi': 7,
  'sekiz': 8,
  'dokuz': 9,
  'on': 10,
  'yirmi': 20,
  'otuz': 30,
  'kırk': 40,
  'elli': 50,
  'altmış': 60,
  'yetmiş': 70,
  'seksen': 80,
  'doksan': 90,
};

/// Kesir sözcükleri: "yedi buçuk" → 7.5, "çeyrek" → 0.25.
const _fractions = <String, double>{
  'buçuk': 0.5,
  'yarım': 0.5,
  'çeyrek': 0.25,
};

/// Serbest konuşmadan ilk anlamlı sayıyı çıkarır.
///
/// Desteklenen biçimler:
/// - Rakam: "7", "7.5", "7,5"
/// - Sözcük: "yedi", "yetmiş dört", "yüz yirmi"
/// - Kesir: "yedi buçuk", "yarım", "bir çeyrek"
/// - Ondalık: "yetmiş dört nokta iki", "yetmiş dört virgül iki"
///
/// Ayrıştırılamazsa `null` döner — çağıran taraf kullanıcıdan tekrar ister.
double? parseTurkishNumber(String rawText) {
  final text = rawText.toLowerCase().trim();
  if (text.isEmpty) return null;

  // Önce düz rakam ara: "7.5 saat" gibi karışık söyleyişlerde en güvenilir yol.
  final numeric = RegExp(r'\d+(?:[,.]\d+)?').firstMatch(text);
  if (numeric != null) {
    final value = double.tryParse(numeric.group(0)!.replaceAll(',', '.'));
    if (value != null && value.isFinite) return value;
  }

  final tokens = text
      .replaceAll(RegExp(r'[^a-zçğıöşü ]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return null;

  // "nokta" / "virgül" ondalık ayırıcı olarak kullanılabilir.
  final separator = tokens.indexWhere(
    (token) => token == 'nokta' || token == 'virgül',
  );
  if (separator > 0 && separator < tokens.length - 1) {
    final whole = _parseWords(tokens.sublist(0, separator));
    final fraction = _parseWords(tokens.sublist(separator + 1));
    if (whole != null && fraction != null) {
      // "yetmiş dört nokta iki" → 74.2, "... nokta yirmi beş" → 74.25
      final digits = fraction.toInt().toString();
      return double.tryParse('${whole.toInt()}.$digits');
    }
  }

  return _parseWords(tokens);
}

double? _parseWords(List<String> tokens) {
  var total = 0.0;
  var current = 0.0;
  var fraction = 0.0;
  var sawNumber = false;

  for (final token in tokens) {
    final digit = _digits[token];
    if (digit != null) {
      current += digit;
      sawNumber = true;
      continue;
    }
    final part = _fractions[token];
    if (part != null) {
      fraction += part;
      sawNumber = true;
      continue;
    }
    if (token == 'yüz') {
      current = (current == 0 ? 1 : current) * 100;
      sawNumber = true;
    } else if (token == 'bin') {
      total += (current == 0 ? 1 : current) * 1000;
      current = 0;
      sawNumber = true;
    }
  }

  if (!sawNumber) return null;
  final value = total + current + fraction;
  return value.isFinite ? value : null;
}

/// Sayıyı ekran okuyucunun doğru seslendireceği biçimde yazar.
///
/// Türkçe TTS "7.5" ifadesini "yedi nokta beş" diye okur; "7,5" ise
/// "yedi virgül beş" olarak daha doğal duyulur.
String speakableNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1).replaceAll('.', ',');
}
