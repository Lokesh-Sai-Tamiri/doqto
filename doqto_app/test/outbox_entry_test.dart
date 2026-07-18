import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/data/services/outbox.dart';

void main() {
  group('OutboxEntry map round-trip', () {
    test('text entry survives toMap/fromMap', () {
      final e = OutboxEntry(
        clientId: 'c1',
        conversationId: 'conv1',
        content: 'hello',
        createdAt: DateTime.utc(2026, 7, 18, 12, 0, 0),
      );
      final out = OutboxEntry.fromMap(e.toMap());
      expect(out.clientId, 'c1');
      expect(out.conversationId, 'conv1');
      expect(out.kind, OutboxKind.text);
      expect(out.content, 'hello');
      expect(out.createdAt, DateTime.utc(2026, 7, 18, 12, 0, 0));
      expect(out.filePath, isNull);
      expect(out.fileName, isNull);
      expect(out.mimeType, isNull);
      expect(out.durationSec, isNull);
      expect(out.transcript, isNull);
    });

    test('media entry survives toMap/fromMap', () {
      final e = OutboxEntry(
        clientId: 'c2',
        conversationId: 'conv1',
        kind: OutboxKind.media,
        createdAt: DateTime.utc(2026, 7, 18),
        filePath: '/docs/outbox_media/c2.jpg',
        fileName: 'scan.jpg',
        mimeType: 'image/jpeg',
      );
      final out = OutboxEntry.fromMap(e.toMap());
      expect(out.kind, OutboxKind.media);
      expect(out.content, '');
      expect(out.filePath, '/docs/outbox_media/c2.jpg');
      expect(out.fileName, 'scan.jpg');
      expect(out.mimeType, 'image/jpeg');
    });

    test('voice entry survives toMap/fromMap', () {
      final e = OutboxEntry(
        clientId: 'c3',
        conversationId: 'conv2',
        kind: OutboxKind.voice,
        createdAt: DateTime.utc(2026, 7, 18),
        filePath: '/docs/outbox_media/c3.wav',
        fileName: 'voice_1.wav',
        durationSec: 42,
        transcript: 'patient follow-up notes',
      );
      final out = OutboxEntry.fromMap(e.toMap());
      expect(out.kind, OutboxKind.voice);
      expect(out.durationSec, 42);
      expect(out.transcript, 'patient follow-up notes');
      expect(out.fileName, 'voice_1.wav');
    });

    test('legacy map without kind decodes as text', () {
      // Exactly the shape written by the pre-media outbox.
      final legacy = <dynamic, dynamic>{
        'client_id': 'old1',
        'conversation_id': 'conv1',
        'content': 'queued before upgrade',
        'created_at': '2026-05-01T10:00:00.000Z',
      };
      final out = OutboxEntry.fromMap(legacy);
      expect(out.kind, OutboxKind.text);
      expect(out.content, 'queued before upgrade');
      expect(out.filePath, isNull);
      expect(out.durationSec, isNull);
    });

    test('unknown kind string falls back to text', () {
      expect(OutboxKind.fromName('video_call'), OutboxKind.text);
      expect(OutboxKind.fromName(null), OutboxKind.text);
      expect(OutboxKind.fromName('media'), OutboxKind.media);
      expect(OutboxKind.fromName('voice'), OutboxKind.voice);
    });
  });
}
