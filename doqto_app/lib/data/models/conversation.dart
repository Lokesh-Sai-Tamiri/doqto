import '../../core/enums/app_enums.dart';

class Conversation {
  final String id;
  final String orgId;
  final ConversationType type;
  final String? name;
  final String? createdBy;
  final int? disappearAfterSec;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> memberIds;
  final String? displayName; // direct chats: the other member's full name (server-resolved)
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastMessageSenderId;
  final MessageType? lastMessageType;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.orgId,
    required this.type,
    required this.name,
    required this.createdBy,
    required this.disappearAfterSec,
    required this.createdAt,
    required this.updatedAt,
    required this.memberIds,
    this.displayName,
    required this.lastMessageAt,
    required this.lastMessagePreview,
    required this.lastMessageSenderId,
    required this.lastMessageType,
    required this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] as String,
        orgId: j['org_id'] as String,
        type: ConversationType.fromWire(j['type'] as String),
        name: j['name'] as String?,
        createdBy: j['created_by'] as String?,
        disappearAfterSec: j['disappear_after_sec'] as int?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
        memberIds: ((j['member_ids'] ?? []) as List).map((e) => e.toString()).toList(),
        displayName: j['display_name'] as String?,
        lastMessageAt: j['last_message_at'] != null
            ? DateTime.parse(j['last_message_at'] as String)
            : null,
        lastMessagePreview: j['last_message_preview'] as String?,
        lastMessageSenderId: j['last_message_sender_id'] as String?,
        lastMessageType: j['last_message_type'] != null
            ? MessageType.fromWire(j['last_message_type'] as String)
            : null,
        unreadCount: (j['unread_count'] ?? 0) as int,
      );

  /// Round-trips through [Conversation.fromJson] — used by the offline cache.
  Map<String, dynamic> toJson() => {
        'id': id,
        'org_id': orgId,
        'type': type.wire,
        'name': name,
        'created_by': createdBy,
        'disappear_after_sec': disappearAfterSec,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'member_ids': memberIds,
        'display_name': displayName,
        'last_message_at': lastMessageAt?.toIso8601String(),
        'last_message_preview': lastMessagePreview,
        'last_message_sender_id': lastMessageSenderId,
        'last_message_type': lastMessageType?.wire,
        'unread_count': unreadCount,
      };
}
