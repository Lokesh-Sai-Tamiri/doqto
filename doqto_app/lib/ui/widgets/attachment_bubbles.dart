import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/tokens/colors.dart';
import '../../core/tokens/radii.dart';
import '../../core/tokens/spacing.dart';
import '../../core/tokens/typography.dart';
import '../../data/models/message.dart';
import 'app_pressable.dart';
import 'message_bubble.dart';

/// Timestamp + status ticks row shared by attachment bubbles (mirrors
/// MessageBubble's footer).
class _BubbleFooter extends StatelessWidget {
  final bool isMine;
  final DateTime timestamp;
  final bool read;
  final bool delivered;
  final MessageStatus status;
  const _BubbleFooter({
    required this.isMine,
    required this.timestamp,
    required this.read,
    this.delivered = false,
    this.status = MessageStatus.sent,
  });

  @override
  Widget build(BuildContext context) {
    final timeColor =
        isMine ? AppColors.white.withValues(alpha: 0.55) : AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat.Hm().format(timestamp),
          style: AppText.timestamp.copyWith(color: timeColor),
        ),
        if (isMine) ...[
          const SizedBox(width: 3),
          MessageStatusTick(
            status: status,
            read: read,
            delivered: delivered,
            idleColor: AppColors.white.withValues(alpha: 0.55),
          ),
        ],
      ],
    );
  }
}

/// Photo message. Lazily resolves a presigned URL (same pattern as
/// VoiceNoteBubble) and renders the image; tap → full-screen viewer.
class ImageBubble extends StatefulWidget {
  final Future<String> Function() getFileUrl;
  final bool isMine;
  final DateTime timestamp;
  final bool read;
  final bool delivered;

  const ImageBubble({
    super.key,
    required this.getFileUrl,
    required this.isMine,
    required this.timestamp,
    this.read = false,
    this.delivered = false,
  });

  @override
  State<ImageBubble> createState() => _ImageBubbleState();
}

class _ImageBubbleState extends State<ImageBubble> {
  late final Future<String> _url = widget.getFileUrl();

  void _openViewer(String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Center(child: CachedNetworkImage(imageUrl: url)),
              ),
            ),
            Positioned(
              top: AppSpacing.lg,
              right: AppSpacing.md,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width * 0.65;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: widget.isMine ? AppColors.medBlue : AppColors.white,
        borderRadius:
            widget.isMine ? AppRadii.bubbleSent : AppRadii.bubbleReceived,
        border: widget.isMine ? null : Border.all(color: AppColors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FutureBuilder<String>(
              future: _url,
              builder: (context, snap) {
                if (snap.hasError) {
                  return SizedBox(
                    width: maxW - 8,
                    height: 120,
                    child: const Icon(Icons.broken_image_outlined,
                        color: Colors.grey),
                  );
                }
                if (!snap.hasData) {
                  return SizedBox(
                    width: maxW - 8,
                    height: 160,
                    child:
                        const Center(child: CircularProgressIndicator()),
                  );
                }
                final url = snap.data!;
                return AppPressable(
                  onTap: () => _openViewer(url),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    width: maxW - 8,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => SizedBox(
                      width: maxW - 8,
                      height: 160,
                      child:
                          const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, _, _) => const SizedBox(
                      height: 120,
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 3, 4, 2),
            child: _BubbleFooter(
              isMine: widget.isMine,
              timestamp: widget.timestamp,
              read: widget.read,
              delivered: widget.delivered,
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment:
            widget.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [bubble],
      ),
    );
  }
}

/// Outbox image still uploading (or failed): renders the on-disk file as a
/// real preview — same frame as [ImageBubble] — with a sending/failed tick.
class PendingImageBubble extends StatelessWidget {
  final String path;
  final bool isMine;
  final DateTime timestamp;
  final MessageStatus status;

  const PendingImageBubble({
    super.key,
    required this.path,
    required this.isMine,
    required this.timestamp,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width * 0.65;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isMine ? AppColors.medBlue : AppColors.white,
        borderRadius: isMine ? AppRadii.bubbleSent : AppRadii.bubbleReceived,
        border: isMine ? null : Border.all(color: AppColors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Opacity(
              opacity: status == MessageStatus.sending ? 0.7 : 1,
              child: Image.file(
                File(path),
                width: maxW - 8,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 120,
                  child:
                      Icon(Icons.broken_image_outlined, color: Colors.grey),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 3, 4, 2),
            child: _BubbleFooter(
              isMine: isMine,
              timestamp: timestamp,
              read: false,
              status: status,
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [bubble],
      ),
    );
  }
}

/// Document message: icon + name + size. Tap → open presigned URL externally.
/// A null [getFileUrl] means the file is still in the local outbox (uploading
/// or failed) — same card, status tick from [status], tap does nothing.
class FileBubble extends StatelessWidget {
  final Future<String> Function()? getFileUrl;
  final String fileName;
  final int? fileSizeBytes;
  final bool isMine;
  final DateTime timestamp;
  final bool read;
  final bool delivered;
  final MessageStatus status;

  const FileBubble({
    super.key,
    required this.getFileUrl,
    required this.fileName,
    this.fileSizeBytes,
    required this.isMine,
    required this.timestamp,
    this.read = false,
    this.delivered = false,
    this.status = MessageStatus.sent,
  });

  String get _sizeLabel {
    final b = fileSizeBytes;
    if (b == null) return '';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _open(BuildContext context) async {
    final resolve = getFileUrl;
    if (resolve == null) return;
    try {
      final url = await resolve();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the file')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = isMine ? AppColors.white : AppColors.textPrimary;
    final bubble = AppPressable(
      onTap: () => _open(context),
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: isMine ? AppColors.medBlue : AppColors.white,
          borderRadius: isMine ? AppRadii.bubbleSent : AppRadii.bubbleReceived,
          border: isMine ? null : Border.all(color: AppColors.gray100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file_outlined, color: fg, size: 30),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fileName,
                        style: AppText.messageBody.copyWith(color: fg),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_sizeLabel.isNotEmpty)
                        Text(
                          _sizeLabel,
                          style: AppText.timestamp.copyWith(
                            color: isMine
                                ? AppColors.white.withValues(alpha: 0.7)
                                : AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            _BubbleFooter(
                isMine: isMine,
                timestamp: timestamp,
                read: read,
                delivered: delivered,
                status: status),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [bubble],
      ),
    );
  }
}
