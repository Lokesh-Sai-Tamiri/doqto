import '../../core/constants/api_routes.dart';
import '../../core/enums/app_enums.dart';
import '../api/api_client.dart';
import '../models/group.dart';
import '../models/network_profile.dart' show CursorPage;

/// Every group endpoint (M5). Discovery/`GET /groups` return a `{data,
/// next_cursor}` page; `/me/groups`, members and join-requests return bare
/// lists; single-object endpoints return the object.
class GroupsRepository {
  final ApiClient _api;
  GroupsRepository(this._api);

  // --- Create / discovery / detail / update ---

  Future<Group> createGroup({
    required String name,
    String? description,
    required GroupVisibility visibility,
    required GroupJoinPolicy joinPolicy,
    String? memberDmPolicy,
    String? postPolicy,
    String? orgId,
  }) async {
    final j = await _api.post(ApiRoutes.groups, body: {
      'name': name,
      if (description != null && description.isNotEmpty)
        'description': description,
      'visibility': visibility.wire,
      'join_policy': joinPolicy.wire,
      'member_dm_policy': ?memberDmPolicy,
      'post_policy': ?postPolicy,
      'org_id': ?orgId,
    });
    return Group.fromJson(j);
  }

  /// Discovery / browse. `mine=true` returns the caller's member groups;
  /// otherwise public+private (secret hidden). `{data, next_cursor}`.
  Future<CursorPage<Group>> listGroups({
    bool mine = false,
    String? q,
    String? cursor,
  }) async {
    final j = await _api.get(ApiRoutes.groups, query: {
      if (mine) 'mine': 'true',
      if (q != null && q.isNotEmpty) 'q': q,
      'cursor': ?cursor,
    });
    final data = (j['data'] as List? ?? const [])
        .map((e) => Group.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return CursorPage(data, j['next_cursor'] as String?);
  }

  Future<Group> getGroup(String id) async {
    final j = await _api.get(ApiRoutes.group(id));
    return Group.fromJson(j);
  }

  Future<Group> updateGroup(
    String id, {
    String? name,
    String? description,
    GroupVisibility? visibility,
    GroupJoinPolicy? joinPolicy,
    String? postPolicy,
    String? memberDmPolicy,
    String? avatarUrl,
  }) async {
    final j = await _api.patch(ApiRoutes.group(id), body: {
      'name': ?name,
      'description': ?description,
      if (visibility != null) 'visibility': visibility.wire,
      if (joinPolicy != null) 'join_policy': joinPolicy.wire,
      'post_policy': ?postPolicy,
      'member_dm_policy': ?memberDmPolicy,
      'avatar_url': ?avatarUrl,
    });
    return Group.fromJson(j);
  }

  /// `/me/groups?state=member|requested|invited` → bare list of cards.
  Future<List<Group>> myGroups({String state = 'member'}) async {
    final list = await _api.getList(ApiRoutes.meGroups, query: {'state': state});
    return list
        .map((e) => Group.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // --- Join + join requests ---

  /// open → member; request → join-request created; invite_only → 403.
  Future<JoinResult> join(String groupId, {String? message}) async {
    final j = await _api.post(
      ApiRoutes.groupJoin(groupId),
      body: message != null && message.isNotEmpty ? {'message': message} : null,
    );
    return JoinResult.fromJson(j);
  }

  Future<JoinResult> requestToJoin(String groupId, {String? message}) async {
    final j = await _api.post(
      ApiRoutes.groupJoinRequests(groupId),
      body: {if (message != null && message.isNotEmpty) 'message': message},
    );
    return JoinResult.fromJson(j);
  }

  Future<List<GroupJoinRequest>> joinRequests(String groupId) async {
    final list = await _api.getList(ApiRoutes.groupJoinRequests(groupId));
    return list
        .map((e) => GroupJoinRequest.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> withdrawJoinRequest(String groupId) =>
      _api.delete(ApiRoutes.groupJoinRequestWithdraw(groupId));

  Future<void> approveJoinRequest(String groupId, String requestId) =>
      _api.post(ApiRoutes.groupJoinRequestApprove(groupId, requestId));

  Future<void> rejectJoinRequest(String groupId, String requestId) =>
      _api.post(ApiRoutes.groupJoinRequestReject(groupId, requestId));

  // --- Invites ---

  Future<Map<String, dynamic>> inviteUser(String groupId, String userId) =>
      _api.post(ApiRoutes.groupInvites(groupId), body: {'user_id': userId});

  Future<Map<String, dynamic>> createLinkInvite(
    String groupId, {
    int? maxUses,
    DateTime? expiresAt,
  }) =>
      _api.post(ApiRoutes.groupInvites(groupId), body: {
        'link': true,
        'max_uses': ?maxUses,
        if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
      });

  Future<JoinResult> acceptLinkInvite(String token) async {
    final j = await _api.post(ApiRoutes.groupInviteTokenAccept(token));
    return JoinResult.fromJson(j);
  }

  Future<void> acceptInvite(String groupId, String inviteId) =>
      _api.post(ApiRoutes.groupInviteAccept(groupId, inviteId));

  Future<void> declineInvite(String groupId, String inviteId) =>
      _api.post(ApiRoutes.groupInviteDecline(groupId, inviteId));

  Future<void> revokeInvite(String groupId, String inviteId) =>
      _api.delete(ApiRoutes.groupInvite(groupId, inviteId));

  // --- Members / roles / ownership ---

  Future<List<GroupMember>> members(String groupId) async {
    final list = await _api.getList(ApiRoutes.groupMembers(groupId));
    return list
        .map((e) => GroupMember.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> changeRole(String groupId, String userId, GroupRole role) =>
      _api.patch(ApiRoutes.groupMember(groupId, userId), body: {'role': role.wire});

  /// Remove a member, or leave the group (pass your own id).
  Future<void> removeMember(String groupId, String userId) =>
      _api.delete(ApiRoutes.groupMember(groupId, userId));

  Future<void> banMember(String groupId, String userId) =>
      _api.post(ApiRoutes.groupMemberBan(groupId, userId));

  Future<void> transferOwnership(String groupId, String userId) =>
      _api.post(ApiRoutes.groupTransferOwnership(groupId), body: {'user_id': userId});
}
