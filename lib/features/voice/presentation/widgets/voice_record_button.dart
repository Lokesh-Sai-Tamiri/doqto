import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../providers/voice_recording_provider.dart';
import 'audio_waveform.dart';
import '../../../contacts/presentation/providers/contacts_provider.dart';
import '../../../contacts/data/models/connection_model.dart';
import '../../../chat/presentation/providers/messaging_provider.dart';

/// The main voice recording button with waveform visualization
class VoiceRecordButton extends ConsumerStatefulWidget {
  const VoiceRecordButton({super.key});

  @override
  ConsumerState<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends ConsumerState<VoiceRecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onPressStart() async {
    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Start pulse animation
    _pulseController.repeat(reverse: true);

    // Start recording
    debugPrint('[VoiceBtn] Starting recording...');
    final success = await ref.read(voiceRecordingProvider.notifier).startRecording();
    debugPrint('[VoiceBtn] startRecording=$success');

    // If recording failed, check if permission was denied
    if (!success && mounted) {
      final voiceState = ref.read(voiceRecordingProvider);

      _pulseController.stop();
      _pulseController.reset();

      if (voiceState.isPermissionPermanentlyDenied) {
        _showPermissionDeniedDialog();
      } else if (!voiceState.hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to record voice messages'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Microphone Access Required',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Microphone permission was denied. Please enable it in Settings to record voice messages.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(voiceRecordingProvider.notifier).openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _onPressEnd() async {
    // Stop pulse animation
    _pulseController.stop();
    _pulseController.reset();

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Stop recording and get the path
    final path = await ref.read(voiceRecordingProvider.notifier).stopRecording();

    if (path != null && mounted) {
      _showSendToFriendsSheet(path);
    }
  }

  void _showSendToFriendsSheet(String recordingPath) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SendToFriendsSheet(
        recordingPath: recordingPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceRecordingProvider);
    final isRecording = voiceState.isRecording;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Waveform display (above the button)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: isRecording ? 70 : 0, // Increased height to prevent overflow
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(), // Required for clipBehavior
          child: isRecording
              ? OverflowBox(
                  maxHeight: double.infinity,
                  alignment: Alignment.topCenter,
                  child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Recording duration
                      Text(
                        _formatDuration(voiceState.recordingDuration),
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Waveform
                      SizedBox(
                        height: 24,
                        child: AudioWaveform(
                          isRecording: isRecording,
                          amplitude: voiceState.currentAmplitude,
                          color: AppColors.error,
                          barCount: 25,
                        ),
                      ),
                    ],
                  ),
                ))
              : const SizedBox.shrink(),
        ),
        
        const SizedBox(height: 8),
        
