/// ============================================================================
/// CHAT SCREEN - Real-time Messaging
/// ============================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/services/supabase_service.dart';
import '../../data/models/messaging_models.dart';
import '../providers/messaging_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String userName;
  final String? otherUserId;

  const ChatScreen({
    super.key,
    required this.chatId,
    this.userName = 'Chat',
    this.otherUserId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String? _currentUserId = SupabaseService.client.auth.currentUser?.id;
  bool _isTyping = false;
  Timer? _typingHeartbeatTimer;

  @override
  void initState() {
    super.initState();
    // Load chat
    Future.microtask(() {
      ref.read(chatProvider.notifier).loadChat(widget.chatId);
    });

    // Scroll listener for loading more
    _scrollController.addListener(_onScroll);

    // Text field listener with typing indicator
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});

    // Handle typing indicator with heartbeat
    final hasText = _messageController.text.isNotEmpty;
    if (hasText && !_isTyping) {
      _isTyping = true;
      _startTypingHeartbeat();
    } else if (!hasText && _isTyping) {
      _isTyping = false;
      _stopTypingHeartbeat();
    }
  }

  /// Start sending periodic typing events to keep the indicator alive
  void _startTypingHeartbeat() {
    // Send initial typing start
    ref.read(chatProvider.notifier).startTyping();

    // Cancel any existing timer
    _typingHeartbeatTimer?.cancel();

    // Re-send typing_start every 3 seconds while user has text
    // This keeps the receiver's indicator alive (their timeout is 5 seconds)
    _typingHeartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_isTyping && _messageController.text.isNotEmpty) {
        ref.read(chatProvider.notifier).startTyping();
      } else {
        _stopTypingHeartbeat();
      }
    });
  }

  /// Stop the typing heartbeat and send stop event
  void _stopTypingHeartbeat() {
    _typingHeartbeatTimer?.cancel();
    _typingHeartbeatTimer = null;
    ref.read(chatProvider.notifier).stopTyping();
  }

  @override
  void dispose() {
    _typingHeartbeatTimer?.cancel();
    if (_isTyping) {
      ref.read(chatProvider.notifier).stopTyping();
    }
    _messageController.dispose();
    _scrollController.dispose();
    ref.read(chatProvider.notifier).clear();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatProvider.notifier).loadMoreMessages();
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Stop typing indicator
    if (_isTyping) {
      _isTyping = false;
      _stopTypingHeartbeat();
    }

    _messageController.clear();

    final success = await ref.read(chatProvider.notifier).sendMessage(text);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final conversation = chatState.conversation;
    final disappearingHours = conversation?.disappearingHours;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: GestureDetector(
          onTap: () => context.push(
            '/chat-settings/${widget.chatId}',
            extra: {
              'userName': conversation?.otherUserName ?? widget.userName,
              'otherUserId': conversation?.otherUserId ?? widget.otherUserId,
            },
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.surfaceLight,
                radius: 16,
                child: conversation?.avatarUrl != null
                    ? ClipOval(
                        child: Image.network(
                          conversation!.avatarUrl!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Text(
                            conversation.initials,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        (conversation?.otherUserName ?? widget.userName).isNotEmpty
                            ? (conversation?.otherUserName ?? widget.userName)[0]
                            : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  conversation?.otherUserName ?? widget.userName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 16),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_call_rounded, color: AppColors.textPrimary, size: 28),
            onPressed: () {
              // Video call - future feature
            },
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded, color: AppColors.textPrimary, size: 24),
            onPressed: () {
              // Voice call - future feature
            },
          ),
        ],
      ),
      body: conversation?.isBlocked == true
          ? _buildBlockedState()
          : Column(
              children: [
                // Disappearing messages notice
                if (disappearingHours != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "Chats disappear $disappearingHours hours after viewing",
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ),

                // Messages List
                Expanded(
                  child: _buildMessagesList(chatState),
                ),

                // Typing Indicator
                if (chatState.isOtherUserTyping)
                  _buildTypingIndicator(),

                // Input Area
                _buildInputArea(chatState),
              ],
            ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'typing',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 4),
                _TypingDots(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            const Text(
              'Conversation Blocked',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You cannot send or receive messages in this conversation',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(ChatState state) {
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.errorMessage != null && state.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(chatProvider.notifier).loadChat(widget.chatId),
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

    if (state.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha:0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'No messages yet',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Send a message to start the conversation',
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      reverse: true,
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[index];
        final isMe = message.senderId == _currentUserId;

        // Show date separator if needed
        final showDate = _shouldShowDate(state.messages, index);

        return Column(
          children: [
            if (showDate) _buildDateSeparator(message.createdAt),
            _buildMessageBubble(message, isMe),
          ],
        );
      },
    );
  }

  bool _shouldShowDate(List<MessageModel> messages, int index) {
    if (index == messages.length - 1) return true;

    final current = messages[index];
    final previous = messages[index + 1];

    final currentDate = DateTime(
      current.createdAt.year,
      current.createdAt.month,
      current.createdAt.day,
    );
    final previousDate = DateTime(
      previous.createdAt.year,
      previous.createdAt.month,
      previous.createdAt.day,
    );

    return currentDate != previousDate;
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String text;
    if (messageDate == today) {
      text = 'Today';
    } else if (messageDate == yesterday) {
      text = 'Yesterday';
    } else {
      text = DateFormat('EEEE, MMMM d').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textSecondary.withValues(alpha:0.6),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message, isMe),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.primary : AppColors.surfaceLight,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMe
                        ? const Radius.circular(16)
                        : const Radius.circular(4),
                    bottomRight: isMe
                        ? const Radius.circular(4)
                        : const Radius.circular(16),
                  ),
                  border: isMe
                      ? null
                      : Border.all(color: AppColors.primary.withValues(alpha:0.2)),
                ),
                child: _buildMessageContent(message, isMe),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('h:mm a').format(message.createdAt),
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha:0.6),
                      fontSize: 10,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.status == MessageStatus.read
                          ? Icons.done_all
                          : message.status == MessageStatus.delivered
                              ? Icons.done_all
                              : Icons.done,
                      size: 12,
                      color: message.status == MessageStatus.read
                          ? AppColors.primary
                          : AppColors.textSecondary.withValues(alpha:0.6),
                    ),
                  ],
                  if (message.isSaved) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.bookmark,
                      size: 12,
                      color: AppColors.primary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(MessageModel message, bool isMe) {
    switch (message.messageType) {
      case MessageType.audio:
        return _buildAudioMessage(message, isMe);
      case MessageType.image:
        return _buildImageMessage(message);
      default:
        return Text(
          message.content ?? '',
          style: TextStyle(
            color: isMe ? AppColors.textInverse : AppColors.textPrimary,
            fontSize: 16,
          ),
        );
    }
  }

  Widget _buildAudioMessage(MessageModel message, bool isMe) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.play_circle_fill,
          color: isMe ? AppColors.textInverse : AppColors.primary,
          size: 32,
        ),
        const SizedBox(width: 8),
        Container(
          width: 100,
          height: 24,
          decoration: BoxDecoration(
            color: (isMe ? AppColors.textInverse : AppColors.primary).withValues(alpha:0.2),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          message.audioDurationFormatted,
          style: TextStyle(
            color: isMe ? AppColors.textInverse : AppColors.textPrimary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildImageMessage(MessageModel message) {
    if (message.fileUrl == null) {
      return const Icon(Icons.broken_image, color: AppColors.textSecondary);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        message.fileUrl!,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildInputArea(ChatState state) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
      ),
      child: Row(
        children: [
          // Camera Button
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: AppColors.textPrimary,
              size: 24,
            ),
          ),

          const SizedBox(width: 8),

          // Text Field
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
              ),
              maxLines: 4,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: 'Message',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: false,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),

          const SizedBox(width: 8),

          // Send Button
          GestureDetector(
            onTap: () {
              if (_messageController.text.isNotEmpty) {
                HapticFeedback.lightImpact();
                _sendMessage();
              } else {
                // Voice record - future feature
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _messageController.text.isNotEmpty
                    ? AppColors.primary
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: state.isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.textInverse,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      _messageController.text.isNotEmpty
                          ? Icons.arrow_upward_rounded
                          : Icons.mic_none_rounded,
                      color: _messageController.text.isNotEmpty
                          ? AppColors.textInverse
                          : AppColors.textPrimary,
                      size: 28,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(MessageModel message, bool isMe) {
    HapticFeedback.mediumImpact();

    final conversation = ref.read(chatProvider).conversation;
    final canSaveAudio =
        message.isAudio && !isMe && conversation?.otherAllowsAudioSave == true;

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
            if (message.isText)
              ListTile(
                leading: const Icon(Icons.copy, color: AppColors.textSecondary),
                title: const Text('Copy', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message.content ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied')),
                  );
                },
              ),
            if (canSaveAudio)
              ListTile(
                leading: Icon(
                  message.isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: AppColors.primary,
                ),
                title: Text(
                  message.isSaved ? 'Saved' : 'Save in Chat',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: message.isSaved
                    ? null
                    : const Text(
                        'Save this voice message',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                onTap: () async {
                  Navigator.pop(context);
                  if (!message.isSaved) {
                    final success = await ref
                        .read(chatProvider.notifier)
                        .saveAudioMessage(message.id);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Voice message saved'
                                : 'Could not save voice message',
                          ),
                          backgroundColor:
                              success ? AppColors.success : AppColors.error,
                        ),
                      );
                    }
                  }
                },
              ),
            if (!canSaveAudio && message.isAudio && !isMe)
              ListTile(
                leading: const Icon(Icons.bookmark_border, color: AppColors.textSecondary),
                title: const Text(
                  'Cannot Save',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                subtitle: const Text(
                  'User has disabled saving audio messages',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Animated typing dots indicator
class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    // Create staggered animations for each dot
    _animations = List.generate(3, (index) {
      final start = index * 0.2;
      final end = start + 0.4;
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Padding(
              padding: EdgeInsets.only(left: index > 0 ? 3 : 0),
              child: Transform.translate(
                offset: Offset(0, -3 * _animations[index].value),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
