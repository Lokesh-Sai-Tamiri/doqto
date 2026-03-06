/// ============================================================================
/// PROFILE REPOSITORY
/// ============================================================================
///
/// Handles profile data operations via the HymnChat API backend.
/// Provides methods for CRUD operations on user profiles.
/// ============================================================================
library;

import '../../../../core/services/api_service.dart';
import '../../../../core/config/app_config.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  final ApiService _api = ApiService();

  /// Get current user's profile
  Future<ProfileModel?> getMyProfile() async {
    try {
      if (AppConfig.debugMode) {
        _log('📋 Fetching current user profile');
      }

      final response = await _api.get<Map<String, dynamic>>(
        '/profiles/me',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        final profile = ProfileModel.fromJson(response.data!);
        if (AppConfig.debugMode) {
          _log('✅ Profile loaded: ${profile.fullName}');
        }
        return profile;
      }

      if (AppConfig.debugMode) {
        _log('⚠️ Failed to fetch profile: ${response.error}');
      }
      return null;
    } catch (e) {
      if (AppConfig.debugMode) {
        _log('❌ Error fetching profile: $e');
      }
      rethrow;
    }
  }

  /// Get user profile by user ID
  Future<ProfileModel?> getProfile(String userId) async {
    try {
      if (AppConfig.debugMode) {
        _log('📋 Fetching profile for user: $userId');
      }

      final response = await _api.get<Map<String, dynamic>>(
        '/profiles/$userId',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        final profile = ProfileModel.fromJson(response.data!);
        if (AppConfig.debugMode) {
          _log('✅ Profile loaded: ${profile.fullName}');
        }
        return profile;
      }

      if (response.statusCode == 404) {
        if (AppConfig.debugMode) {
          _log('⚠️ Profile not found for user: $userId');
        }
        return null;
      }

      if (AppConfig.debugMode) {
        _log('⚠️ Failed to fetch profile: ${response.error}');
      }
      return null;
    } catch (e) {
      if (AppConfig.debugMode) {
        _log('❌ Error fetching profile: $e');
      }
      rethrow;
    }
  }

  /// Update current user's profile
  Future<ProfileModel> updateProfile(ProfileModel profile) async {
    try {
      if (AppConfig.debugMode) {
        _log('💾 Updating profile');
      }

      final response = await _api.put<Map<String, dynamic>>(
        '/profiles/me',
        body: profile.toJson(),
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        final updatedProfile = ProfileModel.fromJson(response.data!);
        if (AppConfig.debugMode) {
          _log('✅ Profile updated successfully');
        }
        return updatedProfile;
      }

      throw Exception(response.error ?? 'Failed to update profile');
    } catch (e) {
      if (AppConfig.debugMode) {
        _log('❌ Error updating profile: $e');
      }
      rethrow;
    }
  }

  /// Create or update profile (upsert)
  Future<ProfileModel> upsertProfile(ProfileModel profile) async {
    // The API handles upsert automatically via PUT /profiles/me
    return updateProfile(profile);
  }

  /// Check if profile is completed
  Future<bool> isProfileCompleted(String userId) async {
    try {
      final response = await _api.get<bool>(
        '/profiles/me/completed',
        fromJson: (json) => json as bool,
      );

      return response.data ?? false;
    } catch (e) {
      if (AppConfig.debugMode) {
        _log('❌ Error checking profile completion: $e');
      }
      return false;
    }
  }

  /// Mark profile as completed
  Future<void> markProfileAsCompleted(String userId) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/profiles/me/complete',
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (!response.success) {
        throw Exception(response.error ?? 'Failed to mark profile as completed');
      }

      if (AppConfig.debugMode) {
        _log('✅ Profile marked as completed');
      }
    } catch (e) {
      if (AppConfig.debugMode) {
        _log('❌ Error updating profile status: $e');
      }
      rethrow;
    }
  }

  /// Get avatar upload URL
  Future<AvatarUploadInfo> getAvatarUploadUrl(String filename) async {
    try {
      if (AppConfig.debugMode) {
        _log('📤 Getting avatar upload URL for: $filename');
      }

      final response = await _api.post<Map<String, dynamic>>(
        '/profiles/me/avatar',
        queryParams: {'filename': filename},
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return AvatarUploadInfo(
          uploadUrl: response.data!['upload_url'] as String,
          key: response.data!['key'] as String,
          finalUrl: response.data!['final_url'] as String,
        );
      }

      throw Exception(response.error ?? 'Failed to get upload URL');
    } catch (e) {
      if (AppConfig.debugMode) {
        _log('❌ Error getting avatar upload URL: $e');
      }
      rethrow;
    }
  }

  /// Search profiles
  Future<List<ProfileModel>> searchProfiles(String query) async {
    try {
      if (AppConfig.debugMode) {
        _log('🔍 Searching profiles: $query');
      }

      final response = await _api.get<List<dynamic>>(
        '/profiles/search/',
        queryParams: {'q': query},
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data!
            .map((json) => ProfileModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      if (AppConfig.debugMode) {
        _log('❌ Error searching profiles: $e');
      }
      return [];
    }
  }

  void _log(String message) {
    if (AppConfig.debugMode) {
      // Production-safe logging
      assert(() {
        // ignore: avoid_print
        print('[ProfileRepository] $message');
        return true;
      }());
    }
  }
}

/// Avatar upload information
class AvatarUploadInfo {
  final String uploadUrl;
  final String key;
  final String finalUrl;

  AvatarUploadInfo({
    required this.uploadUrl,
    required this.key,
    required this.finalUrl,
  });
}
