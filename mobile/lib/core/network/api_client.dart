import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/env_config.dart';
import 'dev_media_host.dart';
import '../services/secure_storage_service.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

class ApiClient {
  final Dio _dio;

  /// How many times a request that hit a transient connection problem is repeated before the error reaches the
  /// screen (see [_isTransient]). Off for injected Dio instances (tests) unless asked for.
  final int _retries;

  ApiClient({
    required SecureStorageService storage,
    void Function()? onUnauthorized,
    Dio? customDio,
    String? baseUrl,
    int? retries,
  })  : _retries = retries ?? (customDio == null ? 2 : 0),
        _dio = customDio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? EnvConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                headers: {
                  'Accept': 'application/json',
                },
              ),
            ) {
    if (customDio == null) {
      _dio.interceptors.add(
        AuthInterceptor(
          storage: storage,
          onUnauthorized: onUnauthorized,
        ),
      );
      // Local development only: a backend on this machine hands out media URLs
      // with its own loopback address, which an emulator/device cannot open.
      final api = Uri.tryParse(_dio.options.baseUrl);
      if (!kReleaseMode && api != null && api.host.isNotEmpty && !isLoopbackHost(api.host)) {
        _dio.interceptors.add(DevMediaHostInterceptor(api.origin));
      }
    }
  }

  Dio get dio => _dio;

  /// Transient problems (the server was a moment away, a worker restarted, a mobile data hiccup) are retried
  /// quietly before an error screen shows. Only requests that cannot have been processed are repeated: the
  /// connection never opened (any method), or for a GET also a connect / read timeout and 502 / 503 / 504.
  bool _isTransient(String method, DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return method == 'GET';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        return method == 'GET' && (status == 502 || status == 503 || status == 504);
      default:
        return false;
    }
  }

  Future<Response<T>> _send<T>(String method, Future<Response<T>> Function() request) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await request();
      } on DioException catch (e) {
        if (attempt >= _retries || !_isTransient(method, e)) rethrow;
        await Future<void>.delayed(Duration(milliseconds: attempt == 0 ? 600 : 1500));
      }
    }
  }

  void _validateResponse(dynamic data) {
    if (data is String) {
      final str = data.trimLeft();
      if (str.startsWith('<') || str.contains('<html') || str.contains('<br') || str.contains('Fatal error') || str.contains('<!DOCTYPE')) {
        throw const AppException(
          message: 'Sunucu geçici olarak kullanılamıyor. Lütfen daha sonra tekrar deneyin.',
          statusCode: 502,
        );
      }
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _send('GET', () => _dio.get<T>(path, queryParameters: queryParameters, options: options));
      _validateResponse(response.data);
      return response;
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _send('POST', () => _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options));
      _validateResponse(response.data);
      return response;
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _send('PUT', () => _dio.put<T>(path, data: data, queryParameters: queryParameters, options: options));
      _validateResponse(response.data);
      return response;
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _send('PATCH', () => _dio.patch<T>(path, data: data, queryParameters: queryParameters, options: options));
      _validateResponse(response.data);
      return response;
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _send('DELETE', () => _dio.delete<T>(path, data: data, queryParameters: queryParameters, options: options));
      _validateResponse(response.data);
      return response;
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }
}
