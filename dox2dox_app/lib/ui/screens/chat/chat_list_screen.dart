import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/strings.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/radii.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/tokens/typography.dart';
import '../../../core/utils/datetime_format.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/organization.dart';
import '../../../state/auth_state.dart';
import '../../../state/chat_state.dart';
import '../../../state/org_state.dart';
import '../../widgets/doctor_avatar.dart';
import '_conversation_display.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convs = ref.watch(conversationsProvider);
    final user = ref.watch(authProvider).user;
    final currentOrg = ref.watch(orgProvider).current;
    final membersAsync = currentOrg == null
        ? const AsyncValue<List<OrgMember>>.data([])
        : ref.watch(orgMembersProvider(currentOrg.id));
    final orgMembers = membersAsync.asData?.value ?? const <OrgMember>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => context.push(AppRoutes.createGroup),
          ),
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: IconButton(
                tooltip: 'Profile',
                onPressed: () => context.push(AppRoutes.profile),
                icon: DoctorAvatar(
                  initials: user.initials,
                  size: AvatarSize.sm,
                  imageUrl: user.avatarPresignedUrl,
                ),
              ),
            ),
        ],
      ),
      body: convs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e', style: AppText.caption)),
        data: (rawList) {
          if (rawList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Text(
                  'Start a conversation from My Org.',
                  style: AppText.body,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final list = [...rawList]..sort((a, b) {
              final ta = a.lastMessageAt ?? a.updatedAt;
              final tb = b.lastMessageAt ?? b.updatedAt;
              return tb.compareTo(ta);
            });
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: list.length,
            separatorBuilder: (ctx, i) => const Divider(indent: AppSpacing.xxl + AppSpacing.lg, height: 0),
            itemBuilder: (ctx, i) {
              final c = list[i];
              final display = conversationDisplay(
                c: c,
                orgMembers: orgMembers,
                meId: user?.id,
                fallbackColorIndex: i,
              );
              return _ChatRow(
                conversation: c,
                display: display,
                orgMembers: orgMembers,
                meId: user?.id,
              );
            },
          );
        },
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final Conversation conversation;
  final ConversationDisplay display;
  final List<OrgMember> orgMembers;
  final String? meId;

  const _ChatRow({
    required this.conversation,
    required this.display,
    required this.orgMembers,
    required this.meId,
  });

  String? _resolveSenderFirstName(String senderId) {
    for (final m in orgMembers) {
      if (m.user.id == senderId) {
        final first = m.user.fullName.trim().split(RegExp(r'\s+')).first;
        return first.isEmpty ? null : first;
      }
    }
    return null;
  }

  String _previewText() {
    final c = conversation;
    final senderId = c.lastMessageSenderId;
    final isMine = senderId != null && senderId == meId;
    final type = c.lastMessageType;
    if (type == null) return 'Tap to start chatting';
    String body;
    switch (type) {
      case MessageType.text:
        body = c.lastMessagePreview ?? '';
        break;
      case MessageType.voiceNote:
        body = '🎙 Voice note';
        break;
      case MessageType.image:
        body = '📷 Photo';
        break;
      case MessageType.file:
        body = '📎 File';
        break;
      case MessageType.system:
        return c.lastMessagePreview ?? '';
    }
    if (body.isEmpty) return 'Tap to start chatting';
    if (isMine) return 'You: $body';
    if (!display.isDirect && senderId != null) {
      final name = _resolveSenderFirstName(senderId);
      if (name != null) return '$name: $body';
    }
    return body;
  }

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final hasMsg = c.lastMessageType != null;
    final previewStyle = hasMsg
        ? AppText.caption.copyWith(color: AppColors.textSecondary)
        : AppText.caption.copyWith(fontStyle: FontStyle.italic);
    return ListTile(
      onTap: () => context.push(AppRoutes.chat(c.id)),
      leading: DoctorAvatar(
        initials: display.initials,
        colorIndex: display.colorIndex,
        imageUrl: display.otherUser?.avatarPresignedUrl,
      ),
      title: Text(display.title, style: AppText.heading, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_previewText(), style: previewStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatChatListTime(c.lastMessageAt ?? c.updatedAt),
            style: c.unreadCount > 0
                ? AppText.timestamp.copyWith(color: AppColors.medBlue, fontWeight: FontWeight.w600)
                : AppText.timestamp,
          ),
          if (c.unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.medBlue,
                borderRadius: AppRadii.rFull,
              ),
              constraints: const BoxConstraints(minWidth: 20),
              child: Text(
                c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                style: AppText.badge.copyWith(color: AppColors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
