import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/motion.dart';
import '../../../core/tokens/radii.dart';
import '../../../core/tokens/typography.dart';
import '../../../state/chat_state.dart';
import '../../widgets/app_pressable.dart';

/// Total unread across all conversations — drives the badge on the Chats tab.
/// Derived read-only from the existing conversations provider.
final _totalUnreadProvider = Provider<int>((ref) {
  final convs = ref.watch(conversationsProvider).asData?.value;
  if (convs == null) return 0;
  return convs.fold<int>(0, (sum, c) => sum + c.unreadCount);
});

/// App shell: content runs edge-to-edge behind a floating frosted-glass nav
/// bar (2025 chrome — no solid slabs, no notched FAB cutout). The mic action
/// is a raised gradient button overlapping the bar.
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _indexForLocation(String location) {
    if (location.startsWith(AppRoutes.myOrg)) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexForLocation(location);
    return Scaffold(
      extendBody: true, // content scrolls behind the translucent bar
      body: child,
      floatingActionButton: _MicButton(
        onPressed: () => context.push(AppRoutes.record),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _FrostedNavBar(index: index),
    );
  }
}

/// Raised broadcast button: brand teal→navy gradient, floats over the bar.
class _MicButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _MicButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onPressed,
      haptic: true,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.medBlue, AppColors.medBlueDark],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.medBlueDark.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.mic_rounded, color: AppColors.white, size: 26),
      ),
    );
  }
}

class _FrostedNavBar extends ConsumerWidget {
  final int index;
  const _FrostedNavBar({required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalUnread = ref.watch(_totalUnreadProvider);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.82),
            border: Border(
              top: BorderSide(
                color: AppColors.gray200.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      activeIcon: Icons.chat_bubble_rounded,
                      label: Strings.tabChats,
                      isSelected: index == 0,
                      badgeCount: totalUnread,
                      onTap: () => context.go(AppRoutes.chats),
                    ),
                  ),
                  const SizedBox(width: 72), // clearance for the mic button
                  Expanded(
                    child: _NavItem(
                      icon: Icons.apartment_outlined,
                      activeIcon: Icons.apartment_rounded,
                      label: Strings.tabMyOrg,
                      isSelected: index == 1,
                      onTap: () => context.go(AppRoutes.myOrg),
                    ),
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.medBlue : AppColors.gray400;
    final duration = AppMotion.maybe(context, AppMotion.micro);
    return AppPressable(
      onTap: onTap,
      minTarget: true,
      child: Center(
        // Active pill: tint + label weight animate in place (never shifts
        // layout) so the current tab is unmistakable.
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.standard,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.medBlueLight : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(isSelected ? activeIcon : icon, color: color, size: 23),
                  // Unread badge — overlays the icon corner so it never
                  // shifts layout; scales in/out as the count crosses zero.
                  Positioned(
                    top: -5,
                    right: -10,
                    child: AnimatedScale(
                      scale: badgeCount > 0 ? 1.0 : 0.0,
                      duration: duration,
                      curve: AppMotion.standard,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 16),
                        decoration: BoxDecoration(
                          color: AppColors.medBlue,
                          borderRadius: AppRadii.rFull,
                          border:
                              Border.all(color: AppColors.white, width: 1.5),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: AppText.badge
                              .copyWith(color: AppColors.white, fontSize: 9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppText.button.copyWith(
                  fontSize: 10,
                  color: color,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
