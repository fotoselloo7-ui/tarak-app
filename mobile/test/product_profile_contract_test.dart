import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/push_notification_service.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/features/customer/appointments/models/customer_appointment_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'push preference network failures never fabricate a saved value',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) => h.reject(
            DioException(
              requestOptions: o,
              type: DioExceptionType.connectionError,
            ),
          ),
        ),
      );
      final storage = SecureStorageService();
      final service = PushNotificationService(
        apiClient: ApiClient(storage: storage, customDio: dio),
        storage: storage,
      );
      await expectLater(service.getPushPreference(), throwsA(anything));
      await expectLater(service.updatePushPreference(false), throwsA(anything));
    },
  );
  test('malformed preference response cannot mean enabled or saved', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) => h.resolve(
          Response(requestOptions: o, statusCode: 200, data: {'data': []}),
        ),
      ),
    );
    final storage = SecureStorageService();
    final service = PushNotificationService(
      apiClient: ApiClient(storage: storage, customDio: dio),
      storage: storage,
    );
    await expectLater(service.getPushPreference(), throwsFormatException);
    await expectLater(
      service.updatePushPreference(true),
      throwsFormatException,
    );
  });
  test(
    'customer package snapshot preserves title, inclusions and total amount',
    () {
      final model = CustomerAppointmentModel.fromJson({
        'id': 64,
        'status': 'CONFIRMED',
        'total_price': 1250,
        'total_duration_minutes': 90,
        'offering': {
          'type': 'PACKAGE',
          'title': 'Damat Paketi',
          'price': 1250,
          'items': [
            {'name': 'Saç Kesimi'},
            {'name': 'Sakal Tıraşı'},
          ],
        },
        'services': [
          {
            'id': 1,
            'name': 'Saç Kesimi',
            'price_snapshot': 0,
            'duration_minutes_snapshot': 0,
          },
        ],
      });
      expect(model.servicesSummary, 'Damat Paketi');
      expect(model.offering!.isPackage, isTrue);
      expect(model.offering!.items, ['Saç Kesimi', 'Sakal Tıraşı']);
      expect(model.totalPrice, 1250);
      expect(model.totalDurationMinutes, 90);
    },
  );
  test(
    'canonical ALT_PROPOSED keeps alternative actions and readable label',
    () {
      final model = CustomerAppointmentModel.fromJson({
        'id': 1,
        'status': 'ALT_PROPOSED',
      });
      expect(model.isAlternativeProposed, isTrue);
      expect(model.canCancel, isTrue);
      expect(model.statusLabel, 'Alternatif Saat Önerildi');
    },
  );
}
