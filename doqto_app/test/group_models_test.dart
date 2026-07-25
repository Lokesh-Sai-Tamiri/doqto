import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/core/enums/app_enums.dart';
import 'package:doqto_app/data/models/group.dart';

void main() {
  group('Group enum tolerance (A5)', () {
    test('GroupVisibility.fromWire garbage → unknown', () {
      expect(GroupVisibility.fromWire('garbage'), GroupVisibility.unknown);
      expect(GroupVisibility.fromWire('public'), GroupVisibility.public);
      expect(GroupVisibility.fromWire('secret'), GroupVisibility.secret);
      expect(GroupVisibility.fromWire(null), GroupVisibility.unknown);
      expect(GroupVisibility.private.wire, 'private');
    });

    test('GroupJoinPolicy.fromWire garbage → unknown', () {
      expect(GroupJoinPolicy.fromWire('garbage'), GroupJoinPolicy.unknown);
      expect(GroupJoinPolicy.fromWire('invite_only'), GroupJoinPolicy.inviteOnly);
      expect(GroupJoinPolicy.inviteOnly.wire, 'invite_only');
    });

    test('GroupRole.fromWire garbage → unknown; isAdminTier ladder', () {
      expect(GroupRole.fromWire('garbage'), GroupRole.unknown);
      expect(GroupRole.fromWire('owner'), GroupRole.owner);
      expect(GroupRole.owner.isAdminTier, isTrue);
      expect(GroupRole.admin.isAdminTier, isTrue);
      expect(GroupRole.moderator.isAdminTier, isTrue);
      expect(GroupRole.member.isAdminTier, isFalse);
      expect(GroupRole.moderator.wire, 'moderator');
    });

    test('GroupMemberState.fromWire garbage → unknown', () {
      expect(GroupMemberState.fromWire('garbage'), GroupMemberState.unknown);
      expect(GroupMemberState.fromWire('active'), GroupMemberState.active);
      expect(GroupMemberState.banned.wire, 'banned');
    });

    test('WsEventServer mirrors the four group events', () {
      expect(WsEventServer.fromWire('group_invite_received'),
          WsEventServer.groupInviteReceived);
      expect(WsEventServer.fromWire('group_join_request'),
          WsEventServer.groupJoinRequest);
      expect(WsEventServer.fromWire('group_member_joined'),
          WsEventServer.groupMemberJoined);
      expect(WsEventServer.fromWire('group_join_request_approved'),
          WsEventServer.groupJoinRequestApproved);
    });
  });

  group('Group.fromJson', () {
    Map<String, dynamic> fullGroup() => {
          'id': 'g1',
          'conversation_id': 'c1',
          'name': 'Cardiology Leads',
          'description': 'Cross-org cardiology collaboration.',
          'visibility': 'public',
          'join_policy': 'open',
          'post_policy': 'all_members',
          'member_dm_policy': 'request',
          'owner_id': 'u9',
          'org_id': null,
          'avatar_url': null,
          'member_count': 12,
          'created_at': '2026-07-20T00:00:00Z',
          'my_role': 'owner',
          'my_state': 'active',
        };

    test('full GroupOut parses every field', () {
      final g = Group.fromJson(fullGroup());
      expect(g.id, 'g1');
      expect(g.conversationId, 'c1');
      expect(g.name, 'Cardiology Leads');
      expect(g.visibility, GroupVisibility.public);
      expect(g.joinPolicy, GroupJoinPolicy.open);
      expect(g.memberDmPolicy, 'request');
      expect(g.postPolicy, 'all_members');
      expect(g.memberCount, 12);
      expect(g.ownerId, 'u9');
      expect(g.myRole, GroupRole.owner);
      expect(g.myState, GroupMemberState.active);
      expect(g.createdAt, isNotNull);
      expect(g.isMember, isTrue);
      expect(g.isAdmin, isTrue); // owner
      expect(g.initials, 'CL');
    });

    test('redacted GroupCardOut (no conversation_id / join_policy) is tolerant',
        () {
      final g = Group.fromJson({
        'id': 'g2',
        'name': 'Private Rounds',
        'visibility': 'private',
        'member_count': 3,
      });
      expect(g.conversationId, ''); // card omits it
      expect(g.joinPolicy, isNull); // redacted for non-members
      expect(g.myRole, isNull);
      expect(g.isMember, isFalse);
      expect(g.isAdmin, isFalse);
      expect(g.visibility, GroupVisibility.private);
      expect(g.memberCount, 3);
    });

    test('sparse/garbage payload never throws', () {
      final g = Group.fromJson({'id': 'x', 'visibility': 'bogus'});
      expect(g.name, '');
      expect(g.visibility, GroupVisibility.unknown);
      expect(g.memberCount, 0);
      expect(g.avatarIndex, isNonNegative);
    });

    test('isMember respects non-active member state', () {
      final left = Group.fromJson({
        'id': 'g3',
        'name': 'Left Group',
        'visibility': 'public',
        'member_count': 1,
        'my_role': 'member',
        'my_state': 'left',
      });
      expect(left.isMember, isFalse);
    });

    test('copyWith flips role/state and clears membership', () {
      final g = Group.fromJson(fullGroup());
      final left = g.copyWith(clearMyRole: true);
      expect(left.myRole, isNull);
      expect(left.myState, isNull);
      expect(left.isMember, isFalse);
      expect(left.name, g.name);
    });
  });

  group('GroupMember / GroupJoinRequest fromJson', () {
    test('GroupMember parses tolerantly', () {
      final m = GroupMember.fromJson({
        'user_id': 'u1',
        'full_name': 'Dr. Ada Vance',
        'role': 'admin',
        'state': 'active',
        'specialty': 'Cardiology',
      });
      expect(m.userId, 'u1');
      expect(m.role, GroupRole.admin);
      expect(m.state, GroupMemberState.active);
      expect(m.initials, 'DV'); // first+last word initials ("Dr." + "Vance")
    });

    test('GroupJoinRequest falls back to a display name when name is absent',
        () {
      final r = GroupJoinRequest.fromJson({
        'id': 'r1',
        'group_id': 'g1',
        'user_id': 'abcd1234',
        'message': 'Please add me',
        'created_at': '2026-07-25T00:00:00Z',
      });
      expect(r.id, 'r1');
      expect(r.userId, 'abcd1234');
      expect(r.message, 'Please add me');
      expect(r.displayName, contains('abcd'));
      expect(r.createdAt, isNotNull);
    });
  });

  group('JoinResult', () {
    test('joined vs requested', () {
      expect(JoinResult.fromJson({'result': 'joined', 'group_id': 'g1'}).joined,
          isTrue);
      expect(
          JoinResult.fromJson({'result': 'requested', 'group_id': 'g1'})
              .requested,
          isTrue);
    });
  });
}
