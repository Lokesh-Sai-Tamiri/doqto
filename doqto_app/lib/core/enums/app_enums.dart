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

  static UserRole fromWire(String s) => switch (s) {
        'doctor' => UserRole.doctor,
        'super_admin' => UserRole.superAdmin,
        _ => throw ArgumentError('Unknown UserRole: $s'),
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

  static OrgStatus fromWire(String s) => switch (s) {
        'pending' => OrgStatus.pending,
        'active' => OrgStatus.active,
        'suspended' => OrgStatus.suspended,
        _ => throw ArgumentError('Unknown OrgStatus: $s'),
      };
}

enum OrgRole {
  @JsonValue('admin') admin,
  @JsonValue('doctor') doctor;

  String get wire => switch (this) {
        OrgRole.admin => 'admin',
        OrgRole.doctor => 'doctor',
      };

  static OrgRole fromWire(String s) => switch (s) {
        'admin' => OrgRole.admin,
        'doctor' => OrgRole.doctor,
        _ => throw ArgumentError('Unknown OrgRole: $s'),
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
  @JsonValue('group') group;

  String get wire => switch (this) {
        ConversationType.direct => 'direct',
        ConversationType.group => 'group',
      };

  static ConversationType fromWire(String s) => switch (s) {
        'direct' => ConversationType.direct,
        'group' => ConversationType.group,
        _ => throw ArgumentError('Unknown ConversationType: $s'),
      };
}

enum MessageType {
  @JsonValue('text') text,
  @JsonValue('voice_note') voiceNote,
  @JsonValue('image') image,
  @JsonValue('file') file,
  @JsonValue('system') system;

  String get wire => switch (this) {
        MessageType.text => 'text',
        MessageType.voiceNote => 'voice_note',
        MessageType.image => 'image',
        MessageType.file => 'file',
        MessageType.system => 'system',
      };

  static MessageType fromWire(String s) => switch (s) {
        'text' => MessageType.text,
        'voice_note' => MessageType.voiceNote,
        'image' => MessageType.image,
        'file' => MessageType.file,
        'system' => MessageType.system,
        _ => throw ArgumentError('Unknown MessageType: $s'),
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
  typingStop;

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

enum DisappearAfter {
  off(null),
  day(86400),
  week(604800);

  final int? seconds;
  const DisappearAfter(this.seconds);
}
