/// ============================================================================
/// ORGANIZATION PROVIDERS - Riverpod State Management
/// ============================================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/organization_model.dart';
import '../../data/repositories/organization_repository.dart';

// ============================================================================
// REPOSITORY PROVIDER
// ============================================================================

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepository();
});

// ============================================================================
// MY ORGANIZATIONS STATE
// ============================================================================

class MyOrganizationsState {
  final bool isLoading;
  final List<MyOrganizationModel> organizations;
  final MyOrganizationModel? selectedOrganization;
  final String? errorMessage;

  const MyOrganizationsState({
    this.isLoading = false,
    this.organizations = const [],
    this.selectedOrganization,
    this.errorMessage,
  });

  MyOrganizationsState copyWith({
    bool? isLoading,
    List<MyOrganizationModel>? organizations,
    MyOrganizationModel? selectedOrganization,
    String? errorMessage,
  }) {
    return MyOrganizationsState(
      isLoading: isLoading ?? this.isLoading,
      organizations: organizations ?? this.organizations,
      selectedOrganization: selectedOrganization ?? this.selectedOrganization,
      errorMessage: errorMessage,
    );
  }
}

class MyOrganizationsNotifier extends Notifier<MyOrganizationsState> {
  late final OrganizationRepository _repository;

  @override
  MyOrganizationsState build() {
    _repository = ref.watch(organizationRepositoryProvider);
    // Auto-load on build
    Future.microtask(() => loadOrganizations());
    return const MyOrganizationsState(isLoading: true);
  }

  Future<void> loadOrganizations() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final orgs = await _repository.getMyOrganizations();
      
      // Auto-select first organization if none selected
      MyOrganizationModel? selected = state.selectedOrganization;
      if (selected == null && orgs.isNotEmpty) {
        selected = orgs.first;
      } else if (selected != null) {
        // Re-fetch selected org data
        selected = orgs.firstWhere(
          (o) => o.organizationId == selected!.organizationId,
          orElse: () => orgs.isNotEmpty ? orgs.first : selected!,
        );
      }

