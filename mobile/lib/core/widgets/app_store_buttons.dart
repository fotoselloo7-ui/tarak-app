import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../content/home_copy.dart';

/// Shared with the website: each badge uses its own admin-configured HTTPS URL.
class AppStoreButtons extends StatelessWidget {
  const AppStoreButtons({super.key, this.appStoreUrl, this.playStoreUrl});

  final String? appStoreUrl;
  final String? playStoreUrl;

  Uri? _storeUri(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri
        : null;
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Keep failed external launches recoverable without leaving the home.
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bağlantı açılamadı. Tekrar deneyin.')),
      );
    }
  }

  Widget _badge(
    BuildContext context,
    String name,
    IconData icon,
    String? value,
    String key,
  ) {
    final uri = _storeUri(value);
    return Semantics(
      label: uri == null ? '$name (yakında)' : '$name uygulamasını indir',
      child: ElevatedButton(
        key: ValueKey(key),
        onPressed: uri == null ? null : () => _open(context, uri),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.darkNavy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.darkNavy,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    uri == null ? 'Çok yakında' : 'Şimdi indirin',
                    style: const TextStyle(
                      fontSize: 8,
                      color: Color(0xFFCBD5E1),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final apple = _badge(
        context,
        'App Store',
        Icons.apple,
        appStoreUrl,
        'app-store-badge',
      );
      final google = _badge(
        context,
        'Google Play',
        Icons.play_arrow_rounded,
        playStoreUrl,
        'play-store-badge',
      );
      // Side by side when both fit, otherwise stacked; the two badges always share one size.
      if (box.maxWidth < 232) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [apple, const SizedBox(height: 8), google],
        );
      }
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 264),
          child: Row(
            children: [
              Expanded(child: apple),
              const SizedBox(width: 8),
              Expanded(child: google),
            ],
          ),
        ),
      );
    },
  );
}

class AppDownloadSection extends StatelessWidget {
  const AppDownloadSection({super.key, required this.siteConfig});
  final Map<String, dynamic> siteConfig;

  @override
  Widget build(BuildContext context) {
    final home = siteConfig['home'];
    final content = home is Map && home['app_download'] is Map
        ? home['app_download'] as Map
        : const {};
    final config = siteConfig['config'] is Map
        ? siteConfig['config'] as Map
        : const {};
    String copy(String key, String fallback) =>
        homeCopy(content[key], fallback);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5F8FF), Color(0xFFFFEFE6)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1E6DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            homeLabel(copy('eyebrow', 'Tarak Mobil')),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1D4ED8),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${copy('title', 'Tarak')} '),
                TextSpan(
                  text: copy('title_highlight', 'Cebinde!'),
                  style: const TextStyle(color: AppTheme.primary),
                ),
              ],
            ),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.darkNavy,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            copy(
              'subtitle',
              'Hizmetleri keşfet, randevularını yönet, bildirimlerini takip et ve hizmet vereninle iletişimde kal.',
            ),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12.5,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          for (final benefit in homeAppBenefits)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      benefit,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkNavy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          AppStoreButtons(
            appStoreUrl: config['app_store_url']?.toString(),
            playStoreUrl: config['play_store_url']?.toString(),
          ),
        ],
      ),
    );
  }
}
