import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/providers.dart';
import '../core/enums/app_enums.dart';
import '../data/models/conversation.dart';
import '../data/models/message.dart';

final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  return ref.read(chatRepositoryProvider).listConversations();
});

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
    final current = state.value ?? [];
    // If WS already pushed it, don't duplicate.
    if (current.any((m) => m.id == msg.id)) return;
    state = AsyncData([msg, ...current]);
  }
}

final messagesProvider =
    AsyncNotifierProvider.family<MessagesNotifier, List<Message>, String>(MessagesNotifier.new);
