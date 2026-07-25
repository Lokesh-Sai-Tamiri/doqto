import '../../core/constants/api_routes.dart';
import '../../core/enums/app_enums.dart';
import '../api/api_client.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class ChatRepository {
  final ApiClient _api;
  ChatRepository(this._api);

  /// [filter] == 'requests' returns received pending message requests
  /// (access=pending_request, initiator != me), each carrying `is_hidden`.
  /// The default (unfiltered) list excludes received requests but includes
  /// ones I initiated (rendered with a "Request sent" chip).
  Future<List<Conversation>> listConversations({String? filter}) async {
    final list = await _api.getList(
      ApiRoutes.conversations,
      query: filter == null ? null : {'filter': filter},
    );
    return list.map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Recipient accepts a pending message request → access flips to open and the
  /// conversation moves to Focused. Idempotent server-side.
  Future<void> acceptRequest(String conversationId) async {
    await _api.post(ApiRoutes.conversationRequestAccept(conversationId));
  }

  /// Recipient declines a pending message request (silent to the initiator).
  Future<void> declineRequest(String conversationId) async {
    await _api.post(ApiRoutes.conversationRequestDecline(conversationId));
  }

  Future<Conversation> createConversation({
    required ConversationType type,
    String? name,
    required List<String> memberIds,
  }) async {
    final j = await _api.post(ApiRoutes.conversations, body: {
      'type': type.wire,
      'name': name,
      'member_ids': memberIds,
    });
    return Conversation.fromJson(j);
  }

  /// [before] pages backwards (history); [afterSeq] pages forwards in seq
  /// order (catch-up after offline). The server rejects both together.
  Future<List<Message>> listMessages(
    String conversationId, {
    DateTime? before,
    int? afterSeq,
  }) async {
    final query = <String, dynamic>{
      'before': ?before?.toUtc().toIso8601String(),
      'after_seq': ?afterSeq,
    };
    final list = await _api.getList(
      ApiRoutes.conversationMessages(conversationId),
      query: query.isEmpty ? null : query,
    );
    return list.map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Message> sendText(
    String conversationId,
    String content, {
    String? clientId,
  }) async {
    final j = await _api.post(
      ApiRoutes.conversationMessages(conversationId),
      body: {
        'type': MessageType.text.wire,
        'content': content,
        // Outbox idempotency key — retries return the original row.
        'client_id': ?clientId,
      },
    );
    return Message.fromJson(j);
  }

  Future<Message> uploadFile({
    required String conversationId,
    required List<int> bytes,
    required String filename,
    String? contentType,
    String? clientId,
  }) async {
    final j = await _api.postMultipart(
      ApiRoutes.messageUpload(conversationId),
      fileField: 'file',
      bytes: bytes,
      filename: filename,
      // Server classifies IMAGE vs FILE from this MIME type.
      contentType: contentType,
      fields: {
        // Outbox idempotency key — retries return the original row.
        'client_id': ?clientId,
      },
    );
    return Message.fromJson(j);
  }

  Future<Message> uploadVoiceNote({
    required String conversationId,
    required List<int> bytes,
    required String filename,
    required int durationSec,
    String? transcript,
    String? clientId,
  }) async {
    final j = await _api.postMultipart(
      ApiRoutes.messageVoiceNote(conversationId),
      fileField: 'file',
      bytes: bytes,
      filename: filename,
      fields: {
        'duration_sec': durationSec,
        if (transcript != null && transcript.isNotEmpty) 'transcript': transcript,
        // Outbox idempotency key — retries return the original row.
        'client_id': ?clientId,
      },
    );
    return Message.fromJson(j);
  }

  Future<void> markRead(String messageId) async {
    await _api.post(ApiRoutes.messageRead(messageId));
  }

  Future<void> markConversationRead(String conversationId) async {
    await _api.post(ApiRoutes.conversationRead(conversationId));
  }

  /// Ack receipt → sender's gray double-check. Fire on message arrival.
  Future<void> markConversationDelivered(String conversationId) async {
    await _api.post(ApiRoutes.conversationDelivered(conversationId));
  }

  Future<String> fileUrl(String messageId) async {
    final j = await _api.get(ApiRoutes.messageFileUrl(messageId));
    return j['url'] as String;
  }

  Future<void> addMembers(String conversationId, List<String> userIds) async {
    await _api.patch(ApiRoutes.conversationMembers(conversationId), body: {'user_ids': userIds});
  }

  Future<void> removeMember(String conversationId, String userId) async {
    await _api.delete(ApiRoutes.conversationMember(conversationId, userId));
  }

  Future<void> updateSettings(String conversationId, {int? disappearAfterSec}) async {
    await _api.patch(
      ApiRoutes.conversationSettings(conversationId),
      body: {'disappear_after_sec': disappearAfterSec},
    );
  }
}
