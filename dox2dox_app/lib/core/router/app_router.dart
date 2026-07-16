import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/user.dart';
import '../../state/auth_state.dart';
import '../../ui/screens/auth/otp_screen.dart';
import '../../ui/screens/auth/phone_screen.dart';
import '../../ui/screens/auth/registration_screen.dart';
import '../../ui/screens/chat/chat_details_screen.dart';
import '../../ui/screens/chat/chat_list_screen.dart';
import '../../ui/screens/chat/chat_thread_screen.dart';
import '../../ui/screens/chat/create_group_screen.dart';
import '../../ui/screens/home/main_shell.dart';
import '../../ui/screens/my_org/my_org_screen.dart';
import '../../ui/screens/org/create_org_screen.dart';
import '../../ui/screens/org/join_org_screen.dart';
import '../../ui/screens/org/org_selection_screen.dart';
import '../../ui/screens/org/pending_verification_screen.dart';
import '../../ui/screens/profile/profile_edit_screen.dart';
import '../../ui/screens/profile/profile_screen.dart';
import '../../ui/screens/settings/settings_screen.dart';
import '../../ui/screens/voice_broadcast/voice_broadcast_screen.dart';
import '../../ui/screens/splash/splash_screen.dart';

class AppRoutes {
  AppRoutes._();
  static const splash = '/';
  static const phone = '/auth/phone';
  static const otp = '/auth/otp';
  static const registration = '/auth/registration';
  static const orgSelection = '/org/select';
  static const createOrg = '/org/create';
  static const joinOrg = '/org/join';
  static const pending = '/org/pending';
  static const chats = '/chats';
  // Put NEW-group under a distinct prefix so it never collides with
  // `/chat/:id`. The colon segment of a UUID would otherwise happily
  // swallow "create-group".
  static const createGroup = '/new-group';
  static String chat(String convId) => '/chat/$convId';
  static String chatDetails(String convId) => '/chat/$convId/details';
  static const myOrg = '/my-org';
  static const settings = '/settings';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static const record = '/record';
}

/// Re-evaluates redirects whenever AuthStage changes.
Listenable _authListenable(Ref ref) {
  final notifier = ValueNotifier<AuthStage>(ref.read(authProvider).stage);
  ref.listen(authProvider.select((s) => s.stage), (_, next) => notifier.value = next);
  return notifier;
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.phone, builder: (_, __) => const PhoneScreen()),
      GoRoute(
        path: AppRoutes.otp,
        builder: (_, state) => OtpScreen(phone: state.extra as String),
      ),
      GoRoute(path: AppRoutes.registration, builder: (_, __) => const RegistrationScreen()),
      GoRoute(path: AppRoutes.orgSelection, builder: (_, __) => const OrgSelectionScreen()),
      GoRoute(path: AppRoutes.createOrg, builder: (_, __) => const CreateOrgScreen()),
      GoRoute(path: AppRoutes.joinOrg, builder: (_, __) => const JoinOrgScreen()),
      GoRoute(path: AppRoutes.pending, builder: (_, __) => const PendingVerificationScreen()),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(path: AppRoutes.chats, builder: (_, __) => const ChatListScreen()),
          GoRoute(path: AppRoutes.myOrg, builder: (_, __) => const MyOrgScreen()),
        ],
      ),
      // More specific routes MUST come before the generic /chats/:id matcher.
      GoRoute(path: AppRoutes.createGroup, builder: (_, __) => const CreateGroupScreen()),
      GoRoute(
        path: '/chat/:id/details',
        builder: (_, state) => ChatDetailsScreen(conversationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) => ChatThreadScreen(conversationId: state.pathParameters['id']!),
      ),
      GoRoute(path: AppRoutes.settings, builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, state) => ProfileScreen(user: state.extra as User?),
      ),
      GoRoute(path: AppRoutes.profileEdit, builder: (_, __) => const ProfileEditScreen()),
      GoRoute(path: AppRoutes.record, builder: (_, __) => const VoiceBroadcastScreen()),
    ],
    refreshListenable: _authListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      if (auth.stage == AuthStage.unknown) return null;
      final inAuthFlow = [
        AppRoutes.splash,
        AppRoutes.phone,
        AppRoutes.otp,
        AppRoutes.registration,
      ].contains(loc);
      final inOrgFlow = [
        AppRoutes.orgSelection,
        AppRoutes.createOrg,
        AppRoutes.joinOrg,
        AppRoutes.pending,
      ].contains(loc);
      if (auth.stage == AuthStage.signedOut && !inAuthFlow) return AppRoutes.phone;
      if (auth.stage == AuthStage.needsRegistration && loc != AppRoutes.registration) {
        return AppRoutes.registration;
      }
      if (auth.stage == AuthStage.needsOrg && !inOrgFlow) {
        return AppRoutes.orgSelection;
      }
      if (auth.stage == AuthStage.pendingVerification && loc != AppRoutes.pending) {
        return AppRoutes.pending;
      }
      // Signed-in user shouldn't be stuck on the pending screen or any of the
      // pre-auth / org-onboarding flows. Push them to chats.
      if (auth.stage == AuthStage.signedIn && (inAuthFlow || inOrgFlow)) {
        return AppRoutes.chats;
      }
      return null;
    },
  );
});
