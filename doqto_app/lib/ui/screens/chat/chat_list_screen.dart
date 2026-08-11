import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/strings.dart';
import '../../../core/di/providers.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/motion.dart';
import '../../../core/tokens/radii.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/tokens/typography.dart';
import '../../../core/utils/datetime_format.dart';
import '../../../core/utils/error_messages.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/organization.dart';
import '../../../state/auth_state.dart';
import '../../../state/chat_state.dart';
import '../../../state/org_state.dart';
import '../../../data/models/network_profile.dart';
import '../../widgets/app_pressable.dart';
import '../../widgets/app_segmented.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/connectivity_banner.dart';
import '../../widgets/doctor_avatar.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/request_card.dart';
import '../../widgets/search_bar.dart';
import '../../widgets/typing_indicator.dart';
import '_conversation_display.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String _query = '';
  // 0 = Focused (default conversations), 1 = Requests (received pending).
  int _tab = 0;
  final Set<String> _selectedIds = {};
  bool _deleting = false;
  // Rows stagger-animate only on the very first data paint; refreshes and
  // scrolled-in rows render instantly.
  bool _entranceDone = false;

  bool get _isSelecting => _selectedIds.isNotEmpty;

  void _toggleSelect(String convId) {
    setState(() {
      if (_selectedIds.contains(convId)) {
        _selectedIds.remove(convId);
      } else {
        _selectedIds.add(convId);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $count chat${count == 1 ? '' : 's'}?'),
        content: const Text(
          "You won't see these conversations anymore, but the other members still can.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    final meId = ref.read(authProvider).user?.id;
    if (meId == null) return;
    final repo = ref.read(chatRepositoryProvider);
    for (final convId in _selectedIds.toList()) {
      try {
        await repo.removeMember(convId, meId);
      } catch (_) {}
    }
    ref.invalidate(conversationsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Removed $count chat${count == 1 ? '' : 's'}.'),
      backgroundColor: AppColors.medBlue,
    ));
    setState(() {
      _selectedIds.clear();
      _deleting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final convs = ref.watch(conversationsProvider);
    final user = ref.watch(authProvider).user;
    final currentOrg = ref.watch(orgProvider).current;
    final membersAsync = currentOrg == null
        ? const AsyncValue<List<OrgMember>>.data([])
        : ref.watch(orgMembersProvider(currentOrg.id));
    final orgMembers = membersAsync.asData?.value ?? const <OrgMember>[];
    if (!_entranceDone && convs.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_entranceDone) setState(() => _entranceDone = true);
      });
    }
    return Scaffold(
      floatingActionButton: _isSelecting
          ? null
          // Lift above the shell's frosted nav bar (64 + safe inset), which
          // overlays this inner Scaffold's FAB zone (extendBody shell).
          : Padding(
              padding: const EdgeInsets.only(bottom: 72),
              child:
                  _NewChatFab(onTap: () => context.push(AppRoutes.createGroup)),
            ),
      appBar: _isSelecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              ),
              title: Text('${_selectedIds.length} selected'),
              actions: [
                IconButton(
                  icon: _deleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  tooltip: 'Remove',
                  onPressed: _deleting ? null : _deleteSelected,
                ),
              ],
            )
          : AppBar(
              toolbarHeight: 64,
              title: Text(
                Strings.appName,
                style: AppText.display.copyWith(fontSize: 28),
              ),
              actions: [
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
      body: Column(
        children: [
          const ConnectivityBanner(),
          // Focused | Requests segmented header — hidden during multi-select.
          if (!_isSelecting)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.sm,
                AppSpacing.screenHorizontal,
                AppSpacing.xs,
              ),
              child: AppSegmented(
                tabs: const [
                  Strings.netFilterFocused,
                  Strings.netFilterRequests,
                ],
                index: _tab,
                badges: [null, ref.watch(requestsCountProvider)],
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
          if (_tab == 0 && !_isSelecting)
            AppSearchBar(
              hint: 'Search chats or people…',
              onChanged: (q) => setState(() => _query = q),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppMotion.maybe(context, AppMotion.enter),
              switchInCurve: AppMotion.curveEnter,
              switchOutCurve: AppMotion.curveExit,
              child: _tab == 1 && !_isSelecting
                  ? const _RequestsTab(key: ValueKey('requests'))
                  : _query.isNotEmpty && !_isSelecting
                      ? _SearchResults(
                          key: const ValueKey('search'),
                          query: _query,
                          conversations: convs.asData?.value ?? const [],
                          orgMembers: orgMembers,
                          meId: user?.id,
                        )
                      : _ConversationList(
                          key: const ValueKey('list'),
                          convs: convs,
                          orgMembers: orgMembers,
                          meId: user?.id,
                          selectedIds: _selectedIds,
                          isSelecting: _isSelecting,
                          onSelect: _toggleSelect,
                          staggerEntrance: !_entranceDone,
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationList extends ConsumerWidget {
  final AsyncValue<List<Conversation>> convs;
  final List<OrgMember> orgMembers;
  final String? meId;
  final Set<String> selectedIds;
  final bool isSelecting;
  final ValueChanged<String> onSelect;
  final bool staggerEntrance;

  const _ConversationList({
    super.key,
    required this.convs,
    required this.orgMembers,
    required this.meId,
    required this.selectedIds,
    required this.isSelecting,
    required this.onSelect,
    required this.staggerEntrance,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return convs.when(
      // Cached data paints instantly (AsyncData); the skeleton only ever
      // shows on a true cold start with nothing cached.
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const SkeletonList(),
      error: (e, _) => _StatusPane(
        icon: Icons.cloud_off_rounded,
        title: 'Couldn’t load your chats',
        subtitle: ErrorMessages.forApi(e),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(conversationsProvider),
      ),
      data: (rawList) {
        final list = [...rawList]..sort((a, b) {
            final ta = a.lastMessageAt ?? a.updatedAt;
            final tb = b.lastMessageAt ?? b.updatedAt;
            return tb.compareTo(ta);
          });
        return RefreshIndicator(
          onRefresh: () => ref.read(conversationsProvider.notifier).refresh(),
          child: list.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.22),
                    _StatusPane(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No conversations yet',
                      subtitle:
                          'Message a colleague or start a group to get going.',
                      actionLabel: 'Start a conversation',
                      onAction: () => context.push(AppRoutes.createGroup),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  // extendBody: keep last row clear of the floating nav bar.
                  padding: EdgeInsets.only(
                    top: AppSpacing.sm,
                    bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.sm,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (ctx, i) => const Divider(indent: AppSpacing.xxl + AppSpacing.lg, height: 0),
                  itemBuilder: (ctx, i) {
                    final c = list[i];
                    final display = conversationDisplay(
                      c: c,
                      orgMembers: orgMembers,
                      meId: meId,
                      fallbackColorIndex: i,
                    );
                    return FadeSlideIn.staggered(
                      i,
                      _ChatRow(
                        conversation: c,
                        display: display,
                        orgMembers: orgMembers,
                        meId: meId,
                        isSelected: selectedIds.contains(c.id),
                        isSelecting: isSelecting,
                        onSelect: onSelect,
                      ),
                      enabled: staggerEntrance && i <= AppMotion.staggerCap,
                    );
                  },
                ),
        );
      },
    );
  }
}

class _SearchResults extends ConsumerStatefulWidget {
  final String query;
  final List<Conversation> conversations;
  final List<OrgMember> orgMembers;
  final String? meId;

  const _SearchResults({
    super.key,
    required this.query,
    required this.conversations,
    required this.orgMembers,
    required this.meId,
  });

  @override
  ConsumerState<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends ConsumerState<_SearchResults> {
  final Set<String> _startingChat = {};

  bool _matchConversation(Conversation c) {
    final q = widget.query.toLowerCase();
    final display = conversationDisplay(
      c: c,
      orgMembers: widget.orgMembers,
      meId: widget.meId,
      fallbackColorIndex: 0,
    );
    if (display.title.toLowerCase().contains(q)) return true;
    if (c.lastMessagePreview != null && c.lastMessagePreview!.toLowerCase().contains(q)) return true;
    return false;
  }

  bool _matchMember(OrgMember m) {
    if (m.id == widget.meId) return false;
    final q = widget.query.toLowerCase();
    if (m.fullName.toLowerCase().contains(q)) return true;
    if (m.specialty != null && m.specialty!.toLowerCase().contains(q)) return true;
    return false;
  }

  Future<void> _startChat(OrgMember m) async {
    if (_startingChat.contains(m.id)) return;
    setState(() => _startingChat.add(m.id));
    try {
      final conv = await ref.read(chatRepositoryProvider).createConversation(
            type: ConversationType.direct,
            name: null,
            memberIds: [m.id],
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
      if (mounted) setState(() => _startingChat.remove(m.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchingConvs = widget.conversations.where(_matchConversation).toList();
    final matchingMembers = widget.orgMembers.where(_matchMember).toList();

    if (matchingConvs.isEmpty && matchingMembers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 40, color: AppColors.gray400),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No results for "${widget.query}"',
              style: AppText.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Try a different name or specialty.',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.sm,
      ),
      children: [
        if (matchingConvs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.xs,
            ),
            child: Text('CONVERSATIONS', style: AppText.label),
          ),
          for (var i = 0; i < matchingConvs.length; i++)
            _ChatRow(
              conversation: matchingConvs[i],
              display: conversationDisplay(
                c: matchingConvs[i],
                orgMembers: widget.orgMembers,
                meId: widget.meId,
                fallbackColorIndex: i,
              ),
              orgMembers: widget.orgMembers,
              meId: widget.meId,
            ),
        ],
        if (matchingMembers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
              AppSpacing.screenHorizontal,
              AppSpacing.xs,
            ),
            child: Text('PEOPLE', style: AppText.label),
          ),
          for (final m in matchingMembers)
            AppPressable(
              onTap: () => context.push(AppRoutes.person(m.id)),
              child: ListTile(
                leading: DoctorAvatar(
                  initials: m.initials,
                  colorIndex: widget.orgMembers.indexOf(m),
                  imageUrl: m.avatarPresignedUrl,
                ),
                title: Text(m.fullName, style: AppText.heading, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(m.specialty ?? '', style: AppText.caption, maxLines: 1),
                trailing: SizedBox(
                  width: 40,
                  height: 40,
                  child: _startingChat.contains(m.id)
                      ? const Padding(
                          padding: EdgeInsets.all(AppSpacing.sm),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          tooltip: 'Message',
                          icon: const Icon(Icons.chat_bubble_outline),
                          color: AppColors.medBlue,
                          onPressed: () => _startChat(m),
                        ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ChatRow extends ConsumerWidget {
  final Conversation conversation;
  final ConversationDisplay display;
  final List<OrgMember> orgMembers;
  final String? meId;
  final bool isSelected;
  final bool isSelecting;
  final ValueChanged<String>? onSelect;

  const _ChatRow({
    required this.conversation,
    required this.display,
    required this.orgMembers,
    required this.meId,
    this.isSelected = false,
    this.isSelecting = false,
    this.onSelect,
  });

  String? _resolveSenderFirstName(String senderId) {
    for (final m in orgMembers) {
      if (m.id == senderId) {
        final first = m.fullName.trim().split(RegExp(r'\s+')).first;
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
      case MessageType.unknown:
        // Tolerant fallback (A5): render like text, never crash.
        body = c.lastMessagePreview ?? '';
        break;
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
  Widget build(BuildContext context, WidgetRef ref) {
    final c = conversation;
    final hasMsg = c.lastMessageType != null;
    final isUnread = c.unreadCount > 0;
    final isTyping = ref.watch(typingProvider(c.id));
    final titleStyle = isUnread
        ? AppText.heading.copyWith(fontWeight: FontWeight.w700)
        : AppText.heading;
    final previewStyle = isUnread
        ? AppText.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)
        : hasMsg
            ? AppText.caption.copyWith(color: AppColors.textSecondary)
            : AppText.caption.copyWith(fontStyle: FontStyle.italic);
    final subtitle = isTyping
        ? Row(
            children: [
              Text('typing', style: AppText.caption.copyWith(
                color: AppColors.medBlue, fontWeight: FontWeight.w600)),
              const SizedBox(width: 5),
              const TypingDots(color: AppColors.medBlue, size: 6),
            ],
          )
        : Text(_previewText(), style: previewStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
    return AppPressable(
      onTap: () {
        if (isSelecting) {
          onSelect?.call(c.id);
        } else {
          context.push(AppRoutes.chat(c.id));
        }
      },
      onLongPress: () => onSelect?.call(c.id),
      child: ListTile(
        tileColor: isSelected ? AppColors.medBlueLight : null,
        leading: DoctorAvatar(
          initials: display.initials,
          colorIndex: display.colorIndex,
          imageUrl: display.otherUser?.avatarPresignedUrl,
          isSelected: isSelected,
        ),
        title: Text(display.title, style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle,
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
              // Badge pill scales in when a row first becomes unread.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: AppMotion.maybe(context, AppMotion.micro),
                curve: AppMotion.standard,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom-anchored new-chat action: thumb-zone reachable, scales in on
/// first build, press feedback via AppPressable.
class _NewChatFab extends StatelessWidget {
  final VoidCallback onTap;
  const _NewChatFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: AppMotion.maybe(context, AppMotion.enter),
      curve: AppMotion.curveEnter,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: AppPressable(
        onTap: onTap,
        haptic: true,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.medBlue,
            boxShadow: [
              BoxShadow(
                color: AppColors.medBlueDark.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(Icons.edit_rounded,
              color: AppColors.white, size: 24),
        ),
      ),
    );
  }
}

/// Requests tab: received pending message requests as [RequestCard]s. Visible
/// (non-hidden) requests list first; hidden ones fold under an expandable
/// "Hidden requests" footer (no badge). Optimistic accept/delete/block via
/// [requestsProvider]; tapping a card opens the thread.
class _RequestsTab extends ConsumerStatefulWidget {
  const _RequestsTab({super.key});

  @override
  ConsumerState<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends ConsumerState<_RequestsTab> {
  bool _showHidden = false;

  Future<void> _accept(Conversation c) async {
    try {
      await ref.read(requestsProvider.notifier).accept(c.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Strings.netRequestAcceptedToast)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ErrorMessages.forApi(e)),
        backgroundColor: AppColors.red,
      ));
    }
  }

  Future<void> _delete(Conversation c) async {
    // Silent decline — no toast, per plan.
    try {
      await ref.read(requestsProvider.notifier).decline(c.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ErrorMessages.forApi(e)),
        backgroundColor: AppColors.red,
      ));
    }
  }

  Future<void> _block(Conversation c) async {
    final otherId = c.initiatorId;
    ref.read(requestsProvider.notifier).removeLocally(c.id);
    try {
      if (otherId != null) {
        await ref.read(networkRepositoryProvider).block(otherId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Strings.netBlockedToast)),
      );
    } catch (e) {
      await ref.read(requestsProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ErrorMessages.forApi(e)),
        backgroundColor: AppColors.red,
      ));
    }
  }

  RequestCard _card(Conversation c) {
    final name = (c.displayName?.trim().isNotEmpty ?? false)
        ? c.displayName!.trim()
        : 'Doctor';
    return RequestCard(
      key: ValueKey(c.id),
      name: name,
      initials: initialsOf(name),
      avatarColorIndex: avatarIndexFrom(null, c.initiatorId ?? c.id),
      messagePreview: c.lastMessagePreview,
      heroTag: c.initiatorId != null ? 'member-avatar-${c.initiatorId}' : null,
      onAccept: () => _accept(c),
      onDelete: () => _delete(c),
      onBlock: () => _block(c),
      onTap: () => context.push(AppRoutes.chat(c.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(requestsProvider);
    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const SkeletonList(),
      error: (e, _) => _StatusPane(
        icon: Icons.cloud_off_rounded,
        title: 'Couldn’t load requests',
        subtitle: ErrorMessages.forApi(e),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(requestsProvider),
      ),
      data: (all) {
        final visible = all.where((c) => !c.isHidden).toList();
        final hidden = all.where((c) => c.isHidden).toList();
        if (visible.isEmpty && hidden.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.18),
              const _StatusPane(
                icon: Icons.mark_email_unread_outlined,
                title: Strings.netEmptyRequests,
                subtitle: Strings.netExplainRequestTier,
              ),
            ],
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(requestsProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: AppSpacing.sm,
              left: AppSpacing.screenHorizontal,
              right: AppSpacing.screenHorizontal,
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.sm,
            ),
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                FadeSlideIn.staggered(
                  i,
                  _card(visible[i]),
                  enabled: i <= AppMotion.staggerCap,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (hidden.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                AppPressable(
                  onTap: () => setState(() => _showHidden = !_showHidden),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${Strings.netHiddenRequests} (${hidden.length})',
                          style: AppText.button.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Icon(
                          _showHidden
                              ? Icons.expand_less_rounded
                              : Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showHidden)
                  for (final c in hidden) ...[
                    _card(c),
                    const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Shared empty/error pane: icon + one line + one action. No blank screens.
class _StatusPane extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusPane({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.gray400),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppText.heading, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, style: AppText.caption, textAlign: TextAlign.center),
            if (actionLabel != null && actionLabel!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
