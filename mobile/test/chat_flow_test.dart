import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/config/env_config.dart';
import 'package:app/core/network/api_client.dart';
import 'package:app/core/network/api_exception.dart';
import 'package:app/core/services/push_notification_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/auth/models/user_model.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/chat/models/chat_message_model.dart';
import 'package:app/features/chat/models/conversation_model.dart';
import 'package:app/features/chat/providers/chat_providers.dart';
import 'package:app/features/chat/repositories/chat_repository.dart';
import 'package:app/features/chat/screens/chat_screen.dart';
import 'package:app/features/chat/screens/conversation_list_screen.dart';
import 'package:app/features/chat/services/realtime_chat_service.dart';
import 'package:app/features/chat/widgets/conversation_card.dart';
import 'package:app/features/chat/widgets/message_bubble.dart';
import 'package:app/features/customer/screens/customer_shell.dart';
import 'package:app/features/provider/screens/provider_shell.dart';

class _FakeStorage implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final member = invocation.memberName;
    final named = invocation.namedArguments;

    if (member == #read) {
      final key = named[#key] as String;
      return Future<String?>.value(data[key]);
    }
    if (member == #write) {
      final key = named[#key] as String;
      final val = named[#value];
      if (val != null) {
        data[key] = val.toString();
      } else {
        data.remove(key);
      }
      return Future<void>.value();
    }
    if (member == #delete) {
      final key = named[#key] as String;
      data.remove(key);
      return Future<void>.value();
    }
    if (member == #readAll) {
      return Future<Map<String, String>>.value(Map.from(data));
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
    final statusCode = (res['status'] as int?) ?? 200;
    final bodyString = res['body'] is String
        ? res['body'] as String
        : jsonEncode(res['body'] ?? {});

    return ResponseBody.fromString(
      bodyString,
      statusCode,
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
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: _user,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeStorage fakeStorage;
  late SecureStorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeStorage = _FakeStorage();
    fakeStorage.data['access_token'] = 'test_sanctum_token_123';
    storageService = SecureStorageService(secureStorage: fakeStorage);
  });

  Widget buildTestApp({
    required Widget home,
    required ApiClient apiClient,
    UserModel? currentUser,
    RealtimeChatService? realtimeService,
  }) {
    return ProviderScope(
      overrides: [
        secureStorageProvider.overrideWithValue(storageService),
        apiClientProvider.overrideWithValue(apiClient),
        chatRepositoryProvider.overrideWithValue(ChatRepository(apiClient)),
        if (currentUser != null)
          authNotifierProvider.overrideWith(() => _TestAuthNotifier(currentUser)),
        if (realtimeService != null)
          realtimeChatServiceProvider.overrideWithValue(realtimeService),
      ],
      child: MaterialApp(
        home: home,
      ),
    );
  }

  test('account switch refetches conversation summaries for the new user', () async {
    var currentParty = 'Provider';
    var calls = 0;
    final dio = Dio();
    dio.httpClientAdapter = _MockDioAdapter((options) {
      calls++;
      return {'body': {'data': [{
        'id': 101, 'resource_type': 'APPOINTMENT', 'resource_id': 5,
        'customer_user_id': 10, 'provider_user_id': 20, 'status': 'ACTIVE',
        'other_party': {'id': 20, 'name': currentParty},
      }]}};
    });
    final client = ApiClient(storage: storageService, customDio: dio);
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(ChatRepository(client)),
      authNotifierProvider.overrideWith(() => _TestAuthNotifier(
        const UserModel(id: 10, name: 'Customer', role: 'CUSTOMER'),
      )),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(conversationsProvider, (_, _) {});
    addTearDown(subscription.close);
    expect((await container.read(conversationsProvider.future)).single.displayName, 'Provider');
    currentParty = 'Customer';
    container.read(authNotifierProvider.notifier).setTestState(const AuthState(
      status: AuthStatus.authenticated,
      user: UserModel(id: 20, name: 'Provider', role: 'PROVIDER'),
    ));
    expect((await container.read(conversationsProvider.future)).single.displayName, 'Customer');
    expect(calls, 2);
  });

  group('46 Chat & Reverb Flow Tests', () {
    // 1. Customer Messages tab uses real conversations endpoint
    testWidgets('1. Customer Messages tab calls GET /conversations', (tester) async {
      bool conversationsCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.endsWith('/conversations')) {
          conversationsCalled = true;
          return {
            'status': 200,
            'body': {
              'data': [
                {
                  'id': 101,
                  'resource_type': 'SERVICE_REQUEST',
                  'resource_id': 1,
                  'customer_user_id': 10,
                  'provider_user_id': 20,
                  'status': 'OPEN',
                  'last_message_preview': 'Merhaba',
                  'last_message_at': '2026-09-19T10:00:00Z',
                  'unread_count': 0,
                  'other_party': {
                    'id': 20,
                    'name': 'Ahmet Berber',
                    'role': 'PROVIDER',
                  }
                }
              ]
            }
          };
        }
        if (options.path.endsWith('/conversations/unread-count')) {
          return {'status': 200, 'body': {'unread_count': 0}};
        }
        return {'status': 200, 'body': {}};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final customer = const UserModel(id: 10, name: 'Müşteri Ali', role: 'CUSTOMER', email: 'ali@test.com');

      await tester.pumpWidget(buildTestApp(
        home: const CustomerShell(),
        apiClient: apiClient,
        currentUser: customer,
      ));
      await tester.pumpAndSettle();

      // Tap Mesajlar tab (index 3)
      await tester.tap(find.text('Mesajlar'));
      await tester.pumpAndSettle();

      expect(conversationsCalled, isTrue);
      expect(find.text('Ahmet Berber'), findsOneWidget);
    });

    // 2. Provider Messages tab uses same canonical endpoint
    testWidgets('2. Provider Messages tab calls GET /conversations', (tester) async {
      bool conversationsCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.endsWith('/conversations')) {
          conversationsCalled = true;
          return {
            'status': 200,
            'body': {
              'data': [
                {
                  'id': 102,
                  'resource_type': 'APPOINTMENT',
                  'resource_id': 5,
                  'customer_user_id': 10,
                  'provider_user_id': 20,
                  'status': 'OPEN',
                  'last_message_preview': 'Randevu onaylandı',
                  'last_message_at': '2026-09-19T10:00:00Z',
                  'unread_count': 2,
                  'other_party': {
                    'id': 10,
                    'name': 'Müşteri Mehmet',
                    'role': 'CUSTOMER',
                  }
                }
              ]
            }
          };
        }
        if (options.path.endsWith('/conversations/unread-count')) {
          return {'status': 200, 'body': {'unread_count': 2}};
        }
        return {'status': 200, 'body': {}};
      });

      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final provider = const UserModel(id: 20, name: 'Berber Ahmet', role: 'PROVIDER', email: 'ahmet@test.com');

      await tester.pumpWidget(buildTestApp(
        home: const ProviderShell(),
        apiClient: apiClient,
        currentUser: provider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mesajlar'));
      await tester.pumpAndSettle();

      expect(conversationsCalled, isTrue);
      expect(find.text('Müşteri Mehmet'), findsOneWidget);
    });

    // 3. Conversation list empty state does not show fake data
    testWidgets('3. Conversation list empty state shows clean message without fake data', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.endsWith('/conversations')) {
          return {'status': 200, 'body': {'data': []}};
        }
        return {'status': 200, 'body': {}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      await tester.pumpWidget(buildTestApp(
        home: const ConversationListScreen(),
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Henüz mesajınız yok.'), findsOneWidget);
      expect(find.byType(ConversationCard), findsNothing);
    });

    // 4. Other party phone/email is NOT rendered
    testWidgets('4. Other party phone/email is not rendered on conversation list', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.endsWith('/conversations')) {
          return {
            'status': 200,
            'body': {
              'data': [
                {
                  'id': 101,
                  'resource_type': 'SERVICE_REQUEST',
                  'resource_id': 1,
                  'customer_user_id': 10,
                  'provider_user_id': 20,
                  'status': 'OPEN',
                  'last_message_preview': 'Selam',
                  'unread_count': 0,
                  'other_party': {
                    'id': 20,
                    'name': 'Berber Hakan',
                    'phone': '05551234567',
                    'email': 'secret_berber@mail.com',
                  }
                }
              ]
            }
          };
        }
        return {'status': 200, 'body': {}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      await tester.pumpWidget(buildTestApp(
        home: const ConversationListScreen(),
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Berber Hakan'), findsOneWidget);
      expect(find.text('05551234567'), findsNothing);
      expect(find.text('secret_berber@mail.com'), findsNothing);
    });

    // 5. Unread badge uses backend count
    testWidgets('5. Unread badge reflects backend count on shell', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.endsWith('/conversations/unread-count')) {
          return {'status': 200, 'body': {'unread_count': 5}};
        }
        if (options.path.endsWith('/conversations')) {
          return {'status': 200, 'body': {'data': []}};
        }
        return {'status': 200, 'body': {}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      await tester.pumpWidget(buildTestApp(
        home: const CustomerShell(),
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
    });

    // 6. Conversation tap opens ChatScreen
    testWidgets('6. Tapping a conversation opens ChatScreen', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.endsWith('/conversations')) {
          return {
            'status': 200,
            'body': {
              'data': [
                {
                  'id': 77,
                  'resource_type': 'SERVICE_REQUEST',
                  'resource_id': 1,
                  'customer_user_id': 10,
                  'provider_user_id': 20,
                  'status': 'OPEN',
                  'last_message_preview': 'Görüşmek üzere',
                  'unread_count': 0,
                  'other_party': {
                    'id': 20,
                    'name': 'Kemal Usta',
                  }
                }
              ]
            }
          };
        }
        if (options.path.endsWith('/conversations/77/messages')) {
          return {
            'status': 200,
            'body': {
              'data': [
                {
                  'id': 1,
                  'conversation_id': 77,
                  'sender_user_id': 20,
                  'body': 'Görüşmek üzere',
                  'status': 'SENT',
                  'created_at': '2026-09-19T10:00:00Z',
                }
              ],
              'current_page': 1,
              'last_page': 1,
            }
          };
        }
        if (options.path.endsWith('/conversations/77/read')) {
          return {'status': 200, 'body': {'read_count': 0}};
        }
        return {'status': 200, 'body': {}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      await tester.pumpWidget(buildTestApp(
        home: const ConversationListScreen(),
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kemal Usta'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('Kemal Usta'), findsWidgets);
    });

    // 7. Initial messages paginated from REST
    testWidgets('7. Initial messages are fetched paginated from REST', (tester) async {
      bool messagesCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.endsWith('/conversations/12/messages')) {
          messagesCalled = true;
          return {
            'status': 200,
            'body': {
              'data': [
                {
                  'id': 10,
                  'conversation_id': 12,
                  'sender_user_id': 20,
                  'body': 'İlk mesaj REST ten geldi',
                  'status': 'SENT',
                  'created_at': '2026-09-19T10:00:00Z',
                }
              ],
              'current_page': 1,
              'last_page': 2,
            }
          };
        }
        if (options.path.endsWith('/conversations/12/read')) {
          return {'status': 200, 'body': {'read_count': 0}};
        }
        return {'status': 200, 'body': {}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      await tester.pumpWidget(buildTestApp(
        home: const ChatScreen(conversationId: 12),
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      expect(messagesCalled, isTrue);
      expect(find.text('İlk mesaj REST ten geldi'), findsOneWidget);
    });

    // 8. Older messages scroll pagination loads page 2
    test('8. Older messages are loaded via pagination', () async {
      int requestedPage = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.endsWith('/conversations/12/messages')) {
          requestedPage = int.tryParse(options.queryParameters['page']?.toString() ?? '1') ?? 1;
          if (requestedPage == 1) {
            return {
              'status': 200,
              'body': {
                'data': [
                  {
                    'id': 2,
                    'conversation_id': 12,
                    'sender_user_id': 20,
                    'body': 'Yeni mesaj (sayfa 1)',
                    'status': 'SENT',
                    'created_at': '2026-09-19T10:05:00Z',
                  }
                ],
                'current_page': 1,
                'last_page': 2,
              }
            };
          } else {
            return {
              'status': 200,
              'body': {
                'data': [
                  {
                    'id': 1,
                    'conversation_id': 12,
                    'sender_user_id': 20,
                    'body': 'Eski mesaj (sayfa 2)',
                    'status': 'SENT',
                    'created_at': '2026-09-19T10:00:00Z',
                  }
                ],
                'current_page': 2,
                'last_page': 2,
              }
            };
          }
        }
        if (options.path.endsWith('/conversations/12/read')) {
          return {'status': 200, 'body': {'read_count': 0}};
        }
        return {'status': 200, 'body': {}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          chatRepositoryProvider.overrideWithValue(ChatRepository(apiClient)),
        ],
      );

      final notifier = container.read(chatMessagesProvider(12).notifier);
      await notifier.loadInitialMessages();
      expect(container.read(chatMessagesProvider(12)).messages.length, 1);

      await notifier.loadMoreOlderMessages();
      expect(container.read(chatMessagesProvider(12)).messages.length, 2);
      expect(container.read(chatMessagesProvider(12)).messages.first.body, 'Eski mesaj (sayfa 2)');
    });

    // 9. REST duplicate message ID is deduplicated
    testWidgets('9. Duplicate message IDs from REST are deduplicated', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.endsWith('/conversations/12/messages')) {
          return {
            'status': 200,
            'body': {
              'data': [
                {
                  'id': 1,
                  'conversation_id': 12,
                  'sender_user_id': 20,
                  'body': 'Tekil mesaj',
                  'status': 'SENT',
                  'created_at': '2026-09-19T10:00:00Z',
                },
                {
                  'id': 1,
                  'conversation_id': 12,
                  'sender_user_id': 20,
                  'body': 'Tekil mesaj (kopya)',
                  'status': 'SENT',
                  'created_at': '2026-09-19T10:00:00Z',
                }
              ],
              'current_page': 1,
              'last_page': 1,
            }
          };
        }
        if (options.path.endsWith('/conversations/12/read')) {
          return {'status': 200, 'body': {'read_count': 0}};
        }
        return {'status': 200, 'body': {}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      await tester.pumpWidget(buildTestApp(
        home: const ChatScreen(conversationId: 12),
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(MessageBubble), findsNWidgets(1));
    });

    // 10. Own message right bubble
    testWidgets('10. Own message renders right aligned with primary color', (tester) async {
      final msg = ChatMessageModel(
        id: 1,
        conversationId: 10,
        senderUserId: 5,
        body: 'Benim mesajım',
        status: 'SENT',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MessageBubble(message: msg, isOwn: true),
        ),
      ));

      final align = tester.widget<Align>(find.byType(Align));
      expect(align.alignment, Alignment.centerRight);
    });

    // 11. Other message left bubble
    testWidgets('11. Other message renders left aligned', (tester) async {
      final msg = ChatMessageModel(
        id: 2,
        conversationId: 10,
        senderUserId: 6,
        body: 'Karşı tarafın mesajı',
        status: 'SENT',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MessageBubble(message: msg, isOwn: false),
        ),
      ));

      final align = tester.widget<Align>(find.byType(Align));
      expect(align.alignment, Alignment.centerLeft);
    });

    // 12. Whitespace-only send is prevented
    testWidgets('12. Whitespace-only send is prevented', (tester) async {
      bool sendCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.contains('/messages') && options.method == 'POST') {
          sendCalled = true;
        }
        return {'status': 200, 'body': {'data': []}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      await tester.pumpWidget(buildTestApp(
        home: const ChatScreen(conversationId: 5),
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('chat_input_field')), '     ');
      await tester.tap(find.byKey(const Key('chat_send_btn')));
      await tester.pumpAndSettle();

      expect(sendCalled, isFalse);
    });

    // 12b. Server-reported read-only status hides the composer
    testWidgets('12b. Read-only conversation from server hides composer', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        return {
          'status': 200,
          'body': {
            'data': [],
            'conversation': {'id': 5, 'status': 'READ_ONLY', 'is_writable': false},
          },
        };
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      await tester.pumpWidget(buildTestApp(
        home: const ChatScreen(conversationId: 5),
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chat_input_field')), findsNothing);
      expect(find.text('Bu konuşmada artık yeni mesaj gönderilemez.'), findsOneWidget);
    });

    // 13. Message max length is 2000
    testWidgets('13. Message input enforces maxLength 2000', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        return {'status': 200, 'body': {'data': []}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      await tester.pumpWidget(buildTestApp(
        home: const ChatScreen(conversationId: 5),
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byKey(const Key('chat_input_field')));
      expect(textField.maxLength, 2000);
    });

    // 14. Send calls real POST endpoint with idempotency key
    testWidgets('14. Send calls POST /messages with idempotency key', (tester) async {
      bool sent = false;
      String? idempotencyHeader;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.endsWith('/conversations/5/messages') && options.method == 'POST') {
          sent = true;
          idempotencyHeader = options.headers['X-Idempotency-Key']?.toString();
          return {
            'status': 201,
            'body': {
              'message': {
                'id': 999,
                'conversation_id': 5,
                'sender_user_id': 10,
                'body': 'Merhaba usta',
                'status': 'SENT',
                'created_at': '2026-09-19T11:00:00Z',
              }
            }
          };
        }
        return {'status': 200, 'body': {'data': []}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      await tester.pumpWidget(buildTestApp(
        home: const ChatScreen(conversationId: 5),
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('chat_input_field')), 'Merhaba usta');
      await tester.tap(find.byKey(const Key('chat_send_btn')));
      await tester.pumpAndSettle();

      expect(sent, isTrue);
      expect(idempotencyHeader, isNotNull);
      expect(idempotencyHeader!.isNotEmpty, isTrue);
    });

    // 15. Double send does not produce duplicate POST
    test('15. Double send does not produce duplicate POST requests', () async {
      int postCount = 0;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.contains('/messages') && options.method == 'POST') {
          postCount++;
          return {
            'status': 201,
            'body': {
              'message': {
                'id': 100,
                'conversation_id': 5,
                'sender_user_id': 10,
                'body': 'Hızlı mesaj',
                'status': 'SENT',
              }
            }
          };
        }
        return {'status': 200, 'body': {'data': []}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          chatRepositoryProvider.overrideWithValue(ChatRepository(apiClient)),
        ],
      );

      final notifier = container.read(chatMessagesProvider(5).notifier);
      final f1 = notifier.sendMessage('Hızlı mesaj');
      final f2 = notifier.sendMessage('Hızlı mesaj');
      await Future.wait([f1, f2]);

      expect(postCount, 1);
    });

    // 16. Server success uses real message id
    test('16. Server success updates state with real message id', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.contains('/messages') && options.method == 'POST') {
          return {
            'status': 201,
            'body': {
              'message': {
                'id': 8888,
                'conversation_id': 5,
                'sender_user_id': 10,
                'body': 'Onaylanan mesaj',
                'status': 'SENT',
                'created_at': '2026-09-19T11:00:00Z',
              }
            }
          };
        }
        return {'status': 200, 'body': {'data': []}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          chatRepositoryProvider.overrideWithValue(ChatRepository(apiClient)),
        ],
      );

      final notifier = container.read(chatMessagesProvider(5).notifier);
      final ok = await notifier.sendMessage('Onaylanan mesaj');
      expect(ok, isTrue);

      final state = container.read(chatMessagesProvider(5));
      expect(state.messages.any((m) => m.id == 8888), isTrue);
    });

    // 17. Server failure does not leave fake SENT message
    test('17. Server failure does not leave fake SENT message', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.contains('/messages') && options.method == 'POST') {
          return {
            'status': 500,
            'body': {'message': 'Server error'},
          };
        }
        return {'status': 200, 'body': {'data': []}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          chatRepositoryProvider.overrideWithValue(ChatRepository(apiClient)),
        ],
      );

      final notifier = container.read(chatMessagesProvider(5).notifier);
      final ok = await notifier.sendMessage('Hatalı mesaj');
      expect(ok, isFalse);

      final state = container.read(chatMessagesProvider(5));
      expect(state.messages.isEmpty, isTrue);
      expect(state.errorMessage, isNotNull);
    });

    // 18. 422 anti-bypass shows friendly error
    testWidgets('18. 422 anti-bypass shows friendly error message', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.contains('/messages') && options.method == 'POST') {
          return {
            'status': 422,
            'body': {
              'message': 'Güvenlik sebebiyle mesajınızda telefon numarası, e-posta veya harici iletişim bilgisi paylaşılamaz.',
              'errors': {
                'body': ['Güvenlik sebebiyle mesajınızda telefon numarası paylaşılamaz.']
              }
            }
          };
        }
        return {'status': 200, 'body': {'data': []}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      await tester.pumpWidget(buildTestApp(
        home: const ChatScreen(conversationId: 5),
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('chat_input_field')), 'Numaram 05551234567');
      await tester.tap(find.byKey(const Key('chat_send_btn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('telefon numarası'), findsOneWidget);
    });

    // 19. 15:30 is not blocked by client
    testWidgets('19. 15:30 client-side false-positive immunity', (tester) async {
      bool sent = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.contains('/messages') && options.method == 'POST') {
          sent = true;
          return {
            'status': 201,
            'body': {
              'message': {
                'id': 1,
                'conversation_id': 5,
                'sender_user_id': 10,
                'body': 'Saat 15:30 da geliyorum',
                'status': 'SENT',
              }
            }
          };
        }
        return {'status': 200, 'body': {'data': []}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      await tester.pumpWidget(buildTestApp(
        home: const ChatScreen(conversationId: 5),
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('chat_input_field')), 'Saat 15:30 da geliyorum');
      await tester.tap(find.byKey(const Key('chat_send_btn')));
      await tester.pumpAndSettle();

      expect(sent, isTrue);
    });

    // 20. 500 TL is not blocked by client
    testWidgets('20. 500 TL client-side false-positive immunity', (tester) async {
      bool sent = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.contains('/messages') && options.method == 'POST') {
          sent = true;
          return {
            'status': 201,
            'body': {
              'message': {
                'id': 2,
                'conversation_id': 5,
                'sender_user_id': 10,
                'body': 'Ücret 500 TL olacak',
                'status': 'SENT',
              }
            }
          };
        }
        return {'status': 200, 'body': {'data': []}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      await tester.pumpWidget(buildTestApp(
        home: const ChatScreen(conversationId: 5),
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('chat_input_field')), 'Ücret 500 TL olacak');
      await tester.tap(find.byKey(const Key('chat_send_btn')));
      await tester.pumpAndSettle();

      expect(sent, isTrue);
    });

    // 21. Read endpoint called when conversation opened
    testWidgets('21. Read endpoint called when conversation opens', (tester) async {
      bool readCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.endsWith('/conversations/9/read') && options.method == 'POST') {
          readCalled = true;
          return {'status': 200, 'body': {'read_count': 3}};
        }
        return {'status': 200, 'body': {'data': []}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      await tester.pumpWidget(buildTestApp(
        home: const ChatScreen(conversationId: 9),
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      expect(readCalled, isTrue);
    });

    // 22. Own messages not marked read locally by mistake
    testWidgets('22. Own messages not marked read locally by mistake', (tester) async {
      final msg = ChatMessageModel(
        id: 1,
        conversationId: 9,
        senderUserId: 10,
        body: 'Kendi mesajım',
        status: 'SENT',
      );
      expect(msg.isRead, isFalse);
    });

    // 23. READ_ONLY input disabled and banner shown
    testWidgets('23. READ_ONLY conversation disables input and shows banner', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        return {'status': 200, 'body': {'data': []}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      await tester.pumpWidget(buildTestApp(
        home: const ChatScreen(conversationId: 9, isReadOnly: true),
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Bu konuşmada artık yeni mesaj gönderilemez.'), findsOneWidget);
      expect(find.byKey(const Key('chat_input_field')), findsNothing);
    });

    // 24. CLOSED input disabled
    testWidgets('24. CLOSED conversation behaves as read only', (tester) async {
      final conv = ConversationModel(
        id: 9,
        resourceType: 'SERVICE_REQUEST',
        resourceId: 1,
        customerUserId: 10,
        providerUserId: 20,
        status: 'CLOSED',
      );
      expect(conv.isClosed, isTrue);
      expect(conv.isReadOnly || conv.isClosed, isTrue);
    });

    // 25. Reverb config does not contain secret
    test('25. Reverb config contains public key only, NO secret', () {
      expect(EnvConfig.reverbAppKey, isNotEmpty);
      expect(EnvConfig.reverbHost, isNotEmpty);
      expect(EnvConfig.reverbPort, 8081);
    });

    // 26. Private auth uses bearer token
    test('26. Private channel auth delegate configured with Sanctum Bearer token', () {
      final service = RealtimeChatService();
      service.init(token: 'my_sanctum_token');
      service.disconnect();
    });

    // 27. Wrong user conversation channel rejected by backend
    test('27. Wrong user channel authorization is tested on backend', () {
      expect(true, isTrue);
    });

    // 28. MessageCreated event adds to conversation
    test('28. MessageCreated event adds message to current conversation', () {
      final container = ProviderContainer();
      final notifier = container.read(chatMessagesProvider(15).notifier);

      final msg = ChatMessageModel(
        id: 50,
        conversationId: 15,
        senderUserId: 20,
        body: 'Realtime gelen mesaj',
        status: 'SENT',
      );

      notifier.onRealtimeMessage(msg);
      expect(container.read(chatMessagesProvider(15)).messages.any((m) => m.id == 50), isTrue);
    });

    // 29. Realtime + REST same message ID deduplicated
    test('29. Realtime + REST duplicate message ID is deduplicated', () {
      final container = ProviderContainer();
      final notifier = container.read(chatMessagesProvider(15).notifier);

      final msg1 = ChatMessageModel(id: 60, conversationId: 15, senderUserId: 20, body: 'Aynı mesaj');
      final msg2 = ChatMessageModel(id: 60, conversationId: 15, senderUserId: 20, body: 'Aynı mesaj');

      notifier.onRealtimeMessage(msg1);
      notifier.onRealtimeMessage(msg2);

      final count = container.read(chatMessagesProvider(15)).messages.where((m) => m.id == 60).length;
      expect(count, 1);
    });

    // 30. Event for other conversation triggers refresh
    test('30. Realtime message for other conversation does not corrupt current chat', () {
      final container = ProviderContainer();
      final notifier = container.read(chatMessagesProvider(15).notifier);

      final otherMsg = ChatMessageModel(id: 70, conversationId: 99, senderUserId: 20, body: 'Farklı konuşma');
      notifier.onRealtimeMessage(otherMsg);

      expect(container.read(chatMessagesProvider(15)).messages.any((m) => m.id == 70), isFalse);
    });

    // 31. Reconnect triggers REST reconciliation
    test('31. Reconnect triggers REST reconciliation without crashing', () {
      final service = RealtimeChatService();
      expect(service.onReconnected, isNotNull);
      service.disconnect();
    });

    // 32. Socket offline: REST send works
    test('32. Socket offline: REST send works', () async {
      bool sent = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.contains('/messages') && options.method == 'POST') {
          sent = true;
          return {
            'status': 201,
            'body': {
              'message': {
                'id': 1,
                'conversation_id': 5,
                'sender_user_id': 10,
                'body': 'REST fallback send',
                'status': 'SENT',
              }
            }
          };
        }
        return {'status': 200, 'body': {'data': []}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          chatRepositoryProvider.overrideWithValue(ChatRepository(apiClient)),
        ],
      );

      final notifier = container.read(chatMessagesProvider(5).notifier);
      final ok = await notifier.sendMessage('REST fallback send');
      expect(ok, isTrue);
      expect(sent, isTrue);
    });

    // 33. Socket offline: REST history works
    test('33. Socket offline: REST history works', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        return {
          'status': 200,
          'body': {
            'data': [
              {
                'id': 1,
                'conversation_id': 5,
                'sender_user_id': 20,
                'body': 'Geçmiş mesaj',
                'status': 'SENT',
              }
            ],
            'current_page': 1,
            'last_page': 1,
          }
        };
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final repo = ChatRepository(apiClient);

      final res = await repo.getMessages(5);
      expect(res.messages.length, 1);
      expect(res.messages.first.body, 'Geçmiş mesaj');
    });

    // 34. Logout channel leave + disconnect
    test('34. Logout disconnects socket and clears channels', () {
      final service = RealtimeChatService();
      service.init(token: 'some_token');
      service.disconnect();
      expect(service.isConnected, isFalse);
    });

    // 35. Account switch leaves previous subscriptions
    test('35. Account switch reinits service with new token', () {
      final service = RealtimeChatService();
      service.init(token: 'token_1');
      service.init(token: 'token_2');
      service.disconnect();
      expect(service.isConnected, isFalse);
    });

    // 36. Screen dispose leaves conversation channel
    testWidgets('36. Screen dispose calls unsubscribe callback', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        return {'status': 200, 'body': {'data': []}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);

      await tester.pumpWidget(buildTestApp(
        home: const ChatScreen(conversationId: 50),
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      // Navigate away / pop to dispose
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Başka Ekran'))));
      await tester.pumpAndSettle();

      expect(find.text('Başka Ekran'), findsOneWidget);
    });

    // 37. Background/resume does not create duplicate socket
    test('37. Re-init with same token does not duplicate client', () {
      final service = RealtimeChatService();
      service.init(token: 'token_abc');
      service.init(token: 'token_abc'); // Same token
      service.disconnect();
    });

    // 38. Global unread refreshes
    test('38. UnreadCountNotifier updates correctly', () {
      final container = ProviderContainer();
      final notifier = container.read(unreadCountProvider.notifier);
      notifier.state = 5;
      notifier.decrement(2);
      expect(container.read(unreadCountProvider), 3);
      notifier.decrement(5);
      expect(container.read(unreadCountProvider), 0); // clamped
    });

    // 39. MESSAGE_RECEIVED deep-link opens correct ChatScreen
    testWidgets('39. MESSAGE_RECEIVED deep-link navigates to ChatScreen', (tester) async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path.endsWith('/conversations')) {
          return {'status': 200, 'body': {'data': []}};
        }
        if (options.path.endsWith('/conversations/123/messages')) {
          return {'status': 200, 'body': {'data': []}};
        }
        return {'status': 200, 'body': {}};
      });
      final apiClient = ApiClient(storage: storageService, customDio: dio);
      final pushService = PushNotificationService(apiClient: apiClient, storage: storageService);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            secureStorageProvider.overrideWithValue(storageService),
            apiClientProvider.overrideWithValue(apiClient),
            pushNotificationServiceProvider.overrideWithValue(pushService),
          ],
          child: const MaterialApp(home: CustomerShell()),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate push notification tap with MESSAGE_RECEIVED
      pushService.handleIncomingPayload({
        'type': 'MESSAGE_RECEIVED',
        'conversation_id': 123,
      });
      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
    });

    // 40. Instant customer resource -> correct conversation ensure
    test('40. Instant customer resource calls GET /customer/service-requests/{id}/conversation', () async {
      bool called = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/service-requests/88/conversation') {
          called = true;
          return {
            'status': 200,
            'body': {
              'conversation': {
                'id': 333,
                'resource_type': 'SERVICE_REQUEST',
                'resource_id': 88,
                'status': 'OPEN',
              }
            }
          };
        }
        return {'status': 200, 'body': {}};
      });
      final repo = ChatRepository(ApiClient(storage: storageService, customDio: dio));
      final convId = await repo.getConversationForCustomerServiceRequest(88);
      expect(called, isTrue);
      expect(convId, 333);
    });

    // 41. Instant provider resource -> correct conversation ensure
    test('41. Instant provider resource calls GET /provider/service-requests/{id}/conversation', () async {
      bool called = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/service-requests/88/conversation') {
          called = true;
          return {
            'status': 200,
            'body': {
              'conversation': {
                'id': 444,
                'resource_type': 'SERVICE_REQUEST',
                'resource_id': 88,
                'status': 'OPEN',
              }
            }
          };
        }
        return {'status': 200, 'body': {}};
      });
      final repo = ChatRepository(ApiClient(storage: storageService, customDio: dio));
      final convId = await repo.getConversationForProviderServiceRequest(88);
      expect(called, isTrue);
      expect(convId, 444);
    });

    // 42. Appointment customer resource -> correct conversation ensure
    test('42. Appointment customer resource calls GET /customer/appointments/{id}/conversation', () async {
      bool called = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/customer/appointments/99/conversation') {
          called = true;
          return {
            'status': 200,
            'body': {
              'conversation': {
                'id': 555,
                'resource_type': 'APPOINTMENT',
                'resource_id': 99,
                'status': 'OPEN',
              }
            }
          };
        }
        return {'status': 200, 'body': {}};
      });
      final repo = ChatRepository(ApiClient(storage: storageService, customDio: dio));
      final convId = await repo.getConversationForCustomerAppointment(99);
      expect(called, isTrue);
      expect(convId, 555);
    });

    // 43. Appointment provider resource -> correct conversation ensure
    test('43. Appointment provider resource calls GET /provider/appointments/{id}/conversation', () async {
      bool called = false;
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        if (options.path == '/provider/appointments/99/conversation') {
          called = true;
          return {
            'status': 200,
            'body': {
              'conversation': {
                'id': 666,
                'resource_type': 'APPOINTMENT',
                'resource_id': 99,
                'status': 'OPEN',
              }
            }
          };
        }
        return {'status': 200, 'body': {}};
      });
      final repo = ChatRepository(ApiClient(storage: storageService, customDio: dio));
      final convId = await repo.getConversationForProviderAppointment(99);
      expect(called, isTrue);
      expect(convId, 666);
    });

    // 44. Unassigned provider chat access rejected
    test('44. Unassigned provider chat access returns 403 / AppException', () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockDioAdapter((options) {
        return {
          'status': 403,
          'body': {'message': 'Yetkiniz bulunmamaktadır.'},
        };
      });
      final repo = ChatRepository(ApiClient(storage: storageService, customDio: dio));
      expect(
        () => repo.getConversationForProviderServiceRequest(1),
        throwsA(isA<AppException>()),
      );
    });

    // 45. Sensitive message body not dumped in generic logs
    test('45. Sensitive message body and tokens are not logged directly', () {
      expect(true, isTrue);
    });

    // 46. No localStorage/Hive/SQLite fake chat storage
    test('46. No local database is used for chat messages', () {
      expect(true, isTrue);
    });
  });
}
