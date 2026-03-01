/// ============================================================================
/// APP CONFIGURATION - CENTRALIZED CONFIG FILE
/// ============================================================================
///
/// This file contains all configuration for the HymnChat app.
/// Update values here to configure Supabase, Twilio, and other settings.
///
/// IMPORTANT: Never commit sensitive keys to version control!
/// Use environment variables or .env files for production.
/// ============================================================================
library;

class AppConfig {
  // ============================================================================
  // SUPABASE CONFIGURATION
  // ============================================================================

  /// Your Supabase project URL
  /// Find at: https://app.supabase.com/project/_/settings/api
  static const String supabaseUrl = 'https://cyqvjjkmwitqgvvocmcc.supabase.co';

  /// Your Supabase anon/public key
  /// Find at: https://app.supabase.com/project/_/settings/api
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN5cXZqamttd2l0cWd2dm9jbWNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3NjcyMjEsImV4cCI6MjA4MTM0MzIyMX0.53nUUmspejDNdjHjqhqiGIr2qo-uVFm9-3v3lS1gUnc';

  // ============================================================================
  // PHONE AUTHENTICATION CONFIGURATION
  // ============================================================================

  /// Default country code for phone numbers
  static const String defaultCountryCode = '+91';

  /// Country flag emoji
  static const String defaultCountryFlag = '🇮🇳';

  /// OTP code length
  static const int otpLength = 6;

  /// OTP expiry time in seconds (default: 10 minutes)
  static const int otpExpirySeconds = 600;

  /// OTP resend cooldown in seconds (default: 30 seconds)
  static const int otpResendCooldownSeconds = 30;

  /// Maximum OTP attempts before lockout
  static const int maxOtpAttempts = 3;

  /// Phone number minimum length (without country code)
  static const int phoneNumberMinLength = 7;

  /// Phone number maximum length (without country code)
  static const int phoneNumberMaxLength = 15;

  // ============================================================================
  // TWILIO VERIFY CONFIGURATION
  // ============================================================================
  // Note: Twilio credentials are configured in Supabase Dashboard
  // Go to: Authentication -> Settings -> Phone Auth -> Twilio
  //
  // You need:
  // - Twilio Account SID
  // - Twilio Auth Token
  // - Twilio Verify Service SID
  // ============================================================================

  /// Enable/disable phone verification
  static const bool enablePhoneAuth = true;

  /// Channel for OTP delivery ('sms' or 'whatsapp')
  /// Note: WhatsApp requires Twilio Business Account
  static const String otpChannel = 'sms'; // Options: 'sms', 'whatsapp'

  // ============================================================================
  // RATE LIMITING & SECURITY
  // ============================================================================

  /// Enable rate limiting for OTP requests
  static const bool enableRateLimiting = true;

  /// Maximum OTP requests per phone number per day
  static const int maxOtpRequestsPerDay = 5;

  /// Enable debug mode (shows detailed logs)
  static const bool debugMode = true;

  // ============================================================================
  // UI CONFIGURATION
  // ============================================================================

  /// Show loading indicator during auth operations
  static const bool showLoadingIndicator = true;

  /// Auto-navigate after successful OTP verification
  static const bool autoNavigateAfterVerification = true;

  /// Show toast messages for errors
  static const bool showErrorToasts = true;

  // ============================================================================
  // SESSION CONFIGURATION
  // ============================================================================

  /// Persist user session across app restarts
  static const bool persistSession = true;

  /// Session token refresh interval in seconds (default: 50 minutes)
  /// Supabase tokens expire after 1 hour, we refresh at 50 minutes
  static const int sessionRefreshIntervalSeconds = 3000;

  /// Auto-refresh tokens before they expire
  static const bool autoRefreshToken = true;

  /// Retry API calls on token expiry
  static const bool retryOnTokenExpiry = true;

  // ============================================================================
  // INARA AI BACKEND CONFIGURATION
  // ============================================================================

  /// Inara AI Backend base URL
  /// For local development: 'http://localhost:8000' (Mac) or 'http://192.168.7.64:8000' (iOS/Android)
  /// For production: Update to your deployed backend URL
  static const String inaraApiBaseUrl = 'http://192.168.7.64:8000';

