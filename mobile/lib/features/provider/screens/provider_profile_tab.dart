import '../../notifications/screens/notification_center_screen.dart';

import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tarak_rating.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/screens/support_screen.dart';
import '../../shared/screens/legal_screen.dart';
import '../../shared/screens/sessions_screen.dart';
import '../../offerings/screens/provider_offerings_screen.dart';
import '../../shared/widgets/account_sheets.dart';
import '../../shared/widgets/social_account_link_sheet.dart';
import '../../shared/widgets/avatar_picker.dart';
import '../appointments/screens/provider_schedule_screen.dart';
import 'provider_wallet_screen.dart';
import 'provider_documents_screen.dart';
import 'provider_location_sheet.dart';
import '../instant/providers/provider_instant_providers.dart';
import '../../shared/widgets/app_icon_card.dart';
import '../../../core/widgets/verified_tick.dart';

/// The signed-in provider's own rating summary (real data).
final providerReviewSummaryProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  ref.watch(authNotifierProvider.select((state) => state.user?.id));
  final api = ref.read(apiClientProvider);
  final res = await api.get('/provider/reviews');
  final data = res.data is Map ? res.data['data'] : null;
  if (data is! Map) {
    throw const FormatException('Değerlendirmeler yüklenemedi.');
  }
  return Map<String, dynamic>.from(data);
}, retry: (_, _) => null);

final providerDocumentsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  ref.watch(authNotifierProvider.select((state) => state.user?.id));
  final api = ref.read(apiClientProvider);
  final res = await api.get('/provider/documents');
  final data = res.data is Map ? res.data['data'] : null;
  if (data is! List) throw const FormatException('Belgeler yüklenemedi.');
  return data
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}, retry: (_, _) => null);

final providerJobStatsProvider =
    FutureProvider<({int completed, int upcoming})>((ref) async {
      ref.watch(authNotifierProvider.select((state) => state.user?.id));
      final api = ref.read(apiClientProvider);
      final res = await api.get('/provider/appointments');
      final data = res.data is Map ? res.data['data'] : null;
      if (data is! List) throw const FormatException('Randevular yüklenemedi.');
      final rows = data.whereType<Map>();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return (
        completed: rows.where((a) => a['status'] == 'COMPLETED').length,
        upcoming: rows.where((a) {
          final date = DateTime.tryParse(
            a['appointment_date']?.toString() ?? '',
          );
          return {
                'PENDING',
                'CONFIRMED',
                'ALT_PROPOSED',
              }.contains(a['status']) &&
              date != null &&
              !date.isBefore(today);
        }).length,
      );
    }, retry: (_, _) => null);

class ProviderProfileTab extends ConsumerStatefulWidget {
  const ProviderProfileTab({super.key});

  @override
  ConsumerState<ProviderProfileTab> createState() => _ProviderProfileTabState();
}

class _ProviderProfileTabState extends ConsumerState<ProviderProfileTab> {
  bool _pushEnabled = false;
  bool _pushLoading = true;
  bool _pushSaving = false;
  String? _pushError;
  bool _coverUploading = false;
  bool _galleryUploading = false;
  bool _statusSaving = false;

  static const _acceptedImageExt = ['jpg', 'jpeg', 'png', 'webp'];
  static const _maxMediaBytes = 5 * 1024 * 1024; // 5MB, matches backend cap

