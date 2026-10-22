import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/provider/instant/providers/provider_instant_providers.dart';

class _Adapter implements HttpClientAdapter {
  final FutureOr<ResponseBody> Function(RequestOptions) handler;
  _Adapter(this.handler);
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream,
      Future<void>? cancelFuture) async => handler(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody _body(dynamic data, [int status = 200]) => ResponseBody.fromString(
    jsonEncode(data), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

void main() {
  test('polling retains mounted detail data while awaiting canonical response', () async {
    var calls = 0;
    final response = Completer<ResponseBody>();
    final dio = Dio()..httpClientAdapter = _Adapter((options) {
      return calls++ == 0
          ? _body({'data': {'id': 238, 'status': 'ASSIGNED', 'services': []}})
          : response.future;
    });
    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(ApiClient(storage: SecureStorageService(), customDio: dio)),
    ]);
    addTearDown(container.dispose);
    final provider = activeJobDetailNotifierProvider(238);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);
    final refresh = container.read(provider.notifier).refresh();
    expect(container.read(provider).isLoading, isFalse);
    expect(container.read(provider).value?.isAssigned, isTrue);
    response.complete(_body({'data': {'id': 238, 'status': 'IN_PROGRESS', 'services': []}}));
    await refresh;
    expect(container.read(provider).value?.status, 'IN_PROGRESS');
  });

  test('leaving job detail drops exact address and reentry reads revoked state', () async {
    var shared = true;
    var calls = 0;
    final dio = Dio()..httpClientAdapter = _Adapter((options) {
      calls++;
      return shared ? _body({'data': {'resource_id': 238, 'exact_location': {'street': 'Private address'}}})
          : _body({'message': 'Konum paylaşılmıyor'}, 404);
    });
    final client = ApiClient(storage: SecureStorageService(), customDio: dio);
    final container = ProviderContainer(overrides: [apiClientProvider.overrideWithValue(client)]);
    addTearDown(container.dispose);
    final provider = transientSharedLocationProvider(238);
    final first = container.listen(provider, (_, _) {});
    expect((await container.read(provider.future))?.street, 'Private address');
    first.close();
    await container.pump();
    expect(container.exists(provider), isFalse);
    shared = false;
    final second = container.listen(provider, (_, _) {});
    addTearDown(second.close);
    expect(await container.read(provider.future), isNull);
    expect(calls, 2);
  });

  test('opening assigned job after accepting never reuses OPEN detail', () async {
    var status = 'OPEN';
    final dio = Dio()..httpClientAdapter = _Adapter((options) =>
        _body({'data': {'id': 238, 'status': status, 'services': []}}));
    final client = ApiClient(storage: SecureStorageService(), customDio: dio);
    final container = ProviderContainer(overrides: [apiClientProvider.overrideWithValue(client)]);
    addTearDown(container.dispose);
    final provider = activeJobDetailNotifierProvider(238);
    final first = container.listen(provider, (_, _) {});
    expect((await container.read(provider.future)).isOpen, isTrue);
    first.close();
    await container.pump();
    status = 'ASSIGNED';
    final second = container.listen(provider, (_, _) {});
    addTearDown(second.close);
    expect((await container.read(provider.future)).isAssigned, isTrue);
  });
}
