import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/tokens/colors.dart';
import '../../../core/tokens/typography.dart';

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
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => context.go(i == 0 ? AppRoutes.chats : AppRoutes.myOrg),
        selectedItemColor: AppColors.medBlue,
        unselectedItemColor: AppColors.gray400,
        backgroundColor: AppColors.white,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: AppText.button.copyWith(fontSize: 12),
        unselectedLabelStyle: AppText.button.copyWith(fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: Strings.tabChats),
          BottomNavigationBarItem(icon: Icon(Icons.apartment), label: Strings.tabMyOrg),
        ],
      ),
    );
  }
}
