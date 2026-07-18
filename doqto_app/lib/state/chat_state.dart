import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/di/providers.dart';
import '../core/enums/app_enums.dart';
import '../data/api/websocket_client.dart';
import '../data/models/conversation.dart';
import '../data/models/message.dart';
import '../data/services/outbox.dart';
import 'auth_state.dart';

/// Conversation list that live-updates: re-fetches in place (no loading flash)
/// whenever a message is sent/received or read state changes. Cache-first so
/// a cold start offline still shows the list.
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
    // Gap recovery: a reconnect means events were missed — refetch.
    final stateSub = ws.states.listen((s) {
      if (s == WsConnState.connected) refresh();
    });
    ref.onDispose(sub.cancel);
    ref.onDispose(stateSub.cancel);

    final cache = ref.read(chatCacheProvider);
    final cached = cache.conversations();
    if (cached != null) state = AsyncData(cached); // instant paint offline
    try {
      final fresh = await ref.read(chatRepositoryProvider).listConversations();
      await cache.putConversations(fresh);
      return fresh;
    } catch (_) {
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<void> refresh() async {
    try {
      final list = await ref.read(chatRepositoryProvider).listConversations();
      await ref.read(chatCacheProvider).putConversations(list);
      state = AsyncData(list); // stays on previous data until this resolves → no flash
    } catch (_) {
      // Offline refresh: keep showing what we have.
    }
  }
}

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<Conversation>>(
        ConversationsNotifier.new);

class MessagesNotifier extends FamilyAsyncNotifier<List<Message>, String> {
  /// Older-page cursor state (read by the thread screen for the spinner row).
  bool hasMore = true;
  bool loadingOlder = false;

  @override
  Future<List<Message>> build(String conversationId) async {
    _listenWs(conversationId);

    final cache = ref.read(chatCacheProvider);
    final pending = _pendingAsMessages(conversationId);
    final cached = cache.messages(conversationId);
    if (cached != null) state = AsyncData([...pending, ...cached]);

    try {
      final msgs =
          await ref.read(chatRepositoryProvider).listMessages(conversationId);
      hasMore = msgs.length >= AppConstants.messagesPageSize;
      await cache.putMessages(conversationId, msgs);
      return [...pending, ...msgs];
    } catch (_) {
      if (cached != null) return [...pending, ...cached];
      rethrow;
    }
  }

  /// Unsent outbox entries for this conversation, shown as clock-tick bubbles
  /// (they survive app restarts).
  List<Message> _pendingAsMessages(String conversationId) {
    final me = ref.read(authProvider).user?.id;
    if (me == null) return const [];
    final entries = ref
        .read(outboxProvider)
        .pending(conversationId: conversationId)
        .reversed; // newest first, matching list order
    return [
      for (final e in entries)
        Message.pending(
          clientId: e.clientId,
          conversationId: e.conversationId,
          senderId: me,
          content: e.content,
        ),
    ];
  }

