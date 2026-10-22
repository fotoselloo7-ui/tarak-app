import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/models/user_model.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/chat/providers/chat_providers.dart';
import 'package:app/features/chat/repositories/chat_repository.dart';
import 'package:app/features/chat/screens/chat_screen.dart';
import 'package:app/features/shared/moderation/moderation_repository.dart';

class _FakeStorage implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final member = invocation.memberName;
    final named = invocation.namedArguments;
    if (member == #read) return Future<String?>.value(data[named[#key] as String]);
    if (member == #write) {
      final value = named[#value];
      if (value != null) {
        data[named[#key] as String] = value.toString();
      } else {
        data.remove(named[#key] as String);
      }
      return Future<void>.value();
    }
    if (member == #delete) {
      data.remove(named[#key] as String);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _MockDioAdapter implements HttpClientAdapter {
  final Map<String, dynamic> Function(RequestOptions options) handler;

  _MockDioAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final res = handler(options);
    return ResponseBody.fromString(
      res['body'] is String ? res['body'] as String : jsonEncode(res['body'] ?? {}),
      (res['status'] as int?) ?? 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _TestAuthNotifier extends AuthNotifier {
  final UserModel _user;
  _TestAuthNotifier(this._user);

  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated, user: _user);
}

/// Minimal fake of the backend: one conversation (10 = customer, 20 = provider)
/// with one message from each side, `POST /reports`, `POST|DELETE /blocks`.
class _FakeBackend {
  bool blockedByMe = false;
  bool failReport = false;
  bool blockSendWith403 = false;
  final requests = <String>[];
  final bodies = <String, dynamic>{};

  Map<String, dynamic> handle(RequestOptions options) {
    final key = '${options.method} ${options.path}';
    requests.add(key);
    bodies[key] = options.data;

    if (options.path.endsWith('/conversations/12/messages') && options.method == 'GET') {
      return {
        'body': {
          'data': [
            {
              'id': 1,
              'conversation_id': 12,
              'sender_user_id': 20,
              'body': 'Uygunsuz mesaj',
              'status': 'SENT',
              'created_at': '2026-10-19T10:00:00Z',
            },
            {
              'id': 2,
              'conversation_id': 12,
              'sender_user_id': 10,
              'body': 'Benim mesajım',
              'status': 'SENT',
              'created_at': '2026-10-19T10:01:00Z',
            },
          ],
          'current_page': 1,
          'last_page': 1,
          'conversation': {
            'id': 12,
            'status': 'ACTIVE',
            'is_writable': !blockedByMe,
            'blocked_by_me': blockedByMe,
            'other_user_id': 20,
          },
        },
      };
    }
    if (options.path.endsWith('/conversations/12/messages') && options.method == 'POST') {
      if (blockSendWith403) {
        return {
          'status': 403,
          'body': {'message': 'Bu kullanıcıya şu anda mesaj gönderemezsiniz.'},
        };
      }
      return {
        'status': 201,
        'body': {
          'data': {'id': 3, 'conversation_id': 12, 'sender_user_id': 10, 'body': 'x', 'status': 'SENT'},
        },
      };
    }
    if (options.path.endsWith('/read')) return {'body': {'marked_count': 0}};
    if (options.path.endsWith('/reports')) {
      if (failReport) {
        return {
          'status': 422,
          'body': {'message': 'Geçerli bir bildirim nedeni seçin.'},
        };
      }
      return {
        'status': 201,
        'body': {'success': true, 'message': 'Bildiriminiz alındı. Ekibimiz inceleyecek.', 'data': {'id': 1}},
      };
    }
    if (options.path.endsWith('/blocks') && options.method == 'POST') {
      blockedByMe = true;
      return {'status': 201, 'body': {'success': true}};
    }
    if (options.path.contains('/blocks/') && options.method == 'DELETE') {
      blockedByMe = false;
      return {'body': {'success': true}};
    }
    if (options.path.endsWith('/conversations')) return {'body': {'data': []}};
    return {'body': {}};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeStorage storage;
  late SecureStorageService storageService;
  late _FakeBackend backend;
  late ApiClient apiClient;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = _FakeStorage()..data['access_token'] = 'test_token';
    storageService = SecureStorageService(secureStorage: storage);
    backend = _FakeBackend();
    final dio = Dio()..httpClientAdapter = _MockDioAdapter(backend.handle);
    apiClient = ApiClient(storage: storageService, customDio: dio);
  });

  Widget app() {
    return ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(storageService),
        apiClientProvider.overrideWithValue(apiClient),
        chatRepositoryProvider.overrideWithValue(ChatRepository(apiClient)),
        authNotifierProvider.overrideWith(
          () => _TestAuthNotifier(const UserModel(id: 10, name: 'Müşteri', role: 'CUSTOMER')),
        ),
      ],
      child: const MaterialApp(
        home: ChatScreen(conversationId: 12, otherPartyName: 'Usta Ali'),
      ),
    );
  }

  Future<void> openChat(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
  }

  group('Moderation — repository', () {
    test('report posts type, id and reason and returns the server message', () async {
      final message = await ModerationRepository(apiClient).report(
        contentType: 'REVIEW',
        contentId: 7,
        reason: 'SPAM',
        details: '  reklam  ',
      );

      expect(message, 'Bildiriminiz alındı. Ekibimiz inceleyecek.');
      final body = backend.bodies['POST /reports'] as Map;
      expect(body['content_type'], 'REVIEW');
      expect(body['content_id'], 7);
      expect(body['reason'], 'SPAM');
      expect(body['details'], 'reklam');
    });

    test('block and unblock hit the blocks endpoints', () async {
      final repo = ModerationRepository(apiClient);
      await repo.blockUser(20);
      await repo.unblockUser(20);

      expect(backend.requests, containsAll(['POST /blocks', 'DELETE /blocks/20']));
      expect((backend.bodies['POST /blocks'] as Map)['user_id'], 20);
    });
  });

  group('Moderation — chat screen', () {
    testWidgets('only the other party\'s messages can be reported', (tester) async {
      await openChat(tester);

      expect(find.text('Uygunsuz mesaj'), findsOneWidget);
      expect(find.text('Benim mesajım'), findsOneWidget);
      expect(find.byKey(const Key('report_message_1')), findsOneWidget);
      expect(find.byKey(const Key('report_message_2')), findsNothing);
    });

    testWidgets('reporting a message sends the chosen reason and confirms', (tester) async {
      await openChat(tester);

      await tester.tap(find.byKey(const Key('report_message_1')));
      await tester.pumpAndSettle();
      expect(find.text('Mesajı bildir'), findsOneWidget);

      await tester.tap(find.byKey(const Key('report_reason_SPAM')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('report_submit_btn')));
      await tester.tap(find.byKey(const Key('report_submit_btn')));
      await tester.pumpAndSettle();

      final body = backend.bodies['POST /reports'] as Map;
      expect(body['content_type'], 'MESSAGE');
      expect(body['content_id'], 1);
      expect(body['reason'], 'SPAM');
      expect(find.text('Bildiriminiz alındı. Ekibimiz inceleyecek.'), findsOneWidget);
      expect(find.text('Mesajı bildir'), findsNothing); // sheet closed
    });

    testWidgets('a failed report keeps the sheet open and shows the real error', (tester) async {
      backend.failReport = true;
      await openChat(tester);

      await tester.tap(find.byKey(const Key('report_message_1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('report_submit_btn')));
      await tester.tap(find.byKey(const Key('report_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Geçerli bir bildirim nedeni seçin.'), findsOneWidget);
      expect(find.text('Mesajı bildir'), findsOneWidget);
    });

    testWidgets('blocking asks for confirmation, locks the composer and can be undone', (tester) async {
      await openChat(tester);
      expect(find.byKey(const Key('chat_input_field')), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat_menu_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Kullanıcıyı engelle'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat_block_item')));
      await tester.pumpAndSettle();

      // Nothing happens before the user confirms.
      expect(backend.requests.contains('POST /blocks'), isFalse);
      await tester.tap(find.text('Engelle'));
      await tester.pumpAndSettle();

      expect((backend.bodies['POST /blocks'] as Map)['user_id'], 20);
      expect(find.text('Bu kullanıcıyı engellediniz. Mesaj göndermek için engeli kaldırın.'), findsOneWidget);
      expect(find.byKey(const Key('chat_input_field')), findsNothing);

      await tester.tap(find.byKey(const Key('chat_unblock_btn')));
      await tester.pumpAndSettle();

      expect(backend.requests.contains('DELETE /blocks/20'), isTrue);
      expect(find.byKey(const Key('chat_input_field')), findsOneWidget);
    });

    testWidgets('a block set by the other side shows the server reason on send', (tester) async {
      backend.blockSendWith403 = true;
      await openChat(tester);

      await tester.enterText(find.byKey(const Key('chat_input_field')), 'Merhaba');
      await tester.tap(find.byKey(const Key('chat_send_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Bu kullanıcıya şu anda mesaj gönderemezsiniz.'), findsOneWidget);
    });
  });
}
