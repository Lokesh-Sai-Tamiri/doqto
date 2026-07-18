import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../../core/di/providers.dart';
import '../../../core/constants/strings.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/radii.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/tokens/typography.dart';
import '../../../core/utils/error_messages.dart';
import '../../../data/models/message.dart';
import '../../../data/models/organization.dart';
import '../../../state/auth_state.dart';
import '../../../state/chat_state.dart';
import '../../../state/notification_state.dart';
import '../../../state/org_state.dart';
import '../../widgets/attachment_bubbles.dart';
import '../../widgets/connectivity_banner.dart';
import '../../widgets/doctor_avatar.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/typing_indicator.dart';
import '../../widgets/voice_note_bubble.dart';
import '_conversation_display.dart';
import 'voice_recorder_panel.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatThreadScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _showRecorder = false;
  bool _typing = false;
  bool _hasText = false;
  Timer? _typingPing;

  @override
  void initState() {
    super.initState();
    // Infinite scroll-back: nearing the top (= end of the reversed list)
    // pulls the next older page.
    _scroll.addListener(() {
      if (_scroll.position.pixels >
          _scroll.position.maxScrollExtent - 400) {
        ref.read(messagesProvider(widget.conversationId).notifier).loadOlder();
      }
    });
    // Opening the thread = reading it: flip the sender's ticks to double-check.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatRepositoryProvider)
          .markConversationRead(widget.conversationId);
      // This chat is on screen: suppress banners for it and clear any shown.
      ref.read(activeConversationProvider.notifier).state =
          widget.conversationId;
      ref
          .read(notificationServiceProvider)
          .cancelForConversation(widget.conversationId);
    });
  }

  @override
  void dispose() {
    if (ref.read(activeConversationProvider) == widget.conversationId) {
      ref.read(activeConversationProvider.notifier).state = null;
    }
    _stopTyping();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Tap on a failed bubble: offer retry / discard.
  Future<void> _onFailedTap(String clientId) async {
    final notifier = ref.read(messagesProvider(widget.conversationId).notifier);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh, color: AppColors.medBlue),
              title: const Text('Retry send'),
              onTap: () => Navigator.pop(ctx, 'retry'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.red),
              title: const Text('Delete message'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'retry') await notifier.retry(clientId);
    if (action == 'delete') await notifier.discard(clientId);
  }

  void _wsTyping(bool typing) {
    ref.read(websocketClientProvider).send({
      'type': typing
          ? WsEventClient.typingStart.wire
          : WsEventClient.typingStop.wire,
      'conversation_id': widget.conversationId,
    });
  }

  void _stopTyping() {
    _typingPing?.cancel();
    _typingPing = null;
    if (_typing) {
      _typing = false;
      _wsTyping(false);
    }
  }

  void _onInputChanged(String value) {
    final hasText = value.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
    if (hasText) {
      if (!_typing) {
        _typing = true;
        _wsTyping(true);
        // Re-ping while text is present so the other side's indicator never
        // times out mid-message.
        _typingPing = Timer.periodic(const Duration(seconds: 3), (_) {
          if (_typing) _wsTyping(true);
        });
      }
    } else {
      _stopTyping();
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() => _hasText = false); // clear() doesn't fire onChanged
    _stopTyping();
    await ref
        .read(messagesProvider(widget.conversationId).notifier)
        .sendText(text);
  }

  // ---- Attachments ---------------------------------------------------------

  Future<void> _pickAttachment() async {
    final choice = await _showOptionsSheet(
      title: 'Share',
      options: const [
        (icon: Icons.photo_outlined, label: 'Photo', value: 'photo'),
        (icon: Icons.description_outlined, label: 'Document', value: 'doc'),
      ],
    );
    if (choice == 'photo') {
      await _pickPhoto();
    } else if (choice == 'doc') {
      await _pickDocument();
    }
  }

  Future<void> _pickPhoto() async {
    final source = await _showOptionsSheet(
      title: 'Photo',
      options: const [
        (icon: Icons.camera_alt_outlined, label: 'Take photo', value: 'camera'),
        (
          icon: Icons.photo_library_outlined,
          label: 'Choose from gallery',
          value: 'gallery'
        ),
      ],
    );
    if (source == null) return;
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      _showError(source == 'camera'
          ? 'Camera not available on this device'
          : 'Could not open the photo library');
      return;
    }
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await _upload(
      bytes: bytes,
      filename: picked.name,
      contentType:
          picked.mimeType ?? lookupMimeType(picked.name) ?? 'image/jpeg',
    );
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    await _upload(
      bytes: file.bytes!,
      filename: file.name,
      contentType: lookupMimeType(file.name) ?? 'application/octet-stream',
    );
  }

  /// Outbox-first: the notifier persists + enqueues and shows an optimistic
  /// bubble immediately; failures surface as a failed bubble (tap to retry),
  /// so no blocking spinner and no error snackbar here.
  Future<void> _upload({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    try {
      await ref
          .read(messagesProvider(widget.conversationId).notifier)
          .sendUpload(
            bytes: bytes,
            filename: filename,
            contentType: contentType,
          );
    } catch (e) {
      // Only local persistence can throw (e.g. disk full).
      _showError(ErrorMessages.forApi(e));
    }
  }

  Future<String?> _showOptionsSheet({
    required String title,
    required List<({IconData icon, String label, String value})> options,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
              child: Text(title, style: AppText.heading),
            ),
            for (final o in options)
              ListTile(
                leading: Icon(o.icon, color: AppColors.medBlue),
                title: Text(o.label, style: AppText.bodyPrimary),
                onTap: () => Navigator.of(sheetCtx).pop(o.value),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authProvider).user;
    final async = ref.watch(messagesProvider(widget.conversationId));
    final otherTyping = ref.watch(typingProvider(widget.conversationId));
    // While the thread is open, mark read only when a genuinely NEW message
    // from the other party arrives (newest id changed) — guarding against the
    // read→MESSAGE_READ→rebuild feedback loop.
    ref.listen(messagesProvider(widget.conversationId), (prev, next) {
      final msgs = next.asData?.value;
      if (msgs == null || msgs.isEmpty) return;
      final prevNewestId = prev?.asData?.value.firstOrNull?.id;
      if (msgs.first.id == prevNewestId) {
        return; // read-state change, not a new message
      }
      if (msgs.first.senderId != me?.id) {
        ref
            .read(chatRepositoryProvider)
            .markConversationRead(widget.conversationId);
      }
    });
    final convs = ref.watch(conversationsProvider).asData?.value ?? const [];
    final conv = convs
        .where((c) => c.id == widget.conversationId)
        .cast<dynamic>()
        .firstOrNull;
    final currentOrg = ref.watch(orgProvider).current;
    final orgMembers = currentOrg == null
        ? const <OrgMember>[]
        : (ref.watch(orgMembersProvider(currentOrg.id)).asData?.value ??
              const <OrgMember>[]);
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
                onTap: () =>
                    context.push(AppRoutes.chatDetails(widget.conversationId)),
                child: Row(
                  children: [
                    DoctorAvatar(
                      initials: display.initials,
                      size: AvatarSize.sm,
                      imageUrl: display.otherUser?.avatarPresignedUrl,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(display.title, overflow: TextOverflow.ellipsis),
                          if (otherTyping)
                            Text(
                              'typing…',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.medBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      body: Column(
        children: [
          const ConnectivityBanner(),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (allMsgs) {
                // Hide disappearing messages past their expiry even before the
                // server purge tick; any rebuild re-filters.
                final now = DateTime.now().toUtc();
                final msgs = allMsgs
                    .where(
                      (m) => m.expiresAt == null || m.expiresAt!.isAfter(now),
                    )
                    .toList();
                final notifier =
                    ref.read(messagesProvider(widget.conversationId).notifier);
                return ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  // +1 row at the top (list end) for the older-page spinner.
                  itemCount: msgs.length + (notifier.loadingOlder ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= msgs.length) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final m = msgs[i];
                    final isMine = me?.id == m.senderId;
                    if (m.type == MessageType.system) {
                      return SystemMessageBubble(text: m.content ?? '');
                    }
                    // Local outbox media/voice (sending or failed): the file
                    // isn't on the server yet, so the URL-backed bubbles can't
                    // render it — show a labeled bubble with status ticks
                    // (and the same tap-to-retry flow as failed text).
                    final isLocalPending =
                        m.clientId != null && m.status != MessageStatus.sent;
                    if (isLocalPending && m.type != MessageType.text) {
                      final label = switch (m.type) {
                        MessageType.voiceNote =>
                          'Voice note (${(m.voiceDurationSec ?? 0) ~/ 60}:${((m.voiceDurationSec ?? 0) % 60).toString().padLeft(2, '0')})',
                        _ => m.fileName ?? 'Attachment',
                      };
                      final bubble = MessageBubble(
                        text: label,
                        isMine: isMine,
                        timestamp: m.createdAt.toLocal(),
                        read: m.read,
                        delivered: m.delivered,
                        status: m.status,
                      );
                      if (m.status == MessageStatus.failed) {
                        return GestureDetector(
                          onTap: () => _onFailedTap(m.clientId!),
                          child: bubble,
                        );
                      }
                      return bubble;
                    }
                    if (m.type == MessageType.voiceNote) {
                      return VoiceNoteBubble(
                        // Key by message id: these bubbles cache a resolved
                        // file URL in State — without a key, ListView reuses
                        // the State for a DIFFERENT message when the list
                        // shifts, showing the wrong media.
                        key: ValueKey(m.id),
                        durationSec: m.voiceDurationSec ?? 0,
                        transcript: m.transcript,
                        isMine: isMine,
                        getAudioUrl: () =>
                            ref.read(chatRepositoryProvider).fileUrl(m.id),
                      );
                    }
                    if (m.type == MessageType.image) {
                      return ImageBubble(
                        key: ValueKey(m.id),
                        getFileUrl: () =>
                            ref.read(chatRepositoryProvider).fileUrl(m.id),
                        isMine: isMine,
                        timestamp: m.createdAt.toLocal(),
                        read: m.read,
                        delivered: m.delivered,
                      );
                    }
                    if (m.type == MessageType.file) {
                      return FileBubble(
                        getFileUrl: () =>
                            ref.read(chatRepositoryProvider).fileUrl(m.id),
                        fileName: m.fileName ?? 'File',
                        fileSizeBytes: m.fileSizeBytes,
                        isMine: isMine,
                        timestamp: m.createdAt.toLocal(),
                        read: m.read,
                        delivered: m.delivered,
                      );
                    }
                    final bubble = MessageBubble(
                      text: m.content ?? '[${m.type.wire}]',
                      isMine: isMine,
                      timestamp: m.createdAt.toLocal(),
                      read: m.read,
                      delivered: m.delivered,
                      status: m.status,
                    );
                    if (m.status == MessageStatus.failed && m.clientId != null) {
                      return GestureDetector(
                        onTap: () => _onFailedTap(m.clientId!),
                        child: bubble,
                      );
                    }
                    return bubble;
                  },
                );
              },
            ),
          ),
          if (otherTyping) const TypingIndicator(),
          if (_showRecorder)
            VoiceRecorderPanel(
              conversationId: widget.conversationId,
              onSent: () => setState(() => _showRecorder = false),
              onCancel: () => setState(() => _showRecorder = false),
            )
          else
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                color: AppColors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            decoration: InputDecoration(
                              hintText: Strings.chatMessageHint,
                              border: OutlineInputBorder(
                                borderRadius: AppRadii.rFull,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md + 2,
                                vertical: AppSpacing.sm + 1,
                              ),
                            ),
                            onChanged: _onInputChanged,
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        // WhatsApp-style: attach + mic when idle, send while typing.
                        if (_hasText)
                          IconButton(
                            onPressed: _send,
                            icon: const Icon(Icons.send,
                                color: AppColors.medBlue),
                          )
                        else ...[
                          IconButton(
                            onPressed: _pickAttachment,
                            icon: const Icon(Icons.attach_file,
                                color: AppColors.medBlue),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _showRecorder = true),
                            icon: const Icon(Icons.mic,
                                color: AppColors.medBlue),
                          ),
                        ],
                      ],
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
