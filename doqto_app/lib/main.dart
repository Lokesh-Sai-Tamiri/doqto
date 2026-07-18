import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/constants/strings.dart';
import 'core/di/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme.dart';
import 'data/local/box_key_storage.dart';
import 'data/services/chat_cache.dart';
import 'data/services/outbox.dart';
import 'state/auth_state.dart';
import 'state/chat_state.dart';
import 'state/notification_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // M6: fail fast at launch — a release build must never talk cleartext.
  if (kReleaseMode &&
      (!AppConstants.apiBaseUrl.startsWith('https://') ||
          !AppConstants.wsBaseUrl.startsWith('wss://'))) {
    throw StateError(
      'Release builds require https:// API_BASE_URL and wss:// WS_BASE_URL.',
    );
  }
  await Hive.initFlutter();
  // H1: boxes hold PHI (message text, transcripts, cached history) — AES-256
  // encrypted with a key kept in the platform keychain/keystore.
  final cipher = HiveAesCipher(await BoxKeyStorage().getOrCreateKey());
  await _openEncryptedBox(Outbox.boxName, cipher); // durable unsent messages
  await _openEncryptedBox(ChatCache.boxName, cipher); // offline read cache
  runApp(const ProviderScope(child: DoqtoApp()));
}

/// Opens [name] encrypted; a pre-encryption plaintext box (or a corrupt one)
/// fails to open, so delete it and start fresh — the cache refetches and a
/// one-time loss of queued outbox entries is accepted (see remediation plan).
Future<void> _openEncryptedBox(String name, HiveAesCipher cipher) async {
  try {
    await Hive.openBox<dynamic>(name, encryptionCipher: cipher);
  } catch (_) {
    await Hive.deleteBoxFromDisk(name);
    await Hive.openBox<dynamic>(name, encryptionCipher: cipher);
  }
}

class DoqtoApp extends ConsumerStatefulWidget {
  const DoqtoApp({super.key});

  @override
  ConsumerState<DoqtoApp> createState() => _DoqtoAppState();
}

class _DoqtoAppState extends ConsumerState<DoqtoApp>
    with WidgetsBindingObserver {
  /// H5a: when the app left the foreground (earliest of inactive/paused/hidden).
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now(); // keep the earliest timestamp
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final away = _backgroundedAt == null
        ? Duration.zero
        : DateTime.now().difference(_backgroundedAt!);
    _backgroundedAt = null;
    // H5a: automatic logoff — away too long forces sign-out, which also
    // wipes cached PHI (H2). Router redirect lands on the login screen.
    if (away > AppConstants.sessionIdleTimeout &&
        ref.read(authProvider).stage == AuthStage.signedIn) {
      ref.read(authProvider.notifier).signOut();
      return;
    }
    // Resume = instant reconnect (skipping any pending backoff). The
    // WsConnState.connected stream then drives conversation refresh, message
    // catch-up, and outbox drain. Nothing on pause — the server's idle
    // deadline reaps dead sockets, so brief app-switches survive.
    ref.read(websocketClientProvider).ensureConnected();
  }

  @override
  Widget build(BuildContext context) {
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
