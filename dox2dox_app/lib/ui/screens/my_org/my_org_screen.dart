import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/tokens/typography.dart';
import '../../../core/utils/error_messages.dart';
import '../../../data/models/organization.dart';
import '../../../state/auth_state.dart';
import '../../../state/org_state.dart';
import '../../widgets/doctor_avatar.dart';
import '../../widgets/invite_code_card.dart';

class MyOrgScreen extends ConsumerWidget {
  const MyOrgScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(orgProvider).current;
    final me = ref.watch(authProvider).user;
    return Scaffold(
      appBar: AppBar(title: Text(org?.name ?? 'My Org')),
      body: org == null
          ? const Center(child: Text('No organization selected'))
          : ref.watch(orgMembersProvider(org.id)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e', style: AppText.caption)),
                data: (members) {
                  final isAdmin = me != null &&
                      members.any((m) =>
                          m.user.id == me.id && m.orgRole == OrgRole.admin);
                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                    children: [
                      if (isAdmin) ...[
                        InviteCodeCard(code: org.inviteCode),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      Text('MEMBERS (${org.memberCount})', style: AppText.label),
                      const SizedBox(height: AppSpacing.sm),
                      for (final (i, m) in members.indexed)
                        _MemberRow(
                          member: m,
                          colorIndex: i,
                          isSelf: me != null && m.user.id == me.id,
                        ),
                    ],
                  );
                },
              ),
    );
  }
}

class _MemberRow extends ConsumerStatefulWidget {
  final OrgMember member;
  final int colorIndex;
  final bool isSelf;

  const _MemberRow({
    required this.member,
    required this.colorIndex,
    required this.isSelf,
  });

  @override
  ConsumerState<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends ConsumerState<_MemberRow> {
  bool _starting = false;

  Future<void> _startChat() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final conv = await ref.read(chatRepositoryProvider).createConversation(
            type: ConversationType.direct,
            name: null,
            memberIds: [widget.member.user.id],
          );
      if (!mounted) return;
      context.push(AppRoutes.chat(conv.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ErrorMessages.forApi(e)),
        backgroundColor: AppColors.red,
      ));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _openProfile() {
    // For self, omit `extra` so we see the editable self view.
    context.push(
      AppRoutes.profile,
      extra: widget.isSelf ? null : widget.member.user,
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: _openProfile,
      leading: DoctorAvatar(
        initials: m.user.initials,
        colorIndex: widget.colorIndex,
        imageUrl: m.user.avatarPresignedUrl,
      ),
      title: Text(m.user.fullName),
      subtitle: Text(
        m.user.specialty ?? (widget.isSelf ? 'You' : ''),
      ),
      trailing: widget.isSelf
          ? null
          : SizedBox(
              width: 40,
              height: 40,
              child: _starting
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      tooltip: 'Message',
                      icon: const Icon(Icons.chat_bubble_outline),
                      color: AppColors.medBlue,
                      onPressed: _startChat,
                    ),
            ),
    );
  }
}
