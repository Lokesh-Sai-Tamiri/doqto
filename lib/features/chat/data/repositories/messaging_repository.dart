/// ============================================================================
/// MESSAGING REPOSITORY - HIPAA Compliant
/// ============================================================================
///
/// Handles messaging operations via the HymnChat API backend.
/// Uses Socket.io for real-time message delivery and typing indicators.
/// ============================================================================
library;

import 'dart:async';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/config/app_config.dart';
import '../models/messaging_models.dart';

export '../../../../core/services/socket_service.dart' show GroupEvent, GroupEventType;

class MessagingRepository {
  final ApiService _api = ApiService();
  final SocketService _socket = SocketService();

  String? get currentUserId => SupabaseService.currentUser?.id;

  // ============================================================================
  // CONVERSATIONS
  // ============================================================================

  /// Get all conversations for current user
  Future<List<ConversationModel>> getConversations({bool includeArchived = false}) async {
    try {
      _log('💬 Fetching conversations...');

      final response = await _api.get<List<dynamic>>(
        '/conversations',
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        var convs = response.data!
            .map((json) => ConversationModel.fromJson(json as Map<String, dynamic>))
            .toList();

        if (!includeArchived) {
          convs = convs.where((c) => !c.isArchived).toList();
        }

        _log('✅ Conversations loaded: ${convs.length}');
        return convs;
      }

      _log('⚠️ Failed to fetch conversations: ${response.error}');
      return [];
    } catch (e) {
      _log('❌ Error fetching conversations: $e');
      rethrow;
    }
  }

  /// Get or create conversation with another user
  Future<String> getOrCreateConversation(String otherUserId) async {
    try {
      _log('💬 Getting/creating conversation with: $otherUserId');

      final response = await _api.post<Map<String, dynamic>>(
        '/conversations',
        body: {'other_user_id': otherUserId},
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!['id'] as String;
      }

      throw Exception(response.error ?? 'Failed to create conversation');
    } catch (e) {
      _log('❌ Error getting/creating conversation: $e');
      rethrow;
    }
  }

