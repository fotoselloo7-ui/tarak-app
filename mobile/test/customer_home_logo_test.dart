import 'dart:convert';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/core/widgets/brand_logo.dart';
import 'package:app/features/shared/widgets/common_widgets.dart';
import 'package:app/features/customer/screens/home_sections.dart';
import 'package:app/features/auth/models/user_model.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/customer/appointments/models/customer_appointment_model.dart';
import 'package:app/features/customer/appointments/providers/customer_appointment_providers.dart';
import 'package:app/features/customer/models/service_request_model.dart';
import 'package:app/features/customer/providers/instant_request_provider.dart';
import 'package:app/features/customer/screens/customer_home_tab.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Every endpoint answers with an empty success: the home falls back to its built-in sections.
class _EmptyAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(jsonEncode({'success': true, 'data': []}), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

class _NoRequests extends MyServiceRequestsNotifier {
  @override
  Future<List<ServiceRequestModel>> build() async => const [];
}

class _NoAppointments extends CustomerAppointmentsNotifier {
  @override
  Future<List<CustomerAppointmentModel>> build() async => const [];
}

void main() {
  testWidgets('the Tarak wordmark stays pinned at the top of the customer home while the page scrolls', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The test font is wider than the real one: unrelated cards further down the page may report overflow.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);
    SharedPreferences.setMockInitialValues({});
    final storage = SecureStorageService(secureStorage: _FakeStorage());
    await storage.init();
    final api = ApiClient(storage: storage, customDio: Dio()..httpClientAdapter = _EmptyAdapter());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authNotifierProvider.overrideWith(() => AuthNotifier(
              storage: storage,
              initialState: const AuthState(status: AuthStatus.authenticated, user: UserModel(id: 1, role: 'CUSTOMER', name: 'Test Müşteri', firstName: 'Test', avatarUrl: 'https://example.test/customer-avatar.png')),
            )),
        myServiceRequestsProvider.overrideWith(_NoRequests.new),
        customerAppointmentsProvider.overrideWith(_NoAppointments.new),
      ],
      child: const MaterialApp(home: CustomerHomeTab()),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final logo = find.byType(TarakLogo);
    expect(logo, findsOneWidget);
    final before = tester.getTopLeft(logo);
    expect(before.dy, lessThan(80), reason: 'the wordmark sits in the toolbar row at the top');
    expect(find.text('Merhaba, Test'), findsOneWidget);
    expect(tester.widget<AppAvatar>(find.byType(AppAvatar).first).imageUrl, 'https://example.test/customer-avatar.png');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 300));

    // The page scrolled, the toolbar (wordmark) did not move.
    expect(logo, findsOneWidget);
    expect(tester.getTopLeft(logo), before);
    tester.widget<HomeFinalCta>(find.byType(HomeFinalCta)).onSelect();
    await tester.pumpAndSettle();
    expect(find.text('1. Adres Seçimi'), findsOneWidget);

  });
}
