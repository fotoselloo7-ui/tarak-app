import 'package:dio/dio.dart';

final RegExp _loopbackOrigin = RegExp(r'^http://(127\.0\.0\.1|localhost)(:\d+)?(?=/)');

bool isLoopbackHost(String host) => host == '127.0.0.1' || host == 'localhost' || host == '::1';

/// Rewrites backend media URLs that point at the server's own loopback address
/// (`http://127.0.0.1:8010/storage/...`) to [targetOrigin] (for the Android
/// emulator: `http://10.0.2.2:8010`). The backend builds these URLs from its
/// APP_URL, which a phone or emulator cannot reach. Strings, lists and maps are
/// walked recursively; everything else is returned untouched.
dynamic rewriteLoopbackMediaHosts(dynamic data, String targetOrigin) {
  if (data is String) {
    return data.startsWith('http://') ? data.replaceFirst(_loopbackOrigin, targetOrigin) : data;
  }
  if (data is List) {
    return [for (final item in data) rewriteLoopbackMediaHosts(item, targetOrigin)];
  }
  // Keep the JSON map type: callers check `is Map<String, dynamic>`.
  if (data is Map<String, dynamic>) {
    return <String, dynamic>{for (final e in data.entries) e.key: rewriteLoopbackMediaHosts(e.value, targetOrigin)};
  }
  if (data is Map) {
    return <dynamic, dynamic>{for (final e in data.entries) e.key: rewriteLoopbackMediaHosts(e.value, targetOrigin)};
  }
  return data;
}

/// Debug-only interceptor: lets images served by a local backend load on an
/// emulator/device that reaches the host through another address.
class DevMediaHostInterceptor extends Interceptor {
  final String targetOrigin;

  DevMediaHostInterceptor(this.targetOrigin);

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    response.data = rewriteLoopbackMediaHosts(response.data, targetOrigin);
    handler.next(response);
  }
}
