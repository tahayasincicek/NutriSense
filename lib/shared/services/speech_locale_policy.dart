/// Selects the actual Turkish locale identifier exposed by the platform.
///
/// Apple commonly reports `tr_TR`, while other engines may report `tr-TR`.
/// Passing a hard-coded identifier that the engine did not advertise can
/// silently fall back to another language, so callers must use this result.
String? selectTurkishSpeechLocale(Iterable<String> localeIds) {
  final normalized = localeIds
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);

  for (final preferred in const ['tr_TR', 'tr-TR']) {
    for (final locale in normalized) {
      if (locale.toLowerCase() == preferred.toLowerCase()) return locale;
    }
  }

  for (final locale in normalized) {
    final lower = locale.toLowerCase();
    if (lower == 'tr' || lower.startsWith('tr_') || lower.startsWith('tr-')) {
      return locale;
    }
  }
  return null;
}
