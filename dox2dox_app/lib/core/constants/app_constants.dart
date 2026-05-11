/// Timing + limits mirrored from backend app/core/constants.py.
class AppConstants {
  AppConstants._();

  // API base URL — overridden per environment via --dart-define=API_BASE_URL=...
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000', // Android emulator loopback
  );

  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://10.0.2.2:8000',
  );

  // OTP
  static const int otpLength = 6;
  static const Duration otpResendCooldown = Duration(seconds: 30);

  // WebSocket
  static const Duration wsHeartbeatInterval = Duration(seconds: 60);
  static const Duration wsReconnectBackoff = Duration(seconds: 3);

  // Voice notes
  static const Duration voiceNoteMaxDuration = Duration(minutes: 5);
  static const Duration voiceNoteMinDuration = Duration(seconds: 1);

  // Pagination
  static const int messagesPageSize = 50;

  // Storage keys
  static const String kAccessToken = 'dox2dox_access_token';
  static const String kRefreshToken = 'dox2dox_refresh_token';

  // Invite code format (visual)
  static const String inviteCodeSeparator = '·';
}
