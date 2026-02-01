/// ============================================================================
/// MESSAGING PROVIDERS - Riverpod State Management
/// ============================================================================
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/socket_service.dart';
import '../../data/models/messaging_models.dart';
import '../../data/repositories/messaging_repository.dart';

export '../../data/repositories/messaging_repository.dart' show GroupEvent, GroupEventType;

// ============================================================================
// REPOSITORY PROVIDER
// ============================================================================

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  return MessagingRepository();
});

// ============================================================================
// CONVERSATIONS STATE
// ============================================================================

class ConversationsState {
  final bool isLoading;
  final List<ConversationModel> conversations;
  final int totalUnreadCount;
  final String? errorMessage;
  final Map<String, bool> typingIndicators; // conversationId -> isTyping

  const ConversationsState({
    this.isLoading = false,
    this.conversations = const [],
    this.totalUnreadCount = 0,
    this.errorMessage,
    this.typingIndicators = const {},
  });

  ConversationsState copyWith({
    bool? isLoading,
    List<ConversationModel>? conversations,
    int? totalUnreadCount,
    String? errorMessage,
    Map<String, bool>? typingIndicators,
  }) {
    return ConversationsState(
      isLoading: isLoading ?? this.isLoading,
      conversations: conversations ?? this.conversations,
      totalUnreadCount: totalUnreadCount ?? this.totalUnreadCount,
      errorMessage: errorMessage,
      typingIndicators: typingIndicators ?? this.typingIndicators,
    );
  }

  /// Check if someone is typing in a conversation
  bool isTypingIn(String conversationId) {
    return typingIndicators[conversationId] == true;
  }

  List<ConversationModel> get pinnedConversations =>
      conversations.where((c) => c.isPinned).toList();

  List<ConversationModel> get regularConversations =>
      conversations.where((c) => !c.isPinned && !c.isArchived).toList();

  List<ConversationModel> get archivedConversations =>
      conversations.where((c) => c.isArchived).toList();
}

class ConversationsNotifier extends Notifier<ConversationsState> {
  late final MessagingRepository _repository;
  StreamSubscription<Map<String, dynamic>>? _conversationSubscription;
  StreamSubscription<MessageEvent>? _newMessageSubscription;
  StreamSubscription<TypingEvent>? _typingSubscription;
  StreamSubscription<GroupEvent>? _groupEventSubscription;
  final Map<String, Timer> _typingTimers = {};

  @override
  ConversationsState build() {
    _repository = ref.watch(messagingRepositoryProvider);

    // Auto-load, connect realtime, and subscribe
    Future.microtask(() async {
      // Connect to Socket.io for real-time features
      await _repository.connectRealtime();
      loadConversations();
      _subscribeToUpdates();
    });

    // Cleanup on dispose
    ref.onDispose(() {
      _conversationSubscription?.cancel();
      _newMessageSubscription?.cancel();
      _typingSubscription?.cancel();
      _groupEventSubscription?.cancel();
      for (final timer in _typingTimers.values) {
        timer.cancel();
      }
      _typingTimers.clear();
      _repository.disconnectRealtime();
    });

    return const ConversationsState(isLoading: true);
  }

  void _subscribeToUpdates() {
    try {
      // Subscribe to conversation updates via Socket.io
      _conversationSubscription = _repository.onConversationUpdated.listen((_) {
        loadConversations();
      });

      // Subscribe to new messages to update chat list in real-time
      _newMessageSubscription = _repository.onNewMessage.listen((event) {
        _handleNewMessage(event);
      });

      // Subscribe to typing events for chat list typing indicator
      _typingSubscription = _repository.onTyping.listen((event) {
        _handleTypingEvent(event);
      });

      // Subscribe to group events
      _groupEventSubscription = _repository.onGroupEvent.listen((event) {
        _handleGroupEvent(event);
      });
    } catch (e) {
      // Ignore subscription errors
    }
  }

