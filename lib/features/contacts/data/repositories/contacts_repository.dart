/// ============================================================================
/// CONTACTS REPOSITORY - HIPAA Compliant
/// ============================================================================
///
/// Handles all data operations for connections/contacts via the HymnChat API.
/// Uses Socket.io for real-time connection request notifications.
/// ============================================================================
library;

import 'dart:async';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/config/app_config.dart';
import '../models/connection_model.dart';

class ContactsRepository {
  final ApiService _api = ApiService();
  final SocketService _socket = SocketService();

  // ============================================================================
  // NETWORK (Accepted Connections)
  // ============================================================================

  /// Get user's network (accepted connections with profile info)
  Future<List<NetworkContactModel>> getNetwork() async {
    try {
      _log('👥 Fetching user network...');

      final response = await _api.get<List<dynamic>>(
        '/connections/network',
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        final contacts = response.data!
            .map((json) => NetworkContactModel.fromJson(json as Map<String, dynamic>))
            .toList();

        _log('✅ Network loaded: ${contacts.length} contacts');
        return contacts;
      }

      return [];
    } catch (e) {
      _log('❌ Error fetching network: $e');
      rethrow;
    }
  }

  /// Search network contacts
  Future<List<NetworkContactModel>> searchNetwork(String query) async {
    try {
      _log('🔍 Searching network for: $query');

      final response = await _api.get<List<dynamic>>(
        '/connections/network/search',
        queryParams: {'q': query},
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!
            .map((json) => NetworkContactModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      _log('❌ Error searching network: $e');
      rethrow;
    }
  }

  // ============================================================================
  // SUGGESTIONS
  // ============================================================================

  /// Get suggested connections (doctors not yet connected)
  Future<List<SuggestedContactModel>> getSuggestions() async {
    try {
      _log('💡 Fetching connection suggestions...');

      final response = await _api.get<List<dynamic>>(
        '/connections/suggestions',
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        final suggestions = response.data!
            .map((json) => SuggestedContactModel.fromJson(json as Map<String, dynamic>))
            .toList();

        _log('✅ Suggestions loaded: ${suggestions.length}');
        return suggestions;
      }

      return [];
    } catch (e) {
      _log('❌ Error fetching suggestions: $e');
      rethrow;
    }
  }

  /// Search for users to connect with (same as suggestions but filtered)
  Future<List<SuggestedContactModel>> searchUsers(String query) async {
    try {
      _log('🔍 Searching users for: $query');

      // Use profile search endpoint for broader search
      final response = await _api.get<List<dynamic>>(
        '/profiles/search/',
        queryParams: {'q': query},
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!.map((json) {
          final data = json as Map<String, dynamic>;
          return SuggestedContactModel(
            userId: data['user_id'] as String? ?? data['id'] as String,
            firstName: data['first_name'] as String?,
            lastName: data['last_name'] as String?,
            displayName: data['display_name'] as String?,
            specialization: data['specialization'] as String?,
            clinicName: data['clinic_name'] as String?,
            avatarUrl: data['avatar_url'] as String?,
            profileCompleted: data['profile_completed'] as bool? ?? false,
          );
        }).toList();
      }

      return [];
    } catch (e) {
      _log('❌ Error searching users: $e');
      rethrow;
    }
  }

  // ============================================================================
  // PENDING REQUESTS
  // ============================================================================

  /// Get pending connection requests (received)
  Future<List<PendingRequestModel>> getPendingRequests() async {
    try {
      _log('📬 Fetching pending requests...');

      final response = await _api.get<List<dynamic>>(
        '/connections/pending',
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        final requests = response.data!
            .map((json) => PendingRequestModel.fromJson(json as Map<String, dynamic>))
            .toList();

        _log('✅ Pending requests loaded: ${requests.length}');
        return requests;
      }

      return [];
    } catch (e) {
      _log('❌ Error fetching pending requests: $e');
      rethrow;
    }
  }

  /// Get sent connection requests (outgoing)
  Future<List<String>> getSentRequestUserIds() async {
    try {
      final response = await _api.get<List<dynamic>>(
        '/connections/sent',
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!.map((id) => id as String).toList();
      }

      return [];
    } catch (e) {
      _log('❌ Error fetching sent requests: $e');
      rethrow;
    }
  }

  // ============================================================================
  // CONNECTION ACTIONS
  // ============================================================================

  /// Send a connection request
  Future<ConnectionModel> sendConnectionRequest(String recipientId, {String? message}) async {
    try {
      _log('📤 Sending connection request to: $recipientId');

      final response = await _api.post<Map<String, dynamic>>(
        '/connections/request',
        body: {
          'recipient_id': recipientId,
          if (message != null) 'request_message': message,
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        _log('✅ Connection request sent');
        return ConnectionModel.fromJson(response.data!);
      }

      throw Exception(response.error ?? 'Failed to send connection request');
    } catch (e) {
      _log('❌ Error sending connection request: $e');
      rethrow;
    }
  }

  /// Accept a connection request
  Future<ConnectionModel> acceptConnectionRequest(String connectionId) async {
    try {
      _log('✅ Accepting connection request: $connectionId');

      final response = await _api.post<Map<String, dynamic>>(
        '/connections/$connectionId/accept',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        _log('✅ Connection accepted');
        return ConnectionModel.fromJson(response.data!);
      }

      throw Exception(response.error ?? 'Failed to accept connection');
    } catch (e) {
      _log('❌ Error accepting connection: $e');
      rethrow;
    }
  }

  /// Reject a connection request
  Future<bool> rejectConnectionRequest(String connectionId) async {
    try {
      _log('❌ Rejecting connection request: $connectionId');

      final response = await _api.post<Map<String, dynamic>>(
        '/connections/$connectionId/reject',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      _log('❌ Error rejecting connection: $e');
      rethrow;
    }
  }

  /// Remove a connection (soft delete)
  Future<bool> removeConnection(String connectionId) async {
    try {
      _log('🗑️ Removing connection: $connectionId');

      final response = await _api.delete<Map<String, dynamic>>(
        '/connections/$connectionId',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      _log('❌ Error removing connection: $e');
      rethrow;
    }
  }

  /// Get connection status with another user
  Future<ConnectionModel?> getConnectionStatus(String otherUserId) async {
    try {
      final response = await _api.get<Map<String, dynamic>?>(
        '/connections/status/$otherUserId',
        fromJson: (json) => json as Map<String, dynamic>?,
      );

      if (response.success && response.data != null) {
        return ConnectionModel.fromJson(response.data!);
      }

      return null;
    } catch (e) {
      _log('❌ Error getting connection status: $e');
      return null;
    }
  }

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

  // ============================================================================
  // REAL-TIME SUBSCRIPTIONS (via Socket.io)
  // ============================================================================

  /// Stream of connection request notifications
  Stream<ConnectionRequestEvent> get onConnectionRequest => _socket.onConnectionRequest;

  /// Stream of connection accepted notifications
  Stream<Map<String, dynamic>> get onConnectionAccepted => _socket.onConnectionAccepted;

  /// Subscribe to connection changes and handle updates
  void subscribeToConnections({
    required void Function(List<NetworkContactModel>) onNetworkUpdate,
    required void Function(List<PendingRequestModel>) onPendingUpdate,
  }) {
    // Listen for connection requests
    _socket.onConnectionRequest.listen((_) async {
      try {
        final pending = await getPendingRequests();
        onPendingUpdate(pending);
      } catch (e) {
        _log('❌ Error handling connection request: $e');
      }
    });

    // Listen for accepted connections
    _socket.onConnectionAccepted.listen((_) async {
      try {
        final network = await getNetwork();
        onNetworkUpdate(network);

        final pending = await getPendingRequests();
        onPendingUpdate(pending);
      } catch (e) {
        _log('❌ Error handling connection accepted: $e');
      }
    });
  }

  void _log(String message) {
    if (AppConfig.debugMode) {
      assert(() {
        // ignore: avoid_print
        print('[ContactsRepository] $message');
        return true;
      }());
    }
  }
}
