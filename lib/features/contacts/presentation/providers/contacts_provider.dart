/// ============================================================================
/// CONTACTS PROVIDERS - Riverpod State Management
/// ============================================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/connection_model.dart';
import '../../data/repositories/contacts_repository.dart';

// ============================================================================
// REPOSITORY PROVIDER
// ============================================================================

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return ContactsRepository();
});

// ============================================================================
// NETWORK STATE
// ============================================================================

class NetworkState {
  final bool isLoading;
  final List<NetworkContactModel> contacts;
  final String? errorMessage;

  const NetworkState({
    this.isLoading = false,
    this.contacts = const [],
    this.errorMessage,
  });

  NetworkState copyWith({
    bool? isLoading,
    List<NetworkContactModel>? contacts,
    String? errorMessage,
  }) {
    return NetworkState(
      isLoading: isLoading ?? this.isLoading,
      contacts: contacts ?? this.contacts,
      errorMessage: errorMessage,
    );
  }
}

class NetworkNotifier extends Notifier<NetworkState> {
  late final ContactsRepository _repository;

  @override
  NetworkState build() {
    _repository = ref.watch(contactsRepositoryProvider);
    // Auto-load on build
    Future.microtask(() => loadNetwork());
    return const NetworkState(isLoading: true);
  }

  Future<void> loadNetwork() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final contacts = await _repository.getNetwork();
      state = state.copyWith(isLoading: false, contacts: contacts);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load network: ${e.toString()}',
      );
    }
  }

  Future<void> searchNetwork(String query) async {
    if (query.isEmpty) {
      await loadNetwork();
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final contacts = await _repository.searchNetwork(query);
      state = state.copyWith(isLoading: false, contacts: contacts);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Search failed: ${e.toString()}',
      );
    }
  }

  Future<bool> removeConnection(String connectionId) async {
    try {
      final success = await _repository.removeConnection(connectionId);
      if (success) {
        // Remove from local state
        state = state.copyWith(
          contacts: state.contacts
              .where((c) => c.connectionId != connectionId)
              .toList(),
        );
      }
      return success;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to remove connection');
      return false;
    }
  }

  void updateContacts(List<NetworkContactModel> contacts) {
    state = state.copyWith(contacts: contacts);
  }
}

final networkProvider = NotifierProvider<NetworkNotifier, NetworkState>(() {
  return NetworkNotifier();
});

// ============================================================================
// SUGGESTIONS STATE
// ============================================================================

class SuggestionsState {
  final bool isLoading;
  final List<SuggestedContactModel> suggestions;
  final Set<String> pendingRequestIds; // IDs of users we've sent requests to
  final String? errorMessage;

  const SuggestionsState({
    this.isLoading = false,
    this.suggestions = const [],
    this.pendingRequestIds = const {},
    this.errorMessage,
  });

  SuggestionsState copyWith({
    bool? isLoading,
    List<SuggestedContactModel>? suggestions,
    Set<String>? pendingRequestIds,
    String? errorMessage,
  }) {
    return SuggestionsState(
      isLoading: isLoading ?? this.isLoading,
      suggestions: suggestions ?? this.suggestions,
      pendingRequestIds: pendingRequestIds ?? this.pendingRequestIds,
      errorMessage: errorMessage,
    );
  }
}

class SuggestionsNotifier extends Notifier<SuggestionsState> {
  late final ContactsRepository _repository;

  @override
  SuggestionsState build() {
    _repository = ref.watch(contactsRepositoryProvider);
    // Auto-load on build
    Future.microtask(() => loadSuggestions());
    return const SuggestionsState(isLoading: true);
  }

  Future<void> loadSuggestions() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final suggestions = await _repository.getSuggestions();
      final sentRequests = await _repository.getSentRequestUserIds();
      