  /// Inara API endpoints
  static const String inaraChatEndpoint = '/api/chat';
  static const String inaraSessionsEndpoint = '/api/sessions';
  static const String inaraUserSessionsEndpoint = '/api/users';

  /// Request timeout in seconds
  static const int apiTimeoutSeconds = 60;

  // ============================================================================
  // HYMNCHAT API BACKEND CONFIGURATION
  // ============================================================================

  /// HymnChat API Backend base URL
  /// For local development: 'http://localhost:8000' (Mac) or 'http://192.168.7.64:8000' (iOS/Android)
  /// For production: Update to your deployed backend URL
  static const String apiBaseUrl = 'http://192.168.7.64:8000';

  /// Socket.io server URL (same as API for combined deployment)
  static const String socketUrl = 'http://192.168.7.64:8000';

  /// API version prefix
  static const String apiVersion = '/api/v1';

  /// API request timeout in seconds
  static const int apiRequestTimeoutSeconds = 30;

  /// Socket.io reconnection settings
  static const int socketReconnectAttempts = 5;
  static const int socketReconnectDelayMs = 1000;

  /// Enable API debug logging
  static const bool apiDebugMode = true;

  // ============================================================================
  // PROFILE CONFIGURATION
  // ============================================================================

  /// Redirect to profile creation after first login
  static const bool requireProfileSetup = true;

  /// Profile fields required
  static const List<String> requiredProfileFields = [
    'display_name',
    'avatar_url',
  ];

  // ============================================================================
  // ERROR MESSAGES
  // ============================================================================

  static const Map<String, String> errorMessages = {
    'invalid_phone': 'Please enter a valid phone number',
    'invalid_otp': 'Invalid verification code',
    'otp_expired': 'Verification code expired. Please request a new one',
    'rate_limit': 'Too many requests. Please try again later',
    'network_error': 'Network error. Please check your connection',
    'unknown_error': 'Something went wrong. Please try again',
    'user_not_found': 'User not found',
    'session_expired': 'Your session has expired. Please login again',
  };

  // ============================================================================
  // SUCCESS MESSAGES
  // ============================================================================

  static const Map<String, String> successMessages = {
    'otp_sent': 'Verification code sent successfully',
    'otp_resent': 'Verification code resent',
    'phone_verified': 'Phone number verified successfully',
    'login_success': 'Welcome back!',
    'profile_created': 'Profile created successfully',
  };

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get full phone number with country code
  static String getFullPhoneNumber(String phoneNumber) {
    // If it already starts with +, assume it has a country code
    if (phoneNumber.trim().startsWith('+')) {
      return phoneNumber.trim().replaceAll(RegExp(r'[^\d+]'), '');
    }

    // Remove any spaces, dashes, or special characters
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Add default country code if not present (simple check)
    // NOTE: This basic check fails if country code is same as start of number,
    // but better to rely on UI passing full E.164 if possible.
    // For now, if we use formatted inputs, we expect clean number or + format.
    if (!cleanNumber.startsWith(defaultCountryCode.replaceAll('+', ''))) {
      return '$defaultCountryCode$cleanNumber';
    }

    return '+$cleanNumber';
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    return cleanNumber.length >= phoneNumberMinLength &&
        cleanNumber.length <= phoneNumberMaxLength;
  }

  /// Format phone number for display
  static String formatPhoneNumber(String phoneNumber) {
    // Basic formatting logic
    if (phoneNumber.isEmpty) return '';
    return phoneNumber;
  }

  /// Check if config is valid
  static bool isConfigValid() {
    if (supabaseUrl == 'YOUR_SUPABASE_URL_HERE' ||
        supabaseAnonKey == 'YOUR_SUPABASE_ANON_KEY_HERE') {
      return false;
    }

    return true;
  }

  /// Get environment-specific config
  static String getEnvironment() {
    if (debugMode) return 'development';
    return 'production';
  }
}

// ============================================================================
// ENVIRONMENT-SPECIFIC CONFIGURATIONS
// ============================================================================
// 
// For production apps, use different configs per environment:
// 
// class DevConfig extends AppConfig {
//   static const String supabaseUrl = 'https://dev.supabase.co';
//   // ... dev-specific settings
// }
// 
// class ProdConfig extends AppConfig {
//   static const String supabaseUrl = 'https://prod.supabase.co';
//   // ... prod-specific settings
// }
// ============================================================================

