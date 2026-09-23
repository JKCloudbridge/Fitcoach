/// Hand-written models with fromMap/toMap -- no codegen (freezed/json_serializable
/// aren't in the dependency set), same convention as both sibling apps'
/// hand-written Riverpod/repository layer.
class TrainerProfile {
  const TrainerProfile({
    required this.id,
    this.displayName,
    this.bio,
    this.certifications = const [],
    this.isVerified = false,
    this.avatarUrl,
  });

  final String id;
  final String? displayName;
  final String? bio;
  final List<String> certifications;
  final bool isVerified;
  final String? avatarUrl;

  factory TrainerProfile.fromMap(Map<String, dynamic> map) {
    return TrainerProfile(
      id: map['id'] as String,
      displayName: map['display_name'] as String?,
      bio: map['bio'] as String?,
      certifications: (map['certifications'] as List<dynamic>?)?.cast<String>() ?? const [],
      isVerified: map['is_verified'] as bool? ?? false,
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}

class ClientProfile {
  const ClientProfile({
    required this.id,
    this.displayName,
    this.dateOfBirth,
    this.heightCm,
    this.weightKg,
    this.goals = const [],
    this.avatarUrl,
  });

  final String id;
  final String? displayName;
  final DateTime? dateOfBirth;
  final num? heightCm;
  final num? weightKg;
  final List<String> goals;
  final String? avatarUrl;

  factory ClientProfile.fromMap(Map<String, dynamic> map) {
    return ClientProfile(
      id: map['id'] as String,
      displayName: map['display_name'] as String?,
      dateOfBirth: map['date_of_birth'] != null ? DateTime.parse(map['date_of_birth'] as String) : null,
      heightCm: map['height_cm'] as num?,
      weightKg: map['weight_kg'] as num?,
      goals: (map['goals'] as List<dynamic>?)?.cast<String>() ?? const [],
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}

/// Splits a comma-separated field (certifications, goals) into a trimmed,
/// non-empty list -- shared by both profile edit screens' text[] fields.
List<String> parseCommaSeparated(String input) {
  return input.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}
