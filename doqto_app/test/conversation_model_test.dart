import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/core/enums/app_enums.dart';
import 'package:doqto_app/data/models/conversation.dart';

void main() {
  // Since M0 every direct conversation is network-scoped with org_id NULL.
  // A non-null cast here threw before the thread could ever open.
  test('parses a network-scoped conversation with a null org_id', () {
    const raw = '{"id":"c1","org_id":null,"type":"direct","name":null,'
        '"created_by":"u2","access":"open","initiator_id":null,'
        '"is_network":true,"is_hidden":false,"disappear_after_sec":null,'
        '"created_at":"2026-07-26T01:00:00Z","updated_at":"2026-07-26T01:00:00Z",'
        '"member_ids":["u1","u2"],"display_name":"Dr Vimal",'
        '"last_message_at":null,"last_message_preview":null,'
        '"last_message_sender_id":null,"last_message_type":null,"unread_count":0}';

    final c = Conversation.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(c.orgId, isNull);
    expect(c.id, 'c1');
    expect(c.type, ConversationType.direct);
    expect(c.isNetwork, isTrue);

    // Survives the offline-cache round trip too.
    expect(Conversation.fromJson(c.toJson()).orgId, isNull);
  });
}
