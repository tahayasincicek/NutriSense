import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/water_tracker/state/water_provider.dart';
import 'package:nutrisense/features/water_tracker/services/step_counter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('başlangıç durumu uydurma ölçüm içermez', () {
    const state = ActivityState();
    expect(state.steps, 0);
    expect(state.consumedWater, 0);
    expect(state.sleepHours, 0);
    expect(state.currentWeight, isNull);
    expect(state.hasWeight, isFalse);
    expect(state.weightHistory, isEmpty);
    expect(state.medications, isEmpty);
  });

  test('rozetler gerçek ilerlemeden türetilir', () {
    const empty = ActivityState();
    expect(empty.badges.every((badge) => !badge.isUnlocked), isTrue);

    const done = ActivityState(
      consumedWater: 2500,
      steps: 10000,
      sleepHours: 8,
      weightHistory: [80, 79, 78],
    );
    expect(done.badges.every((badge) => badge.isUnlocked), isTrue);
  });

  test('ölçümler cihazda saklanır ve geri yüklenir', () async {
    final notifier = ActivityNotifier(null);
    notifier.addWater(600);
    notifier.setSleep(7.5);
    notifier.updateWeight(72.4);
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('activity_state_v1');
    expect(raw, isNotNull);
    final restored =
        ActivityState.fromJson(jsonDecode(raw!) as Map<String, dynamic>);
    expect(restored.consumedWater, 600);
    expect(restored.sleepHours, 7.5);
    expect(restored.currentWeight, 72.4);
  });

  test('gün değişince günlük ölçümler sıfırlanır, kilo geçmişi kalır',
      () async {
    SharedPreferences.setMockInitialValues({
      'activity_state_v1': jsonEncode(const ActivityState(
        consumedWater: 1200,
        steps: 4000,
        sleepHours: 6,
        currentMood: 'mutlu',
        currentWeight: 70,
        weightHistory: [71, 70],
        medications: [
          MedicationModel(name: 'D Vitamini', schedule: 'Sabah', isTaken: true),
        ],
      ).toJson()),
      'activity_state_day': '2020-01-01',
    });

    final notifier = ActivityNotifier(null);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.consumedWater, 0);
    expect(notifier.state.steps, 0);
    expect(notifier.state.sleepHours, 0);
    expect(notifier.state.currentMood, isNull);
    expect(notifier.state.medications.single.isTaken, isFalse);
    // Kilo bir güne ait değildir; korunur.
    expect(notifier.state.currentWeight, 70);
    expect(notifier.state.weightHistory, [71, 70]);
  });

  test('geçersiz kilo yok sayılır', () {
    final notifier = ActivityNotifier(null);
    notifier.updateWeight(0);
    notifier.updateWeight(900);
    expect(notifier.state.currentWeight, isNull);
  });

  test('aynı takviye iki kez eklenmez', () {
    final notifier = ActivityNotifier(null);
    notifier.addMedication('Omega 3', 'Sabah');
    notifier.addMedication('Omega 3', 'Akşam');
    expect(notifier.state.medications.length, 1);

    notifier.removeMedication('Omega 3');
    expect(notifier.state.medications, isEmpty);
  });

  test('bozuk kayıt uygulamayı kilitlemez', () async {
    SharedPreferences.setMockInitialValues({
      'activity_state_v1': 'bu json degil',
    });
    final notifier = ActivityNotifier(null);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.isLoaded, isTrue);
    expect(notifier.state.consumedWater, 0);
  });

  test('gerçek sensör toplamındaki fark günlük adıma eklenir', () async {
    final sensor = _FakeStepCounter();
    final notifier = ActivityNotifier(null, sensor);
    await Future<void>.delayed(Duration.zero);

    sensor.controller.add(1200);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.steps, 0);
    expect(notifier.state.stepTrackingStatus, StepTrackingStatus.active);

    sensor.controller.add(1243);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.steps, 43);
    expect(notifier.state.sensorRawSteps, 1243);

    notifier.dispose();
    await sensor.controller.close();
  });

  test('hareket izni reddedildiğinde sensör dinlenmez', () async {
    final sensor = _FakeStepCounter(permissionGranted: false);
    final notifier = ActivityNotifier(null, sensor);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.stepTrackingStatus, StepTrackingStatus.denied);
    expect(sensor.listenCount, 0);

    notifier.dispose();
    await sensor.controller.close();
  });
}

class _FakeStepCounter implements StepCounterSource {
  _FakeStepCounter({this.permissionGranted = true});

  final bool permissionGranted;
  final controller = StreamController<int>.broadcast();
  int listenCount = 0;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Stream<int> get stepCountStream {
    listenCount++;
    return controller.stream;
  }
}
