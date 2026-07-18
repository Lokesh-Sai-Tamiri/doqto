import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/strings.dart';
import '../../../core/di/providers.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
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
import '../../widgets/connectivity_banner.dart';
import '../../widgets/doctor_avatar.dart';
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
  final Set<String> _selectedIds = {};
  bool _deleting = false;

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
    return Scaffold(
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
      body: Column(
        children: [
          const ConnectivityBanner(),
          if (!_isSelecting)
            AppSearchBar(
              hint: 'Search chats or people…',
              onChanged: (q) => setState(() => _query = q),
            ),
          Expanded(
            child: _query.isNotEmpty && !_isSelecting
                ? _SearchResults(
                    query: _query,
                    conversations: convs.asData?.value ?? const [],
                    orgMembers: orgMembers,
                    meId: user?.id,
                  )
                : _ConversationList(
                    convs: convs,
                    orgMembers: orgMembers,
                    meId: user?.id,
                    selectedIds: _selectedIds,
                    isSelecting: _isSelecting,
                    onSelect: _toggleSelect,
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

  const _ConversationList({
    required this.convs,
    required this.orgMembers,
    required this.meId,
    required this.selectedIds,
    required this.isSelecting,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return convs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e', style: AppText.caption)),
      data: (rawList) {
        final list = [...rawList]..sort((a, b) {
            final ta = a.lastMessageAt ?? a.updatedAt;
            final tb = b.lastMessageAt ?? b.updatedAt;
            return tb.compareTo(ta);
          });
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(conversationsProvider),
          child: list.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                    Center(
                      child: Text(
                        'Start a conversation from My Org.',
                        style: AppText.body,
                        textAlign: TextAlign.center,
                      ),
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
                    return _ChatRow(
                      conversation: c,
                      display: display,
                      orgMembers: orgMembers,
                      meId: meId,
                      isSelected: selectedIds.contains(c.id),
                      isSelecting: isSelecting,
                      onSelect: onSelect,
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
    if (m.user.id == widget.meId) return false;
    final q = widget.query.toLowerCase();
    if (m.user.fullName.toLowerCase().contains(q)) return true;
    if (m.user.specialty != null && m.user.specialty!.toLowerCase().contains(q)) return true;
    if (m.user.phone.contains(q)) return true;
    return false;
  }

  Future<void> _startChat(OrgMember m) async {
    if (_startingChat.contains(m.user.id)) return;
    setState(() => _startingChat.add(m.user.id));
    try {
      final conv = await ref.read(chatRepositoryProvider).createConversation(
            type: ConversationType.direct,
            name: null,
            memberIds: [m.user.id],
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
      if (mounted) setState(() => _startingChat.remove(m.user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchingConvs = widget.conversations.where(_matchConversation).toList();
    final matchingMembers = widget.orgMembers.where(_matchMember).toList();

    if (matchingConvs.isEmpty && matchingMembers.isEmpty) {
      return Center(
        child: Text(
          'No results for "${widget.query}"',
          style: AppText.body,
          textAlign: TextAlign.center,
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
            ListTile(
              onTap: () => context.push(AppRoutes.profile, extra: m.user),
              leading: DoctorAvatar(
                initials: m.user.initials,
                colorIndex: widget.orgMembers.indexOf(m),
                imageUrl: m.user.avatarPresignedUrl,
              ),
              title: Text(m.user.fullName, style: AppText.heading, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(m.user.specialty ?? '', style: AppText.caption, maxLines: 1),
              trailing: SizedBox(
                width: 40,
                height: 40,
                child: _startingChat.contains(m.user.id)
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
    return ListTile(
      onTap: () {
        if (isSelecting) {
          onSelect?.call(c.id);
        } else {
          context.push(AppRoutes.chat(c.id));
        }
      },
      onLongPress: () => onSelect?.call(c.id),
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
