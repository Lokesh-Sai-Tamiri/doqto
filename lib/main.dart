import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/services/security_service.dart';
import 'core/services/supabase_service.dart';
import 'core/widgets/auto_logout_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Supabase with Twilio Verify
    await SupabaseService.initialize();
    
    // Run Security Checks for HIPAA compliance
    final securityFailures = await SecurityService.runStartupChecks();
    if (securityFailures.isNotEmpty) {
      if (AppConfig.debugMode) {
        print('🔒 SECURITY WARNING: Device compromised!');
        for(var f in securityFailures) {
          print('🔒 $f');
        }
      }
      // Note: In a production environment, you would navigate to a hard "Access Denied" screen here.
    }
    
    if (AppConfig.debugMode) {
      print('🚀 HymnChat initialized successfully');
    }
  } catch (e) {
    if (AppConfig.debugMode) {
      print('❌ Initialization error: $e');
      print('⚠️ Make sure to configure Supabase credentials in app_config.dart');
    }
  }
  
  runApp(const ProviderScope(child: HymnChatApp()));
}

class HymnChatApp extends ConsumerWidget {
  const HymnChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return AutoLogoutWrapper(
      timeoutDuration: const Duration(minutes: 15),
      child: MaterialApp.router(
        title: 'Hymn Chat',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: router,
      ),
    );
  }
}
