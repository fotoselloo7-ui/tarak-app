import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/web_landing_widgets.dart' show trUpper;
import '../../notifications/screens/notification_center_screen.dart';
import '../../shared/screens/legal_screen.dart';
import '../../shared/screens/sessions_screen.dart';
import '../../shared/screens/support_screen.dart';
import '../../shared/widgets/account_sheets.dart';
import '../../shared/widgets/social_account_link_sheet.dart';
import '../../shared/widgets/common_widgets.dart';
import 'customer_profile_edit_screen.dart';

/// The customer's settings page (web: Ayarlar): account summary, notification preferences,
/// security & privacy and legal texts. The profile tab itself only keeps the overview.
class CustomerSettingsScreen extends ConsumerStatefulWidget {
  const CustomerSettingsScreen({super.key});

  @override
  ConsumerState<CustomerSettingsScreen> createState() => _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState extends ConsumerState<CustomerSettingsScreen> {
  bool _pushEnabled = true;
  bool _campaignEnabled = true;
  bool _loadingPreference = true;
  bool _savingPreference = false;
  String? _preferenceError;

  @override
  void initState() {
    super.initState();
    _loadPushPreference();
  }

  Future<void> _loadPushPreference() async {
    setState(() {
      _loadingPreference = true;
      _preferenceError = null;
    });
    try {
      final prefs = await ref.read(pushNotificationServiceProvider).getNotificationPreferences();
      if (mounted) setState(() { _pushEnabled = prefs.push; _campaignEnabled = prefs.campaign; _loadingPreference = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingPreference = false; _preferenceError = 'Bildirim tercihi yüklenemedi.'; });
    }
  }

  Future<void> _togglePush(bool value) async {
    if (_savingPreference || _loadingPreference || _preferenceError != null) return;
    setState(() { _savingPreference = true; _pushEnabled = value; });
    try {
      final saved = await ref.read(pushNotificationServiceProvider).updatePushPreference(value);
      if (mounted && saved != value) {
        setState(() => _pushEnabled = !value);
        _snack('Bildirim tercihi güncellenemedi.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pushEnabled = !value);
        _snack('Bildirim tercihi güncellenemedi.');
      }
    } finally {
      if (mounted) setState(() => _savingPreference = false);
    }
  }

  Future<void> _toggleCampaign(bool value) async {
    if (_savingPreference || _loadingPreference || _preferenceError != null) return;
    setState(() { _savingPreference = true; _campaignEnabled = value; });
    try {
      final saved = await ref.read(pushNotificationServiceProvider).updateCampaignPreference(value);
      if (mounted && saved != value) {
        setState(() => _campaignEnabled = !value);
        _snack('Bildirim tercihi güncellenemedi.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _campaignEnabled = !value);
        _snack('Bildirim tercihi güncellenemedi.');
      }
    } finally {
      if (mounted) setState(() => _savingPreference = false);
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _push(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  static const _text = TextStyle(fontFamily: AppTheme.fontFamily);

  Widget _group(String title, List<Widget> rows) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(trUpper(title),
                  style: _text.copyWith(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppTheme.slate400)),
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 60, color: AppTheme.slate100),
                    rows[i],
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  Widget _row({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    Color color = AppTheme.primary,
    Color tint = AppTheme.primaryLight,
    bool danger = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: danger ? AppTheme.errorLight : tint, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 19, color: danger ? AppTheme.error : color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _text.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: danger ? AppTheme.error : AppTheme.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: _text.copyWith(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.3)),
                  ],
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.slate400),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final name = (user?.name.trim().isNotEmpty ?? false) ? user!.name.trim() : 'Müşteri';
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        title: const Text('Ayarlar', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: Text('Hesap bilgilerini, bildirim tercihlerini, güvenliğini ve gizlilik ayarlarını buradan yönet.',
                style: _text.copyWith(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4)),
          ),
          _group('Hesap', [
            _row(
              icon: Icons.person_outline_rounded,
              title: name,
              subtitle: email.isEmpty ? 'Profilini düzenle' : '$email • Profilini düzenle',
              onTap: () => _push(const CustomerProfileEditScreen()),
            ),
          ]),
          _group('Bildirimler', [
            _row(
              icon: Icons.notifications_none_rounded,
              title: 'Push bildirimleri',
              subtitle: _preferenceError ?? 'Randevu, talep ve mesaj bildirimleri',
              onTap: _preferenceError != null ? _loadPushPreference : () => _togglePush(!_pushEnabled),
              trailing: _preferenceError != null
                  ? const Icon(Icons.refresh_rounded, size: 20, color: AppTheme.slate500)
                  : _loadingPreference || _savingPreference
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Switch.adaptive(value: _pushEnabled, activeThumbColor: AppTheme.primary, onChanged: _togglePush),
            ),
            _row(
              icon: Icons.local_offer_outlined,
              title: 'Kampanya bildirimleri',
              subtitle: 'Hizmet verenlerin indirim ve kampanya bildirimleri',
              onTap: _preferenceError != null ? _loadPushPreference : () => _toggleCampaign(!_campaignEnabled),
              trailing: _preferenceError != null
                  ? const Icon(Icons.refresh_rounded, size: 20, color: AppTheme.slate500)
                  : _loadingPreference || _savingPreference
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Switch.adaptive(key: const Key('campaign_switch'), value: _campaignEnabled, activeThumbColor: AppTheme.primary, onChanged: _toggleCampaign),
            ),
            _row(
              icon: Icons.notifications_active_outlined,
              title: 'Bildirim merkezi',
              subtitle: 'Randevu, talep ve mesaj bildirimlerini görüntüle',
              onTap: () => openNotificationCenter(context, ref),
            ),
          ]),
          _group('Güvenlik', [
            _row(
              icon: Icons.link_rounded,
              title: 'Google / Apple hesabı bağla',
              subtitle: 'Sağlayıcınızı şifrenizle onaylayarak bağlayın',
              onTap: () => showSocialAccountLinkSheet(context),
            ),
            _row(
              icon: Icons.lock_outline_rounded,
              title: 'Şifre değiştir',
              subtitle: 'Hesap güvenliğini artır',
              color: AppTheme.info,
              tint: AppTheme.infoLight,
              onTap: () => showChangePasswordSheet(context),
            ),
            _row(
              icon: Icons.smartphone_rounded,
              title: 'Cihaz oturumları',
              subtitle: 'Aktif oturumları görüntüle ve kapat',
              color: AppTheme.info,
              tint: AppTheme.infoLight,
              onTap: () => _push(const SessionsScreen()),
            ),
          ]),
          _group('Gizlilik ve yardım', [
            _row(
              icon: Icons.privacy_tip_outlined,
              title: 'Kişisel veri tercihleri',
              subtitle: 'Kişisel verilerin için destek talebi gönder',
              color: AppTheme.success,
              tint: AppTheme.successLight,
              onTap: () => _push(const SupportScreen()),
            ),
            _row(
              icon: Icons.gavel_rounded,
              title: 'Yasal ve sözleşmeler',
              subtitle: 'Gizlilik, KVKK, kullanım koşulları ve çerez politikası',
              color: AppTheme.success,
              tint: AppTheme.successLight,
              onTap: () => _push(const LegalScreen()),
            ),
            _row(
              icon: Icons.headset_mic_outlined,
              title: 'Destek merkezi',
              subtitle: 'Yardım, sık sorulan sorular ve iletişim',
              color: AppTheme.success,
              tint: AppTheme.successLight,
              onTap: () => _push(const SupportScreen()),
            ),
          ]),
          _group('Hesap silme', [
            _row(
              icon: Icons.delete_outline_rounded,
              title: 'Hesabımı sil',
              subtitle: 'Hesap ve tüm verilerini kalıcı olarak sil',
              danger: true,
              onTap: () => showDeleteAccountSheet(context),
            ),
          ]),
        ],
      ),
    );
  }
}
