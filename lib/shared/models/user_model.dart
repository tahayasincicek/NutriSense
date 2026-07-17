// =============================================================================
// lib/shared/models/user_model.dart
// NutriSense — Kullanıcı Veri Modeli
// =============================================================================

import 'package:equatable/equatable.dart';

/// Kullanıcı rolleri
enum UserRole { patient, dietitian, admin }

/// Kullanıcı modeli
class UserModel extends Equatable {
  final int id;
  final String email;
  final String fullName;
  final String? phone;
  final UserRole role;
  final bool isActive;
  final bool emailVerified;
  final UserPreferences? preferences;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    this.isActive = true,
    this.emailVerified = false,
    this.preferences,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['user_id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.patient,
      ),
      isActive: json['is_active'] as bool? ?? true,
      emailVerified: json['email_verified'] as bool? ?? false,
      preferences: json['preferences'] != null
          ? UserPreferences.fromJson(json['preferences'])
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': id,
        'email': email,
        'full_name': fullName,
        'phone': phone,
        'role': role.name,
        'is_active': isActive,
        'email_verified': emailVerified,
        'preferences': preferences?.toJson(),
        'created_at': createdAt.toIso8601String(),
      };

  UserModel copyWith({
    String? fullName,
    String? phone,
    UserPreferences? preferences,
  }) {
    return UserModel(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role,
      isActive: isActive,
      emailVerified: emailVerified,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, email, fullName, phone, role, isActive, emailVerified];
}

/// Kullanıcı erişilebilirlik tercihleri
class UserPreferences extends Equatable {
  final double ttsSpeed;
  final String ttsLanguage;
  final bool highContrast;
  final String fontSize;
  final bool hapticFeedback;

  const UserPreferences({
    this.ttsSpeed = 0.5,
    this.ttsLanguage = 'tr-TR',
    this.highContrast = false,
    this.fontSize = 'large',
    this.hapticFeedback = true,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      ttsSpeed: (json['tts_speed'] as num?)?.toDouble() ?? 0.5,
      ttsLanguage: json['tts_language'] as String? ?? 'tr-TR',
      highContrast: json['high_contrast'] as bool? ?? false,
      fontSize: json['font_size'] as String? ?? 'large',
      hapticFeedback: json['haptic_feedback'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'tts_speed': ttsSpeed,
        'tts_language': ttsLanguage,
        'high_contrast': highContrast,
        'font_size': fontSize,
        'haptic_feedback': hapticFeedback,
      };

  UserPreferences copyWith({
    double? ttsSpeed,
    String? ttsLanguage,
    bool? highContrast,
    String? fontSize,
    bool? hapticFeedback,
  }) {
    return UserPreferences(
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
      highContrast: highContrast ?? this.highContrast,
      fontSize: fontSize ?? this.fontSize,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
    );
  }

  @override
  List<Object?> get props =>
      [ttsSpeed, ttsLanguage, highContrast, fontSize, hapticFeedback];
}
