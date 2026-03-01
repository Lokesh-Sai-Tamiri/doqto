import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/profile/presentation/screens/create_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/chat_settings_screen.dart';
import '../../features/chat/presentation/screens/create_group_screen.dart';
import '../../features/chat/presentation/screens/group_info_screen.dart';
import '../../features/chat/presentation/screens/add_members_screen.dart';
import '../../features/chat/data/models/messaging_models.dart';
import '../../features/contacts/presentation/screens/contact_profile_screen.dart';
import '../../features/contacts/data/models/connection_model.dart';
import '../../features/home/presentation/screens/main_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../config/app_config.dart';
import '../../features/billing/presentation/screens/plans_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: AppConfig.debugMode,
    
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final currentPath = state.matchedLocation;
      
      // Auth flow pages - DON'T auto-redirect from these
      final isAuthFlowPage = currentPath == '/login' || 
                             currentPath == '/otp' ||
                             currentPath == '/create-profile';
      
      if (AppConfig.debugMode) {
        print('🔀 Router redirect: path=$currentPath, authenticated=$isAuthenticated');
      }
      
      // If not authenticated and trying to access protected routes
      if (!isAuthenticated && !isAuthFlowPage) {
        if (AppConfig.debugMode) {
          print('🚫 Not authenticated, redirecting to /login');
        }
        return '/login';
      }
      
      // If authenticated and on login page ONLY (not OTP or create-profile)
      // We ONLY redirect from /login - let other pages handle their own navigation
      if (isAuthenticated && currentPath == '/login') {
        if (AppConfig.debugMode) {
          print('✅ Authenticated on login page, redirecting to /home');
        }
        return '/home';
      }
      
      // For ALL other cases, don't redirect - let the page handle navigation
      return null;
    },
    
    routes: [
      // Auth routes
      GoRoute(
        path: '/login', 
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return OtpScreen(phoneNumber: extra?['phone'] ?? '');
        },
      ),
      GoRoute(
        path: '/create-profile',
        builder: (context, state) => const CreateProfileScreen(),
      ),
      
      // Main app routes
      GoRoute(
        path: '/home', 
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: '/profile', 
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>?;
          return ChatScreen(
            chatId: id,
            userName: extra?['userName'] ?? 'Chat',
            otherUserId: extra?['otherUserId'],
            isGroup: extra?['isGroup'] ?? false,
          );
        },
      ),
      GoRoute(
        path: '/create-group',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/group-info/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>?;
          return GroupInfoScreen(
            groupId: id,
            groupName: extra?['groupName'],
          );
        },
      ),
      GoRoute(
        path: '/add-members/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>?;
          final existingMembers = extra?['existingMembers'];
          return AddMembersScreen(
            groupId: id,
            existingMembers: existingMembers is List<ParticipantInfo>
                ? existingMembers
                : null,
          );
        },
      ),
      GoRoute(
        path: '/chat-settings/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>?;
          return ChatSettingsScreen(
            chatId: id,
            userName: extra?['userName'] ?? 'User',
            otherUserId: extra?['otherUserId'],
          );
        },
      ),
      GoRoute(
        path: '/contact/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>?;
          
          ConnectionStatus? connectionStatus;
          if (extra != null && extra['connectionStatus'] != null) {
            final statusStr = extra['connectionStatus'];
            if (statusStr is String) { // Handle string from JSON/serialization
               try {
                 connectionStatus = ConnectionStatus.values.firstWhere(
                   (e) => e.name == statusStr,
                   orElse: () => ConnectionStatus.pending,
                 );
               } catch (_) {}
            } else if (statusStr is ConnectionStatus) { // Handle direct object (if supported)
               connectionStatus = statusStr;
            }
          }

          return ContactProfileScreen(
            userId: id,
            connectionId: extra?['connectionId'],
            connectionStatus: connectionStatus,
          );
        },
      ),
      GoRoute(
        path: '/billing',
        builder: (context, state) => const PlansScreen(),
      ),
    ],

    // DON'T use refreshListenable - it causes race conditions
    // Let each screen handle its own navigation
  );
});
