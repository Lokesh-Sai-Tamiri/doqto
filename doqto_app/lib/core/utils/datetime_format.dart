import 'package:intl/intl.dart';

/// WhatsApp-style compact timestamp for chat list rows.
/// - Today → "2:32 PM" (locale-aware; 24h where the locale uses it)
/// - Yesterday → "Yesterday"
/// - Within the past 7 days → weekday abbreviation ("Mon")
/// - Older → "dd/MM/yy"
String formatChatListTime(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final local = dt.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(local.year, local.month, local.day);
  final diffDays = today.difference(that).inDays;
  if (diffDays == 0) return DateFormat.jm().format(local);
  if (diffDays == 1) return 'Yesterday';
  if (diffDays < 7) return DateFormat.E().format(local); // Mon, Tue…
  return DateFormat('dd/MM/yy').format(local);
}
