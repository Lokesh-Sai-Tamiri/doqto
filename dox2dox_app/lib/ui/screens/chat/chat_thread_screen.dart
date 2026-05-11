import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../core/constants/strings.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/radii.dart';
import '../../../core/tokens/spacing.dart';
import '../../../data/models/organization.dart';
import '../../../state/auth_state.dart';
import '../../../state/chat_state.dart';
import '../../../state/org_state.dart';
import '../../widgets/doctor_avatar.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/voice_note_bubble.dart';
import '_conversation_display.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatThreadScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _input = TextEditingController();

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await ref.read(messagesProvider(widget.conversationId).notifier).sendText(text);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).user;
    final async = ref.watch(messagesProvider(widget.conversationId));
    final convs = ref.watch(conversationsProvider).asData?.value ?? const [];
    final conv = convs.where((c) => c.id == widget.conversationId).cast<dynamic>().firstOrNull;
    final currentOrg = ref.watch(orgProvider).current;
    final orgMembers = currentOrg == null
        ? const <OrgMember>[]
        : (ref.watch(orgMembersProvider(currentOrg.id)).asData?.value ?? const <OrgMember>[]);
    final display = conv == null
        ? null
        : conversationDisplay(
            c: conv,
            orgMembers: orgMembers,
            meId: me?.id,
            fallbackColorIndex: 0,
          );
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: display == null
            ? const Text('Chat')
            : InkWell(
                onTap: display.isDirect && display.otherUser != null
                    ? () => context.push(AppRoutes.profile, extra: display.otherUser)
                    : null,
                child: Row(
                  children: [
                    DoctorAvatar(
                      initials: display.initials,
                      size: AvatarSize.sm,
                      imageUrl: display.otherUser?.avatarPresignedUrl,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        display.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
      ),
      body: Column(
        children: [
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (msgs) => ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final m = msgs[i];
                  final isMine = me?.id == m.senderId;
                  if (m.type == MessageType.voiceNote) {
                    return VoiceNoteBubble(
                      durationSec: m.voiceDurationSec ?? 0,
                      transcript: m.transcript,
                      isMine: isMine,
                    );
                  }
                  return MessageBubble(
                    text: m.content ?? '[${m.type.wire}]',
                    isMine: isMine,
                    timestamp: m.createdAt.toLocal(),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              color: AppColors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: InputDecoration(
                        hintText: Strings.chatMessageHint,
                        border: OutlineInputBorder(borderRadius: AppRadii.rFull),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md + 2,
                          vertical: AppSpacing.sm + 1,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send, color: AppColors.medBlue),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
