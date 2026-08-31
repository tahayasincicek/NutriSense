class DietitianDashboardData {
  const DietitianDashboardData({
    required this.dietitianId,
    required this.fullName,
    required this.specialization,
    required this.emailVerified,
    required this.activePatients,
    required this.pendingAssignments,
    required this.reportsReceived,
    required this.patients,
  });

  final String dietitianId;
  final String fullName;
  final String specialization;
  final bool emailVerified;
  final int activePatients;
  final int pendingAssignments;
  final int reportsReceived;
  final List<DietitianPatientSummary> patients;

  factory DietitianDashboardData.fromJson(Map<String, dynamic> json) {
    final rawPatients = json['patients'] as List<dynamic>? ?? const [];
    return DietitianDashboardData(
      dietitianId: json['dietitian_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      specialization: json['specialization'] as String? ?? '',
      emailVerified: json['email_verified'] as bool? ?? false,
      activePatients: json['active_patients'] as int? ?? 0,
      pendingAssignments: json['pending_assignments'] as int? ?? 0,
      reportsReceived: json['reports_received'] as int? ?? 0,
      patients: rawPatients
          .whereType<Map<String, dynamic>>()
          .map(DietitianPatientSummary.fromJson)
          .toList(growable: false),
    );
  }
}

class DietitianPatientSummary {
  const DietitianPatientSummary({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.todayCalories,
    required this.sevenDayMeals,
    this.lastLogAt,
  });

  final String userId;
  final String fullName;
  final String email;
  final double todayCalories;
  final int sevenDayMeals;
  final DateTime? lastLogAt;

  factory DietitianPatientSummary.fromJson(Map<String, dynamic> json) =>
      DietitianPatientSummary(
        userId: json['user_id'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        todayCalories: (json['today_calories'] as num?)?.toDouble() ?? 0,
        sevenDayMeals: json['seven_day_meals'] as int? ?? 0,
        lastLogAt: DateTime.tryParse(json['last_log_at'] as String? ?? ''),
      );
}

class DietitianPatientHistoryData {
  const DietitianPatientHistoryData({
    required this.userId,
    required this.fullName,
    required this.dateFrom,
    required this.dateTo,
    required this.totalCalories,
    required this.totalMeals,
    required this.logs,
  });

  final String userId;
  final String fullName;
  final DateTime dateFrom;
  final DateTime dateTo;
  final double totalCalories;
  final int totalMeals;
  final List<DietitianPatientLog> logs;

  factory DietitianPatientHistoryData.fromJson(Map<String, dynamic> json) {
    final rawLogs = json['logs'] as List<dynamic>? ?? const [];
    return DietitianPatientHistoryData(
      userId: json['user_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      dateFrom: DateTime.tryParse(json['date_from'] as String? ?? '') ??
          DateTime.now(),
      dateTo:
          DateTime.tryParse(json['date_to'] as String? ?? '') ?? DateTime.now(),
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0,
      totalMeals: json['total_meals'] as int? ?? 0,
      logs: rawLogs
          .whereType<Map<String, dynamic>>()
          .map(DietitianPatientLog.fromJson)
          .toList(growable: false),
    );
  }
}

class DietitianPatientLog {
  const DietitianPatientLog({
    required this.id,
    required this.foodName,
    required this.mealType,
    required this.portionGrams,
    required this.totalCalories,
    required this.loggedAt,
  });

  final String id;
  final String foodName;
  final String mealType;
  final double portionGrams;
  final double totalCalories;
  final DateTime loggedAt;

  factory DietitianPatientLog.fromJson(Map<String, dynamic> json) =>
      DietitianPatientLog(
        id: json['id'] as String? ?? '',
        foodName: json['food_name_tr'] as String? ??
            json['food_name'] as String? ??
            '',
        mealType: json['meal_type'] as String? ?? 'atistirmalik',
        portionGrams: (json['portion_grams'] as num?)?.toDouble() ?? 0,
        totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0,
        loggedAt: DateTime.tryParse(json['logged_at'] as String? ?? '') ??
            DateTime.now(),
      );
}
