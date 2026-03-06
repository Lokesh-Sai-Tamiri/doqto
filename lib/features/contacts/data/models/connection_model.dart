/// ============================================================================
/// CONNECTION MODEL - HIPAA Compliant
/// ============================================================================
/// 
/// Represents a connection/relationship between two healthcare professionals.
/// Designed with HIPAA compliance in mind:
/// - Minimum necessary data principle
/// - Audit trail support (timestamps)
/// - Soft delete capability
/// ============================================================================
library;

enum ConnectionStatus {
  pending,
  accepted,
  rejected,
  blocked,
}

/// Model for a connection between two users
class ConnectionModel {
  final String id;
  final String requesterId;
  final String recipientId;
  final ConnectionStatus status;
  final String? requestMessage;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? deletedAt;
  final String? deletedBy;

  const ConnectionModel({
    required this.id,
    required this.requesterId,
    required this.recipientId,
    required this.status,
    this.requestMessage,
    required this.createdAt,
    this.acceptedAt,
    this.deletedAt,
    this.deletedBy,
  });

  factory ConnectionModel.fromJson(Map<String, dynamic> json) {
    return ConnectionModel(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      recipientId: json['recipient_id'] as String,
      status: _parseStatus(json['status'] as String?),
      requestMessage: json['request_message'] as String?,
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      acceptedAt: _parseDateTime(json['accepted_at']),
      deletedAt: _parseDateTime(json['deleted_at']),
      deletedBy: json['deleted_by'] as String?,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requester_id': requesterId,
      'recipient_id': recipientId,
      'status': status.name,
      'request_message': requestMessage,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'deleted_by': deletedBy,
    };
  }

  static ConnectionStatus _parseStatus(String? status) {
    switch (status) {
      case 'pending':
        return ConnectionStatus.pending;
      case 'accepted':
        return ConnectionStatus.accepted;
      case 'rejected':
        return ConnectionStatus.rejected;
      case 'blocked':
        return ConnectionStatus.blocked;
      default:
        return ConnectionStatus.pending;
    }
  }

  bool get isPending => status == ConnectionStatus.pending;
  bool get isAccepted => status == ConnectionStatus.accepted;
  bool get isRejected => status == ConnectionStatus.rejected;
  bool get isBlocked => status == ConnectionStatus.blocked;
}

/// Model for a contact in the user's network (with profile info)
/// Supports both Supabase view format and API response format
class NetworkContactModel {
  final String connectionId;
  final String contactUserId;
  final ConnectionStatus status;
  final DateTime connectedSince;

  // Profile information
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? specialization;
  final String? clinicName;
  final String? avatarUrl;
  final String? city;
  final String? state;

  const NetworkContactModel({
    required this.connectionId,
    required this.contactUserId,
    required this.status,
    required this.connectedSince,
    this.firstName,
    this.lastName,
    this.displayName,
    this.specialization,
    this.clinicName,
    this.avatarUrl,
    this.city,
    this.state,
  });

  factory NetworkContactModel.fromJson(Map<String, dynamic> json) {
    // Support both Supabase view format and API format
    final isApiFormat = json.containsKey('user_id') && json.containsKey('connected_at');

    if (isApiFormat) {
      return NetworkContactModel(
        connectionId: json['connection_id'] as String,
        contactUserId: json['user_id'] as String,
        status: ConnectionStatus.accepted,
        connectedSince: ConnectionModel._parseDateTime(json['connected_at']) ?? DateTime.now(),
        firstName: json['first_name'] as String?,
        lastName: json['last_name'] as String?,
        displayName: json['display_name'] as String?,
        specialization: json['specialization'] as String?,
        clinicName: json['clinic_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        city: null,
        state: null,
      );
    }

    return NetworkContactModel(
      connectionId: json['connection_id'] as String,
      contactUserId: json['contact_user_id'] as String,
      status: ConnectionModel._parseStatus(json['status'] as String?),
      connectedSince: ConnectionModel._parseDateTime(json['connected_since']) ?? DateTime.now(),
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      displayName: json['display_name'] as String?,
      specialization: json['specialization'] as String?,
      clinicName: json['clinic_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
    );
  }

  /// Get display name with fallback
  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (displayName != null) {
      return displayName!;
    } else if (firstName != null) {
      return firstName!;
    }
    return 'Unknown';
  }

  /// Get initials for avatar
  String get initials {
    if (firstName != null && lastName != null) {
      return '${firstName![0]}${lastName![0]}'.toUpperCase();
    } else if (displayName != null && displayName!.isNotEmpty) {
      final parts = displayName!.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName![0].toUpperCase();
    }
    return '?';
  }

  /// Get location string
  String? get location {
    if (city != null && state != null) {
      return '$city, $state';
    } else if (city != null) {
      return city;
    } else if (state != null) {
      return state;
    }
    return null;
  }
}

/// Model for a pending connection request
/// Supports both Supabase view format and API response format
class PendingRequestModel {
  final String connectionId;
  final String requesterId;
  final String? requestMessage;
  final DateTime createdAt;

