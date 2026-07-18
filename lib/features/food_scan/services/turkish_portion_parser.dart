class PortionInput {
  final double value;
  final String unit;

  const PortionInput({required this.value, required this.unit});
}

const _units = <String, String>{
  'gram': 'gram',
  'gramlık': 'gram',
  'adet': 'adet',
  'tane': 'adet',
  'dilim': 'dilim',
  'kase': 'kase',
  'kâse': 'kase',
};

const _numbers = <String, int>{
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

PortionInput? parseTurkishPortion(String rawText) {
  final text = rawText.toLowerCase().trim();
  if (text.isEmpty) return null;
  if (RegExp(r'-\s*\d').hasMatch(text)) return null;
  final tokens = text
      .replaceAll(RegExp(r'[^a-zçğıöşüâ0-9,.]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList();
  final unit =
      tokens.map((token) => _units[token]).whereType<String>().firstOrNull;
  if (unit == null) return null;

  final numericMatch = RegExp(r'\d+(?:[,.]\d+)?').firstMatch(text);
  final value = numericMatch == null
      ? _parseNumberWords(tokens)
      : double.tryParse(numericMatch.group(0)!.replaceAll(',', '.'));
  if (value == null || !value.isFinite || value <= 0) return null;
  final limit = unit == 'gram' ? 2000 : 20;
  if (value > limit) return null;
  return PortionInput(value: value, unit: unit);
}

double? _parseNumberWords(List<String> tokens) {
  var total = 0;
  var current = 0;
  var sawNumber = false;
  for (final token in tokens) {
    final number = _numbers[token];
    if (number != null) {
      current += number;
      sawNumber = true;
    } else if (token == 'yüz') {
      current = (current == 0 ? 1 : current) * 100;
      sawNumber = true;
    } else if (token == 'bin') {
      total += (current == 0 ? 1 : current) * 1000;
      current = 0;
      sawNumber = true;
    }
  }
  return sawNumber ? (total + current).toDouble() : null;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
