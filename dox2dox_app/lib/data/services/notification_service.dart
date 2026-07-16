import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around local notifications.
///
/// Local-first push: banners are driven by our own WebSocket while the app is
/// running (foreground or briefly backgrounded). When FCM/APNs is added later,
/// this same surface shows the remote payloads — which must be PHI-free
/// (sender/content only ever appear in LOCAL notifications, never in remote
/// payloads that transit Apple/Google).
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channel = AndroidNotificationDetails(
    'messages',
    'Messages',
    channelDescription: 'New secure messages',
    importance: Importance.high,
    priority: Priority.high,
  );

  /// [onTap] receives the notification payload (a conversation id).
  Future<void> init({required void Function(String payload) onTap}) async {
    if (_initialized) return;
    _initialized = true;
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload != null && payload.isNotEmpty) onTap(payload);
      },
    );
    // iOS runtime permission (no-op elsewhere).
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> showMessage({
    required String conversationId,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      // One notification per conversation — newest replaces older.
      id: conversationId.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        android: _channel,
      ),
      payload: conversationId,
    );
  }

  Future<void> cancelForConversation(String conversationId) =>
      _plugin.cancel(id: conversationId.hashCode);
}
