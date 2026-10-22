import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/network/dev_media_host.dart';

void main() {
  const emulator = 'http://10.0.2.2:8010';

  group('rewriteLoopbackMediaHosts', () {
    test('rewrites loopback media URLs, including nested maps and lists', () {
      final data = {
        'data': {
          'avatar_url': 'http://127.0.0.1:8010/storage/demo/avatars/a.png',
          'cover_url': 'http://localhost:8010/storage/c.jpg',
          'gallery': ['http://127.0.0.1:8010/storage/1.jpg', 'http://127.0.0.1:8010/storage/2.jpg'],
          'name': 'Berber Ali',
        },
      };

      final out = rewriteLoopbackMediaHosts(data, emulator) as Map;

      expect(out['data']['avatar_url'], 'http://10.0.2.2:8010/storage/demo/avatars/a.png');
      expect(out['data']['cover_url'], 'http://10.0.2.2:8010/storage/c.jpg');
      expect(out['data']['gallery'], ['http://10.0.2.2:8010/storage/1.jpg', 'http://10.0.2.2:8010/storage/2.jpg']);
      expect(out['data']['name'], 'Berber Ali');
    });

    test('leaves real hosts, https URLs, plain text and non-strings alone', () {
      expect(rewriteLoopbackMediaHosts('https://cdn.example.com/x.jpg', emulator), 'https://cdn.example.com/x.jpg');
      expect(rewriteLoopbackMediaHosts('http://example.com/x.jpg', emulator), 'http://example.com/x.jpg');
      expect(rewriteLoopbackMediaHosts('Bağlantı: http://127.0.0.1:8010/x', emulator), 'Bağlantı: http://127.0.0.1:8010/x');
      expect(rewriteLoopbackMediaHosts(42, emulator), 42);
      expect(rewriteLoopbackMediaHosts(null, emulator), isNull);
      expect(rewriteLoopbackMediaHosts(true, emulator), true);
    });

    test('keeps JSON map and list types so `is Map<String, dynamic>` checks still pass', () {
      final out = rewriteLoopbackMediaHosts(<String, dynamic>{
        'token': 'abc',
        'user': <String, dynamic>{'avatar_url': 'http://127.0.0.1:8010/a.png'},
      }, emulator);

      expect(out is Map<String, dynamic>, isTrue);
      expect((out as Map<String, dynamic>)['user'] is Map<String, dynamic>, isTrue);
    });

    test('works without a port', () {
      expect(rewriteLoopbackMediaHosts('http://127.0.0.1/storage/a.png', 'http://10.0.2.2'), 'http://10.0.2.2/storage/a.png');
    });
  });

  test('isLoopbackHost', () {
    expect(isLoopbackHost('127.0.0.1'), isTrue);
    expect(isLoopbackHost('localhost'), isTrue);
    expect(isLoopbackHost('10.0.2.2'), isFalse);
    expect(isLoopbackHost('api.tarak.app'), isFalse);
  });

  test('DevMediaHostInterceptor rewrites response bodies', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:8010/api'))
      ..interceptors.add(DevMediaHostInterceptor(emulator))
      ..httpClientAdapter = _Adapter();

    final res = await dio.get('/providers/1');

    expect(res.data is Map<String, dynamic>, isTrue);
    expect(res.data['data']['avatar_url'], 'http://10.0.2.2:8010/storage/demo/avatars/a.png');
  });
}

class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(
      jsonEncode({
        'data': {'avatar_url': 'http://127.0.0.1:8010/storage/demo/avatars/a.png'},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
