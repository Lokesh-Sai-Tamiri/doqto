import '../../core/enums/app_enums.dart';
import 'network_profile.dart';

/// Client-only membership-state mirror (backend GroupMemberState). Tolerant:
/// unknown → [active] so a member row never wrongly disappears. NOT parity-gated
/// (backend-only enum — plan §M5).
enum GroupMemberState {
  active,
  banned,
  left,
  removed,
  unknown;

  String get wire => switch (this) {
        GroupMemberState.active => 'active',
        GroupMemberState.banned => 'banned',
        GroupMemberState.left => 'left',
        GroupMemberState.removed => 'removed',
        GroupMemberState.unknown => 'unknown',
      };

  static GroupMemberState fromWire(String? s) => switch (s) {
        'active' => GroupMemberState.active,
        'banned' => GroupMemberState.banned,
        'left' => GroupMemberState.left,
        'removed' => GroupMemberState.removed,
        _ => GroupMemberState.unknown,
      };
}

/// Where this group appeared in "My groups" (client-only tag, set by the state
/// layer from which /me/groups query produced it — the wire has no such field).
enum GroupMembershipTag { member, invited, none }

/// A group. Tolerant hand-written [fromJson] that parses BOTH the full
/// `GroupOut` (detail/create) and the `GroupCardOut` (my groups) — card
/// payloads omit conversation_id/owner_id/post_policy, which default to safe
/// empties. Mirrors backend schemas/group.py.
class Group {
  final String id;
  final String name;
  final String? description;
  final String? memberDmPolicy;
  final String? postPolicy;
  final String? avatarUrl;
  final int memberCount;
  final String conversationId;
  final String ownerId;
  final String? orgId;

  /// The requesting user's role/state, when the payload carries it.
  final GroupRole? myRole;
  final GroupMemberState? myState;
  final DateTime? createdAt;

  /// Client-only tag (see [GroupMembershipTag]); never from the wire.
  final GroupMembershipTag membershipTag;

  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.memberDmPolicy,
    required this.postPolicy,
    required this.avatarUrl,
    required this.memberCount,
    required this.conversationId,
    required this.ownerId,
    required this.orgId,
    required this.myRole,
    required this.myState,
    required this.createdAt,
    this.membershipTag = GroupMembershipTag.none,
  });

  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        description: j['description'] as String?,
        memberDmPolicy: j['member_dm_policy'] as String?,
        postPolicy: j['post_policy'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        memberCount: (j['member_count'] as num?)?.toInt() ?? 0,
        conversationId: (j['conversation_id'] ?? '') as String,
        ownerId: (j['owner_id'] ?? '') as String,
        orgId: j['org_id'] as String?,
        myRole: j['my_role'] != null
            ? GroupRole.fromWire(j['my_role'] as String?)
            : null,
        myState: j['my_state'] != null
            ? GroupMemberState.fromWire(j['my_state'] as String?)
            : null,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String)
            : null,
      );

  /// True when the requesting user is an active member.
  bool get isMember =>
      myRole != null &&
      (myState == null || myState == GroupMemberState.active);

  /// True when the requesting user can manage the group (owner/admin/mod).
  bool get isAdmin => isMember && (myRole?.isAdminTier ?? false);

  String get initials => initialsOf(name);
  int get avatarIndex => avatarIndexFrom(null, id);

  Group copyWith({
    GroupRole? myRole,
    GroupMemberState? myState,
    int? memberCount,
    GroupMembershipTag? membershipTag,
    bool clearMyRole = false,
  }) =>
      Group(
        id: id,
        name: name,
        description: description,
        memberDmPolicy: memberDmPolicy,
        postPolicy: postPolicy,
        avatarUrl: avatarUrl,
        memberCount: memberCount ?? this.memberCount,
        conversationId: conversationId,
        ownerId: ownerId,
        orgId: orgId,
        myRole: clearMyRole ? null : (myRole ?? this.myRole),
        myState: clearMyRole ? null : (myState ?? this.myState),
        createdAt: createdAt,
        membershipTag: membershipTag ?? this.membershipTag,
      );

  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'name': name,
        'description': description,
        'member_dm_policy': memberDmPolicy,
        'post_policy': postPolicy,
        'avatar_url': avatarUrl,
        'member_count': memberCount,
        'conversation_id': conversationId,
        'owner_id': ownerId,
        'org_id': orgId,
        'my_role': myRole?.wire,
        'my_state': myState?.wire,
        'created_at': createdAt?.toIso8601String(),
      };
}

/// One active member of a group. Mirrors backend GroupMemberOut. Carries NO
/// relationship fields (the members endpoint doesn't return degree/state), so
/// per-row Connect/Message is driven by [relationshipProvider] or a tap that
/// routes to /people/:id.
class GroupMember {
  final String userId;
  final String fullName;
  final String? specialty;
  final String? headline;
  final String? avatarColor;
  final String? avatarUrl;
  final GroupRole role;
  final GroupMemberState state;

  const GroupMember({
    required this.userId,
    required this.fullName,
    required this.specialty,
    required this.headline,
    required this.avatarColor,
    required this.avatarUrl,
    required this.role,
    required this.state,
  });

  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
        userId: (j['user_id'] ?? '') as String,
        fullName: (j['full_name'] ?? '') as String,
        specialty: j['specialty'] as String?,
        headline: j['headline'] as String?,
        avatarColor: j['avatar_color'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        role: GroupRole.fromWire(j['role'] as String?),
        state: GroupMemberState.fromWire(j['state'] as String?),
      );

  String get initials => initialsOf(fullName);
  int get avatarIndex => avatarIndexFrom(avatarColor, userId);
}

/// Result of accepting an invite link: `{result: 'joined'}`.
class JoinResult {
  final String result;
  final String groupId;
  const JoinResult(this.result, this.groupId);

  bool get joined => result == 'joined';

  factory JoinResult.fromJson(Map<String, dynamic> j) => JoinResult(
        (j['result'] ?? '') as String,
        (j['group_id'] ?? '') as String,
      );
}
