import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../data/auth_repository.dart';
import '../../domain/user_model.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum AuthStatus { initial, loading, pendingOtp, emailVerified, authenticated, unauthenticated, error, resetPending, resetSuccess }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.pendingEmail,
    this.resetEmail,
  });

  final AuthStatus status;
  final UserModel? user;
  final String? error;
  final String? pendingEmail;
  final String? resetEmail;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? error,
    String? pendingEmail,
    String? resetEmail,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
        pendingEmail: pendingEmail ?? this.pendingEmail,
        resetEmail: resetEmail ?? this.resetEmail,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState()) {
    // Register the unauthenticated callback so the Dio interceptor can call it.
    registerUnauthenticatedCallback(_onTokenExpired);
  }

  final AuthRepository _repo;

  // Called at startup from SplashScreen.
  Future<void> checkAuth() async {
    state = state.copyWith(status: AuthStatus.loading);
    final user = await _repo.checkStoredAuth();
    if (user != null) {
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> signup(String firstName, String lastName, String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      await _repo.signup(firstName, lastName, email, password);
      state = AuthState(status: AuthStatus.pendingOtp, pendingEmail: email.trim());
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  // Login — tokens returned directly, no OTP step.
  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _repo.login(email.trim(), password);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  // Email verification OTP (after signup) — navigates to login after success.
  Future<void> verifyOtp(String otp) async {
    final email = state.pendingEmail;
    if (email == null) return;
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      await _repo.verifyOtp(email, otp.trim());
      state = const AuthState(status: AuthStatus.emailVerified);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString(), pendingEmail: email);
    }
  }

  Future<void> resendOtp() async {
    final email = state.pendingEmail;
    if (email == null) return;
    try {
      await _repo.resendOtp(email);
    } catch (_) {}
  }

  Future<void> forgotPassword(String email) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      await _repo.forgotPassword(email.trim());
      state = AuthState(status: AuthStatus.resetPending, resetEmail: email.trim());
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  Future<void> resetPassword(String otp, String newPassword) async {
    final email = state.resetEmail;
    if (email == null) return;
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      await _repo.resetPassword(email, otp.trim(), newPassword);
      state = const AuthState(status: AuthStatus.resetSuccess);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString(), resetEmail: email);
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(
      status: state.pendingEmail != null ? AuthStatus.pendingOtp : AuthStatus.unauthenticated,
      error: null,
    );
  }

  void _onTokenExpired() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final _authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(apiClientProvider),
    ref.read(secureStorageProvider),
  );
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(_authRepositoryProvider)),
);

final currentUserProvider = Provider<UserModel?>((ref) => ref.watch(authProvider).user);

final isOwnerProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider)?.isOwner ?? false,
);
