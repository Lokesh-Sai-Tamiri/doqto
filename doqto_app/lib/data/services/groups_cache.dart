import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/group.dart';

/// Read-through cache for the "My groups" (member) list so a cold start with no
/// network still paints. Same encrypted-box pattern as [NetworkCache]. Only the
/// member list is cached; requested/invited are live-only.
class GroupsCache {
  static const boxName = 'groups_cache';
  Box<dynamic> get _box => Hive.box(boxName);

  static const _myGroupsKey = 'my_groups';

  Future<void> putMyGroups(List<Group> list) => _box.put(
        _myGroupsKey,
        jsonEncode([for (final g in list) g.toCacheJson()]),
      );

  List<Group>? myGroups() {
    final raw = _box.get(_myGroupsKey) as String?;
    if (raw == null) return null;
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          Group.fromJson((e as Map).cast<String, dynamic>())
              .copyWith(membershipTag: GroupMembershipTag.member),
      ];
    } catch (_) {
      return null; // schema drift → cache miss
    }
  }

  Future<void> clear() => _box.clear();
}
