import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';

/// RFC-4122 v4 uuid from Random.secure — avoids a uuid package dependency.
String uuidV4() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}'
      '-${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

class OutboxEntry {
  final String clientId;
  final String conversationId;
  final String content;
  final DateTime createdAt;

  const OutboxEntry({
    required this.clientId,
    required this.conversationId,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'client_id': clientId,
        'conversation_id': conversationId,
        'content': content,
        'created_at': createdAt.toIso8601String(),
      };

  factory OutboxEntry.fromMap(Map<dynamic, dynamic> m) => OutboxEntry(
        clientId: m['client_id'] as String,
        conversationId: m['conversation_id'] as String,
        content: m['content'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// Durable queue of unsent text messages, keyed by clientId. Survives app
/// kill; drained on start / reconnect / manual retry.
class Outbox {
  static const boxName = 'outbox';
  Box<dynamic> get _box => Hive.box(boxName);

  Future<void> add(OutboxEntry e) => _box.put(e.clientId, e.toMap());

  Future<void> remove(String clientId) => _box.delete(clientId);

  bool contains(String clientId) => _box.containsKey(clientId);

  /// Oldest-first, optionally scoped to one conversation.
  List<OutboxEntry> pending({String? conversationId}) {
    final list = _box.values
        .map((v) => OutboxEntry.fromMap(v as Map))
        .where((e) => conversationId == null || e.conversationId == conversationId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }
}
