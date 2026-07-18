import '../../core/constants/api_routes.dart';
import '../../core/enums/app_enums.dart';
import '../api/api_client.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class ChatRepository {
  final ApiClient _api;
  ChatRepository(this._api);

  Future<List<Conversation>> listConversations() async {
    final list = await _api.getList(ApiRoutes.conversations);
    return list.map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
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

  Future<List<Message>> listMessages(String conversationId, {DateTime? before}) async {
    final list = await _api.getList(
      ApiRoutes.conversationMessages(conversationId),
      query: before != null ? {'before': before.toUtc().toIso8601String()} : null,
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
  }) async {
    final j = await _api.postMultipart(
      ApiRoutes.messageUpload(conversationId),
      fileField: 'file',
      bytes: bytes,
      filename: filename,
      // Server classifies IMAGE vs FILE from this MIME type.
      contentType: contentType,
    );
    return Message.fromJson(j);
  }

  Future<Message> uploadVoiceNote({
    required String conversationId,
    required List<int> bytes,
    required String filename,
    required int durationSec,
    String? transcript,
  }) async {
    final j = await _api.postMultipart(
      ApiRoutes.messageVoiceNote(conversationId),
      fileField: 'file',
      bytes: bytes,
      filename: filename,
      fields: {
        'duration_sec': durationSec,
        if (transcript != null && transcript.isNotEmpty) 'transcript': transcript,
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
