import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/app_exception.dart';
import 'network_status.dart';

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
      } catch (e) {
        _isRefreshing = false;
        // A connection-level failure (DNS/timeout/no signal) during refresh
        // doesn't mean the refresh token is invalid — don't force a logout
        // for what's likely a transient network blip. Only clear the
        // session when the server actually rejected the refresh token.
        final isNetworkIssue = e is DioException && e.response == null;
        if (!isNetworkIssue) {
          await _clearSession(storage);
          onUnauthenticated();
        }
        handler.reject(err);
      }
      return;
    }

    handler.next(err);
  }
}

// ─── Retry Interceptor ────────────────────────────────────────────────────────

// Retries requests that failed before ever reaching the server (DNS
// failures, dropped connections, connect timeouts) — safe to retry
// regardless of HTTP method since the server never saw the request. Send/
// receive timeouts are more ambiguous (the server may have already gotten
// the request), so those are only retried for GET.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.maxRetries = 3});

  final Dio _dio;
  final int maxRetries;

  static const _retryCountKey = 'retry_count';

  bool _alwaysRetryable(DioExceptionType type) =>
      type == DioExceptionType.connectionError ||
      type == DioExceptionType.connectionTimeout;

  bool _idempotentOnlyRetryable(DioExceptionType type) =>
      type == DioExceptionType.sendTimeout ||
      type == DioExceptionType.receiveTimeout;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isGet = options.method.toUpperCase() == 'GET';
    final retryable =
        _alwaysRetryable(err.type) ||
        (isGet && _idempotentOnlyRetryable(err.type));

    final attempt = (options.extra[_retryCountKey] as int?) ?? 0;
    if (!retryable || attempt >= maxRetries) {
      handler.next(err);
      return;
    }

    options.extra[_retryCountKey] = attempt + 1;
    final backoff = Duration(milliseconds: 400 * (1 << attempt));
    await Future.delayed(backoff);

    try {
      final response = await _dio.fetch(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

// ─── Connectivity Interceptor ─────────────────────────────────────────────────

// Flips a global "backend unreachable" flag so the UI can show a persistent
// offline banner — set on connection-level failures (after retries are
// exhausted), cleared as soon as any request succeeds.
class ConnectivityInterceptor extends Interceptor {
  ConnectivityInterceptor(this._ref);

  final Ref _ref;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _ref.read(isBackendUnreachableProvider.notifier).markOnline();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout) {
      _ref.read(isBackendUnreachableProvider.notifier).markOffline();
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

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: response,
        error: AppException(_friendlyMessage(err)),
        type: err.type,
      ),
    );
  }

  String _friendlyMessage(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network and try again.';
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The connection timed out. Please check your network and try again.';
      case DioExceptionType.badCertificate:
        return 'Could not establish a secure connection. Please try again later.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return err.message ?? 'Something went wrong. Please try again.';
    }
  }
}
