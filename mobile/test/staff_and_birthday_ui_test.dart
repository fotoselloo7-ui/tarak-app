import 'dart:convert';
import 'dart:typed_data';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/models/user_model.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/customer/appointments/screens/create_appointment_screen.dart';
import 'package:app/features/provider/appointments/screens/provider_appointments_tab.dart';
import 'package:app/features/provider/appointments/screens/provider_create_appointment_screen.dart';
import 'package:app/features/provider/screens/provider_birthday_assistant_screen.dart';
import 'package:app/features/provider/screens/provider_notification_ad_section.dart';
import 'package:app/features/provider/staff/screens/provider_staff_screen.dart';
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
    if (invocation.memberName == #read) {
      return Future<String?>.value(data[named[#key] as String]);
    }
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

class _RecordedCall {
  final String method;
  final String path;
  final dynamic data;
  final Map<String, dynamic> query;

  const _RecordedCall(this.method, this.path, this.data, this.query);
}

class _StaffBirthdayAdapter implements HttpClientAdapter {
  final List<_RecordedCall> calls = [];
  bool includeCustomerStaff = true;
  bool archivedStaff1 = false;
  final List<Map<String, dynamic>> staffRows = [
    {
      'id': 11,
      'provider_profile_id': 5,
      'first_name': 'Ahmet',
      'last_name': 'Usta',
      'full_name': 'Ahmet Usta',
      'title': 'Baş Berber',
      'specialty': 'Modern Kesim',
      'is_active': true,
      'accepts_appointments': true,
      'visible_to_customers': true,
      'sort_order': 1,
      'archived_at': null,
      'services': [
        {
          'service_id': 1,
          'service_name': 'Saç Kesimi',
          'custom_duration_minutes': 45,
          'is_active': true,
        },
      ],
      'schedule': [],
      'time_offs': [],
    },
  ];

  bool birthdayRestricted = false;
  bool notificationAdsRestricted = false;

  Map<String, dynamic> birthdaySettings = {
    'is_enabled': false,
    'send_on_birthday': true,
    'send_one_day_before': false,
    'send_two_days_before': false,
    'send_time': '10:00',
    'template_key': 'classic',
    'custom_message': null,
    'required_plan_tier': null,
    'plan_entitled': true,
    'eligible_customer_count': 14,
    'sent_this_year_count': 3,
    'upcoming_eligible_birthdays_30d': 4,
    'pricing': {
      'birthday_unit_price': 1.5,
      'allow_promo_for_birthday': true,
      'fallback_to_cash_when_promo_insufficient': true,
    },
    'wallet': {
      'usable_promo_balance': 500.0,
      'usable_cash_balance': 0.0,
      'is_frozen': false,
    },
    'permissions': {
      'birthday_blocked': false,
      'auto_special_day_blocked': false,
      'restriction_reason': null,
    },
    'monthly_summary': {
      'paid_notifications_count': 2,
      'total_spent': 3.0,
    },
    'templates': [
      {
        'key': 'classic',
        'label': 'Klasik Tebrik',
        'body': 'İyi ki doğdun {customer_name}! {business_name} iyi yıllar diler.',
      },
    ],
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path.replaceFirst('/api', '');
    calls.add(_RecordedCall(options.method, path, options.data, options.queryParameters));

    Object? body;
    int status = 200;

    if (path == '/provider/staff' && options.method == 'GET') {
      body = {'success': true, 'data': staffRows};
    } else if (path == '/provider/services' && options.method == 'GET') {
      body = {
        'success': true,
        'data': [
          {
            'id': '1',
            'service_id': '1',
            'name': 'Saç Kesimi',
            'custom_duration_minutes': 30,
            'is_active': true,
            'service': {'id': 1, 'name': 'Saç Kesimi', 'duration_minutes': 30},
          },
        ],
      };
    } else if (path == '/provider/staff' && options.method == 'POST') {
      status = 201;
      final req = Map<String, dynamic>.from(options.data as Map);
      final created = {
        'id': 12,
        'provider_profile_id': 5,
        'first_name': req['first_name'],
        'last_name': req['last_name'],
        'full_name': '${req['first_name']} ${req['last_name']}',
        'title': req['title'],
        'specialty': req['specialty'],
        'is_active': true,
        'accepts_appointments': true,
        'visible_to_customers': true,
        'sort_order': 2,
        'archived_at': null,
        'services': [],
        'schedule': [],
        'time_offs': [],
      };
      staffRows.add(created);
      body = {'success': true, 'data': created};
    } else if (path == '/provider/staff/11' && options.method == 'DELETE') {
      archivedStaff1 = true;
      staffRows[0]['is_active'] = false;
      staffRows[0]['archived_at'] = '2026-11-21T12:00:00Z';
      body = {'success': true, 'data': staffRows[0]};
    } else if (path == '/provider/birthday-assistant' && options.method == 'GET') {
      final data = {
        ...birthdaySettings,
        'permissions': {
          'birthday_blocked': birthdayRestricted,
          'auto_special_day_blocked': false,
          'restriction_reason': birthdayRestricted ? 'Spam şikayeti' : null,
        },
      };
      body = {'success': true, 'data': data};
    } else if (path == '/provider/notification-ads' && options.method == 'GET') {
      body = {
        'success': true,
        'data': {
          'is_enabled': true,
          'title': 'Bildirim Reklamı',
          'description': 'Açıklama',
          'provider_name': 'Altın Makas',
          'is_verified': true,
          'sends_left_today': 2,
          'audiences': [
            {
              'audience': 'service_area',
              'name': 'Hizmet bölgem',
              'description': 'Bölge',
              'price': 100.0,
            },
          ],
          'limits': {
            'min_discount_percent': 5,
            'max_discount_percent': 50,
            'max_discount_days': 14,
            'title_max': 50,
            'body_max': 120,
          },
          'pricing': {
            'birthday_unit_price': 2.0,
            'allow_promo_for_notification_ads': true,
            'fallback_to_cash_when_promo_insufficient': true,
          },
          'wallet': {
            'usable_promo_balance': 500.0,
            'usable_cash_balance': 40.0,
            'is_frozen': false,
          },
          'permissions': {
            'notification_ads_blocked': notificationAdsRestricted,
            'restriction_reason': notificationAdsRestricted ? 'Sınır aşımı' : null,
          },
          'monthly_summary': {
            'paid_notifications_count': 5,
            'total_spent': 250.0,
            'fcm_accepted_count': 40,
            'failed_count': 1,
          },
          'upcoming_eligible_birthdays_30d': 6,
          'provinces': [],
          'payment': {'wallet_enabled': true, 'card_enabled': false},
          'history': [],
          'birthday_history': [],
        },
      };
    } else if (path == '/provider/birthday-assistant' && options.method == 'PUT') {
      final req = Map<String, dynamic>.from(options.data as Map);
      birthdaySettings = {
        ...birthdaySettings,
        ...req,
      };
      body = {'success': true, 'data': birthdaySettings};
    } else if (path == '/provider/customers' && options.method == 'GET') {
      body = {
        'success': true,
        'data': [
          {'id': 55, 'name': 'Ayşe Yılmaz', 'avatar_url': null},
        ],
      };
    } else if (path == '/provider/appointments' && options.method == 'GET') {
      body = {'success': true, 'data': []};
    } else if (path == '/provider/appointments' && options.method == 'POST') {
      status = 201;
      final req = Map<String, dynamic>.from(options.data as Map);
      body = {
        'success': true,
        'notification_sent': req['customer_mode'] == 'registered',
        'data': {
          'id': 900,
          'public_id': 'APT000900',
          'customer_user_id': req['customer_user_id'] ?? 0,
          'provider_user_id': 20,
          'status': 'CONFIRMED',
          'appointment_date': req['date'],
          'start_time': req['time'],
          'end_time': '10:30',
          'payment_method': 'CASH',
          'total_price': 250,
          'total_duration_minutes': 30,
          'booking_source': 'PROVIDER_MANUAL',
          'is_guest_customer': req['customer_mode'] == 'guest',
          'guest_customer_name': req['guest_customer_name'],
          'staff_id': req['staff_id'],
          'staff_name': req['staff_id'] == 11 ? 'Ahmet Usta' : null,
          'services': [],
          'alternative_slots': [],
        },
      };
    } else if (path == '/customer/addresses' && options.method == 'GET') {
      body = {
        'success': true,
        'data': [
          {
            'id': 1,
            'title': 'Ev',
            'province': 'İstanbul',
            'district': 'Şişli',
            'neighborhood': 'Meşrutiyet',
            'latitude': 41.0637,
            'longitude': 28.9831,
            'is_default': true,
          },
        ],
      };
    } else if (path == '/services' && options.method == 'GET') {
      body = {
        'success': true,
        'data': [
          {'id': 1, 'name': 'Saç Kesimi', 'duration_minutes': 30, 'is_active': true},
        ],
      };
    } else if (path == '/customer/providers' && options.method == 'GET') {
      body = {
        'success': true,
        'data': [
          {
            'id': '10',
            'user_id': '20',
            'business_name': 'Altın Makas',
            'name': 'Usta Berber',
            'city': 'İstanbul',
            'district': 'Şişli',
            'provider_type': 'barber',
            'is_approved': true,
            'is_verified': true,
            'rating': 4.9,
            'review_count': 12,
          },
        ],
        'sponsored': [],
      };
    } else if (path == '/customer/providers/20/offerings') {
      body = {'success': true, 'data': {'packages': [], 'campaigns': []}};
    } else if (path == '/customer/providers/20/staff') {
      body = {
        'success': true,
        'data': includeCustomerStaff ? staffRows : <dynamic>[],
      };
    } else if (path == '/customer/providers/20/availability') {
      body = {
        'success': true,
        'data': {
          'provider_id': '20',
          'date': options.queryParameters['date'] ?? '2026-11-22',
          'total_duration_minutes': 30,
          'total_price': 250,
          'available_slots': ['10:00', '11:00'],
        },
      };
    } else {
      body = {'success': true, 'data': {}};
    }

    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ProviderAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        status: AuthStatus.authenticated,
        user: UserModel(
          id: 20,
          role: 'PROVIDER',
          name: 'Usta Berber',
          email: 'berber@test.com',
        ),
      );
}

class _CustomerAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        status: AuthStatus.authenticated,
        user: UserModel(
          id: 10,
          role: 'CUSTOMER',
          name: 'Ayşe Müşteri',
          email: 'ayse@test.com',
        ),
      );
}

Future<(ApiClient, SecureStorageService)> _makeEnv(
  _StaffBirthdayAdapter adapter,
) async {
  SharedPreferences.setMockInitialValues({});
  final storage = SecureStorageService(secureStorage: _FakeStorage());
  await storage.init();
  final api = ApiClient(
    storage: storage,
    customDio: Dio()..httpClientAdapter = adapter,
    retries: 0,
  );
  return (api, storage);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ProviderStaffScreen lists, creates, and archives staff cleanly', (
    tester,
  ) async {
    final adapter = _StaffBirthdayAdapter();
    final (api, storage) = await _makeEnv(adapter);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          secureStorageProvider.overrideWithValue(storage),
          authNotifierProvider.overrideWith(_ProviderAuth.new),
        ],
        child: const MaterialApp(home: ProviderStaffScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ahmet Usta'), findsOneWidget);
    expect(find.text('Baş Berber • Modern Kesim'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_staff_btn')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('staff_photo_section')), findsOneWidget);
    expect(find.byKey(const Key('staff_pick_photo_btn')), findsOneWidget);
    expect(find.text('Çalışan Profil Fotoğrafı'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('staff_first_name_input')), 'Mehmet');
    await tester.enterText(find.byKey(const Key('staff_last_name_input')), 'Stilist');
    final saveBtn = find.byKey(const Key('save_staff_btn'));
    await tester.ensureVisible(saveBtn);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    expect(find.text('Mehmet Stilist'), findsOneWidget);

    await tester.tap(find.byKey(const Key('archive_staff_11')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arşivle'));
    await tester.pumpAndSettle();

    expect(adapter.archivedStaff1, isTrue);
  });

  testWidgets(
    'ProviderBirthdayAssistantScreen protects customer birthdates and saves settings',
    (tester) async {
      final adapter = _StaffBirthdayAdapter();
      final (api, storage) = await _makeEnv(adapter);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            secureStorageProvider.overrideWithValue(storage),
            authNotifierProvider.overrideWith(_ProviderAuth.new),
          ],
          child: const MaterialApp(home: ProviderBirthdayAssistantScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('14'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.textContaining('bireysel doğum tarihleri işletmelere açılmaz'), findsOneWidget);

      await tester.tap(find.byKey(const Key('birthday_assistant_enabled_switch')));
      await tester.pumpAndSettle();

      final customRadio = find.text('Özel Tebrik Mesajı Yaz');
      await tester.ensureVisible(customRadio);
      await tester.tap(customRadio);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('birthday_custom_message_input')),
        'Doğum günün kutlu olsun {customer_name}!',
      );

      final saveBtn = find.byKey(const Key('save_birthday_assistant_btn'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      final putCall = adapter.calls.lastWhere(
        (c) => c.path == '/provider/birthday-assistant' && c.method == 'PUT',
      );
      final sent = Map<String, dynamic>.from(putCall.data as Map);
      expect(sent['is_enabled'], isTrue);
      expect(sent['template_key'], 'custom');
      expect(sent['custom_message'], 'Doğum günün kutlu olsun {customer_name}!');
    },
  );

  testWidgets(
    'ProviderCreateAppointmentScreen supports registered & consenting guest bookings cleanly',
    (tester) async {
      final adapter = _StaffBirthdayAdapter();
      final (api, storage) = await _makeEnv(adapter);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            secureStorageProvider.overrideWithValue(storage),
            authNotifierProvider.overrideWith(_ProviderAuth.new),
          ],
          child: const MaterialApp(home: ProviderAppointmentsTab()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('provider_create_manual_appt_btn')));
      await tester.pumpAndSettle();
      expect(find.byType(ProviderCreateAppointmentScreen), findsOneWidget);

      // Registered mode submit
      final submitBtn = find.byKey(const Key('manual_submit_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      final regPost = adapter.calls.lastWhere(
        (c) => c.path == '/provider/appointments' && c.method == 'POST',
      );
      expect((regPost.data as Map)['customer_mode'], 'registered');
      expect((regPost.data as Map)['customer_user_id'], 55);

      // Open again in guest mode: consent required
      await tester.tap(find.byKey(const Key('provider_create_manual_appt_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manual_mode_guest')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('manual_guest_name_input')),
        'Misafir Kemal',
      );
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('manual_submit_error')), findsOneWidget);

      final consentBox = find.byKey(const Key('manual_guest_consent_checkbox'));
      await tester.ensureVisible(consentBox);
      await tester.tap(consentBox);
      await tester.pumpAndSettle();

      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      final guestPost = adapter.calls.lastWhere(
        (c) => c.path == '/provider/appointments' && c.method == 'POST',
      );
      expect((guestPost.data as Map)['customer_mode'], 'guest');
      expect((guestPost.data as Map)['guest_customer_name'], 'Misafir Kemal');
      expect((guestPost.data as Map)['guest_customer_consent'], isTrue);
    },
  );

  testWidgets(
    'CreateAppointmentScreen renders Fark Etmez first with staff list and hides selector when salon has no staff',
    (tester) async {
      final adapter = _StaffBirthdayAdapter();
      final (api, storage) = await _makeEnv(adapter);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            secureStorageProvider.overrideWithValue(storage),
            authNotifierProvider.overrideWith(_CustomerAuth.new),
          ],
          child: const MaterialApp(home: CreateAppointmentScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Step 0 -> Step 1 -> Step 2 -> Step 3
      await tester.tap(find.byKey(const Key('address_item_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('service_item_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('provider_card_10')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();

      final anyOpt = find.byKey(const Key('staff_option_any'));
      final staffOpt = find.byKey(const Key('staff_option_11'));
      expect(anyOpt, findsOneWidget);
      expect(staffOpt, findsOneWidget);
      expect(find.text('Fark Etmez — İlk Müsait Usta'), findsOneWidget);
      expect(find.text('Ahmet Usta'), findsOneWidget);
      expect(
        tester.getTopLeft(anyOpt).dy,
        lessThan(tester.getTopLeft(staffOpt).dy),
      );

      await tester.tap(staffOpt);
      await tester.pumpAndSettle();

      // Legacy salon without staff hides staff section cleanly
      adapter.includeCustomerStaff = false;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            secureStorageProvider.overrideWithValue(storage),
            authNotifierProvider.overrideWith(_CustomerAuth.new),
          ],
          child: const MaterialApp(home: CreateAppointmentScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('address_item_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('service_item_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('provider_card_10')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('wizard_next_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Usta / Uzman Seçimi'), findsNothing);
    },
  );

  testWidgets(
    'ProviderNotificationAdSection & ProviderBirthdayAssistantScreen display balances, pricing, and enforce admin restrictions',
    (tester) async {
      final adapter = _StaffBirthdayAdapter();
      final (api, storage) = await _makeEnv(adapter);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            secureStorageProvider.overrideWithValue(storage),
            authNotifierProvider.overrideWith(_ProviderAuth.new),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: ProviderNotificationAdSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('provider_notification_report_card')), findsOneWidget);
      expect(find.text('Promosyon Bakiyesi'), findsOneWidget);
      expect(find.text('₺500'), findsOneWidget);
      expect(find.textContaining('₺2 / alıcı'), findsOneWidget);

      // Admin blocks provider notification ads
      adapter.notificationAdsRestricted = true;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            secureStorageProvider.overrideWithValue(storage),
            authNotifierProvider.overrideWith(_ProviderAuth.new),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: ProviderNotificationAdSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notification_ad_blocked_banner')), findsOneWidget);
      expect(find.text('Yönetici tarafından kısıtlandı'), findsOneWidget);

      // Admin blocks provider birthday assistant
      adapter.birthdayRestricted = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            secureStorageProvider.overrideWithValue(storage),
            authNotifierProvider.overrideWith(_ProviderAuth.new),
          ],
          child: const MaterialApp(home: ProviderBirthdayAssistantScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('birthday_pricing_summary_card')), findsOneWidget);
      expect(find.byKey(const Key('birthday_admin_restricted_banner')), findsOneWidget);
      expect(find.textContaining('Spam şikayeti'), findsOneWidget);
    },
  );
}
