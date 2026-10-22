import 'dart:convert';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/network/api_exception.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStorage implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final named = invocation.namedArguments;
    if (invocation.memberName == #read) return Future<String?>.value(data[named[#key] as String]);
    if (invocation.memberName == #write) {
      data[named[#key] as String] = '${named[#value]}';
      return Future<void>.value();
    }
    if (invocation.memberName == #delete) {
      data.remove(named[#key] as String);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

/// Fails the first [failures] requests the way [failWith] says, then answers 200.
class _FlakyAdapter implements HttpClientAdapter {
  final int failures;
  final DioExceptionType type;
  final int? status;
  int calls = 0;
  _FlakyAdapter({required this.failures, this.type = DioExceptionType.connectionError, this.status});

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    if (calls <= failures) {
      if (status != null) {
        return ResponseBody.fromString(jsonEncode({'message': 'down'}), status!, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
      }
      throw DioException(requestOptions: options, type: type, message: 'offline');
    }
    return ResponseBody.fromString(jsonEncode({'success': true}), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late SecureStorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = SecureStorageService(secureStorage: _FakeStorage());
    await storage.init();
  });

  ApiClient client(_FlakyAdapter adapter, {int? retries}) {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = adapter;
    return ApiClient(storage: storage, customDio: dio, retries: retries);
  }

  test('a connection that fails twice and then works never reaches the screen as an error', () async {
    final adapter = _FlakyAdapter(failures: 2);
    final res = await client(adapter, retries: 2).get('/providers');
    expect(res.statusCode, 200);
    expect(adapter.calls, 3);
  });

  test('a POST is retried only while the connection itself cannot be opened', () async {
    final unreachable = _FlakyAdapter(failures: 1);
    await client(unreachable, retries: 2).post('/auth/login', data: {'a': 1});
    expect(unreachable.calls, 2, reason: 'connection refused: the server never saw the request');

    final timedOut = _FlakyAdapter(failures: 1, type: DioExceptionType.receiveTimeout);
    await expectLater(client(timedOut, retries: 2).post('/auth/login', data: {'a': 1}), throwsA(isA<AppException>()));
    expect(timedOut.calls, 1, reason: 'the server may have processed it: never repeated blindly');
  });

  test('a GET also survives a server that is restarting (502 / 503 / 504)', () async {
    final adapter = _FlakyAdapter(failures: 1, status: 503);
    final res = await client(adapter, retries: 2).get('/providers');
    expect(res.statusCode, 200);
    expect(adapter.calls, 2);
  });

  test('after the retries are used up the friendly error is shown, a client error is never retried', () async {
    final down = _FlakyAdapter(failures: 99);
    await expectLater(
      client(down, retries: 2).get('/providers'),
      throwsA(isA<AppException>().having((e) => e.message, 'message', contains('Sunucuya bağlanılamadı'))),
    );
    expect(down.calls, 3);

    final bad = _FlakyAdapter(failures: 5, status: 422);
    await expectLater(client(bad, retries: 2).get('/providers'), throwsA(isA<AppException>()));
    expect(bad.calls, 1);
  });

  test('injected Dio instances (the other tests) do not retry unless asked to', () async {
    final adapter = _FlakyAdapter(failures: 1);
    await expectLater(client(adapter).get('/providers'), throwsA(isA<AppException>()));
    expect(adapter.calls, 1);
  });
}
