import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/app_exception.dart';

const _kAccessToken = 'auth_token';
const _kRefreshToken = 'refresh_token';

// ─── Auth Interceptor ─────────────────────────────────────────────────────────

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: _kAccessToken);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

// ─── Refresh Interceptor ──────────────────────────────────────────────────────

class RefreshInterceptor extends Interceptor {
  RefreshInterceptor({
    required this.dio,
    required this.storage,
    required this.onUnauthenticated,
  });

  final Dio dio;
  final FlutterSecureStorage storage;
  final void Function() onUnauthenticated;

  bool _isRefreshing = false;

  // Clears current session keys but preserves owner_* keys so the profile
  // picker can restore the owner session without a full re-login.
  Future<void> _clearSession(FlutterSecureStorage s) async {
    await Future.wait([
      s.delete(key: _kAccessToken),
      s.delete(key: _kRefreshToken),
      s.delete(key: 'user_id'),
      s.delete(key: 'user_role'),
    ]);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final path = err.requestOptions.path;

    if (response?.statusCode == 401 &&
        !path.contains('/auth/refresh-token') &&
        !path.contains('/auth/login') &&
        !path.contains('/auth/verify-otp') &&
        !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await storage.read(key: _kRefreshToken);
        if (refreshToken == null) {
          _isRefreshing = false;
          await _clearSession(storage);
          onUnauthenticated();
          handler.reject(err);
          return;
        }

        final refreshResponse = await dio.post(
          '/auth/refresh-token',
          data: {'refreshToken': refreshToken},
        );

        final data = refreshResponse.data['data'] as Map<String, dynamic>;
        final newAccess = data['accessToken'] as String;
        final newRefresh = data['refreshToken'] as String? ?? refreshToken;

        await Future.wait([
          storage.write(key: _kAccessToken, value: newAccess),
          storage.write(key: _kRefreshToken, value: newRefresh),
        ]);

        _isRefreshing = false;

        // Retry the original request with the new token.
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newAccess';
        final retryResponse = await dio.fetch(opts);
        handler.resolve(retryResponse);
      } catch (_) {
        _isRefreshing = false;
        await _clearSession(storage);
        onUnauthenticated();
        handler.reject(err);
      }
      return;
    }

    handler.next(err);
  }
}

// ─── Error Interceptor ────────────────────────────────────────────────────────

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;

    if (response != null) {
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final raw = body['message'];
        final msg = raw is List
            ? raw.join(', ')
            : (raw as String? ?? 'An error occurred');
        final statusCode = response.statusCode;
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            response: response,
            error: AppException(msg, statusCode: statusCode),
            type: err.type,
          ),
        );
        return;
      }
    }

    handler.next(err);
  }
}
