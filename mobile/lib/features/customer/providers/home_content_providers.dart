import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

/// Verified/featured providers for the customer home (real data, same
/// `/providers/featured` endpoint the web homepage falls back to).
/// Non-autoDispose + guarded so it never leaves a pending timer in widget tests.
final featuredProvidersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authNotifierProvider.select((s) => s.user?.avatarUrl));
  try {
    final ApiClient api = ref.read(apiClientProvider);
    final res = await api.get('/providers/featured', queryParameters: {'limit': 8});
    final data = res.data is Map ? res.data['data'] : null;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  } catch (_) {
    // Safe empty fallback.
  }
  return <Map<String, dynamic>>[];
});

/// "Doğrulanmış Hizmet Verenler" for one type: `barber` (men) or `coiffeur` (women).
/// The server ranks by Tarak puanı and limits the list.
final verifiedProvidersByTypeProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, type) async {
  ref.watch(authNotifierProvider.select((s) => s.user?.avatarUrl));
  try {
    final ApiClient api = ref.read(apiClientProvider);
    final res = await api.get('/providers/featured', queryParameters: {'limit': 8, 'type': type});
    final data = res.data is Map ? res.data['data'] : null;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  } catch (_) {
    // Safe empty fallback.
  }
  return <Map<String, dynamic>>[];
});

/// Paid "Öne Çıkan Profesyoneller": providers with a running period, in random
/// order, plus how often the section should turn to the next page.
class SpotlightData {
  final List<Map<String, dynamic>> providers;
  final int rotateSeconds;
  const SpotlightData({this.providers = const [], this.rotateSeconds = 8});
}

final spotlightProvidersProvider = FutureProvider<SpotlightData>((ref) async {
  ref.watch(authNotifierProvider.select((s) => s.user?.avatarUrl));
  try {
    final ApiClient api = ref.read(apiClientProvider);
    final res = await api.get('/providers/spotlight');
    final body = res.data is Map ? res.data : null;
    final data = body?['data'];
    if (data is List) {
      final meta = body?['meta'];
      final seconds = meta is Map ? (meta['rotate_seconds'] as num?)?.toInt() : null;
      return SpotlightData(
        providers: data.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        rotateSeconds: (seconds ?? 8).clamp(3, 120),
      );
    }
  } catch (_) {
    // Hidden when it cannot load.
  }
  return const SpotlightData();
});

/// "Yeni Katılan Profesyoneller": most recently approved providers.
final newestProvidersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authNotifierProvider.select((s) => s.user?.avatarUrl));
  try {
    final ApiClient api = ref.read(apiClientProvider);
    final res = await api.get('/providers/newest', queryParameters: {'limit': 8});
    final data = res.data is Map ? res.data['data'] : null;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  } catch (_) {
    // Hidden when it cannot load.
  }
  return <Map<String, dynamic>>[];
});

/// Home statistics resolved by the server (real or admin-typed, per the admin's
/// mode). [audience]: `all` (landing) | `customer` | `provider`.
final homeStatsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, audience) async {
  try {
    final ApiClient api = ref.read(apiClientProvider);
    final res = await api.get('/stats/home', queryParameters: {'audience': audience});
    final data = res.data is Map ? res.data['data'] : null;
    final items = data is Map ? data['items'] : null;
    if (items is List) {
      return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  } catch (_) {
    // Hidden when it cannot load.
  }
  return <Map<String, dynamic>>[];
});

/// The full `/site-config` payload, fetched ONCE and shared by every derived
/// provider below (Riverpod caches this future — homeVerificationProvider,
/// homeSectionsProvider and providerCtaProvider all watch it instead of each
/// issuing their own request). Single source of truth, shared with web.
final siteConfigDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final ApiClient api = ref.read(apiClientProvider);
    final res = await api.get('/site-config');
    final data = res.data is Map ? res.data['data'] : null;
    if (data is Map) return Map<String, dynamic>.from(data);
  } catch (_) {
    // Fall through to defaults handled by widgets.
  }
  return <String, dynamic>{};
});

/// Home verification/trust content from site-config (single source of truth,
/// shared with the web SecuritySection).
final homeVerificationProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final data = await ref.watch(siteConfigDataProvider.future);
  final home = data['home'];
  final verification = home is Map ? home['verification'] : null;
  return verification is Map ? Map<String, dynamic>.from(verification) : <String, dynamic>{};
});

/// Homepage section visibility + order (shared by web & mobile — same keys:
/// hero, stats, how_it_works, categories, providers, verification,
/// provider_cta, app_download). Empty list => every section defaults visible.
final homeSectionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.watch(siteConfigDataProvider.future);
  final home = data['home'];
  final sections = home is Map ? home['sections'] : null;
  if (sections is List) {
    return sections.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  return <Map<String, dynamic>>[];
});

/// "Hizmet Veren Ol" recruitment banner copy from site-config.
final providerCtaProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final data = await ref.watch(siteConfigDataProvider.future);
  final home = data['home'];
  final cta = home is Map ? home['provider_cta'] : null;
  return cta is Map ? Map<String, dynamic>.from(cta) : <String, dynamic>{};
});

