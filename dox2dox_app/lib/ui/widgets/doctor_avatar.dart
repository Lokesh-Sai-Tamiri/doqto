import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/tokens/colors.dart';

enum AvatarSize { sm, md, lg, xl, xxl }

class DoctorAvatar extends StatelessWidget {
  final String initials;
  final int colorIndex;
  final AvatarSize size;
  final PresenceStatusDot? presence;
  final String? imageUrl;

  const DoctorAvatar({
    super.key,
    required this.initials,
    this.colorIndex = 0,
    this.size = AvatarSize.lg,
    this.presence,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final dim = switch (size) {
      AvatarSize.xxl => 104.0,
      AvatarSize.xl => 52.0,
      AvatarSize.lg => 44.0,
      AvatarSize.md => 36.0,
      AvatarSize.sm => 28.0,
    };
    final fontSize = switch (size) {
      AvatarSize.xxl => 32.0,
      AvatarSize.xl => 16.0,
      AvatarSize.lg => 14.0,
      AvatarSize.md => 12.0,
      AvatarSize.sm => 10.0,
    };
    final bg = AppColors.avatarColorFor(colorIndex);
    final initialsWidget = Container(
      width: dim,
      height: dim,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        initials,
        style: GoogleFonts.sora(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
    );

    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final picture = hasImage
        ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: imageUrl!,
              width: dim,
              height: dim,
              fit: BoxFit.cover,
              placeholder: (ctx, url) => initialsWidget,
              errorWidget: (ctx, url, err) => initialsWidget,
              fadeInDuration: const Duration(milliseconds: 120),
            ),
          )
        : initialsWidget;

    return SizedBox(
      width: dim,
      height: dim,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          picture,
          if (presence != null)
            Positioned(bottom: -1, right: -1, child: presence!),
        ],
      ),
    );
  }
}

class PresenceStatusDot extends StatelessWidget {
  final Color color;
  const PresenceStatusDot({super.key, required this.color});

  factory PresenceStatusDot.online() => const PresenceStatusDot(color: AppColors.presenceOnline);
  factory PresenceStatusDot.away() => const PresenceStatusDot(color: AppColors.presenceAway);
  factory PresenceStatusDot.offline() => const PresenceStatusDot(color: AppColors.presenceOffline);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 2),
      ),
    );
  }
}
