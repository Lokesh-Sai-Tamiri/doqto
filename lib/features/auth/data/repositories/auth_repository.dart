/// ============================================================================
/// AUTH REPOSITORY - Supabase Phone Authentication with Twilio Verify
/// ============================================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/config/app_config.dart';

class AuthRepository {
  final SupabaseClient _supabase = SupabaseService.client;
  final ApiService _api = ApiService();

  /// Execute API call with automatic token refresh on expiry
  Future<T> _executeWithRefresh<T>(Future<T> Function() operation) async {
    try {
      // Check if session is valid before making the call
      if (!SupabaseService.isSessionValid() &&
          SupabaseService.isAuthenticated) {
        if (AppConfig.debugMode) {
          print('⚠️ Session expired, refreshing...');
        }
        await SupabaseService.refreshSession();
      }

      return await operation();
    } on AuthException catch (e) {
      // If token is invalid/expired, try refreshing and retry once
      if (AppConfig.retryOnTokenExpiry && _isTokenError(e)) {
        if (AppConfig.debugMode) {
          print('🔄 Token error detected, attempting refresh and retry...');
        }

        final refreshed = await SupabaseService.refreshSession();

        if (refreshed) {
          // Retry the operation after refresh
          return await operation();
        } else {
          throw Exception(AppConfig.errorMessages['session_expired']);
        }
      }
      rethrow;
    }
  }

  /// Check if error is related to token expiry
  bool _isTokenError(AuthException e) {
    final errorMessage = e.message.toLowerCase();
    return errorMessage.contains('jwt') ||
        errorMessage.contains('token') ||
        errorMessage.contains('expired') ||
        errorMessage.contains('invalid') ||
        e.statusCode == '401';
  }

  /// Send OTP to phone number
  ///
  /// This triggers Twilio Verify to send an SMS with verification code
  Future<void> sendOtp(String phoneNumber) async {
    try {
      // Format phone number with country code
      final fullPhoneNumber = AppConfig.getFullPhoneNumber(phoneNumber);

      if (AppConfig.debugMode) {
        print('📱 Sending OTP to: $fullPhoneNumber');
      }

      // Supabase will use Twilio Verify configured in dashboard
      await _supabase.auth.signInWithOtp(
        phone: fullPhoneNumber,
        // Channel can be 'sms' or 'whatsapp' (requires Twilio Business)
        channel: AppConfig.otpChannel == 'whatsapp'
            ? OtpChannel.whatsapp
            : OtpChannel.sms,
      );

      if (AppConfig.debugMode) {
        print('✅ OTP sent successfully via ${AppConfig.otpChannel}');
      }
    } on AuthException catch (e) {
      if (AppConfig.debugMode) {
        print('❌ Auth error: ${e.message}');
      }
      throw _handleAuthException(e);
    } catch (e) {
      if (AppConfig.debugMode) {
        print('❌ Unexpected error: $e');
      }
      throw Exception(AppConfig.errorMessages['unknown_error']);
    }
  }

  /// Verify OTP code
  ///
  /// This verifies the code sent by Twilio Verify
  Future<AuthResponse> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    try {
      // Format phone number with country code
      final fullPhoneNumber = AppConfig.getFullPhoneNumber(phoneNumber);

      if (AppConfig.debugMode) {
        print('🔐 Verifying OTP for: $fullPhoneNumber');
      }

      // Verify OTP with Supabase (which uses Twilio Verify)
      final response = await _supabase.auth.verifyOTP(
        phone: fullPhoneNumber,
        token: otpCode,
        type: OtpType.sms,
      );

      if (response.user != null) {
        if (AppConfig.debugMode) {
          print('✅ OTP verified successfully');
          print('👤 User ID: ${response.user!.id}');
          print('📱 Phone: ${response.user!.phone}');
        }
      }

      return response;
    } on AuthException catch (e) {
      if (AppConfig.debugMode) {
        print('❌ Verification failed: ${e.message}');
      }
      throw _handleAuthException(e);
    } catch (e) {
      if (AppConfig.debugMode) {
        print('❌ Unexpected error: $e');
      }
      throw Exception(AppConfig.errorMessages['unknown_error']);
    }
  }

  /// Resend OTP
  Future<void> resendOtp(String phoneNumber) async {
    // Resending uses the same method as sending
    await sendOtp(phoneNumber);
  }

  /// Get current user
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  /// Get current session
  Session? getCurrentSession() {
    return _supabase.auth.currentSession;
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    return _supabase.auth.currentSession != null;
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();

      if (AppConfig.debugMode) {
        print('👋 User signed out successfully');
      }
    } catch (e) {
      if (AppConfig.debugMode) {
        print('❌ Sign out error: $e');
      }
      throw Exception(AppConfig.errorMessages['unknown_error']);
    }
  }

  /// Listen to auth state changes
  Stream<AuthState> onAuthStateChange() {
    return _supabase.auth.onAuthStateChange;
  }

  /// Check if user has completed profile
  Future<bool> hasCompletedProfile() async {
    return await _executeWithRefresh(() async {
      try {
        final user = getCurrentUser();
        if (user == null) return false;

        // Query profile via API backend
        final response = await _api.get<Map<String, dynamic>>(
          '/profiles/me',
          fromJson: (json) => json as Map<String, dynamic>,
        );

        if (!response.success || response.data == null) {
          if (AppConfig.debugMode) {
            print('⚠️ No profile found - needs to create profile');
          }
          return false;
        }

        final profile = response.data!;

        // Check if profile is marked as completed
        if (profile['profile_completed'] == true) {
          return true;
        }

        // Check if required fields are filled
        final hasRequiredFields =
            profile['first_name'] != null &&
            profile['first_name'].toString().isNotEmpty &&
            profile['last_name'] != null &&
            profile['last_name'].toString().isNotEmpty &&
            profile['email'] != null &&
            profile['email'].toString().isNotEmpty;

        if (AppConfig.debugMode) {
          print('📊 Profile completion check:');
          print('   - Has first name: ${profile['first_name'] != null}');
          print('   - Has last name: ${profile['last_name'] != null}');
          print('   - Has email: ${profile['email'] != null}');
          print('   - Profile completed: ${profile['profile_completed']}');
          print('   - Result: $hasRequiredFields');
        }

        return hasRequiredFields;
      } catch (e) {
        if (AppConfig.debugMode) {
          print('⚠️ Error checking profile: $e');
        }
        return false;
      }
    });
  }

  /// Handle auth exceptions and return user-friendly messages
  Exception _handleAuthException(AuthException e) {
    switch (e.statusCode) {
      case '400':
        if (e.message.toLowerCase().contains('invalid')) {
          return Exception(AppConfig.errorMessages['invalid_otp']);
        }
        return Exception(AppConfig.errorMessages['invalid_phone']);

      case '429':
        return Exception(AppConfig.errorMessages['rate_limit']);

      case '422':
        return Exception(AppConfig.errorMessages['otp_expired']);

      default:
        if (e.message.toLowerCase().contains('network')) {
          return Exception(AppConfig.errorMessages['network_error']);
        }
        return Exception(e.message);
    }
  }
}
