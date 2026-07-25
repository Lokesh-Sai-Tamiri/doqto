import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/tokens/typography.dart';
import '../../../core/utils/error_messages.dart';
import '../../../data/models/network_profile.dart';
import '../../../state/network_state.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/invitation_card.dart';
import '../../widgets/person_card_row.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_card.dart';

/// Network tab: an invitations preview (top ≤2 received pending), a connections
/// preview with a count + "Manage all", and a search entry. No PYMK/Discover
/// rails (deferred M7). Pull-to-refresh refetches both lists.
class NetworkTabScreen extends ConsumerWidget {
  const NetworkTabScreen({super.key});

  static const _invitePreviewCount = 2;
  static const _connectionPreviewCount = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(invitationsProvider);
    final connectionsAsync = ref.watch(connectionsProvider);

    final invites = invitesAsync.valueOrNull ?? const <Invitation>[];
    final connections = connectionsAsync.valueOrNull ?? const <PersonCard>[];
    final loading = invitesAsync.isLoading && connectionsAsync.isLoading;
    final isEmpty = !loading && invites.isEmpty && connections.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        title: const Text(Strings.netMyNetwork),
        actions: [
          IconButton(
            tooltip: Strings.netDiscoverPeople,
            icon: const Icon(Icons.search),
            onPressed: () => context.push(AppRoutes.peopleSearch),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(invitationsProvider.notifier).refresh(),
            ref.read(connectionsProvider.notifier).refresh(),
          ]);
        },
        child: loading
            ? const SkeletonList()
            : isEmpty
                ? _EmptyNetwork(
                    onDiscover: () => context.push(AppRoutes.peopleSearch),
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: AppSpacing.md,
                      bottom: MediaQuery.paddingOf(context).bottom +
                          AppSpacing.xl,
                    ),
                    children: [
                      if (invites.isNotEmpty)
                        _InvitationsPreview(
                          invitations: invites,
                          previewCount: _invitePreviewCount,
                        ),
                      _ConnectionsPreview(
                        connections: connections,
                        previewCount: _connectionPreviewCount,
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _InvitationsPreview extends ConsumerWidget {
  final List<Invitation> invitations;
  final int previewCount;
  const _InvitationsPreview({
    required this.invitations,
    required this.previewCount,
  });

  Future<void> _accept(BuildContext context, WidgetRef ref, Invitation inv) =>
      _run(context, ref, () => ref.read(invitationsProvider.notifier).accept(inv),
          Strings.netNowConnectedToast);

  Future<void> _ignore(BuildContext context, WidgetRef ref, Invitation inv) =>
      _run(context, ref, () => ref.read(invitationsProvider.notifier).ignore(inv),
          null);

  Future<void> _run(BuildContext context, WidgetRef ref,
      Future<void> Function() action, String? toast) async {
    try {
      await action();
      if (toast != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(toast)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ErrorMessages.forApi(e)),
          backgroundColor: AppColors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = invitations.take(previewCount).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        0,
        AppSpacing.screenHorizontal,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.xs, bottom: AppSpacing.sm),
            child: Text(Strings.netInvitations.toUpperCase(),
                style: AppText.label),
          ),
          for (final (i, inv) in shown.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            FadeSlideIn.staggered(
              i,
              InvitationCard(
                invitation: inv,
                onAccept: () => _accept(context, ref, inv),
                onIgnore: () => _ignore(context, ref, inv),
                onTap: inv.sender != null
                    ? () => context.push(AppRoutes.person(inv.sender!.id))
                    : null,
              ),
            ),
          ],
          if (invitations.length > shown.length) ...[
            const SizedBox(height: AppSpacing.sm),
            _SeeAllButton(
              label: Strings.netSeeAllInvitations(invitations.length),
              onTap: () => context.push(AppRoutes.networkInvitations),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectionsPreview extends StatelessWidget {
  final List<PersonCard> connections;
  final int previewCount;
  const _ConnectionsPreview({
    required this.connections,
    required this.previewCount,
  });

  @override
  Widget build(BuildContext context) {
    final shown = connections.take(previewCount).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.xs, bottom: AppSpacing.sm),
            child: Row(
              children: [
                Text(Strings.netYourConnections.toUpperCase(),
                    style: AppText.label),
                const SizedBox(width: AppSpacing.sm),
                if (connections.isNotEmpty)
                  Text('${connections.length}',
                      style: AppText.label.copyWith(color: AppColors.medBlue)),
              ],
            ),
          ),
          if (connections.isEmpty)
            SectionCard(
              child: Text(Strings.netEmptyConnections, style: AppText.caption),
            )
          else ...[
            for (final (i, p) in shown.indexed)
              FadeSlideIn.staggered(
                i,
                PersonCardRow(
                  person: p,
                  onTap: () => context.push(AppRoutes.person(p.id)),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            _SeeAllButton(
              label: Strings.netManageAll,
              onTap: () => context.push(AppRoutes.networkConnections),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SeeAllButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppText.button.copyWith(color: AppColors.medBlue)),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.medBlue),
          ],
        ),
      ),
    );
  }
}

class _EmptyNetwork extends StatelessWidget {
  final VoidCallback onDiscover;
  const _EmptyNetwork({required this.onDiscover});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline,
                    size: 48, color: AppColors.gray400),
                const SizedBox(height: AppSpacing.lg),
                Text(Strings.netEmptyNetwork,
                    style: AppText.body, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: Strings.netDiscoverPeople,
                  icon: Icons.search,
                  onPressed: onDiscover,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
