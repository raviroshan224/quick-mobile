import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../data/auth_repository.dart';
import '../../domain/user_model.dart';
import '../../domain/profile_model.dart';

// Must match AuthService.login()'s exact message on the backend for the
// not-verified case — see auth.service.ts. Not a great coupling, but the
// backend has no distinct error code for this, only a shared 401 with
// different messages depending on why login failed.
const _kEmailNotVerifiedMessage = 'Email not verified. Please verify OTP first.';

// ─── State ────────────────────────────────────────────────────────────────────

enum AuthStatus {
  initial,
  loading,
  pendingOtp,
  emailVerified,
  authenticated,
  unauthenticated,
  error,
  resetPending,
  resetSuccess,
  pickingProfile,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.pendingEmail,
    this.resetEmail,
    this.profiles,
    this.ownerUserId,
  });

  final AuthStatus status;
  final UserModel? user;
  final String? error;
  final String? pendingEmail;
  final String? resetEmail;
  final List<ProfileModel>? profiles;
  final String? ownerUserId;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? error,
    String? pendingEmail,
    String? resetEmail,
    List<ProfileModel>? profiles,
    String? ownerUserId,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
        pendingEmail: pendingEmail ?? this.pendingEmail,
        resetEmail: resetEmail ?? this.resetEmail,
        profiles: profiles ?? this.profiles,
        ownerUserId: ownerUserId ?? this.ownerUserId,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState()) {
    registerUnauthenticatedCallback(_onTokenExpired);
  }

  final AuthRepository _repo;

  // Called at startup from SplashScreen.
  Future<void> checkAuth() async {
    state = state.copyWith(status: AuthStatus.loading);

    // First check: is there already a valid active session?
    final user = await _repo.checkStoredAuth();
    if (user != null) {
      if (user.isOwner) {
        // Owner is active → show profile picker.
        try {
          final profiles = await _repo.getProfiles();
          state = AuthState(
            status: AuthStatus.pickingProfile,
            profiles: profiles,
            ownerUserId: user.id,
          );
        } catch (_) {
          // Profiles failed — go straight to dashboard (degraded mode).
          state = AuthState(status: AuthStatus.authenticated, user: user);
        }
        return;
      } else {
        // Staff was last active — always show profile picker on restart.
        // Clear staff tokens (owner tokens are preserved by clearTokens()).
        await _repo.clearStaffSession();
      }
    }

    // No active session — try to restore from persisted owner tokens.
    final hasOwner = await _repo.hasOwnerSession();
    if (hasOwner) {
      try {
        final profiles = await _repo.switchToOwnerAndGetProfiles();
        final ownerProfile = profiles.firstWhere((p) => p.isOwner);
        state = AuthState(
          status: AuthStatus.pickingProfile,
          profiles: profiles,
          ownerUserId: ownerProfile.id,
        );
        return;
      } catch (_) {
        // Owner session expired — fall through to login.
      }
    }

    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> signup(
    String companyName,
    String firstName,
    String lastName,
    String email,
    String password,
  ) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      await _repo.signup(companyName, firstName, lastName, email, password);
      state = AuthState(status: AuthStatus.pendingOtp, pendingEmail: email.trim());
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  // Email/password login — only used for the OWNER on first use.
  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _repo.login(email.trim(), password);
      if (user.isOwner) {
        final profiles = await _repo.getProfiles();
        state = AuthState(
          status: AuthStatus.pickingProfile,
          profiles: profiles,
          ownerUserId: user.id,
        );
      } else {
        state = AuthState(status: AuthStatus.authenticated, user: user);
      }
    } catch (e) {
      if (e is AppException && e.message == _kEmailNotVerifiedMessage) {
        // Same dead end an abandoned signup leaves behind — route straight
        // into OTP verification instead of stranding the user on a login
        // error with no way forward. Fire off a fresh OTP so the code
        // waiting in their inbox is guaranteed current.
        final trimmedEmail = email.trim();
        state = AuthState(status: AuthStatus.pendingOtp, pendingEmail: trimmedEmail);
        unawaited(resendOtp());
        return;
      }
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  // PIN login — called when a profile card is tapped and PIN is confirmed.
  Future<void> pinLogin(String userId, String pin) async {
    // Keep profile state visible while loading.
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _repo.pinLogin(userId, pin);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      // Restore picker state so the PIN sheet can show the error.
      state = state.copyWith(
        status: AuthStatus.pickingProfile,
        error: e.toString(),
      );
    }
  }

  // Switch back to the profile picker (without a full logout).
  Future<void> switchProfile() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final profiles = await _repo.switchToOwnerAndGetProfiles();
      final ownerProfile = profiles.firstWhere((p) => p.isOwner);
      state = AuthState(
        status: AuthStatus.pickingProfile,
        profiles: profiles,
        ownerUserId: ownerProfile.id,
      );
    } catch (_) {
      await _repo.fullLogout();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  // Refresh profiles list (e.g. after setting a PIN).
  Future<void> refreshProfiles() async {
    try {
      final profiles = await _repo.getProfiles();
      state = state.copyWith(profiles: profiles);
    } catch (_) {}
  }

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
    await _repo.fullLogout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(
      status: state.pendingEmail != null ? AuthStatus.pendingOtp : AuthStatus.unauthenticated,
      error: null,
    );
  }

  // Fully abandons an in-progress OTP verification (e.g. the user taps back
  // from the OTP screen) — clearError() alone isn't enough here, since it
  // preserves AuthStatus.pendingOtp as long as pendingEmail is still set,
  // and the router unconditionally redirects any navigation back to
  // /verify-otp while that status holds. This resets to a clean
  // unauthenticated state so leaving the OTP screen actually leaves it.
  void cancelPendingOtp() {
    state = const AuthState(status: AuthStatus.unauthenticated);
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
