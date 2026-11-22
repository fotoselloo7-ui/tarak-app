import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app/core/network/api_client.dart';
import 'package:app/core/services/secure_storage_service.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/tarak_rating.dart';
import 'package:app/core/widgets/verified_tick.dart';
import 'package:app/features/auth/models/user_model.dart';
import 'package:app/features/auth/providers/auth_provider.dart';
import 'package:app/features/auth/screens/register_screen.dart';
import 'package:app/features/customer/appointments/models/customer_appointment_model.dart';
import 'package:app/features/customer/appointments/providers/customer_appointment_providers.dart';
import 'package:app/features/customer/appointments/screens/create_appointment_screen.dart';
import 'package:app/features/customer/models/customer_address.dart';
import 'package:app/features/customer/models/service_request_model.dart';
import 'package:app/features/customer/providers/instant_request_provider.dart';
import 'package:app/features/customer/screens/customer_home_tab.dart';
import 'package:app/features/customer/screens/provider_detail_screen.dart';
import 'package:app/features/customer/services/geo_service.dart';
import 'package:app/features/customer/widgets/tarak_provider_profile_content.dart';
import 'package:app/features/map_directory/models/map_business_model.dart';
import 'package:app/features/map_directory/models/map_route_model.dart';
import 'package:app/features/map_directory/widgets/map_business_sheet.dart';
import 'package:app/features/map_directory/screens/business_showcase_screen.dart';
import 'package:app/features/map_directory/screens/tarak_map_screen.dart';
import 'package:app/features/map_directory/services/directions_launcher.dart';
import 'package:app/features/map_directory/services/tarak_marker_renderer.dart';
import 'package:app/features/provider/screens/provider_profile_tab.dart';
import 'package:app/features/provider/staff/models/provider_staff_model.dart';
import 'package:app/features/shared/widgets/provider_gallery.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/disk_asset_bundle.dart';

class _CapturedRequest {
  final String method;
  final String path;
  final Map<String, dynamic> query;
  final dynamic data;

  _CapturedRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.data,
  });
}

class _NoRequests extends MyServiceRequestsNotifier {
  @override
  Future<List<ServiceRequestModel>> build() async => const [];
}

class _NoAppointments extends CustomerAppointmentsNotifier {
  @override
  Future<List<CustomerAppointmentModel>> build() async => const [];
}

class _HaritaMockAdapter implements HttpClientAdapter {
  final List<_CapturedRequest> requests = [];

  bool failMapBusinesses = false;
  bool failRoute = false;
  bool emptyCitySearch = false;
  bool providerDirectoryListed = false;
  bool providerAcceptsNewClients = false;
  String providerWorkMode = 'venue';
  int providerRadiusKm = 15;
  String providerBusinessName = 'Salon Deniz';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    dynamic parsedBody = options.data;
    if (options.data is String && (options.data as String).isNotEmpty) {
      try {
        parsedBody = jsonDecode(options.data as String);
      } catch (_) {}
    }

    requests.add(
      _CapturedRequest(
        method: options.method,
        path: options.path,
        query: Map<String, dynamic>.from(options.queryParameters),
        data: parsedBody,
      ),
    );

