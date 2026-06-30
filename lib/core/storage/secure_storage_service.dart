import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _kAccessToken = 'auth_token';
const _kRefreshToken = 'refresh_token';
const _kUserId = 'user_id';
const _kUserRole = 'user_role';

class SecureStorageService {
  SecureStorageService() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kUserRole),
    ]);
  }

  Future<void> saveUser(String id, String role) async {
    await Future.wait([
      _storage.write(key: _kUserId, value: id),
      _storage.write(key: _kUserRole, value: role),
    ]);
  }

  Future<String?> getUserId() => _storage.read(key: _kUserId);
  Future<String?> getUserRole() => _storage.read(key: _kUserRole);
}

final secureStorageProvider = Provider<SecureStorageService>((_) => SecureStorageService());
