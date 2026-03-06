/// ============================================================================
/// ORGANIZATION SCREEN - HIPAA Compliant
/// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gradient_app_bar.dart';
import '../../data/models/organization_model.dart';
import '../providers/organization_provider.dart';

class OrganizationScreen extends ConsumerStatefulWidget {
  const OrganizationScreen({super.key});

  @override
  ConsumerState<OrganizationScreen> createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends ConsumerState<OrganizationScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    final orgState = ref.read(myOrganizationsProvider);
    
    if (orgState.selectedOrganization != null) {
      ref.read(colleaguesProvider.notifier).searchColleagues(query);
    }
  }

  Future<void> _refreshAll() async {
    await ref.read(myOrganizationsProvider.notifier).loadOrganizations();
    
    final orgState = ref.read(myOrganizationsProvider);
    if (orgState.selectedOrganization != null) {
      await Future.wait([
        ref.read(colleaguesProvider.notifier)
            .loadColleagues(orgState.selectedOrganization!.organizationId),
        ref.read(departmentsProvider.notifier)
            .loadDepartments(orgState.selectedOrganization!.organizationId),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgState = ref.watch(myOrganizationsProvider);
    final colleaguesState = ref.watch(colleaguesProvider);
    final invitesState = ref.watch(invitesProvider);

    // Load colleagues when org is selected
    ref.listen<MyOrganizationsState>(myOrganizationsProvider, (previous, next) {
      if (next.selectedOrganization != null &&
          next.selectedOrganization?.organizationId !=
              previous?.selectedOrganization?.organizationId) {
        ref.read(colleaguesProvider.notifier)
            .loadColleagues(next.selectedOrganization!.organizationId);
        ref.read(departmentsProvider.notifier)
            .loadDepartments(next.selectedOrganization!.organizationId);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Gradient App Bar
          GradientAppBar(
            title: 'Organization',
            subtitle: orgState.selectedOrganization != null
                ? '${orgState.selectedOrganization!.organizationName} • ${orgState.selectedOrganization!.location}'
                : null,
            trailing: _buildHeaderTrailing(orgState, invitesState),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search colleagues, departments...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  isDense: true,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Content
          Expanded(
            child: _buildContent(orgState, colleaguesState),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTrailing(MyOrganizationsState orgState, InvitesState invitesState) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pending invites badge
        if (invitesState.count > 0)
          GestureDetector(
            onTap: () => _showPendingInvites(invitesState.pendingInvites),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mail, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${invitesState.count}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Organization switcher/manager (show if user has any organizations)
        if (orgState.organizations.isNotEmpty) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showOrganizationSwitcher(orgState.organizations),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                orgState.organizations.length > 1 ? Icons.swap_horiz : Icons.business,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
        
        // Add/Join organization - only show if user has NO active organizations
        if (orgState.organizations.isEmpty) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showAddOrganizationOptions,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, size: 18, color: AppColors.textSecondary),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContent(MyOrganizationsState orgState, ColleaguesState colleaguesState) {
    if (orgState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (orgState.errorMessage != null) {
      return _buildErrorState(orgState.errorMessage!, () {
        ref.read(myOrganizationsProvider.notifier).loadOrganizations();
      });
    }

    // No organizations - show empty state with join/create options
    if (orgState.organizations.isEmpty) {
      return _buildNoOrganizationState();
    }

    // Has organization - show colleagues
    if (colleaguesState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (colleaguesState.errorMessage != null) {
      return _buildErrorState(colleaguesState.errorMessage!, () {
        if (orgState.selectedOrganization != null) {
          ref.read(colleaguesProvider.notifier)
              .loadColleagues(orgState.selectedOrganization!.organizationId);
        }
      });
    }

    if (colleaguesState.colleagues.isEmpty) {
      return _buildEmptyColleaguesState(orgState.selectedOrganization!);
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: colleaguesState.byDepartment.length,
        itemBuilder: (context, index) {
          final deptName = colleaguesState.byDepartment.keys.elementAt(index);
          final members = colleaguesState.byDepartment[deptName]!;
          return _buildDepartmentSection(deptName, members);
        },
      ),
    );
  }

  Widget _buildNoOrganizationState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.business_outlined,
                size: 64,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Organization Yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Join your hospital or clinic to connect with colleagues',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _showJoinByCodeDialog,
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Join with Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textInverse,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _showCreateOrganizationDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Create New'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyColleaguesState(MyOrganizationModel org) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Colleagues Yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Invite your colleagues to join the organization',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            if (org.isAdmin) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showInviteDialog(org),
                icon: const Icon(Icons.person_add),
                label: const Text('Invite Colleagues'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textInverse,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textInverse,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentSection(String? deptName, List<ColleagueModel> members) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
          child: Text(
            (deptName ?? 'Unassigned').toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        ...members.map((member) => _buildMemberCard(member)),
      ],
    );
  }

  Widget _buildMemberCard(ColleagueModel member) {
    final currentUserId = SupabaseService.client.auth.currentUser?.id;
    final isCurrentUser = member.userId == currentUserId;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (isCurrentUser) {
          context.push('/profile');
        } else {
          context.push('/contact/${member.userId}');
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: member.departmentColor != null
                          ? _parseColor(member.departmentColor!).withOpacity(0.2)
                          : AppColors.inputBackground,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: member.avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              member.avatarUrl!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Text(
                                member.initials,
                                style: TextStyle(
                                  color: member.departmentColor != null
                                      ? _parseColor(member.departmentColor!)
                                      : AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            member.initials,
                            style: TextStyle(
                              color: member.departmentColor != null
                                  ? _parseColor(member.departmentColor!)
                                  : AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                  ),
                  // Online indicator (placeholder - would need real presence)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        border: Border.all(color: AppColors.surface, width: 2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.roleDisplay,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (member.specialization != null)
                      Text(
                        member.specialization!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),

              // Actions - only show chat button for other users
              if (!isCurrentUser)
                IconButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.push(
                      '/chat/${member.userId}',
                      extra: {
                        'userName': member.fullName,
                        'otherUserId': member.userId,
                      },
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              else
                // Show "You" badge for current user
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'You',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return AppColors.primary;
    }
  }

  // ============================================================================
  // DIALOGS
  // ============================================================================

  void _showAddOrganizationOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.qr_code, color: AppColors.primary),
              title: const Text('Join with Invite Code', style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text('Enter a code from your organization', style: TextStyle(color: AppColors.textSecondary)),
              onTap: () {
                Navigator.pop(context);
                _showJoinByCodeDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_business, color: AppColors.primary),
              title: const Text('Create Organization', style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text('Start a new organization', style: TextStyle(color: AppColors.textSecondary)),
              onTap: () {
                Navigator.pop(context);
                _showCreateOrganizationDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showJoinByCodeDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Join Organization', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the invite code you received',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              style: const TextStyle(color: AppColors.textPrimary),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Enter code',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  if (codeController.text.isEmpty) return;

                  Navigator.pop(context);

                  final result = await ref
                      .read(myOrganizationsProvider.notifier)
                      .joinByCode(codeController.text.trim());

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result != null
                              ? 'Successfully joined organization!'
                              : 'Invalid or expired invite code',
                        ),
                        backgroundColor: result != null ? AppColors.success : AppColors.error,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textInverse,
                ),
                child: const Text('Join'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateOrganizationDialog() {
    final nameController = TextEditingController();
    final cityController = TextEditingController();
    String selectedType = 'hospital';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Create Organization', style: TextStyle(color: AppColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Organization Name',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Type',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'hospital', child: Text('Hospital')),
                    DropdownMenuItem(value: 'clinic', child: Text('Clinic')),
                    DropdownMenuItem(value: 'practice', child: Text('Practice')),
                    DropdownMenuItem(value: 'network', child: Text('Network')),
                  ],
                  onChanged: (value) => setState(() => selectedType = value!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: cityController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'City (Optional)',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty) return;

                    Navigator.pop(context);

                    final result = await ref
                        .read(myOrganizationsProvider.notifier)
                        .createOrganization(
                          name: nameController.text.trim(),
                          type: OrganizationType.values.firstWhere(
                            (t) => t.name == selectedType,
                            orElse: () => OrganizationType.hospital,
                          ),
                          city: cityController.text.isNotEmpty ? cityController.text.trim() : null,
                        );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result != null
                                ? 'Organization created!'
                                : 'Failed to create organization',
                          ),
                          backgroundColor: result != null ? AppColors.success : AppColors.error,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textInverse,
                  ),
                  child: const Text('Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOrganizationSwitcher(List<MyOrganizationModel> orgs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              orgs.length > 1 ? 'Your Organizations' : 'Organization',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...orgs.map((org) => ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.business, color: AppColors.primary),
              ),
              title: Text(
                org.organizationName,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                '${org.roleDisplay} • ${org.memberCount} members',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ref.read(myOrganizationsProvider).selectedOrganization?.organizationId ==
                      org.organizationId)
                    const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  // More options menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                    color: AppColors.surface,
                    onSelected: (value) {
                      Navigator.pop(context);
                      if (value == 'leave') {
                        _showLeaveConfirmation(org);
                      } else if (value == 'invite' && org.isAdmin) {
                        _showInviteDialog(org);
                      }
                    },
                    itemBuilder: (context) => [
                      if (org.isAdmin)
                        const PopupMenuItem(
                          value: 'invite',
                          child: Row(
                            children: [
                              Icon(Icons.person_add, size: 18, color: AppColors.textSecondary),
                              SizedBox(width: 8),
                              Text('Invite Members', style: TextStyle(color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'leave',
                        child: Row(
                          children: [
                            Icon(Icons.logout, size: 18, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Leave Organization', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              onTap: () {
                Navigator.pop(context);
                ref.read(myOrganizationsProvider.notifier).selectOrganization(org);
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showLeaveConfirmation(MyOrganizationModel org) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Leave Organization?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Are you sure you want to leave ${org.organizationName}? You will need a new invite to rejoin.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  
                  final success = await ref
                      .read(myOrganizationsProvider.notifier)
                      .leaveOrganization(org.organizationId);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Left ${org.organizationName}'
                              : 'Failed to leave organization',
                        ),
                        backgroundColor: success ? AppColors.success : AppColors.error,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Leave'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPendingInvites(List<OrganizationInviteModel> invites) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Organization Invites',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: invites.length,
                itemBuilder: (context, index) {
                  final invite = invites[index];
                  return _buildInviteCard(invite);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCard(OrganizationInviteModel invite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.business, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.organizationName ?? 'Unknown Organization',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (invite.inviterName != null) ...[
            const SizedBox(height: 8),
            Text(
              'Invited by ${invite.inviterName}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Could add decline functionality
                  },
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final result = await ref
                        .read(myOrganizationsProvider.notifier)
                        .joinByCode(invite.inviteCode);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result != null
                                ? 'Joined ${invite.organizationName ?? 'organization'}!'
                                : 'Failed to join organization',
                          ),
                          backgroundColor: result != null ? AppColors.success : AppColors.error,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textInverse,
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(MyOrganizationModel org) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Invite Colleagues', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Generate an invite code to share with your colleagues.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);

                  final code = await ref
                      .read(invitesProvider.notifier)
                      .createInvite(organizationId: org.organizationId);

                  if (code != null && mounted) {
                    _showInviteCodeDialog(code);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textInverse,
                ),
                child: const Text('Invite'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInviteCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Invite Code', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this code with your colleagues:',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                code.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Valid for 7 days',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code.toUpperCase()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied to clipboard')),
                  );
                },
                child: const Text('Copy Code'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textInverse,
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
