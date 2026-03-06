import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../chat/presentation/screens/chat_list_screen.dart';
import '../../../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../../../features/organization/presentation/screens/organization_screen.dart';
import '../../../../features/ai/presentation/screens/inara_ai_screen.dart';
import '../../../../features/ai/presentation/widgets/animated_ai_icon.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../voice/presentation/widgets/voice_record_button.dart';
import '../../../voice/presentation/providers/voice_recording_provider.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;
  int _previousIndex = 0;
  PageController? _pageController;
  bool _isCheckingProfile = true;
  bool _hasCheckedProfile = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    
    // Check profile status after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfileAndRedirect();
    });
  }
  
  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _checkProfileAndRedirect() async {
    if (_hasCheckedProfile) return;
    _hasCheckedProfile = true;

    try {
      final hasProfile = await ref.read(authStateProvider.notifier).hasCompletedProfile();
      
      if (AppConfig.debugMode) {
        print('🏠 MainScreen: Profile check result: $hasProfile');
      }

      if (!mounted) return;

      if (!hasProfile) {
        if (AppConfig.debugMode) {
          print('📝 MainScreen: No profile found, redirecting to create-profile');
        }
        context.go('/create-profile');
        return;
      }

      // Profile exists, show the home screen
      setState(() {
        _isCheckingProfile = false;
      });
      
      // Request microphone permission immediately after showing home screen
      _requestMicrophonePermission();
    } catch (e) {
      if (AppConfig.debugMode) {
        print('⚠️ MainScreen: Error checking profile: $e');
      }
      // On error, redirect to create profile to be safe
      if (mounted) {
        context.go('/create-profile');
      }
    }
  }
  
  Future<void> _requestMicrophonePermission() async {
    // Request microphone permission as soon as home screen loads
    final voiceNotifier = ref.read(voiceRecordingProvider.notifier);
    final granted = await voiceNotifier.requestPermission();
    
    if (AppConfig.debugMode) {
      print('🎤 Microphone permission on home screen: $granted');
    }
  }

  void _onTabTapped(int index) {
    _pageController?.jumpToPage(index);
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      setState(() {
        _previousIndex = _currentIndex;
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure controller is initialized (handle hot reload case)
    _pageController ??= PageController(initialPage: _currentIndex);

    // Define screens here to ensure hot reload works correctly
    final List<Widget> screens = [
      ChatListScreen(),
      const OrganizationScreen(),
      const ContactsScreen(),
      InaraAIScreen(
        onBackPressed: () => _onTabTapped(_previousIndex),
      ),
    ];

    // Show loading while checking profile
    if (_isCheckingProfile) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Main Content
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(), // Better feel on iOS/Android
            children: screens,
          ),

          // Create Group FAB (only on Chats tab)
          if (_currentIndex == 0)
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 180,
              child: FloatingActionButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  context.push('/create-group');
                },
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.group_add, color: AppColors.textInverse),
              ),
            ),

          // Custom Bottom Bar (Hidden when on AI Tab)
          if (_currentIndex != 3)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 10,
                  bottom: MediaQuery.of(context).padding.bottom + 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.95),
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.0),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Voice Record Button
                    const VoiceRecordButton(),
                    
                    const SizedBox(height: 16),
                    
                    // Navigation icons row
                    Row(
                      children: [
                        // Left Side (Chats, Org)
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildNavItem(
                                icon: Icons.chat_bubble_rounded,
                                label: 'Chats',
                                isSelected: _currentIndex == 0,
                                onTap: () => _onTabTapped(0),
                              ),
                              _buildNavItem(
                                icon: Icons.business_rounded,
                                label: 'Organization',
                                isSelected: _currentIndex == 1,
                                onTap: () => _onTabTapped(1),
                              ),
                            ],
                          ),
                        ),

                        // Center Spacer for Record Button
                        const SizedBox(width: 80),

                        // Right Side (Contacts, AI)
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildNavItem(
                                icon: Icons.people_alt_rounded,
                                label: 'Contacts',
                                isSelected: _currentIndex == 2,
                                onTap: () => _onTabTapped(2),
                              ),
                              
                              // Custom AI Item
                              GestureDetector(
                                onTap: () => _onTabTapped(3),
                                behavior: HitTestBehavior.opaque,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedAIIcon(isSelected: _currentIndex == 3),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Inara AI',
                                      style: TextStyle(
                                        color: _currentIndex == 3 ? AppColors.textPrimary : AppColors.textSecondary,
                                        fontSize: 11,
                                        fontWeight: _currentIndex == 3 ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