/// Any `home.<group>` object from site-config (how_it_works, categories,
/// providers, app_download ...). Keeps web and mobile on identical copy.
final homeGroupProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, group) async {
  final data = await ref.watch(siteConfigDataProvider.future);
  final home = data['home'];
  final value = home is Map ? home[group] : null;
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
});

/// Hero copy (`landing.hero`) + admin-uploaded branding images.
final heroContentProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final data = await ref.watch(siteConfigDataProvider.future);
  final landing = data['landing'];
  final hero = landing is Map ? landing['hero'] : null;
  return hero is Map ? Map<String, dynamic>.from(hero) : <String, dynamic>{};
});

final brandingProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final data = await ref.watch(siteConfigDataProvider.future);
  final branding = data['branding'];
  return branding is Map ? Map<String, dynamic>.from(branding) : <String, dynamic>{};
});

/// Marketing stats (`landing.stats`) honouring admin visibility/order —
/// exactly the same list the web homepage renders.
final landingStatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.watch(siteConfigDataProvider.future);
  final landing = data['landing'];
  final stats = landing is Map ? landing['stats'] : null;
  if (stats is! List) return <Map<String, dynamic>>[];

  final list = stats.map((e) => Map<String, dynamic>.from(e as Map)).where((s) => s['is_active'] != false).toList()
    ..sort((a, b) => ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0));
  return list;
});

/// Canonical service categories for the HOMEPAGE, read from the very same
/// `/api/service-categories` endpoint the booking flow and the web homepage
/// use. Kept separate from `serviceCategoriesProvider` (booking flow) only so
/// homepage rendering is failure-tolerant: errors resolve to an empty list
/// instead of leaving a pending request, matching the other home providers.
final homeCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final ApiClient api = ref.read(apiClientProvider);
    final res = await api.get('/service-categories');
    final data = res.data is Map ? res.data['data'] : null;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  } catch (_) {
    // Heading still renders; cards simply stay empty.
  }
  return <Map<String, dynamic>>[];
});

/// Is homepage section [key] active per admin config? Defaults to visible
/// when the admin hasn't configured section visibility yet.
bool isHomeSectionActive(List<Map<String, dynamic>> sections, String key) {
  if (sections.isEmpty) return true;
  final match = sections.where((s) => s['key'] == key);
  if (match.isEmpty) return true;
  return match.first['is_active'] != false;
}

/// Homepage section keys in admin-configured order (falls back to
/// [defaultOrder] when the admin hasn't set an order yet). Mirrors the web's
/// `orderedSectionKeys` in siteConfigService.ts — same config, same result.
List<String> orderedHomeSectionKeys(List<Map<String, dynamic>> sections, List<String> defaultOrder) {
  if (sections.isEmpty) return defaultOrder;
  final known = defaultOrder.toSet();
  final ranked = [...sections]
      .where((s) => known.contains(s['key']))
      .toList()
    ..sort((a, b) => ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0));
  final result = ranked.map((s) => s['key'] as String).toList();
  for (final key in defaultOrder) {
    if (!result.contains(key)) result.add(key);
  }
  return result;
}


/// Same public catalog and product hierarchy as the web home.
const homeProductSectionOrder = ['hero', 'stats', 'categories', 'spotlight', 'services', 'providers', 'newest', 'how_it_works', 'verification', 'provider_cta', 'app_download'];
final homeServicesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/services');
  final data = res.data is Map ? res.data['data'] : null;
  if (data is! List) throw const FormatException('Hizmetler yüklenemedi.');
  return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
}, retry: (_, _) => null);

/// Uses the same server-side distance query as the web home. The API computes
/// distance from the customer's actual profile coordinates and never sends
/// provider coordinates to the client.
typedef NearbyHomeQuery = ({double? latitude, double? longitude, int radiusKm, int? customerAddressId});

String? nearbyProviderType(String? gender) => switch (gender?.toLowerCase()) {
  'female' => 'coiffeur', 'male' => 'barber', _ => null,
};

final nearbyHomeProvidersProvider = FutureProvider.family<List<Map<String, dynamic>>, NearbyHomeQuery>((ref, query) async {
  ref.watch(authNotifierProvider.select((s) => s.user?.id));
  ref.watch(authNotifierProvider.select((s) => s.user?.avatarUrl));
  final type = nearbyProviderType(ref.watch(authNotifierProvider.select((s) => s.user?.gender)));
  final res = await ref.read(apiClientProvider).get('/customer/providers/nearby', queryParameters: {
    if (query.customerAddressId != null) 'customer_address_id': query.customerAddressId,
    'type': ?type,
    if (query.latitude != null) 'lat': query.latitude,
    if (query.longitude != null) 'lng': query.longitude,
    'radius_km': query.radiusKm,
  });
  final data = res.data is Map ? res.data['data'] : null;
  if (data is! List) throw const FormatException('Yakındaki hizmet verenler yüklenemedi.');
  return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
}, retry: (_, _) => null);
