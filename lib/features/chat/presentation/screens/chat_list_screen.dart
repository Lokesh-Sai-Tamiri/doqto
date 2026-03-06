/// ============================================================================
/// CHAT LIST SCREEN - Conversations List
/// ============================================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../data/models/messaging_models.dart';
import '../providers/messaging_provider.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshConversations() async {
    await ref.read(conversationsProvider.notifier).loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsProvider);

    return GradientScaffold(
      title: 'Messages',
      subtitle: state.totalUnreadCount > 0
          ? '${state.totalUnreadCount} unread message${state.totalUnreadCount > 1 ? 's' : ''}'
          : null,
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.textPrimary),
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Chat List
          Expanded(
            child: _buildContent(state),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ConversationsState state) {
    if (state.isLoading && state.conversations.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.errorMessage != null && state.conversations.isEmpty) {
      return _buildErrorState(state.errorMessage!);
    }

    // Filter conversations by search
    List<ConversationModel> filteredConversations = state.conversations;
    if (_searchQuery.isNotEmpty) {
      filteredConversations = state.conversations.where((conv) {
        return conv.conversationDisplayName.toLowerCase().contains(_searchQuery) ||
            (conv.lastMessageText?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }

    if (filteredConversations.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return _buildEmptySearchState();
      }
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshConversations,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: filteredConversations.length,
        itemBuilder: (context, index) {
          final conv = filteredConversations[index];
          return _buildChatTile(conv);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Messages Yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a conversation with your colleagues\nfrom the Contacts or Organization tab',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No conversations found',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshConversations,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textInverse,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTile(ConversationModel conv) {
    final state = ref.watch(conversationsProvider);
    final isTyping = state.isTypingIn(conv.conversationId);
    final isVoice = conv.lastMessageType == MessageType.audio;
    final isImage = conv.lastMessageType == MessageType.image;
    final isSystem = conv.lastMessageType == MessageType.system;
    final isGroup = conv.isGroup;

    return Dismissible(
      key: Key(conv.conversationId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) => _confirmDelete(conv),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push(
              '/chat/${conv.conversationId}',
              extra: {
                'userName': conv.conversationDisplayName,
                'otherUserId': conv.isGroup ? null : conv.otherUserId,
                'isGroup': conv.isGroup,
              },
            );
          },
          onLongPress: () => _showChatOptions(conv),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: _buildAvatar(conv),
                    ),
                    // Online indicator (only for direct conversations)
                    if (!isGroup)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.background, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                if (conv.isPinned)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(Icons.push_pin, size: 14, color: AppColors.primary),
                                  ),
                                if (conv.isMuted)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(Icons.notifications_off, size: 14, color: AppColors.textSecondary),
                                  ),
                                Expanded(
                                  child: Text(
                                    conv.conversationDisplayName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Show member count for groups, time for all
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isGroup)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.people, size: 12, color: AppColors.textSecondary),
                                      const SizedBox(width: 2),
                                      Text(
                                        conv.memberCount.toString(),
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Text(
                                _formatTime(conv.lastMessageAt),
                                style: TextStyle(
                                  color: conv.unreadCount > 0 ? AppColors.primary : AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: conv.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: isTyping
                                ? const Text(
                                    'typing...',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                : Row(
                                    children: [
                                      if (isVoice)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 6),
                                          child: Icon(Icons.mic, size: 16, color: AppColors.textSecondary),
                                        ),
                                      if (isImage)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 6),
                                          child: Icon(Icons.image, size: 16, color: AppColors.textSecondary),
                                        ),
                                      Expanded(
                                        child: Text(
                                          _getMessagePreview(conv, isSystem),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: conv.unreadCount > 0
                                                ? AppColors.textPrimary
                                                : AppColors.textSecondary,
                                            fontSize: 14,
                                            fontWeight: conv.unreadCount > 0
                                                ? FontWeight.w500
                                                : FontWeight.normal,
                                            fontStyle: isSystem ? FontStyle.italic : FontStyle.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          if (conv.unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                conv.unreadCount > 99 ? '99+' : conv.unreadCount.toString(),
                                style: const TextStyle(
                                  color: AppColors.textInverse,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ConversationModel conv) {
    if (conv.isGroup) {
      // Group avatar
      if (conv.displayAvatarUrl != null) {
        return ClipOval(
          child: Image.network(
            conv.displayAvatarUrl!,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.group,
              color: AppColors.primary,
              size: 28,
            ),
          ),
        );
      }
      return const Icon(
        Icons.group,
        color: AppColors.primary,
        size: 28,
      );
    } else {
      // Direct conversation avatar
      if (conv.avatarUrl != null) {
        return ClipOval(
          child: Image.network(
            conv.avatarUrl!,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Text(
              conv.initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        );
      }
      return Text(
        conv.initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      );
    }
  }

  String _getMessagePreview(ConversationModel conv, bool isSystem) {
    if (conv.lastMessageText == null) {
      return 'Start a conversation';
    }

    // For system messages, resolve user ID placeholders
    if (isSystem) {
      String content = conv.lastMessageText!;
      final regex = RegExp(r'\{user:([^}]+)\}');
      content = content.replaceAllMapped(regex, (match) {
        final userId = match.group(1);
        final member = conv.getMemberProfile(userId ?? '');
        return member?.firstName ?? member?.displayName ?? 'Someone';
      });
      return content;
    }

    // For group conversations, show sender name prefix
    if (conv.isGroup && conv.lastMessageSenderId != null && !isSystem) {
      final sender = conv.getMemberProfile(conv.lastMessageSenderId!);
      final senderName = sender?.firstName ?? sender?.displayName ?? 'Someone';
      return '$senderName: ${conv.lastMessageText}';
    }

    return conv.lastMessageText!;
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m';
    } else if (diff.inDays < 1) {
      return DateFormat('h:mm a').format(dateTime);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat('EEE').format(dateTime);
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  Future<bool> _confirmDelete(ConversationModel conv) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Chat?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Delete your conversation with ${conv.otherUserName}? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );

    if (result == true) {
      final success = await ref
          .read(conversationsProvider.notifier)
          .deleteConversation(conv.conversationId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation deleted')),
        );
      }
      return success;
    }
    return false;
  }

  void _showChatOptions(ConversationModel conv) {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                conv.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                color: AppColors.primary,
              ),
              title: Text(
                conv.isPinned ? 'Unpin Chat' : 'Pin Chat',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                ref.read(conversationsProvider.notifier).updateSettings(
                  conversationId: conv.conversationId,
                  pinned: !conv.isPinned,
                );
              },
            ),
            ListTile(
              leading: Icon(
                conv.isMuted ? Icons.notifications : Icons.notifications_off,
                color: AppColors.textSecondary,
              ),
              title: Text(
                conv.isMuted ? 'Unmute' : 'Mute',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                ref.read(conversationsProvider.notifier).updateSettings(
                  conversationId: conv.conversationId,
                  muted: !conv.isMuted,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined, color: AppColors.textSecondary),
              title: const Text('Archive', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                ref.read(conversationsProvider.notifier).updateSettings(
                  conversationId: conv.conversationId,
                  archived: true,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Delete', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(conv);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
