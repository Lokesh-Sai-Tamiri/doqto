// Mirrors docs/enums.md + app/core/enums.py on the backend.
// Wire values are snake_case strings — enforced via @JsonValue.
// A parity check in scripts/check_enum_parity.py fails CI on drift.

import 'package:json_annotation/json_annotation.dart';

enum UserRole {
  @JsonValue('doctor') doctor,
  @JsonValue('super_admin') superAdmin;

  String get wire => switch (this) {
        UserRole.doctor => 'doctor',
        UserRole.superAdmin => 'super_admin',
      };

  // Tolerant (A5): unknown wire values map to the least-privileged role.
  static UserRole fromWire(String s) => switch (s) {
        'super_admin' => UserRole.superAdmin,
        _ => UserRole.doctor,
      };
}

enum OrgStatus {
  @JsonValue('pending') pending,
  @JsonValue('active') active,
  @JsonValue('suspended') suspended;

  String get wire => switch (this) {
        OrgStatus.pending => 'pending',
        OrgStatus.active => 'active',
        OrgStatus.suspended => 'suspended',
      };

  // Tolerant (A5): unknown wire values fail safe to `pending`
  // (benign "verification in progress" state, never grants access).
  static OrgStatus fromWire(String s) => switch (s) {
        'active' => OrgStatus.active,
        'suspended' => OrgStatus.suspended,
        _ => OrgStatus.pending,
      };
}

enum OrgRole {
  @JsonValue('admin') admin,
  @JsonValue('doctor') doctor;

  String get wire => switch (this) {
        OrgRole.admin => 'admin',
        OrgRole.doctor => 'doctor',
      };

  // Tolerant (A5): unknown wire values map to the least-privileged role.
  static OrgRole fromWire(String s) => switch (s) {
        'admin' => OrgRole.admin,
        _ => OrgRole.doctor,
      };
}

enum PracticeType {
  @JsonValue('independent') independent,
  @JsonValue('specialty_group') specialtyGroup,
  @JsonValue('community_hospital') communityHospital;

  String get wire => switch (this) {
        PracticeType.independent => 'independent',
        PracticeType.specialtyGroup => 'specialty_group',
        PracticeType.communityHospital => 'community_hospital',
      };
}

enum ConversationType {
  @JsonValue('direct') direct,
  @JsonValue('group') group,

  /// Tolerant fallback for wire values this client doesn't know yet (A5).
  /// Consumers must treat it like [direct] (safest render path) — never crash.
  @JsonValue('unknown') unknown;

  String get wire => switch (this) {
        ConversationType.direct => 'direct',
        ConversationType.group => 'group',
        ConversationType.unknown => 'unknown',
      };

  static ConversationType fromWire(String s) => switch (s) {
        'direct' => ConversationType.direct,
        'group' => ConversationType.group,
        _ => ConversationType.unknown,
      };
}

enum MessageType {
  @JsonValue('text') text,
  @JsonValue('voice_note') voiceNote,
  @JsonValue('image') image,
  @JsonValue('file') file,
  @JsonValue('system') system,

  /// Tolerant fallback for wire values this client doesn't know yet (A5).
  /// Consumers must treat it like [text] (generic bubble) — never crash.
  @JsonValue('unknown') unknown;

  String get wire => switch (this) {
        MessageType.text => 'text',
        MessageType.voiceNote => 'voice_note',
        MessageType.image => 'image',
        MessageType.file => 'file',
        MessageType.system => 'system',
        MessageType.unknown => 'unknown',
      };

  static MessageType fromWire(String s) => switch (s) {
        'text' => MessageType.text,
        'voice_note' => MessageType.voiceNote,
        'image' => MessageType.image,
        'file' => MessageType.file,
        'system' => MessageType.system,
        _ => MessageType.unknown,
      };
}

/// Access tier of a conversation (networking layer, plan M0/A5).
/// `open` = normal thread; `pending_request` = message-request tier;
/// `declined` = recipient declined the request.
enum ConversationAccess {
  @JsonValue('open') open,
  @JsonValue('pending_request') pendingRequest,
  @JsonValue('declined') declined,

  /// Tolerant fallback (A5) — consumers must treat it like [open].
  @JsonValue('unknown') unknown;

