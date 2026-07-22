enum ResearchMode { disabled, synthetic, approved }

class ResearchGateException implements Exception {
  final String message;
  const ResearchGateException(this.message);

  @override
  String toString() => message;
}

/// Compile-time research gate. No approval reference is shipped by default.
/// Production participant builds must receive externally verified dart-defines.
class ResearchRuntimeConfig {
  final ResearchMode mode;
  final String protocolVersion;
  final String consentVersion;
  final String approvalReference;

  const ResearchRuntimeConfig({
    required this.mode,
    required this.protocolVersion,
    required this.consentVersion,
    required this.approvalReference,
  });

  factory ResearchRuntimeConfig.fromEnvironment() {
    const modeValue = String.fromEnvironment(
      'RESEARCH_MODE',
      defaultValue: 'synthetic',
    );
    final mode = switch (modeValue) {
      'disabled' => ResearchMode.disabled,
      'approved' => ResearchMode.approved,
      _ => ResearchMode.synthetic,
    };
    return ResearchRuntimeConfig(
      mode: mode,
      protocolVersion:
          const String.fromEnvironment('RESEARCH_PROTOCOL_VERSION'),
      consentVersion: const String.fromEnvironment('RESEARCH_CONSENT_VERSION'),
      approvalReference:
          const String.fromEnvironment('RESEARCH_APPROVAL_REFERENCE'),
    );
  }

  bool get canCollectSynthetic => mode != ResearchMode.disabled;

  bool get canCollectParticipant =>
      mode == ResearchMode.approved &&
      _isVerified(protocolVersion) &&
      _isVerified(consentVersion) &&
      _isVerified(approvalReference);

  String get dataOrigin =>
      mode == ResearchMode.approved ? 'participant' : 'synthetic';

  void assertCollectionAllowed() {
    if (mode == ResearchMode.disabled) {
      throw const ResearchGateException(
          'Araştırma veri toplama modu kapalıdır.');
    }
    if (mode == ResearchMode.approved && !canCollectParticipant) {
      throw const ResearchGateException(
        'Etik kurul referansı, protokol ve onam sürümü doğrulanmadan '
        'gerçek katılımcı verisi toplanamaz.',
      );
    }
  }

  static bool _isVerified(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) return false;
    return !const ['PLACEHOLDER', 'REPLACE', 'TODO', 'TBD', 'EXAMPLE', 'ÖRNEK']
        .any(normalized.contains);
  }
}
