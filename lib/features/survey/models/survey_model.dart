// =============================================================================
// lib/features/survey/models/survey_model.dart
// NutriSense — Anket Veri Modelleri
//
// Soru tipleri: Likert (1-5), Çoktan seçmeli, Evet/Hayır, Açık uçlu, Yıldız
// TTS etiketli tüm seçenekler + fromJson/toJson serileştirme.
// =============================================================================

/// Soru tipi
enum QuestionType {
  likert, // 1-5 Likert ölçeği
  multiChoice, // Çoktan seçmeli
  yesNo, // Evet / Hayır / Belki
  openText, // Açık uçlu metin
  starRating, // 1-5 yıldız
}

/// Tek anket sorusu tanımı
class SurveyQuestion {
  final String id;
  final String text; // Soru metni (TTS ile okunacak)
  final QuestionType type;
  final List<String>? options; // Çoktan seçmeli seçenekler
  final bool required;
  final String instrumentVersion;
  final String source;
  final String scaleDirection;

  const SurveyQuestion({
    required this.id,
    required this.text,
    required this.type,
    this.options,
    this.required = true,
    this.instrumentVersion = surveyInstrumentVersion,
    this.source = 'Araştırmacı tarafından geliştirilen taslak madde',
    this.scaleDirection = 'Yüksek puan daha olumlu değerlendirme gösterir',
  });
}

const surveyInstrumentVersion = 'NS-SURVEY-1.0-DRAFT';
const surveyApiSchemaVersion = '1.0';

/// Likert seviyeleri — Türkçe etiketler
class LikertLabels {
  static const labels = {
    1: 'Hiç yeterli değil',
    2: 'Yeterli değil',
    3: 'Orta',
    4: 'Yeterli',
    5: 'Çok yeterli',
  };

  static const easeLabels = {
    1: 'Çok zor',
    2: 'Zor',
    3: 'Orta',
    4: 'Kolay',
    5: 'Çok kolay',
  };

  static const trustLabels = {
    1: 'Hiç güvenmedim',
    2: 'Az güvendim',
    3: 'Orta düzeyde güvendim',
    4: 'Güvendim',
    5: 'Tamamen güvendim',
  };

  static const starLabels = {
    1: 'Çok kötü',
    2: 'Kötü',
    3: 'Orta',
    4: 'İyi',
    5: 'Çok iyi',
  };
}

/// Kullanıcının tek bir soruya verdiği yanıt
class SurveyAnswer {
  final String questionId;
  final dynamic answer; // int, String, veya List<String>
  final DateTime answeredAt;

  SurveyAnswer({
    required this.questionId,
    required this.answer,
    DateTime? answeredAt,
  }) : answeredAt = answeredAt ?? DateTime.now();

  factory SurveyAnswer.fromJson(Map<String, dynamic> json) => SurveyAnswer(
        questionId: json['question_id'] ?? '',
        answer: json['answer'],
        answeredAt:
            DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'answer': answer,
        'timestamp': answeredAt.toIso8601String(),
      };
}

/// Tamamlanmış anket
class SurveySubmission {
  final String id;
  final String participantId;
  final List<SurveyAnswer> answers;
  final DateTime submittedAt;
  final String deviceInfo;
  final Duration completionTime;
  final String protocolVersion;
  final String dataOrigin;

  SurveySubmission({
    required this.id,
    required this.participantId,
    required this.answers,
    required this.completionTime,
    this.deviceInfo = '',
    this.protocolVersion = '',
    this.dataOrigin = 'synthetic',
    DateTime? submittedAt,
  }) : submittedAt = submittedAt ?? DateTime.now();

