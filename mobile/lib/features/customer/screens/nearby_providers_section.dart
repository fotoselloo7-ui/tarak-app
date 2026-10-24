import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/provider_list_origin.dart';
import 'all_providers_screen.dart';
import 'home_sections.dart' show HomeProviderCard;
import 'my_addresses_screen.dart';

/// Reuses the verified provider distance query; no location permission on page load.
final nearbyHomeProvidersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, (double, double, int)>((ref, criteria) async {
  final (lat, lng, maxKm) = criteria;
  final page = await ref.read(providerListLoaderProvider)(
    ProviderListQuery(
      sort: 'distance',
      maxDistanceKm: maxKm,
      origin: ListOrigin(lat: lat, lng: lng),
    ), 1);
  return page.items.take(8).toList();
});

class NearbyProvidersSection extends ConsumerStatefulWidget {
  const NearbyProvidersSection({super.key});

  @override
  ConsumerState<NearbyProvidersSection> createState() => _NearbyProvidersSectionState();
}

class _NearbyProvidersSectionState extends ConsumerState<NearbyProvidersSection> {
  double _draftKm = 10;
  int _radiusKm = 10;

  @override
  Widget build(BuildContext context) {
    final origin = ref.watch(listOriginProvider);
    final locating = ref.watch(providerListOriginProvider).status;
    final results = origin == null ? null
        : ref.watch(nearbyHomeProvidersProvider((origin.lat, origin.lng, _radiusKm)));

    return Container(
      key: const Key('home_nearby_providers'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: AppTheme.radiusCard,
        border: Border.all(color: AppTheme.slate200), boxShadow: AppTheme.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Size Yakın Berberler',
          style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 18,
            fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        Text(origin == null
            ? 'Konum seçerek çevrenizdeki doğrulanmış uzmanları görün.'
            : 'Mesafeler kayıtlı adresinize veya seçtiğiniz cihaz konumuna göre hesaplanır.',
          style: const TextStyle(fontFamily: AppTheme.fontFamily,
            fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.tune_rounded, color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          const Expanded(child: Text('Arama mesafesi',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          Text(_draftKm.round().toString() + ' km',
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary)),
        ]),
        Slider(
          key: const Key('nearby_distance_slider'),
          value: _draftKm, min: 1, max: 50, divisions: 49,
          label: _draftKm.round().toString() + ' km',
          activeColor: AppTheme.primary,
          onChanged: (value) => setState(() => _draftKm = value),
          onChangeEnd: (value) => setState(() => _radiusKm = value.round()),
        ),
        if (origin == null) ...[
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Adresimi seç'),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const MyAddressesScreen()));
              }),
            OutlinedButton.icon(
              icon: const Icon(Icons.my_location),
              label: Text(locating == DeviceLocationStatus.locating
                ? 'Konum alınıyor...' : 'Konumumu kullan'),
              onPressed: locating == DeviceLocationStatus.locating
                ? null : () => ref.read(providerListOriginProvider.notifier).useDevice()),
          ]),
          if (locating == DeviceLocationStatus.denied ||
              locating == DeviceLocationStatus.unavailable)
            const Padding(padding: EdgeInsets.only(top: 8),
              child: Text('Konum alınamadı. Cihaz iznini kontrol edin veya adres seçin.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
        ] else ...[
          TextButton.icon(
            onPressed: () => ref.read(providerListOriginProvider.notifier).useDevice(),
            icon: const Icon(Icons.my_location, size: 17),
            label: const Text('Cihaz konumumu kullan')),
          if (results != null)
            results.when(
              data: (items) => items.isEmpty
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text('Bu mesafede konumu kayıtlı uzman bulunamadı.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)))
                : SizedBox(height: 188, child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => HomeProviderCard(provider: items[i]))),
              loading: () => const Padding(padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              error: (_, _) => TextButton(
                onPressed: () => ref.invalidate(
                  nearbyHomeProvidersProvider((origin.lat, origin.lng, _radiusKm))),
                child: const Text('Uzmanlar yüklenemedi. Tekrar dene'))),
        ],
      ]),
    );
  }
}
