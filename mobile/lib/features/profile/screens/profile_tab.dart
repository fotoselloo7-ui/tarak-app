import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../provider/appointments/screens/provider_schedule_screen.dart';
import '../../provider/instant/providers/provider_instant_providers.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../core/widgets/verified_tick.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  bool _pushEnabled = true;
  bool _isLoadingPreference = true;

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
          _isLoadingPreference = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPreference = false;
        });
      }
    }
  }

  Future<void> _togglePushPreference(bool value) async {
    setState(() {
      _pushEnabled = value;
    });

    try {
      final pushService = ref.read(pushNotificationServiceProvider);
      final result = await pushService.updatePushPreference(value);
      if (mounted) setState(() => _pushEnabled = result);
    } catch (_) {
      if (mounted) {
        setState(() => _pushEnabled = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bildirim tercihi güncellenemedi.')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final providerProfile = user?.isProvider == true
        ? ref.watch(providerProfileNotifierProvider).value
        : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Profil'),
        automaticallyImplyLeading: false,
      ),
      body: user == null
          ? const Center(
              child: Text(
                'Kullanıcı oturumu bulunamadı.',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.slate500,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // User Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppTheme.radiusCard,
                    border: Border.all(color: AppTheme.slate200),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Row(
                    children: [
                      AppAvatar(
                        name: user.name,
                        radius: 30,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProviderNameRow(
                              name: user.name,
                              verified: user.isProvider && providerProfile?.isVerified == true,
                              tickSize: 18,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: user.isCustomer
                                    ? AppTheme.slate100
                                    : AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user.isCustomer
                                    ? 'Müşteri'
                                    : 'Hizmet Veren (Usta)',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: user.isCustomer
                                      ? AppTheme.slate700
                                      : AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Provider-specific shortcut items
                if (user.isProvider) ...[
                  const SectionHeader(title: 'Hizmet Yönetimi'),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.radiusCard,
                      border: Border.all(color: AppTheme.slate200),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: AppTheme.radiusCard,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.schedule_rounded,
                              color: AppTheme.primary,
                            ),
                            title: const Text(
                              'Çalışma Takvimi ve Saatleri',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            subtitle: const Text(
                              'Haftalık müsaitlik, mola ve tatil günlerini düzenle',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.slate400,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ProviderScheduleScreen(),
                                ),
                              );
                            },
                          ),
                          if (providerProfile != null) ...[
                            const Divider(height: 1),
                            ListTile(
                              leading: Icon(
                                providerProfile.canWork
                                    ? Icons.verified_user_rounded
                                    : Icons.hourglass_top_rounded,
                                color: providerProfile.canWork
                                    ? AppTheme.success
                                    : AppTheme.warning,
                              ),
                              title: const Text(
                                'Hesap Onay Durumu',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              trailing: StatusBadge(
                                status: providerProfile.canWork
                                    ? 'CONFIRMED'
                                    : 'PENDING',
                                customLabel: providerProfile.canWork
                                    ? 'Onaylı Hesap'
                                    : 'Onay Bekliyor',
                                isSmall: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Contact Details Section
                const SectionHeader(title: 'Hesap Bilgileri'),
                const SizedBox(height: 4),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppTheme.radiusCard,
                    border: Border.all(color: AppTheme.slate200),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: AppTheme.radiusCard,
                    child: Column(
                      children: [
                        if (user.email != null && user.email!.isNotEmpty)
                          ListTile(
                            leading: const Icon(
                              Icons.email_outlined,
                              color: AppTheme.slate500,
                              size: 20,
                            ),
                            title: const Text(
                              'E-posta',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            subtitle: Text(
                              user.email!,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        if (user.email != null &&
                            user.email!.isNotEmpty &&
                            user.phone != null &&
                            user.phone!.isNotEmpty)
                          const Divider(height: 1),
                        if (user.phone != null && user.phone!.isNotEmpty)
                          ListTile(
                            leading: const Icon(
                              Icons.phone_outlined,
                              color: AppTheme.slate500,
                              size: 20,
                            ),
                            title: const Text(
                              'Telefon',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            subtitle: Text(
                              user.phone!,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Settings Section
                const SectionHeader(title: 'Ayarlar'),
                const SizedBox(height: 4),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppTheme.radiusCard,
                    border: Border.all(color: AppTheme.slate200),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: AppTheme.radiusCard,
                    child: SwitchListTile(
                      title: const Text(
                        'Push Bildirimleri',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: const Text(
                        'Hizmet, randevu ve mesaj bildirimlerini anında al',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      value: _pushEnabled,
                      activeTrackColor: AppTheme.primary,
                      activeThumbColor: Colors.white,
                      onChanged: _isLoadingPreference
                          ? null
                          : _togglePushPreference,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Logout Button
                OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: AppTheme.error,
                    size: 20,
                  ),
                  label: const Text(
                    'Çıkış Yap',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppTheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.radiusButton,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