  /// Get single conversation by ID
  Future<ConversationModel?> getConversation(String conversationId) async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/conversations/$conversationId',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return ConversationModel.fromJson(response.data!);
      }

      return null;
    } catch (e) {
      _log('❌ Error fetching conversation: $e');
      rethrow;
    }
  }

  /// Update conversation settings
  Future<bool> updateConversationSettings({
    required String conversationId,
    bool? muted,
    bool? archived,
    bool? pinned,
    int? disappearingHours,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (muted != null) body['is_muted'] = muted;
      if (archived != null) body['is_archived'] = archived;
      if (pinned != null) body['is_pinned'] = pinned;
      if (disappearingHours != null) body['disappearing_hours'] = disappearingHours;

      final response = await _api.patch<Map<String, dynamic>>(
        '/conversations/$conversationId/settings',
        body: body,
        fromJson: (json) => json as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      _log('❌ Error updating conversation settings: $e');
      rethrow;
    }
  }

  /// Delete conversation (soft delete for user)
  Future<bool> deleteConversation(String conversationId) async {
    try {
      final response = await _api.delete<Map<String, dynamic>>(
        '/conversations/$conversationId',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      _log('❌ Error deleting conversation: $e');
      rethrow;
    }
  }

  /// Get total unread count
  Future<int> getTotalUnreadCount() async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/messaging/unread-count',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!['total_unread'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      _log('❌ Error getting unread count: $e');
      return 0;
    }
  }

  // ============================================================================
  // GROUPS
  // ============================================================================

  /// Create a new group conversation
  Future<ConversationModel> createGroup({
    required String name,
    required List<String> participantIds,
    String? description,
  }) async {
    try {
      _log('👥 Creating group: $name');

      final response = await _api.post<Map<String, dynamic>>(
        '/groups',
        body: {
          'name': name,
          'participant_ids': participantIds,
          if (description != null) 'description': description,
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        _log('✅ Group created successfully');
        return ConversationModel.fromJson(response.data!);
      }

      throw Exception(response.error ?? 'Failed to create group');
    } catch (e) {
      _log('❌ Error creating group: $e');
      rethrow;
    }
  }

  /// Update group information
  Future<ConversationModel> updateGroup({
    required String conversationId,
    String? name,
    String? description,
    String? iconUrl,
  }) async {
    try {
      _log('📝 Updating group: $conversationId');

      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (iconUrl != null) body['icon_url'] = iconUrl;

      final response = await _api.patch<Map<String, dynamic>>(
        '/groups/$conversationId',
        body: body,
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return ConversationModel.fromJson(response.data!);
      }

      throw Exception(response.error ?? 'Failed to update group');
    } catch (e) {
      _log('❌ Error updating group: $e');
      rethrow;
    }
  }

  /// Add members to a group
  Future<ConversationModel> addGroupMembers({
    required String conversationId,
    required List<String> userIds,
  }) async {
    try {
      _log('➕ Adding members to group: $conversationId');

      final response = await _api.post<Map<String, dynamic>>(
        '/groups/$conversationId/members',
        body: {'user_ids': userIds},
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return ConversationModel.fromJson(response.data!);
      }

      throw Exception(response.error ?? 'Failed to add members');
    } catch (e) {
      _log('❌ Error adding group members: $e');
      rethrow;
    }
  }

  /// Remove a member from a group
  Future<bool> removeGroupMember({
    required String conversationId,
    required String userId,
  }) async {
    try {
      _log('➖ Removing member from group: $conversationId');

      final response = await _api.delete<Map<String, dynamic>>(
        '/groups/$conversationId/members/$userId',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      _log('❌ Error removing group member: $e');
      rethrow;
    }
  }

  /// Leave a group
  Future<bool> leaveGroup(String conversationId) async {
    try {
      _log('🚪 Leaving group: $conversationId');

      final response = await _api.post<Map<String, dynamic>>(
        '/groups/$conversationId/leave',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      _log('❌ Error leaving group: $e');
      rethrow;
    }
  }

  /// Add an admin to a group
  Future<ConversationModel> addGroupAdmin({
    required String conversationId,
    required String userId,
  }) async {
    try {
      _log('👑 Adding admin to group: $conversationId');

      final response = await _api.post<Map<String, dynamic>>(
        '/groups/$conversationId/admins',
        body: {'user_id': userId},
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return ConversationModel.fromJson(response.data!);
      }

      throw Exception(response.error ?? 'Failed to add admin');
    } catch (e) {
      _log('❌ Error adding group admin: $e');
      rethrow;
    }
  }

  /// Remove an admin from a group
  Future<ConversationModel> removeGroupAdmin({
    required String conversationId,
    required String userId,
  }) async {
    try {
      _log('👤 Removing admin from group: $conversationId');

      final response = await _api.delete<Map<String, dynamic>>(
        '/groups/$conversationId/admins/$userId',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return ConversationModel.fromJson(response.data!);
      }

      throw Exception(response.error ?? 'Failed to remove admin');
    } catch (e) {
      _log('❌ Error removing group admin: $e');
      rethrow;
    }
  }

  // ============================================================================
  // MESSAGES
  // ============================================================================

  /// Get messages for a conversation
  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async {
    try {
      _log('📨 Fetching messages for: $conversationId');

      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      if (before != null) {
        queryParams['before'] = before;
      }

      final response = await _api.get<List<dynamic>>(
        '/conversations/$conversationId/messages',
        queryParams: queryParams,
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        final messages = response.data!
            .map((json) => MessageModel.fromJson(json as Map<String, dynamic>))
            .toList();

        _log('✅ Messages loaded: ${messages.length}');
        return messages;
      }

      return [];
    } catch (e) {
      _log('❌ Error fetching messages: $e');
      rethrow;
    }
  }

  /// Send a text message
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String content,
    String? replyToId,
    List<String>? mentions,
  }) async {
    try {
      _log('📤 Sending message to: $conversationId');

      final response = await _api.post<Map<String, dynamic>>(
        '/conversations/$conversationId/messages',
        body: {
          'message_type': 'text',
          'content': content,
          if (replyToId != null) 'reply_to_id': replyToId,
          if (mentions != null && mentions.isNotEmpty) 'mentions': mentions,
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return MessageModel.fromJson(response.data!);
      }

      throw Exception(response.error ?? 'Failed to send message');
    } catch (e) {
      _log('❌ Error sending message: $e');
      rethrow;
    }
  }

  /// Send an audio message
  Future<MessageModel> sendAudioMessage({
    required String conversationId,
    required String fileUrl,
    required int durationSeconds,
    String? fileName,
    int? fileSize,
  }) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/conversations/$conversationId/messages',
        body: {
          'message_type': 'audio',
          'file': {
            'url': fileUrl,
            'name': fileName,
            'size': fileSize,
          },
          'audio': {
            'duration_seconds': durationSeconds,
          },
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return MessageModel.fromJson(response.data!);
      }

      throw Exception(response.error ?? 'Failed to send audio message');
    } catch (e) {
      _log('❌ Error sending audio message: $e');
      rethrow;
    }
  }

  /// Send an image message
  Future<MessageModel> sendImageMessage({
    required String conversationId,
    required String fileUrl,
    String? fileName,
    int? fileSize,
  }) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/conversations/$conversationId/messages',
        body: {
          'message_type': 'image',
          'file': {
            'url': fileUrl,
            'name': fileName,
            'size': fileSize,
          },
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return MessageModel.fromJson(response.data!);
      }

      throw Exception(response.error ?? 'Failed to send image message');
    } catch (e) {
      _log('❌ Error sending image message: $e');
      rethrow;
    }
  }

  /// Mark messages as read
  Future<int> markMessagesRead(String conversationId) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/conversations/$conversationId/messages/read',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!['marked_read'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      _log('❌ Error marking messages read: $e');
      rethrow;
    }
  }

  /// Save audio message (Snapchat-style)
  Future<bool> saveAudioMessage(String messageId) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/messages/$messageId/save-audio',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      _log('❌ Error saving audio message: $e');
      rethrow;
    }
  }

  // ============================================================================
  // REAL-TIME SUBSCRIPTIONS (via Socket.io)
  // ============================================================================

  /// Connect to real-time server
  Future<bool> connectRealtime() async {
    return await _socket.connect();
  }

  /// Disconnect from real-time server
  void disconnectRealtime() {
    _socket.disconnect();
  }

  /// Join a conversation room for real-time updates
  void joinConversation(String conversationId) {
    _socket.joinConversation(conversationId);
  }

  /// Leave a conversation room
  void leaveConversation(String conversationId) {
    _socket.leaveConversation(conversationId);
  }

  /// Stream of new messages
  Stream<MessageEvent> get onNewMessage => _socket.onNewMessage;

  /// Stream of message status updates
  Stream<MessageStatusEvent> get onMessageStatusUpdate => _socket.onMessageStatusUpdate;

  /// Stream of messages read (for read receipts)
  Stream<MessagesReadEvent> get onMessagesRead => _socket.onMessagesRead;

  /// Stream of typing events
  Stream<TypingEvent> get onTyping => _socket.onTyping;

  /// Stream of conversation updates
  Stream<Map<String, dynamic>> get onConversationUpdated => _socket.onConversationUpdated;

  /// Stream of group events
  Stream<GroupEvent> get onGroupEvent => _socket.onGroupEvent;

  /// Start typing indicator
  void startTyping(String conversationId) {
    _socket.startTyping(conversationId);
  }

  /// Stop typing indicator
  void stopTyping(String conversationId) {
    _socket.stopTyping(conversationId);
  }

  /// Acknowledge message delivery
  void acknowledgeDelivery(String messageId, String conversationId) {
    _socket.acknowledgeDelivery(messageId, conversationId);
  }

  // ============================================================================
  // BLOCKING & REPORTING (via connections API)
  // ============================================================================

  /// Block a user
  Future<bool> blockUser(String userId, {String? reason}) async {
    try {
      _log('🚫 Blocking user: $userId');

      final response = await _api.post<Map<String, dynamic>>(
        '/connections/users/$userId/block',
        body: reason != null ? {'reason': reason} : null,
        fromJson: (json) => json as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      _log('❌ Error blocking user: $e');
      rethrow;
    }
  }

  /// Unblock a user
  Future<bool> unblockUser(String userId) async {
    try {
      _log('✅ Unblocking user: $userId');

      final response = await _api.delete<Map<String, dynamic>>(
        '/connections/users/$userId/block',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      _log('❌ Error unblocking user: $e');
      rethrow;
    }
  }

  /// Get blocked users
  Future<List<BlockedUserModel>> getBlockedUsers() async {
    try {
      final response = await _api.get<List<dynamic>>(
        '/connections/users/blocked',
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!
            .map((json) => BlockedUserModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      _log('❌ Error fetching blocked users: $e');
      rethrow;
    }
  }

  /// Report a user
  Future<bool> reportUser({
    required String userId,
    required String reason,
    String? description,
    String? messageId,
  }) async {
    try {
      _log('🚨 Reporting user: $userId');

      final response = await _api.post<Map<String, dynamic>>(
        '/connections/users/$userId/report',
        body: {
          'reported_user_id': userId,
          'reason': reason,
          if (description != null) 'description': description,
          if (messageId != null) 'message_id': messageId,
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      _log('❌ Error reporting user: $e');
      rethrow;
    }
  }

  // ============================================================================
  // MESSAGING PREFERENCES
  // ============================================================================

  /// Get user's messaging preferences
  Future<MessagingPreferencesModel?> getMessagingPreferences() async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/messaging/preferences',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return MessagingPreferencesModel.fromJson(response.data!);
      }

      return null;
    } catch (e) {
      _log('❌ Error fetching messaging preferences: $e');
      rethrow;
    }
  }

  /// Update messaging preferences
  Future<bool> updateMessagingPreferences(MessagingPreferencesModel prefs) async {
    try {
      final response = await _api.put<Map<String, dynamic>>(
        '/messaging/preferences',
        body: prefs.toJson(),
        fromJson: (json) => json as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      _log('❌ Error updating messaging preferences: $e');
      rethrow;
    }
  }

  // ============================================================================
  // FILE UPLOAD
  // ============================================================================

  /// Get presigned URL for file upload
  Future<FileUploadInfo> getUploadUrl({
    required String filename,
    String? contentType,
  }) async {
    try {
      final queryParams = <String, String>{
        'filename': filename,
      };
      if (contentType != null) {
        queryParams['content_type'] = contentType;
      }

      final response = await _api.post<Map<String, dynamic>>(
        '/messaging/upload-url',
        queryParams: queryParams,
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return FileUploadInfo(
          uploadUrl: response.data!['upload_url'] as String,
          key: response.data!['key'] as String,
          downloadUrl: response.data!['download_url'] as String,
        );
      }

      throw Exception(response.error ?? 'Failed to get upload URL');
    } catch (e) {
      _log('❌ Error getting upload URL: $e');
      rethrow;
    }
  }

  void _log(String message) {
    if (AppConfig.debugMode) {
      assert(() {
        // ignore: avoid_print
        print('[MessagingRepository] $message');
        return true;
      }());
    }
  }
}

/// File upload information
class FileUploadInfo {
  final String uploadUrl;
  final String key;
  final String downloadUrl;

  FileUploadInfo({
    required this.uploadUrl,
    required this.key,
    required this.downloadUrl,
  });
}
