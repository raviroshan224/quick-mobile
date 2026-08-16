import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _kAccessToken = 'auth_token';
const _kRefreshToken = 'refresh_token';
const _kUserId = 'user_id';
const _kUserRole = 'user_role';
const _kOwnerAccessToken = 'owner_access_token';
const _kOwnerRefreshToken = 'owner_refresh_token';

class SecureStorageService {
  SecureStorageService() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    // Sequential, not Future.wait — on the web backend the first write
    // lazily creates the encryption key in localStorage. Two writes racing
    // to create it in parallel can each generate a different key, leaving
    // whichever value was encrypted with the losing key undecryptable
    // (throws OperationError on read).
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
  }

  Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);

  // Owner-specific tokens — persist across staff profile switches.
  Future<void> saveOwnerTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kOwnerAccessToken, value: accessToken);
    await _storage.write(key: _kOwnerRefreshToken, value: refreshToken);
  }

  Future<String?> getOwnerAccessToken() => _storage.read(key: _kOwnerAccessToken);
  Future<String?> getOwnerRefreshToken() => _storage.read(key: _kOwnerRefreshToken);

  // Clears current session (staff or owner active session), keeps owner keys.
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kUserRole),
    ]);
  }

  // Full logout — clears everything including the persistent owner session.
  Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kUserRole),
      _storage.delete(key: _kOwnerAccessToken),
      _storage.delete(key: _kOwnerRefreshToken),
    ]);
  }

  Future<void> saveUser(String id, String role) async {
    await _storage.write(key: _kUserId, value: id);
    await _storage.write(key: _kUserRole, value: role);
  }

  Future<String?> getUserId() => _storage.read(key: _kUserId);
  Future<String?> getUserRole() => _storage.read(key: _kUserRole);
}

final secureStorageProvider = Provider<SecureStorageService>((_) => SecureStorageService());
