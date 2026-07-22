import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/survey/models/research_runtime_config.dart';
import 'package:nutrisense/features/survey/models/survey_model.dart';

void main() {
  group('research approval gate', () {
    test('approved mode rejects missing external references', () {
      const config = ResearchRuntimeConfig(
        mode: ResearchMode.approved,
        protocolVersion: '',
        consentVersion: 'TODO',
        approvalReference: 'PLACEHOLDER',
      );

      expect(config.canCollectParticipant, isFalse);
      expect(config.assertCollectionAllowed,
          throwsA(isA<ResearchGateException>()));
    });

    test('synthetic mode is explicitly marked synthetic', () {
      const config = ResearchRuntimeConfig(
        mode: ResearchMode.synthetic,
        protocolVersion: '',
        consentVersion: '',
        approvalReference: '',
      );

      expect(config.canCollectSynthetic, isTrue);
      expect(config.dataOrigin, 'synthetic');
      expect(config.assertCollectionAllowed, returnsNormally);
    });
  });

  test('usability duration uses monotonic timer and exports audit fields',
      () async {
    final task = UsabilityTask(
      id: 't1',
      title: 'Sentetik görev',
      description: 'Gerçek katılımcı içermez',
      successCriterion: 'Sentetik ölçüm tamamlanır',
      startPoint: 'Başlangıç',
      endPoint: 'Bitiş',
      maximumSeconds: 30,
    );

    task.startTime = DateTime.now();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    task.status = TaskStatus.completed;
    task.endTime = DateTime.now();
    task.errorCount = 1;
    task.assistanceLevel = 'prompt';

    final json = task.toJson();
    expect(json['duration_seconds'], greaterThan(0));
    expect(json['timing_source'], 'monotonic');
    expect(json['error_count'], 1);
    expect(json['assistance_level'], 'prompt');
    expect(json['maximum_seconds'], 30);
  });

  test('open text questions contain a personal-data warning', () {
    final openTextQuestions = nutrisenseSurveyQuestions
        .where((question) => question.type == QuestionType.openText);

    expect(openTextQuestions, isNotEmpty);
    for (final question in openTextQuestions) {
      expect(question.text, contains('kişisel bilgi yazmayın'));
      expect(question.instrumentVersion, surveyInstrumentVersion);
    }
  });

  test('all six tasks define measurable boundaries', () {
    final tasks = defaultUsabilityTasks();
    expect(tasks, hasLength(6));
    for (final task in tasks) {
      expect(task.startPoint, isNotEmpty);
      expect(task.endPoint, isNotEmpty);
      expect(task.successCriterion, isNotEmpty);
      expect(task.maximumSeconds, greaterThan(0));
    }
  });
}
