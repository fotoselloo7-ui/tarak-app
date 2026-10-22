import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_icon/app_icon_options.dart';
import '../../../core/app_icon/app_icon_service.dart';
import '../../../core/theme/app_theme.dart';
import '../screens/app_icon_screen.dart';
import 'app_icon_preview.dart';
import 'common_widgets.dart';

/// Profile entry "Uygulama İkonu" (customers and providers). Hidden where the icon cannot be changed (web, desktop).
/// Draws its own bottom spacing so a hidden card leaves no gap.
class AppIconCard extends ConsumerWidget {
  const AppIconCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(appIconSupportedProvider).value != true) return const SizedBox.shrink();
    final currentId = ref.watch(appIconCurrentProvider).value ?? kDefaultAppIconId;
    final option = kAppIconOptions.firstWhere((o) => o.id == currentId, orElse: () => kAppIconOptions.first);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        key: const Key('app_icon_card'),
        padding: const EdgeInsets.all(14),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AppIconScreen()));
          ref.invalidate(appIconCurrentProvider);
        },
        child: Row(
          children: [
            AppIconPreview(option: option, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Uygulama İkonu', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 3),
                  Text('Şu an: ${option.name}. Ana ekran ikonunun rengini seç', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11.5, height: 1.3, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.slate400),
          ],
        ),
      ),
    );
  }
}