  Future<void> _pickAndUploadCover() async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final ext = picked.path.split('.').last.toLowerCase();
    if (!_acceptedImageExt.contains(ext)) {
      _showSnack(
        'Yalnızca JPG, PNG veya WEBP formatı kabul edilir.',
        isError: true,
      );
      return;
    }
    final size = await File(picked.path).length();
    if (size > _maxMediaBytes) {
      _showSnack('Görsel boyutu en fazla 5 MB olabilir.', isError: true);
      return;
    }
    setState(() => _coverUploading = true);
    try {
      final api = ref.read(apiClientProvider);
      final formData = dio.FormData.fromMap({
        'cover': await dio.MultipartFile.fromFile(
          picked.path,
          filename: 'cover.$ext',
        ),
      });
      await api.post('/provider/profile/cover', data: formData);
      await ref.read(providerProfileNotifierProvider.notifier).refresh();
      _showSnack('Kapak görseli güncellendi.');
    } catch (_) {
      _showSnack('Kapak görseli yüklenemedi.', isError: true);
    } finally {
      if (mounted) setState(() => _coverUploading = false);
    }
  }

  Future<void> _removeCover() async {
    if (_coverUploading) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kapak görselini sil'),
        content: const Text(
          'Kapak görseli profilinizden kaldırılacak. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Kapak Görselini Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _coverUploading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/provider/profile/cover');
      await ref.read(providerProfileNotifierProvider.notifier).refresh();
      _showSnack('Kapak görseli kaldırıldı.');
    } catch (_) {
      _showSnack('Kaldırma işlemi başarısız oldu.', isError: true);
    } finally {
      if (mounted) setState(() => _coverUploading = false);
    }
  }

  Future<void> _pickAndUploadGalleryImage() async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final ext = picked.path.split('.').last.toLowerCase();
    if (!_acceptedImageExt.contains(ext)) {
      _showSnack(
        'Yalnızca JPG, PNG veya WEBP formatı kabul edilir.',
        isError: true,
      );
      return;
    }
    final size = await File(picked.path).length();
    if (size > _maxMediaBytes) {
      _showSnack('Görsel boyutu en fazla 5 MB olabilir.', isError: true);
      return;
    }
    setState(() => _galleryUploading = true);
    try {
      final api = ref.read(apiClientProvider);
      final formData = dio.FormData.fromMap({
        'image': await dio.MultipartFile.fromFile(
          picked.path,
          filename: 'gallery.$ext',
        ),
      });
      await api.post('/provider/profile/gallery', data: formData);
      await ref.read(providerProfileNotifierProvider.notifier).refresh();
      _showSnack('Görsel galeriye eklendi.');
    } on AppException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack('Görsel eklenemedi.', isError: true);
    } finally {
      if (mounted) setState(() => _galleryUploading = false);
    }
  }

  Future<void> _removeGalleryImage(String url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Görseli sil'),
        content: const Text(
          'Bu görsel galerinizden kaldırılacak. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Görseli Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/provider/profile/gallery', data: {'url': url});
      await ref.read(providerProfileNotifierProvider.notifier).refresh();
      _showSnack('Görsel galeriden kaldırıldı.');
    } catch (_) {
      _showSnack('Görsel kaldırılamadı.', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadPushPreference();
  }

  Future<void> _loadPushPreference() async {
    try {
      final pushService = ref.read(pushNotificationServiceProvider);
      final enabled = await pushService.getPushPreference();
      if (mounted) {
        setState(() {
          _pushEnabled = enabled;
          _pushError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _pushError = 'Bildirim tercihi yüklenemedi.');
    } finally {
      if (mounted) setState(() => _pushLoading = false);
    }
  }

  Future<void> _togglePushPreference(bool value) async {
    if (_pushLoading || _pushSaving) return;
    if (_pushError != null) {
      await _loadPushPreference();
      return;
    }
    setState(() {
      _pushSaving = true;
      _pushEnabled = value;
    });

    try {
      final pushService = ref.read(pushNotificationServiceProvider);
      final success = await pushService.updatePushPreference(value);
      if (mounted && success != value) {
        setState(() {
          _pushEnabled = !value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bildirim tercihi güncellenemedi.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pushEnabled = !value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bildirim tercihi güncellenemedi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _pushSaving = false);
    }
  }

  Future<void> _toggleOnline(bool value) async {
    if (_statusSaving) return;
    setState(() => _statusSaving = true);
    final notifier = ref.read(providerProfileNotifierProvider.notifier);
    final ok = await notifier.setOnline(value);
    if (!mounted) return;
    setState(() => _statusSaving = false);
    if (ok) {
      _showSnack(value ? 'Hizmet durumun aktif.' : 'Hizmet durumun pasif.');
    } else {
      _showSnack(
        notifier.lastOnlineError ?? 'Hizmet durumu güncellenemedi.',
        isError: true,
      );
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Çıkış Yap',
      message: 'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
      confirmText: 'Çıkış Yap',
      cancelText: 'Vazgeç',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      ref.read(authNotifierProvider.notifier).logout();
    }
  }

  void _openSecuritySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.link_rounded, color: AppTheme.primary),
              title: const Text('Google / Apple hesabı bağla'),
              onTap: () {
                Navigator.pop(ctx);
                showSocialAccountLinkSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.lock_outline_rounded,
                color: AppTheme.primary,
              ),
              title: const Text(
                'Şifre Değiştir',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                showChangePasswordSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.smartphone_rounded,
                color: AppTheme.primary,
              ),
              title: const Text(
                'Cihaz Oturumları',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SessionsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.error,
              ),
              title: const Text(
                'Hesabımı Sil',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.error,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                showDeleteAccountSheet(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _tl(double v) {
    final neg = v < 0;
    final cents = (v.abs() * 100).round();
    final lira = (cents ~/ 100).toString();
    final kurus = (cents % 100).toString().padLeft(2, '0');
    final buf = StringBuffer();
    for (var i = 0; i < lira.length; i++) {
      if (i > 0 && (lira.length - i) % 3 == 0) buf.write('.');
      buf.write(lira[i]);
    }
    return '${neg ? '-' : ''}$buf,$kurus TL';
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(providerWalletSummaryProvider);
    final walletSummary = walletAsync.value;
    final wCash = walletSummary?.cashBalance ?? 0;
    final wPending = walletSummary?.pendingBalance ?? 0;
    final wPromo = walletSummary?.promoBalance ?? 0;
    final wIban = walletSummary?.iban;
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final providerProfileAsync = ref.watch(providerProfileNotifierProvider);
    final providerProfile = providerProfileAsync.value;
    final isOnline = providerProfile?.isOnline ?? false;
    // Never fall back to an invented person: show the business name, then the
    // account name, then a neutral role label.
    final ustaName = (providerProfile?.businessName?.trim().isNotEmpty ?? false)
        ? providerProfile!.businessName!.trim()
        : (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()
        : 'Hizmet Veren';

    // Real approval / document verification state (no hardcoded "onaylandı").
    final identityStatus = providerProfile?.identityStatus ?? 'PENDING';
    final isApprovedAcct = providerProfile?.canWork ?? false;
    final approvalTitle = isApprovedAcct
        ? 'Hesabınız Onaylandı'
        : (identityStatus == 'REJECTED' ? 'Belge Reddedildi' : 'Onay Bekliyor');
    final approvalSubtitle = isApprovedAcct
        ? 'Tüm belgeleriniz kontrol edilmiş ve onaylanmıştır.'
        : (identityStatus == 'REJECTED'
              ? 'Belgeleriniz reddedildi. Lütfen yeniden yükleyin.'
              : 'Belgeleriniz inceleniyor. Onaylanınca çevrimiçi olabilirsiniz.');
    final approvalColor = isApprovedAcct
        ? AppTheme.success
        : (identityStatus == 'REJECTED' ? AppTheme.error : AppTheme.warning);
    final approvalBg = isApprovedAcct
        ? AppTheme.successLight
        : (identityStatus == 'REJECTED'
              ? AppTheme.errorLight
              : AppTheme.warningLight);
    final approvalIcon = isApprovedAcct
        ? Icons.verified_user_rounded
        : Icons.hourglass_bottom_rounded;
    // Per-item verification state, each from its own real source — the same
    // four rows the web profile shows, so both platforms agree.
    final documentsAsync = ref.watch(providerDocumentsProvider);
    final documents = documentsAsync.asData?.value ?? const [];
    String statusLabel(String? raw) => switch (raw) {
      'APPROVED' => 'Onaylandı',
      'REJECTED' => 'Reddedildi',
      'REUPLOAD_REQUIRED' => 'Yeniden Yükleyin',
      null => 'Yüklenmedi',
      _ => 'İnceleniyor',
    };
    const docTypeLabels = {
      'DIPLOMA': 'Diploma',
      'MASTER_CERTIFICATE': 'Ustalık Belgesi',
      'JOURNEYMAN_CERTIFICATE': 'Kalfalık Belgesi',
    };
    final professionalDoc = documents.isEmpty ? null : documents.first;
    final hasIban = (wIban ?? '').trim().isNotEmpty && wIban != '-';
    final hasAddress =
        (providerProfile?.city ?? '').trim().isNotEmpty &&
        (providerProfile?.district ?? '').trim().isNotEmpty;

    final jobStatsAsync = ref.watch(providerJobStatsProvider);
    final jobStats = jobStatsAsync.asData?.value ?? (completed: 0, upcoming: 0);
    final serviceRadiusKm = providerProfile?.serviceRadiusKm ?? 10;
    final locationLine = () {
      final parts = [
        providerProfile?.city,
        providerProfile?.district,
      ].map((v) => v?.trim() ?? '').where((v) => v.isNotEmpty).toList();
      return parts.isEmpty ? null : parts.join(', ');
    }();

    final verificationRows = <(String, String)>[
      (
        'Kimlik Doğrulama',
        switch (identityStatus) {
          'APPROVED' => 'Onaylandı',
          'REJECTED' => 'Reddedildi',
          _ => 'İnceleniyor',
        },
      ),
      (
        docTypeLabels[professionalDoc?['document_type']?.toString()] ??
            'Mesleki Belge',
        statusLabel(professionalDoc?['status']?.toString()),
      ),
      ('IBAN Bilgisi', hasIban ? 'Onaylandı' : 'Eksik'),
      ('Adres Bilgisi', hasAddress ? 'Onaylandı' : 'Eksik'),
    ];

    final reviewAsync = ref.watch(providerReviewSummaryProvider);
    final reviewSummary = reviewAsync.value;
    final reviewCount = (reviewSummary?['count'] as num?)?.toInt() ?? 0;
    final reviewAvg = (reviewSummary?['average'] as num?)?.toDouble() ?? 0.0;
    final ratingValue = reviewCount > 0 ? reviewAvg.toStringAsFixed(1) : 'Yeni';
    final ratingSub = reviewCount > 0
        ? '$reviewCount değerlendirme'
        : 'Henüz yorum yok';

    final resources = <AsyncValue<dynamic>>[
      providerProfileAsync,
      walletAsync,
      documentsAsync,
      jobStatsAsync,
      reviewAsync,
    ];
    if (resources.any((value) => value.hasError)) {
      return Scaffold(
        body: SafeArea(
          child: ErrorState(
            message: 'Profil verileri yüklenemedi. Bağlantınızı kontrol edin.',
            onRetry: () {
              ref.invalidate(providerProfileNotifierProvider);
              ref.invalidate(providerWalletSummaryProvider);
              ref.invalidate(providerDocumentsProvider);
              ref.invalidate(providerJobStatsProvider);
              ref.invalidate(providerReviewSummaryProvider);
            },
          ),
        ),
      );
    }
    if (resources.any((value) => value.isLoading && !value.hasValue)) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header (Matching Image 2) ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profilim',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Hesabını yönet, bilgilerini güncelle.',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.slate200),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: AppTheme.slate700,
                        size: 22,
                      ),
                      onPressed: () => showProfileEditSheet(
                        context,
                        title: 'İşletme Bilgileri',
                        endpoint: '/provider/profile',
                        fields: [
                          ProfileEditField(
                            key: 'business_name',
                            label: 'İşletme Adı',
                            initial: providerProfile?.businessName ?? ustaName,
                          ),
                          ProfileEditField(
                            key: 'city',
                            label: 'Şehir',
                            initial: providerProfile?.city ?? '',
                            kind: ProfileEditKind.province,
                          ),
                          ProfileEditField(
                            key: 'district',
                            label: 'İlçe',
                            initial: providerProfile?.district ?? '',
                            kind: ProfileEditKind.district,
                          ),
                          ProfileEditField(
                            key: 'service_radius_km',
                            label: 'Hizmet Yarıçapı (km)',
                            initial:
                                '${providerProfile?.serviceRadiusKm ?? 15}',
                            keyboardType: TextInputType.number,
                            maxLength: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Top Provider Card (Matching Image 2) ───────────────────────
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Real avatar (upload/remove) with online-status dot.
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AvatarPicker(
                              avatarUrl: user?.avatarUrl,
                              name: ustaName,
                              radius: 36,
                            ),
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? AppTheme.success
                                      : AppTheme.slate400,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 14),

                        // Name, Badge & Status Toggle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              ustaName,
                                              style: const TextStyle(
                                                fontFamily: AppTheme.fontFamily,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (providerProfile?.isVerified == true) ...[
                                            const SizedBox(width: 6),
                                            const VerifiedTick(size: 18),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Provider Role Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryLight,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Text(
                                          'Hizmet Veren • Usta',
                                          style: TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Service Status Toggle
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Hizmet Durumu',
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            isOnline ? 'Aktif' : 'Pasif',
                                            style: TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isOnline
                                                  ? AppTheme.success
                                                  : AppTheme.slate500,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Transform.scale(
                                            scale: 0.75,
                                            child: Switch.adaptive(
                                              value: isOnline,
                                              activeColor: AppTheme.success,
                                              onChanged: _statusSaving
                                                  ? null
                                                  : _toggleOnline,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        isOnline
                                            ? 'Yeni randevu alabilirsin'
                                            : 'Randevu alımı kapalı',
                                        style: const TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: 10,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              const Text(
                                '"Profesyonel bakım, mutlu insanlar"',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppTheme.slate100),
                    const SizedBox(height: 10),

                    // Location & coverage — both read from the saved business
                    // profile; the location is hidden when it isn't set yet.
                    Row(
                      children: [
                        if (locationLine != null) ...[
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppTheme.slate400,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              locationLine,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                color: AppTheme.slate600,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '|',
                            style: TextStyle(color: AppTheme.slate300),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppTheme.slate400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$serviceRadiusKm km hizmet alanı',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: AppTheme.slate600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (providerProfile != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            final saved = await showModalBottomSheet<bool>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => ProviderLocationSheet(profile: providerProfile),
                            );
                            if (saved == true) ref.invalidate(providerProfileNotifierProvider);
                          },
                          icon: const Icon(Icons.edit_location_alt_outlined, size: 17),
                          label: const Text('İşletme konumunu düzenle'),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── 4-Item Provider Stats Bar (Matching Image 2) ───────────────
              AppCard(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 10,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildStatCol(
                          icon: Icons.star_rounded,
                          tarak: true,
                          iconColor: AppTheme.warning,
                          value: ratingValue,
                          label: 'Tarak Puanı',
                          sublabel: ratingSub,
                        ),
                        _buildDivider(),
                        _buildStatCol(
                          icon: Icons.work_outline_rounded,
                          iconColor: const Color(0xFFE11D48),
                          value: '${jobStats.completed}',
                          label: 'Tamamlanan İş',
                          sublabel: 'Başarılı randevu',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatCol(
                          icon: Icons.event_available_rounded,
                          iconColor: AppTheme.primary,
                          value: '${jobStats.upcoming}',
                          label: 'Yaklaşan Randevu',
                          sublabel: 'Onaylı ve bekleyen',
                        ),
                        _buildDivider(),
                        _buildStatCol(
                          icon: Icons.location_on_outlined,
                          iconColor: const Color(0xFFDC2626),
                          value:
                              '${providerProfileAsync.value?.serviceRadiusKm ?? 15} km',
                          label: 'Hizmet Alanı',
                          sublabel: [
                            providerProfileAsync.value?.district,
                            've çevresi',
                          ].where((e) => e != null && e != '').join(' '),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Hesap Onay Durumu Card (Matching Image 2) ──────────────────
              AppCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProviderDocumentsScreen(),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: approvalBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(approvalIcon, color: approvalColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hesap Onay Durumu',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            approvalSubtitle,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: approvalBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              approvalTitle,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: approvalColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.slate400,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── 2-Column Grid (Row 1: Schedule & Services) ─────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildGridModuleCard(
                    icon: Icons.calendar_month_outlined,
                    iconColor: AppTheme.primary,
                    title: 'Çalışma Takvimi ve Saatleri',
                    description:
                        'Haftalık müsaitlik, mola ve tatil günlerini düzenle',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProviderScheduleScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildGridModuleCard(
                    icon: Icons.content_cut_rounded,
                    iconColor: AppTheme.primary,
                    title: 'Hizmetlerim',
                    description: 'Verdiğin hizmetleri görüntüle ve düzenle',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProviderOfferingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── 2-Column Grid (Row 2: Wallet & Documents) ──────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cüzdan ve Hakediş Card
                  AppCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProviderWalletScreen(),
                      ),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_outlined,
                                color: AppTheme.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Cüzdan ve Hakediş',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _tl(wCash),
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Detaylar',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppTheme.slate400,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppTheme.slate100),
                        const SizedBox(height: 8),
                        _buildWalletRow(
                          Icons.access_time_rounded,
                          'Bekleyen Hakediş',
                          _tl(wPending),
                        ),
                        const SizedBox(height: 4),
                        _buildWalletRow(
                          Icons.card_giftcard_rounded,
                          'Promosyon Bakiyesi',
                          _tl(wPromo),
                        ),
                        const SizedBox(height: 4),
                        _buildWalletRow(
                          Icons.credit_card_outlined,
                          'IBAN',
                          wIban != null && wIban.length >= 4
                              ? 'TR** **** ${wIban.substring(wIban.length - 4)}'
                              : 'Tanımlı değil',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Belgeler ve Doğrulama Card
                  AppCard(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProviderDocumentsScreen(),
                      ),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.description_outlined,
                                color: AppTheme.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Belgeler ve Doğrulama',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppTheme.slate400,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppTheme.slate100),
                        const SizedBox(height: 10),
                        for (final row in verificationRows) ...[
                          _buildDocRow(row.$1, row.$2),
                          if (row != verificationRows.last)
                            const SizedBox(height: 6),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── İşletme Vitrini: Kapak Görseli ──────────────────────────────
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Text(
                        'Kapak Görseli',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Stack(
                      children: [
                        Container(
                          height: 120,
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: AppTheme.slate100,
                            image:
                                (providerProfile?.coverUrl != null &&
                                    providerProfile!.coverUrl!.isNotEmpty)
                                ? DecorationImage(
                                    image: NetworkImage(
                                      providerProfile.coverUrl!,
                                    ),
                                    fit: BoxFit.cover,
                                    alignment: const Alignment(0, -0.4),
                                  )
                                : null,
                          ),
                          child:
                              (providerProfile?.coverUrl == null ||
                                  providerProfile!.coverUrl!.isEmpty)
                              ? const Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: AppTheme.slate400,
                                    size: 28,
                                  ),
                                )
                              : null,
                        ),
                        if (_coverUploading)
                          Positioned.fill(
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: Colors.black38,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 8,
                          right: 22,
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _coverUploading
                                    ? null
                                    : _pickAndUploadCover,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (providerProfile?.coverUrl != null &&
                                  providerProfile!.coverUrl!.isNotEmpty &&
                                  !_coverUploading) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _removeCover,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: const BoxDecoration(
                                      color: Colors.black45,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── İşletme Vitrini: Galeri ──────────────────────────────────────
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Galeri',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${providerProfile?.gallery.length ?? 0}/12',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.slate400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount:
                          (providerProfile?.gallery.length ?? 0) +
                          ((providerProfile?.gallery.length ?? 0) < 12 ? 1 : 0),
                      itemBuilder: (context, index) {
                        final gallery = providerProfile?.gallery ?? [];
                        if (index == gallery.length) {
                          return GestureDetector(
                            onTap: _galleryUploading
                                ? null
                                : _pickAndUploadGalleryImage,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.slate200,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: _galleryUploading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.add_photo_alternate_outlined,
                                        color: AppTheme.slate400,
                                        size: 22,
                                      ),
                              ),
                            ),
                          );
                        }
                        final url = gallery[index];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                url,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 3,
                              right: 3,
                              child: GestureDetector(
                                onTap: () => _removeGalleryImage(url),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _buildGridModuleCard(
                icon: Icons.notifications_active_outlined,
                iconColor: AppTheme.primary,
                title: 'Bildirimler',
                description: 'Randevu, talep ve mesaj bildirimlerini görüntüle',
                onTap: () => openNotificationCenter(context, ref),
              ),
              const SizedBox(height: 12),

              // İşletme bilgileri: same header row as every module, details underneath.
              AppCard(
                onTap: () => showProfileEditSheet(
                  context,
                  title: 'İşletme Bilgileri',
                  endpoint: '/provider/profile',
                  fields: [
                    ProfileEditField(
                      key: 'business_name',
                      label: 'İşletme Adı',
                      initial: providerProfile?.businessName ?? ustaName,
                    ),
                    ProfileEditField(
                      key: 'city',
                      label: 'Şehir',
                      initial: providerProfile?.city ?? '',
                      kind: ProfileEditKind.province,
                    ),
                    ProfileEditField(
                      key: 'district',
                      label: 'İlçe',
                      initial: providerProfile?.district ?? '',
                      kind: ProfileEditKind.district,
                    ),
                    ProfileEditField(
                      key: 'service_radius_km',
                      label: 'Hizmet Yarıçapı (km)',
                      initial: '${providerProfile?.serviceRadiusKm ?? 15}',
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.storefront_outlined,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'İşletme Bilgileri',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppTheme.slate400,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppTheme.slate100),
                    const SizedBox(height: 8),
                    _buildWalletRow(
                      Icons.storefront_outlined,
                      'İşletme',
                      providerProfile?.businessName ?? ustaName,
                    ),
                    const SizedBox(height: 4),
                    _buildWalletRow(
                      Icons.location_on_outlined,
                      'Hizmet Bölgesi',
                      locationLine ?? 'Belirtilmedi',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              _buildGridModuleCard(
                icon: Icons.notifications_none_rounded,
                iconColor: AppTheme.primary,
                title: 'Bildirim Tercihleri',
                description:
                    _pushError ??
                    (_pushLoading
                        ? 'Yükleniyor…'
                        : _pushSaving
                        ? 'Kaydediliyor…'
                        : _pushEnabled
                        ? 'Push bildirimleri açık'
                        : 'Push bildirimleri kapalı'),
                trailing: _pushError != null
                    ? IconButton(
                        tooltip: 'Tekrar Dene',
                        onPressed: _loadPushPreference,
                        icon: const Icon(Icons.refresh),
                      )
                    : (_pushLoading || _pushSaving)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch.adaptive(
                        value: _pushEnabled,
                        activeColor: AppTheme.primary,
                        onChanged: _togglePushPreference,
                      ),
                onTap: () {
                  if (_pushError != null) {
                    _loadPushPreference();
                  } else {
                    _togglePushPreference(!_pushEnabled);
                  }
                },
              ),
              const SizedBox(height: 12),

              const AppIconCard(),

              _buildGridModuleCard(
                icon: Icons.shield_outlined,
                iconColor: AppTheme.primary,
                title: 'Güvenlik',
                description:
                    'Şifre değiştir, oturumları yönet ve hesabını koru',
                onTap: _openSecuritySheet,
              ),
              const SizedBox(height: 12),

              _buildGridModuleCard(
                icon: Icons.headset_mic_outlined,
                iconColor: AppTheme.primary,
                title: 'Destek Merkezi',
                description:
                    'Yardım, sık sorulan sorular ve bizimle iletişime geç',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SupportScreen()),
                ),
              ),
              const SizedBox(height: 12),

              _buildGridModuleCard(
                icon: Icons.gavel_rounded,
                iconColor: AppTheme.primary,
                title: 'Yasal & Sözleşmeler',
                description:
                    'Gizlilik, KVKK, kullanım koşulları ve çerez politikası',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LegalScreen()),
                ),
              ),

              const SizedBox(height: 16),

              // ── Logout Button (Matching Image 2) ───────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text(
                    'Çıkış Yap',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCol({
    required IconData icon,
    bool tarak = false,
    required Color iconColor,
    required String value,
    required String label,
    required String sublabel,
  }) {
    return Expanded(
      child: Column(
        children: [
          tarak
              ? const TarakMark(size: 26)
              : Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            sublabel,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 36,
      color: AppTheme.slate100,
      margin: const EdgeInsets.symmetric(horizontal: 2),
    );
  }

  /// Full-width module row: icon, title + description, chevron (or a trailing control).
  Widget _buildGridModuleCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ??
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.slate400,
              ),
        ],
      ),
    );
  }

  Widget _buildWalletRow(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppTheme.slate400),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocRow(String title, String status) {
    final approved = status == 'Onaylandı';
    final rejected = status == 'Reddedildi';
    final statusColor = approved
        ? AppTheme.success
        : (rejected ? AppTheme.error : AppTheme.warning);
    final statusIcon = approved
        ? Icons.check_circle_rounded
        : (rejected ? Icons.cancel_rounded : Icons.hourglass_bottom_rounded);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(statusIcon, size: 14, color: statusColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 18, top: 2),
          child: Text(
            status,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }
}
