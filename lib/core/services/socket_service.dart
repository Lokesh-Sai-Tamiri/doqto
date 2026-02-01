/// ============================================================================
/// SOCKET SERVICE - Real-time Communication via Socket.io
/// ============================================================================
///
/// Handles real-time features like message delivery, typing indicators,
/// and presence updates via Socket.io.
/// ============================================================================
library;

import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../config/app_config.dart';
import 'supabase_service.dart';

/// Connection state for the socket
enum SocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Real-time message event
class MessageEvent {
  final String conversationId;
  final Map<String, dynamic> message;

  MessageEvent({required this.conversationId, required this.message});
}

/// Message status update event
class MessageStatusEvent {
  final String messageId;
  final String status;

  MessageStatusEvent({required this.messageId, required this.status});
}

/// Messages read event (for read receipts)
class MessagesReadEvent {
  final String conversationId;
  final String readerId;
  final List<String> messageIds;

  MessagesReadEvent({
    required this.conversationId,
    required this.readerId,
    required this.messageIds,
  });
}

/// Typing event
class TypingEvent {
  final String conversationId;
  final String userId;
  final bool isTyping;

  TypingEvent({
    required this.conversationId,
    required this.userId,
    required this.isTyping,
  });
}

/// Connection request event
class ConnectionRequestEvent {
  final Map<String, dynamic> data;

  ConnectionRequestEvent({required this.data});
}

/// Group event types
enum GroupEventType {
  created,
  updated,
  membersAdded,
  memberRemoved,
  memberLeft,
  adminChanged,
  removedFromGroup,
}

/// Group event
class GroupEvent {
  final GroupEventType type;
  final String groupId;
  final Map<String, dynamic> data;

  GroupEvent({
    required this.type,
    required this.groupId,
    required this.data,
  });
}

