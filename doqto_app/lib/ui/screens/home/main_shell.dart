import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/motion.dart';
import '../../../core/tokens/typography.dart';

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
    return Container(
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
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: const Icon(Icons.mic_rounded, color: AppColors.white, size: 26),
        ),
      ),
    );
  }
}

class _FrostedNavBar extends StatelessWidget {
  final int index;
  const _FrostedNavBar({required this.index});

  @override
  Widget build(BuildContext context) {
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
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.medBlue : AppColors.gray400;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.medBlueLight : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isSelected ? activeIcon : icon, color: color, size: 23),
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
