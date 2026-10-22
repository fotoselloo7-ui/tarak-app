import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/push_notification_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/notifications/screens/notification_center_screen.dart';

class _Adapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions) handler;
  _Adapter(this.handler);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody _body(dynamic data, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Map<String, dynamic> _row(int id) => {
  'id': id,
  'title': 'Mesaj $id',
  'message': 'Gerçek sunucu sözleşmesi',
  'read_at': null,
  'created_at': '2026-10-07T04:22:00Z',
  'type': 'MESSAGE_RECEIVED',
  'resource_type': 'CONVERSATION',
  'resource_id': 36,
  'metadata': {'conversation_id': 36},
};

void main() {
  test('request and appointment notification targets open their resource details', () {
    expect(const SemanticDeepLink(tab: SemanticRouteTab.requests,
        resourceType: 'INSTANT_REQUEST', resourceId: 238, eventType: 'REQUEST_ASSIGNED').hasRequestDetail, isTrue);
    expect(const SemanticDeepLink(tab: SemanticRouteTab.appointments,
        resourceType: 'SCHEDULED_APPOINTMENT', resourceId: 62, eventType: 'APPOINTMENT_CONFIRMED').hasAppointmentDetail, isTrue);
  });

  testWidgets('unread filter and mark-all await canonical server state', (tester) async {
    var read = false;
    var canRead = false;
    var requestedUnread = false;
    final dio = Dio()..httpClientAdapter = _Adapter((options) {
      if (options.method == 'POST') {
        expect(options.path, '/notifications/read-all');
        if (!canRead) return _body({'message': 'Bağlantı hatası'}, 503);
        read = true;
        return _body({'success': true, 'updated_count': 1});
      }
      requestedUnread = options.queryParameters['unread'] == true;
      return _body({'data': requestedUnread && read ? [] : [_row(1)],
        'meta': {'current_page': 1, 'last_page': 1}});
    });
    final client = ApiClient(storage: SecureStorageService(), customDio: dio);
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(client)],
        child: MaterialApp(theme: AppTheme.lightTheme, home: const NotificationCenterScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Okunmamış'));
    await tester.pumpAndSettle();
    expect(requestedUnread, isTrue);
    await tester.tap(find.byTooltip('Tümünü Okundu İşaretle'));
    await tester.pumpAndSettle();
    expect(read, isFalse);
    expect(find.text('Mesaj 1'), findsOneWidget);
    canRead = true;
    await tester.tap(find.byTooltip('Tümünü Okundu İşaretle'));
    await tester.pumpAndSettle();
    expect(read, isTrue);
    expect(find.text('Okunmamış bildiriminiz yok'), findsOneWidget);
  });
  testWidgets('paginated inbox deduplicates overlapping server IDs', (
    tester,
  ) async {
    final dio = Dio()
      ..httpClientAdapter = _Adapter((options) {
        final page = options.queryParameters['page'] as int;
        return _body({
          'data': page == 1 ? [_row(2)] : [_row(2), _row(1)],
          'meta': {'current_page': page, 'last_page': 2},
        });
      });
    final client = ApiClient(storage: SecureStorageService(), customDio: dio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const NotificationCenterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daha fazla göster'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notification-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('notification-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed inbox shows retry and recovers from canonical response', (
    tester,
  ) async {
    var online = false;
    final dio = Dio()
      ..httpClientAdapter = _Adapter(
        (options) => online
            ? _body({
                'data': [_row(1)],
                'meta': {'current_page': 1, 'last_page': 1},
              })
            : _body({'message': 'Sunucu kullanılamıyor'}, 503),
      );
    final client = ApiClient(storage: SecureStorageService(), customDio: dio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const NotificationCenterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bir Hata Oluştu'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    online = true;
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();
    expect(find.text('Mesaj 1'), findsOneWidget);
    expect(find.text('Bir Hata Oluştu'), findsNothing);
  });

  testWidgets(
    'failed mark-read keeps inbox; server success opens conversation once',
    (tester) async {
      var canRead = false;
      var readCalls = 0;
      final dio = Dio()
        ..httpClientAdapter = _Adapter((options) {
          if (options.method == 'POST') {
            expect(options.path, '/notifications/1/read');
            readCalls++;
            return canRead
                ? _body({'success': true})
                : _body({'message': 'Bağlantı hatası'}, 503);
          }
          return _body({
            'data': [_row(1)],
            'meta': {'current_page': 1, 'last_page': 1},
          });
        });
      final storage = SecureStorageService();
      final client = ApiClient(storage: storage, customDio: dio);
      final push = PushNotificationService(apiClient: client, storage: storage);
      final links = <SemanticDeepLink>[];
      final sub = push.deepLinkStream.listen(links.add);
      addTearDown(() async {
        await sub.cancel();
        push.dispose();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(client),
            pushNotificationServiceProvider.overrideWithValue(push),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: NotificationCenterButton()),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Bildirimler'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mesaj 1'));
      await tester.pumpAndSettle();
      expect(find.text('Mesaj 1'), findsOneWidget);
      expect(links, isEmpty);
      canRead = true;
      await tester.tap(find.text('Mesaj 1'));
      await tester.pumpAndSettle();
      expect(readCalls, 2);
      expect(links.single.tab, SemanticRouteTab.messages);
      expect(links.single.conversationId, 36);
      expect(find.byType(NotificationCenterScreen), findsNothing);
    },
  );
}
