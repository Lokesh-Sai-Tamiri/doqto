/// A superseded version of an edited message (transparent edit history).
class MessageEdit {
  final String content;
  final DateTime replacedAt;

  const MessageEdit({required this.content, required this.replacedAt});

  factory MessageEdit.fromJson(Map<String, dynamic> j) => MessageEdit(
        content: j['content'] as String,
        replacedAt: DateTime.parse(j['replaced_at'] as String),
      );
}
