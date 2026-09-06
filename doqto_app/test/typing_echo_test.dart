import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/core/di/providers.dart';
import 'package:doqto_app/core/enums/app_enums.dart';
import 'package:doqto_app/data/api/websocket_client.dart';
import 'package:doqto_app/data/models/user.dart';
import 'package:doqto_app/state/auth_state.dart';
import 'package:doqto_app/state/chat_state.dart';

class _FakeSocket extends WebsocketClient {
  final _c = StreamController<WsEvent>.broadcast();
  @override
  Stream<WsEvent> get events => _c.stream;
  void emit(WsEvent e) => _c.add(e);
}

/// Auth that starts unknown (cold start) and can be signed in later.
class _LateAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStage.unknown, null);
  void signIn(User u) => state = AuthState(AuthStage.signedIn, u);
}

User _user(String id) => User.fromJson({
      'id': id,
      'phone': '+15550000101',
      'full_name': 'Dr A',
      'npi_number': '1234567893',
      'role': 'doctor',
      'created_at': '2026-09-05T00:00:00Z',
    });

void main() {
  test('own typing echo is ignored even when auth loads after the thread', () async {
    final socket = _FakeSocket();
    final container = ProviderContainer(overrides: [
      websocketClientProvider.overrideWithValue(socket),
      authProvider.overrideWith(_LateAuth.new),
    ]);
    addTearDown(container.dispose);

    // Notification tap at cold start: thread (and its typing provider) is
    // built BEFORE the auth user is known.
    container.read(typingProvider('c1'));
    (container.read(authProvider.notifier) as _LateAuth).signIn(_user('me'));

    socket.emit(WsEvent(WsEventServer.typingStart, {'conversation_id': 'c1', 'user_id': 'me'}));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(typingProvider('c1')), isFalse, reason: 'my own echo');

    socket.emit(WsEvent(WsEventServer.typingStart, {'conversation_id': 'c1', 'user_id': 'them'}));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(typingProvider('c1')), isTrue, reason: 'the other side');
  });
}
