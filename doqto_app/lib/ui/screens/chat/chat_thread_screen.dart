import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';

import '../../../core/di/providers.dart';
import '../../../core/constants/strings.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/motion.dart';
import '../../../core/tokens/radii.dart';
import '../../../core/tokens/shadows.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/tokens/typography.dart';
import '../../../core/utils/error_messages.dart';
import '../../../data/models/conversation.dart';
import '../../../data/models/message.dart';
import '../../../data/models/message_edit.dart';
import '../../../data/models/organization.dart';
import '../../../state/auth_state.dart';
import '../../../state/chat_state.dart';
import '../../../state/network_state.dart';
import '../../../state/notification_state.dart';
import '../../../state/org_state.dart';
import '../../widgets/app_pressable.dart';
import '../../widgets/attachment_bubbles.dart';
import '../../widgets/connectivity_banner.dart';
import '../../widgets/doctor_avatar.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/request_composer_bar.dart';
import '../../widgets/typing_indicator.dart';
import '../../widgets/voice_note_bubble.dart';
import '_conversation_display.dart';
import 'voice_recorder_panel.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String conversationId;

  /// When false, the screen renders without its own AppBar — used when the
  /// thread is embedded inside another screen's segment (e.g. a group detail's
  /// Chat tab, which already shows the group header). All message plumbing
  /// (MessagesNotifier, composer, receipts) is reused unchanged.
  final bool showAppBar;

  const ChatThreadScreen({
    super.key,
    required this.conversationId,
    this.showAppBar = true,
  });

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
  // Composer edit mode: the sent message whose text is being replaced.
  Message? _editing;

  // --- New-message entrance tracking (screen-local; no state-layer changes).
  // Messages present at first build (and older pages loaded later) never
  // animate; only messages created after the screen opened do.
  final DateTime _openedAt = DateTime.now().toUtc();
  final Set<String> _knownIds = {};
  final Set<String> _entranceIds = {};
  bool _seededIds = false;

  // --- Scroll-to-bottom pill (screen-local).
  static const double _jumpThresholdPx = 400;
  bool _showJump = false;
  int _unseenCount = 0;

  // --- Request-tier composer state (M4). Tier is read from the conversations/
  // requests LIST providers (never a detail fetch — detail returns access=null).
  ConversationAccess? _accessOverride; // set after accept / recipient reply
  bool _sentInRequest = false; // initiator sent their one message this session
  bool _notConnectedDismissed = false;
  bool _requestBusy = false;
  // Snapshot of the current tier, recomputed each build and read by _send.
  bool _curRecipientPending = false;
  bool _curInitiatorBeforeFirst = false;

  @override
  void initState() {
    super.initState();
    // Infinite scroll-back: nearing the top (= end of the reversed list)
    // pulls the next older page.
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(messagesProvider(widget.conversationId).notifier).loadOlder();
      }
      final showJump = _scroll.position.pixels > _jumpThresholdPx;
      if (showJump != _showJump) {
        setState(() {
          _showJump = showJump;
          if (!showJump) _unseenCount = 0; // back at bottom = caught up
        });
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
    // ponytail: ref is gone when the whole tree is torn down (app exit /
    // test teardown); clearing the active chat is moot then.
    try {
      if (ref.read(activeConversationProvider) == widget.conversationId) {
        ref.read(activeConversationProvider.notifier).state = null;
      }
    } catch (_) {}
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

  /// Long-press on an own sent bubble: edit (text, ≤5 min) / delete (≤3 min).
  /// The server is the authority on the windows; this only decides what to show.
  Future<void> _onMessageLongPress(Message m) async {
    final me = ref.read(authProvider).user?.id;
    if (me == null) return;
    final canEdit = m.canEdit(me: me);
    final canDelete = m.canDelete(me: me);
    if (!canEdit && !canDelete) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit)
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.medBlue,
                ),
                title: const Text(Strings.chatEditMessage),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.red),
                title: const Text(Strings.chatDeleteMessage),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') _startEdit(m);
    if (action == 'delete') await _deleteMessage(m);
  }

  void _startEdit(Message m) {
    setState(() {
      _editing = m;
      _input.text = m.content ?? '';
      _hasText = _input.text.trim().isNotEmpty;
    });
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
  }

  void _cancelEdit() {
    setState(() {
      _editing = null;
      _input.clear();
      _hasText = false;
    });
    _stopTyping();
  }

  Future<void> _submitEdit(Message m, String text) async {
    _cancelEdit();
    if (text == m.content) return; // nothing changed
    try {
      await ref
          .read(messagesProvider(widget.conversationId).notifier)
          .edit(m.id, text);
    } catch (e) {
      _toast(ErrorMessages.forApi(e));
    }
  }

  Future<void> _deleteMessage(Message m) async {
    if (_editing?.id == m.id) _cancelEdit();
    try {
      await ref
          .read(messagesProvider(widget.conversationId).notifier)
          .delete(m.id);
    } catch (e) {
      _toast(ErrorMessages.forApi(e));
    }
  }

  /// Every earlier version of an edited message, newest first — either side.
  Future<void> _showEditHistory(Message m) async {
    final future = ref.read(chatRepositoryProvider).messageEdits(m.id);
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: FutureBuilder<List<MessageEdit>>(
          future: future,
          builder: (ctx, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(ErrorMessages.forApi(snap.error)),
              );
            }
            if (!snap.hasData) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final edits = snap.data!.reversed.toList();
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: [
                ListTile(
                  title: Text(Strings.chatEditHistory, style: AppText.label),
                  subtitle: Text(
                    '${Strings.chatEdited} ${DateFormat.yMMMd().add_jm().format((m.editedAt ?? m.createdAt).toLocal())}',
                    style: AppText.caption,
                  ),
                ),
                const Divider(height: 1),
                if (edits.isEmpty)
                  const ListTile(title: Text(Strings.chatEditHistoryEmpty))
                else
                  for (final e in edits)
                    ListTile(
                      title: Text(e.content, style: AppText.messageBody),
                      subtitle: Text(
                        DateFormat.yMMMd().add_jm().format(
                          e.replacedAt.toLocal(),
                        ),
                        style: AppText.timestamp,
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
    final editing = _editing;
    if (editing != null) {
      return _submitEdit(editing, text);
    }
    _input.clear();
    setState(() => _hasText = false); // clear() doesn't fire onChanged
    _stopTyping();
    await ref
        .read(messagesProvider(widget.conversationId).notifier)
        .sendText(text);
    // Request-tier reflection (server enforces the actual rules):
    if (_curRecipientPending) {
      // A recipient reply auto-accepts server-side → flip to open locally and
      // move the thread out of Requests into Focused.
      if (mounted) setState(() => _accessOverride = ConversationAccess.open);
      ref.read(requestsProvider.notifier).removeLocally(widget.conversationId);
      ref.read(conversationsProvider.notifier).refresh();
    } else if (_curInitiatorBeforeFirst) {
      // The one allowed message is now sent → lock the composer.
      if (mounted) setState(() => _sentInRequest = true);
    }
  }

  // ---- Scheduled send (long-press on the send button) ---------------------

  static const _deviceZone = 'Device time';
  // ponytail: curated zone list; the server (Python zoneinfo) accepts any
  // IANA name, so growing this is a one-line-per-zone change.
  static const _zones = [
    _deviceZone,
    'UTC',
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'Europe/London',
    'Europe/Berlin',
    'Asia/Dubai',
    'Asia/Kolkata',
    'Asia/Singapore',
    'Asia/Tokyo',
    'Australia/Sydney',
  ];

  Future<void> _openScheduleSheet() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    var when = DateTime.now().add(const Duration(hours: 1));
    var date = DateTime(when.year, when.month, when.day);
    var time = TimeOfDay.fromDateTime(when);
    var zone = _deviceZone;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Schedule message',
                  style: Theme.of(ctx).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                ListTile(
                  leading: const Icon(Icons.event, color: AppColors.medBlue),
                  title: Text(DateFormat.yMMMEd().format(date)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setSheet(() => date = picked);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.schedule, color: AppColors.medBlue),
                  title: Text(time.format(ctx)),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: time,
                    );
                    if (picked != null) setSheet(() => time = picked);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.public, color: AppColors.medBlue),
                  title: DropdownButton<String>(
                    value: zone,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final z in _zones)
                        DropdownMenuItem(
                          value: z,
                          child: Text(z.replaceAll('_', ' ')),
                        ),
                    ],
                    onChanged: (z) {
                      if (z != null) setSheet(() => zone = z);
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Schedule'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final wall = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    // Device zone: the client already knows the UTC instant — send it as UTC.
    // Named zone: send the wall-clock time and let the server's tz database
    // resolve the instant (DST rules live in one place).
    final scheduledLocal = zone == _deviceZone
        ? wall.toUtc().toIso8601String()
        : DateFormat("yyyy-MM-dd'T'HH:mm:00").format(wall);
    final tz = zone == _deviceZone ? 'UTC' : zone;
    try {
      await ref
          .read(chatRepositoryProvider)
          .scheduleText(
            widget.conversationId,
            text,
            scheduledLocal: scheduledLocal,
            timezone: tz,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ErrorMessages.forApi(e))));
      }
      return;
    }
    if (!mounted) return;
    _input.clear();
    setState(() => _hasText = false);
    _stopTyping();
    final zoneLabel = zone == _deviceZone
        ? ''
        : ' (${zone.replaceAll('_', ' ')})';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Scheduled for ${DateFormat.yMMMEd().format(wall)} ${time.format(context)}$zoneLabel',
        ),
      ),
    );
  }

  // ---- Request-tier actions (recipient) -----------------------------------

  Future<void> _acceptRequest() async {
    if (_requestBusy) return;
    setState(() => _requestBusy = true);
    try {
      await ref.read(requestsProvider.notifier).accept(widget.conversationId);
      if (!mounted) return;
      setState(() => _accessOverride = ConversationAccess.open);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Strings.netRequestAcceptedToast)),
      );
    } catch (e) {
      if (mounted) _showError(ErrorMessages.forApi(e));
    } finally {
      if (mounted) setState(() => _requestBusy = false);
    }
  }

  Future<void> _declineRequest() async {
    if (_requestBusy) return;
    setState(() => _requestBusy = true);
    try {
      await ref.read(requestsProvider.notifier).decline(widget.conversationId);
      if (mounted) context.pop(); // silent — leave the thread
    } catch (e) {
      if (mounted) {
        setState(() => _requestBusy = false);
        _showError(ErrorMessages.forApi(e));
      }
    }
  }

  Future<void> _blockFromThread(String otherId) async {
    if (_requestBusy) return;
    setState(() => _requestBusy = true);
    ref.read(requestsProvider.notifier).removeLocally(widget.conversationId);
    try {
      await ref.read(networkRepositoryProvider).block(otherId);
      if (mounted) context.pop();
    } catch (e) {
      await ref.read(requestsProvider.notifier).refresh();
      if (mounted) {
        setState(() => _requestBusy = false);
        _showError(ErrorMessages.forApi(e));
      }
    }
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
          value: 'gallery',
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
      _showError(
        source == 'camera'
            ? 'Camera not available on this device'
            : 'Could not open the photo library',
      );
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
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- Entrance / separator helpers ---------------------------------------

  /// Records which message ids are already known so only genuinely NEW
  /// messages (arrived over WS after mount) get an entrance animation.
  /// History and older pagination pages never animate. Runs during build —
  /// pure set mutation, no setState (the unseen-count bump is deferred).
  void _trackNew(List<Message> msgs, String? meId) {
    if (!_seededIds) {
      _knownIds.addAll(msgs.map((m) => m.id));
      _seededIds = true;
      return;
    }
    var newIncoming = 0;
    for (final m in msgs) {
      if (_knownIds.contains(m.id)) continue;
      _knownIds.add(m.id);
      // Server echo of an optimistic outbox bubble: same message, new id —
      // it already animated under its clientId, don't replay. (The optimistic
      // bubble itself has id == clientId, so exclude that case.)
      final isEcho =
          m.clientId != null &&
          m.clientId != m.id &&
          _knownIds.contains(m.clientId);
      if (m.createdAt.isAfter(_openedAt) && !isEcho) {
        _entranceIds.add(m.id);
        if (m.senderId != meId) newIncoming++;
      }
    }
    if (newIncoming > 0 &&
        _scroll.hasClients &&
        _scroll.position.pixels > _jumpThresholdPx) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _unseenCount += newIncoming);
      });
    }
  }

  /// Consecutive same-sender, same-day bubbles group tighter.
  /// List is reversed: the message visually above index i is msgs[i + 1].
  bool _isGrouped(List<Message> msgs, int i) {
    if (i + 1 >= msgs.length) return false;
    final prev = msgs[i + 1];
    final cur = msgs[i];
    return prev.senderId == cur.senderId &&
        prev.type != MessageType.system &&
        _sameDay(prev.createdAt.toLocal(), cur.createdAt.toLocal());
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dayLabel(DateTime local) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat(
      that.year == now.year ? 'MMM d' : 'MMM d, y',
    ).format(that);
  }

  /// Per-type bubble (logic unchanged from the pre-revamp itemBuilder);
  /// failed bubbles get press feedback via AppPressable but keep the exact
  /// same tap → retry/discard sheet flow.
  Widget _buildBubble(Message m, bool isMine, List<Message> msgs, int i) {
    if (m.type == MessageType.system) {
      return SystemMessageBubble(text: m.content ?? '');
    }
    final grouped = _isGrouped(msgs, i);
    // Sender deleted it: same tombstone for every type, no menu, no ticks.
    if (m.isDeleted) {
      return MessageBubble(
        text: '',
        isMine: isMine,
        timestamp: m.createdAt.toLocal(),
        grouped: grouped,
        deleted: true,
      );
    }
    return _withActions(m, _buildLiveBubble(m, isMine, msgs, i, grouped));
  }

  /// Own sent bubbles get the long-press edit/delete menu while a window is
  /// still open; the menu itself re-checks, so a stale wrap is harmless.
  Widget _withActions(Message m, Widget bubble) {
    final me = ref.read(authProvider).user?.id;
    if (me == null || !(m.canEdit(me: me) || m.canDelete(me: me))) {
      return bubble;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _onMessageLongPress(m),
      child: bubble,
    );
  }

  Widget _buildLiveBubble(
    Message m,
    bool isMine,
    List<Message> msgs,
    int i,
    bool grouped,
  ) {
    // Local outbox media/voice (sending or failed): the file isn't on the
    // server yet, so the URL-backed bubbles can't render it — show a labeled
    // bubble with status ticks (and the same tap-to-retry flow as failed text).
    final isLocalPending = m.clientId != null && m.status != MessageStatus.sent;
    if (isLocalPending && m.type != MessageType.text) {
      final Widget bubble;
      if (m.type == MessageType.image && m.localPath != null) {
        bubble = PendingImageBubble(
          path: m.localPath!,
          isMine: isMine,
          timestamp: m.createdAt.toLocal(),
          status: m.status,
        );
      } else if (m.type == MessageType.file) {
        bubble = FileBubble(
          getFileUrl: null, // still local — nothing to open yet
          fileName: m.fileName ?? 'Document',
          isMine: isMine,
          timestamp: m.createdAt.toLocal(),
          status: m.status,
        );
      } else {
        final label = switch (m.type) {
          MessageType.voiceNote =>
            'Voice note (${(m.voiceDurationSec ?? 0) ~/ 60}:${((m.voiceDurationSec ?? 0) % 60).toString().padLeft(2, '0')})',
          _ => m.fileName ?? 'Attachment',
        };
        bubble = MessageBubble(
          text: label,
          isMine: isMine,
          timestamp: m.createdAt.toLocal(),
          read: m.read,
          delivered: m.delivered,
          status: m.status,
          grouped: grouped,
        );
      }
      if (m.status == MessageStatus.failed) {
        return AppPressable(
          onTap: () => _onFailedTap(m.clientId!),
          child: bubble,
        );
      }
      return bubble;
    }
    if (m.type == MessageType.voiceNote) {
      return VoiceNoteBubble(
        // Key by message id: these bubbles cache a resolved file URL in
        // State — without a key, ListView reuses the State for a DIFFERENT
        // message when the list shifts, showing the wrong media.
        key: ValueKey(m.id),
        durationSec: m.voiceDurationSec ?? 0,
        transcript: m.transcript,
        isMine: isMine,
        getAudioUrl: () => ref.read(chatRepositoryProvider).fileUrl(m.id),
      );
    }
    if (m.type == MessageType.image) {
      return ImageBubble(
        key: ValueKey(m.id),
        getFileUrl: () => ref.read(chatRepositoryProvider).fileUrl(m.id),
        isMine: isMine,
        timestamp: m.createdAt.toLocal(),
        read: m.read,
        delivered: m.delivered,
      );
    }
    if (m.type == MessageType.file) {
      return FileBubble(
        getFileUrl: () => ref.read(chatRepositoryProvider).fileUrl(m.id),
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
      grouped: grouped,
      edited: m.editedAt != null,
      onEditedTap: () => _showEditHistory(m),
    );
    if (m.status == MessageStatus.failed && m.clientId != null) {
      return AppPressable(
        onTap: () => _onFailedTap(m.clientId!),
        child: bubble,
      );
    }
    return bubble;
  }

  void _jumpToBottom() {
    setState(() => _unseenCount = 0);
    if (AppMotion.reduced(context)) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(
        0,
        duration: AppMotion.emphasizedDuration,
        curve: AppMotion.standard,
      );
    }
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
    // Tier source: the LIST providers. Focused holds open + initiator-pending
    // conversations; requests holds received pending ones. Detail endpoint
    // returns access=null, so it is never consulted for the tier.
    final focused = ref.watch(conversationsProvider).asData?.value ?? const [];
    final requests = ref.watch(requestsProvider).valueOrNull ?? const [];
    Conversation? conv;
    for (final c in [...focused, ...requests]) {
      if (c.id == widget.conversationId) {
        conv = c;
        break;
      }
    }
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

    // ---- Request-tier / not-connected computation (M4) --------------------
    final meId = me?.id;
    final access = _accessOverride ?? conv?.access ?? ConversationAccess.open;
    final initiatorId = conv?.initiatorId;
    final isPending = access == ConversationAccess.pendingRequest;
    final isRecipientPending =
        isPending && initiatorId != null && initiatorId != meId;
    final isInitiatorPending =
        isPending && initiatorId != null && initiatorId == meId;
    final initiatorFirstSent =
        isInitiatorPending &&
        ((conv?.lastMessageType != null) || _sentInRequest);
    final isInitiatorBeforeFirst = isInitiatorPending && !initiatorFirstSent;
    final isDeclined = access == ConversationAccess.declined;
    // The other participant (direct threads only) — drives block + Connect.
    String? otherId;
    if (conv != null) {
      for (final id in conv.memberIds) {
        if (id != meId) {
          otherId = id;
          break;
        }
      }
    }
    // Cache the tier for _send.
    _curRecipientPending = isRecipientPending;
    _curInitiatorBeforeFirst = isInitiatorBeforeFirst;

    // Composer visibility: locked when the request is one-directional/terminal.
    final composerLocked = isDeclined || initiatorFirstSent;
    final composerTextOnly = isInitiatorBeforeFirst;

    // Non-connected direct network chat (open) → dismissible Connect banner.
    // Colleagues are excluded: every direct conversation is network-scoped
    // since M0, so isNetwork alone would nag people who share an org and
    // never needed a connection in the first place.
    final otherRel = otherId == null
        ? null
        : ref.watch(relationshipProvider(otherId)).valueOrNull?.relationship;
    final showNotConnected =
        access == ConversationAccess.open &&
        conv != null &&
        conv.isNetwork &&
        (display?.isDirect ?? false) &&
        otherId != null &&
        !_notConnectedDismissed &&
        !(otherRel?.isColleague ?? false) &&
        otherRel?.connectionState != RelationshipState.connected;

    return Scaffold(
      appBar: !widget.showAppBar
          ? null
          : AppBar(
              titleSpacing: 0,
              title: display == null
                  ? const Text('Chat')
                  : InkWell(
                      onTap: () => context.push(
                        AppRoutes.chatDetails(widget.conversationId),
                      ),
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
                                Text(
                                  display.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                _trackNew(msgs, me?.id);
                final notifier = ref.read(
                  messagesProvider(widget.conversationId).notifier,
                );
                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        final m = msgs[i];
                        final isMine = me?.id == m.senderId;
                        Widget row = _buildBubble(m, isMine, msgs, i);
                        // NEW messages only: sent slide from right, received
                        // from left. Keyed by id so history/pagination and
                        // recycled list elements never replay.
                        row = _MessageEntrance(
                          key: ValueKey('enter-${m.id}'),
                          animate: _entranceIds.contains(m.id),
                          fromRight: isMine,
                          onShown: () => _entranceIds.remove(m.id),
                          child: row,
                        );
                        // Day pill above the first message of each day
                        // (reversed list: "above" = index i + 1).
                        final showDay =
                            i == msgs.length - 1 ||
                            !_sameDay(
                              m.createdAt.toLocal(),
                              msgs[i + 1].createdAt.toLocal(),
                            );
                        if (showDay) {
                          row = Column(
                            children: [
                              _DateChip(
                                label: _dayLabel(m.createdAt.toLocal()),
                              ),
                              row,
                            ],
                          );
                        }
                        return row;
                      },
                    ),
                    Positioned(
                      right: AppSpacing.lg,
                      bottom: AppSpacing.lg,
                      child: _JumpToBottomPill(
                        visible: _showJump,
                        unreadCount: _unseenCount,
                        onTap: _jumpToBottom,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (otherTyping) const TypingIndicator(),
          // Request-tier region: banners + (composer | locked bar). Tier comes
          // from the LIST providers above — never a thread-detail fetch.
          RequestComposerBar(
            isRecipientPending: isRecipientPending,
            isInitiatorBeforeFirst: isInitiatorBeforeFirst,
            composerLocked: composerLocked,
            isDeclined: isDeclined,
            showNotConnected: showNotConnected,
            otherId: otherId,
            otherName: display?.title ?? '',
            busy: _requestBusy,
            onAccept: _acceptRequest,
            onDelete: _declineRequest,
            onBlock: _blockFromThread,
            onDismissNotConnected: () =>
                setState(() => _notConnectedDismissed = true),
            composer: _showRecorder
                ? VoiceRecorderPanel(
                    conversationId: widget.conversationId,
                    onSent: () => setState(() => _showRecorder = false),
                    onCancel: () => setState(() => _showRecorder = false),
                  )
                : _composer(hideAttachments: composerTextOnly),
          ),
        ],
      ),
    );
  }

  /// The normal message composer. [hideAttachments] drops the attach/mic
  /// affordances (request tier allows exactly one text message, no media).
  Widget _composer({bool hideAttachments = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_editing != null) _editingStrip(_editing!),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.send,
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        decoration: InputDecoration(
                          hintText: Strings.chatMessageHint,
                          border: OutlineInputBorder(
                            borderRadius: AppRadii.rXl,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md + 2,
                            vertical: AppSpacing.md - 2,
                          ),
                        ),
                        onChanged: _onInputChanged,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // WhatsApp-style morph: attach + mic when idle, send while
                  // typing — scale+fade swap, never a snap. In request mode the
                  // idle affordances collapse to nothing (text-only).
                  AnimatedSwitcher(
                    duration: AppMotion.maybe(context, AppMotion.micro),
                    switchInCurve: AppMotion.curveEnter,
                    switchOutCurve: AppMotion.curveExit,
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: _hasText
                        ? AppPressable(
                            key: const ValueKey('composer-send'),
                            haptic: true,
                            minTarget: true,
                            onTap: _send,
                            onLongPress: _openScheduleSheet,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: AppColors.medBlue,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _editing != null
                                    ? Icons.check_rounded
                                    : Icons.send_rounded,
                                color: AppColors.white,
                                size: 20,
                              ),
                            ),
                          )
                        : hideAttachments
                        ? const SizedBox(
                            key: ValueKey('composer-idle-empty'),
                            height: 44,
                          )
                        : Row(
                            key: const ValueKey('composer-idle'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: _pickAttachment,
                                icon: const Icon(
                                  Icons.attach_file,
                                  color: AppColors.medBlue,
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _showRecorder = true),
                                icon: const Icon(
                                  Icons.mic,
                                  color: AppColors.medBlue,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Editing message" strip above the composer with the original text and a
  /// close button that abandons the edit.
  Widget _editingStrip(Message m) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        0,
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, size: 18, color: AppColors.medBlue),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Strings.chatEditingMessage,
                  style: AppText.label.copyWith(color: AppColors.medBlue),
                ),
                Text(
                  m.content ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _cancelEdit,
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    );
  }
}

