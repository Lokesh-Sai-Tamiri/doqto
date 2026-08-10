import '../../core/enums/app_enums.dart';

/// Client-side send lifecycle (not a wire enum — the server only ever returns
/// persisted messages, which are always [sent]).
enum MessageStatus { sending, sent, failed }

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final MessageType type;
  final String? content;
  final String? s3Key;
  final String? fileName;
  final int? fileSizeBytes;
  final int? voiceDurationSec;
  final String? transcript;
  final TranscriptStatus transcriptStatus;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final bool read;
  final bool delivered;
  final MessageStatus status;
  final String? clientId; // outbox idempotency key (echoed by the server)
  final int? seq; // per-conversation sequence (null for pending/legacy cache)
  // Outbox media file on disk — lets pending image bubbles show a real
  // preview instead of a filename. Never serialized; rebuilt from the outbox.
  final String? localPath;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    required this.content,
    required this.s3Key,
    required this.fileName,
    required this.fileSizeBytes,
    required this.voiceDurationSec,
    required this.transcript,
    required this.transcriptStatus,
    required this.expiresAt,
    required this.createdAt,
    this.read = false,
    this.delivered = false,
    this.status = MessageStatus.sent,
    this.clientId,
    this.seq,
    this.localPath,
  });

  /// Optimistic local message (text, media, or voice): shown with a clock tick
  /// while the outbox delivers it. `id` is the clientId until the server row
  /// replaces it.
  factory Message.pending({
    required String clientId,
    required String conversationId,
    required String senderId,
    String? content,
    MessageType type = MessageType.text,
    String? fileName,
    int? voiceDurationSec,
    String? transcript,
    MessageStatus status = MessageStatus.sending,
    String? localPath,
  }) =>
      Message(
        id: clientId,
        conversationId: conversationId,
        senderId: senderId,
        type: type,
        content: content,
        s3Key: null,
        fileName: fileName,
        fileSizeBytes: null,
        voiceDurationSec: voiceDurationSec,
        transcript: transcript,
        transcriptStatus: TranscriptStatus.none,
        expiresAt: null,
        createdAt: DateTime.now().toUtc(),
        status: status,
        clientId: clientId,
        localPath: localPath,
      );

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String,
        conversationId: j['conversation_id'] as String,
        senderId: j['sender_id'] as String,
        type: MessageType.fromWire(j['type'] as String),
        content: j['content'] as String?,
        s3Key: j['s3_key'] as String?,
        fileName: j['file_name'] as String?,
        fileSizeBytes: j['file_size_bytes'] as int?,
        voiceDurationSec: j['voice_duration_sec'] as int?,
        transcript: j['transcript'] as String?,
        transcriptStatus:
            TranscriptStatus.fromWire((j['transcript_status'] as String?) ?? 'none'),
        expiresAt: j['expires_at'] != null ? DateTime.parse(j['expires_at'] as String) : null,
        createdAt: DateTime.parse(j['created_at'] as String),
        read: (j['read'] as bool?) ?? false,
        delivered: (j['delivered'] as bool?) ?? false,
        clientId: j['client_id'] as String?,
        seq: j['seq'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'type': type.wire,
        'content': content,
        's3_key': s3Key,
        'file_name': fileName,
        'file_size_bytes': fileSizeBytes,
        'voice_duration_sec': voiceDurationSec,
        'transcript': transcript,
        'transcript_status': transcriptStatus.wire,
        'expires_at': expiresAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'read': read,
        'delivered': delivered,
        'client_id': clientId,
        'seq': seq,
      };

  Message copyWith({
    String? transcript,
    TranscriptStatus? transcriptStatus,
    bool? read,
    bool? delivered,
    MessageStatus? status,
  }) =>
      Message(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        type: type,
        content: content,
        s3Key: s3Key,
        fileName: fileName,
        fileSizeBytes: fileSizeBytes,
        voiceDurationSec: voiceDurationSec,
        transcript: transcript ?? this.transcript,
        transcriptStatus: transcriptStatus ?? this.transcriptStatus,
        expiresAt: expiresAt,
        createdAt: createdAt,
        read: read ?? this.read,
        delivered: delivered ?? this.delivered,
        status: status ?? this.status,
        clientId: clientId,
        seq: seq,
        localPath: localPath,
      );
}
