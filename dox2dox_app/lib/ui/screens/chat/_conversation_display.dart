import '../../../core/enums/app_enums.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/organization.dart';
import '../../../data/models/user.dart';

class ConversationDisplay {
  final String title;
  final User? otherUser;   // direct: the other member; group/unknown: null
  final bool isDirect;
  final int colorIndex;    // for fallback DoctorAvatar
  final String initials;

  const ConversationDisplay({
    required this.title,
    required this.otherUser,
    required this.isDirect,
    required this.colorIndex,
    required this.initials,
  });
}

/// Derive a display-ready title/avatar bundle for a conversation.
///
/// - Direct: finds the OTHER member in `orgMembers` and uses their profile.
/// - Group: uses `c.name` as title with generated initials.
ConversationDisplay conversationDisplay({
  required Conversation c,
  required List<OrgMember> orgMembers,
  required String? meId,
  required int fallbackColorIndex,
}) {
  if (c.type == ConversationType.direct) {
    String? otherId;
    for (final id in c.memberIds) {
      if (id != meId) {
        otherId = id;
        break;
      }
    }
    OrgMember? otherMember;
    if (otherId != null) {
      for (final m in orgMembers) {
        if (m.user.id == otherId) {
          otherMember = m;
          break;
        }
      }
    }
    if (otherMember != null) {
      final u = otherMember.user;
      return ConversationDisplay(
        title: u.fullName,
        otherUser: u,
        isDirect: true,
        colorIndex: fallbackColorIndex,
        initials: u.initials,
      );
    }
    return ConversationDisplay(
      title: 'Direct chat',
      otherUser: null,
      isDirect: true,
      colorIndex: fallbackColorIndex,
      initials: '•',
    );
  }
  // Group (or anything else).
  final name = (c.name == null || c.name!.trim().isEmpty) ? 'Group' : c.name!;
  final parts = name.trim().split(RegExp(r'\s+'));
  final initials = parts.length >= 2
      ? (parts[0][0] + parts[1][0]).toUpperCase()
      : name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  return ConversationDisplay(
    title: name,
    otherUser: null,
    isDirect: false,
    colorIndex: fallbackColorIndex,
    initials: initials,
  );
}
