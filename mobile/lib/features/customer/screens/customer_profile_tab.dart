import '../../notifications/screens/notification_center_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/avatar_picker.dart';
import '../../shared/screens/support_screen.dart';
import '../screens/payment_history_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/my_reviews_screen.dart';
import '../screens/my_addresses_screen.dart';
import '../providers/customer_profile_stats_provider.dart';
import 'customer_profile_edit_screen.dart';
import 'customer_settings_screen.dart';
import '../../shared/widgets/app_icon_card.dart';

class CustomerProfileTab extends ConsumerStatefulWidget {
  const CustomerProfileTab({super.key});

  @override
  ConsumerState<CustomerProfileTab> createState() => _CustomerProfileTabState();
}

class _CustomerProfileTabState extends ConsumerState<CustomerProfileTab> {
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

  void _openProfileEdit() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerProfileEditScreen()),
      );

  void _openSettings() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerSettingsScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    // No invented person as a fallback — use the account name or a neutral label.
    final userName = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()
        : 'Müşteri';
    // Real counters from the customer's own records — never placeholder zeros.
    final statsAsync = ref.watch(customerProfileStatsProvider);
    final stats = statsAsync.asData?.value ?? CustomerProfileStats.empty;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header (Matching Image 4) ──────────────────────────────────
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
                          fontSize: 22,
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
                      tooltip: 'Ayarlar',
                      onPressed: _openSettings,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Top Profile Card (Matching Image 4) ────────────────────────
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Real avatar — upload/remove via gallery picker.
                        AvatarPicker(
                          avatarUrl: user?.avatarUrl,
                          name: userName,
                          radius: 36,
                        ),

                        const SizedBox(width: 14),

                        // Name, Badge & Edit Action
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          userName,
                                          style: const TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.verified,
                                        color: AppTheme.info,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: _openProfileEdit,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minHeight: 44,
                                      ),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.slate100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.edit_outlined,
                                            size: 13,
                                            color: AppTheme.slate700,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Profili Düzenle',
                                            style: TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.slate700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              // Customer Role Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Müşteri',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 6),

                              const Text(
                                '"Güzel bir gün, güzel bir bakım ile başlar."',
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

                    // Location (default saved address) & tagline. The location
                    // is shown only when the customer actually has an address.
                    Row(
                      children: [
                        if (stats.defaultAddressLine != null) ...[
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppTheme.slate400,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              stats.defaultAddressLine!,
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
                          Icons.favorite_border_rounded,
                          size: 14,
                          color: AppTheme.slate400,
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Tarak ile daha güzel',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              color: AppTheme.slate600,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── 4-Item Customer Stats Bar (Matching Image 4) ───────────────
              if (statsAsync.isLoading && !statsAsync.hasValue)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (statsAsync.hasError)
                AppCard(
                  child: Column(
                    children: [
                      const Text('Profil istatistikleri yüklenemedi.'),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(customerProfileStatsProvider),
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                )
              else
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
                            icon: Icons.description_outlined,
                            iconColor: AppTheme.primary,
                            value: '${stats.activeRequests}',
                            label: 'Aktif Talep',
                            sublabel: 'Devam ediyor',
                          ),
                          _buildDivider(),
                          _buildStatCol(
                            icon: Icons.calendar_today_outlined,
                            iconColor: AppTheme.warning,
                            value: '${stats.upcomingAppointments}',
                            label: 'Yaklaşan Randevu',
                            sublabel: 'Bu hafta',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStatCol(
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: AppTheme.success,
                            value: '${stats.completedServices}',
                            label: 'Tamamlanan',
                            sublabel: 'Hizmet (Toplam)',
                          ),
                          _buildDivider(),
                          _buildStatCol(
                            icon: Icons.location_on_outlined,
                            iconColor: AppTheme.info,
                            value: '${stats.savedAddresses}',
                            label: 'Kayıtlı Adres',
                            sublabel: 'Ev ve iş adresi',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // ── 2-Column Grid Modules (Matching Image 4) ───────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildGridModuleCard(
                    icon: Icons.person_outline_rounded,
                    iconColor: AppTheme.primary,
                    title: 'Kişisel Bilgiler',
                    description: 'Ad, soyad, cinsiyet, doğum tarihi ve adresini düzenle',
                    onTap: _openProfileEdit,
                  ),
                  const SizedBox(height: 12),
                  _buildGridModuleCard(
                    icon: Icons.home_outlined,
                    iconColor: AppTheme.primary,
                    title: 'Kayıtlı Adresler',
                    description: 'Ev, iş ve diğer adreslerini yönet',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyAddressesScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildGridModuleCard(
                    icon: Icons.credit_card_outlined,
                    iconColor: AppTheme.primary,
                    title: 'Ödemelerim',
                    description:
                        'Ödeme geçmişini ve işlem durumlarını görüntüle',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PaymentHistoryScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildGridModuleCard(
                    icon: Icons.favorite_border_rounded,
                    iconColor: AppTheme.primary,
                    title: 'Favori Ustalar',
                    description: 'Beğendiğin ustaları görüntüle ve yönet',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FavoritesScreen(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildGridModuleCard(
                    icon: Icons.rate_review_outlined,
                    iconColor: AppTheme.primary,
                    title: 'Değerlendirmelerim',
                    description: 'Yazdığın değerlendirmeleri görüntüle',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyReviewsScreen(),
                      ),
                    ),
                  ),
                ],
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

              _buildGridModuleCard(
                icon: Icons.settings_outlined,
                iconColor: AppTheme.primary,
                title: 'Ayarlar',
                description: 'Bildirim tercihleri, güvenlik, gizlilik ve hesap',
                onTap: _openSettings,
              ),
              const SizedBox(height: 12),

              const AppIconCard(),

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
              const SizedBox(height: 16),

              // ── Logout Button (Matching Image 4) ───────────────────────────
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
    required Color iconColor,
    required String value,
    required String label,
    required String sublabel,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
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
                  maxLines: 1,
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
}
