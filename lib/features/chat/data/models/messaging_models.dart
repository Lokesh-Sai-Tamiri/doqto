/// ============================================================================
/// MESSAGING MODELS - HIPAA Compliant
/// ============================================================================
library;

/// Conversation type enum
enum ConversationType {
  direct,
  group,
}

/// Message type enum
enum MessageType {
  text,
  audio,
  image,
  document,
  system,
}

/// Message status enum
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

/// System event types for group messages
enum SystemEventType {
  groupCreated,
  memberAdded,
  memberRemoved,
  memberLeft,
  adminAdded,
  adminRemoved,
  groupInfoUpdated,
  groupIconUpdated,
  disappearingChanged,
}

/// Report reason enum
enum ReportReason {
  spam,
  harassment,
  inappropriateContent,
  impersonation,
  privacyViolation,
  other,
}

/// Helper function to safely parse DateTime from various formats
DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Group settings model
class GroupSettings {
  final bool onlyAdminsCanSend;
  final bool onlyAdminsCanEditInfo;
  final bool allowMemberInvites;

  const GroupSettings({
    this.onlyAdminsCanSend = false,
    this.onlyAdminsCanEditInfo = true,
    this.allowMemberInvites = false,
  });

  factory GroupSettings.fromJson(Map<String, dynamic> json) {
    return GroupSettings(
      onlyAdminsCanSend: json['only_admins_can_send'] as bool? ?? false,
      onlyAdminsCanEditInfo: json['only_admins_can_edit_info'] as bool? ?? true,
      allowMemberInvites: json['allow_member_invites'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'only_admins_can_send': onlyAdminsCanSend,
        'only_admins_can_edit_info': onlyAdminsCanEditInfo,
        'allow_member_invites': allowMemberInvites,
      };

  GroupSettings copyWith({
    bool? onlyAdminsCanSend,
    bool? onlyAdminsCanEditInfo,
    bool? allowMemberInvites,
  }) {
    return GroupSettings(
      onlyAdminsCanSend: onlyAdminsCanSend ?? this.onlyAdminsCanSend,
      onlyAdminsCanEditInfo: onlyAdminsCanEditInfo ?? this.onlyAdminsCanEditInfo,
      allowMemberInvites: allowMemberInvites ?? this.allowMemberInvites,
    );
  }
}

/// Group info model
class GroupInfo {
  final String name;
  final String? iconUrl;
  final String? description;
  final String createdBy;
  final List<String> admins;
  final GroupSettings settings;

  const GroupInfo({
    required this.name,
    this.iconUrl,
    this.description,
    required this.createdBy,
    this.admins = const [],
    this.settings = const GroupSettings(),
  });

  factory GroupInfo.fromJson(Map<String, dynamic> json) {
    return GroupInfo(
      name: json['name'] as String? ?? 'Group',
      iconUrl: json['icon_url'] as String?,
      description: json['description'] as String?,
      createdBy: json['created_by'] as String? ?? '',
      admins: (json['admins'] as List<dynamic>?)?.cast<String>() ?? [],
      settings: json['settings'] != null
          ? GroupSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : const GroupSettings(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'icon_url': iconUrl,
        'description': description,
        'created_by': createdBy,
        'admins': admins,
        'settings': settings.toJson(),
      };

  bool isAdmin(String userId) => admins.contains(userId);

  GroupInfo copyWith({
    String? name,
    String? iconUrl,
    String? description,
    String? createdBy,
    List<String>? admins,
    GroupSettings? settings,
  }) {
    return GroupInfo(
      name: name ?? this.name,
      iconUrl: iconUrl ?? this.iconUrl,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      admins: admins ?? this.admins,
      settings: settings ?? this.settings,
    );
  }
}

/// Participant info for group members
class ParticipantInfo {
  final String userId;
  final String? displayName;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final bool isAdmin;

  const ParticipantInfo({
    required this.userId,
    this.displayName,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.isAdmin = false,
  });

  factory ParticipantInfo.fromJson(Map<String, dynamic> json) {
    return ParticipantInfo(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
    );
  }

  String get name {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (displayName != null) {
      return displayName!;
    } else if (firstName != null) {
      return firstName!;
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
}

/// System event data for group messages
class SystemEventData {
  final SystemEventType eventType;
  final String actorId;
  final List<String> targetIds;
  final String? oldValue;
  final String? newValue;

  const SystemEventData({
    required this.eventType,
    required this.actorId,
    this.targetIds = const [],
    this.oldValue,
    this.newValue,
  });

  factory SystemEventData.fromJson(Map<String, dynamic> json) {
    return SystemEventData(
      eventType: _parseSystemEventType(json['event_type'] as String?),
      actorId: json['actor_id'] as String? ?? '',
      targetIds: (json['target_ids'] as List<dynamic>?)?.cast<String>() ?? [],
      oldValue: json['old_value'] as String?,
      newValue: json['new_value'] as String?,
    );
  }

  static SystemEventType _parseSystemEventType(String? type) {
    switch (type) {
      case 'group_created':
        return SystemEventType.groupCreated;
      case 'member_added':
        return SystemEventType.memberAdded;
      case 'member_removed':
        return SystemEventType.memberRemoved;
      case 'member_left':
        return SystemEventType.memberLeft;
      case 'admin_added':
        return SystemEventType.adminAdded;
      case 'admin_removed':
        return SystemEventType.adminRemoved;
      case 'group_info_updated':
        return SystemEventType.groupInfoUpdated;
      case 'group_icon_updated':
        return SystemEventType.groupIconUpdated;
      case 'disappearing_changed':
        return SystemEventType.disappearingChanged;
      default:
        return SystemEventType.groupInfoUpdated;
    }
  }
}

/// Messaging preferences model
class MessagingPreferencesModel {
  final String userId;
  final String whoCanMessage; // 'everyone', 'connections', 'organization', 'none'
  final bool readReceiptsEnabled;
  final bool showTypingIndicator;
  final bool showOnlineStatus;
  final bool allowAudioSave; // Snapchat-style: others can save your audio
  final int? defaultDisappearingHours;
  final bool messageNotifications;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MessagingPreferencesModel({
    required this.userId,
    this.whoCanMessage = 'connections',
    this.readReceiptsEnabled = true,
    this.showTypingIndicator = true,
    this.showOnlineStatus = true,
    this.allowAudioSave = false,
    this.defaultDisappearingHours = 24,
    this.messageNotifications = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MessagingPreferencesModel.fromJson(Map<String, dynamic> json) {
    return MessagingPreferencesModel(
      userId: json['user_id'] as String,
      whoCanMessage: json['who_can_message'] as String? ?? 'connections',
      readReceiptsEnabled: json['read_receipts_enabled'] as bool? ?? true,
      showTypingIndicator: json['show_typing_indicator'] as bool? ?? true,
      showOnlineStatus: json['show_online_status'] as bool? ?? true,
      allowAudioSave: json['allow_audio_save'] as bool? ?? false,
      defaultDisappearingHours: json['default_disappearing_hours'] as int?,
      messageNotifications: json['message_notifications'] as bool? ?? true,
      soundEnabled: json['sound_enabled'] as bool? ?? true,
      vibrationEnabled: json['vibration_enabled'] as bool? ?? true,
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'who_can_message': whoCanMessage,
      'read_receipts_enabled': readReceiptsEnabled,
      'show_typing_indicator': showTypingIndicator,
      'show_online_status': showOnlineStatus,
      'allow_audio_save': allowAudioSave,
      'default_disappearing_hours': defaultDisappearingHours,
      'message_notifications': messageNotifications,
      'sound_enabled': soundEnabled,
      'vibration_enabled': vibrationEnabled,
    };
  }

  MessagingPreferencesModel copyWith({
    String? whoCanMessage,
    bool? readReceiptsEnabled,
    bool? showTypingIndicator,
    bool? showOnlineStatus,
    bool? allowAudioSave,
    int? defaultDisappearingHours,
    bool? messageNotifications,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return MessagingPreferencesModel(
      userId: userId,
      whoCanMessage: whoCanMessage ?? this.whoCanMessage,
      readReceiptsEnabled: readReceiptsEnabled ?? this.readReceiptsEnabled,
      showTypingIndicator: showTypingIndicator ?? this.showTypingIndicator,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      allowAudioSave: allowAudioSave ?? this.allowAudioSave,
      defaultDisappearingHours: defaultDisappearingHours ?? this.defaultDisappearingHours,
      messageNotifications: messageNotifications ?? this.messageNotifications,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Conversation model (supports both Supabase view and API response formats)
class ConversationModel {
  final String conversationId;
  final ConversationType type;
  final String? lastMessageText;
  final MessageType lastMessageType;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final String? blockedBy;
  final int? disappearingHours;
  final DateTime createdAt;

  // Other user info (for direct conversations)
  final String otherUserId;
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? avatarUrl;
  final String? specialization;

  // Group info (for group conversations)
  final GroupInfo? groupInfo;
  final List<ParticipantInfo> memberProfiles;

  // My settings
  final int unreadCount;
  final bool isMuted;
  final bool isArchived;
  final bool isPinned;

  // Other user's audio save preference
  final bool otherAllowsAudioSave;

  // Block status from API (for direct conversations)
  final bool isBlockedByMe;
  final bool isBlockedByOther;

  const ConversationModel({
    required this.conversationId,
    this.type = ConversationType.direct,
    this.lastMessageText,
    this.lastMessageType = MessageType.text,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.blockedBy,
    this.disappearingHours,
    required this.createdAt,
    this.otherUserId = '',
    this.firstName,
    this.lastName,
    this.displayName,
    this.avatarUrl,
    this.specialization,
    this.groupInfo,
    this.memberProfiles = const [],
    this.unreadCount = 0,
    this.isMuted = false,
    this.isArchived = false,
    this.isPinned = false,
    this.otherAllowsAudioSave = false,
    this.isBlockedByMe = false,
    this.isBlockedByOther = false,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    // Support both Supabase view format and API format
    final isApiFormat = json.containsKey('id') && json.containsKey('participants');

    if (isApiFormat) {
      return ConversationModel._fromApiJson(json);
    }

    return ConversationModel._fromSupabaseJson(json);
  }

  // Parse from Supabase my_conversations view format
  factory ConversationModel._fromSupabaseJson(Map<String, dynamic> json) {
    return ConversationModel(
      conversationId: json['conversation_id'] as String,
      type: _parseConversationType(json['type'] as String?),
      lastMessageText: json['last_message_text'] as String?,
      lastMessageType: _parseMessageType(json['last_message_type'] as String?),
      lastMessageAt: _parseDateTime(json['last_message_at']),
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      blockedBy: json['blocked_by'] as String?,
      disappearingHours: json['disappearing_hours'] as int?,
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      otherUserId: json['other_user_id'] as String? ?? '',
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      specialization: json['specialization'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
      isMuted: json['is_muted'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      otherAllowsAudioSave: json['other_allows_audio_save'] as bool? ?? false,
    );
  }

  // Parse from API backend format
  factory ConversationModel._fromApiJson(Map<String, dynamic> json) {
    // Extract last message info
    final lastMessage = json['last_message'] as Map<String, dynamic>?;

    // Extract other user info (for direct)
    final otherUser = json['other_user'] as Map<String, dynamic>?;

    // Extract group info (for group)
    final groupInfoJson = json['group_info'] as Map<String, dynamic>?;
    final groupInfo = groupInfoJson != null ? GroupInfo.fromJson(groupInfoJson) : null;

    // Extract member profiles (for group)
    final memberProfilesJson = json['member_profiles'] as List<dynamic>?;
    final memberProfiles = memberProfilesJson
            ?.map((p) => ParticipantInfo.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    final convType = _parseConversationType(json['type'] as String?);

    return ConversationModel(
      conversationId: json['id'] as String,
      type: convType,
      lastMessageText: lastMessage?['text'] as String?,
      lastMessageType: _parseMessageType(lastMessage?['type'] as String?),
      lastMessageAt: _parseDateTime(lastMessage?['at']),
      lastMessageSenderId: lastMessage?['sender_id'] as String?,
      blockedBy: null, // Handled by isBlockedByMe/isBlockedByOther
      disappearingHours: null, // Stored in settings
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      otherUserId: otherUser?['user_id'] as String? ?? '',
      firstName: otherUser?['first_name'] as String?,
      lastName: otherUser?['last_name'] as String?,
      displayName: otherUser?['display_name'] as String?,
      avatarUrl: otherUser?['avatar_url'] as String?,
      specialization: otherUser?['specialization'] as String?,
      groupInfo: groupInfo,
      memberProfiles: memberProfiles,
      unreadCount: json['unread_count'] as int? ?? 0,
      isMuted: false, // Extract from settings if needed
      isArchived: false,
      isPinned: false,
      otherAllowsAudioSave: false,
      isBlockedByMe: json['is_blocked'] as bool? ?? false,
      isBlockedByOther: json['blocked_by_other'] as bool? ?? false,
    );
  }

  /// Whether this is a group conversation
  bool get isGroup => type == ConversationType.group;

  /// Whether this is a direct conversation
  bool get isDirect => type == ConversationType.direct;

  /// Get the display name for this conversation
  String get conversationDisplayName {
    if (isGroup && groupInfo != null) {
      return groupInfo!.name;
    }
    return otherUserName;
  }

  /// Get display initials for this conversation
  String get displayInitials {
    if (isGroup && groupInfo != null) {
      final name = groupInfo!.name;
      final parts = name.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name.isNotEmpty ? name[0].toUpperCase() : 'G';
    }
    return initials;
  }

  /// Get the group icon URL or user avatar URL
  String? get displayAvatarUrl {
    if (isGroup && groupInfo != null) {
      return groupInfo!.iconUrl;
    }
    return avatarUrl;
  }

  /// Get member count for groups
  int get memberCount => memberProfiles.length;

  /// Check if a user is admin in this group
  bool isUserAdmin(String userId) {
    if (!isGroup || groupInfo == null) return false;
    return groupInfo!.isAdmin(userId);
  }

  /// Find a member profile by user ID
  ParticipantInfo? getMemberProfile(String userId) {
    try {
      return memberProfiles.firstWhere((m) => m.userId == userId);
    } catch (_) {
      return null;
    }
  }

  String get otherUserName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (displayName != null) {
      return displayName!;
    } else if (firstName != null) {
      return firstName!;
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

  bool get isBlocked => blockedBy != null || isBlockedByMe || isBlockedByOther;

  static ConversationType _parseConversationType(String? type) {
    switch (type) {
      case 'group':
        return ConversationType.group;
      default:
        return ConversationType.direct;
    }
  }

  static MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'audio':
        return MessageType.audio;
      case 'image':
        return MessageType.image;
      case 'document':
        return MessageType.document;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }

  ConversationModel copyWith({
    String? conversationId,
    ConversationType? type,
    String? lastMessageText,
    MessageType? lastMessageType,
    DateTime? lastMessageAt,
    String? lastMessageSenderId,
    String? blockedBy,
    int? disappearingHours,
    DateTime? createdAt,
    String? otherUserId,
    String? firstName,
    String? lastName,
    String? displayName,
    String? avatarUrl,
    String? specialization,
    GroupInfo? groupInfo,
    List<ParticipantInfo>? memberProfiles,
    int? unreadCount,
    bool? isMuted,
    bool? isArchived,
    bool? isPinned,
    bool? otherAllowsAudioSave,
    bool? isBlockedByMe,
    bool? isBlockedByOther,
  }) {
    return ConversationModel(
      conversationId: conversationId ?? this.conversationId,
      type: type ?? this.type,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      blockedBy: blockedBy ?? this.blockedBy,
      disappearingHours: disappearingHours ?? this.disappearingHours,
      createdAt: createdAt ?? this.createdAt,
      otherUserId: otherUserId ?? this.otherUserId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      specialization: specialization ?? this.specialization,
      groupInfo: groupInfo ?? this.groupInfo,
      memberProfiles: memberProfiles ?? this.memberProfiles,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
      otherAllowsAudioSave: otherAllowsAudioSave ?? this.otherAllowsAudioSave,
      isBlockedByMe: isBlockedByMe ?? this.isBlockedByMe,
      isBlockedByOther: isBlockedByOther ?? this.isBlockedByOther,
    );
  }
}

/// Message model
class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final MessageType messageType;
  final String? content;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? fileMimeType;
  final int? audioDurationSeconds;
  final Map<String, dynamic>? audioWaveform;
  final String? savedBy;
  final DateTime? savedAt;
  final MessageStatus status;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? disappearsAt;
  final DateTime? viewedAt;
  final String? replyToId;
  final List<String> mentions;
  final SystemEventData? systemEvent;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.messageType = MessageType.text,
    this.content,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.fileMimeType,
    this.audioDurationSeconds,
    this.audioWaveform,
    this.savedBy,
    this.savedAt,
    this.status = MessageStatus.sent,
    this.deliveredAt,
    this.readAt,
    this.disappearsAt,
    this.viewedAt,
    this.replyToId,
    this.mentions = const [],
    this.systemEvent,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    // Support both Supabase and API backend formats
    final fileInfo = json['file'] as Map<String, dynamic>?;
    final audioInfo = json['audio'] as Map<String, dynamic>?;
    final systemEventJson = json['system_event'] as Map<String, dynamic>?;

    final createdAt = _parseDateTime(json['created_at']) ?? DateTime.now();

    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      messageType: ConversationModel._parseMessageType(json['message_type'] as String?),
      content: json['content'] as String?,
      // Support both flat and nested file formats
      fileUrl: fileInfo?['url'] as String? ?? json['file_url'] as String?,
      fileName: fileInfo?['name'] as String? ?? json['file_name'] as String?,
      fileSize: fileInfo?['size'] as int? ?? json['file_size'] as int?,
      fileMimeType: fileInfo?['mime_type'] as String? ?? json['file_mime_type'] as String?,
      // Support both flat and nested audio formats
      audioDurationSeconds: audioInfo?['duration_seconds'] as int? ?? json['audio_duration_seconds'] as int?,
      audioWaveform: audioInfo?['waveform'] != null
          ? {'data': audioInfo!['waveform']}
          : json['audio_waveform'] as Map<String, dynamic>?,
      savedBy: json['saved_by'] as String?,
      savedAt: _parseDateTime(json['saved_at']),
      status: _parseStatus(json['status'] as String?),
      deliveredAt: _parseDateTime(json['delivered_at']),
      readAt: _parseDateTime(json['read_at']),
      disappearsAt: _parseDateTime(json['disappears_at']),
      viewedAt: _parseDateTime(json['viewed_at']),
      replyToId: json['reply_to_id'] as String?,
      mentions: (json['mentions'] as List<dynamic>?)?.cast<String>() ?? [],
      systemEvent: systemEventJson != null ? SystemEventData.fromJson(systemEventJson) : null,
      createdAt: createdAt,
      updatedAt: _parseDateTime(json['updated_at']) ?? createdAt,
    );
  }

  static MessageStatus _parseStatus(String? status) {
    switch (status) {
      case 'sending':
        return MessageStatus.sending;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  bool get isAudio => messageType == MessageType.audio;
  bool get isImage => messageType == MessageType.image;
  bool get isDocument => messageType == MessageType.document;
  bool get isText => messageType == MessageType.text;
  bool get isSystem => messageType == MessageType.system;
  bool get isSaved => savedBy != null;
  bool get willDisappear => disappearsAt != null;
  bool get hasMentions => mentions.isNotEmpty;

  String get audioDurationFormatted {
    if (audioDurationSeconds == null) return '0:00';
    final minutes = audioDurationSeconds! ~/ 60;
    final seconds = audioDurationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  MessageModel copyWith({
    MessageStatus? status,
    DateTime? readAt,
    String? savedBy,
    DateTime? savedAt,
  }) {
    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      messageType: messageType,
      content: content,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      fileMimeType: fileMimeType,
      audioDurationSeconds: audioDurationSeconds,
      audioWaveform: audioWaveform,
      savedBy: savedBy ?? this.savedBy,
      savedAt: savedAt ?? this.savedAt,
      status: status ?? this.status,
      deliveredAt: deliveredAt,
      readAt: readAt ?? this.readAt,
      disappearsAt: disappearsAt,
      viewedAt: viewedAt,
      replyToId: replyToId,
      mentions: mentions,
      systemEvent: systemEvent,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Blocked user model
class BlockedUserModel {
  final String blockId;
  final String blockedId;
  final String? reason;
  final DateTime blockedAt;
  final String? firstName;
  final String? lastName;
  final String? displayName;
  final String? avatarUrl;

  const BlockedUserModel({
    required this.blockId,
    required this.blockedId,
    this.reason,
    required this.blockedAt,
    this.firstName,
    this.lastName,
    this.displayName,
    this.avatarUrl,
  });

  factory BlockedUserModel.fromJson(Map<String, dynamic> json) {
    return BlockedUserModel(
      blockId: json['block_id'] as String? ?? json['id'] as String,
      blockedId: json['blocked_id'] as String,
      reason: json['reason'] as String?,
      blockedAt: _parseDateTime(json['blocked_at']) ?? DateTime.now(),
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  String get name {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return displayName ?? 'Unknown';
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

/// Chat settings for a specific conversation
class ChatSettingsModel {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? otherUserSpecialization;
  final bool isMuted;
  final bool isArchived;
  final bool isPinned;
  final int? disappearingHours;
  final bool isBlocked;
  final bool otherAllowsAudioSave;

  const ChatSettingsModel({
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.otherUserSpecialization,
    this.isMuted = false,
    this.isArchived = false,
    this.isPinned = false,
    this.disappearingHours,
    this.isBlocked = false,
    this.otherAllowsAudioSave = false,
  });

  factory ChatSettingsModel.fromConversation(ConversationModel conv) {
    return ChatSettingsModel(
      conversationId: conv.conversationId,
      otherUserId: conv.otherUserId,
      otherUserName: conv.otherUserName,
      otherUserAvatar: conv.avatarUrl,
      otherUserSpecialization: conv.specialization,
      isMuted: conv.isMuted,
      isArchived: conv.isArchived,
      isPinned: conv.isPinned,
      disappearingHours: conv.disappearingHours,
      isBlocked: conv.isBlocked,
      otherAllowsAudioSave: conv.otherAllowsAudioSave,
    );
  }

  String get disappearingText {
    if (disappearingHours == null) return 'Never';
    if (disappearingHours == 1) return '1 Hour';
    if (disappearingHours == 24) return '24 Hours';
    if (disappearingHours == 168) return '1 Week';
    return '$disappearingHours Hours';
  }
}
