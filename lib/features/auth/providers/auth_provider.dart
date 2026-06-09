import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';

class AuthState {
  const AuthState({this.token, this.user, this.isLoading = false, this.error});
  final String? token;
  final Map<String, dynamic>? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => token != null;
  AuthState copyWith({String? token, Map<String, dynamic>? user, bool? isLoading, String? error}) =>
      AuthState(token: token ?? this.token, user: user ?? this.user, isLoading: isLoading ?? this.isLoading, error: error);
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._apiClient, this._storage) : super(const AuthState()) {
    _restoreSession();
  }

  final ApiClient _apiClient;
  final FlutterSecureStorage _storage;

  Future<void> _restoreSession() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token != null) state = state.copyWith(token: token);
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _apiClient.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final token = res['data']['accessToken'] as String;
      final user = res['data']['user'] as Map<String, dynamic>;
      await _storage.write(key: AppConstants.tokenKey, value: token);
      state = AuthState(token: token, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: AppConstants.tokenKey);
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiClientProvider), const FlutterSecureStorage());
});
