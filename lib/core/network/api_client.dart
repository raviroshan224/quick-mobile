import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../models/app_exception.dart';
import '../utils/env_config.dart';
import 'api_interceptors.dart';
import 'dns_fallback_config.dart';

// Callback set by AuthNotifier so the interceptor can signal logout.
void Function()? _unauthenticatedCallback;
void registerUnauthenticatedCallback(void Function() cb) {
  _unauthenticatedCallback = cb;
}

final _storage = const FlutterSecureStorage();

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = () {
    try {
      return EnvConfig.instance.apiBaseUrl;
    } catch (_) {
      return AppConstants.defaultBaseUrl;
    }
  }();

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  configureDnsFallback(dio);

  // Bare Dio instance for refresh calls (no auth interceptors to avoid cycles).
  final refreshDio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  configureDnsFallback(refreshDio);

  dio.interceptors.addAll([
    RetryInterceptor(dio),
    ConnectivityInterceptor(ref),
    AuthInterceptor(_storage),
    RefreshInterceptor(
      dio: refreshDio,
      storage: _storage,
      onUnauthenticated: () => _unauthenticatedCallback?.call(),
      ref: ref,
    ),
    ErrorInterceptor(),
    if (kDebugMode) DebugLogInterceptor(),
  ]);

  return dio;
});

// ─── ApiClient ────────────────────────────────────────────────────────────────

class ApiClient {
  ApiClient(this._dio);
  final Dio _dio;

  // Unwraps the { success, data, timestamp } envelope automatically.
  dynamic _unwrap(Response<dynamic> res) {
    final body = res.data;
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  AppException _toAppException(DioException e) {
    final inner = e.error;
    if (inner is AppException) return inner;
    return AppException(
      e.message ?? 'Network error',
      statusCode: e.response?.statusCode,
    );
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final res = await _dio.get(path, queryParameters: queryParameters);
      return _unwrap(res);
    } on DioException catch (e) {
      throw _toAppException(e);
    }
  }

  Future<dynamic> post(String path, {dynamic data, Map<String, dynamic>? headers}) async {
    try {
      final res = await _dio.post(
        path,
        data: data,
        options: headers != null ? Options(headers: headers) : null,
      );
      return _unwrap(res);
    } on DioException catch (e) {
      throw _toAppException(e);
    }
  }

  Future<dynamic> patch(String path, {dynamic data}) async {
    try {
      final res = await _dio.patch(path, data: data);
      return _unwrap(res);
    } on DioException catch (e) {
      throw _toAppException(e);
    }
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    try {
      final res = await _dio.put(path, data: data);
      return _unwrap(res);
    } on DioException catch (e) {
      throw _toAppException(e);
    }
  }

  Future<dynamic> delete(String path, {dynamic data}) async {
    try {
      final res = await _dio.delete(path, data: data);
      return _unwrap(res);
    } on DioException catch (e) {
      throw _toAppException(e);
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.read(dioProvider));
});
