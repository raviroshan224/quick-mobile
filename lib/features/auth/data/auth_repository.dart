import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../domain/user_model.dart';

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final SecureStorageService _storage;

  Future<void> signup(String firstName, String lastName, String email, String password) async {
    await _api.post('/auth/signup', data: {
      'firstName': firstName,
      'lastName': lastName,
      'email': email.trim(),
      'password': password,
    });
  }

  // Login — returns tokens + user directly (no OTP step).
  Future<UserModel> login(String email, String password) async {
    final data = await _api.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    ) as Map<String, dynamic>;

    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;

    await _storage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveUser(user.id, user.role == UserRole.owner ? 'OWNER' : 'STAFF');
    return user;
  }

  // Email verification OTP (after signup) — no tokens returned.
  Future<void> verifyOtp(String email, String otp) async {
    await _api.post('/auth/verify-otp', data: {'email': email, 'otp': otp});
  }

  Future<void> resendOtp(String email) async {
    await _api.post('/auth/resend-otp', data: {'email': email});
  }

  Future<void> forgotPassword(String email) async {
    await _api.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword(String email, String otp, String newPassword) async {
    await _api.post('/auth/reset-password', data: {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    });
  }

  Future<UserModel> getMe() async {
    final data = await _api.get('/auth/me') as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Fire and forget — always clear local tokens.
    } finally {
      await _storage.clearTokens();
    }
  }

  // Checks if stored tokens are still valid. Returns null if not.
  Future<UserModel?> checkStoredAuth() async {
    final token = await _storage.getAccessToken();
    if (token == null) return null;
    try {
      return await getMe();
    } catch (_) {
      await _storage.clearTokens();
      return null;
    }
  }
}
