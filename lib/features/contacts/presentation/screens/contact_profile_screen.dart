/// ============================================================================
/// CONTACT PROFILE SCREEN
/// ============================================================================
/// 
/// View another user's public profile information.
/// HIPAA compliant - only shows information the user has chosen to share.
/// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../data/models/connection_model.dart';
import '../providers/contacts_provider.dart';

/// Provider to fetch a specific user's profile
final contactProfileProvider = FutureProvider.family<ProfileModel?, String>((ref, userId) async {
  final repository = ProfileRepository();
  return repository.getProfile(userId);
});

class ContactProfileScreen extends ConsumerWidget {
  final String userId;
  final String? connectionId;
  final ConnectionStatus? connectionStatus;

  const ContactProfileScreen({
    super.key,
    required this.userId,
    this.connectionId,
    this.connectionStatus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(contactProfileProvider(userId));
    final suggestionsState = ref.watch(suggestionsProvider);
    
    // Check if we've sent a pending request to this user
    final isPending = suggestionsState.pendingRequestIds.contains(userId);
    final isConnected = connectionStatus == ConnectionStatus.accepted;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        data: (profile) => _buildProfileContent(context, ref, profile, isPending, isConnected),
        loading: () => _buildLoadingState(),
        error: (error, stack) => _buildErrorState(context, error),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load profile',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textInverse,
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    WidgetRef ref,
    ProfileModel? profile,
    bool isPending,
    bool isConnected,
  ) {
    if (profile == null) {
      return _buildErrorState(context, 'Profile not found');
    }

    final initials = profile.firstName != null && profile.lastName != null
        ? '${profile.firstName![0]}${profile.lastName![0]}'.toUpperCase()
        : '?';

    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          backgroundColor: AppColors.background,
          expandedHeight: 280,
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          actions: [
            if (isConnected)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                color: AppColors.surface,
                onSelected: (value) => _handleMenuAction(context, ref, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'message',
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                        SizedBox(width: 12),
                        Text('Message', style: TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.person_remove, color: AppColors.error),
                        SizedBox(width: 12),
                        Text('Remove Connection', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(Icons.block, color: AppColors.error),
                        SizedBox(width: 12),
                        Text('Block', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  // Avatar
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: profile.avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              profile.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textInverse,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textInverse,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    profile.fullName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Specialization & Clinic
                  if (profile.specialization != null || profile.clinicName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [profile.specialization, profile.clinicName]
                            .where((e) => e != null)
                            .join(' • '),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // Location
                  if (profile.city != null || profile.state != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            [profile.city, profile.state]
                                .where((e) => e != null)
                                .join(', '),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action Button
                _buildActionButton(context, ref, profile, isPending, isConnected),
                
                const SizedBox(height: 24),

                // Bio Section
                if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                  _buildSectionTitle('About'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      profile.bio!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Professional Details
                _buildSectionTitle('Professional Details'),
                const SizedBox(height: 8),
                _buildInfoCard([
                  if (profile.specialization != null)
                    _buildInfoRow(Icons.medical_services, 'Specialization', profile.specialization!),
                  if (profile.clinicName != null)
                    _buildInfoRow(Icons.business, 'Clinic/Hospital', profile.clinicName!),
                  if (profile.yearsOfExperience != null)
                    _buildInfoRow(Icons.timeline, 'Experience', '${profile.yearsOfExperience} years'),
                  if (profile.doctorId != null)
                    _buildInfoRow(Icons.badge, 'Doctor ID', profile.doctorId!),
                ]),

                const SizedBox(height: 24),

                // Contact Info (only for connected users)
                if (isConnected) ...[
                  _buildSectionTitle('Contact Information'),
                  const SizedBox(height: 8),
                  _buildInfoCard([
                    if (profile.email != null)
                      _buildInfoRow(Icons.email, 'Email', profile.email!, copyable: true),
                    if (profile.phone != null)
                      _buildInfoRow(Icons.phone, 'Phone', profile.phone!, copyable: true),
                    if (profile.fullAddress.isNotEmpty)
                      _buildInfoRow(Icons.location_on, 'Address', profile.fullAddress),
                  ]),
                  const SizedBox(height: 24),
                ],

                // Connection Status
                if (!isConnected && !isPending)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Connect with ${profile.firstName ?? 'this doctor'} to see their full contact information.',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref, ProfileModel? profile, bool isPending, bool isConnected) {
    if (isConnected) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                context.push(
                  '/chat/$userId',
                  extra: {
                    'userName': profile?.fullName ?? 'Chat',
                    'otherUserId': userId,
                  },
                );
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textInverse,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (isPending) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.hourglass_empty),
          label: const Text('Request Pending'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          HapticFeedback.mediumImpact();
          final success = await ref
              .read(suggestionsProvider.notifier)
              .sendConnectionRequest(userId);
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success ? 'Connection request sent!' : 'Failed to send request',
                ),
                backgroundColor: success ? AppColors.success : AppColors.error,
              ),
            );
          }
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Connect'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textInverse,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    final filteredChildren = children.where((c) => c is! SizedBox || (c).height != 0).toList();
    
    if (filteredChildren.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No information available',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: filteredChildren,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (copyable)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.copy, size: 18, color: AppColors.textSecondary),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'message':
        // Get profile for the name
        final profileAsync = ref.read(contactProfileProvider(userId));
        final profile = profileAsync.hasValue ? profileAsync.value : null;
        context.push(
          '/chat/$userId',
          extra: {
            'userName': profile?.fullName ?? 'Chat',
            'otherUserId': userId,
          },
        );
        break;
      case 'remove':
        if (connectionId != null) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text(
                'Remove Connection',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              content: const Text(
                'Are you sure you want to remove this connection?',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Remove'),
                ),
              ],
            ),
          );

          if (confirmed == true && context.mounted) {
            await ref.read(networkProvider.notifier).removeConnection(connectionId!);
            if (context.mounted) {
              context.pop();
            }
          }
        }
        break;
      case 'block':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              'Block User',
              style: TextStyle(color: AppColors.error),
            ),
            content: const Text(
              'Blocking this user will remove them from your network and prevent them from contacting you.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Block'),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          await ref.read(contactsRepositoryProvider).blockUser(userId);
          if (context.mounted) {
            context.pop();
          }
        }
        break;
    }
  }
}
