class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final bool isActive;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        fullName: json['full_name'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? false,
      );
}

class DietitianAssignmentInfo {
  final String assignmentId;
  final String status;
  final String dietitianId;
  final String dietitianName;
  final bool emailVerified;
  final bool phoneVerified;

  const DietitianAssignmentInfo({
    required this.assignmentId,
    required this.status,
    required this.dietitianId,
    required this.dietitianName,
    required this.emailVerified,
    required this.phoneVerified,
  });

  bool get isApproved => status == 'approved';
  bool get hasVerifiedContact => emailVerified || phoneVerified;

  factory DietitianAssignmentInfo.fromJson(Map<String, dynamic> json) =>
      DietitianAssignmentInfo(
        assignmentId: json['assignment_id'] as String? ?? '',
        status: json['status'] as String? ?? '',
        dietitianId: json['dietitian_id'] as String? ?? '',
        dietitianName: json['dietitian_name'] as String? ?? '',
        emailVerified: json['email_verified'] as bool? ?? false,
        phoneVerified: json['phone_verified'] as bool? ?? false,
      );
}
