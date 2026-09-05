import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

/// Abstraction over the platform push-token source (FCM/APNs). The real
/// firebase_messaging-backed implementation slots in later via env/config;
/// until then [StubPushTokenProvider] keeps the registration plumbing wired
/// end-to-end without any Firebase dependency.
abstract class PushTokenProvider {
  /// Current device push token, or null when none is available (stub, or
  /// permissions denied).
  Future<String?> getToken();

  /// Emits whenever the platform rotates the token — each emission must be
  /// re-registered with the backend.
  Stream<String> get onTokenRefresh;
}

/// No-op provider used until real FCM/APNs wiring lands.
class StubPushTokenProvider implements PushTokenProvider {
  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream<String>.empty();
}

/// Real FCM-backed provider. On iOS firebase_messaging bridges the APNs token
/// to an FCM token, so the backend only ever deals with FCM tokens.
class FirebasePushTokenProvider implements PushTokenProvider {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  @override
  Future<String?> getToken() async {
    final perm = await _fcm.requestPermission(alert: true, badge: true, sound: true);
    if (perm.authorizationStatus == AuthorizationStatus.denied) return null;
    return _fcm.getToken();
  }

  @override
  Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;
}
