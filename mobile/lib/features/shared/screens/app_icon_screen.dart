import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_icon/app_icon_options.dart';
import '../../../core/app_icon/app_icon_service.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/app_icon_preview.dart';

/// "Uygulama ikonu": pick the colour behind the Tarak mark on the home screen. Shown once right after the first
/// splash ([firstRun]) and from the profile screens of customers and providers afterwards.
class AppIconScreen extends ConsumerStatefulWidget {
  final bool firstRun;
  const AppIconScreen({super.key, this.firstRun = false});

  @override
  ConsumerState<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends ConsumerState<AppIconScreen> {
  String? _selected;
  bool _saving = false;

  AppIconOption _option(String id) => kAppIconOptions.firstWhere((o) => o.id == id, orElse: () => kAppIconOptions.first);

  Future<void> _finishFirstRun() async {
    await ref.read(appIconServiceProvider).markPrompted();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _apply(String current) async {
    final selected = _selected ?? current;
    final messenger = ScaffoldMessenger.of(context);
    if (selected == current) {
      if (widget.firstRun) await _finishFirstRun();
      return;
    }
    setState(() => _saving = true);
    try {
      // Remember the answer first: some launchers restart the app when its icon changes.
      if (widget.firstRun) await ref.read(appIconServiceProvider).markPrompted();
      await ref.read(appIconServiceProvider).change(selected);
      ref.invalidate(appIconCurrentProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('İkon "${_option(selected).name}" olarak ayarlandı. Ana ekranda birkaç saniye içinde değişir.')));
      if (widget.firstRun) Navigator.of(context).pop();
    } on AppIconException catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(appIconCurrentProvider).value ?? kDefaultAppIconId;
    final selected = _selected ?? current;
    final changed = selected != current;
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && widget.firstRun) ref.read(appIconServiceProvider).markPrompted();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: Text(widget.firstRun ? 'İkonunu seç' : 'Uygulama İkonu')),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: AppIconPreview(key: ValueKey('app_icon_big_$selected'), option: _option(selected), size: 112),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(_option(selected).name, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Simge hep aynı kalır, yalnız arka plan rengi değişir. Seçtiğin renk telefonunun ana ekranında görünür; istediğin zaman Profil bölümünden değiştirebilirsin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, height: 1.45, color: AppTheme.slate600),
                      ),
                      const SizedBox(height: 22),
                      LayoutBuilder(
                        builder: (context, box) {
                          const columns = 4;
                          const gap = 12.0;
                          final tile = (box.maxWidth - gap * (columns - 1)) / columns;
                          return Wrap(
                            spacing: gap,
                            runSpacing: 16,
                            children: [
                              for (final option in kAppIconOptions)
                                _Tile(
                                  key: Key('app_icon_${option.id}'),
                                  option: option,
                                  width: tile,
                                  selected: option.id == selected,
                                  isCurrent: option.id == current,
                                  onTap: _saving ? null : () => setState(() => _selected = option.id),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Text(
                        isIos
                            ? 'iPhone, ikon değişirken kendi bilgi penceresini gösterir; bu normaldir.'
                            : 'Android, ikon değişirken uygulamayı kapatabilir; ana ekrandaki yeni ikona dokunarak tekrar açabilirsin.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, height: 1.4, color: AppTheme.slate500),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        key: const Key('app_icon_apply'),
                        onPressed: _saving || (!widget.firstRun && !changed) ? null : () => _apply(current),
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                            : Text(widget.firstRun ? (changed ? 'Bu ikonu kullan' : 'Böyle kalsın') : 'Uygula'),
                      ),
                    ),
                    if (widget.firstRun)
                      TextButton(key: const Key('app_icon_skip'), onPressed: _saving ? null : _finishFirstRun, child: const Text('Şimdilik atla')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final AppIconOption option;
  final double width;
  final bool selected;
  final bool isCurrent;
  final VoidCallback? onTap;
  const _Tile({super.key, required this.option, required this.width, required this.selected, required this.isCurrent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${option.name}${isCurrent ? ', şu an kullanılan' : ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(width * 0.27),
                  border: Border.all(color: selected ? AppTheme.slate900 : Colors.transparent, width: 2.2),
                ),
                child: Stack(
                  children: [
                    AppIconPreview(option: option, size: width - 10.4),
                    if (selected)
                      const Positioned(
                        right: 2,
                        bottom: 2,
                        child: CircleAvatar(radius: 10, backgroundColor: AppTheme.slate900, child: Icon(Icons.check_rounded, size: 14, color: Colors.white)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                option.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? AppTheme.slate900 : AppTheme.slate600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
