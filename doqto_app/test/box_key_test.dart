import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:doqto_app/data/local/box_key_storage.dart';
import 'package:doqto_app/data/services/chat_cache.dart';
import 'package:doqto_app/data/services/outbox.dart';

void main() {
  group('BoxKeyStorage.generateKey', () {
    test('produces 32 bytes (AES-256) and base64 round-trips', () {
      final key = BoxKeyStorage.generateKey();
      expect(key.length, 32);
      expect(base64Decode(base64Encode(key)), key);
    });

    test('keys are unique per call', () {
      expect(
        BoxKeyStorage.generateKey(),
        isNot(equals(BoxKeyStorage.generateKey())),
      );
    });

    test('key is accepted by HiveAesCipher', () {
      expect(() => HiveAesCipher(BoxKeyStorage.generateKey()), returnsNormally);
    });
  });

  group('logout wipe (H2)', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('doqto_hive_test');
      Hive.init(tmp.path);
      await Hive.openBox<dynamic>(Outbox.boxName);
      await Hive.openBox<dynamic>(ChatCache.boxName);
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('Outbox.clear and ChatCache.clear empty both boxes', () async {
      final outbox = Outbox();
      await outbox.add(OutboxEntry(
        clientId: 'c1',
        conversationId: 'conv1',
        content: 'patient details',
        createdAt: DateTime.now().toUtc(),
      ));
      await Hive.box(ChatCache.boxName).put('conversations', '[]');
      expect(outbox.pending(), hasLength(1));
      expect(Hive.box(ChatCache.boxName).isNotEmpty, isTrue);

      await outbox.clear();
      await ChatCache().clear();

      expect(Hive.box(Outbox.boxName).isEmpty, isTrue);
      expect(Hive.box(ChatCache.boxName).isEmpty, isTrue);
      expect(outbox.pending(), isEmpty);
    });

    test('encrypted box round-trips data with a generated key', () async {
      final cipher = HiveAesCipher(BoxKeyStorage.generateKey());
      final box = await Hive.openBox<dynamic>('enc_test', encryptionCipher: cipher);
      await box.put('k', 'sensitive');
      expect(box.get('k'), 'sensitive');
      await box.deleteFromDisk();
    });
  });
}
