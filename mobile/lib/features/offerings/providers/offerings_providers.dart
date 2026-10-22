import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../customer/providers/provider_list_origin.dart';
import '../../shared/widgets/provider_list_tools.dart';
import '../models/offering_models.dart';
import '../repositories/offerings_repository.dart';

final providerOfferingsRepositoryProvider = Provider<ProviderOfferingsRepository>((ref) {
  return ProviderOfferingsRepository(ref.watch(apiClientProvider));
});

final customerOfferingsRepositoryProvider = Provider<CustomerOfferingsRepository>((ref) {
  return CustomerOfferingsRepository(ref.watch(apiClientProvider));
});

// ── Provider side ────────────────────────────────────────────────────────────

final offeringCatalogProvider = FutureProvider<List<CatalogCategory>>((ref) {
  return ref.watch(providerOfferingsRepositoryProvider).fetchCatalog();
});

final myProviderServicesProvider = FutureProvider<List<MyProviderService>>((ref) {
  return ref.watch(providerOfferingsRepositoryProvider).fetchMyServices();
});

final myProviderPackagesProvider = FutureProvider<List<ProviderPackageModel>>((ref) {
  return ref.watch(providerOfferingsRepositoryProvider).fetchPackages();
});

// ── Customer side ────────────────────────────────────────────────────────────

typedef ServiceProvidersQuery = ({int serviceId, int? addressId, ProviderListFilters filters, ListOrigin? origin});
typedef ProviderOfferingsQuery = ({int providerUserId, int? addressId});

final serviceProvidersProvider =
    FutureProvider.family<ServiceProviderList, ServiceProvidersQuery>((ref, q) {
  return ref
      .watch(customerOfferingsRepositoryProvider)
      .fetchServiceProviderList(q.serviceId, addressId: q.addressId, filters: q.filters.toQuery(q.origin));
});

final providerOfferingsProvider =
    FutureProvider.family<ProviderOfferingsBundle, ProviderOfferingsQuery>((ref, q) {
  return ref.watch(customerOfferingsRepositoryProvider).fetchProviderOfferings(q.providerUserId, addressId: q.addressId);
});