  String get wire => switch (this) {
        ConversationAccess.open => 'open',
        ConversationAccess.pendingRequest => 'pending_request',
        ConversationAccess.declined => 'declined',
        ConversationAccess.unknown => 'unknown',
      };

  static ConversationAccess fromWire(String s) => switch (s) {
        'open' => ConversationAccess.open,
        'pending_request' => ConversationAccess.pendingRequest,
        'declined' => ConversationAccess.declined,
        _ => ConversationAccess.unknown,
      };
}

enum TranscriptStatus {
  @JsonValue('none') none,
  @JsonValue('pending') pending,
  @JsonValue('completed') completed,
  @JsonValue('failed') failed;

  String get wire => switch (this) {
        TranscriptStatus.none => 'none',
        TranscriptStatus.pending => 'pending',
        TranscriptStatus.completed => 'completed',
        TranscriptStatus.failed => 'failed',
      };

  static TranscriptStatus fromWire(String s) => switch (s) {
        'pending' => TranscriptStatus.pending,
        'completed' => TranscriptStatus.completed,
        'failed' => TranscriptStatus.failed,
        _ => TranscriptStatus.none,
      };
}

enum PresenceStatus {
  online,
  away,
  offline;

  String get wire => switch (this) {
        PresenceStatus.online => 'online',
        PresenceStatus.away => 'away',
        PresenceStatus.offline => 'offline',
      };

  static PresenceStatus fromWire(String? s) => switch (s) {
        'online' => PresenceStatus.online,
        'away' => PresenceStatus.away,
        _ => PresenceStatus.offline,
      };
}

enum WsEventServer {
  newMessage,
  transcriptReady,
  messageDelivered,
  messageRead,
  presenceUpdate,
  memberAdded,
  memberRemoved,
  systemMessage,
  typingStart,
  typingStop,
  heartbeatAck;

  String get wire => switch (this) {
        WsEventServer.newMessage => 'new_message',
        WsEventServer.transcriptReady => 'transcript_ready',
        WsEventServer.messageDelivered => 'message_delivered',
        WsEventServer.messageRead => 'message_read',
        WsEventServer.presenceUpdate => 'presence_update',
        WsEventServer.memberAdded => 'member_added',
        WsEventServer.memberRemoved => 'member_removed',
        WsEventServer.systemMessage => 'system_message',
        WsEventServer.typingStart => 'typing_start',
        WsEventServer.typingStop => 'typing_stop',
        WsEventServer.heartbeatAck => 'heartbeat_ack',
      };

  static WsEventServer? fromWire(String s) => switch (s) {
        'new_message' => WsEventServer.newMessage,
        'transcript_ready' => WsEventServer.transcriptReady,
        'message_delivered' => WsEventServer.messageDelivered,
        'message_read' => WsEventServer.messageRead,
        'presence_update' => WsEventServer.presenceUpdate,
        'member_added' => WsEventServer.memberAdded,
        'member_removed' => WsEventServer.memberRemoved,
        'system_message' => WsEventServer.systemMessage,
        'typing_start' => WsEventServer.typingStart,
        'typing_stop' => WsEventServer.typingStop,
        'heartbeat_ack' => WsEventServer.heartbeatAck,
        _ => null,
      };
}

enum WsEventClient {
  heartbeat,
  typingStart,
  typingStop;

  String get wire => switch (this) {
        WsEventClient.heartbeat => 'heartbeat',
        WsEventClient.typingStart => 'typing_start',
        WsEventClient.typingStop => 'typing_stop',
      };
}

enum DevicePlatform {
  @JsonValue('ios') ios,
  @JsonValue('android') android;

  String get wire => switch (this) {
        DevicePlatform.ios => 'ios',
        DevicePlatform.android => 'android',
      };

  static DevicePlatform fromWire(String s) => switch (s) {
        'ios' => DevicePlatform.ios,
        'android' => DevicePlatform.android,
        _ => throw ArgumentError('Unknown DevicePlatform: $s'),
      };
}

enum DisappearAfter {
  off(null),
  day(86400),
  week(604800);

  final int? seconds;
  const DisappearAfter(this.seconds);
}
