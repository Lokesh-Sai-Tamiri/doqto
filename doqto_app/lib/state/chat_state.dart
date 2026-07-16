import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/providers.dart';
import '../core/enums/app_enums.dart';
import '../data/models/conversation.dart';
import '../data/models/message.dart';
import 'auth_state.dart';

/// Conversation list that live-updates: re-fetches in place (no loading flash)
/// whenever a message is sent/received or read state changes.
class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    final ws = ref.read(websocketClientProvider);
    final sub = ws.events.listen((event) {
      if (event.type == WsEventServer.newMessage ||
          event.type == WsEventServer.messageRead) {
        refresh();
      }
    });
    ref.onDispose(sub.cancel);
    return ref.read(chatRepositoryProvider).listConversations();
  }

  Future<void> refresh() async {
    final list = await ref.read(chatRepositoryProvider).listConversations();
    state = AsyncData(list); // stays on previous data until this resolves → no flash
  }
}

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<Conversation>>(
        ConversationsNotifier.new);

class MessagesNotifier extends FamilyAsyncNotifier<List<Message>, String> {
  @override
  Future<List<Message>> build(String conversationId) async {
    final msgs = await ref.read(chatRepositoryProvider).listMessages(conversationId);
    _listenWs(conversationId);
    return msgs;
  }

  void _listenWs(String conversationId) {
    final ws = ref.read(websocketClientProvider);
    final sub = ws.events.listen((event) {
      switch (event.type) {
        case WsEventServer.newMessage:
          final msg = Message.fromJson(event.data);
          if (msg.conversationId == conversationId) {
            final current = state.value ?? [];
            state = AsyncData([msg, ...current]);
          }
          break;
        case WsEventServer.messageRead:
          final convId = event.data['conversation_id'] as String?;
          final msgId = event.data['message_id'] as String?;
          // Conversation-level read targets a specific conversation; per-message
          // read is matched by id below regardless of conversation.
          if (msgId == null && convId != conversationId) break;
          final current = state.value ?? [];
          state = AsyncData([
            for (final m in current)
              if (msgId == null || m.id == msgId) m.copyWith(read: true) else m,
          ]);
          break;
        case WsEventServer.transcriptReady:
          final id = event.data['message_id'] as String;
          final transcript = event.data['transcript'] as String?;
          final current = state.value ?? [];
          state = AsyncData([
            for (final m in current)
              if (m.id == id)
                m.copyWith(transcript: transcript, transcriptStatus: TranscriptStatus.completed)
              else
                m,
          ]);
          break;
        default:
          break;
      }
    });
    ref.onDispose(sub.cancel);
  }

  Future<void> sendText(String text) async {
    if (text.trim().isEmpty) return;
    final msg = await ref.read(chatRepositoryProvider).sendText(arg, text);
    _insert(msg);
  }

  Future<void> sendUpload({
    required List<int> bytes,
    required String filename,
    String? contentType,
  }) async {
    final msg = await ref.read(chatRepositoryProvider).uploadFile(
          conversationId: arg,
          bytes: bytes,
          filename: filename,
          contentType: contentType,
        );
    _insert(msg);
  }

  void _insert(Message msg) {
    final current = state.value ?? [];
    // If WS already pushed it, don't duplicate.
    if (current.any((m) => m.id == msg.id)) return;
    state = AsyncData([msg, ...current]);
  }
}

final messagesProvider =
    AsyncNotifierProvider.family<MessagesNotifier, List<Message>, String>(MessagesNotifier.new);

/// True when the *other* participant is currently typing in this conversation.
/// Auto-clears after 5s in case a typing_stop event is dropped.
class TypingNotifier extends FamilyNotifier<bool, String> {
  Timer? _clear;

  @override
  bool build(String conversationId) {
    final me = ref.read(authProvider).user?.id;
    final ws = ref.read(websocketClientProvider);
    final sub = ws.events.listen((event) {
      if (event.type != WsEventServer.typingStart &&
          event.type != WsEventServer.typingStop) {
        return;
      }
      final convId = event.data['conversation_id'] as String?;
      final uid = event.data['user_id'] as String?;
      if (convId != conversationId || uid == me) return;
      if (event.type == WsEventServer.typingStart) {
        state = true;
        _clear?.cancel();
        _clear = Timer(const Duration(seconds: 6), () => state = false);
      } else {
        _clear?.cancel();
        state = false;
      }
    });
    ref.onDispose(() {
      _clear?.cancel();
      sub.cancel();
    });
    return false;
  }
}

final typingProvider =
    NotifierProvider.family<TypingNotifier, bool, String>(TypingNotifier.new);
