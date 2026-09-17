String normalizeVoiceText(String input) => input
    .toLowerCase()
    .replaceAll('ç', 'c')
    .replaceAll('ğ', 'g')
    .replaceAll('ı', 'i')
    .replaceAll('ö', 'o')
    .replaceAll('ş', 's')
    .replaceAll('ü', 'u')
    .replaceAll(RegExp(r'[^a-z0-9@.\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

int? spokenOneToFive(String input) {
  final normalized = normalizeVoiceText(input);
  const words = {
    'bir': 1,
    'birinci': 1,
    'iki': 2,
    'ikinci': 2,
    'uc': 3,
    'ucuncu': 3,
    'dort': 4,
    'dorduncu': 4,
    'bes': 5,
    'besinci': 5,
  };
  for (final token in normalized.split(' ')) {
    final numeric = int.tryParse(token);
    if (numeric != null && numeric >= 1 && numeric <= 5) return numeric;
    if (words[token] case final value?) return value;
  }
  return null;
}

String? matchSpokenOption(String input, List<String> options) {
  final normalized = normalizeVoiceText(input);
  final ordinal = spokenOneToFive(normalized);
  if (ordinal != null && ordinal <= options.length) return options[ordinal - 1];

  for (final option in options) {
    final candidate = normalizeVoiceText(option);
    if (normalized == candidate ||
        normalized.contains(candidate) ||
        candidate.contains(normalized)) {
      return option;
    }
  }
  return null;
}

String spokenEmailToAddress(String input) {
  var value = normalizeVoiceText(input);
  const atPhrases = [
    'kuyruklu a',
    'et isareti',
    'at isareti',
    ' et ',
    ' at ',
  ];
  value = ' $value ';
  for (final phrase in atPhrases) {
    value = value.replaceAll(phrase, '@');
  }
  value = value
      .replaceAll(' nokta ', '.')
      .replaceAll(' tire ', '-')
      .replaceAll(' alt cizgi ', '_')
      .replaceAll(' ', '');
  return value;
}

bool voiceContains(String input, Iterable<String> phrases) {
  final normalized = normalizeVoiceText(input);
  return phrases
      .any((phrase) => normalized.contains(normalizeVoiceText(phrase)));
}
