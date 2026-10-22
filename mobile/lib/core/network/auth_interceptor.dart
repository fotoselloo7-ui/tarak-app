import 'package:dio/dio.dart';
import '../services/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorageService storage;
  final void Function()? onUnauthorized;

  AuthInterceptor({
    required this.storage,
    this.onUnauthorized,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['Accept'] = 'application/json';

    final token = await storage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Notify session invalidation listener
      onUnauthorized?.call();
    }
    return handler.next(err);
  }
}
