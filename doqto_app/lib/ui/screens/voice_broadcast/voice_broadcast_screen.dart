import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/di/providers.dart';
import '../../../core/enums/app_enums.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/radii.dart';
import '../../../core/tokens/spacing.dart';
import '../../../core/tokens/typography.dart';
import '../../../data/models/organization.dart';
import '../../../state/auth_state.dart';
import '../../../state/chat_state.dart';
import '../../../state/org_state.dart';
import '../../widgets/doctor_avatar.dart';
import '../../widgets/primary_button.dart';

enum _Phase { pick, record, preview, sending }

class VoiceBroadcastScreen extends ConsumerStatefulWidget {
  const VoiceBroadcastScreen({super.key});

  @override
  ConsumerState<VoiceBroadcastScreen> createState() => _VoiceBroadcastScreenState();
}

class _VoiceBroadcastScreenState extends ConsumerState<VoiceBroadcastScreen> {
  _Phase _phase = _Phase.pick;

  // Recipient selection
  final Set<String> _selectedUserIds = {};
  final Set<String> _selectedConvIds = {};

  // Recording state
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _stt = SpeechToText();
  final List<double> _amplitudes = [];
  String _transcript = '';
  String? _filePath;
  int _durationSec = 0;
  Timer? _timer;
  Timer? _ampTimer;
  bool _isPlaying = false;
  int _sendProgress = 0;
  int _sendTotal = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _ampTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  int get _totalSelected => _selectedUserIds.length + _selectedConvIds.length;

