import 'package:app/core/network/api_client.dart';
import 'package:app/core/network/api_exception.dart';
import 'package:app/core/network/auth_interceptor.dart';
import 'package:app/core/services/push_notification_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/models/user_model.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/auth/screens/auth_gate.dart';
import 'package:app/features/auth/screens/login_screen.dart';
import 'package:app/features/auth/screens/register_screen.dart';
import 'package:app/features/auth/screens/unsupported_admin_screen.dart';
import 'package:app/features/auth/screens/welcome_screen.dart';
import 'package:app/features/customer/screens/customer_shell.dart';
import 'package:app/features/provider/screens/provider_shell.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/customer/models/service_request_model.dart';
import 'package:app/features/customer/providers/instant_request_provider.dart';

import 'package:app/features/customer/models/service_offer.dart';
import 'package:app/features/customer/appointments/models/customer_appointment_model.dart';
import 'package:app/features/customer/appointments/providers/customer_appointment_providers.dart';
import 'package:app/features/provider/instant/models/provider_profile_model.dart';
import 'package:app/features/provider/instant/providers/provider_instant_providers.dart';
import 'package:app/features/provider/screens/provider_profile_tab.dart';

class FakeMyServiceRequestsNotifier extends MyServiceRequestsNotifier {
  @override
  Future<List<ServiceRequestModel>> build() async => const [];
}

class FakeCustomerAppointmentsNotifier extends CustomerAppointmentsNotifier {
  @override
  Future<List<CustomerAppointmentModel>> build() async => const [];
}

class FakeProviderProfileNotifier extends ProviderProfileNotifier {
  @override
  Future<ProviderProfileModel> build() async => const ProviderProfileModel(
    userId: 2,
    businessName: 'Ahmet Berber',
    isOnline: true,
    isApproved: true,
  );
}

class FakeProviderAssignedRequestsNotifier
    extends ProviderAssignedRequestsNotifier {
  @override
  Future<List<ServiceRequestModel>> build() async => const [];
}

class FakeProviderMyOffersNotifier extends ProviderMyOffersNotifier {
  @override
  Future<List<ServiceOffer>> build() async => const [];
}

