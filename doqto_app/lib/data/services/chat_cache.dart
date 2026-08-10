import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/conversation.dart';
import '../models/message.dart';

/// Read-through cache so a cold start with no network still shows history.
/// Write-through on every successful fetch; latest page only.
class ChatCache {
  static const boxName = 'chat_cache';
  Box<dynamic> get _box => Hive.box(boxName);

  static const _convsKey = 'conversations';
  String _msgsKey(String convId) => 'messages:$convId';

  Future<void> putConversations(List<Conversation> list) =>
      _box.put(_convsKey, jsonEncode([for (final c in list) c.toJson()]));

  List<Conversation>? conversations() => _decodeList(_convsKey, Conversation.fromJson);

  Future<void> putMessages(String convId, List<Message> msgs) =>
      _box.put(_msgsKey(convId), jsonEncode([for (final m in msgs) m.toJson()]));

  List<Message>? messages(String convId) => _decodeList(_msgsKey(convId), Message.fromJson);

  List<T>? _decodeList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _box.get(key) as String?;
    if (raw == null) return null;
    try {
      return [
        for (final e in jsonDecode(raw) as List) fromJson(e as Map<String, dynamic>),
      ];
    } catch (_) {
      return null; // schema drift: treat as cache miss
    }
  }

  Future<void> clear() => _box.clear();
}