  void _onNext() {
    if (_totalSelected == 0) return;
    setState(() => _phase = _Phase.record);
    _startRecording();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Microphone access needed'),
          content: const Text(
            'Doqto needs microphone permission to record voice notes. '
            'Tap "Open Settings" to enable it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      if (shouldOpen == true) {
        await openAppSettings();
      }
      if (mounted) setState(() => _phase = _Phase.pick);
      return;
    }
    await _stt.initialize();
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/broadcast_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
    _stt.listen(
      onResult: (result) {
        if (mounted) setState(() => _transcript = result.recognizedWords);
      },
      listenOptions: SpeechListenOptions(listenMode: ListenMode.dictation),
    );
    final stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSec = stopwatch.elapsed.inSeconds);
    });
    _ampTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final amp = await _recorder.getAmplitude();
      if (!mounted) return;
      final normalized = ((amp.current + 60) / 60).clamp(0.05, 1.0);
      setState(() {
        _amplitudes.add(normalized);
        if (_amplitudes.length > 40) _amplitudes.removeAt(0);
      });
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _ampTimer?.cancel();
    _stt.stop();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _filePath = path;
      _phase = _Phase.preview;
    });
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      if (_player.processingState == ProcessingState.completed ||
          _player.processingState == ProcessingState.idle) {
        await _player.setFilePath(_filePath!);
      }
      _player.play();
      setState(() => _isPlaying = true);
      _player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed && mounted) {
          setState(() => _isPlaying = false);
        }
      });
    }
  }

  Future<void> _send() async {
    if (_filePath == null) return;
    setState(() => _phase = _Phase.sending);
    final file = File(_filePath!);
    final bytes = await file.readAsBytes();
    final filename = _filePath!.split('/').last;
    final repo = ref.read(chatRepositoryProvider);

    final targets = <String>[];
    // Resolve direct conv ids for selected users
    for (final userId in _selectedUserIds) {
      try {
        final conv = await repo.createConversation(
          type: ConversationType.direct,
          name: null,
          memberIds: [userId],
        );
        targets.add(conv.id);
      } catch (_) {}
    }
    targets.addAll(_selectedConvIds);

    setState(() {
      _sendTotal = targets.length;
      _sendProgress = 0;
    });

    int successCount = 0;
    for (final convId in targets) {
      try {
        await repo.uploadVoiceNote(
          conversationId: convId,
          bytes: bytes,
          filename: filename,
          durationSec: _durationSec,
          transcript: _transcript.isNotEmpty ? _transcript : null,
        );
        successCount++;
      } catch (_) {}
      if (mounted) setState(() => _sendProgress++);
    }

    ref.invalidate(conversationsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Voice note sent to $successCount conversation${successCount == 1 ? '' : 's'}.'),
      backgroundColor: AppColors.medBlue,
    ));
    context.pop();
  }

  void _discard() {
    if (_filePath != null) File(_filePath!).delete().catchError((_) => File(_filePath!));
    context.pop();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      appBar: AppBar(
        title: Text(_phase == _Phase.pick ? 'Send voice note' : 'Recording'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _phase == _Phase.sending ? null : () => context.pop(),
        ),
      ),
      body: switch (_phase) {
        _Phase.pick => _buildPicker(),
        _Phase.record => _buildRecording(),
        _Phase.preview => _buildPreview(),
        _Phase.sending => _buildSending(),
      },
    );
  }

  Widget _buildPicker() {
    final orgId = ref.watch(orgProvider).current?.id;
    final currentUserId = ref.watch(authProvider).user?.id;
    final membersAsync = orgId != null
        ? ref.watch(orgMembersProvider(orgId))
        : const AsyncValue<List<OrgMember>>.data([]);
    final convsAsync = ref.watch(conversationsProvider);
    final groups = (convsAsync.asData?.value ?? [])
        .where((c) => c.type == ConversationType.group)
        .toList();

    return Column(
      children: [
        Expanded(
          child: membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (members) {
              final others = members.where((m) => m.user.id != currentUserId).toList();
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  if (groups.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenHorizontal, AppSpacing.sm,
                        AppSpacing.screenHorizontal, AppSpacing.xs,
                      ),
                      child: Text('GROUPS', style: AppText.label),
                    ),
                    for (final g in groups)
                      CheckboxListTile(
                        value: _selectedConvIds.contains(g.id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selectedConvIds.add(g.id);
                          } else {
                            _selectedConvIds.remove(g.id);
                          }
                        }),
                        title: Text(g.name ?? 'Group', style: AppText.bodyPrimary),
                        secondary: DoctorAvatar(
                          initials: (g.name ?? 'G').substring(0, (g.name?.length ?? 1).clamp(0, 2)).toUpperCase(),
                          colorIndex: groups.indexOf(g),
                        ),
                        activeColor: AppColors.medBlue,
                        controlAffinity: ListTileControlAffinity.trailing,
                      ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal, AppSpacing.sm,
                      AppSpacing.screenHorizontal, AppSpacing.xs,
                    ),
                    child: Text('PEOPLE', style: AppText.label),
                  ),
                  for (final m in others)
                    CheckboxListTile(
                      value: _selectedUserIds.contains(m.user.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selectedUserIds.add(m.user.id);
                        } else {
                          _selectedUserIds.remove(m.user.id);
                        }
                      }),
                      title: Text(m.user.fullName, style: AppText.bodyPrimary),
                      subtitle: Text(m.user.specialty ?? '', style: AppText.caption),
                      secondary: DoctorAvatar(
                        initials: m.user.initials,
                        colorIndex: others.indexOf(m),
                        imageUrl: m.user.avatarPresignedUrl,
                      ),
                      activeColor: AppColors.medBlue,
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                ],
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: AppButton(
              label: 'Next${_totalSelected > 0 ? ' ($_totalSelected)' : ''}',
              onPressed: _totalSelected > 0 ? _onNext : null,
              expand: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecording() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 40; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        curve: Curves.easeOut,
                        width: 3,
                        height: i < _amplitudes.length
                            ? (_amplitudes[i] * 52).clamp(2.0, 52.0)
                            : 2.0,
                        decoration: BoxDecoration(
                          color: AppColors.medBlue,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(_formatDuration(_durationSec), style: AppText.display),
            const SizedBox(height: AppSpacing.md),
            if (_transcript.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  _transcript,
                  style: AppText.body.copyWith(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: AppSpacing.xxl),
            Material(
              color: AppColors.medBlue,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _stopRecording,
                child: Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  child: const Icon(Icons.stop, color: AppColors.white, size: 36),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _togglePlay,
                  iconSize: 48,
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: AppColors.medBlue,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(_formatDuration(_durationSec), style: AppText.display),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_transcript.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.medBlueLight,
                  borderRadius: AppRadii.rMd,
                ),
                child: Text(
                  _transcript,
                  style: AppText.bodyPrimary,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Discard',
                    variant: AppButtonVariant.ghost,
                    onPressed: _discard,
                    expand: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: 'Send to $_totalSelected',
                    icon: Icons.send,
                    onPressed: _send,
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

  Widget _buildSending() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Sending $_sendProgress / $_sendTotal…',
            style: AppText.body,
          ),
        ],
      ),
    );
  }
}
