import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tarak_rating.dart';
import '../../../core/widgets/verified_tick.dart';
import '../../map_directory/models/map_business_model.dart';
import '../../map_directory/services/directions_launcher.dart';
import '../../provider/staff/models/provider_staff_model.dart';
import '../../shared/widgets/provider_gallery.dart';
import '../../shared/widgets/report_sheet.dart';

class TarakProfileServiceItem {
  final int serviceId;
  final int? providerServiceId;
  final String name;
  final String? description;
  final double price;
  final double? originalPrice;
  final int discountPercent;
  final int durationMinutes;

  const TarakProfileServiceItem({
    required this.serviceId,
    this.providerServiceId,
    required this.name,
    this.description,
    required this.price,
    this.originalPrice,
    this.discountPercent = 0,
    required this.durationMinutes,
  });

  factory TarakProfileServiceItem.fromOfferingJson(Map<String, dynamic> json) {
    final nested = json['service'] is Map
        ? Map<String, dynamic>.from(json['service'] as Map)
        : null;
    return TarakProfileServiceItem(
      serviceId: (json['service_id'] as num?)?.toInt() ??
          int.tryParse((json['id'] ?? '0').toString()) ??
          0,
      providerServiceId: (json['provider_service_id'] as num?)?.toInt() ??
          int.tryParse((json['provider_service_id'] ?? '').toString()),
      name: (json['name'] ?? nested?['name'] ?? 'Hizmet').toString(),
      description: json['description']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      discountPercent: (json['discount_percent'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
    );
  }

  factory TarakProfileServiceItem.fromMapItem(MapBusinessServiceItem item) {
    return TarakProfileServiceItem(
      serviceId: int.tryParse(item.id) ?? 0,
      providerServiceId: int.tryParse(item.providerServiceId),
      name: item.name,
      description: item.description,
      price: item.price,
      originalPrice: item.originalPrice,
      discountPercent: item.discountPercent,
      durationMinutes: item.durationMinutes,
    );
  }
}

class TarakProfilePackageItem {
  final int id;
  final String title;
  final String? description;
  final double price;
  final double? originalPrice;
  final int discountPercent;
  final int durationMinutes;
  final List<String> serviceNames;

  const TarakProfilePackageItem({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    this.originalPrice,
    this.discountPercent = 0,
    required this.durationMinutes,
    this.serviceNames = const [],
  });

  factory TarakProfilePackageItem.fromOfferingJson(Map<String, dynamic> json) {
    final rawSvcs = json['services'];
    return TarakProfilePackageItem(
      id: (json['provider_package_id'] as num?)?.toInt() ??
          int.tryParse((json['id'] ?? '0').toString()) ??
          0,
      title: (json['title'] ?? 'Paket').toString(),
      description: json['description']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      discountPercent: (json['discount_percent'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 45,
      serviceNames: rawSvcs is List
          ? rawSvcs
              .map((e) => e is Map ? (e['name'] ?? '').toString() : '$e')
              .where((s) => s.isNotEmpty)
              .toList()
          : const [],
    );
  }

  factory TarakProfilePackageItem.fromMapItem(MapBusinessPackageItem item) {
    return TarakProfilePackageItem(
      id: int.tryParse(item.id) ?? 0,
      title: item.title,
      description: item.description,
      price: item.price,
      originalPrice: item.originalPrice,
      discountPercent: item.discountPercent,
      durationMinutes: item.durationMinutes,
      serviceNames: item.services,
    );
  }
}

class TarakProfileReviewItem {
  final int? id;
  final int rating;
  final String customerName;
  final String? comment;
  final String? createdAt;

  const TarakProfileReviewItem({
    this.id,
    required this.rating,
    required this.customerName,
    this.comment,
    this.createdAt,
  });

  factory TarakProfileReviewItem.fromJson(Map<String, dynamic> json) {
    return TarakProfileReviewItem(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id'] ?? ''}'),
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      customerName: (json['customer_name'] ?? 'Müşteri').toString(),
      comment: json['comment']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  factory TarakProfileReviewItem.fromMapItem(MapBusinessReviewItem item) {
    return TarakProfileReviewItem(
      id: int.tryParse(item.id),
      rating: item.rating,
      customerName: item.customerName,
      comment: item.comment,
      createdAt: item.createdAt,
    );
  }
}

/// Canonical profile view-model shared by ProviderDetailScreen, expandable map sheet,
/// and showcase views so Tarak ALWAYS renders ONE authentic profile and rating source.
class TarakProviderProfileData {
  final int? userId;
  final String? profileId;
  final String? slug;
  final String? publicUrl;
  final String businessName;
  final String providerType; // 'barber' | 'coiffeur'
  final String? avatarUrl;
  final String? coverUrl;
  final List<String> gallery;
  final bool isVerified;
  final bool isOnline;
  final bool acceptsTarakBookings;
  final String? city;
  final String? district;
  final String? formattedAddress;
  final double? latitude;
  final double? longitude;
  final bool canGetDirections;
  final String? bio;
  final int? experienceYears;
  final int discountPercent;
  final double ratingAvg;
  final int reviewCount;
  final List<TarakProfileReviewItem> reviews;
  final List<TarakProfileServiceItem> services;
  final List<TarakProfilePackageItem> packages;
  final List<ProviderStaffModel> staff;
  final List<WorkingHourItem> workingHours;

  const TarakProviderProfileData({
    this.userId,
    this.profileId,
    this.slug,
    this.publicUrl,
    required this.businessName,
    required this.providerType,
    this.avatarUrl,
    this.coverUrl,
    this.gallery = const [],
    this.isVerified = false,
    this.isOnline = false,
    this.acceptsTarakBookings = true,
    this.city,
    this.district,
    this.formattedAddress,
    this.latitude,
    this.longitude,
    this.canGetDirections = false,
    this.bio,
    this.experienceYears,
    this.discountPercent = 0,
    this.ratingAvg = 0,
    this.reviewCount = 0,
    this.reviews = const [],
    this.services = const [],
    this.packages = const [],
    this.staff = const [],
    this.workingHours = const [],
  });

  String get typeLabel =>
      providerType == 'coiffeur' ? 'Kadın Kuaförü' : 'Erkek Berberi';

  String get regionLabel {
    final parts = [district, city]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  /// Resolves service names mapped by `serviceId` across catalog/provider services.
  Map<int, String> get serviceNamesById {
    return {
      for (final s in services)
        if (s.serviceId > 0) s.serviceId: s.name,
    };
  }
}

/// Fetches canonical profile data by unifying `/customer/providers/{id}/offerings`,
/// `/providers/{id}/reviews`, `/customer/providers/{id}/staff`, and `/map/businesses/{slug}`.
class CanonicalProviderProfileLoader {
  static Future<TarakProviderProfileData> load({
    required ApiClient api,
    int? providerUserId,
    String? slugOrIdentifier,
    String? fallbackName,
    MapBusinessSummary? initialSummary,
    bool isGuest = false,
  }) async {
    Map<String, dynamic>? offeringProvider;
    List<dynamic> rawOfferingServices = const [];
    List<dynamic> rawOfferingPackages = const [];
    bool loadedOfferings = false;

    MapBusinessDetail? mapDetail;
    List<ProviderStaffModel> staffList = const [];
    double? canonicalAvg;
    int? canonicalCount;
    List<TarakProfileReviewItem>? canonicalReviews;

    final int? resolvedUserId =
        providerUserId ?? int.tryParse(initialSummary?.userId ?? '');

    Future<void> fetchOfferings() async {
      if (isGuest || resolvedUserId == null) return;
      try {
        final res =
            await api.get('/customer/providers/$resolvedUserId/offerings');
        final data = res.data is Map ? res.data['data'] : null;
        if (data is Map) {
          offeringProvider = data['provider'] is Map
              ? Map<String, dynamic>.from(data['provider'] as Map)
              : null;
          rawOfferingServices =
              data['services'] is List ? data['services'] as List : const [];
          rawOfferingPackages =
              data['packages'] is List ? data['packages'] as List : const [];
          loadedOfferings = offeringProvider != null;
        }
      } catch (_) {
        // Directory-only or unapproved providers return 404 here; map detail covers them.
      }
    }

    Future<void> fetchReviews(int uid) async {
      try {
        final rev = await api.get('/providers/$uid/reviews');
        final rd = rev.data is Map ? rev.data['data'] : null;
        if (rd is Map) {
          canonicalCount = (rd['count'] as num?)?.toInt() ?? 0;
          canonicalAvg = (rd['average'] as num?)?.toDouble() ?? 0;
          final rawList = rd['reviews'];
          if (rawList is List) {
            canonicalReviews = rawList
                .whereType<Map>()
                .map(
                  (r) => TarakProfileReviewItem.fromJson(
                    Map<String, dynamic>.from(r),
                  ),
                )
                .toList();
          }
        }
      } catch (_) {
        // Best-effort; fall back to mapDetail / offeringProvider stats if unavailable.
      }
    }

    Future<void> fetchStaff() async {
      if (isGuest || resolvedUserId == null) return;
      try {
        final res = await api.get('/customer/providers/$resolvedUserId/staff');
        final body = res.data;
        final list =
            body is Map && body['data'] is List ? body['data'] as List : null;
        if (list != null) {
          staffList = list
              .whereType<Map>()
              .map(
                (e) => ProviderStaffModel.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .where((s) => s.isActive && s.visibleToCustomers && !s.isArchived)
              .toList();
        }
      } catch (_) {
        // Best-effort; map detail may still carry active public staff.
      }
    }

    Future<void> fetchMapDetail() async {
      final rawId = slugOrIdentifier?.trim().isNotEmpty == true
          ? slugOrIdentifier!.trim()
          : (initialSummary?.slug.trim().isNotEmpty == true
              ? initialSummary!.slug.trim()
              : resolvedUserId?.toString());
      if (rawId == null || rawId.isEmpty) return;
      try {
        final res = await api.get('/map/businesses/$rawId');
        final data = res.data is Map ? res.data['data'] : null;
        if (data is Map) {
          mapDetail =
              MapBusinessDetail.fromJson(Map<String, dynamic>.from(data));
        }
      } catch (_) {
        // Some non-map contexts or unit-test mocks do not register /map/businesses/*.
      }
    }

    await Future.wait([
      fetchOfferings(),
      if (resolvedUserId != null) fetchReviews(resolvedUserId),
      fetchStaff(),
      fetchMapDetail(),
    ]);

    // If identifier was a slug and we didn't have userId up front, fetch canonical reviews now.
    final detailUserId =
        resolvedUserId ?? int.tryParse(mapDetail?.userId ?? '');
    if (canonicalCount == null && detailUserId != null) {
      await fetchReviews(detailUserId);
    }

    if (!loadedOfferings && mapDetail == null && initialSummary == null) {
      throw StateError('Hizmet veren profili yüklenemedi.');
    }

    final name = offeringProvider?['business_name']?.toString() ??
        offeringProvider?['name']?.toString() ??
        mapDetail?.businessName ??
        initialSummary?.businessName ??
        fallbackName ??
        'Hizmet Veren';

    final providerType = offeringProvider?['provider_type']?.toString() ??
        mapDetail?.providerType ??
        initialSummary?.providerType ??
        'barber';

    final avatarUrl = (offeringProvider?['avatar_url']?.toString() ??
            mapDetail?.avatarUrl ??
            initialSummary?.avatarUrl ??
            mapDetail?.logoUrl ??
            initialSummary?.logoUrl)
        ?.trim();

    final coverUrl = (offeringProvider?['cover_url']?.toString() ??
            mapDetail?.coverUrl ??
            initialSummary?.coverUrl)
        ?.trim();

    final galleryRaw = offeringProvider?['gallery'] ?? mapDetail?.gallery;
    final gallery = providerGalleryUrls(galleryRaw);

    final bool isVerified = offeringProvider != null
        ? (offeringProvider!['is_verified'] == true)
        : (mapDetail?.isVerified ?? initialSummary?.isVerified ?? false);

    final bool isOnline = offeringProvider != null
        ? (offeringProvider!['is_online'] == true)
        : (mapDetail?.isOnline ?? initialSummary?.isOnline ?? false);

    // If customer offerings endpoint didn't exist (directory-only), read accepts_tarak_bookings from mapDetail.
    final bool acceptsTarak = mapDetail?.acceptsTarakBookings ??
        initialSummary?.acceptsTarakBookings ??
        loadedOfferings;

    final int reviewCount = canonicalCount ??
        (offeringProvider?['review_count'] as num?)?.toInt() ??
        mapDetail?.reviewCount ??
        initialSummary?.reviewCount ??
        0;

    final double ratingAvg = canonicalAvg ??
        (offeringProvider?['rating'] as num?)?.toDouble() ??
        mapDetail?.rating ??
        initialSummary?.rating ??
        0;

    final List<TarakProfileReviewItem> reviews = canonicalReviews ??
        (mapDetail?.reviews.map(TarakProfileReviewItem.fromMapItem).toList() ??
            const []);

    final services = rawOfferingServices.isNotEmpty
        ? rawOfferingServices
            .whereType<Map>()
            .map(
              (s) => TarakProfileServiceItem.fromOfferingJson(
                Map<String, dynamic>.from(s),
              ),
            )
            .toList()
        : (mapDetail?.services
                .map(TarakProfileServiceItem.fromMapItem)
                .toList() ??
            const []);

    final packages = rawOfferingPackages.isNotEmpty
        ? rawOfferingPackages
            .whereType<Map>()
            .map(
              (p) => TarakProfilePackageItem.fromOfferingJson(
                Map<String, dynamic>.from(p),
              ),
            )
            .toList()
        : (mapDetail?.packages
                .map(TarakProfilePackageItem.fromMapItem)
                .toList() ??
            const []);

    final resolvedStaff = staffList.isNotEmpty
        ? staffList
        : (acceptsTarak ? (mapDetail?.staff ?? const []) : const <ProviderStaffModel>[]);

    return TarakProviderProfileData(
      userId: detailUserId,
      profileId: offeringProvider?['id']?.toString() ?? mapDetail?.id,
      slug: mapDetail?.slug ?? initialSummary?.slug,
      publicUrl: mapDetail?.publicUrl ?? initialSummary?.publicUrl,
      businessName: name,
      providerType: providerType,
      avatarUrl: (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : null,
      coverUrl: (coverUrl != null && coverUrl.isNotEmpty) ? coverUrl : null,
      gallery: gallery,
      isVerified: isVerified,
      isOnline: isOnline,
      acceptsTarakBookings: acceptsTarak,
      city: offeringProvider?['city']?.toString() ??
          mapDetail?.city ??
          initialSummary?.city,
      district: offeringProvider?['district']?.toString() ??
          mapDetail?.district ??
          initialSummary?.district,
      formattedAddress:
          mapDetail?.formattedAddress ?? initialSummary?.formattedAddress,
      latitude: mapDetail?.latitude ?? initialSummary?.latitude,
      longitude: mapDetail?.longitude ?? initialSummary?.longitude,
      canGetDirections: mapDetail?.canGetDirections ??
          initialSummary?.canGetDirections ??
          false,
      bio: offeringProvider?['bio']?.toString() ?? mapDetail?.bio,
      experienceYears:
          (offeringProvider?['experience_years'] as num?)?.toInt() ??
              mapDetail?.experienceYears,
      discountPercent:
          (offeringProvider?['discount_percent'] as num?)?.toInt() ??
              mapDetail?.discountPercent ??
              0,
      ratingAvg: ratingAvg,
      reviewCount: reviewCount,
      reviews: reviews,
      services: services,
      packages: packages,
      staff: resolvedStaff,
      workingHours: mapDetail?.workingHours ?? const [],
    );
  }
}

/// Shared original Tarak profile content used verbatim across `ProviderDetailScreen`,
/// `TarakBusinessDetailSheet` (expanded map sheet), and `BusinessShowcaseScreen`.
class TarakProviderProfileContent extends StatelessWidget {
  final TarakProviderProfileData data;
  final bool isGuest;
  final bool showHeaderAndCover;
  final VoidCallback? onBookAppointment;
  final VoidCallback? onInstantCall;
  final void Function(ProviderStaffModel staff)? onSelectStaff;
  final VoidCallback? onInAppDirections;
  final ExternalUriLauncher? uriLauncher;

  const TarakProviderProfileContent({
    super.key,
    required this.data,
    this.isGuest = false,
    this.showHeaderAndCover = true,
    this.onBookAppointment,
    this.onInstantCall,
    this.onSelectStaff,
    this.onInAppDirections,
    this.uriLauncher,
  });

  String _tl(double v) {
    final isWhole = v == v.roundToDouble();
    return isWhole ? '₺${v.toStringAsFixed(0)}' : '₺${v.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: buildSections(context),
    );
  }

  List<Widget> buildSections(BuildContext context) {
    final location = data.regionLabel;
    final hasWorkingHours = data.workingHours.any((h) => h.enabled);

    return <Widget>[
        if (showHeaderAndCover) ...[
          if (data.coverUrl != null && data.coverUrl!.startsWith('http')) ...[
            ProviderCover(url: data.coverUrl!),
            const SizedBox(height: 14),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: ClipOval(
                  child: (data.avatarUrl != null && data.avatarUrl!.isNotEmpty)
                      ? Image.network(
                          data.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _avatarFallback(data.businessName),
                        )
                      : _avatarFallback(data.businessName),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            data.businessName,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (data.isVerified) ...[
                          const SizedBox(width: 6),
                          const VerifiedTick(size: 18),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.typeLabel,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppTheme.slate400,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    data.reviewCount > 0
                        ? TarakRatingLabel(
                            value: data.ratingAvg,
                            count: data.reviewCount,
                            countSuffix: ' değerlendirme',
                            size: 14,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          )
                        : const Text(
                            'Henüz değerlendirme yok',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.slate400,
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ],
        if (data.bio != null && data.bio!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            data.bio!.trim(),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
        if ((data.experienceYears != null && data.experienceYears! > 0) ||
            data.services.isNotEmpty ||
            data.isOnline ||
            data.discountPercent > 0) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (data.experienceYears != null && data.experienceYears! > 0)
                _factChip(
                  Icons.workspace_premium_outlined,
                  '${data.experienceYears} yıl deneyim',
                ),
              if (data.services.isNotEmpty)
                _factChip(
                  Icons.content_cut_rounded,
                  '${data.services.length} hizmet',
                ),
              if (data.isOnline)
                _factChip(
                  Icons.circle,
                  'Şu an müsait',
                  color: AppTheme.success,
                  bg: AppTheme.successLight,
                ),
              if (data.discountPercent > 0)
                _factChip(
                  Icons.local_offer_outlined,
                  '%${data.discountPercent} kampanya indirimi',
                  color: AppTheme.primaryDark,
                  bg: AppTheme.primaryLight,
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),

        ProviderGallerySection(urls: data.gallery),
        if (data.gallery.isNotEmpty) const SizedBox(height: 20),

        // Staff Section ("Ustalarımız / Uzmanlarımız")
        if (data.acceptsTarakBookings && data.staff.isNotEmpty) ...[
          ProviderStaffSection(
            staff: data.staff,
            serviceNamesById: data.serviceNamesById,
            onSelectStaff: onSelectStaff,
          ),
          const SizedBox(height: 20),
        ],

        if (data.services.isNotEmpty) ...[
          const Text(
            'Hizmetler',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...data.services.map(
            (s) => _offeringTile(
              s.name,
              s.description,
              s.price,
              s.originalPrice,
              s.durationMinutes,
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (data.packages.isNotEmpty) ...[
          const Text(
            'Paketler',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...data.packages.map(
            (p) => _offeringTile(
              p.title,
              p.description ??
                  (p.serviceNames.isNotEmpty
                      ? p.serviceNames.join(' + ')
                      : null),
              p.price,
              p.originalPrice,
              p.durationMinutes,
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (hasWorkingHours) ...[
          const Text(
            'Çalışma Saatleri',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.slate200),
            ),
            child: Column(
              children: data.workingHours
                  .map(
                    (h) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 98,
                            child: Text(
                              h.label,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12.5,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              h.displayHours,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: h.enabled
                                    ? AppTheme.textPrimary
                                    : AppTheme.slate400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (data.reviews.isNotEmpty) ...[
          const Text(
            'Değerlendirmeler',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...data.reviews.take(5).map((r) => _reviewTile(context, r)),
          const SizedBox(height: 16),
        ],

        if (data.canGetDirections &&
            data.latitude != null &&
            data.longitude != null &&
            onInAppDirections != null) ...[
          const Text(
            'Konum ve Yol Tarifi',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.slate200),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data.formattedAddress?.isNotEmpty == true
                        ? data.formattedAddress!
                        : (location.isNotEmpty
                            ? location
                            : 'İşletme konumu mevcut'),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const Key('profile_in_app_directions_btn'),
                  onPressed: onInAppDirections,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.darkNavy,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.directions_rounded, size: 16),
                  label: const Text('Yol Tarifi'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Bottom CTAs — strictly preserve original Randevu Al + Hemen Çağır
        if (data.acceptsTarakBookings) ...[
          if (onBookAppointment != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('profile_book_appointment_btn'),
                onPressed: onBookAppointment,
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: const Text('Randevu Al'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          if (onInstantCall != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('profile_instant_call_btn'),
                onPressed: onInstantCall,
                icon: const Icon(Icons.flash_on_rounded, size: 18),
                label: const Text('Hemen Çağır'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.slate100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.slate200),
            ),
            child: const Text(
              'Bu işletme yalnızca Tarak Harita işletme rehberinde yer alır; uygulama içi randevu kabul etmemektedir.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ];
  }

  static Widget _avatarFallback(String name) {
    return Container(
      color: AppTheme.primaryLight,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _factChip(
    IconData icon,
    String text, {
    Color color = AppTheme.slate600,
    Color? bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? AppTheme.slate100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _offeringTile(
    String title,
    String? desc,
    double price,
    double? originalPrice,
    int duration,
  ) {
    final hasDiscount = originalPrice != null && originalPrice > price;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (desc != null && desc.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    desc.trim(),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '$duration dk',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: AppTheme.slate400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hasDiscount)
                Text(
                  _tl(originalPrice),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11.5,
                    color: AppTheme.slate400,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              Text(
                _tl(price),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reviewTile(BuildContext context, TarakProfileReviewItem r) {
    final reviewId = r.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                r.customerName,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TarakRatingScale(value: r.rating, size: 14),
            ],
          ),
          if (r.comment != null && r.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              r.comment!.trim(),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          if (!isGuest && reviewId != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: Key('report_review_$reviewId'),
                onPressed: () => showReportSheet(
                  context,
                  contentType: 'REVIEW',
                  contentId: reviewId,
                  preview: r.comment,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.slate400,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  textStyle: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(Icons.flag_outlined, size: 14),
                label: const Text('Bildir'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal scrollable compact staff cards matching Tarak's visual system.
/// Staff members NEVER inherit the shop's verified tick.
class ProviderStaffSection extends StatelessWidget {
  final List<ProviderStaffModel> staff;
  final Map<int, String> serviceNamesById;
  final void Function(ProviderStaffModel member)? onSelectStaff;

  const ProviderStaffSection({
    super.key,
    required this.staff,
    this.serviceNamesById = const {},
    this.onSelectStaff,
  });

  String _servicesSummary(ProviderStaffModel member) {
    final names = <String>[];
    for (final s in member.services) {
      if (!s.isActive) continue;
      final label = (s.serviceName != null && s.serviceName!.trim().isNotEmpty)
          ? s.serviceName!.trim()
          : serviceNamesById[s.serviceId];
      if (label != null && label.isNotEmpty) {
        names.add(label);
      }
    }
    if (names.isEmpty) {
      return '${member.services.length} hizmet';
    }
    return names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    if (staff.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ustalarımız / Uzmanlarımız',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          key: const Key('provider_staff_horizontal_list'),
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: staff.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final member = staff[index];
              final canBook = member.acceptsAppointments && onSelectStaff != null;
              final initials = member.fullName.isNotEmpty
                  ? member.fullName.substring(0, 1).toUpperCase()
                  : '?';
              final svcSummary = _servicesSummary(member);

              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  key: Key('profile_staff_card_${member.id}'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: canBook ? () => onSelectStaff!(member) : null,
                  child: Container(
                    width: 224,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.slate200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipOval(
                              child: SizedBox(
                                width: 42,
                                height: 42,
                                child: (member.photoUrl != null &&
                                        member.photoUrl!.isNotEmpty)
                                    ? Image.network(
                                        member.photoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _staffFallback(initials),
                                      )
                                    : _staffFallback(initials),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  if (member.subtitle.isNotEmpty)
                                    Text(
                                      member.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 11.5,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            svcSummary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              color: AppTheme.slate600,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: member.acceptsAppointments
                                      ? AppTheme.successLight
                                      : AppTheme.slate100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  member.acceptsAppointments
                                      ? 'Randevuya açık'
                                      : 'Randevu almıyor',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: member.acceptsAppointments
                                        ? AppTheme.success
                                        : AppTheme.slate600,
                                  ),
                                ),
                              ),
                            ),
                            if (canBook) ...[
                              const SizedBox(width: 6),
                              const Text(
                                'Seç',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _staffFallback(String initials) {
    return Container(
      color: AppTheme.primaryLight,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}
