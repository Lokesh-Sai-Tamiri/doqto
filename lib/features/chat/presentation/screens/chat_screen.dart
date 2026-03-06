/// ============================================================================
/// CHAT SCREEN - Real-time Messaging
/// ============================================================================
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/theme/colors.dart';
import '../../../../core/services/supabase_service.dart';
import '../../data/models/messaging_models.dart';
import '../providers/messaging_provider.dart';
import '../widgets/mention_picker.dart';
import '../../../voice/presentation/providers/voice_recording_provider.dart';
import '../../../voice/presentation/widgets/audio_waveform.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String userName;
  final String? otherUserId;
  final bool isGroup;

  const ChatScreen({
    super.key,
    required this.chatId,
    this.userName = 'Chat',
    this.otherUserId,
    this.isGroup = false,
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
  bool _showMentionPicker = false;
  final Map<String, String> _mentionMap = {}; // Maps display name to userId

  // Voice recording state
  bool _isVoiceRecording = false;

  // Audio playback state
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingMessageId;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;

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

    // Set up audio player listeners
    _setupAudioListeners();
  }

  void _setupAudioListeners() {
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _audioPosition = position);
    });

    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _audioDuration = duration);
    });

    _stateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _playerState = state);
        // Reset when playback completes
        if (state == PlayerState.completed) {
          _playingMessageId = null;
          _audioPosition = Duration.zero;
        }
      }
    });
  }

  void _onTextChanged() {
    final text = _messageController.text;
    final selection = _messageController.selection;

    setState(() {});

    // Auto-trigger mention picker when user types "@" in a group
    final isGroup = ref.read(chatProvider).conversation?.isGroup ?? false;
    if (isGroup) {
      if (selection.baseOffset > 0) {
        final cursorPos = selection.baseOffset;
        // Check if user just typed "@"
        if (cursorPos > 0 && text[cursorPos - 1] == '@') {
          // Check if "@" is at the start or preceded by a space
          if (cursorPos == 1 || text[cursorPos - 2] == ' ') {
            if (!_showMentionPicker) {
              setState(() => _showMentionPicker = true);
            }
          }
        }
      }

      // Close mention picker if there's no "@" in the text before cursor
      if (_showMentionPicker) {
        final cursorPos = selection.baseOffset;
        final textBeforeCursor = text.substring(0, cursorPos);
        // Find the last "@" before cursor
        final lastAtIndex = textBeforeCursor.lastIndexOf('@');
        // If no "@" found, or if there's a space after the last "@", close picker
        if (lastAtIndex == -1 ||
            (lastAtIndex < textBeforeCursor.length - 1 &&
             textBeforeCursor.substring(lastAtIndex).contains(' '))) {
          setState(() => _showMentionPicker = false);
        }
      }
    }

    // Handle typing indicator with heartbeat
    final hasText = text.isNotEmpty;
    if (hasText && !_isTyping) {
      _isTyping = true;
      _startTypingHeartbeat();
    } else if (!hasText && _isTyping) {
      _isTyping = false;
      _stopTypingHeartbeat();
    }
  }

  void _insertMention(ParticipantInfo member) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final cursorPos = selection.baseOffset >= 0 ? selection.baseOffset : text.length;

    // Find the position of the "@" symbol that triggered the mention picker
    int atPos = cursorPos - 1;
    while (atPos >= 0 && text[atPos] != '@') {
      atPos--;
    }

    // If we found an "@", replace it and any text after it up to cursor with the mention
    String beforeMention = atPos >= 0 ? text.substring(0, atPos) : text.substring(0, cursorPos);
    String afterMention = text.substring(cursorPos);

    // Use a format that we can parse: @[Name](userId)
    // This way users see the name, but we can extract the userId when sending
    final displayName = member.firstName ?? member.displayName ?? 'Unknown';
    final mention = '@$displayName ';
    final newText = beforeMention + mention + afterMention;

    _messageController.text = newText;
    _messageController.selection = TextSelection.collapsed(
      offset: beforeMention.length + mention.length,
    );

    // Store the mention mapping for later extraction
    _mentionMap[displayName] = member.userId;
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

  Future<void> _startVoiceRecording() async {
    debugPrint('[Chat] Starting voice recording...');
    final success = await ref.read(voiceRecordingProvider.notifier).startRecording();
    debugPrint('[Chat] startRecording returned: $success');
    if (!mounted) return;
    if (success) {
      setState(() => _isVoiceRecording = true);
    } else {
      final voiceState = ref.read(voiceRecordingProvider);
      debugPrint('[Chat] permission denied=${voiceState.isPermissionPermanentlyDenied}, hasPermission=${voiceState.hasPermission}');
      if (voiceState.isPermissionPermanentlyDenied) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Microphone Access Required',
                style: TextStyle(color: AppColors.textPrimary)),
            content: const Text(
                'Enable microphone access in Settings to record voice messages.',
                style: TextStyle(color: AppColors.textSecondary)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(voiceRecordingProvider.notifier).openSettings();
                  },
                  child: const Text('Open Settings')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Microphone permission is required'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _stopAndSendVoiceRecording() async {
    final voiceState = ref.read(voiceRecordingProvider);
    final durationSeconds = voiceState.recordingDuration.inSeconds;

    final path = await ref.read(voiceRecordingProvider.notifier).stopRecording();
    if (!mounted) return;
    setState(() => _isVoiceRecording = false);

    if (path == null) return;

    final String fileName;
    final int fileSize;
    final String contentType;

    if (kIsWeb) {
      fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.webm';
      fileSize = 0;
      contentType = 'audio/webm';
    } else {
      final file = File(path);
      fileName = path.split('/').last;
      fileSize = await file.length();
      contentType = 'audio/m4a';
    }

    try {
      final repo = ref.read(messagingRepositoryProvider);

      // Step 1: upload to S3
      final uploadInfo = await repo.getUploadUrl(
        filename: fileName,
        contentType: contentType,
      );
      final downloadUrl = await repo.uploadFileToS3(
        localFilePath: path,
        uploadUrl: uploadInfo.uploadUrl,
        downloadUrl: uploadInfo.downloadUrl,
        contentType: contentType,
      );

      // Step 2: send message — updates chat state immediately
      if (mounted) {
        await ref.read(chatProvider.notifier).sendAudioMessage(
          fileUrl: downloadUrl,
          durationSeconds: durationSeconds,
          fileName: fileName,
          fileSize: fileSize,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send voice message: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _cancelVoiceRecording() async {
    await ref.read(voiceRecordingProvider.notifier).cancelRecording();
    if (mounted) setState(() => _isVoiceRecording = false);
  }

  @override
  void deactivate() {
    // Capture notifier before deactivation; delay state mutations out of the
    // build frame to avoid "modified provider during build" assertion.
    final notifier = ref.read(chatProvider.notifier);
    final wasTyping = _isTyping;
    Future.microtask(() {
      if (wasTyping) notifier.stopTyping();
      notifier.clear();
    });
    super.deactivate();
  }

  @override
  void dispose() {
    _typingHeartbeatTimer?.cancel();
    // Clean up audio player
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _stateSubscription?.cancel();
    _audioPlayer.dispose();

    _messageController.dispose();
    _scrollController.dispose();
    _mentionMap.clear();
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

    // Extract mentions - try both display name format and userId format
    final List<String> mentions = [];
    String messageText = text;

    // First, check for display name mentions and convert to userId format
    final namePattern = RegExp(r'@(\w+(?:\s+\w+)*)');
    final nameMatches = namePattern.allMatches(text);

    for (final match in nameMatches) {
      final displayName = match.group(1)!;
      if (_mentionMap.containsKey(displayName)) {
        final userId = _mentionMap[displayName]!;
        mentions.add(userId);
        // Replace @Name with @userId in the message text for backend
        messageText = messageText.replaceFirst('@$displayName', '@$userId');
      }
    }

    // Also check for direct userId mentions (fallback)
    final uuidPattern = RegExp(r'@([a-f0-9-]{36})');
    final uuidMatches = uuidPattern.allMatches(messageText);
    for (final match in uuidMatches) {
      final userId = match.group(1)!;
      if (!mentions.contains(userId)) {
        mentions.add(userId);
      }
    }

    _messageController.clear();
    _mentionMap.clear(); // Clear the mention map after sending

    final success = await ref.read(chatProvider.notifier).sendMessage(
          messageText,
          mentions: mentions.isNotEmpty ? mentions : null,
        );

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
    final isGroup = conversation?.isGroup ?? widget.isGroup;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: GestureDetector(
          onTap: () {
            if (isGroup) {
              context.push(
                '/group-info/${widget.chatId}',
                extra: {
                  'groupName': conversation?.conversationDisplayName ?? widget.userName,
                },
              );
            } else {
              context.push(
                '/chat-settings/${widget.chatId}',
                extra: {
                  'userName': conversation?.otherUserName ?? widget.userName,
                  'otherUserId': conversation?.otherUserId ?? widget.otherUserId,
                },
              );
            }
          },
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.surfaceLight,
                radius: 16,
                child: _buildAppBarAvatar(conversation, isGroup),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation?.conversationDisplayName ?? widget.userName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    if (isGroup && conversation != null)
                      Text(
                        '${conversation.memberCount} members',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 16),
            ],
          ),
        ),
        actions: [
          if (!isGroup) ...[
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

                // Mention Picker for groups
                if (_showMentionPicker && isGroup && conversation != null)
                  MentionPicker(
                    members: conversation.memberProfiles,
                    currentUserId: _currentUserId,
                    onMemberSelected: (member) {
                      _insertMention(member);
                      setState(() => _showMentionPicker = false);
                    },
                    onClose: () => setState(() => _showMentionPicker = false),
                  ),

                // Input Area
                _buildInputArea(chatState, isGroup: isGroup),
              ],
            ),
    );
  }

  Widget _buildAppBarAvatar(ConversationModel? conversation, bool isGroup) {
    if (isGroup) {
      if (conversation?.displayAvatarUrl != null) {
        return ClipOval(
          child: Image.network(
            conversation!.displayAvatarUrl!,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.group,
              color: AppColors.primary,
              size: 18,
            ),
          ),
        );
      }
      return const Icon(
        Icons.group,
        color: AppColors.primary,
        size: 18,
      );
    } else {
      if (conversation?.avatarUrl != null) {
        return ClipOval(
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
        );
      }
      return Text(
        (conversation?.otherUserName ?? widget.userName).isNotEmpty
            ? (conversation?.otherUserName ?? widget.userName)[0]
            : '?',
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
    }
  }

  Widget _buildTypingIndicator() {
    final chatState = ref.watch(chatProvider);
    final conversation = chatState.conversation;
    final typingUserId = chatState.typingUserId;

    // Get typing user's name (for groups)
    String typingText = 'typing';
    if (conversation?.isGroup == true && typingUserId != null) {
      final typingUser = conversation?.getMemberProfile(typingUserId);
      final typingName = typingUser?.firstName ?? typingUser?.displayName ?? 'Someone';
      typingText = '$typingName is typing';
    }

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
                  typingText,
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

    final isGroup = state.conversation?.isGroup ?? false;

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

        // Show sender name in groups for other users' messages
        final showSenderName = isGroup && !isMe && !message.isSystem;

        return Column(
          children: [
            if (showDate) _buildDateSeparator(message.createdAt),
            if (message.isSystem)
              _buildSystemMessage(message, state.conversation)
            else
              _buildMessageBubble(message, isMe, showSenderName: showSenderName, conversation: state.conversation),
          ],
        );
      },
    );
  }

  Widget _buildSystemMessage(MessageModel message, ConversationModel? conversation) {
    // Format system message content by replacing user placeholders
    String content = message.content ?? '';

    // Replace {user:id} placeholders with actual names
    final regex = RegExp(r'\{user:([^}]+)\}');
    content = content.replaceAllMapped(regex, (match) {
      final userId = match.group(1);
      if (userId == _currentUserId) {
        return 'You';
      }
      final member = conversation?.getMemberProfile(userId ?? '');
      return member?.firstName ?? member?.displayName ?? 'Someone';
    });

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            content,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
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

  Widget _buildMessageBubble(MessageModel message, bool isMe, {bool showSenderName = false, ConversationModel? conversation}) {
    // Get sender name for groups
    String? senderName;
    if (showSenderName) {
      final sender = conversation?.getMemberProfile(message.senderId);
      senderName = sender?.firstName ?? sender?.displayName;
    }

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
              // Sender name for group messages
              if (showSenderName && senderName != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    senderName,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
                child: _buildMessageContent(message, isMe, conversation: conversation),
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

  Widget _buildMessageContent(MessageModel message, bool isMe, {ConversationModel? conversation}) {
    switch (message.messageType) {
      case MessageType.audio:
        return _buildAudioMessage(message, isMe);
      case MessageType.image:
        return _buildImageMessage(message);
      default:
        // Check if message has mentions to render
        if (message.hasMentions && conversation != null) {
          return _buildMentionText(message, isMe, conversation);
        }
        return Text(
          message.content ?? '',
          style: TextStyle(
            color: isMe ? AppColors.textInverse : AppColors.textPrimary,
            fontSize: 16,
          ),
        );
    }
  }

  Widget _buildMentionText(MessageModel message, bool isMe, ConversationModel conversation) {
    final text = message.content ?? '';
    final baseStyle = TextStyle(
      color: isMe ? AppColors.textInverse : AppColors.textPrimary,
      fontSize: 16,
    );

    // Build a map of userId -> member info for quick lookup
    final memberMap = <String, ParticipantInfo>{};
    for (final member in conversation.memberProfiles) {
      memberMap[member.userId] = member;
    }

    // Parse the text to find @mentions and highlight them
    final spans = <InlineSpan>[];
    String remaining = text;

    // Pattern to match @userId format
    final mentionPattern = RegExp(r'@([a-f0-9-]{36})');

    while (remaining.isNotEmpty) {
      final match = mentionPattern.firstMatch(remaining);
      if (match == null) {
        spans.add(TextSpan(text: remaining, style: baseStyle));
        break;
      }

      // Add text before the mention
      if (match.start > 0) {
        spans.add(TextSpan(
          text: remaining.substring(0, match.start),
          style: baseStyle,
        ));
      }

      // Add the mention with highlight
      final userId = match.group(1)!;
      final member = memberMap[userId];
      final isCurrentUser = userId == _currentUserId;

      spans.add(TextSpan(
        text: '@${member?.name ?? 'Unknown'}',
        style: baseStyle.copyWith(
          color: isCurrentUser
              ? (isMe ? AppColors.warning : AppColors.warning)
              : (isMe ? AppColors.textInverse : AppColors.primary),
          fontWeight: FontWeight.w600,
          backgroundColor: isCurrentUser
              ? AppColors.warning.withValues(alpha: 0.2)
              : null,
        ),
      ));

      remaining = remaining.substring(match.end);
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Future<void> _playPauseAudio(MessageModel message) async {
    final audioUrl = message.fileUrl;
    if (audioUrl == null) return;

    try {
      // If this message is already playing, pause it
      if (_playingMessageId == message.id) {
        if (_playerState == PlayerState.playing) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.resume();
        }
        return;
      }

      // Stop any currently playing audio
      await _audioPlayer.stop();
      _audioPosition = Duration.zero;

      // Set the new message as playing
      setState(() => _playingMessageId = message.id);

      // Play the audio - check if it's a local file or URL
      if (audioUrl.startsWith('/') || audioUrl.startsWith('file://')) {
        // Local file
        final file = File(audioUrl.replaceFirst('file://', ''));
        if (await file.exists()) {
          await _audioPlayer.play(DeviceFileSource(file.path));
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Audio file not found'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          setState(() => _playingMessageId = null);
        }
      } else {
        // Remote URL
        await _audioPlayer.play(UrlSource(audioUrl));
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play audio: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() => _playingMessageId = null);
    }
  }

  Widget _buildAudioMessage(MessageModel message, bool isMe) {
    final isPlaying = _playingMessageId == message.id;
    final isCurrentlyPlaying = isPlaying && _playerState == PlayerState.playing;

    // Calculate progress
    final progress = isPlaying && _audioDuration.inMilliseconds > 0
        ? _audioPosition.inMilliseconds / _audioDuration.inMilliseconds
        : 0.0;

    return GestureDetector(
      onTap: () => _playPauseAudio(message),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCurrentlyPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: isMe ? AppColors.textInverse : AppColors.primary,
            size: 32,
          ),
          const SizedBox(width: 8),
          // Progress bar
          SizedBox(
            width: 100,
            child: Stack(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: (isMe ? AppColors.textInverse : AppColors.primary).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  height: 4,
                  width: 100 * progress,
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.textInverse : AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isPlaying && _audioPosition.inSeconds > 0
                ? _formatAudioDuration(_audioPosition)
                : message.audioDurationFormatted,
            style: TextStyle(
              color: isMe ? AppColors.textInverse : AppColors.textPrimary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAudioDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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

  Widget _buildInputArea(ChatState state, {bool isGroup = false}) {
    // ── Inline voice recording bar ──────────────────────────────────────────
    if (_isVoiceRecording) {
      final voiceState = ref.watch(voiceRecordingProvider);
      final duration = voiceState.recordingDuration;
      final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

      return Container(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 10,
          bottom: MediaQuery.of(context).padding.bottom + 10,
        ),
        decoration: const BoxDecoration(color: AppColors.background),
        child: Row(
          children: [
            // Cancel
            GestureDetector(
              onTap: _cancelVoiceRecording,
              child: const Icon(Icons.delete_outline, color: AppColors.error, size: 28),
            ),
            const SizedBox(width: 10),

            // Waveform + timer
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 28,
                    child: AudioWaveform(
                      isRecording: true,
                      amplitude: voiceState.currentAmplitude,
                      color: AppColors.error,
                      barCount: 28,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$minutes:$seconds',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Send
            GestureDetector(
              onTap: _stopAndSendVoiceRecording,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      );
    }

    // ── Normal input bar ────────────────────────────────────────────────────
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

          // Mention button for groups
          if (isGroup)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _showMentionPicker = !_showMentionPicker);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _showMentionPicker
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.alternate_email,
                  color: _showMentionPicker
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  size: 24,
                ),
              ),
            ),

          if (isGroup) const SizedBox(width: 8),

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

          // Send / Mic Button
          GestureDetector(
            onTap: () {
              if (_messageController.text.isNotEmpty) {
                HapticFeedback.lightImpact();
                _sendMessage();
              } else {
                HapticFeedback.mediumImpact();
                _startVoiceRecording();
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
