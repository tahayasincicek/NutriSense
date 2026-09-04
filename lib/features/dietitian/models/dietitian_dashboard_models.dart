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
    this.pendingRequests = const [],
    this.recentReports = const [],
  });

  final String dietitianId;
  final String fullName;
  final String specialization;
  final bool emailVerified;
  final int activePatients;
  final int pendingAssignments;
  final int reportsReceived;
  final List<DietitianPatientSummary> patients;
  final List<DietitianPendingRequest> pendingRequests;
  final List<DietitianReceivedReport> recentReports;

  factory DietitianDashboardData.fromJson(Map<String, dynamic> json) {
    final rawPatients = json['patients'] as List<dynamic>? ?? const [];
    final rawRequests = json['pending_requests'] as List<dynamic>? ?? const [];
    final rawReports = json['recent_reports'] as List<dynamic>? ?? const [];
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
      pendingRequests: rawRequests
          .whereType<Map<String, dynamic>>()
          .map(DietitianPendingRequest.fromJson)
          .toList(growable: false),
      recentReports: rawReports
          .whereType<Map<String, dynamic>>()
          .map(DietitianReceivedReport.fromJson)
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
    this.dailyCalorieTarget = 2000,
    this.assignmentId,
  });

  final String userId;
  final String fullName;
  final String email;
  final double todayCalories;
  final int sevenDayMeals;
  final DateTime? lastLogAt;

  /// Kullanıcının kendi günlük kalori hedefi; panelde karşılaştırma için.
  final double dailyCalorieTarget;

  /// Eşleşmeyi sonlandırmak için gereken atama kimliği.
  final String? assignmentId;

  factory DietitianPatientSummary.fromJson(Map<String, dynamic> json) =>
      DietitianPatientSummary(
        userId: json['user_id'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        todayCalories: (json['today_calories'] as num?)?.toDouble() ?? 0,
        sevenDayMeals: json['seven_day_meals'] as int? ?? 0,
        lastLogAt:
            DateTime.tryParse(json['last_log_at'] as String? ?? '')?.toLocal(),
        dailyCalorieTarget:
            (json['daily_calorie_target'] as num?)?.toDouble() ?? 2000,
        assignmentId: json['assignment_id'] as String?,
      );

  /// Hedefe göre tamamlanma oranı; ilerleme çubuğu için 0-1 aralığında.
  double get targetProgress => dailyCalorieTarget <= 0
      ? 0
      : (todayCalories / dailyCalorieTarget).clamp(0.0, 1.0);

  /// Son kayıttan bu yana geçen tam gün sayısı.
  int? get daysSinceLastLog =>
      lastLogAt == null ? null : DateTime.now().difference(lastLogAt!).inDays;

  /// Üç gün ve üzeri sessizlik takip uyarısı sayılır.
  bool get needsFollowUp {
    final days = daysSinceLastLog;
    return days == null || days >= 3;
  }

  String get followUpLabel {
    final days = daysSinceLastLog;
    if (days == null) return 'Hiç kayıt yok';
    if (days == 0) return 'Bugün kayıt yaptı';
    if (days == 1) return 'Dün kayıt yaptı';
    return '$days gündür kayıt yok';
  }
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

/// Diyetisyenin kabul veya ret bekleyen eşleşme isteği.
class DietitianPendingRequest {
  const DietitianPendingRequest({
    required this.assignmentId,
    required this.patientName,
    required this.patientEmailMasked,
    required this.requestedAt,
    required this.patientApproved,
  });

  final String assignmentId;
  final String patientName;

  /// Hasta e-postası sunucuda maskelenir; panelde tam adres gösterilmez.
  final String patientEmailMasked;
  final DateTime requestedAt;

  /// Hastanın kendi rızasını verip vermediği. İki onay da gerekir.
  final bool patientApproved;

  factory DietitianPendingRequest.fromJson(Map<String, dynamic> json) =>
      DietitianPendingRequest(
        assignmentId: json['assignment_id'] as String? ?? '',
        patientName: json['patient_name'] as String? ?? 'Bilinmeyen hasta',
        patientEmailMasked: json['patient_email_masked'] as String? ?? '',
        requestedAt: DateTime.tryParse(json['requested_at'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
        patientApproved: json['patient_approved'] as bool? ?? false,
      );
}

/// Danışanın onayıyla diyetisyene ulaşmış beslenme raporu.
///
/// Alanlar proje raporunun diyetisyen vaadini karşılar: besin kaydı sayısı,
/// tarih aralığı ve kalori toplamı.
class DietitianReceivedReport {
  const DietitianReceivedReport({
    required this.reportId,
    required this.patientId,
    required this.patientName,
    required this.reportType,
    required this.fromDate,
    required this.toDate,
    required this.recordCount,
    required this.totalMeals,
    required this.totalCalories,
    required this.status,
    required this.createdAt,
    required this.deliveredViaEmail,
    required this.deliveredViaSms,
  });

  final String reportId;
  final String patientId;
  final String patientName;
  final String reportType;
  final DateTime fromDate;
  final DateTime toDate;
  final int recordCount;
  final int totalMeals;
  final double totalCalories;
  final String status;
  final DateTime createdAt;
  final bool deliveredViaEmail;
  final bool deliveredViaSms;

  /// Kısmi teslimat, gönderimin bir kanalda başarısız olduğunu anlatır.
  bool get isPartial => status == 'partial_failed';

  String get reportTypeLabel => switch (reportType) {
        'daily' => 'Günlük',
        'weekly' => 'Haftalık',
        'monthly' => 'Aylık',
        _ => 'Rapor',
      };

  String get channelLabel {
    if (deliveredViaEmail && deliveredViaSms) return 'E-posta ve SMS';
    if (deliveredViaEmail) return 'E-posta';
    if (deliveredViaSms) return 'SMS';
    return 'Kanal yok';
  }

  factory DietitianReceivedReport.fromJson(Map<String, dynamic> json) =>
      DietitianReceivedReport(
        reportId: json['report_id'] as String? ?? '',
        patientId: json['patient_id'] as String? ?? '',
        patientName: json['patient_name'] as String? ?? 'Bilinmeyen danışan',
        reportType: json['report_type'] as String? ?? 'weekly',
        fromDate: DateTime.tryParse(json['from_date'] as String? ?? '') ??
            DateTime.now(),
        toDate: DateTime.tryParse(json['to_date'] as String? ?? '') ??
            DateTime.now(),
        recordCount: json['record_count'] as int? ?? 0,
        totalMeals: json['total_meals'] as int? ?? 0,
        totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        deliveredViaEmail: json['delivered_via_email'] as bool? ?? false,
        deliveredViaSms: json['delivered_via_sms'] as bool? ?? false,
      );
}

/// Raporun içindeki tek besin kaydı.
class DietitianReportRecord {
  const DietitianReportRecord({
    required this.foodNameTr,
    required this.portionGrams,
    required this.portionIsEstimate,
    required this.totalCalories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.mealType,
    required this.loggedAt,
    required this.isCorrected,
  });

  final String foodNameTr;
  final double portionGrams;
  final bool portionIsEstimate;
  final double totalCalories;
  final double protein;
  final double carbs;
  final double fat;
  final String mealType;
  final DateTime loggedAt;
  final bool isCorrected;

  String get mealLabel => switch (mealType) {
        'kahvalti' => 'Kahvaltı',
        'ogle' => 'Öğle',
        'aksam' => 'Akşam',
        _ => 'Atıştırmalık',
      };

  factory DietitianReportRecord.fromJson(Map<String, dynamic> json) =>
      DietitianReportRecord(
        foodNameTr: json['food_name_tr'] as String? ?? 'Bilinmeyen besin',
        portionGrams: (json['portion_grams'] as num?)?.toDouble() ?? 0,
        portionIsEstimate: json['portion_is_estimate'] as bool? ?? false,
        totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
        mealType: json['meal_type'] as String? ?? 'atistirmalik',
        loggedAt:
            DateTime.tryParse(json['logged_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        isCorrected: json['is_corrected'] as bool? ?? false,
      );
}

class DietitianReportDay {
  const DietitianReportDay({
    required this.date,
    required this.calories,
    required this.recordCount,
  });

  final DateTime date;
  final double calories;
  final int recordCount;

  factory DietitianReportDay.fromJson(Map<String, dynamic> json) =>
      DietitianReportDay(
        date:
            DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        calories: (json['calories'] as num?)?.toDouble() ?? 0,
        recordCount: json['record_count'] as int? ?? 0,
      );
}

/// Raporun tam içeriği: proje raporunun diyetisyene vaat ettiği veri kümesi.
class DietitianReportDetail {
  const DietitianReportDetail({
    required this.reportId,
    required this.patientName,
    required this.reportType,
    required this.fromDate,
    required this.toDate,
    required this.recordCount,
    required this.totalCalories,
    required this.averageDailyCalories,
    required this.estimatedPortionCount,
    required this.disclaimer,
    this.patientNote,
    this.dietitianReply,
    this.dietitianRepliedAt,
    required this.records,
    required this.dailyBreakdown,
  });

  final String reportId;
  final String patientName;
  final String reportType;
  final DateTime fromDate;
  final DateTime toDate;
  final int recordCount;
  final double totalCalories;
  final double averageDailyCalories;
  final int estimatedPortionCount;
  final String disclaimer;

  /// Danışanın gönderim sırasında yazdığı isteğe bağlı not veya soru.
  final String? patientNote;

  /// Diyetisyenin bu rapora yazdığı cevap.
  final String? dietitianReply;
  final DateTime? dietitianRepliedAt;
  final List<DietitianReportRecord> records;
  final List<DietitianReportDay> dailyBreakdown;

  /// Rapordaki tüm kayıtların makro toplamı (gram).
  ({double protein, double carbs, double fat}) get macroTotals {
    var protein = 0.0;
    var carbs = 0.0;
    var fat = 0.0;
    for (final record in records) {
      protein += record.protein;
      carbs += record.carbs;
      fat += record.fat;
    }
    return (protein: protein, carbs: carbs, fat: fat);
  }

  /// Öğün türüne göre ortalama kayıt saati ve kayıt sayısı.
  ///
  /// Diyetisyen için "kahvaltıyı genelde ne zaman yapıyor" sorusunun cevabı;
  /// öğün düzeni beslenme takibinde kalori kadar anlamlıdır.
  List<({String meal, int count, int averageMinutes})> get mealTimingSummary {
    final buckets = <String, List<int>>{};
    for (final record in records) {
      final minutes = record.loggedAt.hour * 60 + record.loggedAt.minute;
      buckets.putIfAbsent(record.mealLabel, () => []).add(minutes);
    }
    const order = ['Kahvaltı', 'Öğle', 'Akşam', 'Atıştırmalık'];
    final summary = buckets.entries
        .map((entry) => (
              meal: entry.key,
              count: entry.value.length,
              averageMinutes:
                  entry.value.reduce((a, b) => a + b) ~/ entry.value.length,
            ))
        .toList()
      ..sort((a, b) => order.indexOf(a.meal).compareTo(order.indexOf(b.meal)));
    return summary;
  }

  factory DietitianReportDetail.fromJson(Map<String, dynamic> json) {
    final rawRecords = json['records'] as List<dynamic>? ?? const [];
    final rawDays = json['daily_breakdown'] as List<dynamic>? ?? const [];
    return DietitianReportDetail(
      reportId: json['report_id'] as String? ?? '',
      patientName: json['patient_name'] as String? ?? 'Bilinmeyen danışan',
      reportType: json['report_type'] as String? ?? 'weekly',
      fromDate: DateTime.tryParse(json['from_date'] as String? ?? '') ??
          DateTime.now(),
      toDate:
          DateTime.tryParse(json['to_date'] as String? ?? '') ?? DateTime.now(),
      recordCount: json['record_count'] as int? ?? 0,
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0,
      averageDailyCalories:
          (json['average_daily_calories'] as num?)?.toDouble() ?? 0,
      estimatedPortionCount: json['estimated_portion_count'] as int? ?? 0,
      disclaimer: json['disclaimer'] as String? ?? '',
      patientNote: (json['patient_note'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['patient_note'] as String).trim(),
      dietitianReply:
          (json['dietitian_reply'] as String?)?.trim().isEmpty ?? true
              ? null
              : (json['dietitian_reply'] as String).trim(),
      dietitianRepliedAt:
          DateTime.tryParse(json['dietitian_replied_at'] as String? ?? '')
              ?.toLocal(),
      records: rawRecords
          .whereType<Map<String, dynamic>>()
          .map(DietitianReportRecord.fromJson)
          .toList(growable: false),
      dailyBreakdown: rawDays
          .whereType<Map<String, dynamic>>()
          .map(DietitianReportDay.fromJson)
          .toList(growable: false),
    );
  }
}

/// Diyetisyenin bir danışan için yazdığı tek not.
///
/// Notlar birikir: yeni kayıt eskisinin üzerine yazmaz, listeye eklenir.
class DietitianNote {
  const DietitianNote({
    required this.id,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String body;
  final DateTime createdAt;

  factory DietitianNote.fromJson(Map<String, dynamic> json) => DietitianNote(
        id: json['id'] as String? ?? '',
        body: (json['body'] as String? ?? '').trim(),
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
      );

  /// Uçların döndürdüğü `{user_id, items}` gövdesinden liste çıkarır.
  static List<DietitianNote> listFromJson(Map<String, dynamic>? json) =>
      (json?['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DietitianNote.fromJson)
          .toList(growable: false);
}
