import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/strings.dart';
import 'core/router/app_router.dart';
import 'core/theme.dart';
import 'data/services/chat_cache.dart';
import 'data/services/outbox.dart';
import 'state/chat_state.dart';
import 'state/notification_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<dynamic>(Outbox.boxName); // durable unsent messages
  await Hive.openBox<dynamic>(ChatCache.boxName); // offline read cache
  runApp(const ProviderScope(child: DoqtoApp()));
}

class DoqtoApp extends ConsumerWidget {
  const DoqtoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Activate WS → banner notifications for incoming messages.
    ref.watch(notificationListenerProvider);
    // Resend queued messages on start + every reconnect.
    ref.watch(outboxDrainerProvider);
    return MaterialApp.router(
      title: Strings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