  void _handleGroupEvent(GroupEvent event) {
    // Reload conversations for any group event to update the list
    switch (event.type) {
      case GroupEventType.created:
      case GroupEventType.updated:
      case GroupEventType.membersAdded:
      case GroupEventType.memberRemoved:
      case GroupEventType.memberLeft:
      case GroupEventType.adminChanged:
        loadConversations();
        break;
      case GroupEventType.removedFromGroup:
        // Remove the group from our list
        final updatedList = state.conversations
            .where((c) => c.conversationId != event.groupId)
            .toList();
        state = state.copyWith(conversations: updatedList);
        break;
    }
  }

  void _handleTypingEvent(TypingEvent event) {
    final conversationId = event.conversationId;
    final isTyping = event.isTyping;

    // Don't show typing indicator for our own typing
    if (event.userId == _repository.currentUserId) return;

    // Cancel existing timer for this conversation
    _typingTimers[conversationId]?.cancel();

    // Update typing indicators map
    final updatedIndicators = Map<String, bool>.from(state.typingIndicators);

    if (isTyping) {
      updatedIndicators[conversationId] = true;

      // Auto-clear after 5 seconds (in case stop event is missed)
      _typingTimers[conversationId] = Timer(const Duration(seconds: 5), () {
        final indicators = Map<String, bool>.from(state.typingIndicators);
        indicators.remove(conversationId);
        state = state.copyWith(typingIndicators: indicators);
      });
    } else {
      updatedIndicators.remove(conversationId);
    }

    state = state.copyWith(typingIndicators: updatedIndicators);
  }

  void _handleNewMessage(MessageEvent event) {
    final conversationId = event.conversationId;
    final message = event.message;
    final currentUserId = _repository.currentUserId;

    // Clear typing indicator for this conversation (they sent a message, so no longer typing)
    if (state.typingIndicators.containsKey(conversationId)) {
      _typingTimers[conversationId]?.cancel();
      final updatedIndicators = Map<String, bool>.from(state.typingIndicators);
      updatedIndicators.remove(conversationId);
      state = state.copyWith(typingIndicators: updatedIndicators);
    }

    // Find the conversation in our list
    final existingIndex = state.conversations.indexWhere(
      (c) => c.conversationId == conversationId,
    );

    if (existingIndex == -1) {
      // New conversation - reload all to get full data
      loadConversations();
      return;
    }

    // Update the existing conversation
    final existingConv = state.conversations[existingIndex];
    final isFromOther = message['sender_id'] != currentUserId;

    // Create updated conversation with new message info
    final updatedConv = existingConv.copyWith(
      lastMessageText: message['content'] as String? ?? _getMessagePreview(message),
      lastMessageType: _parseMessageType(message['message_type'] as String?),
      lastMessageAt: DateTime.tryParse(message['created_at'] as String? ?? '') ?? DateTime.now(),
      lastMessageSenderId: message['sender_id'] as String?,
      unreadCount: isFromOther ? existingConv.unreadCount + 1 : existingConv.unreadCount,
    );

    // Remove from current position and add to top (most recent)
    final updatedList = List<ConversationModel>.from(state.conversations);
    updatedList.removeAt(existingIndex);

    // Insert at top (after pinned conversations)
    final firstNonPinnedIndex = updatedList.indexWhere((c) => !c.isPinned);
    if (updatedConv.isPinned || firstNonPinnedIndex == -1) {
      updatedList.insert(0, updatedConv);
    } else {
      updatedList.insert(firstNonPinnedIndex, updatedConv);
    }

    // Update total unread count
    final newUnreadCount = isFromOther
        ? state.totalUnreadCount + 1
        : state.totalUnreadCount;

    state = state.copyWith(
      conversations: updatedList,
      totalUnreadCount: newUnreadCount,
    );
  }

  String _getMessagePreview(Map<String, dynamic> message) {
    final type = message['message_type'] as String?;
    switch (type) {
      case 'audio':
        return 'Voice message';
      case 'image':
        return 'Photo';
      case 'document':
        return 'Document';
      default:
        return message['content'] as String? ?? '';
    }
  }

  MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'audio':
        return MessageType.audio;
      case 'image':
        return MessageType.image;
      case 'document':
        return MessageType.document;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: state.conversations.isEmpty, errorMessage: null);

    try {
      final conversations = await _repository.getConversations();
      final unreadCount = await _repository.getTotalUnreadCount();

      state = state.copyWith(
        isLoading: false,
        conversations: conversations,
        totalUnreadCount: unreadCount,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load conversations: ${e.toString()}',
      );
    }
  }

  Future<String?> startConversation(String otherUserId) async {
    try {
      final conversationId = await _repository.getOrCreateConversation(otherUserId);
      await loadConversations();
      return conversationId;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().contains('Cannot message')
            ? 'Cannot message this user'
            : 'Failed to start conversation',
      );
      return null;
    }
  }

  Future<bool> deleteConversation(String conversationId) async {
    try {
      final success = await _repository.deleteConversation(conversationId);
      if (success) {
        await loadConversations();
      }
      return success;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to delete conversation');
      return false;
    }
  }

  Future<bool> updateSettings({
    required String conversationId,
    bool? muted,
    bool? archived,
    bool? pinned,
    int? disappearingHours,
  }) async {
    try {
      final success = await _repository.updateConversationSettings(
        conversationId: conversationId,
        muted: muted,
        archived: archived,
        pinned: pinned,
        disappearingHours: disappearingHours,
      );

      if (success) {
        await loadConversations();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Mark a conversation as read (clear unread count locally)
  void markConversationAsRead(String conversationId) {
    final existingIndex = state.conversations.indexWhere(
      (c) => c.conversationId == conversationId,
    );

    if (existingIndex == -1) return;

    final existingConv = state.conversations[existingIndex];
    if (existingConv.unreadCount == 0) return;

    // Update unread count to 0
    final updatedConv = existingConv.copyWith(unreadCount: 0);

    final updatedList = List<ConversationModel>.from(state.conversations);
    updatedList[existingIndex] = updatedConv;

    // Update total unread count
    final newTotalUnread = state.totalUnreadCount - existingConv.unreadCount;

    state = state.copyWith(
      conversations: updatedList,
      totalUnreadCount: newTotalUnread < 0 ? 0 : newTotalUnread,
    );
  }
}

final conversationsProvider =
    NotifierProvider<ConversationsNotifier, ConversationsState>(() {
  return ConversationsNotifier();
});

// ============================================================================
// CHAT STATE (Single conversation messages)
// ============================================================================

class ChatState {
  final bool isLoading;
  final bool isSending;
  final String? conversationId;
  final ConversationModel? conversation;
  final List<MessageModel> messages;
  final String? errorMessage;
  final bool hasMore;
  final bool isOtherUserTyping;
  final String? typingUserId; // Track WHO is typing

  const ChatState({
    this.isLoading = false,
    this.isSending = false,
    this.conversationId,
    this.conversation,
    this.messages = const [],
    this.errorMessage,
    this.hasMore = true,
    this.isOtherUserTyping = false,
    this.typingUserId,
  });

  ChatState copyWith({
    bool? isLoading,
    bool? isSending,
    String? conversationId,
    ConversationModel? conversation,
    List<MessageModel>? messages,
    String? errorMessage,
    bool? hasMore,
    bool? isOtherUserTyping,
    String? typingUserId,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      conversationId: conversationId ?? this.conversationId,
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      errorMessage: errorMessage,
      hasMore: hasMore ?? this.hasMore,
      isOtherUserTyping: isOtherUserTyping ?? this.isOtherUserTyping,
      typingUserId: typingUserId ?? this.typingUserId,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  late final MessagingRepository _repository;
  StreamSubscription<MessageEvent>? _newMessageSubscription;
  StreamSubscription<MessageStatusEvent>? _messageStatusSubscription;
  StreamSubscription<MessagesReadEvent>? _messagesReadSubscription;
  StreamSubscription<TypingEvent>? _typingSubscription;
  Timer? _typingTimer;

  @override
  ChatState build() {
    _repository = ref.watch(messagingRepositoryProvider);

    ref.onDispose(() {
      _cancelSubscriptions();
    });

    return const ChatState();
  }

  void _cancelSubscriptions() {
    _newMessageSubscription?.cancel();
    _messageStatusSubscription?.cancel();
    _messagesReadSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingTimer?.cancel();
    _newMessageSubscription = null;
    _messageStatusSubscription = null;
    _messagesReadSubscription = null;
    _typingSubscription = null;
    _typingTimer = null;
  }

  Future<void> loadChat(String conversationId) async {
    // Cancel previous subscriptions
    _cancelSubscriptions();

    // Leave previous conversation room
    if (state.conversationId != null && state.conversationId != conversationId) {
      _repository.leaveConversation(state.conversationId!);
    }

    state = state.copyWith(
      isLoading: true,
      conversationId: conversationId,
      messages: [],
      errorMessage: null,
    );

    try {
      // Load conversation and messages
      final conversation = await _repository.getConversation(conversationId);
      final messages = await _repository.getMessages(conversationId);

      // Get the actual conversation ID (in case we passed a user UUID)
      final actualConversationId = conversation?.conversationId ?? conversationId;

      // Mark as read
      await _repository.markMessagesRead(actualConversationId);

      // Update conversation list to clear unread count
      ref.read(conversationsProvider.notifier).markConversationAsRead(actualConversationId);

      state = state.copyWith(
        isLoading: false,
        conversationId: actualConversationId, // Use actual conversation ID
        conversation: conversation,
        messages: messages,
        hasMore: messages.length >= 50,
      );

      // Join conversation room and subscribe to new messages
      _repository.joinConversation(actualConversationId);
      _subscribeToMessages(actualConversationId);

      // Refresh conversations list to update unread count
      ref.read(conversationsProvider.notifier).loadConversations();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load chat: ${e.toString()}',
      );
    }
  }

  void _subscribeToMessages(String conversationId) {
    // Subscribe to new messages via Socket.io
    _newMessageSubscription = _repository.onNewMessage.listen((event) {
      if (event.conversationId == conversationId) {
        final message = MessageModel.fromJson(event.message);

        // Check if message already exists (sender already added it locally)
        final messageExists = state.messages.any((m) => m.id == message.id);
        if (messageExists) return;

        // Add new message to the list (newest first for reverse ListView)
        final updatedMessages = [message, ...state.messages];

        // Clear typing indicator if the message is from the user who was typing
        final clearTyping = state.typingUserId == message.senderId;
        state = state.copyWith(
          messages: updatedMessages,
          isOtherUserTyping: clearTyping ? false : state.isOtherUserTyping,
          typingUserId: clearTyping ? null : state.typingUserId,
        );

        // Mark as read if from other user
        if (message.senderId != _repository.currentUserId) {
          _repository.markMessagesRead(conversationId);
        }
      }
    });

    // Subscribe to message status updates
    _messageStatusSubscription = _repository.onMessageStatusUpdate.listen((event) {
      // Update existing message status
      final updatedMessages = state.messages.map((m) {
        if (m.id == event.messageId) {
          return m.copyWith(
            status: _parseMessageStatus(event.status),
          );
        }
        return m;
      }).toList();
      state = state.copyWith(messages: updatedMessages);
    });

    // Subscribe to messages read events (for read receipts / double tick)
    _messagesReadSubscription = _repository.onMessagesRead.listen((event) {
      if (event.conversationId == conversationId) {
        // Update all messages that were read to show double tick
        final updatedMessages = state.messages.map((m) {
          if (event.messageIds.contains(m.id)) {
            return m.copyWith(status: MessageStatus.read);
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updatedMessages);
      }
    });

    // Subscribe to typing events
    _typingSubscription = _repository.onTyping.listen((event) {
      if (event.conversationId == conversationId &&
          event.userId != _repository.currentUserId) {
        state = state.copyWith(
          isOtherUserTyping: event.isTyping,
          typingUserId: event.isTyping ? event.userId : null,
        );

        // Auto-clear typing indicator after 5 seconds (in case stop event is missed)
        if (event.isTyping) {
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 5), () {
            state = state.copyWith(
              isOtherUserTyping: false,
              typingUserId: null,
            );
          });
        } else {
          _typingTimer?.cancel();
        }
      }
    });
  }

  MessageStatus _parseMessageStatus(String status) {
    switch (status) {
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      case 'sending':
        return MessageStatus.sending;
      default:
        return MessageStatus.sent;
    }
  }

  Future<void> loadMoreMessages() async {
    if (!state.hasMore || state.isLoading || state.conversationId == null) return;

    final oldestMessage = state.messages.isNotEmpty ? state.messages.last : null;

    try {
      final moreMessages = await _repository.getMessages(
        state.conversationId!,
        before: oldestMessage?.id, // Use message ID, not DateTime
      );

      state = state.copyWith(
        messages: [...state.messages, ...moreMessages],
        hasMore: moreMessages.length >= 50,
      );
    } catch (e) {
      // Ignore pagination errors
    }
  }

  Future<bool> sendMessage(String content, {List<String>? mentions}) async {
    if (state.conversationId == null || content.trim().isEmpty) return false;

    state = state.copyWith(isSending: true);

    try {
      final message = await _repository.sendMessage(
        conversationId: state.conversationId!,
        content: content.trim(),
        mentions: mentions,
      );

      // Add sent message to the list immediately (newest first for reverse ListView)
      // Check if already exists (from Socket.io) to avoid duplicates
      final messageExists = state.messages.any((m) => m.id == message.id);
      if (!messageExists) {
        final updatedMessages = [message, ...state.messages];
        state = state.copyWith(isSending: false, messages: updatedMessages);
      } else {
        state = state.copyWith(isSending: false);
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Failed to send message',
      );
      return false;
    }
  }

  Future<bool> sendAudioMessage({
    required String fileUrl,
    required int durationSeconds,
    String? fileName,
    int? fileSize,
  }) async {
    if (state.conversationId == null) return false;

    state = state.copyWith(isSending: true);

    try {
      final message = await _repository.sendAudioMessage(
        conversationId: state.conversationId!,
        fileUrl: fileUrl,
        durationSeconds: durationSeconds,
        fileName: fileName,
        fileSize: fileSize,
      );

      // Add sent message to the list (check for duplicates)
      final messageExists = state.messages.any((m) => m.id == message.id);
      if (!messageExists) {
        final updatedMessages = [message, ...state.messages];
        state = state.copyWith(isSending: false, messages: updatedMessages);
      } else {
        state = state.copyWith(isSending: false);
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Failed to send audio message',
      );
      return false;
    }
  }

  Future<bool> sendImageMessage({
    required String fileUrl,
    String? fileName,
    int? fileSize,
  }) async {
    if (state.conversationId == null) return false;

    state = state.copyWith(isSending: true);

    try {
      final message = await _repository.sendImageMessage(
        conversationId: state.conversationId!,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: fileSize,
      );

      // Add sent message to the list (check for duplicates)
      final messageExists = state.messages.any((m) => m.id == message.id);
      if (!messageExists) {
        final updatedMessages = [message, ...state.messages];
        state = state.copyWith(isSending: false, messages: updatedMessages);
      } else {
        state = state.copyWith(isSending: false);
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        errorMessage: 'Failed to send image',
      );
      return false;
    }
  }

  Future<bool> saveAudioMessage(String messageId) async {
    try {
      final success = await _repository.saveAudioMessage(messageId);
      if (success) {
        // Update message in state
        final updatedMessages = state.messages.map((m) {
          if (m.id == messageId) {
            return m.copyWith(
              savedBy: _repository.currentUserId,
              savedAt: DateTime.now(),
            );
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updatedMessages);
      }
      return success;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().contains('does not allow')
            ? 'User does not allow saving audio messages'
            : 'Failed to save audio message',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void clear() {
    _cancelSubscriptions();
    if (state.conversationId != null) {
      _repository.leaveConversation(state.conversationId!);
    }
    state = const ChatState();
  }

  /// Emit typing indicator start
  void startTyping() {
    if (state.conversationId != null) {
      _repository.startTyping(state.conversationId!);
    }
  }

  /// Emit typing indicator stop
  void stopTyping() {
    if (state.conversationId != null) {
      _repository.stopTyping(state.conversationId!);
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(() {
  return ChatNotifier();
});

// ============================================================================
// BLOCKED USERS STATE
// ============================================================================

class BlockedUsersState {
  final bool isLoading;
  final List<BlockedUserModel> blockedUsers;
  final String? errorMessage;

  const BlockedUsersState({
    this.isLoading = false,
    this.blockedUsers = const [],
    this.errorMessage,
  });

  BlockedUsersState copyWith({
    bool? isLoading,
    List<BlockedUserModel>? blockedUsers,
    String? errorMessage,
  }) {
    return BlockedUsersState(
      isLoading: isLoading ?? this.isLoading,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      errorMessage: errorMessage,
    );
  }
}

class BlockedUsersNotifier extends Notifier<BlockedUsersState> {
  late final MessagingRepository _repository;

  @override
  BlockedUsersState build() {
    _repository = ref.watch(messagingRepositoryProvider);
    return const BlockedUsersState();
  }

  Future<void> loadBlockedUsers() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final blocked = await _repository.getBlockedUsers();
      state = state.copyWith(isLoading: false, blockedUsers: blocked);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load blocked users',
      );
    }
  }

  Future<bool> blockUser(String userId, {String? reason}) async {
    try {
      final success = await _repository.blockUser(userId, reason: reason);
      if (success) {
        await loadBlockedUsers();
        // Refresh conversations
        ref.read(conversationsProvider.notifier).loadConversations();
      }
      return success;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to block user');
      return false;
    }
  }

  Future<bool> unblockUser(String userId) async {
    try {
      final success = await _repository.unblockUser(userId);
      if (success) {
        await loadBlockedUsers();
        ref.read(conversationsProvider.notifier).loadConversations();
      }
      return success;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to unblock user');
      return false;
    }
  }

  Future<bool> reportUser({
    required String userId,
    required String reason,
    String? description,
    String? messageId,
  }) async {
    try {
      final success = await _repository.reportUser(
        userId: userId,
        reason: reason,
        description: description,
        messageId: messageId,
      );
      return success;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to submit report');
      return false;
    }
  }
}

final blockedUsersProvider =
    NotifierProvider<BlockedUsersNotifier, BlockedUsersState>(() {
  return BlockedUsersNotifier();
});

// ============================================================================
// MESSAGING PREFERENCES STATE
// ============================================================================

class MessagingPrefsState {
  final bool isLoading;
  final MessagingPreferencesModel? preferences;
  final String? errorMessage;

  const MessagingPrefsState({
    this.isLoading = false,
    this.preferences,
    this.errorMessage,
  });

  MessagingPrefsState copyWith({
    bool? isLoading,
    MessagingPreferencesModel? preferences,
    String? errorMessage,
  }) {
    return MessagingPrefsState(
      isLoading: isLoading ?? this.isLoading,
      preferences: preferences ?? this.preferences,
      errorMessage: errorMessage,
    );
  }
}

class MessagingPrefsNotifier extends Notifier<MessagingPrefsState> {
  late final MessagingRepository _repository;

  @override
  MessagingPrefsState build() {
    _repository = ref.watch(messagingRepositoryProvider);
    Future.microtask(() => loadPreferences());
    return const MessagingPrefsState(isLoading: true);
  }

  Future<void> loadPreferences() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final prefs = await _repository.getMessagingPreferences();
      state = state.copyWith(isLoading: false, preferences: prefs);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load preferences',
      );
    }
  }

  Future<bool> updatePreferences(MessagingPreferencesModel prefs) async {
    try {
      final success = await _repository.updateMessagingPreferences(prefs);
      if (success) {
        state = state.copyWith(preferences: prefs);
      }
      return success;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to update preferences');
      return false;
    }
  }

  Future<bool> setAllowAudioSave(bool allow) async {
    if (state.preferences == null) return false;

    final updatedPrefs = state.preferences!.copyWith(allowAudioSave: allow);
    return updatePreferences(updatedPrefs);
  }

  Future<bool> setDefaultDisappearingHours(int? hours) async {
    if (state.preferences == null) return false;

    final updatedPrefs = state.preferences!.copyWith(defaultDisappearingHours: hours);
    return updatePreferences(updatedPrefs);
  }

  Future<bool> setReadReceipts(bool enabled) async {
    if (state.preferences == null) return false;

    final updatedPrefs = state.preferences!.copyWith(readReceiptsEnabled: enabled);
    return updatePreferences(updatedPrefs);
  }

  Future<bool> setNotifications(bool enabled) async {
    if (state.preferences == null) return false;

    final updatedPrefs = state.preferences!.copyWith(messageNotifications: enabled);
    return updatePreferences(updatedPrefs);
  }
}

final messagingPrefsProvider =
    NotifierProvider<MessagingPrefsNotifier, MessagingPrefsState>(() {
  return MessagingPrefsNotifier();
});

// ============================================================================
// GROUP STATE
// ============================================================================

class GroupState {
  final bool isLoading;
  final String? errorMessage;

  const GroupState({
    this.isLoading = false,
    this.errorMessage,
  });

  GroupState copyWith({
    bool? isLoading,
    String? errorMessage,
  }) {
    return GroupState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class GroupNotifier extends Notifier<GroupState> {
  late final MessagingRepository _repository;

  @override
  GroupState build() {
    _repository = ref.watch(messagingRepositoryProvider);
    return const GroupState();
  }

  /// Create a new group
  Future<ConversationModel?> createGroup({
    required String name,
    required List<String> participantIds,
    String? description,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final group = await _repository.createGroup(
        name: name,
        participantIds: participantIds,
        description: description,
      );

      state = state.copyWith(isLoading: false);

      // Refresh conversations list
      ref.read(conversationsProvider.notifier).loadConversations();

      return group;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create group: ${e.toString()}',
      );
      return null;
    }
  }

  /// Update group info
  Future<ConversationModel?> updateGroup({
    required String conversationId,
    String? name,
    String? description,
    String? iconUrl,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final group = await _repository.updateGroup(
        conversationId: conversationId,
        name: name,
        description: description,
        iconUrl: iconUrl,
      );

      state = state.copyWith(isLoading: false);

      // Refresh conversations list
      ref.read(conversationsProvider.notifier).loadConversations();

      return group;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update group',
      );
      return null;
    }
  }

  /// Add members to a group
  Future<bool> addMembers({
    required String conversationId,
    required List<String> userIds,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _repository.addGroupMembers(
        conversationId: conversationId,
        userIds: userIds,
      );

      state = state.copyWith(isLoading: false);

      // Refresh conversations list
      ref.read(conversationsProvider.notifier).loadConversations();

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to add members',
      );
      return false;
    }
  }

  /// Remove a member from a group
  Future<bool> removeMember({
    required String conversationId,
    required String userId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _repository.removeGroupMember(
        conversationId: conversationId,
        userId: userId,
      );

      state = state.copyWith(isLoading: false);

      // Refresh conversations list
      ref.read(conversationsProvider.notifier).loadConversations();

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to remove member',
      );
      return false;
    }
  }

  /// Leave a group
  Future<bool> leaveGroup(String conversationId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _repository.leaveGroup(conversationId);

      state = state.copyWith(isLoading: false);

      // Refresh conversations list
      ref.read(conversationsProvider.notifier).loadConversations();

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to leave group',
      );
      return false;
    }
  }

  /// Add an admin to a group
  Future<bool> addAdmin({
    required String conversationId,
    required String userId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _repository.addGroupAdmin(
        conversationId: conversationId,
        userId: userId,
      );

      state = state.copyWith(isLoading: false);

      // Refresh conversations list
      ref.read(conversationsProvider.notifier).loadConversations();

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to add admin',
      );
      return false;
    }
  }

  /// Remove an admin from a group
  Future<bool> removeAdmin({
    required String conversationId,
    required String userId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _repository.removeGroupAdmin(
        conversationId: conversationId,
        userId: userId,
      );

      state = state.copyWith(isLoading: false);

      // Refresh conversations list
      ref.read(conversationsProvider.notifier).loadConversations();

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to remove admin',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final groupProvider = NotifierProvider<GroupNotifier, GroupState>(() {
  return GroupNotifier();
});
