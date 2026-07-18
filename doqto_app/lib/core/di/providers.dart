import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../../data/api/token_storage.dart';
import '../../data/api/websocket_client.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/org_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/chat_cache.dart';
import '../../data/services/outbox.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(tokens: ref.watch(tokenStorageProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider)),
);

final orgRepositoryProvider = Provider<OrgRepository>(
  (ref) => OrgRepository(ref.watch(apiClientProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(apiClientProvider)),
);

final websocketClientProvider = Provider<WebsocketClient>((ref) {
  final ws = WebsocketClient();
  ref.onDispose(ws.dispose);
  return ws;
});

/// Socket lifecycle as a watchable value — drives the "Connecting…" banner.
final wsConnStateProvider = StreamProvider<WsConnState>(
  (ref) => ref.watch(websocketClientProvider).states,
);

final outboxProvider = Provider<Outbox>((ref) => Outbox());

final chatCacheProvider = Provider<ChatCache>((ref) => ChatCache());