/// One-shot entrance for a NEW message bubble: fade + horizontal slide
/// (sent from the right, received from the left). History renders instantly
/// (`animate: false`). Keyed by message id so list recycling never replays.
class _MessageEntrance extends StatefulWidget {
  final bool animate;
  final bool fromRight;
  final VoidCallback? onShown;
  final Widget child;

  const _MessageEntrance({
    super.key,
    required this.animate,
    required this.fromRight,
    this.onShown,
    required this.child,
  });

  @override
  State<_MessageEntrance> createState() => _MessageEntranceState();
}

class _MessageEntranceState extends State<_MessageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.enter,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.curveEnter,
  );

  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (!widget.animate) _controller.value = 1.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate) return;
    widget.onShown?.call(); // one-shot: never replay after recycle
    if (AppMotion.reduced(context)) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isCompleted) return widget.child;
    final dx = widget.fromRight ? 24.0 : -24.0;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(dx * (1 - _t.value), 0),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Day-separator pill (Today / Yesterday / MMM d) between day groups.
class _DateChip extends StatelessWidget {
  final String label;
  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: AppRadii.rFull,
          ),
          child: Text(
            label,
            style: AppText.timestamp.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating scroll-to-bottom pill: fades + slides in when scrolled up past
/// the threshold; shows an unread badge for messages that arrived meanwhile.
class _JumpToBottomPill extends StatelessWidget {
  final bool visible;
  final int unreadCount;
  final VoidCallback onTap;

  const _JumpToBottomPill({
    required this.visible,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.maybe(context, AppMotion.micro);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        curve: visible ? AppMotion.curveEnter : AppMotion.curveExit,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 0.4),
          duration: duration,
          curve: visible ? AppMotion.curveEnter : AppMotion.curveExit,
          child: AppPressable(
            onTap: onTap,
            minTarget: true,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.rFull,
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.card,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (unreadCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm - 2,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.medBlue,
                        borderRadius: BorderRadius.all(
                          Radius.circular(AppRadii.full),
                        ),
                      ),
                      child: Text(
                        '$unreadCount',
                        style: AppText.badge.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.medBlue,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
