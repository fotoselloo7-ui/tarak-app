import 'dart:async';
import 'dart:convert';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/network/api_exception.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/models/user_model.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/customer/models/customer_address.dart';
import 'package:app/features/customer/providers/home_content_providers.dart';
import 'package:app/features/customer/providers/instant_request_provider.dart';
import 'package:app/features/customer/providers/provider_list_origin.dart';
import 'package:app/features/shared/widgets/avatar_picker.dart';
import 'package:app/features/shared/widgets/common_widgets.dart';
import 'package:app/features/chat/models/conversation_model.dart';
import 'package:app/features/chat/widgets/conversation_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _customer = UserModel(id: 1, role: 'CUSTOMER', name: 'Ayşe Test');
const _mahmutlar = CustomerAddress(
  id: 1,
  isDefault: true,
  latitude: 36.49,
  longitude: 32.09,
);
const _sisli = CustomerAddress(
  id: 1,
  isDefault: true,
  latitude: 41.06,
  longitude: 28.99,
);
const _auth = AuthState(status: AuthStatus.authenticated, user: _customer);

class _Locator implements DeviceLocator {
  final Completer<ListOrigin> result = Completer<ListOrigin>();
  @override
  Future<ListOrigin> locate() => result.future;
}

class _Adapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> requests = [];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(Map<String, dynamic>.from(options.queryParameters));
    return ResponseBody.fromString(
      jsonEncode({
        'data': [
          {'id': 2, 'distance_km': 1.2},
        ],
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

void main() {
  test('default address refresh changes the origin and the real nearby request parameters', () async {
    var addresses = <CustomerAddress>[_mahmutlar];
    final adapter = _Adapter();
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(
          () => AuthNotifier(initialState: _auth),
        ),
        customerAddressesProvider.overrideWith((ref) async => addresses),
        apiClientProvider.overrideWithValue(
          ApiClient(
            storage: SecureStorageService(),
            customDio: Dio()..httpClientAdapter = adapter,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(listOriginProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(customerAddressesProvider.future);
    var origin = container.read(listOriginProvider)!;
    final old = await container.read(
      nearbyHomeProvidersProvider((
        latitude: origin.lat,
        longitude: origin.lng,
        radiusKm: 10,
        customerAddressId: null,
      )).future,
    );
    expect(old.single['distance_km'], 1.2);
    expect(adapter.requests.single, {
      'lat': 36.49,
      'lng': 32.09,
      'radius_km': 10,
    });
    addresses = [_sisli];
    container.invalidate(customerAddressesProvider);
    expect(
      container.read(listOriginProvider),
      isNull,
      reason: 'old city is unavailable during refresh',
    );
    await container.read(customerAddressesProvider.future);
    origin = container.read(listOriginProvider)!;
    await container.read(
      nearbyHomeProvidersProvider((
        latitude: origin.lat,
        longitude: origin.lng,
        radiusKm: 10,
        customerAddressId: null,
      )).future,
    );
    expect(adapter.requests.last, {
      'lat': 41.06,
      'lng': 28.99,
      'radius_km': 10,
    });
    expect(adapter.requests.length, 2);
  });

  test('coordinate-less default cannot select a previous address', () async {
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(
          () => AuthNotifier(initialState: _auth),
        ),
        customerAddressesProvider.overrideWith(
          (ref) async => const [
            CustomerAddress(id: 1, latitude: 36.49, longitude: 32.09),
            CustomerAddress(id: 2, isDefault: true),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(customerAddressesProvider.future);
    expect(container.read(listOriginProvider), isNull);
  });

  test(
    'explicit device origin wins, and a later account never inherits it',
    () async {
      final locator = _Locator();
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => AuthNotifier(initialState: _auth),
          ),
          customerAddressesProvider.overrideWith((ref) async => const [_sisli]),
          deviceLocatorProvider.overrideWithValue(locator),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(listOriginProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(customerAddressesProvider.future);
      final request = container
          .read(providerListOriginProvider.notifier)
          .useDevice();
      locator.result.complete(
        const ListOrigin(lat: 39.9, lng: 32.8, fromDevice: true),
      );
      await request;
      expect(container.read(listOriginProvider)?.fromDevice, isTrue);
      container
          .read(authNotifierProvider.notifier)
          .setTestState(const AuthState(status: AuthStatus.unauthenticated));
      expect(container.read(listOriginProvider), isNull);
    },
  );

  test('a device response arriving after logout is discarded', () async {
    final locator = _Locator();
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(
          () => AuthNotifier(initialState: _auth),
        ),
        deviceLocatorProvider.overrideWithValue(locator),
      ],
    );
    addTearDown(container.dispose);
    final request = container
        .read(providerListOriginProvider.notifier)
        .useDevice();
    container
        .read(authNotifierProvider.notifier)
        .setTestState(const AuthState(status: AuthStatus.unauthenticated));
    locator.result.complete(
      const ListOrigin(lat: 39, lng: 32, fromDevice: true),
    );
    await request;
    expect(container.read(providerListOriginProvider).device, isNull);
  });

  test('avatar upload result updates auth immediately and can be removed', () {
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(
          () => AuthNotifier(initialState: _auth),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(authNotifierProvider.notifier)
        .updateAvatarUrl('https://tarak.app/api/media/avatars/1/a.png');
    expect(
      container.read(authNotifierProvider).user?.avatarUrl,
      endsWith('/a.png'),
    );
    container.read(authNotifierProvider.notifier).updateAvatarUrl(null);
    expect(container.read(authNotifierProvider).user?.avatarUrl, isNull);
  });

  testWidgets(
    'broken avatar URLs fall back to initials without uncaught errors',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  AppAvatar(
                    name: 'Ayşe Test',
                    imageUrl: 'https://example.test/missing.png',
                  ),
                  AvatarPicker(
                    avatarUrl: 'https://example.test/forbidden.png',
                    name: 'Ayşe Test',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(find.text('AT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('chat shows initials when its avatar returns an error', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ConversationCard(
      conversation: const ConversationModel(id: 1, resourceType: 'INSTANT_REQUEST', resourceId: 1,
        customerUserId: 1, providerUserId: 2, status: 'ACTIVE',
        otherParty: OtherPartyModel(id: 2, name: 'Veli Test', avatarUrl: 'https://example.test/broken-chat.png')),
      onTap: () {},
    ))));
    await tester.pumpAndSettle();
    expect(find.text('V'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('framework 429 uses Retry-After in Turkish while specific business errors survive', () {
    AppException parse(String message) {
      final request = RequestOptions(path: '/auth/login');
      return AppException.fromDioError(
        DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: request,
            statusCode: 429,
            data: {'message': message},
            headers: Headers.fromMap({
              'retry-after': ['37'],
            }),
          ),
        ),
      );
    }

    expect(
      parse('Too Many Attempts.').message,
      'Çok fazla deneme yapıldı. 37 saniye sonra tekrar deneyin.',
    );
    expect(
      parse('Kod kilitlendi. Beş dakika bekleyin.').message,
      'Kod kilitlendi. Beş dakika bekleyin.',
    );
  });
}