      state = state.copyWith(
        isLoading: false,
        organizations: orgs,
        selectedOrganization: selected,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load organizations: ${e.toString()}',
      );
    }
  }

  void selectOrganization(MyOrganizationModel org) {
    state = state.copyWith(selectedOrganization: org);
    // Refresh colleagues when org changes
    ref.read(colleaguesProvider.notifier).loadColleagues(org.organizationId);
    ref.read(departmentsProvider.notifier).loadDepartments(org.organizationId);
  }

  Future<String?> createOrganization({
    required String name,
    OrganizationType type = OrganizationType.hospital,
    String? description,
    String? city,
    String? state,
  }) async {
    try {
      final org = await _repository.createOrganization(
        name: name,
        type: type,
        description: description,
        city: city,
        state: state,
      );

      // Refresh organizations list
      await loadOrganizations();

      return org.id;
    } catch (e) {
      this.state = this.state.copyWith(
        errorMessage: 'Failed to create organization: ${e.toString()}',
      );
      return null;
    }
  }

  Future<bool> leaveOrganization(String organizationId) async {
    try {
      final success = await _repository.leaveOrganization(organizationId);
      if (success) {
        // Clear selected if leaving current org
        if (state.selectedOrganization?.organizationId == organizationId) {
          state = state.copyWith(selectedOrganization: null);
        }
        await loadOrganizations();
      }
      return success;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to leave organization: ${e.toString()}',
      );
      return false;
    }
  }

  Future<String?> joinByCode(String inviteCode) async {
    try {
      final membership = await _repository.joinByInviteCode(inviteCode);
      await loadOrganizations();
      return membership.organizationId;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().contains('Invalid')
            ? 'Invalid or expired invite code'
            : 'Failed to join organization',
      );
      return null;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final myOrganizationsProvider =
    NotifierProvider<MyOrganizationsNotifier, MyOrganizationsState>(() {
  return MyOrganizationsNotifier();
});

// ============================================================================
// COLLEAGUES STATE
// ============================================================================

class ColleaguesState {
  final bool isLoading;
  final String? organizationId;
  final List<ColleagueModel> colleagues;
  final Map<String?, List<ColleagueModel>> byDepartment;
  final String? errorMessage;

  const ColleaguesState({
    this.isLoading = false,
    this.organizationId,
    this.colleagues = const [],
    this.byDepartment = const {},
    this.errorMessage,
  });

  ColleaguesState copyWith({
    bool? isLoading,
    String? organizationId,
    List<ColleagueModel>? colleagues,
    Map<String?, List<ColleagueModel>>? byDepartment,
    String? errorMessage,
  }) {
    return ColleaguesState(
      isLoading: isLoading ?? this.isLoading,
      organizationId: organizationId ?? this.organizationId,
      colleagues: colleagues ?? this.colleagues,
      byDepartment: byDepartment ?? this.byDepartment,
      errorMessage: errorMessage,
    );
  }
}

class ColleaguesNotifier extends Notifier<ColleaguesState> {
  late final OrganizationRepository _repository;

  @override
  ColleaguesState build() {
    _repository = ref.watch(organizationRepositoryProvider);
    return const ColleaguesState();
  }

  Future<void> loadColleagues(String organizationId) async {
    state = state.copyWith(
      isLoading: true,
      organizationId: organizationId,
      errorMessage: null,
    );

    try {
      final byDept = await _repository.getColleaguesByDepartment(organizationId);
      final allColleagues = byDept.values.expand((list) => list).toList();

      state = state.copyWith(
        isLoading: false,
        colleagues: allColleagues,
        byDepartment: byDept,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load colleagues: ${e.toString()}',
      );
    }
  }

  Future<void> searchColleagues(String query) async {
    if (state.organizationId == null) return;

    if (query.isEmpty) {
      await loadColleagues(state.organizationId!);
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final results = await _repository.searchColleagues(
        state.organizationId!,
        query,
      );

      // Group by department
      final Map<String?, List<ColleagueModel>> grouped = {};
      for (final colleague in results) {
        final deptName = colleague.departmentName;
        if (!grouped.containsKey(deptName)) {
          grouped[deptName] = [];
        }
        grouped[deptName]!.add(colleague);
      }

      state = state.copyWith(
        isLoading: false,
        colleagues: results,
        byDepartment: grouped,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Search failed: ${e.toString()}',
      );
    }
  }
}

final colleaguesProvider =
    NotifierProvider<ColleaguesNotifier, ColleaguesState>(() {
  return ColleaguesNotifier();
});

// ============================================================================
// DEPARTMENTS STATE
// ============================================================================

class DepartmentsState {
  final bool isLoading;
  final String? organizationId;
  final List<DepartmentModel> departments;
  final String? errorMessage;

  const DepartmentsState({
    this.isLoading = false,
    this.organizationId,
    this.departments = const [],
    this.errorMessage,
  });

  DepartmentsState copyWith({
    bool? isLoading,
    String? organizationId,
    List<DepartmentModel>? departments,
    String? errorMessage,
  }) {
    return DepartmentsState(
      isLoading: isLoading ?? this.isLoading,
      organizationId: organizationId ?? this.organizationId,
      departments: departments ?? this.departments,
      errorMessage: errorMessage,
    );
  }
}

class DepartmentsNotifier extends Notifier<DepartmentsState> {
  late final OrganizationRepository _repository;

  @override
  DepartmentsState build() {
    _repository = ref.watch(organizationRepositoryProvider);
    return const DepartmentsState();
  }

  Future<void> loadDepartments(String organizationId) async {
    state = state.copyWith(
      isLoading: true,
      organizationId: organizationId,
      errorMessage: null,
    );

    try {
      final depts = await _repository.getDepartments(organizationId);
      state = state.copyWith(isLoading: false, departments: depts);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load departments: ${e.toString()}',
      );
    }
  }

  Future<String?> createDepartment({
    required String name,
    String? description,
    String? color,
  }) async {
    if (state.organizationId == null) return null;

    try {
      final dept = await _repository.createDepartment(
        organizationId: state.organizationId!,
        name: name,
        description: description,
        color: color,
      );

      await loadDepartments(state.organizationId!);
      return dept.id;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to create department: ${e.toString()}',
      );
      return null;
    }
  }
}

final departmentsProvider =
    NotifierProvider<DepartmentsNotifier, DepartmentsState>(() {
  return DepartmentsNotifier();
});

// ============================================================================
// INVITES STATE
// ============================================================================

class InvitesState {
  final bool isLoading;
  final List<OrganizationInviteModel> pendingInvites;
  final String? errorMessage;

  const InvitesState({
    this.isLoading = false,
    this.pendingInvites = const [],
    this.errorMessage,
  });

  InvitesState copyWith({
    bool? isLoading,
    List<OrganizationInviteModel>? pendingInvites,
    String? errorMessage,
  }) {
    return InvitesState(
      isLoading: isLoading ?? this.isLoading,
      pendingInvites: pendingInvites ?? this.pendingInvites,
      errorMessage: errorMessage,
    );
  }

  int get count => pendingInvites.length;
}

class InvitesNotifier extends Notifier<InvitesState> {
  late final OrganizationRepository _repository;

  @override
  InvitesState build() {
    _repository = ref.watch(organizationRepositoryProvider);
    // Auto-load on build
    Future.microtask(() => loadInvites());
    return const InvitesState(isLoading: true);
  }

  Future<void> loadInvites() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final invites = await _repository.getMyPendingInvites();
      state = state.copyWith(isLoading: false, pendingInvites: invites);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load invites: ${e.toString()}',
      );
    }
  }

  Future<String?> createInvite({
    required String organizationId,
    MemberRole role = MemberRole.member,
    String? departmentId,
  }) async {
    try {
      final invite = await _repository.createInvite(
        organizationId: organizationId,
        role: role,
        departmentId: departmentId,
      );
      return invite.inviteCode;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to create invite: ${e.toString()}',
      );
      return null;
    }
  }
}

final invitesProvider = NotifierProvider<InvitesNotifier, InvitesState>(() {
  return InvitesNotifier();
});
