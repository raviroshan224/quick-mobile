import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../domain/user_model.dart';
import '../domain/profile_model.dart';

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

    await _storage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);

    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveUser(user.id, user.isOwner ? 'OWNER' : 'STAFF');

    // Persist owner session separately so the profile picker survives staff switches.
    if (user.isOwner) {
      await _storage.saveOwnerTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    }

    return user;
  }

  // PIN login — authenticates any user (owner or staff) with a 4-digit PIN.
  Future<UserModel> pinLogin(String userId, String pin) async {
    final data = await _api.post(
      '/auth/pin-login',
      data: {'userId': userId, 'pin': pin},
    ) as Map<String, dynamic>;

    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;

    await _storage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);

    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveUser(user.id, user.isOwner ? 'OWNER' : 'STAFF');

    // If it's the owner logging in via PIN, also refresh the persistent owner tokens.
    if (user.isOwner) {
      await _storage.saveOwnerTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    }

    return user;
  }

  // Fetch all active profiles for the profile picker (requires owner JWT).
  Future<List<ProfileModel>> getProfiles() async {
    final data = await _api.get('/auth/profiles') as List<dynamic>;
    return data
        .map((e) => ProfileModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Restores the owner's tokens as the active session, then fetches profiles.
  // After the call, re-saves the (possibly refreshed) tokens to owner_* so
  // they stay current even after token rotation.
  Future<List<ProfileModel>> switchToOwnerAndGetProfiles() async {
    final ownerAccess = await _storage.getOwnerAccessToken();
    final ownerRefresh = await _storage.getOwnerRefreshToken();
    if (ownerAccess == null || ownerRefresh == null) {
      throw Exception('No persistent owner session found');
    }
    await _storage.saveTokens(
      accessToken: ownerAccess,
      refreshToken: ownerRefresh,
    );

    // This call may trigger a token refresh via the Dio interceptor.
    final profiles = await getProfiles();

    // Persist whatever tokens are now active (may have been rotated).
    final currentAccess = await _storage.getAccessToken();
    final currentRefresh = await _storage.getRefreshToken();
    if (currentAccess != null && currentRefresh != null) {
      await _storage.saveOwnerTokens(
        accessToken: currentAccess,
        refreshToken: currentRefresh,
      );
    }

    return profiles;
  }

  Future<bool> hasOwnerSession() async {
    final token = await _storage.getOwnerAccessToken();
    return token != null;
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

  Future<void> setOwnerPin(String pin) async {
    await _api.patch('/auth/set-pin', data: {'pin': pin});
  }

  Future<void> setStaffPin(String staffId, String pin) async {
    await _api.patch('/auth/staff/$staffId/pin', data: {'pin': pin});
  }

  // Clears the active staff/user session without touching the owner_* tokens.
  Future<void> clearStaffSession() => _storage.clearTokens();

  // Logs out fully — clears all tokens including the persistent owner session.
  Future<void> fullLogout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
    } finally {
      await _storage.clearAll();
    }
  }

  // Checks if stored tokens are still valid. Returns null if not.
  Future<UserModel?> checkStoredAuth() async {
    final token = await _storage.getAccessToken();
    if (token == null) return null;
    try {
      final user = await getMe();
      // Keep owner tokens in sync whenever the owner is the active session.
      if (user.isOwner) {
        final currentAccess = await _storage.getAccessToken();
        final currentRefresh = await _storage.getRefreshToken();
        if (currentAccess != null && currentRefresh != null) {
          await _storage.saveOwnerTokens(
            accessToken: currentAccess,
            refreshToken: currentRefresh,
          );
        }
      }
      return user;
    } catch (_) {
      await _storage.clearTokens();
      return null;
    }
  }

  // Legacy — kept for compatibility; use fullLogout() for the sign-out button.
  Future<void> logout() => fullLogout();
}
