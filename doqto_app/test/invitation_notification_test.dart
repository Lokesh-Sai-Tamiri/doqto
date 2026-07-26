import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/core/constants/strings.dart';
import 'package:doqto_app/core/di/providers.dart';
import 'package:doqto_app/core/enums/app_enums.dart';
import 'package:doqto_app/data/api/websocket_client.dart';
import 'package:doqto_app/data/services/notification_service.dart';
import 'package:doqto_app/state/notification_state.dart';

/// Records banners instead of talking to the platform plugin.
class _RecordingNotifications extends NotificationService {
  final List<Map<String, String>> shown = [];

  @override
  Future<void> init({required void Function(String payload) onTap}) async {}

  @override
  Future<void> showNetworkEvent({
    required String tag,
    required String title,
    required String body,
    required String route,
  }) async {
    shown.add({'tag': tag, 'title': title, 'body': body, 'route': route});
  }
}

/// A socket we can push events into.
class _FakeSocket extends WebsocketClient {
  final _controller = StreamController<WsEvent>.broadcast();
  @override
  Stream<WsEvent> get events => _controller.stream;
  void emit(WsEvent e) => _controller.add(e);
}

void main() {
  late _RecordingNotifications notifications;
  late _FakeSocket socket;
  late ProviderContainer container;

  setUp(() {
    notifications = _RecordingNotifications();
    socket = _FakeSocket();
    container = ProviderContainer(overrides: [
      notificationServiceProvider.overrideWithValue(notifications),
      websocketClientProvider.overrideWithValue(socket),
    ]);
    container.read(notificationListenerProvider); // activate the listener
  });
  tearDown(() => container.dispose());

  test('an incoming connection request raises a banner', () async {
    socket.emit(WsEvent(WsEventServer.invitationReceived, {
      'invitation_id': 'i1',
      'sender_id': 'u7',
      'sender_name': 'Dr. Robert Morgan',
    }));
    await Future<void>.delayed(Duration.zero);

    expect(notifications.shown, hasLength(1));
    final banner = notifications.shown.single;
    expect(banner['title'], Strings.netInvitationNotificationTitle);
    expect(banner['body'], 'Dr. Robert Morgan sent you a connection request');
    // Tapping lands on the sender's profile, where Accept lives.
    expect(banner['route'], 'doqto:///people/u7');
    expect(routePathForPayload(banner['route']!), '/people/u7');
  });

  test('a nameless payload still notifies, and repeats replace', () async {
    socket.emit(WsEvent(WsEventServer.invitationReceived, {'sender_id': 'u7'}));
    socket.emit(WsEvent(WsEventServer.invitationReceived, {'sender_id': 'u7'}));
    await Future<void>.delayed(Duration.zero);

    expect(notifications.shown, hasLength(2));
    expect(notifications.shown.first['body'],
        Strings.netInvitationNotificationBodyGeneric);
    // Same dedupe tag → the platform replaces rather than stacks.
    expect(notifications.shown.first['tag'], notifications.shown.last['tag']);
  });

  test('an event without a sender is ignored', () async {
    socket.emit(WsEvent(WsEventServer.invitationReceived, {'invitation_id': 'i1'}));
    await Future<void>.delayed(Duration.zero);
    expect(notifications.shown, isEmpty);
  });

  test('an incoming message request raises a banner', () async {
    socket.emit(WsEvent(WsEventServer.conversationRequestReceived, {
      'conversation_id': 'c9',
      'sender_id': 'u7',
      'sender_name': 'Dr. Laura Caldwell',
    }));
    await Future<void>.delayed(Duration.zero);

    final banner = notifications.shown.single;
    expect(banner['title'], Strings.netRequestNotificationTitle);
    expect(banner['body'], 'Dr. Laura Caldwell sent you a message request');
    // Opens the request thread itself, where Accept / Block live.
    expect(banner['route'], 'doqto:///chat/c9');
    expect(routePathForPayload(banner['route']!), '/chat/c9');
    // The stranger's opening line must never ride along in the banner.
    expect(banner['body'], isNot(contains('quick consult')));
  });

  test('the sender is told when their connection request is accepted',
      () async {
    socket.emit(WsEvent(WsEventServer.invitationAccepted, {
      'invitation_id': 'i1',
      'user_id': 'u9',
      'user_name': 'Dr. Aaron Mercado',
    }));
    await Future<void>.delayed(Duration.zero);

    final banner = notifications.shown.single;
    expect(banner['title'], Strings.netConnectedNotificationTitle);
    expect(banner['body'], 'Dr. Aaron Mercado accepted your connection request');
    expect(banner['route'], 'doqto:///people/u9');
  });

  test('the initiator is told when their message request is accepted',
      () async {
    socket.emit(WsEvent(WsEventServer.conversationRequestAccepted, {
      'conversation_id': 'c4',
      'user_id': 'u9',
      'user_name': 'Dr. Aaron Mercado',
    }));
    await Future<void>.delayed(Duration.zero);

    final banner = notifications.shown.single;
    expect(banner['title'], Strings.netRequestAcceptedNotificationTitle);
    expect(banner['body'], 'Dr. Aaron Mercado accepted your message request');
    // Straight into the thread that just unlocked.
    expect(banner['route'], 'doqto:///chat/c4');
    expect(routePathForPayload(banner['route']!), '/chat/c4');
  });

  test('accepted events without their id are ignored', () async {
    socket.emit(WsEvent(WsEventServer.invitationAccepted, {'user_name': 'X'}));
    socket.emit(
        WsEvent(WsEventServer.conversationRequestAccepted, {'user_name': 'X'}));
    await Future<void>.delayed(Duration.zero);
    expect(notifications.shown, isEmpty);
  });
}
