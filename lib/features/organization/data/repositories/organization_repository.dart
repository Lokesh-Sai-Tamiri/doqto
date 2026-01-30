/// ============================================================================
/// ORGANIZATION REPOSITORY - HIPAA Compliant
/// ============================================================================
///
/// Handles all organization operations via the HymnChat API backend.
/// ============================================================================
library;

import '../../../../core/services/api_service.dart';
import '../../../../core/config/app_config.dart';
import '../models/organization_model.dart';

class OrganizationRepository {
  final ApiService _api = ApiService();

  // ============================================================================
  // MY ORGANIZATIONS
  // ============================================================================

  /// Get user's organizations
  Future<List<MyOrganizationModel>> getMyOrganizations() async {
    try {
      _log('🏢 Fetching user organizations...');

      final response = await _api.get<List<dynamic>>(
        '/organizations/my',
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        final orgs = response.data!
            .map((json) => MyOrganizationModel.fromJson(json as Map<String, dynamic>))
            .toList();

        _log('✅ Organizations loaded: ${orgs.length}');
        return orgs;
      }

      return [];
    } catch (e) {
      _log('❌ Error fetching organizations: $e');
      rethrow;
    }
  }

  /// Get single organization details
  Future<OrganizationModel?> getOrganization(String organizationId) async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/organizations/$organizationId',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return OrganizationModel.fromJson(response.data!);
      }

      return null;
    } catch (e) {
      _log('❌ Error fetching organization: $e');
      rethrow;
    }
  }

  // ============================================================================
  // DEPARTMENTS
  // ============================================================================

  /// Get departments for an organization
  Future<List<DepartmentModel>> getDepartments(String organizationId) async {
    try {
      _log('🏬 Fetching departments for org: $organizationId');

      final response = await _api.get<List<dynamic>>(
        '/organizations/$organizationId/departments',
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        final depts = response.data!
            .map((json) => DepartmentModel.fromJson(json as Map<String, dynamic>))
            .toList();

        _log('✅ Departments loaded: ${depts.length}');
        return depts;
      }

      return [];
    } catch (e) {
      _log('❌ Error fetching departments: $e');
      rethrow;
    }
  }

  /// Create a new department
  Future<DepartmentModel> createDepartment({
    required String organizationId,
    required String name,
    String? description,
    String? color,
    String? icon,
    int displayOrder = 0,
    String? headUserId,
  }) async {
    try {
      _log('➕ Creating department: $name');

      final response = await _api.post<Map<String, dynamic>>(
        '/organizations/$organizationId/departments',
        body: {
          'name': name,
          if (description != null) 'description': description,
          if (color != null) 'color': color,
          if (icon != null) 'icon': icon,
          'display_order': displayOrder,
          if (headUserId != null) 'head_user_id': headUserId,
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        _log('✅ Department created');
        return DepartmentModel.fromJson(response.data!);
      }

      throw Exception(response.error ?? 'Failed to create department');
    } catch (e) {
      _log('❌ Error creating department: $e');
      rethrow;
    }
  }

  // ============================================================================
  // COLLEAGUES
  // ============================================================================

  /// Get colleagues in an organization
  Future<List<ColleagueModel>> getColleagues(String organizationId) async {
    try {
      _log('👥 Fetching colleagues for org: $organizationId');

      final response = await _api.get<List<dynamic>>(
        '/organizations/$organizationId/colleagues',
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        final colleagues = response.data!
            .map((json) => ColleagueModel.fromJson(json as Map<String, dynamic>))
            .toList();

        _log('✅ Colleagues loaded: ${colleagues.length}');
        return colleagues;
      }

      return [];
    } catch (e) {
      _log('❌ Error fetching colleagues: $e');
      rethrow;
    }
  }

  /// Search colleagues
  Future<List<ColleagueModel>> searchColleagues(
    String organizationId,
    String query,
  ) async {
    try {
      final response = await _api.get<List<dynamic>>(
        '/organizations/$organizationId/colleagues/search',
        queryParams: {'q': query},
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!
            .map((json) => ColleagueModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      _log('❌ Error searching colleagues: $e');
      rethrow;
    }
  }

  /// Get colleagues by department
  Future<Map<String?, List<ColleagueModel>>> getColleaguesByDepartment(
    String organizationId,
  ) async {
    final colleagues = await getColleagues(organizationId);

    final Map<String?, List<ColleagueModel>> grouped = {};

    for (final colleague in colleagues) {
      final deptName = colleague.departmentName;
      if (!grouped.containsKey(deptName)) {
        grouped[deptName] = [];
      }
      grouped[deptName]!.add(colleague);
    }

    return grouped;
  }

  /// Get colleagues in a specific department
  Future<List<ColleagueModel>> getColleaguesInDepartment(
    String organizationId,
    String departmentId,
  ) async {
    try {
      final response = await _api.get<List<dynamic>>(
        '/organizations/$organizationId/departments/$departmentId/colleagues',
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!
            .map((json) => ColleagueModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      _log('❌ Error fetching department colleagues: $e');
      rethrow;
    }
  }

  // ============================================================================
  // ORGANIZATION MANAGEMENT
  // ============================================================================

  /// Create a new organization
  Future<OrganizationModel> createOrganization({
    required String name,
    OrganizationType type = OrganizationType.hospital,
    String? description,
    String? phone,
    String? email,
    String? website,
    String? city,
    String? state,
    bool isPublic = true,
  }) async {
    try {
      _log('🏢 Creating organization: $name');

      final response = await _api.post<Map<String, dynamic>>(
        '/organizations',
        body: {
          'name': name,
          'type': type.name,
          if (description != null) 'description': description,
          'contact': {
            if (phone != null) 'phone': phone,
            if (email != null) 'email': email,
            if (website != null) 'website': website,
          },
          'address': {
            if (city != null) 'city': city,
            if (state != null) 'state': state,
          },
          'is_public': isPublic,
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        _log('✅ Organization created');
        return OrganizationModel.fromJson(response.data!);
      }

      throw Exception(response.error ?? 'Failed to create organization');
    } catch (e) {
      _log('❌ Error creating organization: $e');
      rethrow;
    }
  }

  /// Leave an organization
  Future<bool> leaveOrganization(String organizationId) async {
    try {
      _log('🚪 Leaving organization: $organizationId');

      final response = await _api.delete<Map<String, dynamic>>(
        '/organizations/$organizationId/leave',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      _log('❌ Error leaving organization: $e');
      rethrow;
    }
  }

  // ============================================================================
  // INVITES
  // ============================================================================

  /// Get pending invites for current user
  Future<List<OrganizationInviteModel>> getMyPendingInvites() async {
    try {
      _log('📬 Fetching pending invites...');

      final response = await _api.get<List<dynamic>>(
        '/organizations/invites/pending',
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        final invites = response.data!
            .map((json) => OrganizationInviteModel.fromJson(json as Map<String, dynamic>))
            .toList();

        _log('✅ Pending invites loaded: ${invites.length}');
        return invites;
      }

      return [];
    } catch (e) {
      _log('❌ Error fetching invites: $e');
      rethrow;
    }
  }

  /// Create an invite code
  Future<OrganizationInviteModel> createInvite({
    required String organizationId,
    MemberRole role = MemberRole.member,
    String? departmentId,
    int expiresInDays = 7,
  }) async {
    try {
      _log('📧 Creating invite for org: $organizationId');

      final response = await _api.post<Map<String, dynamic>>(
        '/organizations/$organizationId/invites',
        body: {
          'role': role.name,
          if (departmentId != null) 'department_id': departmentId,
          'expires_in_days': expiresInDays,
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        _log('✅ Invite created');
        return OrganizationInviteModel.fromJson(response.data!);
      }

      throw Exception(response.error ?? 'Failed to create invite');
    } catch (e) {
      _log('❌ Error creating invite: $e');
      rethrow;
    }
  }

  /// Join organization using invite code
  Future<MyOrganizationModel> joinByInviteCode(String inviteCode) async {
    try {
      _log('🔑 Joining with code: $inviteCode');

      final response = await _api.post<Map<String, dynamic>>(
        '/organizations/invites/join',
        body: {'invite_code': inviteCode},
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        _log('✅ Joined organization');
        return MyOrganizationModel.fromJson(response.data!);
      }

      throw Exception(response.error ?? 'Failed to join organization');
    } catch (e) {
      _log('❌ Error joining organization: $e');
      rethrow;
    }
  }

  // ============================================================================
  // MEMBER MANAGEMENT
  // ============================================================================

  /// Update member's department
  Future<bool> updateMemberDepartment({
    required String membershipId,
    String? departmentId,
  }) async {
    try {
      final response = await _api.patch<Map<String, dynamic>>(
        '/organizations/memberships/$membershipId/department',
        body: {'department_id': departmentId},
        fromJson: (json) => json as Map<String, dynamic>,
      );

      return response.success;
    } catch (e) {
      _log('❌ Error updating member department: $e');
      rethrow;
    }
  }

  /// Get logo upload URL
  Future<LogoUploadInfo> getLogoUploadUrl(String organizationId, String filename) async {
    try {
      _log('📤 Getting logo upload URL for: $filename');

      final response = await _api.post<Map<String, dynamic>>(
        '/organizations/$organizationId/logo',
        queryParams: {'filename': filename},
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return LogoUploadInfo(
          uploadUrl: response.data!['upload_url'] as String,
          key: response.data!['key'] as String,
          finalUrl: response.data!['final_url'] as String,
        );
      }

      throw Exception(response.error ?? 'Failed to get upload URL');
    } catch (e) {
      _log('❌ Error getting logo upload URL: $e');
      rethrow;
    }
  }

  void _log(String message) {
    if (AppConfig.debugMode) {
      assert(() {
        // ignore: avoid_print
        print('[OrganizationRepository] $message');
        return true;
      }());
    }
  }
}

/// Logo upload information
class LogoUploadInfo {
  final String uploadUrl;
  final String key;
  final String finalUrl;

  LogoUploadInfo({
    required this.uploadUrl,
    required this.key,
    required this.finalUrl,
  });
}