  // Requester's profile information
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? specialization;
  final String? clinicName;
  final String? avatarUrl;
  final String? city;
  final String? state;

  const PendingRequestModel({
    required this.connectionId,
    required this.requesterId,
    this.requestMessage,
    required this.createdAt,
    this.firstName,
    this.lastName,
    this.displayName,
    this.specialization,
    this.clinicName,
    this.avatarUrl,
    this.city,
    this.state,
  });

  factory PendingRequestModel.fromJson(Map<String, dynamic> json) {
    return PendingRequestModel(
      connectionId: json['connection_id'] as String,
      requesterId: json['requester_id'] as String,
      requestMessage: json['request_message'] as String?,
      createdAt: ConnectionModel._parseDateTime(json['created_at']) ?? DateTime.now(),
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      displayName: json['display_name'] as String?,
      specialization: json['specialization'] as String?,
      clinicName: json['clinic_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
    );
  }

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (displayName != null) {
      return displayName!;
    }
    return 'Unknown';
  }

  String get initials {
    if (firstName != null && lastName != null) {
      return '${firstName![0]}${lastName![0]}'.toUpperCase();
    } else if (displayName != null && displayName!.isNotEmpty) {
      return displayName![0].toUpperCase();
    }
    return '?';
  }
}

/// Model for suggested connections (doctors not yet connected)
/// Supports both Supabase view format and API response format
class SuggestedContactModel {
  final String userId;
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? specialization;
  final String? clinicName;
  final String? avatarUrl;
  final String? city;
  final String? state;
  final bool profileCompleted;
  final int mutualConnections;
  final ConnectionStatus? requestStatus;
  final bool requestSentByMe;

  const SuggestedContactModel({
    required this.userId,
    this.firstName,
    this.lastName,
    this.displayName,
    this.specialization,
    this.clinicName,
    this.avatarUrl,
    this.city,
    this.state,
    this.profileCompleted = false,
    this.mutualConnections = 0,
    this.requestStatus,
    this.requestSentByMe = false,
  });

  factory SuggestedContactModel.fromJson(Map<String, dynamic> json) {
    return SuggestedContactModel(
      userId: json['user_id'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      displayName: json['display_name'] as String?,
      specialization: json['specialization'] as String?,
      clinicName: json['clinic_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      profileCompleted: json['profile_completed'] as bool? ?? false,
      mutualConnections: json['mutual_connections'] as int? ?? 0,
      requestStatus: json['request_status'] != null
          ? ConnectionModel._parseStatus(json['request_status'] as String?)
          : null,
      requestSentByMe: json['request_sent_by_me'] as bool? ?? false,
    );
  }

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (displayName != null) {
      return displayName!;
    }
    return 'Unknown';
  }

  String get initials {
    if (firstName != null && lastName != null) {
      return '${firstName![0]}${lastName![0]}'.toUpperCase();
    } else if (displayName != null && displayName!.isNotEmpty) {
      final parts = displayName!.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName![0].toUpperCase();
    }
    return '?';
  }

  String? get location {
    if (city != null && state != null) {
      return '$city, $state';
    } else if (city != null) {
      return city;
    }
    return null;
  }
}
