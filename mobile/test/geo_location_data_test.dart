import 'package:app/features/customer/providers/instant_request_provider.dart';
import 'package:app/features/customer/services/geo_service.dart';
import 'package:app/features/shared/widgets/account_sheets.dart';
import 'package:app/features/shared/widgets/geo_select_fields.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/disk_asset_bundle.dart';

/// The public API is unreachable; counts how often something tried it.
class _OfflineAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    throw DioException(requestOptions: options, error: 'offline');
  }

  @override
  void close({bool force = false}) {}
}

GeoService _bundledService(_OfflineAdapter adapter) =>
    GeoService(dio: Dio()..httpClientAdapter = adapter, bundle: DiskAssetBundle());

InputDecoration _dec(String label) => InputDecoration(labelText: label);

Future<void> _pumpFields(
  WidgetTester tester,
  GeoService service,
  Widget Function(BuildContext) field,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [geoServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Builder(builder: field),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, int dropdownIndex, String name) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).at(dropdownIndex));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bundled Turkey location data', () {
    test('81 il, tüm ilçeler ve her ilçenin mahalle/köy listesi pakette; ağa çıkılmaz', () async {
      final adapter = _OfflineAdapter();
      final geo = _bundledService(adapter);

      final provinces = await geo.getProvinces();
      expect(provinces.length, 81);
      expect(provinces.map((p) => p.id).toList()..sort(), List<int>.generate(81, (i) => i + 1));
      expect(provinces.fold<int>(0, (n, p) => n + p.districts.length), 973);

      final districtIds = <int>{};
      var names = 0;
      for (final province in provinces) {
        expect(province.districts, isNotEmpty, reason: province.name);
        for (final district in province.districts) {
          expect(districtIds.add(district.id), isTrue, reason: 'district id ${district.id} is unique');
          final list = await geo.getNeighborhoods(district.id);
          expect(list, isNotEmpty, reason: '${province.name} / ${district.name}');
          names += list.length;
        }
      }
      expect(names, greaterThan(49000));
      expect(adapter.calls, 0, reason: 'the bundled data must not need the third-party API');
    });

    test('İstanbul 39 ilçe; Kadıköy mahalleleri Caferağa\'yı içerir', () async {
      final geo = _bundledService(_OfflineAdapter());
      final istanbul = (await geo.getProvinces()).firstWhere((p) => p.name == 'İstanbul');
      expect(istanbul.districts.length, 39);
      final kadikoy = istanbul.districts.firstWhere((d) => d.name == 'Kadıköy');
      final mahalleler = (await geo.getNeighborhoods(kadikoy.id)).map((n) => n.name);
      expect(mahalleler.any((n) => n.contains('Caferağa')), isTrue);
    });

    test('Türkçe harflere duyarsız eşleşme', () async {
      expect(geoKey('İSTANBUL'), 'istanbul');
      expect(geoKey('Istanbul'), 'istanbul');
      expect(geoKey('  Çankırı '), 'cankiri');
      expect(geoKey('ŞANLIURFA'), 'sanliurfa');

      final geo = _bundledService(_OfflineAdapter());
      expect((await geo.findProvince('ISPARTA'))?.name, 'Isparta');
      expect((await geo.findProvince('cankiri'))?.name, 'Çankırı');
      expect(await geo.findProvince('Atlantis'), isNull);
    });
  });

  group('GeoSelectFields', () {
    testWidgets('il → ilçe → mahalle seçilir ve değerler controller\'lara yazılır', (tester) async {
      final geo = _bundledService(_OfflineAdapter());
      final provinces = await geo.getProvinces();
      final province = provinces.first;
      final district = province.districts.first;
      final firstNeighborhood = (await geo.getNeighborhoods(district.id)).first.name;

      final provinceCtl = TextEditingController();
      final districtCtl = TextEditingController();
      final neighborhoodCtl = TextEditingController();
      addTearDown(() {
        provinceCtl.dispose();
        districtCtl.dispose();
        neighborhoodCtl.dispose();
      });

      await _pumpFields(
        tester,
        geo,
        (_) => GeoSelectFields(
          province: provinceCtl,
          district: districtCtl,
          neighborhood: neighborhoodCtl,
          decoration: _dec,
        ),
      );

      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));

      await _choose(tester, 0, province.name);
      expect(provinceCtl.text, province.name);
      expect(districtCtl.text, isEmpty);

      await _choose(tester, 1, district.name);
      expect(districtCtl.text, district.name);

      await _choose(tester, 2, firstNeighborhood);
      expect(neighborhoodCtl.text, firstNeighborhood);

      // changing the il clears everything below it
      final other = provinces[1];
      await _choose(tester, 0, other.name);
      expect(provinceCtl.text, other.name);
      expect(districtCtl.text, isEmpty);
      expect(neighborhoodCtl.text, isEmpty);
    });

    testWidgets('eski serbest yazılmış değerler resmi yazımına çevrilir, bilinmeyenler korunur', (tester) async {
      final geo = _bundledService(_OfflineAdapter());
      final provinceCtl = TextEditingController(text: 'ISTANBUL');
      final districtCtl = TextEditingController(text: 'kadikoy');
      final legacyProvince = TextEditingController(text: 'Atlantis');
      final legacyDistrict = TextEditingController(text: 'Merkez Mahallesi');
      addTearDown(() {
        provinceCtl.dispose();
        districtCtl.dispose();
        legacyProvince.dispose();
        legacyDistrict.dispose();
      });

      await _pumpFields(tester, geo, (_) => GeoSelectFields(province: provinceCtl, district: districtCtl, decoration: _dec));
      expect(provinceCtl.text, 'İstanbul');
      expect(districtCtl.text, 'Kadıköy');
      expect(find.text('İstanbul'), findsOneWidget);
      expect(find.text('Kadıköy'), findsOneWidget);

      await _pumpFields(tester, geo, (_) => GeoSelectFields(province: legacyProvince, district: legacyDistrict, decoration: _dec));
      expect(legacyProvince.text, 'Atlantis');
      expect(legacyDistrict.text, 'Merkez Mahallesi');
      expect(find.text('Atlantis'), findsOneWidget);
    });

    testWidgets('yalnızca mahalle: il/ilçe sabit, o ilçenin mahalleleri sunulur', (tester) async {
      final geo = _bundledService(_OfflineAdapter());
      final istanbul = (await geo.getProvinces()).firstWhere((p) => p.name == 'İstanbul');
      final kadikoy = istanbul.districts.firstWhere((d) => d.name == 'Kadıköy');
      final first = (await geo.getNeighborhoods(kadikoy.id)).first.name;

      final provinceCtl = TextEditingController(text: 'İstanbul');
      final districtCtl = TextEditingController(text: 'Kadıköy');
      final neighborhoodCtl = TextEditingController();
      addTearDown(() {
        provinceCtl.dispose();
        districtCtl.dispose();
        neighborhoodCtl.dispose();
      });

      await _pumpFields(
        tester,
        geo,
        (_) => GeoSelectFields(
          province: provinceCtl,
          district: districtCtl,
          neighborhood: neighborhoodCtl,
          showLocation: false,
          decoration: _dec,
        ),
      );

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      await _choose(tester, 0, first);
      expect(neighborhoodCtl.text, first);
      expect(provinceCtl.text, 'İstanbul');
      expect(districtCtl.text, 'Kadıköy');
    });

    testWidgets('liste hiç yüklenemezse düz metin alanlarına düşer (kullanıcı engellenmez)', (tester) async {
      final geo = GeoService(dio: Dio()..httpClientAdapter = _OfflineAdapter(), bundle: MissingAssetBundle());
      final provinceCtl = TextEditingController();
      final districtCtl = TextEditingController();
      addTearDown(() {
        provinceCtl.dispose();
        districtCtl.dispose();
      });

      await _pumpFields(tester, geo, (_) => GeoSelectFields(province: provinceCtl, district: districtCtl, decoration: _dec));
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(2));

      await tester.enterText(find.byType(TextFormField).first, 'Ankara');
      expect(provinceCtl.text, 'Ankara');
    });
  });

  group('Hizmet veren işletme bilgileri', () {
    testWidgets('Şehir ve İlçe serbest metin değil, seçimli; diğer alanlar metin kalır', (tester) async {
      final geo = _bundledService(_OfflineAdapter());
      final adana = (await geo.getProvinces()).firstWhere((p) => p.name == 'Adana');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [geoServiceProvider.overrideWithValue(geo)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showProfileEditSheet(
                      context,
                      title: 'İşletme Bilgileri',
                      endpoint: '/provider/profile',
                      fields: const [
                        ProfileEditField(key: 'business_name', label: 'İşletme Adı', initial: 'Usta Berber'),
                        ProfileEditField(key: 'city', label: 'Şehir', kind: ProfileEditKind.province),
                        ProfileEditField(key: 'district', label: 'İlçe', kind: ProfileEditKind.district),
                        ProfileEditField(
                          key: 'service_radius_km',
                          label: 'Hizmet Yarıçapı (km)',
                          initial: '15',
                          keyboardType: TextInputType.number,
                          maxLength: 3,
                        ),
                      ],
                    ),
                    child: const Text('Aç'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
      expect(find.byType(TextField), findsNWidgets(2)); // İşletme Adı + Hizmet Yarıçapı

      await _choose(tester, 0, adana.name);
      await _choose(tester, 1, adana.districts.first.name);
      expect(find.text(adana.name), findsOneWidget);
      expect(find.text(adana.districts.first.name), findsOneWidget);
    });
  });
}
