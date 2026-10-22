import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/push_notification_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/auth/screens/auth_gate.dart';
import 'package:app/features/auth/screens/login_screen.dart';
import 'package:app/features/auth/screens/register_screen.dart';
import 'package:app/features/auth/screens/welcome_screen.dart';
import 'package:app/features/auth/widgets/web_landing_widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Widget createTestWidget({
    required Widget child,
  }) {
    final dio = Dio();
    final apiClient = ApiClient(storage: storageService, customDio: dio);
    final pushService =
        PushNotificationService(apiClient: apiClient, storage: storageService);

    return ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(storageService),
        apiClientProvider.overrideWithValue(apiClient),
        pushNotificationServiceProvider.overrideWithValue(pushService),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Web-Identical Mobile Home Tests', () {
    testWidgets('1. WelcomeScreen renders all real web homepage sections',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(child: const WelcomeScreen()),
      );
      await tester.pumpAndSettle();

      // Top badge
      expect(find.text('BERBER VE KUAFÖR PLATFORMU'), findsOneWidget);
      // Hero CTAs, repeated once by the closing dark CTA (same as the web home).
      expect(find.text('Randevu Oluştur'), findsNWidgets(2));
      expect(find.text('Hizmet Veren Olarak Katıl'), findsOneWidget);
      expect(find.text('Hizmet Veren Olun'), findsOneWidget);
      expect(find.text('Giriş Yap'), findsOneWidget);
      expect(find.text('Kayıt Ol'), findsOneWidget);

      // Hero Trust items
      expect(find.text('Belge ve kimlik kontrolü'), findsOneWidget);
      expect(find.text('Şeffaf Tarak Puanı'), findsOneWidget);
      expect(find.text('Konum gizliliği'), findsOneWidget);
      expect(find.text('Güvenli ödeme'), findsOneWidget);

      // Unmeasured platform totals never appear as fallback statistics.
      expect(find.text('4.9/5'), findsNothing);
      expect(find.text('Kullanıcı Memnuniyeti'), findsNothing);
      expect(find.text('%100'), findsNothing);
      expect(find.text('Belgeli Uzmanlar'), findsNothing);

      // How It Works
      expect(find.text('SADECE 4 ADIMDA'), findsOneWidget);
      expect(find.text('Nasıl Çalışır?'), findsOneWidget);
      expect(find.text('Hizmetini Seç'), findsOneWidget);
      expect(find.text('Zamanını Belirle'), findsOneWidget);
      expect(find.text('Doğrulanmış Uzman Gelsin'), findsOneWidget);
      expect(find.text('Güvenle Hizmet Al'), findsOneWidget);

      // Categories Section — rendered only from the canonical
      // /api/service-categories dataset (no fallback list). With no API in
      // this test it stays hidden; home_layout_test covers it with a catalog.
      expect(find.text('BAKIM SANA GÖRE'), findsNothing);
      expect(find.text('Erkek Bakım'), findsNothing);

      // Security Section
      expect(find.text('GÜVEN, BİZİM STANDARTIMIZ'), findsOneWidget);
      expect(find.text('Doğrulanmış ve Güvenilir Hizmet Verenler'), findsOneWidget);
      expect(find.text('Konum Kontrolü Sende'), findsOneWidget);
      expect(find.text('Diploma Kontrolü'), findsOneWidget);
      expect(find.text('Kimlik bilgileri güvenli şekilde doğrulanır.'), findsOneWidget);

      // Closing dark CTA
      expect(find.text('TARAK'), findsOneWidget);
      expect(find.text('Randevunuzu şimdi oluşturun.'), findsOneWidget);

      // Tarak Cebinde
      expect(find.text('TARAK MOBİL'), findsOneWidget);
      expect(find.text('Randevularını yönet'), findsOneWidget);

      // Footer
      expect(find.textContaining('Tarak. Tüm hakları saklıdır.'), findsOneWidget);
    });

    testWidgets('2. WelcomeScreen Hemen Hizmet Al navigates to Customer Register',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(child: const WelcomeScreen()),
      );
      await tester.pumpAndSettle();

      final btn = find.text('Randevu Oluştur').first; // hero CTA
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Müşteri Kaydı'), findsOneWidget);
      expect(find.text('Müşteri Hizmet Avantajı'), findsOneWidget);
    });

    testWidgets('3. WelcomeScreen Hizmet Veren Ol navigates to Provider Register',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(child: const WelcomeScreen()),
      );
      await tester.pumpAndSettle();

      final btn = find.text('Hizmet Veren Olarak Katıl').first; // hero CTA
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Hizmet Veren Kaydı'), findsOneWidget);
      expect(find.text('Hizmet Veren Başvuru Notu'), findsOneWidget);
      expect(find.text('İşletme / Salon Adı (İsteğe Bağlı)'), findsOneWidget);
    });

    testWidgets('4. WelcomeScreen Giriş Yap navigates to LoginScreen',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(child: const WelcomeScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Giriş Yaparak Hizmet Almaya Başlayın'), findsOneWidget);
    });

    testWidgets('5. RegisterScreen role switcher toggles customer and provider fields',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(child: const RegisterScreen(initialRole: 'CUSTOMER')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Müşteri Kaydı'), findsOneWidget);
      expect(find.text('İşletme / Salon Adı (İsteğe Bağlı)'), findsNothing);

      // Switch to Provider
      await tester.tap(find.text('Hizmet Veren'));
      await tester.pumpAndSettle();

      expect(find.text('Hizmet Veren Kaydı'), findsOneWidget);
      expect(find.text('İşletme / Salon Adı (İsteğe Bağlı)'), findsOneWidget);
      expect(find.text('Belge Doğrulaması: Başvurunuz ekibimiz tarafından incelenir ve profiliniz onaylanır.'), findsOneWidget);
    });

    testWidgets('6. LoginScreen password obscure toggle and back button',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: const Text('GoToLogin'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('GoToLogin'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('GoToLogin'), findsOneWidget);
    });

    testWidgets('7. AuthGate shows WelcomeScreen directly for unauthenticated users',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(child: const AuthGate()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Randevu Oluştur'), findsNWidgets(2));
      expect(find.text('Hizmet Veren Olarak Katıl'), findsOneWidget);
      expect(find.text('Hizmet Veren Olun'), findsOneWidget);
    });

    testWidgets('8. Category cards render from CANONICAL domain data, not hardcoded names',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: WebCategoriesSection(
                onSelectCategory: () {},
                // Shape mirrors /api/service-categories records.
                categories: const [
                  {'id': 'cat-1', 'name': 'Erkek Bakım', 'provider_type': 'barber'},
                  {'id': 'cat-2', 'name': 'Kadın Kuaför', 'provider_type': 'coiffeur'},
                ],
                content: const {'title': 'Hizmet Kategorileri'},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Erkek Bakım Hizmetleri'), findsOneWidget);
      expect(find.text('Kadın Kuaför Hizmetleri'), findsOneWidget);
    });

    testWidgets('9. Categories section keeps its heading when the domain API is unavailable',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: Scaffold(
            body: SingleChildScrollView(
              child: WebCategoriesSection(onSelectCategory: () {}, categories: const []),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Hizmet Kategorileri'), findsOneWidget);
      // No invented/demo category may appear when there is no real data.
      expect(find.text('Erkek Bakım Hizmetleri'), findsNothing);
    });
  });
}
