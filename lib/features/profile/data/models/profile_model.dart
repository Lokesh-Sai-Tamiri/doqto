/// ============================================================================
/// PROFILE MODEL
/// ============================================================================
library;

class ProfileModel {
  final String id;
  final String? userId; // Supabase user_id (for API backend)
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? email;
  final String? phone;
  final String? doctorId;
  final String? specialization;
  final String? clinicName;
  final int? yearsOfExperience;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? avatarUrl;
  final String? bio;
  final bool profileCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProfileModel({
    required this.id,
    this.userId,
    this.firstName,
    this.lastName,
    this.displayName,
    this.email,
    this.phone,
    this.doctorId,
    this.specialization,
    this.clinicName,
    this.yearsOfExperience,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.avatarUrl,
    this.bio,
    this.profileCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  // From JSON - handles both flat (Supabase) and nested (API) address formats
  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    // Handle nested address object from API backend
    final address = json['address'] as Map<String, dynamic>?;

    return ProfileModel(
      id: json['id'] as String? ?? json['user_id'] as String,
      userId: json['user_id'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      doctorId: json['doctor_id'] as String?,
      specialization: json['specialization'] as String?,
      clinicName: json['clinic_name'] as String?,
      yearsOfExperience: json['years_of_experience'] as int?,
      // Support both flat and nested address formats
      addressLine1: address?['line1'] as String? ?? json['address_line1'] as String?,
      addressLine2: address?['line2'] as String? ?? json['address_line2'] as String?,
      city: address?['city'] as String? ?? json['city'] as String?,
      state: address?['state'] as String? ?? json['state'] as String?,
      postalCode: address?['postal_code'] as String? ?? json['postal_code'] as String?,
      country: address?['country'] as String? ?? json['country'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      profileCompleted: json['profile_completed'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  // To JSON for API backend (nested address format)
  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'display_name': displayName,
      'email': email,
      'phone': phone,
      'doctor_id': doctorId,
      'specialization': specialization,
      'clinic_name': clinicName,
      'years_of_experience': yearsOfExperience,
      'address': {
        'line1': addressLine1,
        'line2': addressLine2,
        'city': city,
        'state': state,
        'postal_code': postalCode,
        'country': country,
      },
      'avatar_url': avatarUrl,
      'bio': bio,
      'profile_completed': profileCompleted,
    };
  }

  // To JSON for legacy Supabase format (flat address)
  Map<String, dynamic> toJsonFlat() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'display_name': displayName,
      'email': email,
      'phone': phone,
      'doctor_id': doctorId,
      'specialization': specialization,
      'clinic_name': clinicName,
      'years_of_experience': yearsOfExperience,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'country': country,
      'avatar_url': avatarUrl,
      'bio': bio,
      'profile_completed': profileCompleted,
    };
  }

  // Get full name
  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (displayName != null) {
      return displayName!;
    } else if (firstName != null) {
      return firstName!;
    }
    return 'User';
  }

  // Get full address
  String get fullAddress {
    final parts = <String>[];
    if (addressLine1 != null) parts.add(addressLine1!);
    if (addressLine2 != null) parts.add(addressLine2!);
    if (city != null) parts.add(city!);
    if (state != null) parts.add(state!);
    if (postalCode != null) parts.add(postalCode!);
    return parts.join(', ');
  }

  // Copy with
  ProfileModel copyWith({
    String? id,
    String? userId,
    String? firstName,
    String? lastName,
    String? displayName,
    String? email,
    String? phone,
    String? doctorId,
    String? specialization,
    String? clinicName,
    int? yearsOfExperience,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? avatarUrl,
    String? bio,
    bool? profileCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      doctorId: doctorId ?? this.doctorId,
      specialization: specialization ?? this.specialization,
      clinicName: clinicName ?? this.clinicName,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
