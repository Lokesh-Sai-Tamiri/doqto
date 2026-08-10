import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/providers.dart';
import '../core/enums/app_enums.dart';
import '../data/api/websocket_client.dart';
import '../data/models/group.dart';

/// The two "My groups" buckets, tagged by which /me/groups query produced each
/// entry so the tab can render an Invited chip. Groups are invite-only, so
/// there is no third "requested" bucket.
class MyGroupsData {
  final List<Group> member;
  final List<Group> invited;

  const MyGroupsData({this.member = const [], this.invited = const []});

  bool get isEmpty => member.isEmpty && invited.isEmpty;
}

/// The signed-in user's groups. Cache-first (Hive) for the member list so a
/// cold start offline still paints; live-refreshes on group_member_joined /
/// group_invite_received WS events and on reconnect — same idiom as
/// [ConnectionsNotifier].
class MyGroupsNotifier extends AsyncNotifier<MyGroupsData> {
  @override
  Future<MyGroupsData> build() async {
    final ws = ref.read(websocketClientProvider);
    final sub = ws.events.listen((event) {
      if (event.type == WsEventServer.groupMemberJoined ||
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
    // Member list is required; invited is a best-effort adornment.
    final member = (await repo.myGroups(state: 'member'))
        .map((g) => g.copyWith(membershipTag: GroupMembershipTag.member))
        .toList();
    List<Group> invited = const [];
    try {
      invited = (await repo.myGroups(state: 'invited'))
          .map((g) => g.copyWith(membershipTag: GroupMembershipTag.invited))
          .toList();
    } catch (_) {}
    return MyGroupsData(member: member, invited: invited);
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

/// Self-loading detail for one group, keyed by id. Carries the leave flow with
/// an optimistic flip; every mutation invalidates [myGroupsProvider] so the tab
/// stays truthful. There is no join flow — groups are invite-only.
class GroupDetailNotifier extends FamilyAsyncNotifier<Group, String> {
  @override
  Future<Group> build(String groupId) =>
      ref.read(groupsRepositoryProvider).getGroup(groupId);

  Group? get _g => state.valueOrNull;

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

}

final groupDetailProvider =
    AsyncNotifierProvider.family<GroupDetailNotifier, Group, String>(
        GroupDetailNotifier.new);

/// Active members of a group (auto-disposed; refetched when the segment mounts).
final groupMembersProvider =
    FutureProvider.autoDispose.family<List<GroupMember>, String>((ref, groupId) {
  return ref.read(groupsRepositoryProvider).members(groupId);
});

