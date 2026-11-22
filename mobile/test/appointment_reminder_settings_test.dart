import 'dart:convert';
import 'dart:typed_data';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/models/user_model.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/customer/screens/customer_settings_screen.dart';
import 'package:app/features/provider/instant/models/provider_profile_model.dart';
import 'package:app/features/provider/instant/providers/provider_instant_providers.dart';
import 'package:app/features/provider/screens/provider_profile_tab.dart';
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

class _RecordedRequest {
  final String method;
  final String path;
  final dynamic data;

  const _RecordedRequest(this.method, this.path, this.data);
}

class _PreferenceMockAdapter implements HttpClientAdapter {
  bool pushEnabled = true;
  bool campaignEnabled = true;
  bool reminderEnabled;
  int reminderMinutes;
  bool startAlertEnabled;
  bool birthdayGreetingEnabled;
  bool failReminderUpdates = false;
  final List<_RecordedRequest> requests = <_RecordedRequest>[];

  _PreferenceMockAdapter({
    this.reminderEnabled = true,
    this.reminderMinutes = 30,
    this.startAlertEnabled = true,
    this.birthdayGreetingEnabled = false,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path.replaceFirst('/api', '');
    requests.add(_RecordedRequest(options.method, path, options.data));

    if (path == '/push/preferences' &&
        options.method == 'PUT' &&
        failReminderUpdates) {
      return ResponseBody.fromString(
        jsonEncode({'message': 'Sunucu tercihi kaydedemedi.'}),
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    Object? body;
    if (path == '/push/preferences' && options.method == 'GET') {
      body = _prefsPayload();
    } else if (path == '/push/preferences' && options.method == 'PUT') {
      final map = options.data is Map ? options.data as Map : const {};
      if (map.containsKey('push_enabled')) {
        pushEnabled = map['push_enabled'] == true;
      }
      if (map.containsKey('campaign_enabled')) {
        campaignEnabled = map['campaign_enabled'] == true;
      }
      if (map.containsKey('appointment_reminder_enabled')) {
        reminderEnabled = map['appointment_reminder_enabled'] == true;
      }
      if (map.containsKey('appointment_reminder_minutes')) {
        reminderMinutes = (map['appointment_reminder_minutes'] as num).toInt();
      }
      if (map.containsKey('appointment_start_alert_enabled')) {
        startAlertEnabled = map['appointment_start_alert_enabled'] == true;
      }
      if (map.containsKey('birthday_greeting_enabled')) {
        birthdayGreetingEnabled = map['birthday_greeting_enabled'] == true;
      }
      body = _prefsPayload();
    } else if (path == '/provider/wallet') {
      body = {
        'success': true,
        'data': {
          'cash_balance': 0,
          'promo_balance': 0,
          'pending_balance': 0,
          'withdrawable_balance': 0,
        },
      };
    } else if (path == '/provider/payout-account') {
      body = {
        'success': true,
        'data': {'iban_masked': null},
      };
    } else if (path == '/provider/reviews') {
      body = {
        'success': true,
        'data': {'average': 4.8, 'count': 5, 'reviews': <dynamic>[]},
      };
    } else if (path == '/provider/documents') {
      body = {'success': true, 'data': <dynamic>[]};
    } else if (path == '/provider/appointments') {
      body = {'success': true, 'data': <dynamic>[]};
    } else {
      body = {'success': true, 'data': <dynamic>[]};
    }

    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, dynamic> _prefsPayload() => {
        'push_enabled': pushEnabled,
        'campaign_enabled': campaignEnabled,
        'appointment_reminder_enabled': reminderEnabled,
        'appointment_reminder_minutes': reminderMinutes,
        'appointment_start_alert_enabled': startAlertEnabled,
        'birthday_greeting_enabled': birthdayGreetingEnabled,
      };

  @override
  void close({bool force = false}) {}
}

class _CustomerAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        status: AuthStatus.authenticated,
        user: UserModel(
          id: 10,
          role: 'CUSTOMER',
          name: 'Ayşe Test',
          email: 'ayse@test.com',
        ),
      );
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

class _FakeProviderProfileNotifier extends ProviderProfileNotifier {
  @override
  Future<ProviderProfileModel> build() async => const ProviderProfileModel(
        userId: 20,
        businessName: 'Altın Makas',
        isOnline: true,
        isApproved: true,
        identityStatus: 'APPROVED',
        isVerified: true,
      );
}

Future<ApiClient> _makeApi(_PreferenceMockAdapter adapter) async {
  SharedPreferences.setMockInitialValues({});
  final storage = SecureStorageService(secureStorage: _FakeStorage());
  await storage.init();
  return ApiClient(
    storage: storage,
    customDio: Dio()..httpClientAdapter = adapter,
    retries: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final width in [320.0, 360.0, 390.0, 412.0]) {
    testWidgets(
      'All 6 reminder options align on a single horizontal row without overflow at ${width.toInt()}dp',
      (tester) async {
        final adapter = _PreferenceMockAdapter(reminderMinutes: 30);
        final api = await _makeApi(adapter);
        final storage = SecureStorageService(secureStorage: _FakeStorage());
        await storage.init();

        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final errors = <FlutterErrorDetails>[];
        final prevOnError = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details);
        addTearDown(() => FlutterError.onError = prevOnError);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(api),
              secureStorageProvider.overrideWithValue(storage),
              authNotifierProvider.overrideWith(_CustomerAuth.new),
            ],
            child: const MaterialApp(home: CustomerSettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(errors, isEmpty);

        const keys = [
          Key('customer_reminder_min_15'),
          Key('customer_reminder_min_30'),
          Key('customer_reminder_min_45'),
          Key('customer_reminder_min_60'),
          Key('customer_reminder_min_120'),
          Key('customer_reminder_min_custom'),
        ];

        final centersY = keys
            .map((k) => tester.getCenter(find.byKey(k)).dy)
            .toList();
        for (final y in centersY) {
          expect(
            (y - centersY.first).abs(),
            lessThan(0.5),
            reason: 'Expected all 6 reminder pills in 1 row at ${width.toInt()}dp',
          );
        }
      },
    );
  }

  testWidgets(
    'Custom dialog Özel -> 75 -> Kaydet never disposes controller early, handles keyboard insets, persists on re-entry, rejects invalid values, cancels safely, and handles API failures',
    (tester) async {
      final adapter = _PreferenceMockAdapter(
        reminderEnabled: true,
        reminderMinutes: 30,
        startAlertEnabled: true,
        birthdayGreetingEnabled: false,
      );
      final api = await _makeApi(adapter);
      final storage = SecureStorageService(secureStorage: _FakeStorage());
      await storage.init();

      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() {
        tester.view.resetViewInsets();
        tester.binding.setSurfaceSize(null);
      });

      final errors = <FlutterErrorDetails>[];
      final prevOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(api),
              secureStorageProvider.overrideWithValue(storage),
              authNotifierProvider.overrideWith(_CustomerAuth.new),
            ],
            child: const MaterialApp(home: CustomerSettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Open custom dialog
        final customBtn = find.byKey(const Key('customer_reminder_min_custom'));
        await tester.ensureVisible(customBtn);
        await tester.tap(customBtn);
        await tester.pumpAndSettle();

        // Simulate soft keyboard open at 360dp small height — must not overflow!
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(errors, isEmpty);

        final inputFinder = find.byKey(
          const Key('customer_reminder_custom_minutes_input'),
        );
        final saveFinder = find.byKey(
          const Key('customer_reminder_custom_minutes_save'),
        );
        final cancelFinder = find.byKey(
          const Key('customer_reminder_custom_minutes_cancel'),
        );

        // Invalid entries rejected without closing dialog or calling PUT
        for (final bad in ['', 'abc', '0', '-15', '4', '1441']) {
          await tester.enterText(inputFinder, bad);
          await tester.tap(saveFinder);
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
        }
        expect(
          adapter.requests.where((r) => r.method == 'PUT'),
          isEmpty,
        );

        // Failed API error keeps dialog open and preserves previous saved value
        adapter.failReminderUpdates = true;
        await tester.enterText(inputFinder, '75');
        await tester.tap(saveFinder);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Sunucu tercihi kaydedemedi.'),
          ),
          findsOneWidget,
        );
        expect(adapter.reminderMinutes, 30);
        adapter.failReminderUpdates = false;

        // Cancel preserves 30 minutes
        await tester.tap(cancelFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(adapter.reminderMinutes, 30);
        expect(errors, isEmpty);

        // Re-open -> enter 75 -> Kaydet -> frame-by-frame route exit with keyboard closing
        await tester.tap(customBtn);
        await tester.pumpAndSettle();
        await tester.enterText(inputFinder, '75');
        await tester.tap(saveFinder);
        tester.view.resetViewInsets();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pumpAndSettle();

        expect(errors, isEmpty);
        expect(tester.takeException(), isNull);
        expect(find.byType(AlertDialog), findsNothing);
        expect(adapter.reminderMinutes, 75);
        expect(find.text('75 dk'), findsOneWidget);
        expect(
          find.text('Randevudan 75 dakika önce hatırlat'),
          findsOneWidget,
        );

        // Leave and re-enter screen: fresh GET restores 75 dk
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(api),
              secureStorageProvider.overrideWithValue(storage),
              authNotifierProvider.overrideWith(_CustomerAuth.new),
            ],
            child: const MaterialApp(home: CustomerSettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('75 dk'), findsOneWidget);
        expect(
          find.text('Randevudan 75 dakika önce hatırlat'),
          findsOneWidget,
        );

        // Re-open custom dialog again -> close safely
        final reopenedCustomBtn = find.byKey(
          const Key('customer_reminder_min_custom'),
        );
        await tester.ensureVisible(reopenedCustomBtn);
        await tester.pumpAndSettle();
        await tester.tap(reopenedCustomBtn);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('75'),
          ),
          findsOneWidget,
        );
        await tester.tap(cancelFinder);
        await tester.pumpAndSettle();
        expect(errors, isEmpty);

        // Birthday greeting starts OFF even when push & campaign are ON, and saves independently
        final bdaySwitch = tester.widget<Switch>(
          find.byKey(const Key('customer_birthday_greeting_switch')),
        );
        expect(bdaySwitch.value, isFalse);

        await tester.ensureVisible(
          find.byKey(const Key('customer_birthday_greeting_switch')),
        );
        await tester.tap(
          find.byKey(const Key('customer_birthday_greeting_switch')),
        );
        await tester.pumpAndSettle();
        expect(adapter.birthdayGreetingEnabled, isTrue);
      } finally {
        FlutterError.onError = prevOnError;
      }
    },
  );

  testWidgets(
    'ProviderProfileTab renders single-row selector and saves custom minutes via shared dialog without overflow at 360dp',
    (tester) async {
      final adapter = _PreferenceMockAdapter(
        reminderEnabled: true,
        reminderMinutes: 30,
      );
      final api = await _makeApi(adapter);
      final storage = SecureStorageService(secureStorage: _FakeStorage());
      await storage.init();

      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final errors = <FlutterErrorDetails>[];
      final prevOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(api),
              secureStorageProvider.overrideWithValue(storage),
              authNotifierProvider.overrideWith(_ProviderAuth.new),
              providerProfileNotifierProvider.overrideWith(
                _FakeProviderProfileNotifier.new,
              ),
              providerReviewSummaryProvider.overrideWith(
                (ref) async => {'average': 4.8, 'count': 5, 'reviews': <dynamic>[]},
              ),
              providerDocumentsProvider.overrideWith((ref) async => const []),
              providerJobStatsProvider.overrideWith(
                (ref) async => (completed: 2, upcoming: 1),
              ),
            ],
            child: const MaterialApp(home: ProviderProfileTab()),
          ),
        );
        await tester.pumpAndSettle();

        final reminderCard = find.byKey(const Key('provider_reminder_card'));
        await tester.scrollUntilVisible(
          reminderCard,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(find.text('Randevu Hatırlatması'), findsOneWidget);
        expect(errors, isEmpty);

        // Custom 75 on ProviderProfileTab too
        final customBtn = find.byKey(const Key('provider_reminder_min_custom'));
        await tester.ensureVisible(customBtn);
        await tester.tap(customBtn);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('provider_reminder_custom_minutes_input')),
          '75',
        );
        await tester.tap(
          find.byKey(const Key('provider_reminder_custom_minutes_save')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(errors, isEmpty);
        expect(adapter.reminderMinutes, 75);
        expect(find.text('75 dk'), findsOneWidget);
      } finally {
        FlutterError.onError = prevOnError;
      }
    },
  );
}
