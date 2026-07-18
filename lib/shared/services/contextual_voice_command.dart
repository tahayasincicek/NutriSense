import 'dart:math';

/// Sesli komutun hangi gerçek ürün akışında yorumlandığını belirtir.
enum VoiceInteractionContext {
  globalNavigation,
  cameraReady,
  scanConfirmation,
  portionEditing,
  history,
  historyDeleteConfirmation,
  settings,
  logoutConfirmation,
  reportPreview,
  reportConsent,
  reportSendConfirmation,
}

enum ContextualVoiceAction {
  scan,
  retake,
  firstOption,
  secondOption,
  thirdOption,
  setPortion,
  save,
  today,
  listenEntry,
  editEntry,
  changeMeal,
  sendReport,
  deleteEntry,
  logout,
  back,
  yes,
  no,
  cancel,
}

class ContextualVoiceIntent {
  const ContextualVoiceIntent({
    required this.rawText,
    this.action,
    this.confidence = 0,
    this.isExact = false,
    this.requiresSecondConfirmation = false,
    this.portionGrams,
    this.rejectionReason,
  });

  final String rawText;
  final ContextualVoiceAction? action;
  final double confidence;
  final bool isExact;
  final bool requiresSecondConfirmation;
  final double? portionGrams;
  final String? rejectionReason;

  bool get accepted => action != null && rejectionReason == null;
}

/// Bağlam dışı evet/hayır komutlarını ve tehlikeli fuzzy eşleşmeleri reddeder.
class ContextualVoiceCommandParser {
  const ContextualVoiceCommandParser();

  static const _confirmationContexts = {
    VoiceInteractionContext.scanConfirmation,
    VoiceInteractionContext.historyDeleteConfirmation,
    VoiceInteractionContext.logoutConfirmation,
    VoiceInteractionContext.reportSendConfirmation,
  };

  ContextualVoiceIntent parse(
    String input, {
    required VoiceInteractionContext context,
  }) {
    final normalized = _normalize(input);
    if (normalized.isEmpty) return ContextualVoiceIntent(rawText: input);

    if (_confirmationContexts.contains(context)) {
      if (_isExact(normalized, const ['evet', 'onayliyorum'])) {
        return _exact(input, ContextualVoiceAction.yes);
      }
      if (_isExact(normalized, const ['hayir', 'reddet'])) {
        return _exact(input, ContextualVoiceAction.no);
      }
      if (_isExact(normalized, const ['iptal', 'vazgec'])) {
        return _exact(input, ContextualVoiceAction.cancel);
      }
    } else if (_isExact(normalized, const ['evet', 'hayir'])) {
      return ContextualVoiceIntent(
        rawText: input,
        rejectionReason:
            'Bu komut yalnızca etkin bir onay sorusunda kullanılabilir.',
      );
    }
    if (_isExact(normalized, const ['iptal', 'vazgec'])) {
      return _exact(input, ContextualVoiceAction.cancel);
    }

    final exact = _exactForContext(normalized, input, context);
    if (exact != null) return exact;

    // Yalnız geri alınabilir ve güvenli navigasyon eylemlerinde fuzzy eşleşme.
    const safeFuzzy = <String, ContextualVoiceAction>{
      'tara': ContextualVoiceAction.scan,
      'geri': ContextualVoiceAction.back,
      'bugun ne yedim': ContextualVoiceAction.today,
    };
    ContextualVoiceAction? bestAction;
    var bestScore = 0.0;
    for (final candidate in safeFuzzy.entries) {
      final score = _similarity(normalized, candidate.key);
      if (score > bestScore) {
        bestScore = score;
        bestAction = candidate.value;
      }
    }
    if (bestAction != null && bestScore >= 0.8) {
      final allowed = _allowed(bestAction, context);
      if (allowed) {
        return ContextualVoiceIntent(
          rawText: input,
          action: bestAction,
          confidence: bestScore,
        );
      }
    }

    return ContextualVoiceIntent(
      rawText: input,
      rejectionReason: 'Komut bu ekranda tanınmadı veya güvenli değil.',
    );
  }

