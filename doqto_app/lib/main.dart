import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/strings.dart';
import 'core/router/app_router.dart';
import 'core/theme.dart';
import 'state/notification_state.dart';

void main() {
  runApp(const ProviderScope(child: DoqtoApp()));
}

class DoqtoApp extends ConsumerWidget {
  const DoqtoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Activate WS → banner notifications for incoming messages.
    ref.watch(notificationListenerProvider);
    return MaterialApp.router(
      title: Strings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
