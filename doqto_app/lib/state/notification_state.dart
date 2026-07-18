import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/di/providers.dart';
import '../core/enums/app_enums.dart';
import '../core/router/app_router.dart';
import '../data/models/conversation.dart';
import '../data/services/notification_service.dart';
import 'auth_state.dart';
import 'chat_state.dart';

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

/// Conversation currently open in ChatThreadScreen (null = none).
/// Set/cleared by the thread screen so we don't notify for the visible chat.
final activeConversationProvider = StateProvider<String?>((ref) => null);

/// App-wide listener: turns incoming WS messages into banner notifications.
/// Activate once by watching it from the root widget.
final notificationListenerProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);
  service.init(onTap: (conversationId) {
    ref.read(routerProvider).push(AppRoutes.chat(conversationId));
  });

  final sub = ref.watch(websocketClientProvider).events.listen((event) async {
    if (event.type != WsEventServer.newMessage) return;

    final me = ref.read(authProvider).user;
    final senderId = event.data['sender_id'] as String?;
    final conversationId = event.data['conversation_id'] as String?;
    if (conversationId == null || senderId == null || senderId == me?.id) {
      return;
    }
    // Ack receipt → sender sees the gray double-check. WS fanout is
    // conversation-scoped, so any event here is for a chat I'm in.
    ref
        .read(chatRepositoryProvider)
        .markConversationDelivered(conversationId)
        .catchError((_) {});

    final wireType = (event.data['type'] ?? '') as String;
    if (wireType == MessageType.system.wire) return; // settings banners etc.
    final msgType =
        MessageType.values.where((t) => t.wire == wireType).firstOrNull ??
            MessageType.text;

    // Don't notify for the chat the user is looking at right now.
    final appActive =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (appActive &&
        ref.read(activeConversationProvider) == conversationId) {
      return;
    }

    // WS events are org-wide — only notify if I'm actually a member of this
    // conversation (my conversation list only contains my own).
    var convs = ref.read(conversationsProvider).asData?.value;
    Conversation? conv =
        convs?.where((c) => c.id == conversationId).firstOrNull;
    if (conv == null) {
      // Possibly a brand-new conversation — refetch once.
      try {
        convs = await ref.read(chatRepositoryProvider).listConversations();
        conv = convs.where((c) => c.id == conversationId).firstOrNull;
      } catch (_) {
        return;
      }
    }
    if (conv == null) return;

    final title = conv.displayName ?? conv.name ?? 'New message';
    // H3: previews are acceptable only because these banners are
    // foreground-only local notifications (device unlocked, app open). Any
    // future lock-screen or remote path must flip showMessagePreviews to
    // false by default. Non-text kinds (and the null-content fallback)
    // always show a generic label — never raw content.
    final body = !AppConstants.showMessagePreviews
        ? 'New message'
        : switch (msgType) {
            MessageType.voiceNote => '🎤 Voice note',
            MessageType.image => '📷 Photo',
            MessageType.file => '📎 File',
            _ => (event.data['content'] as String?) ?? 'New message',
          };
    await ref.read(notificationServiceProvider).showMessage(
          conversationId: conversationId,
          title: title,
          body: body,
        );
  });
  ref.onDispose(sub.cancel);
});
