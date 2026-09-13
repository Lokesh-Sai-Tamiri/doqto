import '../../core/enums/app_enums.dart';

class User {
  final String id;
  final String phone;
  final String? email;
  final String fullName;
  final String? specialty;
  final String npiNumber;
  final UserRole role;
  final String? avatarColor;
  final String? avatarUrl;
  final String? avatarPresignedUrl;
  final String? bio;
  final String? city;
  final String? state;
  final int? yearsOfExperience;
  final List<String> skills;
  final DateTime? lastSeenAt;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.phone,
    required this.email,
    required this.fullName,
    required this.specialty,
    required this.npiNumber,
    required this.role,
    required this.avatarColor,
    required this.avatarUrl,
    required this.avatarPresignedUrl,
    required this.bio,
    required this.city,
    required this.state,
    required this.yearsOfExperience,
    required this.skills,
    required this.lastSeenAt,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as String,
        // Absent for accounts created by social sign-in until they add one.
        phone: (j['phone'] ?? '') as String,
        email: j['email'] as String?,
        fullName: (j['full_name'] ?? '') as String,
        specialty: j['specialty'] as String?,
        npiNumber: (j['npi_number'] ?? '') as String,
        role: UserRole.fromWire(j['role'] as String),
        avatarColor: j['avatar_color'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        avatarPresignedUrl: j['avatar_presigned_url'] as String?,
        bio: j['bio'] as String?,
        city: j['city'] as String?,
        state: j['state'] as String?,
        yearsOfExperience: j['years_of_experience'] as int?,
        skills: ((j['skills'] as List?) ?? const []).cast<String>(),
        lastSeenAt: j['last_seen_at'] != null ? DateTime.parse(j['last_seen_at'] as String) : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  String? get locationLabel {
    final parts = [city, state].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }
}
