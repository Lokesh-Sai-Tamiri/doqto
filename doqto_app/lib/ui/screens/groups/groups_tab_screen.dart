import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/strings.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/motion.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/tokens/typography.dart';
import '../../../core/utils/error_messages.dart';
import '../../../data/models/group.dart';
import '../../../state/groups_state.dart';
import '../../widgets/app_pill.dart';
import '../../widgets/app_segmented.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/doctor_avatar.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/member_row.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/search_bar.dart';

/// The Groups tab: [My groups | Discover]. Create is a header action (the
/// center FAB slot is owned by the mic).
class GroupsTabScreen extends ConsumerStatefulWidget {
  const GroupsTabScreen({super.key});

  @override
  ConsumerState<GroupsTabScreen> createState() => _GroupsTabScreenState();
}

class _GroupsTabScreenState extends ConsumerState<GroupsTabScreen> {
  int _segment = 0;
  String _discoverQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        title: const Text(Strings.netTabGroups),
        actions: [
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.groupsCreate),
            icon: const Icon(Icons.add, size: 20),
            label: const Text(Strings.groupsCreate),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.xs,
            ),
            child: AppSegmented(
              tabs: const [Strings.groupsMyGroups, Strings.groupsDiscover],
              index: _segment,
              onChanged: (i) => setState(() => _segment = i),
            ),
          ),
          Expanded(
            child: _segment == 0 ? _buildMyGroups() : _buildDiscover(),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ //
  // My groups
  // ------------------------------------------------------------------ //
  Widget _buildMyGroups() {
    final async = ref.watch(myGroupsProvider);
    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const SkeletonList(),
      error: (e, _) => _ErrorPane(
        message: ErrorMessages.forApi(e),
        onRetry: () => ref.invalidate(myGroupsProvider),
      ),
      data: (data) {
        if (data.isEmpty) {
          return const _EmptyPane(
            icon: Icons.groups_outlined,
            text: Strings.netEmptyGroups,
          );
        }
        // member first, then requested, then invited.
        final rows = <Group>[
          ...data.member,
          ...data.requested,
          ...data.invited,
        ];
        return RefreshIndicator(
          onRefresh: () => ref.read(myGroupsProvider.notifier).refresh(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
            ),
            itemCount: rows.length,
            itemBuilder: (context, i) => FadeSlideIn.staggered(
              i,
              _GroupRow(
                group: rows[i],
                onTap: () => context.push(AppRoutes.group(rows[i].id)),
              ),
              enabled: i <= AppMotion.staggerCap,
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------ //
  // Discover
  // ------------------------------------------------------------------ //
  Widget _buildDiscover() {
    final async = ref.watch(groupDiscoverProvider(_discoverQuery));
    return Column(
      children: [
        AppSearchBar(
          hint: Strings.groupsSearchHint,
          onChanged: (q) => setState(() => _discoverQuery = q),
        ),
        Expanded(
          child: async.when(
            loading: () => const SkeletonList(),
            error: (e, _) => _ErrorPane(
              message: ErrorMessages.forApi(e),
              onRetry: () =>
                  ref.invalidate(groupDiscoverProvider(_discoverQuery)),
            ),
            data: (groups) {
              if (groups.isEmpty) {
                return const _EmptyPane(
                  icon: Icons.search_off_rounded,
                  text: Strings.groupsNoDiscover,
                );
              }
              return ListView.builder(
                padding: EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom:
                      MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
                ),
                itemCount: groups.length,
                itemBuilder: (context, i) => FadeSlideIn.staggered(
                  i,
                  _DiscoverCard(
                    group: groups[i],
                    onTap: () => context.push(AppRoutes.group(groups[i].id)),
                  ),
                  enabled: i <= AppMotion.staggerCap,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A "My groups" list row: avatar, name, member count, membership chips and an
/// amber dot when an admin's join-request queue is non-empty.
class _GroupRow extends ConsumerWidget {
  final Group group;
  final VoidCallback onTap;
  const _GroupRow({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = _memberCountLabel(group.memberCount);
    Widget? trailing;
    if (group.membershipTag == GroupMembershipTag.requested) {
      trailing = const AppPill(label: Strings.groupRequested, tone: PillTone.warn);
    } else if (group.membershipTag == GroupMembershipTag.invited) {
      trailing = const AppPill(label: Strings.groupInvited, tone: PillTone.brand);
    } else if (group.isAdmin) {
      // Admin rows: amber dot when the join-request queue is non-empty.
      final count = ref.watch(adminJoinRequestCountProvider(group.id)).valueOrNull ?? 0;
      if (count > 0) {
        trailing = Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.amber,
            shape: BoxShape.circle,
          ),
        );
      }
    }
    return MemberRow(
      avatar: DoctorAvatar(
        initials: group.initials,
        colorIndex: group.avatarIndex,
        imageUrl: group.avatarUrl,
        heroTag: 'group-avatar-${group.id}',
      ),
      title: group.name,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// A discovery card with a Join / Request / View affordance per join policy.
class _DiscoverCard extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;
  const _DiscoverCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (label, _) = switch (group.joinPolicy) {
      GroupJoinPolicy.open => (Strings.groupJoin, true),
      GroupJoinPolicy.request => (Strings.groupRequestToJoin, true),
      _ => (Strings.groupsView, false),
    };
    return MemberRow(
      avatar: DoctorAvatar(
        initials: group.initials,
        colorIndex: group.avatarIndex,
        imageUrl: group.avatarUrl,
        heroTag: 'group-avatar-${group.id}',
      ),
      title: group.name,
      subtitle: _memberCountLabel(group.memberCount),
      trailing: SizedBox(
        // Tapping the affordance just opens the detail, where the full join
        // state machine (JoinButton) lives.
        child: AppButton(
          label: label,
          variant: group.joinPolicy == GroupJoinPolicy.open
              ? AppButtonVariant.primary
              : AppButtonVariant.secondary,
          onPressed: onTap,
        ),
      ),
      onTap: onTap,
    );
  }
}

String _memberCountLabel(int n) => n == 1 ? '1 member' : '$n members';

class _EmptyPane extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyPane({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.gray400),
            const SizedBox(height: AppSpacing.md),
            Text(text, style: AppText.body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorPane({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(message, style: AppText.caption, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
                label: Strings.retry,
                icon: Icons.refresh_rounded,
                onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