    final path = options.path;
    if (options.method == 'GET' && path == '/map/businesses') {
      if (failMapBusinesses) {
        return ResponseBody.fromString(
          jsonEncode({'success': false, 'message': 'Server Error'}),
          500,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }

      final filterType = options.queryParameters['type']?.toString();
      final filterCity = options.queryParameters['city']?.toString();
      final filterMode = options.queryParameters['work_mode']?.toString();
      final filterBookingOnly = options.queryParameters['booking_only'] == 1;
      final filterQ =
          (options.queryParameters['q'] ?? '').toString().toLowerCase().trim();

      final allPins = <Map<String, dynamic>>[
        {
          'id': '101',
          'user_id': '10',
          'slug': 'altin-makas',
          'public_url': 'https://tarak.app/isletme/altin-makas',
          'business_name': 'Altın Makas Berber',
          'name': 'Usta Ahmet',
          'provider_type': 'barber',
          'work_mode': 'venue',
          'rating': 4.9,
          'review_count': 14,
          'is_verified': true,
          'accepts_tarak_bookings': false,
          'is_online': false,
          'city': 'İstanbul',
          'district': 'Kadıköy',
          'neighborhood': 'Caferağa',
          'formatted_address': 'Moda Cd, Kadıköy, İstanbul',
          'latitude': 40.9901,
          'longitude': 29.0211,
          'has_public_pin': true,
          'can_get_directions': true,
          'service_count': 2,
          'service_radius_km': 15,
          'service_areas': <Map<String, dynamic>>[],
        },
        {
          'id': '102',
          'user_id': '11',
          'slug': 'elit-kuafor',
          'public_url': 'https://tarak.app/isletme/elit-kuafor',
          'business_name': 'Elit Kuaför',
          'name': 'Selin Hanım',
          'provider_type': 'coiffeur',
          'work_mode': 'both',
          'rating': 4.5,
          'review_count': 6,
          'is_verified': false,
          'accepts_tarak_bookings': true,
          'is_online': true,
          'city': 'İstanbul',
          'district': 'Kadıköy',
          'neighborhood': 'Suadiye',
          'formatted_address': 'Bağdat Cd, Kadıköy, İstanbul',
          'latitude': 40.9612,
          'longitude': 29.0815,
          'has_public_pin': true,
          'can_get_directions': true,
          'service_count': 3,
          'service_radius_km': 12,
          'service_areas': [
            {'province': 'İstanbul', 'district': 'Kadıköy', 'neighborhood': null},
          ],
        },
        {
          'id': '104',
          'user_id': '14',
          'slug': 'akdeniz-berber',
          'public_url': 'https://tarak.app/isletme/akdeniz-berber',
          'business_name': 'Akdeniz Berber Antalya',
          'name': 'Murat Usta',
          'provider_type': 'barber',
          'work_mode': 'both',
          'rating': 4.7,
          'review_count': 9,
          'is_verified': true,
          'accepts_tarak_bookings': true,
          'is_online': true,
          'city': 'Antalya',
          'district': 'Muratpaşa',
          'neighborhood': 'Işıklar',
          'formatted_address': 'Atatürk Cd, Muratpaşa, Antalya',
          'latitude': 36.8850,
          'longitude': 30.7050,
          'has_public_pin': true,
          'can_get_directions': true,
          'service_count': 2,
          'service_radius_km': 15,
          'service_areas': <Map<String, dynamic>>[],
        },
      ];

      final filteredPins = emptyCitySearch
          ? <Map<String, dynamic>>[]
          : allPins.where((p) {
              if (filterType != null && p['provider_type'] != filterType) {
                return false;
              }
              if (filterCity != null &&
                  p['city'].toString().toLowerCase() !=
                      filterCity.toLowerCase()) {
                return false;
              }
              if (filterMode == 'venue' &&
                  p['work_mode'] != 'venue' &&
                  p['work_mode'] != 'both') {
                return false;
              }
              if (filterMode == 'mobile' && p['work_mode'] != 'both') {
                return false;
              }
              if (filterBookingOnly && p['accepts_tarak_bookings'] != true) {
                return false;
              }
              if (filterQ.isNotEmpty &&
                  !p['business_name']
                      .toString()
                      .toLowerCase()
                      .contains(filterQ)) {
                return false;
              }
              return true;
            }).toList();

      final body = {
        'success': true,
        'data': filteredPins,
        'mobile_providers': (emptyCitySearch || filterMode == 'venue' || filterType == 'coiffeur' || (filterCity != null && filterCity != 'İstanbul'))
            ? <Map<String, dynamic>>[]
            : [
          {
            'id': '103',
            'user_id': '12',
            'slug': 'gezici-ali',
            'public_url': 'https://tarak.app/isletme/gezici-ali',
            'business_name': 'Gezici Usta Ali',
            'name': 'Ali Yılmaz',
            'provider_type': 'barber',
            'work_mode': 'mobile',
            'rating': 4.8,
            'review_count': 5,
            'is_verified': true,
            'accepts_tarak_bookings': true,
            'is_online': true,
            'city': 'İstanbul',
            'district': 'Beşiktaş',
            'neighborhood': null,
            'formatted_address': 'Beşiktaş, İstanbul (Adrese Gelen)',
            'latitude': null,
            'longitude': null,
            'has_public_pin': false,
            'can_get_directions': false,
            'service_count': 1,
            'service_radius_km': 20,
            'service_areas': [
              {'province': 'İstanbul', 'district': 'Beşiktaş', 'neighborhood': null},
            ],
          },
        ],
        'meta': {
          'total_pins': filteredPins.length,
          'total_mobile': 1,
          'map_provider': 'openfreemap',
          'map_style_url': 'https://tiles.openfreemap.org/styles/liberty',
          'truncated': false,
        },
      };
      return ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    Map<String, dynamic> body;
    if (options.method == 'GET' && path == '/map/businesses/altin-makas') {
      body = {
        'success': true,
        'data': {
          'id': '101',
          'user_id': '10',
          'slug': 'altin-makas',
          'public_url': 'https://tarak.app/isletme/altin-makas',
          'business_name': 'Altın Makas Berber',
          'name': 'Usta Ahmet',
          'title': 'Klasik & Modern Kesim',
          'bio': 'Kadıköy merkezde 15 yıllık deneyim.',
          'provider_type': 'barber',
          'work_mode': 'venue',
          'is_verified': true,
          'directory_listed': true,
          'directory_status': 'APPROVED',
          'accepts_tarak_bookings': false,
          'cover_url': 'https://cdn.tarak.test/cover.jpg',
          'gallery': [
            'https://cdn.tarak.test/haircut1.jpg',
            'https://cdn.tarak.test/shave2.jpg',
          ],
          'city': 'İstanbul',
          'district': 'Kadıköy',
          'formatted_address': 'Moda Cd, Kadıköy, İstanbul',
          'latitude': 40.9901,
          'longitude': 29.0211,
          'has_public_pin': true,
          'can_get_directions': true,
          'service_radius_km': 15,
          'service_areas': <Map<String, dynamic>>[],
          'working_hours': [
            {
              'day': 'monday',
              'label': 'Pazartesi',
              'enabled': true,
              'start_time': '09:00',
              'end_time': '19:00',
              'breaks': <Map<String, dynamic>>[],
            },
          ],
          'services': [
            {
              'id': '1',
              'provider_service_id': '11',
              'name': 'Saç Kesimi',
              'price': 350,
              'duration_minutes': 45,
            },
          ],
          'packages': <Map<String, dynamic>>[],
          'staff': <Map<String, dynamic>>[],
          'service_count': 1,
          'rating': 4.9,
          'review_count': 14,
          'reviews': [
            {
              'id': 91,
              'rating': 5,
              'comment': 'Çok özenli ve temiz kesim.',
              'customer_name': 'Mehmet A.',
            },
          ],
        },
      };
    } else if (options.method == 'GET' && path == '/providers/10/reviews') {
      body = {
        'success': true,
        'data': {
          'average': 4.9,
          'count': 14,
          'is_demo': false,
          'reviews': [
            {
              'id': 91,
              'rating': 5,
              'comment': 'Çok özenli ve temiz kesim.',
              'customer_name': 'Mehmet A.',
            },
          ],
        },
      };
    } else if (options.method == 'GET' && path == '/customer/providers/11/offerings') {
      body = {
        'success': true,
        'data': {
          'provider': {
            'id': '102',
            'user_id': '11',
            'business_name': 'Elit Kuaför',
            'provider_type': 'coiffeur',
            'avatar_url': 'https://cdn.tarak.test/elit-avatar.jpg',
            'cover_url': 'https://cdn.tarak.test/elit-cover.jpg',
            'gallery': ['https://cdn.tarak.test/elit-1.jpg'],
            'city': 'İstanbul',
            'district': 'Kadıköy',
            'bio': 'Fön, kesim ve gelin saçı uzmanı.',
            'experience_years': 8,
            'is_verified': true,
            'is_online': true,
            'rating': 4.6,
            'review_count': 6,
          },
          'services': [
            {
              'provider_service_id': 21,
              'service_id': 3,
              'name': 'Fön & Şekillendirme',
              'price': 280,
              'duration_minutes': 40,
            },
          ],
          'packages': <Map<String, dynamic>>[],
        },
      };
    } else if (options.method == 'GET' && path == '/providers/11/reviews') {
      body = {
        'success': true,
        'data': {
          'average': 4.6,
          'count': 6,
          'is_demo': false,
          'reviews': [
            {
              'id': 120,
              'rating': 5,
              'comment': 'Çok memnun kaldım.',
              'customer_name': 'Zeynep K.',
            },
          ],
        },
      };
    } else if (options.method == 'GET' && path == '/customer/providers/11/staff') {
      body = {
        'success': true,
        'data': [
          {
            'id': 501,
            'first_name': 'Derya',
            'last_name': 'Yılmaz',
            'full_name': 'Derya Yılmaz',
            'title': 'Baş Stilist',
            'specialty': 'Fön & Renklendirme',
            'accepts_appointments': true,
            'services': [
              {'service_id': 3, 'service_name': 'Fön & Şekillendirme'},
            ],
          },
        ],
      };
    } else if (options.method == 'GET' && path == '/map/businesses/elit-kuafor') {
      body = {
        'success': true,
        'data': {
          'id': '102',
          'user_id': '11',
          'slug': 'elit-kuafor',
          'public_url': 'https://tarak.app/isletme/elit-kuafor',
          'business_name': 'Elit Kuaför',
          'name': 'Selin Hanım',
          'bio': 'Fön, kesim ve gelin saçı uzmanı.',
          'experience_years': 8,
          'provider_type': 'coiffeur',
          'work_mode': 'both',
          'avatar_url': 'https://cdn.tarak.test/elit-avatar.jpg',
          'cover_url': 'https://cdn.tarak.test/elit-cover.jpg',
          'gallery': ['https://cdn.tarak.test/elit-1.jpg'],
          'is_verified': true,
          'directory_listed': true,
          'directory_status': 'APPROVED',
          'accepts_tarak_bookings': true,
          'is_online': true,
          'city': 'İstanbul',
          'district': 'Kadıköy',
          'formatted_address': 'Bağdat Cd, Kadıköy, İstanbul',
          'latitude': 40.9612,
          'longitude': 29.0815,
          'has_public_pin': true,
          'can_get_directions': true,
          'service_radius_km': 12,
          'service_areas': [
            {'province': 'İstanbul', 'district': 'Kadıköy', 'neighborhood': null},
          ],
          'working_hours': <Map<String, dynamic>>[],
          'services': [
            {
              'id': '3',
              'provider_service_id': '21',
              'name': 'Fön & Şekillendirme',
              'price': 280,
              'duration_minutes': 40,
            },
          ],
          'packages': <Map<String, dynamic>>[],
          'staff': [
            {
              'id': 501,
              'first_name': 'Derya',
              'last_name': 'Yılmaz',
              'full_name': 'Derya Yılmaz',
              'title': 'Baş Stilist',
              'specialty': 'Fön & Renklendirme',
              'accepts_appointments': true,
              'services': [
                {'service_id': 3, 'service_name': 'Fön & Şekillendirme'},
              ],
            },
          ],
          'service_count': 1,
          'rating': 4.6,
          'review_count': 6,
          'reviews': [
            {
              'id': 120,
              'rating': 5,
              'comment': 'Çok memnun kaldım.',
              'customer_name': 'Zeynep K.',
            },
          ],
        },
      };
    } else if (options.method == 'GET' && path == '/provider/profile') {
      body = {
        'success': true,
        'data': {
          'user': {'id': 77, 'name': 'Deniz Usta', 'role': 'PROVIDER'},
          'profile': {
            'id': '77',
            'user_id': '77',
            'business_name': providerBusinessName,
            'slug': 'salon-deniz',
            'public_web_url': 'https://tarak.app/isletme/salon-deniz',
            'provider_type': 'barber',
            'work_mode': providerWorkMode,
            'is_approved': false,
            'identity_status': 'PENDING',
            'is_online': false,
            'accepts_new_clients': providerAcceptsNewClients,
            'directory_listed': providerDirectoryListed,
            'directory_status':
                providerDirectoryListed ? 'PENDING' : 'NOT_REQUESTED',
            'service_radius_km': providerRadiusKm,
            'city': 'İstanbul',
            'district': 'Kadıköy',
            'is_verified': false,
            'service_areas': [
              {'id': '1', 'province': 'İstanbul', 'district': 'Kadıköy'},
            ],
          },
        },
      };
    } else if (options.method == 'GET' && path == '/provider/reviews') {
      body = {
        'success': true,
        'data': {
          'average': 4.8,
          'count': 5,
          'is_demo': false,
          'reviews': <Map<String, dynamic>>[],
        },
      };
    } else if (options.method == 'GET' && path == '/provider/wallet') {
      body = {
        'success': true,
        'data': {
          'cash_balance': 100.0,
          'promo_balance': 500.0,
          'pending_balance': 0.0,
          'withdrawable_balance': 100.0,
          'active_reservations': <Map<String, dynamic>>[],
        },
      };
    } else if (options.method == 'GET' && path == '/provider/payout-account') {
      body = {
        'success': true,
        'data': {'iban_masked': 'TR00 **** 1234'},
      };
    } else if (options.method == 'PUT' && path == '/provider/profile') {
      if (parsedBody is Map) {
        if (parsedBody.containsKey('directory_listed')) {
          providerDirectoryListed = parsedBody['directory_listed'] == true;
        }
        if (parsedBody.containsKey('accepts_new_clients')) {
          providerAcceptsNewClients = parsedBody['accepts_new_clients'] == true;
        }
        if (parsedBody.containsKey('work_mode')) {
          providerWorkMode = parsedBody['work_mode'].toString();
        }
        if (parsedBody.containsKey('service_radius_km')) {
          providerRadiusKm =
              (parsedBody['service_radius_km'] as num?)?.toInt() ?? 15;
        }
        if (parsedBody.containsKey('business_name')) {
          providerBusinessName = parsedBody['business_name'].toString();
        }
      }
      body = {
        'success': true,
        'message': 'Profil güncellendi.',
        'data': {
          'user': {'id': 77, 'name': 'Deniz Usta', 'role': 'PROVIDER'},
          'profile': {
            'id': '77',
            'user_id': '77',
            'business_name': providerBusinessName,
            'slug': 'salon-deniz',
            'public_web_url': 'https://tarak.app/isletme/salon-deniz',
            'provider_type': 'barber',
            'work_mode': providerWorkMode,
            'accepts_new_clients': providerAcceptsNewClients,
            'directory_listed': providerDirectoryListed,
            'directory_status':
                providerDirectoryListed ? 'PENDING' : 'NOT_REQUESTED',
            'service_radius_km': providerRadiusKm,
            'city': 'İstanbul',
            'district': 'Kadıköy',
            'is_verified': false,
            'service_areas': <Map<String, dynamic>>[],
          },
        },
      };
    } else if (options.method == 'GET' && path == '/map/route') {
      if (failRoute) {
        return ResponseBody.fromString(
          jsonEncode({
            'success': false,
            'code': 'UNAVAILABLE',
            'message': 'Yol tarifi servisine şu anda ulaşılamıyor.',
          }),
          503,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      final oLat = (options.queryParameters['origin_lat'] as num).toDouble();
      final oLng = (options.queryParameters['origin_lng'] as num).toDouble();
      final dLat = (options.queryParameters['dest_lat'] as num).toDouble();
      final dLng = (options.queryParameters['dest_lng'] as num).toDouble();
      body = {
        'success': true,
        'data': {
          'provider': 'valhalla',
          'profile': options.queryParameters['profile'] ?? 'driving',
          'distance_meters': 1500,
          'duration_seconds': 300,
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [oLng, oLat],
              [(oLng + dLng) / 2 + 0.002, (oLat + dLat) / 2 + 0.001],
              [dLng, dLat],
            ],
          },
          'bounds': {
            'south': oLat < dLat ? oLat : dLat,
            'west': oLng < dLng ? oLng : dLng,
            'north': oLat > dLat ? oLat : dLat,
            'east': oLng > dLng ? oLng : dLng,
          },
        },
      };
    } else if (options.method == 'GET' && path == '/geo/search') {
      final q = (options.queryParameters['q'] ?? '').toString().toLowerCase();
      if (q.contains('alanya')) {
        body = {
          'success': true,
          'data': {
            'latitude': 36.5437,
            'longitude': 32.0019,
            'province': 'Antalya',
            'district': 'Alanya',
          },
        };
      } else {
        body = {
          'success': true,
          'data': {'latitude': 36.8850, 'longitude': 30.7050},
        };
      }
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

  @override
  void close({bool force = false}) {}
}

ApiClient _makeApi(_HaritaMockAdapter adapter) => ApiClient(
      storage: SecureStorageService(),
      customDio: Dio()..httpClientAdapter = adapter,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tarak Harita Privacy, Markers & Performance', () {
    test('mobile work_mode never retains coordinates or pin/directions flags', () {
      final summary = MapBusinessSummary.fromJson({
        'id': '50',
        'user_id': '99',
        'slug': 'gizli-gezici',
        'business_name': 'Gezici Berber',
        'provider_type': 'barber',
        'work_mode': 'mobile',
        'neighborhood': 'Gizli Mahalle',
        'latitude': 41.0422,
        'longitude': 29.0083,
        'has_public_pin': true,
        'can_get_directions': true,
        'distance_km': 1.2,
      });

      expect(summary.latitude, isNull);
      expect(summary.longitude, isNull);
      expect(summary.neighborhood, isNull);
      expect(summary.hasPublicPin, isFalse);
      expect(summary.canGetDirections, isFalse);
      expect(summary.distanceKm, isNull);

      final detail = MapBusinessDetail.fromJson({
        'id': '50',
        'user_id': '99',
        'slug': 'gizli-gezici',
        'business_name': 'Gezici Berber',
        'provider_type': 'barber',
        'work_mode': 'mobile',
        'neighborhood': 'Gizli Mahalle',
        'street': 'Gizli Sk',
        'building_no': '12',
        'address_detail': 'Kat 3',
        'latitude': 41.0422,
        'longitude': 29.0083,
        'has_public_pin': true,
        'can_get_directions': true,
      });

      expect(detail.latitude, isNull);
      expect(detail.longitude, isNull);
      expect(detail.street, isNull);
      expect(detail.buildingNo, isNull);
      expect(detail.addressDetail, isNull);
      expect(detail.hasPublicPin, isFalse);
      expect(detail.canGetDirections, isFalse);
    });

    test('TarakMarkerRenderer reuses official Tarak comb asset for circular pins and clusters', () async {
      final renderer = TarakMarkerRenderer(bundle: DiskAssetBundle());
      final sprites = await renderer.buildAllSprites();

      expect(sprites.keys, containsAll([
        TarakMarkerRenderer.spriteBarber,
        TarakMarkerRenderer.spriteCoiffeur,
        TarakMarkerRenderer.spriteNeutral,
        TarakMarkerRenderer.spriteBarberVerified,
        TarakMarkerRenderer.spriteCoiffeurVerified,
        TarakMarkerRenderer.spriteBarberSelected,
        TarakMarkerRenderer.spriteCoiffeurSelected,
        TarakMarkerRenderer.spriteClusterBarber,
        TarakMarkerRenderer.spriteClusterCoiffeur,
        TarakMarkerRenderer.spriteClusterMixed,
      ]));
      for (final bytes in sprites.values) {
        expect(bytes.length, greaterThan(200));
        // PNG header signature: 137 80 78 71
        expect(bytes.sublist(0, 4), equals([137, 80, 78, 71]));
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 144);
        expect(frame.image.height, 144);
        frame.image.dispose();
      }
      expect(
        sprites[TarakMarkerRenderer.spriteBarber],
        isNot(equals(sprites[TarakMarkerRenderer.spriteCoiffeur])),
      );
      expect(
        TarakMarkerRenderer.spriteIdFor(category: 'barber', isVerified: false),
        TarakMarkerRenderer.spriteBarber,
      );
      expect(
        TarakMarkerRenderer.spriteIdFor(
          category: 'barber',
          isVerified: true,
          isSelected: true,
        ),
        TarakMarkerRenderer.spriteBarberSelected,
      );
      expect(
        TarakMarkerRenderer.spriteIdFor(category: 'coiffeur', isVerified: false),
        TarakMarkerRenderer.spriteCoiffeur,
      );
      expect(
        TarakMarkerRenderer.spriteIdFor(
          category: 'coiffeur',
          isVerified: true,
          isSelected: true,
        ),
        TarakMarkerRenderer.spriteCoiffeurSelected,
      );
      expect(
        TarakMarkerRenderer.spriteIdFor(category: 'neutral', isVerified: false),
        TarakMarkerRenderer.spriteNeutral,
      );
    });

    test('5000 demo Tarak providers build clustered GeoJSON quickly', () {
      final fiveThousandPins = List<MapBusinessSummary>.generate(
        5000,
        (i) => MapBusinessSummary(
          id: '${i + 1}',
          userId: '${i + 1}',
          slug: 'demo-${i + 1}',
          businessName: 'Demo Salon ${i + 1}',
          providerType: i.isEven ? 'barber' : 'coiffeur',
          workMode: 'venue',
          isDemo: true,
          latitude: 39.90 + (i % 100) * 0.001,
          longitude: 32.80 + (i ~/ 100) * 0.001,
          hasPublicPin: true,
          canGetDirections: true,
        ),
      );

      final sw = Stopwatch()..start();
      final geoJson = TarakMapScreen.buildTarakGeoJson(fiveThousandPins);
      sw.stop();

      final features = geoJson['features'] as List;
      expect(features.length, 5000);
      expect(sw.elapsedMilliseconds, lessThan(250));
    });

    test('DirectionsLauncher builds platform URIs and falls back cleanly', () async {
      final androidUris = DirectionsLauncher.buildCandidateUris(
        latitude: 40.99,
        longitude: 29.02,
        label: 'Altın Makas',
        isAndroid: true,
        isIOS: false,
      );
      expect(androidUris.first.scheme, 'geo');
      expect(androidUris[1].host, 'www.google.com');
      expect(androidUris[2].host, 'www.openstreetmap.org');

      final iosUris = DirectionsLauncher.buildCandidateUris(
        latitude: 40.99,
        longitude: 29.02,
        label: 'Altın Makas',
        isAndroid: false,
        isIOS: true,
      );
      expect(iosUris.first.host, 'maps.apple.com');

      final attempted = <Uri>[];
      final ok = await DirectionsLauncher.openDirections(
        latitude: 40.99,
        longitude: 29.02,
        label: 'Altın Makas',
        launcher: (uri) async {
          attempted.add(uri);
          return attempted.length == 2;
        },
      );
      expect(ok, isTrue);
      expect(attempted.length, 2);
    });
  });

