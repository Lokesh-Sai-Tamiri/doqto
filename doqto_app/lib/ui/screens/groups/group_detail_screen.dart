import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/strings.dart';
import '../../../core/di/providers.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/motion.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/tokens/typography.dart';
import '../../../core/utils/error_messages.dart';
import '../../../data/models/group.dart';
import '../../../state/auth_state.dart';
import '../../../state/groups_state.dart';
import '../chat/chat_thread_screen.dart';
import '../../widgets/app_pill.dart';
import '../../widgets/app_segmented.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/doctor_avatar.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/join_button.dart';
import '../../widgets/member_row.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  /// Optional starting segment (0=Chat, 1=Members, 2=About, 3=Requests). Used
  /// by the `/groups/:id/requests` deep route. Null → member-aware default.
  final int? initialSegment;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    this.initialSegment,
  });

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  int _segment = 0;
  bool _segmentInit = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(groupDetailProvider(widget.groupId));
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: async.when(
        loading: () => const SafeArea(child: SkeletonList()),
        error: (e, _) => _ErrorScaffold(
          message: ErrorMessages.forApi(e),
          onRetry: () => ref.invalidate(groupDetailProvider(widget.groupId)),
        ),
        data: (group) => _buildLoaded(context, group),
      ),
    );
  }

  GroupMembershipTag _tagFor(Group g) {
    if (g.isMember) return GroupMembershipTag.member;
    if (g.membershipTag != GroupMembershipTag.none) return g.membershipTag;
    final my = ref.watch(myGroupsProvider).valueOrNull;
    if (my != null) {
      if (my.requested.any((x) => x.id == g.id)) {
        return GroupMembershipTag.requested;
      }
      if (my.invited.any((x) => x.id == g.id)) return GroupMembershipTag.invited;
    }
    return GroupMembershipTag.none;
  }

  Widget _buildLoaded(BuildContext context, Group group) {
    final tag = _tagFor(group);
    final isMember = tag == GroupMembershipTag.member;
    final isAdmin = group.isAdmin;

    // Default the segment to Chat for members, About for outsiders (or the
    // explicit initialSegment from a deep route, e.g. /groups/:id/requests).
    if (!_segmentInit) {
      _segmentInit = true;
      _segment = widget.initialSegment ?? (isMember ? 0 : 2);
    }

    final tabs = <String>[
      Strings.groupsChatLabel,
      Strings.groupMembersLabel,
      Strings.groupAboutLabel,
      if (isAdmin) Strings.groupRequestsLabel,
    ];
    final reqCount =
        isAdmin ? (ref.watch(adminJoinRequestCountProvider(group.id)).valueOrNull ?? 0) : 0;
    final badges = <int?>[null, null, null, if (isAdmin) reqCount];
    if (_segment >= tabs.length) _segment = 0;

    return SafeArea(
      child: Column(
        children: [
          _TopBar(group: group, isMember: isMember, onLeave: () => _leave(group)),
          _Header(group: group),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
            ),
            child: JoinButton(
              joinPolicy: group.joinPolicy,
              membershipTag: tag,
              busy: _busy,
              expand: true,
              onJoin: () => _join(group),
              onRequest: () => _requestToJoin(group),
              onWithdraw: () => _withdraw(group),
              onOpenChat: () => setState(() => _segment = 0),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
            child: AppSegmented(
              tabs: tabs,
              index: _segment,
              badges: badges,
              onChanged: (i) => setState(() => _segment = i),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _segmentBody(group, isMember, isAdmin)),
        ],
      ),
    );
  }

  Widget _segmentBody(Group group, bool isMember, bool isAdmin) {
    switch (_segment) {
      case 0:
        return _ChatSegment(group: group, isMember: isMember);
      case 1:
        return _MembersSegment(groupId: group.id);
      case 2:
        return _AboutSegment(group: group);
      default:
        return _RequestsSegment(groupId: group.id);
    }
  }

  // ---- Join state machine actions ---------------------------------------

  GroupDetailNotifier get _notifier =>
      ref.read(groupDetailProvider(widget.groupId).notifier);

  Future<void> _join(Group group) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _notifier.join();
      if (!mounted) return;
      setState(() => _segment = 0); // land in the chat
      _toast(Strings.groupJoinedToast);
    } catch (e) {
      _toast(ErrorMessages.forApi(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestToJoin(Group group) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _notifier.requestToJoin();
      if (mounted) _toast(Strings.groupJoinRequestSentToast);
    } catch (e) {
      _toast(ErrorMessages.forApi(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(Group group) async {
    final ok = await _confirm(Strings.groupsWithdrawConfirm,
        confirmLabel: Strings.groupsWithdrawRequest);
    if (ok != true) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _notifier.withdrawRequest();
    } catch (e) {
      _toast(ErrorMessages.forApi(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave(Group group) async {
    final me = ref.read(authProvider).user;
    if (me == null) return;
    final ok = await _confirm(Strings.netLeaveGroupConfirm,
        confirmLabel: Strings.groupLeave);
    if (ok != true) return;
    try {
      await _notifier.leave(me.id);
      if (mounted) {
        _toast(Strings.groupLeftToast);
        context.pop();
      }
    } catch (e) {
      if (mounted) _toast(ErrorMessages.forApi(e), error: true);
    }
  }

  Future<bool?> _confirm(String body, {required String confirmLabel}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(Strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.red : null,
    ));
  }
}

// -------------------------------------------------------------------------- //
// Top bar + header
// -------------------------------------------------------------------------- //
class _TopBar extends StatelessWidget {
  final Group group;
  final bool isMember;
  final VoidCallback onLeave;
  const _TopBar(
      {required this.group, required this.isMember, required this.onLeave});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        const Spacer(),
        if (isMember)
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'leave') onLeave();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'leave', child: Text(Strings.groupLeave)),
            ],
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final Group group;
  const _Header({required this.group});

  (String, PillTone) get _visibility => switch (group.visibility) {
        GroupVisibility.public => ('Public', PillTone.success),
        GroupVisibility.private => ('Private', PillTone.brand),
        GroupVisibility.secret => ('Secret', PillTone.neutral),
        GroupVisibility.unknown => ('Group', PillTone.neutral),
      };

  @override
  Widget build(BuildContext context) {
    final (visLabel, visTone) = _visibility;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
        AppSpacing.screenHorizontal,
        0,
      ),
      child: Column(
        children: [
          DoctorAvatar(
            initials: group.initials,
            colorIndex: group.avatarIndex,
            imageUrl: group.avatarUrl,
            size: AvatarSize.xxl,
            heroTag: 'group-avatar-${group.id}',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            group.name,
            style: AppText.heading,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppPill(label: visLabel, tone: visTone, icon: Icons.visibility_outlined),
              const SizedBox(width: AppSpacing.sm),
              Text(
                group.memberCount == 1 ? '1 member' : '${group.memberCount} members',
                style: AppText.caption,
              ),
            ],
          ),
          if (group.description != null && group.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              group.description!,
              style: AppText.body,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------------- //
// Segments
// -------------------------------------------------------------------------- //
class _ChatSegment extends StatelessWidget {
  final Group group;
  final bool isMember;
  const _ChatSegment({required this.group, required this.isMember});

  @override
  Widget build(BuildContext context) {
    if (!isMember || group.conversationId.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 40, color: AppColors.gray400),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Join this group to see the conversation.',
                style: AppText.body,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    // Reuse the existing chat thread — same MessagesNotifier plumbing, receipts
    // and composer — embedded without its own AppBar (the group header owns it).
    return ChatThreadScreen(
      conversationId: group.conversationId,
      showAppBar: false,
    );
  }
}

class _MembersSegment extends ConsumerWidget {
  final String groupId;
  const _MembersSegment({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupMembersProvider(groupId));
    return async.when(
      loading: () => const SkeletonList(),
      error: (e, _) => _InlineError(
        message: ErrorMessages.forApi(e),
        onRetry: () => ref.invalidate(groupMembersProvider(groupId)),
      ),
      data: (members) {
        if (members.isEmpty) {
          return const _EmptyLabel(Strings.groupsNoMembers);
        }
        return ListView.builder(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
          ),
          itemCount: members.length,
          itemBuilder: (context, i) {
            final m = members[i];
            return FadeSlideIn.staggered(
              i,
              MemberRow(
                avatar: DoctorAvatar(
                  initials: m.initials,
                  colorIndex: m.avatarIndex,
                  imageUrl: m.avatarUrl,
                ),
                title: m.fullName,
                subtitle: m.specialty ?? m.headline,
                trailing: _roleBadge(m.role),
                // No relationship in the payload → tap routes to the profile,
                // where the full Connect/Message affordance lives.
                onTap: () => context.push(AppRoutes.person(m.userId)),
              ),
              enabled: i <= AppMotion.staggerCap,
            );
          },
        );
      },
    );
  }

  Widget? _roleBadge(GroupRole role) => switch (role) {
        GroupRole.owner => const AppPill(label: 'Owner', tone: PillTone.brand),
        GroupRole.admin => const AppPill(label: 'Admin', tone: PillTone.brand),
        GroupRole.moderator =>
          const AppPill(label: 'Mod', tone: PillTone.neutral),
        _ => null,
      };
}

class _AboutSegment extends StatelessWidget {
  final Group group;
  const _AboutSegment({required this.group});

  String get _joinRule => switch (group.joinPolicy) {
        GroupJoinPolicy.open => Strings.groupsPolicyOpen,
        GroupJoinPolicy.request => Strings.groupsPolicyRequest,
        GroupJoinPolicy.inviteOnly => Strings.groupsPolicyInviteOnly,
        _ => Strings.groupsPolicyInviteOnly,
      };

  String get _dmRule => switch (group.memberDmPolicy) {
        'open' => Strings.groupsDmOpen,
        'request' => Strings.groupsDmRequest,
        'disabled' => Strings.groupsDmDisabled,
        _ => Strings.groupsDmRequest,
      };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        0,
        AppSpacing.screenHorizontal,
        MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
      ),
      children: [
        if (group.description != null && group.description!.isNotEmpty)
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Strings.groupAboutLabel, style: AppText.label),
                const SizedBox(height: AppSpacing.xs),
                Text(group.description!, style: AppText.body),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _aboutLine(Strings.groupsRulesLabel, _joinRule),
              const Divider(height: AppSpacing.lg),
              _aboutLine(Strings.groupsMemberMessagingLabel, _dmRule),
              if (group.createdAt != null) ...[
                const Divider(height: AppSpacing.lg),
                _aboutLine(
                  Strings.groupsCreatedLabel,
                  _formatDate(group.createdAt!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _aboutLine(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label),
          const SizedBox(height: 2),
          Text(value, style: AppText.body),
        ],
      );

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final l = d.toLocal();
    return '${months[l.month - 1]} ${l.day}, ${l.year}';
  }
}

class _RequestsSegment extends ConsumerWidget {
  final String groupId;
  const _RequestsSegment({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(joinRequestsProvider(groupId));
    return async.when(
      loading: () => const SkeletonList(),
      error: (e, _) => _InlineError(
        message: ErrorMessages.forApi(e),
        onRetry: () => ref.invalidate(joinRequestsProvider(groupId)),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return const _EmptyLabel(Strings.groupsNoRequests);
        }
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            0,
            AppSpacing.screenHorizontal,
            MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
          ),
          itemCount: requests.length,
          itemBuilder: (context, i) => FadeSlideIn.staggered(
            i,
            _JoinRequestCard(groupId: groupId, request: requests[i]),
            enabled: i <= AppMotion.staggerCap,
          ),
        );
      },
    );
  }
}

class _JoinRequestCard extends ConsumerStatefulWidget {
  final String groupId;
  final GroupJoinRequest request;
  const _JoinRequestCard({required this.groupId, required this.request});

  @override
  ConsumerState<_JoinRequestCard> createState() => _JoinRequestCardState();
}

class _JoinRequestCardState extends ConsumerState<_JoinRequestCard> {
  bool _busy = false;

  Future<void> _act(bool approve) async {
    if (_busy) return;
    setState(() => _busy = true);
    final repo = ref.read(groupsRepositoryProvider);
    try {
      final r = widget.request;
      if (approve) {
        await repo.approveJoinRequest(widget.groupId, r.id);
      } else {
        await repo.rejectJoinRequest(widget.groupId, r.id);
      }
      ref.invalidate(joinRequestsProvider(widget.groupId));
      ref.invalidate(adminJoinRequestCountProvider(widget.groupId));
      ref.invalidate(groupMembersProvider(widget.groupId));
      // Approving adds a member — refresh the detail's member count.
      ref.invalidate(groupDetailProvider(widget.groupId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ErrorMessages.forApi(e)),
          backgroundColor: AppColors.red,
        ));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DoctorAvatar(
                  initials: r.initials,
                  colorIndex: r.avatarIndex,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.displayName, style: AppText.subheading),
                      if (r.specialty != null)
                        Text(r.specialty!, style: AppText.caption),
                    ],
                  ),
                ),
              ],
            ),
            if (r.message != null && r.message!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(r.message!, style: AppText.body),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: Strings.groupsApprove,
                    loading: _busy,
                    onPressed: () => _act(true),
                    expand: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: Strings.groupsReject,
                    variant: AppButtonVariant.ghost,
                    onPressed: _busy ? null : () => _act(false),
                    expand: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------- //
// Small shared panes
// -------------------------------------------------------------------------- //
class _EmptyLabel extends StatelessWidget {
  final String text;
  const _EmptyLabel(this.text);

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(text, style: AppText.body, textAlign: TextAlign.center),
        ),
      );
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: AppText.caption, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: Strings.retry,
                variant: AppButtonVariant.secondary,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      );
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorScaffold({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
            Expanded(
              child: _InlineError(message: message, onRetry: onRetry),
            ),
          ],
        ),
      );
}