/// Socket.io service for real-time features
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  socket_io.Socket? _socket;

  // Stream controllers for events
  final _connectionStateController = StreamController<SocketConnectionState>.broadcast();
  final _newMessageController = StreamController<MessageEvent>.broadcast();
  final _messageStatusController = StreamController<MessageStatusEvent>.broadcast();
  final _messagesReadController = StreamController<MessagesReadEvent>.broadcast();
  final _typingController = StreamController<TypingEvent>.broadcast();
  final _conversationUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionRequestController = StreamController<ConnectionRequestEvent>.broadcast();
  final _connectionAcceptedController = StreamController<Map<String, dynamic>>.broadcast();
  final _groupEventController = StreamController<GroupEvent>.broadcast();

  // Current state
  SocketConnectionState _connectionState = SocketConnectionState.disconnected;
  int _reconnectAttempts = 0;

  // ============================================================================
  // Streams for listening to events
  // ============================================================================

  Stream<SocketConnectionState> get connectionState => _connectionStateController.stream;
  Stream<MessageEvent> get onNewMessage => _newMessageController.stream;
  Stream<MessageStatusEvent> get onMessageStatusUpdate => _messageStatusController.stream;
  Stream<MessagesReadEvent> get onMessagesRead => _messagesReadController.stream;
  Stream<TypingEvent> get onTyping => _typingController.stream;
  Stream<Map<String, dynamic>> get onConversationUpdated => _conversationUpdatedController.stream;
  Stream<ConnectionRequestEvent> get onConnectionRequest => _connectionRequestController.stream;
  Stream<Map<String, dynamic>> get onConnectionAccepted => _connectionAcceptedController.stream;
  Stream<GroupEvent> get onGroupEvent => _groupEventController.stream;

  SocketConnectionState get currentConnectionState => _connectionState;
  bool get isConnected => _connectionState == SocketConnectionState.connected;

  // ============================================================================
  // Connection management
  // ============================================================================

  /// Connect to the Socket.io server
  Future<bool> connect() async {
    if (_socket?.connected == true) {
      return true;
    }

    final token = SupabaseService.currentSession?.accessToken;
    if (token == null) {
      _log('❌ Cannot connect: No auth token');
      return false;
    }

    _updateState(SocketConnectionState.connecting);
    _log('🔌 Connecting to Socket.io server...');

    try {
      _socket = socket_io.io(
        AppConfig.socketUrl,
        socket_io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(AppConfig.socketReconnectAttempts)
            .setReconnectionDelay(AppConfig.socketReconnectDelayMs)
            .build(),
      );

      _setupEventListeners();

      // Wait for connection with timeout
      final completer = Completer<bool>();
      Timer? timeout;

      void onConnect(_) {
        timeout?.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }

      void onError(error) {
        timeout?.cancel();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      }

      _socket!.onConnect(onConnect);
      _socket!.onConnectError(onError);

      timeout = Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      _socket!.connect();
      return await completer.future;
    } catch (e) {
      _log('❌ Connection error: $e');
      _updateState(SocketConnectionState.error);
      return false;
    }
  }

  /// Disconnect from the server
  void disconnect() {
    _log('🔌 Disconnecting from Socket.io server...');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _updateState(SocketConnectionState.disconnected);
    _reconnectAttempts = 0;
  }

  /// Reconnect with fresh token
  Future<bool> reconnect() async {
    disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    return connect();
  }

  // ============================================================================
  // Event listeners setup
  // ============================================================================

  void _setupEventListeners() {
    _socket!.onConnect((_) {
      _log('✅ Connected to Socket.io server');
      _updateState(SocketConnectionState.connected);
      _reconnectAttempts = 0;

      // Auto-join user's conversations
      _socket!.emitWithAck('join_conversations', {}, ack: (data) {
        _log('📋 Joined ${data['joined']} conversations');
      });
    });

    _socket!.onDisconnect((_) {
      _log('🔌 Disconnected from Socket.io server');
      _updateState(SocketConnectionState.disconnected);
    });

    _socket!.onConnectError((error) {
      _log('❌ Connection error: $error');
      _updateState(SocketConnectionState.error);
    });

    _socket!.onReconnecting((_) {
      _reconnectAttempts++;
      _log('🔄 Reconnecting... (attempt $_reconnectAttempts)');
      _updateState(SocketConnectionState.reconnecting);
    });

    _socket!.onReconnect((_) {
      _log('✅ Reconnected to Socket.io server');
      _updateState(SocketConnectionState.connected);
    });

    _socket!.onReconnectFailed((_) {
      _log('❌ Reconnection failed after $_reconnectAttempts attempts');
      _updateState(SocketConnectionState.error);
    });

    // Message events
    _socket!.on('message:new', (data) {
      _log('📩 New message received');
      _newMessageController.add(MessageEvent(
        conversationId: data['conversation_id'],
        message: data['message'],
      ));
    });

    _socket!.on('message:updated', (data) {
      _log('📝 Message status updated: ${data['status']}');
      _messageStatusController.add(MessageStatusEvent(
        messageId: data['message_id'],
        status: data['status'],
      ));
    });

    _socket!.on('messages:read', (data) {
      _log('✓✓ Messages marked as read');
      final messageIds = (data['message_ids'] as List<dynamic>?)
          ?.map((id) => id.toString())
          .toList() ?? [];
      _messagesReadController.add(MessagesReadEvent(
        conversationId: data['conversation_id'],
        readerId: data['reader_id'],
        messageIds: messageIds,
      ));
    });

    // Typing events
    _socket!.on('typing:start', (data) {
      _log('⌨️ Typing start received: $data');
      try {
        final mapData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
        _typingController.add(TypingEvent(
          conversationId: mapData['conversation_id']?.toString() ?? '',
          userId: mapData['user_id']?.toString() ?? '',
          isTyping: true,
        ));
      } catch (e) {
        _log('❌ Error parsing typing:start event: $e');
      }
    });

    _socket!.on('typing:stop', (data) {
      _log('⌨️ Typing stop received: $data');
      try {
        final mapData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
        _typingController.add(TypingEvent(
          conversationId: mapData['conversation_id']?.toString() ?? '',
          userId: mapData['user_id']?.toString() ?? '',
          isTyping: false,
        ));
      } catch (e) {
        _log('❌ Error parsing typing:stop event: $e');
      }
    });

    // Conversation events
    _socket!.on('conversation:updated', (data) {
      _log('💬 Conversation updated');
      _conversationUpdatedController.add(data);
    });

    // Connection events
    _socket!.on('connection:request', (data) {
      _log('🤝 Connection request received');
      _connectionRequestController.add(ConnectionRequestEvent(data: data));
    });

    _socket!.on('connection:accepted', (data) {
      _log('✅ Connection accepted');
      _connectionAcceptedController.add(data);
    });

    // Group events
    _socket!.on('group:created', (data) {
      _log('👥 Group created');
      _groupEventController.add(GroupEvent(
        type: GroupEventType.created,
        groupId: data['group_id'],
        data: data,
      ));
    });

    _socket!.on('group:updated', (data) {
      _log('📝 Group updated');
      _groupEventController.add(GroupEvent(
        type: GroupEventType.updated,
        groupId: data['group_id'],
        data: data,
      ));
    });

    _socket!.on('group:members_added', (data) {
      _log('➕ Group members added');
      _groupEventController.add(GroupEvent(
        type: GroupEventType.membersAdded,
        groupId: data['group_id'],
        data: data,
      ));
    });

    _socket!.on('group:member_removed', (data) {
      _log('➖ Group member removed');
      _groupEventController.add(GroupEvent(
        type: GroupEventType.memberRemoved,
        groupId: data['group_id'],
        data: data,
      ));
    });

    _socket!.on('group:member_left', (data) {
      _log('🚪 Group member left');
      _groupEventController.add(GroupEvent(
        type: GroupEventType.memberLeft,
        groupId: data['group_id'],
        data: data,
      ));
    });

    _socket!.on('group:admin_changed', (data) {
      _log('👑 Group admin changed');
      _groupEventController.add(GroupEvent(
        type: GroupEventType.adminChanged,
        groupId: data['group_id'],
        data: data,
      ));
    });

    _socket!.on('group:removed_from_group', (data) {
      _log('🚫 Removed from group');
      _groupEventController.add(GroupEvent(
        type: GroupEventType.removedFromGroup,
        groupId: data['group_id'],
        data: data,
      ));
    });
  }

  void _updateState(SocketConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  // ============================================================================
  // Emit events
  // ============================================================================

  /// Join a specific conversation room
  void joinConversation(String conversationId) {
    _socket?.emitWithAck('join_conversation', {
      'conversation_id': conversationId,
    }, ack: (data) {
      _log('📋 Joined conversation: $conversationId');
    });
  }

  /// Leave a conversation room
  void leaveConversation(String conversationId) {
    _socket?.emit('leave_conversation', {
      'conversation_id': conversationId,
    });
  }

  /// Start typing indicator
  void startTyping(String conversationId) {
    _log('⌨️ Emitting typing_start for: $conversationId');
    _socket?.emit('typing_start', {
      'conversation_id': conversationId,
    });
  }

  /// Stop typing indicator
  void stopTyping(String conversationId) {
    _log('⌨️ Emitting typing_stop for: $conversationId');
    _socket?.emit('typing_stop', {
      'conversation_id': conversationId,
    });
  }

  /// Acknowledge message delivery
  void acknowledgeDelivery(String messageId, String conversationId) {
    _socket?.emit('message_delivered', {
      'message_id': messageId,
      'conversation_id': conversationId,
    });
  }

  // ============================================================================
  // Utility
  // ============================================================================

  void _log(String message) {
    if (AppConfig.apiDebugMode) {
      // Using debugPrint which is production-safe
      assert(() {
        // ignore: avoid_print
        print('[SocketService] $message');
        return true;
      }());
    }
  }

  /// Dispose all resources
  void dispose() {
    disconnect();
    _connectionStateController.close();
    _newMessageController.close();
    _messageStatusController.close();
    _messagesReadController.close();
    _typingController.close();
    _conversationUpdatedController.close();
    _connectionRequestController.close();
    _connectionAcceptedController.close();
    _groupEventController.close();
  }
}
