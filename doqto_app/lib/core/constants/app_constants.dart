/// Timing + limits mirrored from backend app/core/constants.py.
class AppConstants {
  AppConstants._();

  // API base URL — defaults to production; override for local dev with
  // --dart-define=API_BASE_URL=http://10.0.2.2:8000 (Android emulator loopback)
  // and --dart-define=WS_BASE_URL=ws://10.0.2.2:8000.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.doqto.ai',
  );

  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://api.doqto.ai',
  );

  // OTP
  static const int otpLength = 6;
  static const Duration otpResendCooldown = Duration(seconds: 30);

  // WebSocket — exponential backoff with jitter, base doubling up to the cap.
  static const Duration wsHeartbeatInterval = Duration(seconds: 60);
  // Mirrors WS_HEARTBEAT_TIMEOUT_SECONDS on the backend (2× interval + 10s):
  // silence beyond this on either side means the connection is dead.
  static const Duration wsHeartbeatTimeout = Duration(seconds: 130);
  static const Duration wsReconnectBaseBackoff = Duration(seconds: 1);
  static const Duration wsReconnectMaxBackoff = Duration(seconds: 30);

  // Voice notes
  static const Duration voiceNoteMaxDuration = Duration(minutes: 5);
  static const Duration voiceNoteMinDuration = Duration(seconds: 1);

  // Pagination
  static const int messagesPageSize = 50;

  // Sessions / privacy

  /// H3: whether banner bodies show message content. True is acceptable only
  /// while banners are foreground-only (device unlocked, app open). MUST
  /// default to false before any lock-screen / remote (FCM/APNs) path ships.
  static const bool showMessagePreviews = true;

  // Storage keys
  static const String kAccessToken = 'doqto_access_token';
  static const String kRefreshToken = 'doqto_refresh_token';
  static const String kHiveBoxKey = 'doqto_hive_box_key';

  // Invite code format (visual)
  static const String inviteCodeSeparator = '·';
}
