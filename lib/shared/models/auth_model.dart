class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final bool isActive;
  final String accountType;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
    this.accountType = 'patient',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? false,
        accountType: json['account_type'] as String? ?? 'patient',
      );
}

class DietitianAssignmentInfo {
  final String assignmentId;
  final String status;
  final String dietitianId;
  final String dietitianName;
  final bool emailVerified;
  final bool phoneVerified;
  final String? emailMasked;
  final String? phoneMasked;

  /// Hasta rızasını verdi mi.
  final bool patientApproved;

  /// Diyetisyen isteği kabul etti mi.
  final bool dietitianAccepted;

  /// Hangi tarafın onayı bekleniyor: 'both', 'patient', 'dietitian' veya null.
  final String? awaiting;

  const DietitianAssignmentInfo({
    required this.assignmentId,
    required this.status,
    required this.dietitianId,
    required this.dietitianName,
    required this.emailVerified,
    required this.phoneVerified,
    this.emailMasked,
    this.phoneMasked,
    this.patientApproved = false,
    this.dietitianAccepted = false,
    this.awaiting,
  });

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get awaitingDietitian => awaiting == 'dietitian';
  bool get awaitingPatient => awaiting == 'patient' || awaiting == 'both';
  bool get hasVerifiedContact => emailVerified || phoneVerified;

  factory DietitianAssignmentInfo.fromJson(Map<String, dynamic> json) =>
      DietitianAssignmentInfo(
        assignmentId: json['assignment_id'] as String? ?? '',
        status: json['status'] as String? ?? '',
        dietitianId: json['dietitian_id'] as String? ?? '',
        dietitianName: json['dietitian_name'] as String? ?? '',
        emailVerified: json['email_verified'] as bool? ?? false,
        phoneVerified: json['phone_verified'] as bool? ?? false,
        emailMasked: json['email_masked'] as String?,
        phoneMasked: json['phone_masked'] as String?,
        patientApproved: json['patient_approved'] as bool? ?? false,
        dietitianAccepted: json['dietitian_accepted'] as bool? ?? false,
        awaiting: json['awaiting'] as String?,
      );
}