  factory SurveySubmission.fromJson(Map<String, dynamic> json) =>
      SurveySubmission(
        id: json['id'] ?? '',
        participantId: json['participant_id'] ?? json['user_id'] ?? '',
        answers: (json['answers'] as List?)
                ?.map((a) => SurveyAnswer.fromJson(a))
                .toList() ??
            [],
        completionTime: Duration(seconds: json['completion_seconds'] ?? 0),
        deviceInfo: json['device_info'] ?? '',
        protocolVersion: json['protocol_version'] ?? '',
        dataOrigin: json['data_origin'] ?? 'synthetic',
        submittedAt:
            DateTime.tryParse(json['submitted_at'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'participant_id': participantId,
        'answers': answers.map((a) => a.toJson()).toList(),
        'completion_seconds': completionTime.inSeconds,
        'device_info': deviceInfo,
        'survey_version': surveyApiSchemaVersion,
        'protocol_version': protocolVersion,
        'data_origin': dataOrigin,
        'submitted_at': submittedAt.toIso8601String(),
      };
}

// ═══════════════════════════════════════════════════════════════════════════════
// KULLANILABILIRLIK TESTİ MODELLERİ
// ═══════════════════════════════════════════════════════════════════════════════

/// Görev durumu
enum TaskStatus { notStarted, inProgress, completed, failed }

/// Kullanılabilirlik testi görevi
class UsabilityTask {
  final String id;
  final String title;
  final String description;
  final String condition;
  TaskStatus status;
  DateTime? _startTime;
  DateTime? _endTime;
  String? researcherNote;
  int errorCount;
  String assistanceLevel;
  String? abortReason;
  bool manuallyEdited;
  String? editReason;
  final String successCriterion;
  final String startPoint;
  final String endPoint;
  final int maximumSeconds;
  Stopwatch? _monotonicTimer;
  double? _monotonicDurationSeconds;

  UsabilityTask({
    required this.id,
    required this.title,
    required this.description,
    this.condition = 'nutrisense',
    this.status = TaskStatus.notStarted,
    DateTime? startTime,
    DateTime? endTime,
    this.researcherNote,
    this.errorCount = 0,
    this.assistanceLevel = 'none',
    this.abortReason,
    this.manuallyEdited = false,
    this.editReason,
    this.successCriterion = '',
    this.startPoint = '',
    this.endPoint = '',
    this.maximumSeconds = 300,
  })  : _startTime = startTime,
        _endTime = endTime;

  DateTime? get startTime => _startTime;

  set startTime(DateTime? value) {
    _startTime = value;
    if (value == null) {
      _monotonicTimer = null;
      _monotonicDurationSeconds = null;
      return;
    }
    _monotonicTimer = Stopwatch()..start();
    _monotonicDurationSeconds = null;
  }

  DateTime? get endTime => _endTime;

  set endTime(DateTime? value) {
    _endTime = value;
    if (value == null) return;
    final timer = _monotonicTimer;
    if (timer != null) {
      timer.stop();
      _monotonicDurationSeconds = timer.elapsedMicroseconds / 1000000;
    }
  }

  /// Görev süresi (saniye)
  double? get durationSeconds {
    if (_monotonicDurationSeconds != null) return _monotonicDurationSeconds;
    if (_startTime == null || _endTime == null) return null;
    return _endTime!.difference(_startTime!).inMilliseconds / 1000;
  }

  bool get isSuccess => status == TaskStatus.completed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'condition': condition,
        'title': title,
        'description': description,
        'status': status.name,
        'start_time': startTime?.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'duration_seconds': durationSeconds,
        'is_success': isSuccess,
        'error_count': errorCount,
        'assistance_level': assistanceLevel,
        'abort_reason': abortReason,
        'timing_source':
            _monotonicDurationSeconds == null ? 'manual' : 'monotonic',
        'manually_edited': manuallyEdited,
        'edit_reason': editReason,
        'success_criterion': successCriterion,
        'start_point': startPoint,
        'end_point': endPoint,
        'maximum_seconds': maximumSeconds,
        'researcher_note': researcherNote,
      };
}

/// Kullanılabilirlik testi oturumu
class UsabilitySession {
  final String id;
  final String participantId;
  final DateTime sessionDate;
  final List<UsabilityTask> tasks;
  String? generalNote;
  final String schemaVersion;
  final String protocolVersion;
  final String dataOrigin;
  final String? counterbalanceSequence;

  UsabilitySession({
    required this.id,
    required this.participantId,
    required this.tasks,
    this.generalNote,
    this.schemaVersion = '1.0',
    this.protocolVersion = '',
    this.dataOrigin = 'synthetic',
    this.counterbalanceSequence,
    DateTime? sessionDate,
  }) : sessionDate = sessionDate ?? DateTime.now();

  /// Başarı oranı (%)
  double get successRate {
    if (tasks.isEmpty) return 0;
    final successful = tasks.where((t) => t.isSuccess).length;
    return (successful / tasks.length) * 100;
  }

