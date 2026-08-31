import 'package:flutter_riverpod/flutter_riverpod.dart';

class BadgeModel {
  final String title;
  final String icon;
  final bool isUnlocked;
  BadgeModel({required this.title, required this.icon, this.isUnlocked = false});
}

/// İlaç / takviye hatırlatması.
class MedicationModel {
  const MedicationModel({
    required this.name,
    required this.schedule,
    this.isTaken = false,
  });

  final String name;
  final String schedule;
  final bool isTaken;

  MedicationModel copyWith({bool? isTaken}) => MedicationModel(
        name: name,
        schedule: schedule,
        isTaken: isTaken ?? this.isTaken,
      );
}

class ActivityState {
  final int consumedWater;
  final int waterGoal;
  final int steps;
  final int stepGoal;
  final double currentWeight;
  final List<double> weightHistory;
  final List<BadgeModel> badges;
  final String? currentMood;
  final double sleepHours; // Yeni: Uyku saati
  final double sleepGoal;  // Yeni: Uyku hedefi
  final List<MedicationModel> medications;

  ActivityState({
    this.consumedWater = 0,
    this.waterGoal = 2500,
    this.steps = 1240,
    this.stepGoal = 10000,
    this.currentWeight = 75.5,
    this.weightHistory = const [77.0, 76.8, 76.2, 75.8, 75.5],
    this.badges = const [],
    this.currentMood,
    this.sleepHours = 6.5,
    this.sleepGoal = 8.0,
    this.medications = const [
      MedicationModel(name: 'Omega 3', schedule: 'Sabah - Tok', isTaken: true),
      MedicationModel(name: 'D Vitamini', schedule: 'Öğle - Tok'),
    ],
  });

  double get waterProgress => consumedWater / waterGoal;
  double get stepProgress => steps / stepGoal;
  double get sleepProgress => sleepHours / sleepGoal;

  ActivityState copyWith({
    int? consumedWater,
    int? waterGoal,
    int? steps,
    int? stepGoal,
    double? currentWeight,
    List<double>? weightHistory,
    List<BadgeModel>? badges,
    String? currentMood,
    double? sleepHours,
    double? sleepGoal,
    List<MedicationModel>? medications,
  }) {
    return ActivityState(
      consumedWater: consumedWater ?? this.consumedWater,
      waterGoal: waterGoal ?? this.waterGoal,
      steps: steps ?? this.steps,
      stepGoal: stepGoal ?? this.stepGoal,
      currentWeight: currentWeight ?? this.currentWeight,
      weightHistory: weightHistory ?? this.weightHistory,
      badges: badges ?? this.badges,
      currentMood: currentMood ?? this.currentMood,
      sleepHours: sleepHours ?? this.sleepHours,
      sleepGoal: sleepGoal ?? this.sleepGoal,
      medications: medications ?? this.medications,
    );
  }
}

class ActivityNotifier extends StateNotifier<ActivityState> {
  ActivityNotifier() : super(ActivityState(
    badges: [
      BadgeModel(title: 'Su Avcısı', icon: '💧', isUnlocked: true),
      BadgeModel(title: 'Yolcu', icon: '👟', isUnlocked: true),
      BadgeModel(title: 'Uykucu', icon: '🌙', isUnlocked: true),
    ]
  ));

  void addWater(int ml) => state = state.copyWith(consumedWater: state.consumedWater + ml);
  void addSteps(int count) => state = state.copyWith(steps: state.steps + count);
  void updateWeight(double weight) {
    final history = List<double>.from(state.weightHistory)..add(weight);
    state = state.copyWith(currentWeight: weight, weightHistory: history);
  }
  void setMood(String mood) => state = state.copyWith(currentMood: mood);

  /// Uyku süresini saat cinsinden kaydeder. 0-24 aralığına sıkıştırılır.
  void setSleep(double hours) =>
      state = state.copyWith(sleepHours: hours.clamp(0, 24));

  /// İlacın alındı durumunu tersine çevirir.
  void toggleMedication(String name) {
    state = state.copyWith(
      medications: state.medications
          .map((med) =>
              med.name == name ? med.copyWith(isTaken: !med.isTaken) : med)
          .toList(),
    );
  }
}

final activityProvider = StateNotifierProvider<ActivityNotifier, ActivityState>((ref) => ActivityNotifier());
