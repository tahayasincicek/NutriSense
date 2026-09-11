// =============================================================================
// lib/features/survey/screens/survey_screen.dart
// NutriSense — Erişilebilir Anket Ekranı
//
// 8 soruluk TÜBİTAK anketi.
// Her soru TTS ile okunur, sesli komutla ileri/geri geçiş.
// Likert (1-5), çoktan seçmeli, evet/hayır, açık uçlu, yıldız puanlama.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/voice_command_service.dart';
import '../models/survey_model.dart';
import '../services/survey_service.dart';

class SurveyScreen extends ConsumerStatefulWidget {
  const SurveyScreen({super.key});

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends ConsumerState<SurveyScreen> {
  late AccessibilityService _accessibility;
  late SurveyService _surveyService;
  late VoiceCommandService _voiceCmd;

  // ── Anket durumu ──
  final _questions = nutrisenseSurveyQuestions;
  final Map<String, dynamic> _answers = {};
  int _currentIndex = 0;
  bool _isCompleted = false;
  bool _isSubmitting = false;
  late DateTime _startTime;

  // ── Açık uçlu metin kontrolcüleri ──
  final _textControllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _accessibility = ref.read(accessibilityServiceProvider);
    _surveyService = ref.read(surveyServiceProvider);
    _voiceCmd = ref.read(voiceCommandServiceProvider);
    _startTime = DateTime.now();

    // Metin kontrolcülerini hazırla
    for (final q in _questions) {
      if (q.type == QuestionType.openText) {
        _textControllers[q.id] = TextEditingController();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _accessibility.speak(
        'Anket ekranı. ${_questions.length} soru cevaplanacak. '
        'İlk soru okunuyor.',
        priority: TtsPriority.high,
      );
      Future.delayed(const Duration(seconds: 2), () => _readCurrentQuestion());
    });
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anket'),
        actions: [
          // Soruyu oku butonu
          // tooltip düğmenin kendi adıdır; yalnız dıştaki Semantics'e
          // yazılırsa ekran okuyucu düğmeye odaklandığında adsız kalır.
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: 'Soruyu tekrar oku',
            onPressed: _readCurrentQuestion,
          ),
        ],
      ),
      body: _isCompleted
          ? _buildCompletionScreen(theme)
          : _buildSurveyBody(theme),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ANKET GÖVDESİ
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSurveyBody(ThemeData theme) {
    final question = _questions[_currentIndex];

    return Column(
      children: [
        // ── İlerleme çubuğu ──
        _buildProgressBar(theme),

        // ── Soru içeriği ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Soru numarası
                Semantics(
                  label:
                      '${_questions.length} sorudan ${_currentIndex + 1}. soru.',
                  child: Text(
                    'Soru ${_currentIndex + 1} / ${_questions.length}',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Soru metni
                Semantics(
                  label: question.text,
                  header: true,
                  child: Text(
                    question.text,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Soru tipine göre widget
                _buildQuestionWidget(question, theme),
              ],
            ),
          ),
        ),

        // ── Navigasyon butonları ──
        _buildNavButtons(theme),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // İLERLEME ÇUBUĞU
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProgressBar(ThemeData theme) {
    final progress = (_currentIndex + 1) / _questions.length;

    return Semantics(
      label: 'İlerleme: yüzde ${(progress * 100).toInt()}',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '%${(progress * 100).toInt()}',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SORU TİPLERİ
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildQuestionWidget(SurveyQuestion question, ThemeData theme) {
    return switch (question.type) {
      QuestionType.likert => _buildLikert(question, theme),
      QuestionType.multiChoice => _buildMultiChoice(question, theme),
      QuestionType.yesNo => _buildYesNo(question, theme),
      QuestionType.openText => _buildOpenText(question, theme),
      QuestionType.starRating => _buildStarRating(question, theme),
    };
  }

  // ── Likert 1-5 ──
  Widget _buildLikert(SurveyQuestion question, ThemeData theme) {
    final current = _answers[question.id] as int?;
    final labels = _getLikertLabels(question.id);

    return Column(
      children: List.generate(5, (i) {
        final value = i + 1;
        final label = labels[value] ?? '$value';
        final isSelected = current == value;

        return Semantics(
          label: '$value: $label${isSelected ? ", seçili" : ""}. '
              'Seçmek için çift dokunun.',
          selected: isSelected,
          button: true,
          // Dokunma eylemi adlandirilmis dugume tasinir; ic
          // GestureDetector adsiz bir dugum birakmasin.
          excludeSemantics: true,
          onTap: () => _setAnswer(question.id, value, label),
          child: GestureDetector(
            onTap: () => _setAnswer(question.id, value, label),
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.12)
                    : theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : theme.colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Numara dairesi
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                    ),
                    child: Center(
                      child: Text(
                        '$value',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          isSelected ? AppTheme.primaryColor : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    const Icon(Icons.check_circle,
                        color: AppTheme.primaryColor, size: 24),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Çoktan seçmeli ──
  Widget _buildMultiChoice(SurveyQuestion question, ThemeData theme) {
    final current = _answers[question.id] as String?;
    final options = question.options ?? [];

    return Column(
      children: options.map((opt) {
        final isSelected = current == opt;
        return Semantics(
          label: '$opt${isSelected ? ", seçili" : ""}',
          selected: isSelected,
          button: true,
          // Dokunma eylemi adlandirilmis dugume tasinir; ic
          // GestureDetector adsiz bir dugum birakmasin.
          excludeSemantics: true,
          onTap: () => _setAnswer(question.id, opt, opt),
          child: GestureDetector(
            onTap: () => _setAnswer(question.id, opt, opt),
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.12)
                    : Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Theme.of(context).colorScheme.outline,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      opt,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Evet / Hayır / Belki ──
  Widget _buildYesNo(SurveyQuestion question, ThemeData theme) {
    final current = _answers[question.id] as String?;
    final options = question.options ?? ['Evet', 'Hayır', 'Belki'];

    final icons = {
      'Evet': Icons.check_circle_outline,
      'Hayır': Icons.cancel_outlined,
      'Belki': Icons.help_outline,
    };

    final colors = {
      'Evet': Colors.green,
      'Hayır': Colors.red,
      'Belki': Colors.orange,
    };

    return Row(
      children: options.map((opt) {
        final isSelected = current == opt;
        return Expanded(
          child: Semantics(
            label: '$opt${isSelected ? ", seçili" : ""}',
            selected: isSelected,
            button: true,
            // Dokunma eylemi adlandirilmis dugume tasinir; ic
            // GestureDetector adsiz bir dugum birakmasin.
            excludeSemantics: true,
            onTap: () => _setAnswer(question.id, opt, opt),
            child: GestureDetector(
              onTap: () => _setAnswer(question.id, opt, opt),
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (colors[opt] ?? AppTheme.primaryColor)
                          .withValues(alpha: 0.15)
                      : Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(
                    color: isSelected
                        ? (colors[opt] ?? AppTheme.primaryColor)
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      icons[opt] ?? Icons.circle_outlined,
                      size: 36,
                      color: isSelected
                          ? (colors[opt] ?? AppTheme.primaryColor)
                          : Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      opt,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? (colors[opt] ?? AppTheme.primaryColor)
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Açık uçlu metin ──
  Widget _buildOpenText(SurveyQuestion question, ThemeData theme) {
    final controller = _textControllers[question.id]!;

    return Semantics(
      label:
          'Yanıtınızı yazın veya sesli giriş için mikrofon butonunu kullanın.',
      child: Column(
        children: [
          TextField(
            controller: controller,
            maxLines: 4,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Yanıtınızı buraya yazın...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
            ),
            onChanged: (text) {
              _answers[question.id] = text;
            },
          ),
          const SizedBox(height: 12),
          // Sesli giriş butonu
          Semantics(
            label: 'Sesli giriş. Konuşarak yanıt verin.',
            button: true,
            child: OutlinedButton.icon(
              onPressed: () async {
                _accessibility.speak(
                  'Sesli giriş aktif. Yanıtınızı söyleyin.',
                  priority: TtsPriority.normal,
                );
                // Sesli komutu dinle ve metin alanına yaz
                await _voiceCmd.startListening();
              },
              icon: const Icon(Icons.mic, size: 22),
              label: const Text('Sesli Giriş', style: TextStyle(fontSize: 15)),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Yıldız puanlama ──
  Widget _buildStarRating(SurveyQuestion question, ThemeData theme) {
    final current = _answers[question.id] as int? ?? 0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final value = i + 1;
            final isActive = value <= current;
            final label = LikertLabels.starLabels[value] ?? '';

            return Semantics(
              label:
                  '$value yıldız: $label${value == current ? ", seçili" : ""}',
              selected: value == current,
              button: true,
              // Dokunma eylemi adlandirilmis dugume tasinir; ic
              // GestureDetector adsiz bir dugum birakmasin.
              excludeSemantics: true,
              onTap: () =>
                  _setAnswer(question.id, value, '$value yıldız, $label'),
              child: GestureDetector(
                onTap: () =>
                    _setAnswer(question.id, value, '$value yıldız, $label'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedScale(
                    scale: value == current ? 1.2 : 1.0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    child: Icon(
                      isActive
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 48,
                      color: isActive
                          ? AppTheme.warningColor
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        if (current > 0)
          Text(
            LikertLabels.starLabels[current] ?? '',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.warningColor,
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NAVİGASYON
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildNavButtons(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Geri
          if (_currentIndex > 0)
            Expanded(
              child: Semantics(
                label: 'Önceki soru',
                button: true,
                child: OutlinedButton.icon(
                  onPressed: _goToPrevious,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Önceki', style: TextStyle(fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),

          if (_currentIndex > 0) const SizedBox(width: 12),

          // İleri / Gönder
          Expanded(
            child: Semantics(
              label: _isLastQuestion ? 'Anketi gönder' : 'Sonraki soru',
              button: true,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _goToNext,
                icon: Icon(_isLastQuestion ? Icons.send : Icons.arrow_forward),
                label: Text(
                  _isLastQuestion ? 'Gönder' : 'Sonraki',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAMAMLAMA EKRANI
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCompletionScreen(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle,
                size: 80, color: AppTheme.primaryColor),
            const SizedBox(height: 24),
            Text(
              'Anket Tamamlandı!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Katılımınız için teşekkür ederiz.\n'
              'Yanıtlarınız araştırmaya önemli katkı sağlayacaktır.',
              style: theme.textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.home),
              label:
                  const Text('Ana Sayfaya Dön', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOJİK
  // ═══════════════════════════════════════════════════════════════════════════

  bool get _isLastQuestion => _currentIndex >= _questions.length - 1;

  void _setAnswer(String qId, dynamic value, String ttsLabel) {
    setState(() => _answers[qId] = value);
    _accessibility.speak(ttsLabel, priority: TtsPriority.normal);
    _accessibility.lightHaptic();
  }

  void _readCurrentQuestion() {
    final q = _questions[_currentIndex];
    final num = _currentIndex + 1;
    final total = _questions.length;

    _accessibility.speak(
      '$total sorudan $num. soru. ${q.text}',
      priority: TtsPriority.high,
    );
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _readCurrentQuestion();
      _accessibility.lightHaptic();
    }
  }

  void _goToNext() {
    if (_isLastQuestion) {
      _submitSurvey();
    } else {
      setState(() => _currentIndex++);
      _readCurrentQuestion();
      _accessibility.lightHaptic();
    }
  }

  Map<int, String> _getLikertLabels(String qId) {
    return switch (qId) {
      'q3' => LikertLabels.easeLabels,
      'q4' => LikertLabels.trustLabels,
      _ => LikertLabels.labels,
    };
  }

  Future<void> _submitSurvey() async {
    setState(() => _isSubmitting = true);

    _accessibility.speak(
      'Anket gönderiliyor, lütfen bekleyin.',
      priority: TtsPriority.high,
    );

    // Açık uçlu yanıtları güncelle
    for (final q in _questions) {
      if (q.type == QuestionType.openText) {
        _answers[q.id] = _textControllers[q.id]?.text ?? '';
      }
    }

    final submission = SurveySubmission(
      id: const Uuid().v4(),
      participantId: await _surveyService.getOrCreateResearchParticipantId(),
      answers: _answers.entries
          .map((e) => SurveyAnswer(questionId: e.key, answer: e.value))
          .toList(),
      completionTime: DateTime.now().difference(_startTime),
      deviceInfo: await _surveyService.getDeviceInfo(),
    );

    await _surveyService.submitSurvey(submission);

    setState(() {
      _isSubmitting = false;
      _isCompleted = true;
    });

    _accessibility.speak(
      'Anket tamamlandı. Katıldığınız için teşekkür ederiz.',
      priority: TtsPriority.high,
    );
    _accessibility.successHaptic();
  }
}