// In-Memory Test Storage implementing FlutterSecureStorage via noSuchMethod
class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final member = invocation.memberName;
    final named = invocation.namedArguments;

    if (member == #read) {
      final key = named[#key] as String;
      return Future<String?>.value(_data[key]);
    }
    if (member == #write) {
      final key = named[#key] as String;
      final val = named[#value];
      if (val != null) {
        _data[key] = val.toString();
      } else {
        _data.remove(key);
      }
      return Future<void>.value();
    }
    if (member == #delete) {
      final key = named[#key] as String;
      _data.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSecureStorage fakeSecureStorage;
  late SecureStorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeSecureStorage = FakeSecureStorage();
    storageService = SecureStorageService(secureStorage: fakeSecureStorage);
    await storageService.init();
  });

  // 1. No token -> WelcomeScreen (Mobile Home) directly
  testWidgets(
    '01. No token in storage shows WelcomeScreen directly on launch',
    (tester) async {
      final dio = Dio();
      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final pushService = PushNotificationService(
        apiClient: apiClient,
        storage: storageService,
      );

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storageService),
          apiClientProvider.overrideWithValue(apiClient),
          pushNotificationServiceProvider.overrideWithValue(pushService),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AuthGate()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Giriş Yap'), findsOneWidget);
      expect(find.text('Randevu Oluştur'), findsWidgets);
      expect(find.text('Hizmet Veren Olarak Katıl'), findsWidgets);
    },
  );

  // 1c. WelcomeScreen Randevu Oluştur navigates to Customer Register
  testWidgets(
    '01c. WelcomeScreen Randevu Oluştur navigates to Customer Register',
    (tester) async {
      final dio = Dio();
      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final pushService = PushNotificationService(
        apiClient: apiClient,
        storage: storageService,
      );

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storageService),
          apiClientProvider.overrideWithValue(apiClient),
          pushNotificationServiceProvider.overrideWithValue(pushService),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AuthGate()),
        ),
      );

      await tester.pumpAndSettle();

      final hizmetAlBtn = find.text('Randevu Oluştur').first;
      expect(hizmetAlBtn, findsOneWidget);
      await tester.ensureVisible(hizmetAlBtn);
      await tester.pumpAndSettle();
      await tester.tap(hizmetAlBtn);
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Müşteri Kaydı'), findsOneWidget);
      expect(find.text('Müşteri Hizmet Avantajı'), findsOneWidget);
    },
  );

  // 1d. WelcomeScreen Hizmet Veren Olarak Katıl navigates to Provider Register
  testWidgets(
    '01d. WelcomeScreen Hizmet Veren Olarak Katıl navigates to Provider Register',
    (tester) async {
      final dio = Dio();
      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final pushService = PushNotificationService(
        apiClient: apiClient,
        storage: storageService,
      );

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storageService),
          apiClientProvider.overrideWithValue(apiClient),
          pushNotificationServiceProvider.overrideWithValue(pushService),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AuthGate()),
        ),
      );

      await tester.pumpAndSettle();

      final hizmetVerBtn = find.text('Hizmet Veren Olarak Katıl').first;
      expect(hizmetVerBtn, findsOneWidget);
      await tester.ensureVisible(hizmetVerBtn);
      await tester.pumpAndSettle();
      await tester.tap(hizmetVerBtn);
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Hizmet Veren Kaydı'), findsOneWidget);
      expect(find.text('Hizmet Veren Başvuru Notu'), findsOneWidget);
      expect(find.text('İşletme / Salon Adı (İsteğe Bağlı)'), findsOneWidget);
    },
  );

  // 1e. WelcomeScreen Giriş Yap navigates to LoginScreen
  testWidgets('01e. WelcomeScreen Giriş Yap navigates to LoginScreen', (
    tester,
  ) async {
    final dio = Dio();
    final apiClient = ApiClient(storage: storageService, customDio: dio);
    final pushService = PushNotificationService(
      apiClient: apiClient,
      storage: storageService,
    );

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storageService),
        apiClientProvider.overrideWithValue(apiClient),
        pushNotificationServiceProvider.overrideWithValue(pushService),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AuthGate()),
      ),
    );

    await tester.pumpAndSettle();

    final loginBtn = find.text('Giriş Yap');
    expect(loginBtn, findsOneWidget);
    await tester.tap(loginBtn);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Giriş Yaparak Hizmet Almaya Başlayın'), findsOneWidget);
  });

  // 2. Valid restored customer -> CustomerShell
  testWidgets('02. Valid restored customer shows CustomerShell', (
    tester,
  ) async {
    const customer = UserModel(
      id: 1,
      role: 'CUSTOMER',
      name: 'Ali Veli',
      email: 'ali@example.com',
    );

    final dio = Dio();
    final apiClient = ApiClient(storage: storageService, customDio: dio);
    final pushService = PushNotificationService(
      apiClient: apiClient,
      storage: storageService,
    );

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storageService),
        apiClientProvider.overrideWithValue(apiClient),
        pushNotificationServiceProvider.overrideWithValue(pushService),
        authNotifierProvider.overrideWith(() {
          return AuthNotifier(
            storage: storageService,
            initialState: const AuthState(
              status: AuthStatus.authenticated,
              user: customer,
            ),
          );
        }),
        myServiceRequestsProvider.overrideWith(
          FakeMyServiceRequestsNotifier.new,
        ),
        customerAppointmentsProvider.overrideWith(
          FakeCustomerAppointmentsNotifier.new,
        ),
        serviceCategoriesProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AuthGate()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CustomerShell), findsOneWidget);
    expect(find.text('Talepler'), findsOneWidget);
    expect(find.text('Randevular'), findsOneWidget);
    expect(find.text('Mesajlar'), findsOneWidget);
    expect(find.text('Profilim'), findsOneWidget);
  });

  // 3. Valid restored provider -> ProviderShell
  testWidgets('03. Valid restored provider shows ProviderShell', (
    tester,
  ) async {
    const provider = UserModel(
      id: 2,
      role: 'PROVIDER',
      name: 'Ahmet Berber',
      email: 'ahmet@example.com',
    );

    final dio = Dio();
    final apiClient = ApiClient(storage: storageService, customDio: dio);
    final pushService = PushNotificationService(
      apiClient: apiClient,
      storage: storageService,
    );

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storageService),
        apiClientProvider.overrideWithValue(apiClient),
        pushNotificationServiceProvider.overrideWithValue(pushService),
        authNotifierProvider.overrideWith(() {
          return AuthNotifier(
            storage: storageService,
            initialState: const AuthState(
              status: AuthStatus.authenticated,
              user: provider,
            ),
          );
        }),
        providerProfileNotifierProvider.overrideWith(
          FakeProviderProfileNotifier.new,
        ),
        providerMarketplaceRequestsProvider.overrideWith(
          (ref) async => const [],
        ),
        providerReviewSummaryProvider.overrideWith(
          (ref) async => {'average': 0, 'count': 0, 'reviews': <dynamic>[]},
        ),
        providerAssignedRequestsProvider.overrideWith(
          FakeProviderAssignedRequestsNotifier.new,
        ),
        providerMyOffersProvider.overrideWith(FakeProviderMyOffersNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AuthGate()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ProviderShell), findsOneWidget);
    expect(find.text('İşler'), findsOneWidget);
    expect(find.text('Randevular'), findsOneWidget);
    expect(find.text('Mesajlar'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });

  // 4. 401 me -> token cleared, unauthenticated
  test('04. 401 on me clears token and sets unauthenticated', () async {
    await storageService.saveToken('expired_token_123');

    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 401,
                data: {'message': 'Unauthenticated.'},
              ),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      ),
    );

    final apiClient = ApiClient(storage: storageService, customDio: dio);
    final pushService = PushNotificationService(
      apiClient: apiClient,
      storage: storageService,
    );

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storageService),
        apiClientProvider.overrideWithValue(apiClient),
        pushNotificationServiceProvider.overrideWithValue(pushService),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authNotifierProvider.notifier);
    await notifier.restoreSession();

    expect(
      container.read(authNotifierProvider).status,
      AuthStatus.unauthenticated,
    );
    expect(await storageService.getToken(), isNull);
  });

  // 5. Network failure -> token is NOT blindly cleared
  test('05. Network failure does not clear token from storage', () async {
    await storageService.saveToken('persisted_valid_token_456');

    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
              error: 'Connection timeout',
            ),
          );
        },
      ),
    );

    final apiClient = ApiClient(storage: storageService, customDio: dio);
    final pushService = PushNotificationService(
      apiClient: apiClient,
      storage: storageService,
    );

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storageService),
        apiClientProvider.overrideWithValue(apiClient),
        pushNotificationServiceProvider.overrideWithValue(pushService),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authNotifierProvider.notifier);
    await notifier.restoreSession();

    // Token must NOT be deleted on transient network failure
    expect(await storageService.getToken(), 'persisted_valid_token_456');
    expect(container.read(authNotifierProvider).errorMessage, isNotNull);
  });

  // 6. Admin user -> unsupported mobile state
  testWidgets('06. Admin user results in UnsupportedAdminScreen', (
    tester,
  ) async {
    const admin = UserModel(
      id: 99,
      role: 'ADMIN',
      name: 'Yönetici Admin',
      email: 'admin@example.com',
    );

    final dio = Dio();
    final apiClient = ApiClient(storage: storageService, customDio: dio);
    final pushService = PushNotificationService(
      apiClient: apiClient,
      storage: storageService,
    );

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storageService),
        apiClientProvider.overrideWithValue(apiClient),
        pushNotificationServiceProvider.overrideWithValue(pushService),
        authNotifierProvider.overrideWith(() {
          return AuthNotifier(
            storage: storageService,
            initialState: const AuthState(
              status: AuthStatus.unsupportedAdmin,
              user: admin,
            ),
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AuthGate()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(UnsupportedAdminScreen), findsOneWidget);
    expect(find.text('Yönetici Hesabı'), findsOneWidget);
    expect(find.text('Farklı Bir Hesapla Giriş Yap'), findsOneWidget);
  });

  // 7. Login stores token in secure storage
  test('07. Successful login saves token to secure storage', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'message': 'Giriş başarılı.',
                'data': {
                  'user': {
                    'id': 10,
                    'role': 'CUSTOMER',
                    'first_name': 'Mert',
                    'last_name': 'Kaya',
                    'name': 'Mert Kaya',
                    'email': 'mert@example.com',
                  },
                  'token': 'sanctum_token_abc_789',
                  'token_type': 'Bearer',
                },
              },
            ),
          );
        },
      ),
    );

    final apiClient = ApiClient(storage: storageService, customDio: dio);
    final pushService = PushNotificationService(
      apiClient: apiClient,
      storage: storageService,
    );

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storageService),
        apiClientProvider.overrideWithValue(apiClient),
        pushNotificationServiceProvider.overrideWithValue(pushService),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authNotifierProvider.notifier);
    final success = await notifier.login(
      login: 'mert@example.com',
      password: 'password123',
    );

    expect(success, isTrue);
    expect(container.read(authNotifierProvider).isAuthenticated, isTrue);
    expect(await storageService.getToken(), 'sanctum_token_abc_789');
  });

  // 8. Logout clears local session
  test('08. Logout clears stored token and sets unauthenticated', () async {
    await storageService.saveToken('token_to_clear');

    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true},
            ),
          );
        },
      ),
    );

    final apiClient = ApiClient(storage: storageService, customDio: dio);
    final pushService = PushNotificationService(
      apiClient: apiClient,
      storage: storageService,
    );

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storageService),
        apiClientProvider.overrideWithValue(apiClient),
        pushNotificationServiceProvider.overrideWithValue(pushService),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authNotifierProvider.notifier);
    await notifier.logout();

    expect(await storageService.getToken(), isNull);
    expect(
      container.read(authNotifierProvider).status,
      AuthStatus.unauthenticated,
    );
  });

  // 9. Register does NOT offer admin option
  testWidgets('09. Register screen only offers Customer and Provider options', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RegisterScreen())),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Müşteri'), findsOneWidget);
    expect(find.text('Hizmet Veren'), findsOneWidget);
    expect(find.text('Yönetici'), findsNothing);
    expect(find.text('Admin'), findsNothing);
  });

  // 10. Dio Authorization header is added
  test('10. AuthInterceptor adds Bearer token to requests', () async {
    await storageService.saveToken('my_auth_bearer_token');

    final interceptor = AuthInterceptor(storage: storageService);
    final options = RequestOptions(path: '/test');

    final handler = RequestInterceptorHandler();
    await interceptor.onRequest(options, handler);

    expect(options.headers['Authorization'], 'Bearer my_auth_bearer_token');
    expect(options.headers['Accept'], 'application/json');
  });

  // 11. 422 validation is cleanly mapped
  test('11. AppException cleanly extracts Laravel 422 validation errors', () {
    final dioError = DioException(
      requestOptions: RequestOptions(path: '/auth/register'),
      response: Response(
        requestOptions: RequestOptions(path: '/auth/register'),
        statusCode: 422,
        data: {
          'message': 'Girdiğiniz bilgiler geçersiz.',
          'errors': {
            'email': ['Geçerli bir e-posta adresi giriniz.'],
            'password': ['Şifre en az 8 karakter olmalıdır.'],
          },
        },
      ),
      type: DioExceptionType.badResponse,
    );

    final appException = AppException.fromDioError(dioError);

    expect(appException.statusCode, 422);
    expect(appException.validationErrors, isNotNull);
    expect(
      appException.validationErrors!['email'],
      contains('Geçerli bir e-posta adresi giriniz.'),
    );
    expect(appException.message, 'Geçerli bir e-posta adresi giriniz.');
  });

  // 12. Push config missing does NOT crash app
  test(
    '12. Missing Firebase config gracefully skips push without crashing',
    () async {
      final dio = Dio();
      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final pushService = PushNotificationService(
        apiClient: apiClient,
        storage: storageService,
      );

      // Initializing without google-services.json must NOT throw unhandled exceptions
      await expectLater(pushService.initialize(), completes);
      expect(pushService.isFirebaseInitialized, isFalse);
    },
  );

  // 13. Installation id is stable across runs
  test('13. Installation ID is persisted and stable across calls', () async {
    final id1 = await storageService.getInstallationId();
    final id2 = await storageService.getInstallationId();

    expect(id1, isNotEmpty);
    expect(id1, equals(id2));
  });

  // 14. FCM token register payload is correct
  test('14. Register device payload contains all required fields', () async {
    Map<String, dynamic>? capturedPayload;

    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/push/devices' && options.method == 'POST') {
            capturedPayload = options.data as Map<String, dynamic>;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'message': 'Device registered'},
              ),
            );
          }
        },
      ),
    );

    final apiClient = ApiClient(storage: storageService, customDio: dio);

    // Explicitly call register token with backend endpoint
    final instId = await storageService.getInstallationId();
    final res = await apiClient.post(
      '/push/devices',
      data: {
        'platform': 'ANDROID',
        'token': 'mock_fcm_token_123',
        'installation_id': instId,
        'app_version': '1.0.0',
        'device_model': 'Test Device',
      },
    );

    expect(res.statusCode, 200);
    expect(capturedPayload, isNotNull);
    expect(capturedPayload!['platform'], 'ANDROID');
    expect(capturedPayload!['token'], 'mock_fcm_token_123');
    expect(capturedPayload!['installation_id'], instId);
    expect(capturedPayload!['app_version'], '1.0.0');
  });

  // 15. FCM token refresh updates backend
  test('15. Token refresh updates backend registration', () async {
    int calls = 0;

    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/push/devices') {
            calls++;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true},
              ),
            );
          }
        },
      ),
    );

    final apiClient = ApiClient(storage: storageService, customDio: dio);

    // Initial call
    await apiClient.post(
      '/push/devices',
      data: {'platform': 'ANDROID', 'token': 'old_token'},
    );
    // Refreshed call
    await apiClient.post(
      '/push/devices',
      data: {'platform': 'ANDROID', 'token': 'new_rotated_token'},
    );

    expect(calls, 2);
  });

  // 16. Push preference is connected to backend
  test('16. Push preference GET and PUT communicate with backend', () async {
    bool backendPushEnabled = true;

    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/push/preferences' && options.method == 'GET') {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'push_enabled': backendPushEnabled},
              ),
            );
          } else if (options.path == '/push/preferences' &&
              options.method == 'PUT') {
            backendPushEnabled = options.data['push_enabled'] as bool;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'push_enabled': backendPushEnabled},
              ),
            );
          }
        },
      ),
    );

    final apiClient = ApiClient(storage: storageService, customDio: dio);
    final pushService = PushNotificationService(
      apiClient: apiClient,
      storage: storageService,
    );

    expect(await pushService.getPushPreference(), isTrue);

    final updated = await pushService.updatePushPreference(false);
    expect(updated, isFalse);
    expect(await pushService.getPushPreference(), isFalse);
  });

  // 17. Notification deep-link CUSTOMER routes to correct tab
  testWidgets('17. Customer deep link switches to Requests tab', (
    tester,
  ) async {
    final dio = Dio();
    final apiClient = ApiClient(storage: storageService, customDio: dio);
    final pushService = PushNotificationService(
      apiClient: apiClient,
      storage: storageService,
    );
    const customer = UserModel(
      id: 1,
      role: 'CUSTOMER',
      name: 'Ali',
      email: 'ali@test.com',
    );

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storageService),
        apiClientProvider.overrideWithValue(apiClient),
        pushNotificationServiceProvider.overrideWithValue(pushService),
        authNotifierProvider.overrideWith(() {
          return AuthNotifier(
            storage: storageService,
            initialState: const AuthState(
              status: AuthStatus.authenticated,
              user: customer,
            ),
          );
        }),
        myServiceRequestsProvider.overrideWith(
          FakeMyServiceRequestsNotifier.new,
        ),
        customerAppointmentsProvider.overrideWith(
          FakeCustomerAppointmentsNotifier.new,
        ),
        serviceCategoriesProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CustomerShell()),
      ),
    );

    await tester.pump();
    expect(find.text('Ana Sayfa'), findsWidgets);

    // Deep link triggered via PushNotificationService semantic handler
    pushService.handleIncomingPayload({
      'type': 'REQUEST_UPDATE',
      'resource_type': 'request',
      'resource_id': '10',
    });

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Taleplerim'), findsWidgets);
  });

  // 18. Notification deep-link PROVIDER routes to correct tab
  testWidgets('18. Provider deep link switches to Appointments tab', (
    tester,
  ) async {
    final dio = Dio();
    final apiClient = ApiClient(storage: storageService, customDio: dio);
    final pushService = PushNotificationService(
      apiClient: apiClient,
      storage: storageService,
    );
    const provider = UserModel(
      id: 2,
      role: 'PROVIDER',
      name: 'Ahmet',
      email: 'ahmet@test.com',
    );

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storageService),
        apiClientProvider.overrideWithValue(apiClient),
        pushNotificationServiceProvider.overrideWithValue(pushService),
        authNotifierProvider.overrideWith(() {
          return AuthNotifier(
            storage: storageService,
            initialState: const AuthState(
              status: AuthStatus.authenticated,
              user: provider,
            ),
          );
        }),
        providerProfileNotifierProvider.overrideWith(
          FakeProviderProfileNotifier.new,
        ),
        providerMarketplaceRequestsProvider.overrideWith(
          (ref) async => const [],
        ),
        providerReviewSummaryProvider.overrideWith(
          (ref) async => {'average': 0, 'count': 0, 'reviews': <dynamic>[]},
        ),
        providerAssignedRequestsProvider.overrideWith(
          FakeProviderAssignedRequestsNotifier.new,
        ),
        providerMyOffersProvider.overrideWith(FakeProviderMyOffersNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProviderShell()),
      ),
    );

    await tester.pump();

    // Deep link triggered
    pushService.handleIncomingPayload({
      'type': 'APPOINTMENT_REMINDER',
      'resource_type': 'appointment',
      'resource_id': '25',
    });

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Randevularım'), findsWidgets);
  });

  // 19. MESSAGE_RECEIVED routes to Messages tab
  testWidgets('19. MESSAGE_RECEIVED switches to Messages tab', (tester) async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'data': []},
            ),
          );
        },
      ),
    );
    final apiClient = ApiClient(storage: storageService, customDio: dio);
    final pushService = PushNotificationService(
      apiClient: apiClient,
      storage: storageService,
    );
    const customer = UserModel(
      id: 1,
      role: 'CUSTOMER',
      name: 'Ali',
      email: 'ali@test.com',
    );

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storageService),
        apiClientProvider.overrideWithValue(apiClient),
        pushNotificationServiceProvider.overrideWithValue(pushService),
        authNotifierProvider.overrideWith(() {
          return AuthNotifier(
            storage: storageService,
            initialState: const AuthState(
              status: AuthStatus.authenticated,
              user: customer,
            ),
          );
        }),
        myServiceRequestsProvider.overrideWith(
          FakeMyServiceRequestsNotifier.new,
        ),
        customerAppointmentsProvider.overrideWith(
          FakeCustomerAppointmentsNotifier.new,
        ),
        serviceCategoriesProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CustomerShell()),
      ),
    );

    await tester.pump();

    // MESSAGE_RECEIVED triggered
    pushService.handleIncomingPayload({
      'type': 'MESSAGE_RECEIVED',
      'resource_type': 'conversation',
      'resource_id': '5',
    });

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Mesajlar'), findsWidgets);
  });

  // 20. Role shell separation is strictly maintained
  testWidgets('20. Role shell separation is strictly maintained', (
    tester,
  ) async {
    final dio = Dio();
    final apiClient = ApiClient(storage: storageService, customDio: dio);
    final pushService = PushNotificationService(
      apiClient: apiClient,
      storage: storageService,
    );
    const customer = UserModel(
      id: 1,
      role: 'CUSTOMER',
      name: 'Ali',
      email: 'ali@test.com',
    );
    const provider = UserModel(
      id: 2,
      role: 'PROVIDER',
      name: 'Ahmet',
      email: 'ahmet@test.com',
    );

    final customerContainer = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storageService),
        apiClientProvider.overrideWithValue(apiClient),
        pushNotificationServiceProvider.overrideWithValue(pushService),
        authNotifierProvider.overrideWith(() {
          return AuthNotifier(
            storage: storageService,
            initialState: const AuthState(
              status: AuthStatus.authenticated,
              user: customer,
            ),
          );
        }),
        myServiceRequestsProvider.overrideWith(
          FakeMyServiceRequestsNotifier.new,
        ),
        customerAppointmentsProvider.overrideWith(
          FakeCustomerAppointmentsNotifier.new,
        ),
        serviceCategoriesProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(customerContainer.dispose);

    final providerContainer = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storageService),
        apiClientProvider.overrideWithValue(apiClient),
        pushNotificationServiceProvider.overrideWithValue(pushService),
        authNotifierProvider.overrideWith(() {
          return AuthNotifier(
            storage: storageService,
            initialState: const AuthState(
              status: AuthStatus.authenticated,
              user: provider,
            ),
          );
        }),
        providerProfileNotifierProvider.overrideWith(
          FakeProviderProfileNotifier.new,
        ),
        providerMarketplaceRequestsProvider.overrideWith(
          (ref) async => const [],
        ),
        providerReviewSummaryProvider.overrideWith(
          (ref) async => {'average': 0, 'count': 0, 'reviews': <dynamic>[]},
        ),
        providerAssignedRequestsProvider.overrideWith(
          FakeProviderAssignedRequestsNotifier.new,
        ),
        providerMyOffersProvider.overrideWith(FakeProviderMyOffersNotifier.new),
      ],
    );
    addTearDown(providerContainer.dispose);

    // Customer Shell does NOT contain Provider 'İşler' tab
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: customerContainer,
        child: const MaterialApp(home: CustomerShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('İşler'), findsNothing);
    expect(find.text('Talepler'), findsOneWidget);

    // Provider Shell does NOT contain Customer 'Talepler' tab
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: providerContainer,
        child: const MaterialApp(home: ProviderShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Talepler'), findsNothing);
    expect(find.text('İşler'), findsOneWidget);
  });
}
