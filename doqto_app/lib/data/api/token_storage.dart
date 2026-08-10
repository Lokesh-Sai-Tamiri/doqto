import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';

/// Shared secure-storage options: Android EncryptedSharedPreferences; iOS
/// keychain items unlock after first device unlock and never migrate to a
/// new device via backup (M7). Reused by [BoxKeyStorage].
const kSecureStorageOptions = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

class TokenStorage {
  static const _storage = kSecureStorageOptions;

  Future<String?> get accessToken => _storage.read(key: AppConstants.kAccessToken);
  Future<String?> get refreshToken => _storage.read(key: AppConstants.kRefreshToken);

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: AppConstants.kAccessToken, value: access);
    await _storage.write(key: AppConstants.kRefreshToken, value: refresh);
  }

  Future<void> clear() async {
    await _storage.delete(key: AppConstants.kAccessToken);
    await _storage.delete(key: AppConstants.kRefreshToken);
  }
}
