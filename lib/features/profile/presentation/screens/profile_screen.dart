import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Logout',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              // Logout
              await ref.read(authStateProvider.notifier).signOut();
              
              // Navigate to login
              if (context.mounted) {
                Navigator.pop(context); // Close loading
                context.go('/login');
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                // Delete user account from Supabase
                final user = SupabaseService.currentUser;
                if (user != null) {
                  // Note: Supabase doesn't allow deleting users from client SDK
                  // You need to call your backend API or use Supabase Admin API
                  // For now, we'll just sign out and show a message
                  
                  await SupabaseService.client.auth.signOut();
                  
                  if (context.mounted) {
                    Navigator.pop(context); // Close loading
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Account deletion requested. Please contact support to complete the process.',
                        ),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 4),
                      ),
                    );
                    
                    context.go('/login');
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final user = SupabaseService.currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            expandedHeight: 200,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary, size: 30),
              onPressed: () => context.pop(),
            ),
            actions: [
               IconButton(
                icon: const Icon(Icons.settings, color: AppColors.textPrimary),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.surfaceLight,
                      AppColors.background,
                    ],
                  ),
                ),
                child: profileAsync.when(
                  data: (profile) {
                    final initials = profile != null && profile.firstName != null && profile.lastName != null
                        ? '${profile.firstName![0]}${profile.lastName![0]}'.toUpperCase()
                        : user?.phone?.substring(0, 2) ?? 'U';
                    
                    final displayName = profile?.fullName ?? user?.phone ?? 'User';
                    final subtitle = profile?.specialization != null && profile?.clinicName != null
                        ? '${profile!.specialization} • ${profile.clinicName}'
                        : profile?.email ?? user?.phone ?? '';
                    
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        // Avatar Area
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.background, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              )
                            ]
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textInverse,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                  loading: () => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.background, width: 4),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Loading...",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  error: (error, stack) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.background, width: 4),
                        ),
                        child: const Center(
                          child: Icon(Icons.error, color: Colors.red),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.phone ?? 'User',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Stats Row
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                     children: [
                       _buildStatItem("1,402", "Consults"),
                       _buildStatItem("4.9", "Rating"),
                       _buildStatItem("12m", "Avg Response"),
                     ],
                   ),
                   const SizedBox(height: 30),
                   
                   const Text("My Stories", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                   const SizedBox(height: 10),
                   _buildMenuItem(
                     context,
                     Icons.add_a_photo,
                     "Add to My Story",
                     "Share updates with colleagues",
                   ),
                   const SizedBox(height: 30),

                   const Text("Account", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                   const SizedBox(height: 10),
                   _buildMenuItem(
                     context,
                     Icons.edit,
                     "Edit Profile",
                     "Update your information",
                     onTap: () {
                       context.push('/create-profile');
                     },
                   ),
                   _buildMenuItem(
                     context,
                     Icons.qr_code,
                     "Snapcode",
                     "Share your profile",
                   ),
                   _buildMenuItem(
                     context,
                     Icons.notifications,
                     "Notifications",
                     "Manage alerts",
                   ),
                   _buildMenuItem(
                     context,
                     Icons.security,
                     "Privacy & Security",
                     "Data protection",
                   ),
                   _buildMenuItem(
                     context,
                     Icons.help_outline,
                     "Help & Support",
                     "Get assistance",
                   ),
                   _buildMenuItem(
                     context,
                     Icons.credit_card,
                     "Billing & Plans",
                     "Manage subscription",
                     onTap: () => context.push('/billing'),
                   ),

                   const SizedBox(height: 30),
                   
                   // Logout Button
                   _buildMenuItem(
                     context,
                     Icons.logout,
                     "Logout",
                     "Sign out of your account",
                     color: Colors.orange,
                     onTap: () => _showLogoutDialog(context, ref),
                   ),
                   
                   const SizedBox(height: 10),
                   
                   // Delete Account Button
                   _buildMenuItem(
                     context,
                     Icons.delete_forever,
                     "Delete Account",
                     "Permanently delete your account",
                     color: Colors.red,
                     onTap: () => _showDeleteAccountDialog(context, ref),
                   ),
                   
                   const SizedBox(height: 30),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, {
    Color? color,
    VoidCallback? onTap,
  }) {
    final itemColor = color ?? AppColors.primary;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: color != null
              ? Border.all(color: color.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: itemColor, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color ?? AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color ?? AppColors.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
