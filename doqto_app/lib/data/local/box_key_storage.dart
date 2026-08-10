import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../core/constants/app_constants.dart';
import '../api/token_storage.dart';

/// H1: AES-256 key for the encrypted Hive boxes, generated once on first
/// launch and kept in the platform keychain/keystore (same storage + options
/// as [TokenStorage]).
class BoxKeyStorage {
  static const _storage = kSecureStorageOptions;

  /// Pure keygen — 32 random bytes (AES-256). Static so tests can exercise
  /// it without touching platform secure storage.
  static Uint8List generateKey() => Uint8List.fromList(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)),
      );

  Future<Uint8List> getOrCreateKey() async {
    final existing = await _storage.read(key: AppConstants.kHiveBoxKey);
    if (existing != null && existing.isNotEmpty) {
      return base64Decode(existing);
    }
    final key = generateKey();
    await _storage.write(key: AppConstants.kHiveBoxKey, value: base64Encode(key));
    return key;
  }
}
