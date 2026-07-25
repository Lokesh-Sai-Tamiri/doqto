import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/core/enums/app_enums.dart';
import 'package:doqto_app/data/models/conversation.dart';

void main() {
  group('Enum tolerance (A5)', () {
    test('ConversationType.fromWire tolerates garbage', () {
      expect(ConversationType.fromWire('garbage'), ConversationType.unknown);
      expect(ConversationType.fromWire('direct'), ConversationType.direct);
      expect(ConversationType.fromWire('group'), ConversationType.group);
      expect(ConversationType.unknown.wire, 'unknown');
    });

    test('MessageType.fromWire tolerates garbage', () {
      expect(MessageType.fromWire('garbage'), MessageType.unknown);
      expect(MessageType.fromWire('text'), MessageType.text);
      expect(MessageType.fromWire('voice_note'), MessageType.voiceNote);
      expect(MessageType.unknown.wire, 'unknown');
    });

    test('ConversationAccess.fromWire tolerates garbage', () {
      expect(ConversationAccess.fromWire('open'), ConversationAccess.open);
      expect(ConversationAccess.fromWire('pending_request'),
          ConversationAccess.pendingRequest);
      expect(
          ConversationAccess.fromWire('declined'), ConversationAccess.declined);
      expect(
          ConversationAccess.fromWire('garbage'), ConversationAccess.unknown);
    });

    test('UserRole/OrgStatus/OrgRole.fromWire no longer throw', () {
      expect(UserRole.fromWire('garbage'), UserRole.doctor);
      expect(OrgStatus.fromWire('garbage'), OrgStatus.pending);
      expect(OrgRole.fromWire('garbage'), OrgRole.doctor);
    });
  });

  group('Conversation model (M0 additive fields)', () {
    Map<String, dynamic> baseJson() => {
          'id': 'c1',
          'org_id': 'o1',
          'type': 'direct',
          'name': null,
          'created_by': 'u1',
          'disappear_after_sec': null,
          'created_at': '2026-07-25T00:00:00Z',
          'updated_at': '2026-07-25T00:00:00Z',
          'member_ids': ['u1', 'u2'],
        };

    test('round-trips access + group_id', () {
      final j = baseJson()
        ..['access'] = 'pending_request'
        ..['group_id'] = 'g1';
      final c = Conversation.fromJson(j);
      expect(c.access, ConversationAccess.pendingRequest);
      expect(c.groupId, 'g1');
      final back = Conversation.fromJson(c.toJson());
      expect(back.access, ConversationAccess.pendingRequest);
      expect(back.groupId, 'g1');
    });

    test('legacy payload without access/group_id parses (null defaults)', () {
      final c = Conversation.fromJson(baseJson());
      expect(c.access, isNull);
      expect(c.groupId, isNull);
    });

    test('unknown conversation type does not throw', () {
      final j = baseJson()..['type'] = 'brand_new_type';
      final c = Conversation.fromJson(j);
      expect(c.type, ConversationType.unknown);
    });

    test('copyWith sets access/groupId', () {
      final c = Conversation.fromJson(baseJson())
          .copyWith(access: ConversationAccess.open, groupId: 'g9');
      expect(c.access, ConversationAccess.open);
      expect(c.groupId, 'g9');
    });
  });
}
