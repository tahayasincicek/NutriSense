import 'package:flutter_riverpod/flutter_riverpod.dart';

class WaterState {
  final int consumedAmount; // ml cinsinden
  final int goalAmount;     // ml cinsinden

  WaterState({this.consumedAmount = 0, this.goalAmount = 2500});

  double get progress => consumedAmount / goalAmount;
  int get remaining => (goalAmount - consumedAmount).clamp(0, 5000);

  WaterState copyWith({int? consumedAmount, int? goalAmount}) {
    return WaterState(
      consumedAmount: consumedAmount ?? this.consumedAmount,
      goalAmount: goalAmount ?? this.goalAmount,
    );
  }
}

class WaterNotifier extends StateNotifier<WaterState> {
  WaterNotifier() : super(WaterState());

  void addWater(int ml) {
    state = state.copyWith(consumedAmount: state.consumedAmount + ml);
  }

  void reset() {
    state = state.copyWith(consumedAmount: 0);
  }

  void setGoal(int ml) {
    state = state.copyWith(goalAmount: ml);
  }
}

final waterProvider = StateNotifierProvider<WaterNotifier, WaterState>((ref) {
  return WaterNotifier();
});
