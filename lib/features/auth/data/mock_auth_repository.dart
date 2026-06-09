import '../domain/user_model.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _Account {
  const _Account({required this.user, required this.password});
  final UserModel user;
  final String password;
}

class MockAuthRepository {
  static const _delay = Duration(milliseconds: 800);

  // Shared in-memory account store — persists for the app session.
  // Pre-seeded with demo accounts; owner can add staff accounts at runtime.
  static final Map<String, _Account> _accounts = {
    'owner@salon.com': const _Account(
      password: '1234',
      user: UserModel(
        id: 'user-owner-01',
        email: 'owner@salon.com',
        firstName: 'Aarav',
        lastName: 'Sharma',
        role: UserRole.owner,
      ),
    ),
    'priya@salon.com': const _Account(
      password: '1234',
      user: UserModel(
        id: 'u-st-01',
        email: 'priya@salon.com',
        firstName: 'Priya',
        lastName: 'Thapa',
        role: UserRole.staff,
      ),
    ),
    'rina@salon.com': const _Account(
      password: '1234',
      user: UserModel(
        id: 'u-st-02',
        email: 'rina@salon.com',
        firstName: 'Rina',
        lastName: 'Shrestha',
        role: UserRole.staff,
      ),
    ),
  };

  Future<UserModel> login(String email, String password) async {
    await Future.delayed(_delay);
    final key = email.trim().toLowerCase();
    final account = _accounts[key];
    if (account == null) {
      throw const AuthException('No account found with this email address.');
    }
    if (account.password != password) {
      throw const AuthException('Incorrect password. Please try again.');
    }
    return account.user;
  }

  // Called by StaffFormScreen when the owner creates a new staff member.
  static void registerStaff({
    required String email,
    required String password,
    required UserModel user,
  }) {
    _accounts[email.trim().toLowerCase()] = _Account(user: user, password: password);
  }

  // Called by the reset-password flow in StaffFormScreen.
  static bool resetPassword({
    required String email,
    required String newPassword,
  }) {
    final key = email.trim().toLowerCase();
    final existing = _accounts[key];
    if (existing == null) return false;
    _accounts[key] = _Account(user: existing.user, password: newPassword);
    return true;
  }

  static bool emailExists(String email) =>
      _accounts.containsKey(email.trim().toLowerCase());

  static String? getEmailByUserId(String userId) {
    for (final entry in _accounts.entries) {
      if (entry.value.user.id == userId) return entry.key;
    }
    return null;
  }

  Future<void> logout() async =>
      Future.delayed(const Duration(milliseconds: 200));
}
