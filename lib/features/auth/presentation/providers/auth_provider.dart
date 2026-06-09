import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/mock_auth_repository.dart';
import '../../domain/user_model.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  final AuthStatus status;
  final UserModel? user;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({AuthStatus? status, UserModel? user, String? error}) => AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState(status: AuthStatus.unauthenticated));

  final MockAuthRepository _repo;

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _repo.login(email.trim(), password);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on AuthException catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.message);
    } catch (_) {
      state = const AuthState(status: AuthStatus.error, error: 'Login failed. Please try again.');
    }
  }

  void loginAs(UserRole role) {
    final user = role == UserRole.owner
        ? const UserModel(id: 'owner-demo', email: 'owner@salon.com', firstName: 'Aarav', lastName: 'Sharma', role: UserRole.owner)
        : const UserModel(id: 'staff-demo', email: 'staff@salon.com', firstName: 'Priya', lastName: 'Thapa', role: UserRole.staff);
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() => state = state.copyWith(status: AuthStatus.unauthenticated, error: null);
}

// ─── Providers ────────────────────────────────────────────────────────────────

final _authRepositoryProvider = Provider<MockAuthRepository>((_) => MockAuthRepository());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(_authRepositoryProvider)),
);

final currentUserProvider = Provider<UserModel?>((ref) => ref.watch(authProvider).user);

final isOwnerProvider = Provider<bool>((ref) => ref.watch(currentUserProvider)?.isOwner ?? false);