  ContextualVoiceIntent? _exactForContext(
    String value,
    String raw,
    VoiceInteractionContext context,
  ) {
    if (_isExact(value, const ['tara', 'besin tara']) &&
        _allowed(ContextualVoiceAction.scan, context)) {
      return _exact(raw, ContextualVoiceAction.scan);
    }
    if (_isExact(value, const ['tekrar cek', 'yeniden cek']) &&
        _allowed(ContextualVoiceAction.retake, context)) {
      return _exact(raw, ContextualVoiceAction.retake);
    }
    if (_isExact(value, const ['birinci secenek', 'secenek bir']) &&
        context == VoiceInteractionContext.scanConfirmation) {
      return _exact(raw, ContextualVoiceAction.firstOption);
    }
    if (_isExact(value, const ['ikinci secenek', 'secenek iki']) &&
        context == VoiceInteractionContext.scanConfirmation) {
      return _exact(raw, ContextualVoiceAction.secondOption);
    }
    if (_isExact(value, const ['ucuncu secenek', 'secenek uc']) &&
        context == VoiceInteractionContext.scanConfirmation) {
      return _exact(raw, ContextualVoiceAction.thirdOption);
    }
    final portion =
        RegExp(r'^porsiyon\s+(\d+(?:[.,]\d+)?)\s+gram$').firstMatch(value);
    if (portion != null &&
        {
          VoiceInteractionContext.portionEditing,
          VoiceInteractionContext.scanConfirmation,
          VoiceInteractionContext.history,
        }.contains(context)) {
      final grams = double.tryParse(portion.group(1)!.replaceAll(',', '.'));
      if (grams != null && grams.isFinite && grams > 0 && grams <= 2000) {
        return ContextualVoiceIntent(
          rawText: raw,
          action: ContextualVoiceAction.setPortion,
          confidence: 1,
          isExact: true,
          portionGrams: grams,
        );
      }
    }
    if (_isExact(value, const ['kaydet', 'sonucu kaydet']) &&
        context == VoiceInteractionContext.scanConfirmation) {
      return _exact(raw, ContextualVoiceAction.save);
    }
    if (_isExact(value, const ['bugun ne yedim', 'bugunku kayitlar']) &&
        _allowed(ContextualVoiceAction.today, context)) {
      return _exact(raw, ContextualVoiceAction.today);
    }
    if (_isExact(value, const ['kaydi dinle', 'bu kaydi dinle']) &&
        context == VoiceInteractionContext.history) {
      return _exact(raw, ContextualVoiceAction.listenEntry);
    }
    if (_isExact(value, const ['kaydi duzelt', 'bu kaydi duzelt']) &&
        context == VoiceInteractionContext.history) {
      return _exact(raw, ContextualVoiceAction.editEntry);
    }
    if (_isExact(value, const ['ogunu degistir', 'ogun turunu degistir']) &&
        context == VoiceInteractionContext.history) {
      return _exact(raw, ContextualVoiceAction.changeMeal);
    }
    if (_isExact(value, const ['rapor gonder', 'diyetisyene rapor gonder']) &&
        context == VoiceInteractionContext.reportConsent) {
      return _exact(
        raw,
        ContextualVoiceAction.sendReport,
        requiresSecondConfirmation: true,
      );
    }
    if (_isExact(value, const ['kaydi sil', 'bu kaydi sil']) &&
        context == VoiceInteractionContext.history) {
      return _exact(
        raw,
        ContextualVoiceAction.deleteEntry,
        requiresSecondConfirmation: true,
      );
    }
    if (_isExact(value, const ['cikis yap', 'oturumu kapat']) &&
        context == VoiceInteractionContext.settings) {
      return _exact(
        raw,
        ContextualVoiceAction.logout,
        requiresSecondConfirmation: true,
      );
    }
    if (_isExact(value, const ['geri', 'geri don']) &&
        _allowed(ContextualVoiceAction.back, context)) {
      return _exact(raw, ContextualVoiceAction.back);
    }
    return null;
  }

  bool _allowed(ContextualVoiceAction action, VoiceInteractionContext context) {
    return switch (action) {
      ContextualVoiceAction.scan =>
        context == VoiceInteractionContext.globalNavigation ||
            context == VoiceInteractionContext.cameraReady,
      ContextualVoiceAction.retake =>
        context == VoiceInteractionContext.scanConfirmation,
      ContextualVoiceAction.today =>
        context == VoiceInteractionContext.globalNavigation ||
            context == VoiceInteractionContext.history,
      ContextualVoiceAction.back => true,
      _ => false,
    };
  }

  ContextualVoiceIntent _exact(
    String raw,
    ContextualVoiceAction action, {
    bool requiresSecondConfirmation = false,
  }) =>
      ContextualVoiceIntent(
        rawText: raw,
        action: action,
        confidence: 1,
        isExact: true,
        requiresSecondConfirmation: requiresSecondConfirmation,
      );

  bool _isExact(String value, List<String> candidates) =>
      candidates.contains(value);

  String _normalize(String input) => input
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u')
      .replaceAll(RegExp(r'[^a-z0-9,.\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  double _similarity(String left, String right) {
    final maxLength = max(left.length, right.length);
    if (maxLength == 0) return 1;
    return 1 - (_levenshtein(left, right) / maxLength);
  }

  int _levenshtein(String left, String right) {
    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 1; i <= left.length; i++) {
      final current = List<int>.filled(right.length + 1, 0)..[0] = i;
      for (var j = 1; j <= right.length; j++) {
        final cost = left[i - 1] == right[j - 1] ? 0 : 1;
        current[j] = min(
          min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );
      }
      previous = current;
    }
    return previous.last;
  }
}

/// Kritik eylemin ikinci onayını süreli ve tek kullanımlık hale getirir.
class VoiceConfirmationGate {
  VoiceConfirmationGate({this.timeout = const Duration(seconds: 12)});

  final Duration timeout;
  ContextualVoiceAction? _pending;
  DateTime? _expiresAt;

  ContextualVoiceAction? get pending => isActive ? _pending : null;
  bool get isActive =>
      _pending != null &&
      _expiresAt != null &&
      DateTime.now().isBefore(_expiresAt!);

  void request(ContextualVoiceAction action) {
    _pending = action;
    _expiresAt = DateTime.now().add(timeout);
  }

  ContextualVoiceAction? resolve(ContextualVoiceIntent response) {
    if (!isActive) {
      clear();
      return null;
    }
    if (!response.isExact || response.action != ContextualVoiceAction.yes) {
      if (response.action == ContextualVoiceAction.no ||
          response.action == ContextualVoiceAction.cancel) {
        clear();
      }
      return null;
    }
    final resolved = _pending;
    clear();
    return resolved;
  }

  void clear() {
    _pending = null;
    _expiresAt = null;
  }
}