  /// Ortalama görev süresi
  double get avgTaskDuration {
    final durations = tasks
        .where((t) => t.durationSeconds != null)
        .map((t) => t.durationSeconds!)
        .toList();
    if (durations.isEmpty) return 0;
    return durations.reduce((a, b) => a + b) / durations.length;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'participant_id': participantId,
        'session_date': sessionDate.toIso8601String(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'general_note': generalNote,
        'schema_version': schemaVersion,
        'protocol_version': protocolVersion,
        'data_origin': dataOrigin,
        'counterbalance_sequence': counterbalanceSequence,
        'success_rate': successRate,
        'avg_task_duration': avgTaskDuration,
      };
}

// ═══════════════════════════════════════════════════════════════════════════════
// ÖNTANIMLI ANKET SORULARI
// ═══════════════════════════════════════════════════════════════════════════════

/// TÜBİTAK anket soruları
const nutrisenseSurveyQuestions = <SurveyQuestion>[
  SurveyQuestion(
    id: 'q1',
    text: 'Bu uygulamayı kullanmadan önce yiyeceklerin kalorilerini '
        'nasıl öğreniyordunuz?',
    type: QuestionType.multiChoice,
    options: [
      'Birinden yardım istiyordum',
      'İnternet araması yapıyordum',
      'Hiç takip edemiyordum',
      'Başka bir uygulama kullanıyordum',
      'Diyetisyenime soruyordum',
    ],
  ),
  SurveyQuestion(
    id: 'q2',
    text: 'Sesli geri bildirim sistemi ne kadar yeterli buldunuz?',
    type: QuestionType.likert,
  ),
  SurveyQuestion(
    id: 'q3',
    text: 'Besin tarama işlemi ne kadar kolaydı?',
    type: QuestionType.likert,
  ),
  SurveyQuestion(
    id: 'q4',
    text: 'Kalori hesaplama sonuçlarına ne kadar güvendiniz?',
    type: QuestionType.likert,
  ),
  SurveyQuestion(
    id: 'q5',
    text: 'Diyetisyen bildirim özelliğini kullanır mıydınız?',
    type: QuestionType.yesNo,
    options: ['Evet', 'Hayır', 'Belki'],
  ),
  SurveyQuestion(
    id: 'q6',
    text: 'Uygulamada en beğendiğiniz özellik neydi? '
        'Yanıtınıza ad, telefon, e-posta veya başka kişisel bilgi yazmayın.',
    type: QuestionType.openText,
  ),
  SurveyQuestion(
    id: 'q7',
    text: 'Hangi özelliğin eklenmesini isterdiniz? '
        'Yanıtınıza ad, telefon, e-posta veya başka kişisel bilgi yazmayın.',
    type: QuestionType.openText,
  ),
  SurveyQuestion(
    id: 'q8',
    text: 'Genel değerlendirmeniz nedir?',
    type: QuestionType.starRating,
  ),
];

/// Öntanımlı kullanılabilirlik testi görevleri
List<UsabilityTask> defaultUsabilityTasks() => [
      UsabilityTask(
        id: 't1',
        title: 'Uygulama Giriş',
        description: 'Uygulamayı açın ve ana sayfaya ulaşın.',
        startPoint: 'Araştırmacı başlangıç komutunu verir; uygulama kapalıdır.',
        endPoint: 'Ana sayfa başlığı ekran okuyucu tarafından duyurulur.',
        successCriterion:
            'Yardım almadan doğru hesaba girip ana sayfaya ulaşır.',
        maximumSeconds: 180,
      ),
      UsabilityTask(
        id: 't2',
        title: 'Besin Tarama',
        description: 'Bir yiyeceği kamera ile tarayın ve sonucu dinleyin.',
        startPoint: 'Ana sayfa açıktır ve test yiyeceği masadadır.',
        endPoint: 'Katılımcı sonucu dinler, doğrular ve kaydı onaylar.',
        successCriterion: 'Doğru akışı açar; sonucu kaydetmeden önce onaylar.',
        maximumSeconds: 300,
      ),
      UsabilityTask(
        id: 't3',
        title: 'Geçmiş Görüntüleme',
        description: 'Besin geçmişi ekranına gidin ve bugünkü kaydınızı bulun.',
        startPoint: 'Ana sayfa açıktır ve önceki görev kaydı mevcuttur.',
        endPoint: 'Katılımcı kaydın besin adı, porsiyon ve saatini söyler.',
        successCriterion: 'Bugünkü doğru kaydı bağımsız bulur ve dinler.',
        maximumSeconds: 180,
      ),
      UsabilityTask(
        id: 't4',
        title: 'Diyetisyene Gönder',
        description: 'Haftalık raporu diyetisyeninize gönderin.',
        startPoint:
            'Doğrulanmış sentetik diyetisyen ilişkisi ve geçmiş vardır.',
        endPoint:
            'Önizleme/alıcı/kanal doğrulanır ve sandbox gönderimi onaylanır.',
        successCriterion:
            'Açık onay vermeden göndermez; sentetik raporu başarıyla yollar.',
        maximumSeconds: 300,
      ),
      UsabilityTask(
        id: 't5',
        title: 'Ayar Değiştirme',
        description: 'Sesli geri bildirim hızını değiştirin.',
        startPoint: 'Ana sayfa açıktır.',
        endPoint: 'TTS hızı bir kademe değiştirilir ve örnek dinlenir.',
        successCriterion: 'Ayarı bağımsız bulur, değiştirir ve doğrular.',
        maximumSeconds: 180,
      ),
      UsabilityTask(
        id: 't6',
        title: 'Sesli Komut',
        description:
            '"Bugün ne yedim" sesli komutunu kullanarak günlük özeti dinleyin.',
        startPoint: 'Ana sayfa açıktır ve mikrofon kullanıma hazırdır.',
        endPoint:
            'Günlük özet tamamen duyurulur veya dokunma alternatifi kullanılır.',
        successCriterion:
            'Komutu ya da erişilebilir alternatifi bağımsız tamamlar.',
        maximumSeconds: 180,
      ),
    ];