  void _listenWs(String conversationId) {
    final ws = ref.read(websocketClientProvider);
    final sub = ws.events.listen((event) {
      switch (event.type) {
        case WsEventServer.newMessage:
          final msg = Message.fromJson(event.data);
          if (msg.conversationId == conversationId) _insert(msg);
          break;
        case WsEventServer.messageDelivered:
          // Conversation-level ack: flip gray double-checks on own messages.
          if (event.data['conversation_id'] != conversationId) break;
          state = AsyncData([
            for (final m in state.value ?? <Message>[]) m.copyWith(delivered: true),
          ]);
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
    // Gap recovery: refetch page 1 on reconnect and merge (dedup by id).
    final stateSub = ws.states.listen((s) {
      if (s == WsConnState.connected) _refetchLatest(conversationId);
    });
    ref.onDispose(sub.cancel);
    ref.onDispose(stateSub.cancel);
  }

  Future<void> _refetchLatest(String conversationId) async {
    try {
      final fresh =
          await ref.read(chatRepositoryProvider).listMessages(conversationId);
      final current = state.value ?? [];
      final freshIds = {for (final m in fresh) m.id};
      // Keep what the page doesn't cover: pending/failed bubbles and older pages.
      final keep = current.where((m) => !freshIds.contains(m.id));
      final merged = [...keep, ...fresh]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = AsyncData(merged);
      await ref.read(chatCacheProvider).putMessages(conversationId, fresh);
    } catch (_) {}
  }

  Future<void> sendText(String text) async {
    final content = text.trim();
    if (content.isEmpty) return;
    final me = ref.read(authProvider).user?.id;
    if (me == null) return;

    // 1. Durably queue + optimistic bubble BEFORE any network I/O — a dead
    //    network can no longer lose the message.
    final entry = OutboxEntry(
      clientId: uuidV4(),
      conversationId: arg,
      content: content,
      createdAt: DateTime.now().toUtc(),
    );
    await ref.read(outboxProvider).add(entry);
    _insert(Message.pending(
      clientId: entry.clientId,
      conversationId: arg,
      senderId: me,
      content: content,
    ));

    // 2. Attempt delivery.
    await _deliver(entry);
  }

  /// Send one outbox entry; replace the pending bubble on success, mark it
  /// failed on error. Safe to call twice — the server dedups by client_id.
  Future<void> _deliver(OutboxEntry entry) async {
    try {
      final msg = await ref.read(chatRepositoryProvider).sendText(
            entry.conversationId,
            entry.content,
            clientId: entry.clientId,
          );
      await ref.read(outboxProvider).remove(entry.clientId);
      _insert(msg);
    } catch (_) {
      _setStatus(entry.clientId, MessageStatus.failed);
    }
  }

  /// Tap-to-retry on a failed bubble.
  Future<void> retry(String clientId) async {
    final entry = ref
        .read(outboxProvider)
        .pending(conversationId: arg)
        .where((e) => e.clientId == clientId)
        .firstOrNull;
    if (entry == null) return;
    _setStatus(clientId, MessageStatus.sending);
    await _deliver(entry);
  }

  /// Discard a failed message entirely.
  Future<void> discard(String clientId) async {
    await ref.read(outboxProvider).remove(clientId);
    final current = state.value ?? [];
    state = AsyncData([...current.where((m) => m.clientId != clientId)]);
  }

  void _setStatus(String clientId, MessageStatus status) {
    final current = state.value ?? [];
    state = AsyncData([
      for (final m in current)
        if (m.clientId == clientId) m.copyWith(status: status) else m,
    ]);
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

  /// Load the next older page (cursor = oldest fetched message).
  Future<void> loadOlder() async {
    if (!hasMore || loadingOlder) return;
    final current = state.value ?? [];
    final oldest =
        current.where((m) => m.status == MessageStatus.sent).lastOrNull;
    if (oldest == null) return;
    loadingOlder = true;
    try {
      final older = await ref
          .read(chatRepositoryProvider)
          .listMessages(arg, before: oldest.createdAt);
      hasMore = older.length >= AppConstants.messagesPageSize;
      final ids = {for (final m in current) m.id};
      state =
          AsyncData([...current, ...older.where((m) => !ids.contains(m.id))]);
    } catch (_) {
      // Scroll again to retry.
    } finally {
      loadingOlder = false;
      // Nudge listeners so the spinner row rebuilds even on failure.
      state = AsyncData([...(state.value ?? [])]);
    }
  }

  void _insert(Message msg) {
    final current = state.value ?? [];
    // Replace the optimistic bubble once the server row exists (matched by
    // client_id — covers both the POST response and the WS broadcast).
    if (msg.clientId != null && current.any((m) => m.clientId == msg.clientId)) {
      state = AsyncData([
        for (final m in current)
          if (m.clientId == msg.clientId) msg else m,
      ]);
      return;
    }
    // If WS already pushed it, don't duplicate.
    if (current.any((m) => m.id == msg.id)) return;
    state = AsyncData([msg, ...current]);
  }
}

final messagesProvider =
    AsyncNotifierProvider.family<MessagesNotifier, List<Message>, String>(MessagesNotifier.new);

/// Drains the outbox whenever the socket (re)connects and once on app start.
/// Successful sends reach open threads via the WS broadcast (matched by
/// client_id); server-side idempotency makes overlapping retries harmless.
final outboxDrainerProvider = Provider<void>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  final outbox = ref.watch(outboxProvider);

  Future<void> drain() async {
    for (final e in outbox.pending()) {
      try {
        await repo.sendText(e.conversationId, e.content, clientId: e.clientId);
        await outbox.remove(e.clientId);
      } catch (_) {
        return; // still offline — stop; next reconnect retries
      }
    }
  }

  final sub = ref.watch(websocketClientProvider).states.listen((s) {
    if (s == WsConnState.connected) drain();
  });
  ref.onDispose(sub.cancel);
  drain(); // app start
});

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