  group('CustomerHomeTab 3 Cards in 1 Row (320dp, 360dp, 390dp, 412dp)', () {
    for (final width in const <double>[320, 360, 390, 412]) {
      testWidgets(
        'renders Hemen Çağır, Planlı Randevu, Haritada Gör in 1 row with equal heights and no overflow at ${width.toInt()}dp',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          // Ignore pre-existing Ahem test-font overflow in SliverAppBar greeting
          // (same convention as customer_home_logo_test.dart), while failing if
          // any overflow occurs in the 3-card row under test.
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            final dump = details.toString();
            final isThreeCardOverflow =
                dump.contains('home_primary_actions_row') ||
                dump.contains('home_instant_call_cta') ||
                dump.contains('home_scheduled_appointment_cta') ||
                dump.contains('home_tarak_map_cta');
            if (details.exceptionAsString().contains('overflowed') &&
                !isThreeCardOverflow) {
              return;
            }
            originalOnError?.call(details);
          };
          addTearDown(() => FlutterError.onError = originalOnError);

          final adapter = _HaritaMockAdapter();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                apiClientProvider.overrideWithValue(_makeApi(adapter)),
                myServiceRequestsProvider.overrideWith(_NoRequests.new),
                customerAppointmentsProvider.overrideWith(_NoAppointments.new),
              ],
              child: const MaterialApp(
                home: CustomerHomeTab(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final card1 = find.byKey(const Key('home_instant_call_cta'));
          final card2 = find.byKey(const Key('home_scheduled_appointment_cta'));
          final card3 = find.byKey(const Key('home_tarak_map_cta'));

          expect(card1, findsOneWidget);
          expect(card2, findsOneWidget);
          expect(card3, findsOneWidget);

          final rect1 = tester.getRect(card1);
          final rect2 = tester.getRect(card2);
          final rect3 = tester.getRect(card3);

          // Single row: identical top & bottom (equal height!)
          expect((rect1.top - rect2.top).abs(), lessThanOrEqualTo(1.0));
          expect((rect2.top - rect3.top).abs(), lessThanOrEqualTo(1.0));
          expect((rect1.height - rect2.height).abs(), lessThanOrEqualTo(1.0));
          expect((rect2.height - rect3.height).abs(), lessThanOrEqualTo(1.0));

          // Equal flex:1 width
          expect((rect1.width - rect2.width).abs(), lessThanOrEqualTo(1.0));
          expect((rect2.width - rect3.width).abs(), lessThanOrEqualTo(1.0));

          // Strictly ordered left-to-right within screen width (no horizontal overflow)
          expect(rect1.left, greaterThanOrEqualTo(0));
          expect(rect1.right, lessThanOrEqualTo(rect2.left));
          expect(rect2.right, lessThanOrEqualTo(rect3.left));
          expect(rect3.right, lessThanOrEqualTo(width));

          // Icons sit to the left of titles cleanly inside each card
          final icon1 = tester.getRect(
            find.descendant(
              of: card1,
              matching: find.byIcon(Icons.flash_on_rounded),
            ),
          );
          final title1 = tester.getRect(find.text('Hemen Çağır'));
          final icon2 = tester.getRect(
            find.descendant(
              of: card2,
              matching: find.byIcon(Icons.calendar_month_rounded),
            ),
          );
          final title2 = tester.getRect(find.text('Planlı Randevu'));
          final icon3 = tester.getRect(
            find.descendant(
              of: card3,
              matching: find.byIcon(Icons.map_rounded),
            ),
          );
          final title3 = tester.getRect(find.text('Haritada Gör'));

          expect(find.text('Yakındaki hizmetverenleri keşfet'), findsOneWidget);
          expect(icon1.right, lessThanOrEqualTo(title1.left));
          expect(icon2.right, lessThanOrEqualTo(title2.left));
          expect(icon3.right, lessThanOrEqualTo(title3.left));
          expect(
            ((title1.left - rect1.left) - (title2.left - rect2.left)).abs(),
            lessThanOrEqualTo(2.0),
          );
          expect(
            ((title2.left - rect2.left) - (title3.left - rect3.left)).abs(),
            lessThanOrEqualTo(2.0),
          );
        },
      );
    }
  });

  group('Tarak Harita Location, Tarak-Only Pins, Error Isolation & Widget Flows', () {
    testWidgets(
      'auto-focuses user location at zoom 14 on open, renders ONLY Tarak markers (no OSM), opens canonical sheet & filters by category',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final adapter = _HaritaMockAdapter();
        final launchedUris = <Uri>[];
        double? focusedLat;
        double? focusedLng;
        double? focusedZoom;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(_makeApi(adapter)),
              geoServiceProvider.overrideWithValue(
                GeoService(
                  dio: Dio()..httpClientAdapter = adapter,
                  bundle: DiskAssetBundle(),
                ),
              ),
            ],
            child: MaterialApp(
              home: TarakMapScreen(
                directionsLauncher: (uri) async {
                  launchedUris.add(uri);
                  return true;
                },
                positionFetcher: () async => (lat: 40.9885, lng: 29.0255),
                onCameraTargetChanged: (lat, lng, zoom) {
                  focusedLat = lat;
                  focusedLng = lng;
                  focusedZoom = zoom;
                },
                mapBuilder: (
                  context,
                  tarakPins,
                  selectedBusiness,
                  onSelectBusiness,
                ) {
                  return Center(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final pin in tarakPins)
                          ElevatedButton(
                            key: Key('fake_pin_${pin.userId}'),
                            onPressed: () => onSelectBusiness(pin),
                            child: Text(pin.businessName),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Automatically focused on user's GPS location at zoom 14.0 (neighborhood/district level)
        expect(focusedLat, closeTo(40.9885, 0.0001));
        expect(focusedLng, closeTo(29.0255, 0.0001));
        expect(focusedZoom, inInclusiveRange(13.0, 15.0));

        // 2. Only registered Tarak venue pins appear; mobile-only provider and OSM POIs are hidden
        expect(find.byKey(const Key('fake_pin_10')), findsOneWidget);
        expect(find.byKey(const Key('fake_pin_11')), findsOneWidget);
        expect(find.byKey(const Key('fake_pin_12')), findsNothing);
        expect(find.textContaining('OpenStreetMap'), findsNothing);

        // 3. Tap Tarak venue pin -> opens expandable original Tarak profile sheet; drag reveals gallery & services without contact links
        await tester.tap(find.byKey(const Key('fake_pin_10')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tarak_map_preview_card')), findsOneWidget);
        expect(find.text('Moda Cd, Kadıköy, İstanbul'), findsWidgets);

        await tester.drag(
          find.text('Moda Cd, Kadıköy, İstanbul').first,
          const Offset(0, -360),
        );
        await tester.pumpAndSettle();

        expect(find.text('Çalışmalarım'), findsOneWidget);
        expect(find.byKey(const Key('provider_gallery_list')), findsOneWidget);
        expect(find.text('Saç Kesimi'), findsOneWidget);
        expect(find.text('₺350'), findsOneWidget);
        expect(find.byIcon(Icons.star_rounded), findsNothing);
        expect(find.byIcon(Icons.star), findsNothing);
        expect(find.text('İletişim'), findsNothing);
        expect(find.text('WhatsApp'), findsNothing);

        // Triggering "Yol Tarifi" inside sheet computes real in-app MapLibre road route
        await tester.ensureVisible(find.byKey(const Key('map_directions_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('map_directions_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('map_active_route_bar')), findsOneWidget);
        expect(find.text('1,5 km • 5 dk'), findsOneWidget);
        expect(launchedUris, isEmpty);

        // Closing route restores normal map view
        await tester.tap(find.byKey(const Key('map_close_route_btn')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('map_active_route_bar')), findsNothing);

        // Re-open pin and tap "Profili İncele" -> expands SAME bottom sheet without leaving map
        await tester.tap(find.byKey(const Key('fake_pin_10')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('map_open_showcase_button')));
        await tester.pumpAndSettle();
        expect(find.byType(BusinessShowcaseScreen), findsNothing);
        expect(find.byKey(const Key('tarak_map_preview_card')), findsOneWidget);
        await tester.tap(find.byKey(const Key('map_preview_close_button')));
        await tester.pumpAndSettle();

        // 4. Category Filters via grouped downward dropdown: "Erkek Berber" shows ONLY blue barber pins
        await tester.tap(find.byKey(const Key('map_category_filter_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('map_filter_barber_chip')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('fake_pin_10')), findsOneWidget);
        expect(find.byKey(const Key('fake_pin_11')), findsNothing);

        // "Kadın Kuaför" via downward dropdown shows ONLY red coiffeur pins
        await tester.tap(find.byKey(const Key('map_category_filter_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('map_filter_coiffeur_chip')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('fake_pin_10')), findsNothing);
        expect(find.byKey(const Key('fake_pin_11')), findsOneWidget);

        // Clearing filter restores all Tarak pins
        final clearChip = find.byKey(const Key('map_clear_filters_chip'));
        await tester.ensureVisible(clearChip);
        await tester.pumpAndSettle();
        await tester.tap(clearChip);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('fake_pin_10')), findsOneWidget);
        expect(find.byKey(const Key('fake_pin_11')), findsOneWidget);
      },
    );

    testWidgets(
      'isolates Tarak error and GPS timeout/denial so targeted Retry recovers clean map layers',
      (tester) async {
        final adapter = _HaritaMockAdapter()..failMapBusinesses = true;
        var gpsWorks = false;
        double? fallbackZoom;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(_makeApi(adapter)),
              geoServiceProvider.overrideWithValue(
                GeoService(
                  dio: Dio()..httpClientAdapter = adapter,
                  bundle: DiskAssetBundle(),
                ),
              ),
            ],
            child: MaterialApp(
              home: TarakMapScreen(
                // Simulate GPS timeout on initial open, then succeed on locate-me tap
                positionFetcher: () async {
                  if (!gpsWorks) {
                    throw TimeoutException('GPS timeout');
                  }
                  return (lat: 40.9885, lng: 29.0255);
                },
                onCameraTargetChanged: (lat, lng, zoom) {
                  fallbackZoom = zoom;
                },
                mapBuilder: (
                  context,
                  tarakPins,
                  selectedBusiness,
                  onSelectBusiness,
                ) {
                  return Center(
                    child: Wrap(
                      children: [
                        for (final pin in tarakPins)
                          Text('TARAK:${pin.businessName}'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. GPS timeout fell back to Turkey overview (zoom ~5.8) and showed non-blocking location banner
        expect(fallbackZoom, closeTo(5.8, 0.1));
        expect(find.byKey(const Key('location_layer_error_banner')), findsOneWidget);
        expect(find.text('Konum alınamadı'), findsOneWidget);

        // 2. Tarak layer error banner is shown (never blanket "Harita verileri yüklenemedi.")
        expect(find.byKey(const Key('tarak_layer_error_banner')), findsOneWidget);
        expect(find.text('Tarak işletmeleri yüklenemedi'), findsOneWidget);
        expect(find.text('Harita verileri yüklenemedi.'), findsNothing);

        // 3. Recover Tarak layer via its "Tekrar Dene" button
        adapter.failMapBusinesses = false;
        await tester.tap(find.byKey(const Key('retry_tarak_layer_btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('tarak_layer_error_banner')), findsNothing);
        expect(find.text('TARAK:Altın Makas Berber'), findsOneWidget);

        // 4. Now GPS succeeds on locate-me tap while Tarak stays visible
        gpsWorks = true;
        await tester.tap(find.byKey(const Key('map_locate_me_button')));
        await tester.pumpAndSettle();

        expect(find.text('TARAK:Altın Makas Berber'), findsOneWidget);
        expect(find.byKey(const Key('location_layer_error_banner')), findsNothing);
      },
    );

    testWidgets(
      'RegisterScreen exposes independent directory_listed & accepts_new_clients switches',
      (tester) async {
        final adapter = _HaritaMockAdapter();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(_makeApi(adapter)),
            ],
            child: const MaterialApp(
              home: RegisterScreen(initialRole: 'PROVIDER'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dirSwitch =
            find.byKey(const Key('register_directory_listed_switch'));
        final clientSwitch =
            find.byKey(const Key('register_accepts_new_clients_switch'));

        await tester.ensureVisible(dirSwitch);
        await tester.pumpAndSettle();

        expect(dirSwitch, findsOneWidget);
        expect(clientSwitch, findsOneWidget);
        expect(tester.widget<SwitchListTile>(dirSwitch).value, isTrue);
        expect(tester.widget<SwitchListTile>(clientSwitch).value, isTrue);

        await tester.tap(clientSwitch);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(clientSwitch).value, isFalse);
        expect(tester.widget<SwitchListTile>(dirSwitch).value, isTrue);
      },
    );

    testWidgets(
      'ProviderProfileTab consolidates work mode, service areas, directory visibility without showcase entry or external contact fields',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final adapter = _HaritaMockAdapter();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(_makeApi(adapter)),
              authNotifierProvider.overrideWith(_HaritaProviderAuth.new),
              geoServiceProvider.overrideWithValue(
                GeoService(
                  dio: Dio()..httpClientAdapter = adapter,
                  bundle: DiskAssetBundle(),
                ),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: ProviderProfileTab()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('provider_showcase_entry')), findsNothing);
        expect(find.text('Tarak Harita & İşletme Vitrini'), findsNothing);
        expect(find.text('Telefon Numarası'), findsNothing);
        expect(find.text('WhatsApp'), findsNothing);
        expect(find.text('Instagram'), findsNothing);
        expect(find.text('Web Sitesi'), findsNothing);

        final workModeCard = find.byKey(const Key('provider_work_mode_card'));
        final dirCard = find.byKey(const Key('provider_directory_visibility_card'));
        final venueChip = find.byKey(const Key('provider_work_mode_venue'));
        final mobileChip = find.byKey(const Key('provider_work_mode_mobile'));
        final bothChip = find.byKey(const Key('provider_work_mode_both'));
        final dirSwitch = find.byKey(const Key('provider_directory_listed_switch'));

        await tester.scrollUntilVisible(bothChip, 250, scrollable: find.byType(Scrollable).first);
        expect(workModeCard, findsOneWidget);
        expect(venueChip, findsOneWidget);
        expect(mobileChip, findsOneWidget);
        expect(bothChip, findsOneWidget);

        final venueRect = tester.getRect(venueChip);
        final mobileRect = tester.getRect(mobileChip);
        final bothRect = tester.getRect(bothChip);
        expect((venueRect.top - mobileRect.top).abs(), lessThanOrEqualTo(1.0));
        expect((mobileRect.top - bothRect.top).abs(), lessThanOrEqualTo(1.0));
        expect((venueRect.height - mobileRect.height).abs(), lessThanOrEqualTo(1.0));
        expect((mobileRect.height - bothRect.height).abs(), lessThanOrEqualTo(1.0));
        expect(venueRect.right, lessThan(mobileRect.left));
        expect(mobileRect.right, lessThan(bothRect.left));

        await tester.tap(bothChip);
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(dirSwitch, 250, scrollable: find.byType(Scrollable).first);
        expect(dirCard, findsOneWidget);
        expect(tester.widget<SwitchListTile>(find.byKey(const Key('provider_accepts_clients_switch'))).value, isFalse);
        await tester.tap(dirSwitch);
        await tester.pumpAndSettle();

        final putReqs = adapter.requests
            .where((r) => r.method == 'PUT' && r.path == '/provider/profile')
            .toList();
        expect(putReqs.length, greaterThanOrEqualTo(2));
        expect((putReqs.first.data as Map)['work_mode'], 'both');
        expect((putReqs.last.data as Map)['directory_listed'], isTrue);
      },
    );

    testWidgets(
      'moves camera to Antalya when selected even if GPS is in USA, draws in-app route with optional external fallback, and shows calm empty message',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final adapter = _HaritaMockAdapter();
        final launchedUris = <Uri>[];
        double? lastLat;
        double? lastLng;
        double? lastZoom;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(_makeApi(adapter)),
              geoServiceProvider.overrideWithValue(
                GeoService(
                  dio: Dio()..httpClientAdapter = adapter,
                  bundle: DiskAssetBundle(),
                ),
              ),
            ],
            child: MaterialApp(
              home: TarakMapScreen(
                // Emulator GPS sits in California
                positionFetcher: () async => (lat: 37.421998, lng: -122.084),
                directionsLauncher: (uri) async {
                  launchedUris.add(uri);
                  return true;
                },
                onCameraTargetChanged: (lat, lng, zoom) {
                  lastLat = lat;
                  lastLng = lng;
                  lastZoom = zoom;
                },
                mapBuilder: (
                  context,
                  tarakPins,
                  selectedBusiness,
                  onSelectBusiness,
                ) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final pin in tarakPins)
                          ElevatedButton(
                            key: Key('city_pin_${pin.userId}'),
                            onPressed: () => onSelectBusiness(pin),
                            child: Text(pin.businessName),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially focused on California GPS
        expect(lastLat, closeTo(37.42, 0.01));
        expect(lastLng, closeTo(-122.08, 0.01));

        // Open İl / İlçe filter sheet -> choose Antalya -> apply
        await tester.tap(find.byKey(const Key('map_area_filter_chip')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('map_city_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Antalya').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('apply_area_filter_btn')));
        await tester.pumpAndSettle();

        // Map focused to Antalya (~36.89, ~30.71) despite USA GPS, and loaded Antalya Tarak pin!
        expect(lastLat, inInclusiveRange(36.7, 37.0));
        expect(lastLng, inInclusiveRange(30.5, 30.9));
        expect(lastZoom, greaterThanOrEqualTo(11.5));
        expect(find.byKey(const Key('city_pin_14')), findsOneWidget);

        // Route failure shows clear message without drawing any straight line
        adapter.failRoute = true;
        await tester.tap(find.byKey(const Key('city_pin_14')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('map_directions_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('map_directions_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('map_active_route_bar')), findsNothing);
        expect(
          find.text('Yol tarifi servisine şu anda ulaşılamıyor.'),
          findsOneWidget,
        );
        ScaffoldMessenger.of(
          tester.element(find.byType(Scaffold)),
        ).hideCurrentSnackBar();
        await tester.pumpAndSettle();

        // Close sheet & verify calm empty-results banner when search matches 0 businesses
        await tester.ensureVisible(
          find.byKey(const Key('map_preview_close_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('map_preview_close_button')));
        await tester.pumpAndSettle();
        adapter.emptyCitySearch = true;
        await tester.tap(find.byKey(const Key('map_category_filter_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('map_filter_coiffeur_chip')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('map_empty_results_banner')), findsOneWidget);
        expect(
          find.text('Bu bölgede uygun işletme bulunamadı'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CoLocatedBusinessesSheet lists overlapping Tarak businesses cleanly for separate selection',
      (tester) async {
        final selectedNames = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CoLocatedBusinessesSheet(
                tarakPins: const [
                  MapBusinessSummary(
                    id: '1',
                    userId: '10',
                    slug: 'salon-a',
                    businessName: 'Salon A Berber',
                    providerType: 'barber',
                    workMode: 'venue',
                    latitude: 40.99,
                    longitude: 29.02,
                    hasPublicPin: true,
                    canGetDirections: true,
                  ),
                  MapBusinessSummary(
                    id: '2',
                    userId: '11',
                    slug: 'salon-b',
                    businessName: 'Salon B Kuaför',
                    providerType: 'coiffeur',
                    workMode: 'venue',
                    latitude: 40.99,
                    longitude: 29.02,
                    hasPublicPin: true,
                    canGetDirections: true,
                  ),
                ],
                onSelectBusiness: (b) => selectedNames.add(b.businessName),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Bu Konumdaki İşletmeler (2)'), findsOneWidget);
        expect(find.text('Salon A Berber'), findsOneWidget);
        expect(find.text('Salon B Kuaför'), findsOneWidget);
        await tester.tap(find.byKey(const Key('colocated_tarak_11')));
        await tester.pump();
        expect(selectedNames, ['Salon B Kuaför']);
      },
    );

    testWidgets(
      'TarakBusinessDetailSheet 3 action buttons stay compact on 1 line with zero overflow at 360dp',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 780));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final adapter = _HaritaMockAdapter();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(_makeApi(adapter)),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Stack(
                  children: [
                    TarakBusinessDetailSheet(
                      business: const MapBusinessSummary(
                        id: '102',
                        userId: '11',
                        slug: 'elit-kuafor',
                        businessName: 'Elit Kuaför',
                        providerType: 'coiffeur',
                        workMode: 'both',
                        city: 'İstanbul',
                        district: 'Kadıköy',
                        latitude: 40.9612,
                        longitude: 29.0815,
                        hasPublicPin: true,
                        canGetDirections: true,
                        acceptsTarakBookings: true,
                        isVerified: false,
                      ),
                      isGuest: false,
                      onClose: () {},
                      onInAppDirections: () {},
                      onOpenShowcase: () {},
                      onDirectBooking: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dirBtn = tester.getRect(
          find.byKey(const Key('map_directions_button')),
        );
        final showcaseBtn = tester.getRect(
          find.byKey(const Key('map_open_showcase_button')),
        );
        final bookBtn = tester.getRect(
          find.byKey(const Key('map_provider_direct_book_button')),
        );

        expect(find.text('Yol Tarifi'), findsWidgets);
        expect(find.text('Profili İncele'), findsOneWidget);
        expect(find.text('Randevu Al'), findsWidgets);
        expect(find.byIcon(Icons.star_rounded), findsNothing);
        expect(find.byIcon(Icons.star), findsNothing);
        expect(dirBtn.height, lessThanOrEqualTo(42.0));
        expect(showcaseBtn.height, lessThanOrEqualTo(42.0));
        expect(bookBtn.height, lessThanOrEqualTo(42.0));
        expect(bookBtn.right, lessThanOrEqualTo(360.0));
      },
    );

    testWidgets(
      'search submit button moves camera to typed Turkish province and fits 3 filter pills in 1 row',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 780));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final adapter = _HaritaMockAdapter();
        double? lastLat;
        double? lastLng;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(_makeApi(adapter)),
              geoServiceProvider.overrideWithValue(
                GeoService(
                  dio: Dio()..httpClientAdapter = adapter,
                  bundle: DiskAssetBundle(),
                ),
              ),
            ],
            child: MaterialApp(
              home: TarakMapScreen(
                key: const ValueKey('rule1_case_a'),
                positionFetcher: () async => (lat: 37.421998, lng: -122.084),
                onCameraTargetChanged: (lat, lng, zoom) {
                  lastLat = lat;
                  lastLng = lng;
                },
                mapBuilder: (
                  context,
                  tarakPins,
                  selectedBusiness,
                  onSelectBusiness,
                ) =>
                    Column(
                  children: [
                    for (final pin in tarakPins)
                      Text(pin.businessName, key: Key('srch_pin_${pin.userId}')),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // All 3 grouped filter pills fit within 360dp on 1 row
        final areaRect = tester.getRect(find.byKey(const Key('map_area_filter_chip')));
        final catRect =
            tester.getRect(find.byKey(const Key('map_category_filter_dropdown')));
        final svcRect =
            tester.getRect(find.byKey(const Key('map_service_filter_dropdown')));
        expect((areaRect.top - catRect.top).abs(), lessThanOrEqualTo(1.0));
        expect((catRect.top - svcRect.top).abs(), lessThanOrEqualTo(1.0));
        expect(svcRect.right, lessThanOrEqualTo(360.0));

        // Typing Antalya + tapping Search button moves camera to Antalya
        await tester.enterText(
          find.byKey(const Key('map_search_field')),
          'Antalya',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('map_search_submit_btn')));
        await tester.pumpAndSettle();

        expect(lastLat, inInclusiveRange(36.7, 37.0));
        expect(lastLng, inInclusiveRange(30.5, 30.9));
        expect(find.byKey(const Key('srch_pin_14')), findsOneWidget);
      },
    );

    testWidgets(
      'selecting Antalya then Alanya or searching Alanya moves camera directly to Alanya without visiting Antalya center',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final adapter = _HaritaMockAdapter();
        final cameraHistory = <({double lat, double lng, double zoom})>[];
        double? lastLat;
        double? lastLng;
        double? lastZoom;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(_makeApi(adapter)),
              geoServiceProvider.overrideWithValue(
                GeoService(
                  dio: Dio()..httpClientAdapter = adapter,
                  bundle: DiskAssetBundle(),
                ),
              ),
            ],
            child: MaterialApp(
              home: TarakMapScreen(
                key: const ValueKey('rule1_case_a'),
                positionFetcher: () async => (lat: 37.421998, lng: -122.084),
                onCameraTargetChanged: (lat, lng, zoom) {
                  lastLat = lat;
                  lastLng = lng;
                  lastZoom = zoom;
                  cameraHistory.add((lat: lat, lng: lng, zoom: zoom));
                },
                mapBuilder: (
                  context,
                  tarakPins,
                  selectedBusiness,
                  onSelectBusiness,
                ) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Open İl / İlçe filter -> select Antalya -> select Alanya -> apply
        cameraHistory.clear();
        await tester.tap(find.byKey(const Key('map_area_filter_chip')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('map_city_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Antalya').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('map_district_dropdown')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Alanya').last);
        await tester.tap(find.text('Alanya').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('apply_area_filter_btn')));
        await tester.pumpAndSettle();

        final visitedAntalyaCenter = cameraHistory.any(
          (c) =>
              (c.lat - 36.8969).abs() < 0.05 &&
              (c.lng - 30.7133).abs() < 0.05,
        );
        expect(visitedAntalyaCenter, isFalse);
        expect(lastLat, closeTo(36.5437, 0.01));
        expect(lastLng, closeTo(32.0019, 0.01));
        expect(lastZoom, greaterThanOrEqualTo(13.0));

        // 2. Reset area back to origin, then search "Alanya" in search bar
        await tester.tap(find.byKey(const Key('map_area_filter_chip')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sıfırla'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('apply_area_filter_btn')));
        await tester.pumpAndSettle();

        cameraHistory.clear();
        await tester.enterText(
          find.byKey(const Key('map_search_field')),
          'Alanya',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('map_search_submit_btn')));
        await tester.pumpAndSettle();

        final searchVisitedAntalyaCenter = cameraHistory.any(
          (c) =>
              (c.lat - 36.8969).abs() < 0.05 &&
              (c.lng - 30.7133).abs() < 0.05,
        );
        expect(searchVisitedAntalyaCenter, isFalse);
        expect(lastLat, closeTo(36.5437, 0.01));
        expect(lastLng, closeTo(32.0019, 0.01));
        expect(lastZoom, greaterThanOrEqualTo(13.0));
      },
    );

    testWidgets(
      'Rule #1: opens logged-in customer default saved address immediately (coordinates or geocoded district)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final adapter = _HaritaMockAdapter();
        double? lastLat;
        double? lastLng;
        double? lastZoom;

        // Case A: default address has explicit coordinates (Kadıköy 40.988, 29.026) even though GPS is in USA
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(_makeApi(adapter)),
              authNotifierProvider.overrideWith(_HaritaCustomerAuth.new),
              customerAddressesProvider.overrideWith(
                (ref) async => const [
                  CustomerAddress(
                    id: 1,
                    title: 'Eski Ev',
                    province: 'Ankara',
                    district: 'Çankaya',
                    latitude: 39.9208,
                    longitude: 32.8541,
                    isDefault: false,
                  ),
                  CustomerAddress(
                    id: 2,
                    title: 'Moda Ev',
                    province: 'İstanbul',
                    district: 'Kadıköy',
                    neighborhood: 'Moda',
                    latitude: 40.9880,
                    longitude: 29.0260,
                    isDefault: true,
                  ),
                ],
              ),
              geoServiceProvider.overrideWithValue(
                GeoService(
                  dio: Dio()..httpClientAdapter = adapter,
                  bundle: DiskAssetBundle(),
                ),
              ),
            ],
            child: MaterialApp(
              home: TarakMapScreen(
                key: const ValueKey('rule1_case_a'),
                positionFetcher: () async => (lat: 37.421998, lng: -122.084),
                onCameraTargetChanged: (lat, lng, zoom) {
                  lastLat = lat;
                  lastLng = lng;
                  lastZoom = zoom;
                },
                mapBuilder: (
                  context,
                  tarakPins,
                  selectedBusiness,
                  onSelectBusiness,
                ) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(lastLat, closeTo(40.9880, 0.005));
        expect(lastLng, closeTo(29.0260, 0.005));
        expect(lastZoom, greaterThanOrEqualTo(13.0));

        // Dispose Case A ProviderScope completely before Case B so customerAddressesProvider is not cached
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        // Case B: default address has district/province without coordinates -> geocodes directly to Alanya
        lastLat = null;
        lastLng = null;
        lastZoom = null;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(_makeApi(adapter)),
              authNotifierProvider.overrideWith(_HaritaCustomerAuth.new),
              customerAddressesProvider.overrideWith(
                (ref) async => const [
                  CustomerAddress(
                    id: 3,
                    title: 'Alanya Yazlık',
                    province: 'Antalya',
                    district: 'Alanya',
                    neighborhood: 'Saray',
                    isDefault: true,
                  ),
                ],
              ),
              geoServiceProvider.overrideWithValue(
                GeoService(
                  dio: Dio()..httpClientAdapter = adapter,
                  bundle: DiskAssetBundle(),
                ),
              ),
            ],
            child: MaterialApp(
              home: TarakMapScreen(
                key: const ValueKey('rule1_case_b'),
                positionFetcher: () async => (lat: 37.421998, lng: -122.084),
                onCameraTargetChanged: (lat, lng, zoom) {
                  lastLat = lat;
                  lastLng = lng;
                  lastZoom = zoom;
                },
                mapBuilder: (
                  context,
                  tarakPins,
                  selectedBusiness,
                  onSelectBusiness,
                ) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(lastLat, closeTo(36.5437, 0.01));
        expect(lastLng, closeTo(32.0019, 0.01));
        expect(lastZoom, greaterThanOrEqualTo(13.0));
      },
    );

    test(
      'buildTarakGeoJson builds Tarak-only features with selected icon and isolated IDs',
      () {
        const tarakPins = [
          MapBusinessSummary(
            id: '957',
            userId: '2401',
            slug: 'yigit-erkek-kuaforu-sisli',
            businessName: 'Yiğit Erkek Kuaförü',
            providerType: 'barber',
            workMode: 'both',
            latitude: 41.0507,
            longitude: 28.9810,
            hasPublicPin: true,
            canGetDirections: true,
          ),
        ];

        final tarakOnly = TarakMapScreen.buildTarakGeoJson(
          tarakPins,
          selectedFeatureKey: 'tarak:2401',
        );
        final tarakFeatures =
            (tarakOnly['features'] as List).cast<Map<String, dynamic>>();
        expect(tarakFeatures.length, 1);
        expect(tarakFeatures[0]['properties']['source'], 'tarak');
        expect(tarakFeatures[0]['properties']['user_id'], '2401');
        expect(tarakFeatures[0]['properties']['profile_id'], '957');
        expect(
          tarakFeatures[0]['properties']['icon_id'],
          TarakMarkerRenderer.spriteBarberSelected,
        );
      },
    );

    testWidgets(
      'ProviderDetailScreen and expanded TarakBusinessDetailSheet unify TarakMark rating, gallery, staff cards without VerifiedTick leakage, and zero yellow stars',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final adapter = _HaritaMockAdapter();
        final selectedStaffIds = <int?>[];

        // 1. Verify original ProviderDetailScreen displays Ustalarımız / Uzmanlarımız + TarakMark + Staff tap
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(_makeApi(adapter)),
            ],
            child: MaterialApp(
              home: ProviderDetailScreen(
                providerUserId: 11,
                fallbackName: 'Elit Kuaför',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Elit Kuaför'), findsOneWidget);
        expect(find.byType(VerifiedTick), findsOneWidget);
        expect(find.byType(TarakRatingLabel), findsOneWidget);
        expect(find.byType(TarakRatingScale), findsOneWidget);
        expect(find.byIcon(Icons.star), findsNothing);
        expect(find.byIcon(Icons.star_rounded), findsNothing);
        expect(find.byType(ProviderGallerySection), findsOneWidget);
        expect(find.text('Ustalarımız / Uzmanlarımız'), findsOneWidget);
        expect(find.text('Derya Yılmaz'), findsOneWidget);
        expect(find.text('Fön & Şekillendirme'), findsWidgets);
        // Staff card must NEVER carry VerifiedTick
        expect(
          find.descendant(
            of: find.byKey(const Key('profile_staff_card_501')),
            matching: find.byType(VerifiedTick),
          ),
          findsNothing,
        );

        // Tapping a staff card opens CreateAppointmentScreen pre-populated with provider & staff
        await tester.ensureVisible(
          find.byKey(const Key('profile_staff_card_501')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('profile_staff_card_501')));
        await tester.pumpAndSettle();
        expect(find.byType(CreateAppointmentScreen), findsOneWidget);
        final wizardState = ProviderScope.containerOf(
          tester.element(find.byType(CreateAppointmentScreen)),
        ).read(appointmentWizardProvider);
        expect(wizardState.preferredProviderUserId, 11);
        expect(wizardState.preferredStaffId, 501);

        // Dispose previous Navigator & ProviderScope cleanly before mounting the map sheet
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        // 2. Verify TarakBusinessDetailSheet expanded panel renders same sections + staff callback
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(_makeApi(adapter)),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Stack(
                  children: [
                    TarakBusinessDetailSheet(
                      business: const MapBusinessSummary(
                        id: '102',
                        userId: '11',
                        slug: 'elit-kuafor',
                        businessName: 'Elit Kuaför',
                        providerType: 'coiffeur',
                        workMode: 'both',
                        city: 'İstanbul',
                        district: 'Kadıköy',
                        latitude: 40.9612,
                        longitude: 29.0815,
                        hasPublicPin: true,
                        canGetDirections: true,
                        acceptsTarakBookings: true,
                        isVerified: true,
                      ),
                      isGuest: false,
                      onClose: () {},
                      onInAppDirections: () {},
                      onDirectBooking: () => selectedStaffIds.add(null),
                      onInstantCall: () {},
                      onSelectStaff: (s) => selectedStaffIds.add(s.id),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('map_open_showcase_button')));
        await tester.pumpAndSettle();

        expect(find.text('Ustalarımız / Uzmanlarımız'), findsOneWidget);
        expect(find.text('Derya Yılmaz'), findsOneWidget);
        expect(find.text('₺280'), findsOneWidget);
        expect(find.byType(TarakRatingScale), findsOneWidget);
        expect(find.byIcon(Icons.star), findsNothing);
        expect(find.byIcon(Icons.star_rounded), findsNothing);
        await tester.ensureVisible(
          find.byKey(const Key('profile_staff_card_501')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('profile_staff_card_501')));
        await tester.pump();
        expect(selectedStaffIds, [501]);
      },
    );

    testWidgets(
      'AppTheme.lightTheme docked in-app route bar renders with positive size, switches between GPS and saved origin, and closes cleanly',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 780));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final adapter = _HaritaMockAdapter();
        final recordedOrigins = <({double lat, double lng, String profile})>[];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(_makeApi(adapter)),
              authNotifierProvider.overrideWith(_HaritaCustomerAuth.new),
              customerAddressesProvider.overrideWith(
                (ref) async => const [
                  CustomerAddress(
                    id: 7,
                    title: 'Şişli Ev',
                    province: 'İstanbul',
                    district: 'Şişli',
                    neighborhood: 'Cumhuriyet',
                    latitude: 41.0550,
                    longitude: 28.9850,
                    isDefault: true,
                  ),
                ],
              ),
              geoServiceProvider.overrideWithValue(
                GeoService(
                  dio: Dio()..httpClientAdapter = adapter,
                  bundle: DiskAssetBundle(),
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: TarakMapScreen(
                positionFetcher: () async => (lat: 40.9885, lng: 29.0255),
                routeFetcher: ({
                  required originLat,
                  required originLng,
                  required destLat,
                  required destLng,
                  required destinationName,
                  String profile = 'driving',
                  CancelToken? cancelToken,
                }) async {
                  recordedOrigins.add((
                    lat: originLat,
                    lng: originLng,
                    profile: profile,
                  ));
                  final isSaved = (originLat - 41.0550).abs() < 0.002;
                  return MapRouteResult(
                    provider: 'valhalla',
                    profile: profile,
                    distanceMeters: isSaved ? 1500 : 12400,
                    durationSeconds: isSaved ? 300 : 1680,
                    coordinates: [
                      [originLng, originLat],
                      [destLng, destLat],
                    ],
                    bounds: MapRouteBounds(
                      south: isSaved ? 41.04 : 40.98,
                      west: isSaved ? 28.97 : 28.97,
                      north: 41.06,
                      east: 29.03,
                    ),
                    destinationName: destinationName,
                    destinationLat: destLat,
                    destinationLng: destLng,
                  );
                },
                mapBuilder: (
                  context,
                  tarakPins,
                  selectedBusiness,
                  onSelectBusiness,
                ) {
                  return Center(
                    child: Wrap(
                      children: [
                        for (final pin in tarakPins)
                          ElevatedButton(
                            key: Key('route_test_pin_${pin.userId}'),
                            onPressed: () => onSelectBusiness(pin),
                            child: Text(pin.businessName),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('route_test_pin_10')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('map_directions_button')));
        await tester.pumpAndSettle();

        final routeBarFinder = find.byKey(const Key('map_active_route_bar'));
        final originLabelFinder = find.byKey(const Key('map_route_origin_label'));
        final gpsChipFinder = find.byKey(const Key('map_route_origin_gps_chip'));
        final savedChipFinder =
            find.byKey(const Key('map_route_origin_saved_chip'));
        final closeBtnFinder = find.byKey(const Key('map_close_route_btn'));

        expect(routeBarFinder, findsOneWidget);
        expect(originLabelFinder, findsOneWidget);
        expect(gpsChipFinder, findsOneWidget);
        expect(savedChipFinder, findsOneWidget);
        expect(closeBtnFinder, findsOneWidget);

        expect(tester.getSize(routeBarFinder).height, greaterThan(60.0));
        expect(tester.getSize(closeBtnFinder).height, greaterThanOrEqualTo(36.0));
        expect(tester.getSize(closeBtnFinder).width, greaterThan(60.0));
        expect(recordedOrigins.last.lat, closeTo(40.9885, 0.001));
        expect(find.text('12 km • 28 dk'), findsOneWidget);
        expect(find.text('Başlangıç: Mevcut konumunuz'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(savedChipFinder);
        await tester.pumpAndSettle();

        expect(recordedOrigins.last.lat, closeTo(41.0550, 0.001));
        expect(find.text('1,5 km • 5 dk'), findsOneWidget);
        expect(
          find.text('Başlangıç: Kayıtlı adres (Şişli, İstanbul)'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.tap(closeBtnFinder);
        await tester.pumpAndSettle();

        expect(routeBarFinder, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'AppTheme.lightTheme ProviderDetailScreen and expanded TarakBusinessDetailSheet lay out WorkingHours, Reviews, Konum ve Yol Tarifi, Contact, and CTAs with zero overlap',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final adapter = _HaritaMockAdapter();

        // 1. ProviderDetailScreen under AppTheme.lightTheme
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(_makeApi(adapter)),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const ProviderDetailScreen(
                providerUserId: 11,
                fallbackName: 'Elit Kuaför',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Elit Kuaför'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        // 2. Expanded TarakBusinessDetailSheet under AppTheme.lightTheme with WorkingHours + Reviews + Konum ve Yol Tarifi
        const richData = TarakProviderProfileData(
          userId: 2401,
          profileId: '957',
          slug: 'yigit-erkek-kuaforu-sisli',
          businessName: 'Yiğit Erkek Kuaförü',
          providerType: 'barber',
          isVerified: true,
          isOnline: true,
          acceptsTarakBookings: true,
          city: 'İstanbul',
          district: 'Şişli',
          formattedAddress: 'Fevzi Çakmak Mah. Menekşe Sk. No:41, Şişli',
          latitude: 41.0507,
          longitude: 28.9810,
          canGetDirections: true,
          experienceYears: 12,
          ratingAvg: 4.0,
          reviewCount: 2,
          services: [
            TarakProfileServiceItem(
              serviceId: 1,
              name: 'Saç Kesimi',
              price: 240,
              durationMinutes: 30,
            ),
          ],
          staff: [
            ProviderStaffModel(
              id: 501,
              firstName: 'Emre',
              lastName: 'Kaya',
              fullName: 'Emre Kaya',
              title: 'Usta Berber',
              acceptsAppointments: true,
            ),
          ],
          workingHours: [
            WorkingHourItem(
              day: 'friday',
              label: 'Cuma',
              enabled: true,
              startTime: '09:30',
              endTime: '21:00',
            ),
            WorkingHourItem(
              day: 'saturday',
              label: 'Cumartesi',
              enabled: true,
              startTime: '09:30',
              endTime: '21:00',
            ),
            WorkingHourItem(
              day: 'sunday',
              label: 'Pazar',
              enabled: false,
            ),
          ],
          reviews: [
            TarakProfileReviewItem(
              id: 11,
              rating: 4,
              customerName: 'Fatih Şimşek',
              comment: 'Sakal tasarımı çok temiz ve simetrik çıktı.',
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(_makeApi(adapter)),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: Stack(
                  children: [
                    TarakBusinessDetailSheet(
                      business: const MapBusinessSummary(
                        id: '957',
                        userId: '2401',
                        slug: 'yigit-erkek-kuaforu-sisli',
                        businessName: 'Yiğit Erkek Kuaförü',
                        providerType: 'barber',
                        workMode: 'venue',
                        city: 'İstanbul',
                        district: 'Şişli',
                        latitude: 41.0507,
                        longitude: 28.9810,
                        hasPublicPin: true,
                        canGetDirections: true,
                        acceptsTarakBookings: true,
                        isVerified: true,
                      ),
                      isGuest: false,
                      onClose: () {},
                      onInAppDirections: () {},
                      onDirectBooking: () {},
                      onInstantCall: () {},
                      onSelectStaff: (_) {},
                      profileLoader: () async => richData,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('map_open_showcase_button')));
        await tester.pumpAndSettle();

        final hoursFinder = find.text('Çalışma Saatleri');
        final reviewsFinder = find.text('Değerlendirmeler');
        final directionsFinder = find.text('Konum ve Yol Tarifi');

        await tester.ensureVisible(directionsFinder);
        await tester.pumpAndSettle();

        expect(hoursFinder, findsOneWidget);
        expect(reviewsFinder, findsOneWidget);
        expect(directionsFinder, findsOneWidget);

        final hoursRect = tester.getRect(hoursFinder);
        final reviewsRect = tester.getRect(reviewsFinder);
        final directionsRect = tester.getRect(directionsFinder);

        expect(hoursRect.bottom, lessThanOrEqualTo(reviewsRect.top));
        expect(reviewsRect.bottom, lessThanOrEqualTo(directionsRect.top));
        expect(
          tester.getSize(find.byKey(const Key('profile_in_app_directions_btn'))).width,
          lessThan(200),
        );
        expect(tester.takeException(), isNull);

        // 3. Directory-only business NEVER renders external contact buttons under AppTheme.lightTheme
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: TarakProviderProfileContent(
                  data: const TarakProviderProfileData(
                    userId: 2439,
                    profileId: '995',
                    businessName: 'Dandy Soylu Berber',
                    providerType: 'barber',
                    acceptsTarakBookings: false,
                  ),
                  isGuest: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('İletişim'), findsNothing);
        expect(find.text('WhatsApp'), findsNothing);
        expect(find.text('Instagram'), findsNothing);
        expect(find.text('Web Sitesi'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _HaritaCustomerAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        status: AuthStatus.authenticated,
        user: UserModel(
          id: 901,
          role: 'CUSTOMER',
          name: 'Test Musteri',
          email: 'musteri@test.com',
        ),
      );
}

class _HaritaProviderAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        status: AuthStatus.authenticated,
        user: UserModel(
          id: 77,
          role: 'PROVIDER',
          name: 'Deniz Usta',
          email: 'deniz@test.com',
        ),
      );
}