      state = state.copyWith(
        isLoading: false,
        suggestions: suggestions,
        pendingRequestIds: sentRequests.toSet(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load suggestions: ${e.toString()}',
      );
    }
  }

  Future<void> searchSuggestions(String query) async {
    if (query.isEmpty) {
      await loadSuggestions();
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final suggestions = await _repository.searchUsers(query);
      state = state.copyWith(isLoading: false, suggestions: suggestions);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Search failed: ${e.toString()}',
      );
    }
  }

  Future<bool> sendConnectionRequest(String userId, {String? message}) async {
    try {
      await _repository.sendConnectionRequest(userId, message: message);
      
      // Mark as pending locally
      state = state.copyWith(
        pendingRequestIds: {...state.pendingRequestIds, userId},
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to send request');
      return false;
    }
  }

  bool isPending(String userId) {
    return state.pendingRequestIds.contains(userId);
  }
}

final suggestionsProvider =
    NotifierProvider<SuggestionsNotifier, SuggestionsState>(() {
  return SuggestionsNotifier();
});

// ============================================================================
// PENDING REQUESTS STATE
// ============================================================================

class PendingRequestsState {
  final bool isLoading;
  final List<PendingRequestModel> requests;
  final String? errorMessage;

  const PendingRequestsState({
    this.isLoading = false,
    this.requests = const [],
    this.errorMessage,
  });

  PendingRequestsState copyWith({
    bool? isLoading,
    List<PendingRequestModel>? requests,
    String? errorMessage,
  }) {
    return PendingRequestsState(
      isLoading: isLoading ?? this.isLoading,
      requests: requests ?? this.requests,
      errorMessage: errorMessage,
    );
  }

  int get count => requests.length;
}

class PendingRequestsNotifier extends Notifier<PendingRequestsState> {
  late final ContactsRepository _repository;

  @override
  PendingRequestsState build() {
    _repository = ref.watch(contactsRepositoryProvider);
    // Auto-load on build
    Future.microtask(() => loadRequests());
    return const PendingRequestsState(isLoading: true);
  }

  Future<void> loadRequests() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final requests = await _repository.getPendingRequests();
      state = state.copyWith(isLoading: false, requests: requests);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load requests: ${e.toString()}',
      );
    }
  }

  Future<bool> acceptRequest(String connectionId) async {
    try {
      final connection = await _repository.acceptConnectionRequest(connectionId);
      // Remove from local state
      state = state.copyWith(
        requests: state.requests
            .where((r) => r.connectionId != connectionId)
            .toList(),
      );
      // Refresh network
      ref.read(networkProvider.notifier).loadNetwork();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to accept request');
      return false;
    }
  }

  Future<bool> rejectRequest(String connectionId) async {
    try {
      final success = await _repository.rejectConnectionRequest(connectionId);
      if (success) {
        state = state.copyWith(
          requests: state.requests
              .where((r) => r.connectionId != connectionId)
              .toList(),
        );
      }
      return success;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to reject request');
      return false;
    }
  }

  void updateRequests(List<PendingRequestModel> requests) {
    state = state.copyWith(requests: requests);
  }
}

final pendingRequestsProvider =
    NotifierProvider<PendingRequestsNotifier, PendingRequestsState>(() {
  return PendingRequestsNotifier();
});

// ============================================================================
// REAL-TIME SUBSCRIPTION PROVIDER
// ============================================================================

/// Initializes real-time connection subscriptions via Socket.io
final contactsRealtimeProvider = Provider<void>((ref) {
  final repository = ref.watch(contactsRepositoryProvider);

  // Subscribe to connection changes
  repository.subscribeToConnections(
    onNetworkUpdate: (contacts) {
      ref.read(networkProvider.notifier).updateContacts(contacts);
    },
    onPendingUpdate: (requests) {
      ref.read(pendingRequestsProvider.notifier).updateRequests(requests);
    },
  );

  // Note: Socket.io subscriptions are managed by the SocketService singleton
  // No explicit disposal needed here as the socket handles it
});