        // Record button — tap to start, tap again to stop
        GestureDetector(
          onTap: () => isRecording ? _onPressEnd() : _onPressStart(),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isRecording ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isRecording ? AppColors.error : AppColors.textPrimary,
                      width: 4,
                    ),
                    boxShadow: isRecording
                        ? [
                            BoxShadow(
                              color: AppColors.error.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isRecording 
                          ? AppColors.error 
                          : AppColors.error.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isRecording ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Hint text
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isRecording ? 0.0 : 1.0,
          child: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Tap to record',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Bottom sheet for selecting friends to send the voice to
class SendToFriendsSheet extends ConsumerStatefulWidget {
  final String recordingPath;

  const SendToFriendsSheet({
    super.key,
    required this.recordingPath,
  });

  @override
  ConsumerState<SendToFriendsSheet> createState() => _SendToFriendsSheetState();
}

class _SendToFriendsSheetState extends ConsumerState<SendToFriendsSheet> {
  final Set<String> _selectedContacts = {};
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Load contacts when sheet opens
    Future.microtask(() {
      ref.read(networkProvider.notifier).loadNetwork();
    });
  }

  void _toggleContact(String userId) {
    setState(() {
      if (_selectedContacts.contains(userId)) {
        _selectedContacts.remove(userId);
      } else {
        _selectedContacts.add(userId);
      }
    });
  }

  Future<void> _sendToContacts() async {
    if (_selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one contact'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      // Get file info
      final int fileSize;
      final String fileName;
      if (kIsWeb) {
        fileSize = 0;
        fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.webm';
      } else {
        final file = File(widget.recordingPath);
        fileSize = await file.length();
        fileName = file.path.split('/').last;
      }

      // Get audio duration from the recording provider
      final voiceState = ref.read(voiceRecordingProvider);
      final durationSeconds = voiceState.recordingDuration.inSeconds;

      int successCount = 0;
      int failCount = 0;

      // Upload the audio file once to S3, then send to all recipients
      String? uploadedFileUrl;

      // Send to each selected contact
      for (final userId in _selectedContacts) {
        try {
          // Get or create conversation with this user
          final conversationId = await ref
              .read(messagingRepositoryProvider)
              .getOrCreateConversation(userId);

          // For the first contact, use uploadAndSendAudioMessage which uploads to S3
          // For subsequent contacts, reuse the uploaded URL
          if (uploadedFileUrl == null) {
            // First recipient - upload and send
            final message = await ref
                .read(messagingRepositoryProvider)
                .uploadAndSendAudioMessage(
                  conversationId: conversationId,
                  localFilePath: widget.recordingPath,
                  durationSeconds: durationSeconds,
                );
            // Store the uploaded URL for subsequent recipients
            uploadedFileUrl = message.fileUrl;
          } else {
            // Subsequent recipients - just send with the already uploaded URL
            await ref
                .read(messagingRepositoryProvider)
                .sendAudioMessage(
                  conversationId: conversationId,
                  fileUrl: uploadedFileUrl,
                  durationSeconds: durationSeconds,
                  fileName: fileName,
                  fileSize: fileSize,
                );
          }

          // If we get here, it succeeded (method throws on failure)
          successCount++;
        } catch (e) {
          debugPrint('Error sending audio to $userId: $e');
          failCount++;
        }
      }

      // Get conversation ID before popping context
      String? lastConversationId;
      if (_selectedContacts.length == 1 && successCount == 1) {
        final userId = _selectedContacts.first;
        lastConversationId = await ref
            .read(messagingRepositoryProvider)
            .getOrCreateConversation(userId);
      }

      if (mounted) {
        // Refresh conversations list to show the new messages
        ref.read(conversationsProvider.notifier).loadConversations();

        Navigator.of(context).pop();

        // Navigate to the last conversation if only one contact selected
        if (lastConversationId != null) {
          context.push('/chat/$lastConversationId');
        }

        // Show result message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successCount > 0
                  ? 'Voice sent to $successCount contact(s)${failCount > 0 ? ' ($failCount failed)' : ''}'
                  : 'Failed to send voice message',
            ),
            backgroundColor: successCount > 0 ? AppColors.success : AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send voice: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _deleteRecording() async {
    // Delete the recording file
    final service = ref.read(audioRecordingServiceProvider);
    await service.deleteRecording(widget.recordingPath);
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final networkState = ref.watch(networkProvider);
    final contacts = networkState.contacts.where((c) => c.status == ConnectionStatus.accepted).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Delete button
                IconButton(
                  onPressed: _deleteRecording,
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                ),

                const Expanded(
                  child: Text(
                    'Send To',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Send button
                TextButton(
                  onPressed: _selectedContacts.isEmpty || _isSending
                      ? null
                      : _sendToContacts,
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Text(
                          'Send (${_selectedContacts.length})',
                          style: TextStyle(
                            color: _selectedContacts.isEmpty
                                ? AppColors.textSecondary
                                : AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.divider),

          // Contacts list
          Expanded(
            child: networkState.isLoading && contacts.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : contacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No contacts yet',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          final isSelected = _selectedContacts.contains(contact.contactUserId);

                          return ListTile(
                            onTap: () => _toggleContact(contact.contactUserId),
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? AppColors.primary
                                  : AppColors.inputBackground,
                              backgroundImage: contact.avatarUrl != null
                                  ? NetworkImage(contact.avatarUrl!)
                                  : null,
                              child: contact.avatarUrl == null
                                  ? (isSelected
                                      ? const Icon(Icons.check, color: Colors.black)
                                      : Text(
                                          contact.initials,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ))
                                  : null,
                            ),
                            title: Text(
                              contact.fullName,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: contact.specialization != null
                                ? Text(
                                    contact.specialization!,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: AppColors.primary)
                                : Icon(
                                    Icons.circle_outlined,
                                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                                  ),
                          );
                        },
                      ),
          ),

          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

