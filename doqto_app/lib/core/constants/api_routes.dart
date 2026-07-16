/// API route paths — mirrored from app/core/routes.py on the backend.
class ApiRoutes {
  ApiRoutes._();

  static const String apiV1 = '/api/v1';

  // Auth
  static const String authRequestOtp = '$apiV1/auth/request-otp';
  static const String authVerifyOtp = '$apiV1/auth/verify-otp';
  static const String authRefresh = '$apiV1/auth/refresh';
  static const String authLogout = '$apiV1/auth/logout';
  static const String authRegister = '$apiV1/auth/register';

  // Users
  static const String usersMe = '$apiV1/users/me';
  static const String usersMeAvatar = '$apiV1/users/me/avatar';

  // Orgs
  static const String orgs = '$apiV1/orgs';
  static const String orgsJoin = '$apiV1/orgs/join';
  static const String orgsMine = '$apiV1/orgs/mine';
  static String orgDetail(String id) => '$apiV1/orgs/$id';
  static String orgMembers(String id) => '$apiV1/orgs/$id/members';
  static String orgMember(String orgId, String userId) => '$apiV1/orgs/$orgId/members/$userId';
  static String orgInviteCode(String id) => '$apiV1/orgs/$id/invite-code';

  // Conversations
  static const String conversations = '$apiV1/conversations';
  static String conversationMessages(String id) => '$apiV1/conversations/$id/messages';
  static String conversationRead(String id) => '$apiV1/conversations/$id/read';
  static String conversationMembers(String id) => '$apiV1/conversations/$id/members';
  static String conversationMember(String convId, String userId) =>
      '$apiV1/conversations/$convId/members/$userId';
  static String conversationSettings(String id) => '$apiV1/conversations/$id/settings';

  // Messages
  static String messageUpload(String convId) => '$apiV1/messages/upload/$convId';
  static String messageVoiceNote(String convId) => '$apiV1/messages/voice-notes/$convId';
  static String messageRead(String id) => '$apiV1/messages/$id/read';
  static String messageFileUrl(String id) => '$apiV1/messages/$id/file-url';

  // Admin endpoints live in the separate Next.js admin panel — not in the mobile app.

  // WebSocket
  static String wsOrg(String orgId) => '/ws/$orgId';
}
