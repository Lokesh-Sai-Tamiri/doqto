import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/providers.dart';
import '../core/enums/app_enums.dart';
import '../data/api/websocket_client.dart';
import '../data/models/group.dart';

/// The three "My groups" buckets, tagged by which /me/groups query produced
/// each entry so the tab can render Requested/Invited chips.
class MyGroupsData {
  final List<Group> member;
  final List<Group> requested;
  final List<Group> invited;

  const MyGroupsData({
    this.member = const [],
    this.requested = const [],
    this.invited = const [],
  });

  bool get isEmpty => member.isEmpty && requested.isEmpty && invited.isEmpty;
}

/// The signed-in user's groups. Cache-first (Hive) for the member list so a
/// cold start offline still paints; live-refreshes on group_member_joined /
/// group_join_request_approved WS events and on reconnect — same idiom as
/// [ConnectionsNotifier].
class MyGroupsNotifier extends AsyncNotifier<MyGroupsData> {
  @override
  Future<MyGroupsData> build() async {
    final ws = ref.read(websocketClientProvider);
    final sub = ws.events.listen((event) {
      if (event.type == WsEventServer.groupMemberJoined ||
          event.type == WsEventServer.groupJoinRequestApproved ||
          event.type == WsEventServer.groupInviteReceived) {
        refresh();
      }
    });
    // Gap recovery: a reconnect means events were missed — refetch.
    final stateSub = ws.states.listen((s) {
      if (s == WsConnState.connected) refresh();
    });
    ref.onDispose(sub.cancel);
    ref.onDispose(stateSub.cancel);

    final cache = ref.read(groupsCacheProvider);
    final cachedMembers = cache.myGroups();
    if (cachedMembers != null) {
      state = AsyncData(MyGroupsData(member: cachedMembers)); // instant paint
    }
    try {
      final data = await _fetch();
      await cache.putMyGroups(data.member);
      return data;
    } catch (_) {
      if (cachedMembers != null) {
        return MyGroupsData(member: cachedMembers);
      }
      rethrow;
    }
  }

  Future<MyGroupsData> _fetch() async {
    final repo = ref.read(groupsRepositoryProvider);
    // Member list is required; requested/invited are best-effort adornments.
    final member = (await repo.myGroups(state: 'member'))
        .map((g) => g.copyWith(membershipTag: GroupMembershipTag.member))
        .toList();
    List<Group> requested = const [];
    List<Group> invited = const [];
    try {
      requested = (await repo.myGroups(state: 'requested'))
          .map((g) => g.copyWith(membershipTag: GroupMembershipTag.requested))
          .toList();
    } catch (_) {}
    try {
      invited = (await repo.myGroups(state: 'invited'))
          .map((g) => g.copyWith(membershipTag: GroupMembershipTag.invited))
          .toList();
    } catch (_) {}
    return MyGroupsData(member: member, requested: requested, invited: invited);
  }

  Future<void> refresh() async {
    try {
      final data = await _fetch();
      await ref.read(groupsCacheProvider).putMyGroups(data.member);
      state = AsyncData(data); // stays on previous data → no flash
    } catch (_) {
      // Offline refresh: keep showing what we have.
    }
  }
}

final myGroupsProvider =
    AsyncNotifierProvider<MyGroupsNotifier, MyGroupsData>(MyGroupsNotifier.new);

/// Self-loading detail for one group, keyed by id. Carries the join/withdraw/
/// leave state machine with optimistic flips; every mutation invalidates
/// [myGroupsProvider] so the tab stays truthful.
class GroupDetailNotifier extends FamilyAsyncNotifier<Group, String> {
  @override
  Future<Group> build(String groupId) =>
      ref.read(groupsRepositoryProvider).getGroup(groupId);

  Group? get _g => state.valueOrNull;

  /// open-policy join → optimistic member, then reconcile with the server.
  Future<JoinResult> join() async {
    final g = _g;
    if (g == null) throw StateError('group_not_loaded');
    state = AsyncData(g.copyWith(
      myRole: GroupRole.member,
      myState: GroupMemberState.active,
      memberCount: g.memberCount + 1,
      membershipTag: GroupMembershipTag.member,
    ));
    try {
      final res = await ref.read(groupsRepositoryProvider).join(arg);
      ref.invalidate(myGroupsProvider);
      // Reconcile from source of truth (redaction/role now that we're in).
      await _reload();
      return res;
    } catch (e) {
      state = AsyncData(g); // roll back
      rethrow;
    }
  }

  /// request-policy join → optimistic Requested tag (no membership yet).
  Future<JoinResult> requestToJoin({String? message}) async {
    final g = _g;
    if (g == null) throw StateError('group_not_loaded');
    state = AsyncData(g.copyWith(membershipTag: GroupMembershipTag.requested));
    try {
      final res = await ref
          .read(groupsRepositoryProvider)
          .requestToJoin(arg, message: message);
      ref.invalidate(myGroupsProvider);
      return res;
    } catch (e) {
      state = AsyncData(g); // roll back
      rethrow;
    }
  }

  Future<void> withdrawRequest() async {
    final g = _g;
    if (g == null) return;
    state = AsyncData(g.copyWith(membershipTag: GroupMembershipTag.none));
    try {
      await ref.read(groupsRepositoryProvider).withdrawJoinRequest(arg);
      ref.invalidate(myGroupsProvider);
    } catch (e) {
      state = AsyncData(g);
      rethrow;
    }
  }

  Future<void> leave(String myUserId) async {
    final g = _g;
    if (g == null) return;
    state = AsyncData(g.copyWith(
      clearMyRole: true,
      membershipTag: GroupMembershipTag.none,
      memberCount: g.memberCount > 0 ? g.memberCount - 1 : 0,
    ));
    try {
      await ref.read(groupsRepositoryProvider).removeMember(arg, myUserId);
      ref.invalidate(myGroupsProvider);
      ref.invalidate(groupMembersProvider(arg));
    } catch (e) {
      state = AsyncData(g);
      rethrow;
    }
  }

  Future<void> _reload() async {
    try {
      final fresh = await ref.read(groupsRepositoryProvider).getGroup(arg);
      state = AsyncData(fresh);
    } catch (_) {
      // keep optimistic state
    }
  }
}

final groupDetailProvider =
    AsyncNotifierProvider.family<GroupDetailNotifier, Group, String>(
        GroupDetailNotifier.new);

/// Active members of a group (auto-disposed; refetched when the segment mounts).
final groupMembersProvider =
    FutureProvider.autoDispose.family<List<GroupMember>, String>((ref, groupId) {
  return ref.read(groupsRepositoryProvider).members(groupId);
});

/// Pending join requests (admin-only). 403 for non-admins surfaces as an error.
final joinRequestsProvider = FutureProvider.autoDispose
    .family<List<GroupJoinRequest>, String>((ref, groupId) {
  return ref.read(groupsRepositoryProvider).joinRequests(groupId);
});

/// Count of pending join requests for an admin row's amber dot. Best-effort:
/// any failure (403 / offline) yields 0 (no dot).
final adminJoinRequestCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, groupId) async {
  try {
    final list = await ref.read(groupsRepositoryProvider).joinRequests(groupId);
    return list.length;
  } catch (_) {
    return 0;
  }
});

/// Discovery / browse results for a query (empty query = browse all public +
/// private). Latest-query wins via the family key; auto-disposed.
final groupDiscoverProvider =
    FutureProvider.autoDispose.family<List<Group>, String>((ref, query) async {
  final page =
      await ref.read(groupsRepositoryProvider).listGroups(q: query);
  return page.data;
});
