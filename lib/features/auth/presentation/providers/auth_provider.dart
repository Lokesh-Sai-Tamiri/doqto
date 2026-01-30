/// ============================================================================
/// AUTH PROVIDERS - Riverpod State Management
/// ============================================================================
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/auth_state_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../core/config/app_config.dart';

/// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Auth State Provider
final authStateProvider = NotifierProvider<AuthNotifier, AuthStateModel>(() {
  return AuthNotifier();
});

/// OTP State Provider
final otpStateProvider = NotifierProvider<OtpNotifier, OtpStateModel>(() {
  return OtpNotifier();
});

// ============================================================================
// AUTH NOTIFIER
// ============================================================================

class AuthNotifier extends Notifier<AuthStateModel> {
  late final AuthRepository _repository;
  StreamSubscription? _authSubscription;

  @override
  AuthStateModel build() {
    _repository = ref.watch(authRepositoryProvider);
    _init();
    return AuthStateModel.initial();
  }

  void _init() {
    // Check initial auth state
    final user = _repository.getCurrentUser();
    if (user != null) {
      state = AuthStateModel.authenticated(user);
    } else {
      state = AuthStateModel.unauthenticated();
    }

    // Listen to auth state changes
    _authSubscription = _repository.onAuthStateChange().listen((authState) {
      final event = authState.event;

      if (authState.session?.user != null) {
        state = AuthStateModel.authenticated(authState.session!.user);
      } else {
        state = AuthStateModel.unauthenticated();
      }

      // Handle specific events
      if (event == AuthChangeEvent.tokenRefreshed) {
        if (AppConfig.debugMode) {
          print('🔄 Auth state updated after token refresh');
        }
      } else if (event == AuthChangeEvent.userUpdated) {
        if (AppConfig.debugMode) {
          print('👤 User updated');
        }
      }
    });
  }

  /// Check if user has completed profile setup
  Future<bool> hasCompletedProfile() async {
    return await _repository.hasCompletedProfile();
  }

  /// Explicitly set authenticated state (used after OTP verification)
  void setAuthenticated(User user) {
    state = AuthStateModel.authenticated(user);
    if (AppConfig.debugMode) {
      print('✅ Auth state explicitly set to authenticated');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      state = AuthStateModel.loading();
      await _repository.signOut();
      _authSubscription?.cancel();
      state = AuthStateModel.unauthenticated();
    } catch (e) {
      state = AuthStateModel.error(e.toString());
    }
  }
}

// Dispose is handled automatically by Riverpod 3.x

// ============================================================================
// OTP NOTIFIER
// ============================================================================

class OtpNotifier extends Notifier<OtpStateModel> {
  late final AuthRepository _repository;
  Timer? _resendTimer;
  int _attemptsCount = 0;

  @override
  OtpStateModel build() {
    _repository = ref.watch(authRepositoryProvider);
    return OtpStateModel.initial();
  }

  /// Explicitly update auth state after successful verification
  void _syncAuthState(User user) {
    // Directly update the auth state to avoid race conditions with listener
    ref.read(authStateProvider.notifier).setAuthenticated(user);
  }

  /// Send OTP to phone number
  Future<bool> sendOtp(String phoneNumber) async {
    try {
      // Check if already at max attempts
      if (_attemptsCount >= AppConfig.maxOtpRequestsPerDay) {
        state = OtpStateModel.error(
          AppConfig.errorMessages['rate_limit']!,
          phoneNumber: phoneNumber,
          attemptsLeft: 0,
        );
        return false;
      }

      // Validate phone number
      if (!AppConfig.isValidPhoneNumber(phoneNumber)) {
        state = OtpStateModel.error(
          AppConfig.errorMessages['invalid_phone']!,
          phoneNumber: phoneNumber,
        );
        return false;
      }

      state = OtpStateModel.sending(phoneNumber);

      // Send OTP via repository
      await _repository.sendOtp(phoneNumber);

      _attemptsCount++;

      // Set sent state with cooldown
      state = OtpStateModel.sent(
        phoneNumber,
        cooldownSeconds: AppConfig.otpResendCooldownSeconds,
      );

      // Start cooldown timer
      _startResendTimer(phoneNumber);

      return true;
    } catch (e) {
      state = OtpStateModel.error(
        e.toString().replaceAll('Exception: ', ''),
        phoneNumber: phoneNumber,
        attemptsLeft: AppConfig.maxOtpRequestsPerDay - _attemptsCount,
      );
      return false;
    }
  }

  /// Verify OTP code
  Future<bool> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    try {
      // Validate OTP code length
      if (otpCode.length != AppConfig.otpLength) {
        state = OtpStateModel.error(
          AppConfig.errorMessages['invalid_otp']!,
          phoneNumber: phoneNumber,
        );
        return false;
      }

      state = OtpStateModel.verifying(phoneNumber);

      // Verify OTP via repository
      final response = await _repository.verifyOtp(
        phoneNumber: phoneNumber,
        otpCode: otpCode,
      );

      if (response.user != null) {
        // Explicitly sync auth state to avoid race condition with listener
        _syncAuthState(response.user!);
        state = OtpStateModel.verified(phoneNumber);
        _resetAttempts();
        return true;
      } else {
        state = OtpStateModel.error(
          AppConfig.errorMessages['invalid_otp']!,
          phoneNumber: phoneNumber,
        );
        return false;
      }
    } catch (e) {
      state = OtpStateModel.error(
        e.toString().replaceAll('Exception: ', ''),
        phoneNumber: phoneNumber,
      );
      return false;
    }
  }

  /// Resend OTP
  Future<bool> resendOtp(String phoneNumber) async {
    // Cancel existing timer
    _resendTimer?.cancel();

    // Send new OTP
    return await sendOtp(phoneNumber);
  }

  /// Start resend cooldown timer
  void _startResendTimer(String phoneNumber) {
    _resendTimer?.cancel();

    int remainingSeconds = AppConfig.otpResendCooldownSeconds;

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remainingSeconds--;

      if (remainingSeconds <= 0) {
        timer.cancel();
        state = state.copyWith(canResend: true, remainingSeconds: 0);
      } else {
        state = state.copyWith(remainingSeconds: remainingSeconds);
      }
    });
  }

  /// Reset attempts count
  void _resetAttempts() {
    _attemptsCount = 0;
  }

  /// Reset state
  void reset() {
    _resendTimer?.cancel();
    state = OtpStateModel.initial();
  }
}

// Dispose is handled automatically by Riverpod 3.x
