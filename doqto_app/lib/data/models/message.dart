import '../../core/enums/app_enums.dart';

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
  });

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
      );

  Message copyWith({
    String? transcript,
    TranscriptStatus? transcriptStatus,
    bool? read,
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
      );
}
