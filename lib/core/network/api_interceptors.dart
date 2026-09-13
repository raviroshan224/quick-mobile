import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
    required this.ref,
  });

  final Dio dio;
  final FlutterSecureStorage storage;
  final void Function() onUnauthenticated;
  // Refresh/retry requests run on a bare `refreshDio` with no interceptors
  // of its own (to avoid recursing back into this same handler), so
  // ConnectivityInterceptor never sees their responses — a success here has
  // to mark the app back online itself, or a stale "offline" banner from
  // before the refresh can be left showing indefinitely even though the
  // backend just proved it's reachable.
  final Ref ref;

  // Non-null while a token refresh triggered by a concurrent 401 is in
  // flight — lets sibling requests that 401 at the same moment await the
  // same refresh and retry, instead of each independently failing.
  Future<String?>? _refreshFuture;

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

    // pin-login is a public credential-check endpoint (like /auth/login) —
    // a 401 from it means "wrong PIN", not "access token expired". Treating
    // it as the latter reads the *owner's* currently-active refresh token
    // (the profile picker runs under the owner's session) and can rotate or
    // clear it over a simple wrong-PIN entry, corrupting the owner's session
    // for an error that has nothing to do with them.
    if (response?.statusCode == 401 &&
        !path.contains('/auth/refresh-token') &&
        !path.contains('/auth/login') &&
        !path.contains('/auth/pin-login') &&
        !path.contains('/auth/verify-otp')) {
      if (_refreshFuture != null) {
        // A refresh triggered by another concurrent request is already in
        // flight — await it and retry this request with the resulting
        // token instead of failing it outright (the old behavior: only the
        // first concurrent 401 got refreshed-and-retried, every other one
        // failed even though the token was fixed a moment later).
        try {
          final newAccess = await _refreshFuture;
          if (newAccess == null) {
            handler.reject(err);
            return;
          }
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newAccess';
          final retryResponse = await dio.fetch(opts);
          ref.read(isBackendUnreachableProvider.notifier).markOnline();
          handler.resolve(retryResponse);
        } catch (_) {
          handler.reject(err);
        }
        return;
      }

      final refreshCompleter = Completer<String?>();
      _refreshFuture = refreshCompleter.future;
      try {
        final refreshToken = await storage.read(key: _kRefreshToken);
        if (refreshToken == null) {
          await _clearSession(storage);
          onUnauthenticated();
          refreshCompleter.complete(null);
          _refreshFuture = null;
          handler.reject(err);
          return;
        }

        final refreshResponse = await dio.post(
          '/auth/refresh-token',
          data: {'refreshToken': refreshToken},
        );
        // The refresh call alone already proves the backend is reachable,
        // regardless of what happens with the retry below.
        ref.read(isBackendUnreachableProvider.notifier).markOnline();

        final data = refreshResponse.data['data'] as Map<String, dynamic>;
        final newAccess = data['accessToken'] as String;
        final newRefresh = data['refreshToken'] as String? ?? refreshToken;

        // Sequential, not Future.wait — see secure_storage_service.dart's
        // saveTokens for why parallel writes race on the web backend.
        await storage.write(key: _kAccessToken, value: newAccess);
        await storage.write(key: _kRefreshToken, value: newRefresh);

        refreshCompleter.complete(newAccess);
        _refreshFuture = null;

        // Retry the original request with the new token.
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newAccess';
        final retryResponse = await dio.fetch(opts);
        handler.resolve(retryResponse);
      } catch (e) {
        // A connection-level failure (DNS/timeout/no signal) during refresh
        // doesn't mean the refresh token is invalid — don't force a logout
        // for what's likely a transient network blip. Only clear the
        // session when the server actually rejected the refresh token.
        final isNetworkIssue = e is DioException && e.response == null;
        if (!isNetworkIssue) {
          await _clearSession(storage);
          onUnauthenticated();
        }
        if (!refreshCompleter.isCompleted) refreshCompleter.complete(null);
        _refreshFuture = null;
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

// ─── Debug Logger ─────────────────────────────────────────────────────────────

// Paths whose request/response bodies carry a password, PIN, or raw token —
// never printed, even in debug builds, since debug logs are commonly shared
// with QA/testers and are readable by other apps with log access on some
// Android versions.
const _sensitiveBodyPaths = [
  '/auth/login',
  '/auth/signup',
  '/auth/register',
  '/auth/pin-login',
  '/auth/set-pin',
  '/auth/staff/', // covers /auth/staff/:id/pin
  '/auth/reset-password',
  '/auth/refresh-token',
];

// Debug-only request/response logger. Deliberately not Dio's built-in
// LogInterceptor: that logs the live RequestOptions/Response objects
// directly, including the real Authorization header and body — there's no
// way to redact just for the printed line without risking mutating the
// object actually sent over the wire. This prints its own, separately
// redacted string instead, so the real request/response are never touched.
class DebugLogInterceptor extends Interceptor {
  bool _isSensitive(String path) =>
      _sensitiveBodyPaths.any((p) => path.contains(p));

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final sensitive = _isSensitive(options.path);
    final body = sensitive ? '[redacted]' : options.data;
    debugPrint(
      '→ ${options.method} ${options.path} '
      '${options.queryParameters.isNotEmpty ? options.queryParameters : ''} '
      'body=$body',
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final sensitive = _isSensitive(response.requestOptions.path);
    final body = sensitive ? '[redacted]' : response.data;
    debugPrint(
      '← ${response.statusCode} ${response.requestOptions.path} body=$body',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final sensitive = _isSensitive(err.requestOptions.path);
    final body = sensitive ? '[redacted]' : err.response?.data;
    debugPrint(
      '✕ ${err.response?.statusCode} ${err.requestOptions.path} '
      'body=$body error=${err.message}',
    );
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
        // `raw as String?` would throw if the backend ever sends `message`
        // as something other than a String/List/null (e.g. a nested
        // object or number) — falling back on type instead of casting
        // means a malformed error body degrades to the generic message
        // rather than crashing with an unrelated TypeError.
        final msg = switch (raw) {
          String s => s,
          List l => l.join(', '),
          _ => 'An error occurred',
        };
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
    // These four types share one trait real users need explained simply
    // (no internet / cert / cancel) but that's exactly what makes them a
    // dead end for debugging — a connectionError from a genuine dropped
    // wifi connection and one from a CORS rejection or a misconfigured
    // base URL look identical to the person tapping the button. In debug
    // builds, show what Dio actually reported (its message includes the
    // browser's raw fetch/XHR failure text on web, which is often the only
    // place a CORS block ever surfaces) instead of the friendly copy —
    // release builds are unaffected.
    if (kDebugMode) {
      switch (err.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.badCertificate:
          final uri = err.requestOptions.uri;
          return '[DEBUG] ${err.type.name} calling $uri: '
              '${err.message ?? err.error ?? "no further detail from Dio"}';
        case DioExceptionType.cancel:
        case DioExceptionType.badResponse:
        case DioExceptionType.unknown:
          break; // fall through to the normal messages below
      }
    }

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
