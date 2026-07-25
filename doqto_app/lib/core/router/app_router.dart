import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/organization.dart';
import '../../state/auth_state.dart';
import '../../ui/screens/auth/otp_screen.dart';
import '../../ui/screens/auth/phone_screen.dart';
import '../../ui/screens/auth/registration_screen.dart';
import '../../ui/screens/chat/chat_details_screen.dart';
import '../../ui/screens/chat/chat_list_screen.dart';
import '../../ui/screens/chat/chat_thread_screen.dart';
import '../../ui/screens/chat/create_group_screen.dart';
import '../../ui/screens/groups/groups_tab_screen.dart';
import '../../ui/screens/home/main_shell.dart';
import '../../ui/screens/my_org/my_org_screen.dart';
import '../../ui/screens/network/connections_screen.dart';
import '../../ui/screens/network/invitations_screen.dart';
import '../../ui/screens/network/network_tab_screen.dart';
import '../../ui/screens/org/create_org_screen.dart';
import '../../ui/screens/org/join_org_screen.dart';
import '../../ui/screens/org/org_selection_screen.dart';
import '../../ui/screens/org/pending_verification_screen.dart';
import '../../ui/screens/people/people_search_screen.dart';
import '../../ui/screens/people/person_profile_screen.dart';
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
  // Networking (M2). Network branch of the shell.
  static const network = '/network';
  static const networkInvitations = '/network/invitations';
  static const networkConnections = '/network/connections';
  // People search (M3) — pushed full-screen over the shell.
  static const peopleSearch = '/people/search';
  // Groups branch placeholder (real content is M5).
  static const groups = '/groups';
  static const settings = '/settings';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static const record = '/record';
  // Addressable person profile by user id (networking M1). Root-level route;
  // the shell retrofit that moves it into a branch is the next pass.
  static String person(String userId) => '/people/$userId';
}

/// Re-evaluates redirects whenever AuthStage changes.
Listenable _authListenable(Ref ref) {
  final notifier = ValueNotifier<AuthStage>(ref.read(authProvider).stage);
  ref.listen(authProvider.select((s) => s.stage), (_, next) => notifier.value = next);
  return notifier;
}

/// Root navigator — auth/org/splash + full-screen pushes (profile, settings,
/// record, person profile, people search) live here, ABOVE the tab shell.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _chatsNavKey = GlobalKey<NavigatorState>(debugLabel: 'branch-chats');
final _networkNavKey = GlobalKey<NavigatorState>(debugLabel: 'branch-network');
final _groupsNavKey = GlobalKey<NavigatorState>(debugLabel: 'branch-groups');
final _myOrgNavKey = GlobalKey<NavigatorState>(debugLabel: 'branch-myorg');

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    routes: [
      // --- Pre-shell flows (full-screen, root navigator) ---
      GoRoute(
        path: AppRoutes.splash,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.phone,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => const PhoneScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => OtpScreen(phone: state.extra as String),
      ),
      GoRoute(
        path: AppRoutes.registration,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => const RegistrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.orgSelection,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => const OrgSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.createOrg,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => const CreateOrgScreen(),
      ),
      GoRoute(
        path: AppRoutes.joinOrg,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => const JoinOrgScreen(),
      ),
      GoRoute(
        path: AppRoutes.pending,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => const PendingVerificationScreen(),
      ),

      // --- The 4-tab shell (indexed stack, per-branch state preserved) ---
      StatefulShellRoute.indexedStack(
        builder: (_, s, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          // Branch 0 — Chats. The chat thread lives INSIDE this branch so a
          // tab hop preserves the open conversation. More specific
          // `/chat/:id/details` precedes `/chat/:id`.
          StatefulShellBranch(
            navigatorKey: _chatsNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.chats,
                builder: (_, s) => const ChatListScreen(),
              ),
              GoRoute(
                path: AppRoutes.createGroup,
                builder: (_, s) => const CreateGroupScreen(),
              ),
              GoRoute(
                path: '/chat/:id/details',
                builder: (_, state) =>
                    ChatDetailsScreen(conversationId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: '/chat/:id',
                builder: (_, state) =>
                    ChatThreadScreen(conversationId: state.pathParameters['id']!),
              ),
            ],
          ),
          // Branch 1 — Network.
          StatefulShellBranch(
            navigatorKey: _networkNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.network,
                builder: (_, s) => const NetworkTabScreen(),
              ),
              GoRoute(
                path: AppRoutes.networkInvitations,
                builder: (_, s) => const InvitationsScreen(),
              ),
              GoRoute(
                path: AppRoutes.networkConnections,
                builder: (_, s) => const ConnectionsScreen(),
              ),
            ],
          ),
          // Branch 2 — Groups (placeholder; real content is M5).
          StatefulShellBranch(
            navigatorKey: _groupsNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.groups,
                builder: (_, s) => const GroupsTabScreen(),
              ),
            ],
          ),
          // Branch 3 — My Org.
          StatefulShellBranch(
            navigatorKey: _myOrgNavKey,
            routes: [
              GoRoute(
                path: AppRoutes.myOrg,
                builder: (_, s) => const MyOrgScreen(),
              ),
            ],
          ),
        ],
      ),

      // --- Full-screen pushes OVER the shell (root navigator) ---
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => ProfileScreen(member: state.extra as OrgMember?),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: AppRoutes.record,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => const VoiceBroadcastScreen(),
      ),
      // `/people/search` MUST precede `/people/:userId` — the colon segment
      // would otherwise swallow "search".
      GoRoute(
        path: AppRoutes.peopleSearch,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => const PeopleSearchScreen(),
      ),
      GoRoute(
        path: '/people/:userId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            PersonProfileScreen(userId: state.pathParameters['userId']!),
      ),
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
