import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/common_widgets.dart';
import '../models/offering_models.dart';
import '../providers/offerings_providers.dart';

TextStyle _t(double size, {FontWeight weight = FontWeight.w500, Color color = AppTheme.textPrimary}) =>
    TextStyle(fontFamily: AppTheme.fontFamily, fontSize: size, fontWeight: weight, color: color);

String _errorText(Object e) => e is AppException ? e.message : 'İşlem gerçekleştirilemedi.';

/// Provider "Hizmetlerim": catalog services with own price/duration, plus provider-owned packages.
class ProviderOfferingsScreen extends ConsumerWidget {
  const ProviderOfferingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Hizmetlerim'),
          bottom: const TabBar(
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.slate500,
            indicatorColor: AppTheme.primary,
            labelStyle: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700, fontSize: 14),
            tabs: [Tab(text: 'Normal Hizmetler'), Tab(text: 'Özel Paketler')],
          ),
        ),
        body: const TabBarView(children: [_ServicesTab(), _PackagesTab()]),
      ),
    );
  }
}

// ── Normal services ──────────────────────────────────────────────────────────

class _ServicesTab extends ConsumerWidget {
  const _ServicesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(offeringCatalogProvider);
    final mine = ref.watch(myProviderServicesProvider);

    if (catalog.isLoading || mine.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (catalog.hasError || mine.hasError) {
      return ErrorState(
        message: 'Hizmetler yüklenemedi.',
        onRetry: () {
          ref.invalidate(offeringCatalogProvider);
          ref.invalidate(myProviderServicesProvider);
        },
      );
    }

    final categories = catalog.value ?? const <CatalogCategory>[];
    final offered = {for (final s in mine.value ?? const <MyProviderService>[]) s.serviceId: s};

    if (categories.isEmpty) {
      return const EmptyState(
        icon: Icons.content_cut_rounded,
        title: 'Katalog boş',
        description: 'Hizmet kataloğu henüz tanımlanmamış.',
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        ref.invalidate(myProviderServicesProvider);
        await ref.read(myProviderServicesProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Katalogdan sunduğun hizmetleri seç; kendi fiyatını ve süreni belirle. Pasif hizmetler müşterilere görünmez.',
            style: _t(13, color: AppTheme.slate600),
          ),
          const SizedBox(height: 16),
          for (final cat in categories) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(cat.name.toUpperCase(), style: _t(12, weight: FontWeight.w700, color: AppTheme.slate500)),
            ),
            for (final svc in cat.services)
              _ServiceRow(service: svc, mine: offered[svc.id]),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ServiceRow extends ConsumerWidget {
  final CatalogService service;
  final MyProviderService? mine;

  const _ServiceRow({required this.service, required this.mine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = mine?.isActive ?? false;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      borderColor: active ? AppTheme.primaryBorder : null,
      onTap: () => _openEditor(context, ref),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active ? AppTheme.primaryLight : AppTheme.slate100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.content_cut_rounded, size: 20, color: active ? AppTheme.primary : AppTheme.slate400),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name, style: _t(15, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  mine == null
                      ? 'Sunulmuyor • dokun ve ekle'
                      : '${formatTry(mine!.price)} • ${mine!.durationMinutes} dk${mine!.description != null ? ' • ${mine!.description}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _t(12, color: AppTheme.slate500),
                ),
              ],
            ),
          ),
          if (mine != null)
            Switch.adaptive(
              value: active,
              activeTrackColor: AppTheme.primary,
              onChanged: (v) => _save(context, ref,
                  price: mine!.price, duration: mine!.durationMinutes, description: mine!.description, active: v),
            )
          else
            const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
        ],
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref, {
    required double price,
    required int duration,
    String? description,
    required bool active,
  }) async {
    try {
      await ref.read(providerOfferingsRepositoryProvider).saveService(
            serviceId: service.id,
            price: price,
            durationMinutes: duration,
            description: description,
            isActive: active,
          );
      ref.invalidate(myProviderServicesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(e)), backgroundColor: AppTheme.error));
      }
    }
  }

  void _openEditor(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ServiceEditorSheet(service: service, mine: mine),
    );
  }
}

class _ServiceEditorSheet extends ConsumerStatefulWidget {
  final CatalogService service;
  final MyProviderService? mine;

  const _ServiceEditorSheet({required this.service, required this.mine});

  @override
  ConsumerState<_ServiceEditorSheet> createState() => _ServiceEditorSheetState();
}

class _ServiceEditorSheetState extends ConsumerState<_ServiceEditorSheet> {
  late final TextEditingController _price;
  late final TextEditingController _duration;
  late final TextEditingController _description;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final m = widget.mine;
    _price = TextEditingController(text: (m?.price ?? widget.service.basePrice).toStringAsFixed(0));
    _duration = TextEditingController(text: '${m?.durationMinutes ?? widget.service.durationMinutes}');
    _description = TextEditingController(text: m?.description ?? '');
    _active = m?.isActive ?? true;
  }

  @override
  void dispose() {
    _price.dispose();
    _duration.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final price = double.tryParse(_price.text.replaceAll(',', '.').trim());
    final duration = int.tryParse(_duration.text.trim());
    if (price == null || price <= 0) return setState(() => _error = 'Geçerli bir fiyat girin.');
    if (duration == null || duration < 5) return setState(() => _error = 'Süre en az 5 dakika olmalı.');

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(providerOfferingsRepositoryProvider).saveService(
            serviceId: widget.service.id,
            price: price,
            durationMinutes: duration,
            description: _description.text,
            isActive: _active,
          );
      ref.invalidate(myProviderServicesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = _errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.service.name, style: _t(18, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            widget.mine == null ? 'Bu hizmeti profiline ekle' : 'Fiyat, süre ve açıklamayı güncelle',
            style: _t(13, color: AppTheme.slate500),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _field(_price, 'Fiyat (₺)', number: true, key: 'service_price_field')),
              const SizedBox(width: 12),
              Expanded(child: _field(_duration, 'Süre (dk)', number: true, key: 'service_duration_field')),
            ],
          ),
          const SizedBox(height: 12),
          _field(_description, 'Kısa açıklama (isteğe bağlı)', maxLength: 300),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _active,
            activeTrackColor: AppTheme.primary,
            onChanged: (v) => setState(() => _active = v),
            title: Text('Müşterilere görünür (aktif)', style: _t(14, weight: FontWeight.w600)),
          ),
          if (_error != null) ...[
            Text(_error!, style: _t(12, color: AppTheme.error)),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          ElevatedButton(
            key: const Key('service_save_button'),
            onPressed: _saving ? null : _submit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusButton),
            ),
            child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool number = false, int? maxLength, String? key}) {
    return TextField(
      key: key != null ? Key(key) : null,
      controller: c,
      maxLength: maxLength,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : null,
      decoration: InputDecoration(labelText: label, counterText: ''),
    );
  }
}

// ── Packages ─────────────────────────────────────────────────────────────────

class _PackagesTab extends ConsumerWidget {
  const _PackagesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(myProviderPackagesProvider);

    return Stack(
      children: [
        packages.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          error: (_, _) => ErrorState(
            message: 'Paketler yüklenemedi.',
            onRetry: () => ref.invalidate(myProviderPackagesProvider),
          ),
          data: (list) => list.isEmpty
              ? const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Henüz özel paketin yok',
                  description: 'Örneğin "Damat Hazırlık Paketi" gibi birden çok hizmeti tek fiyat ve süreyle sun.',
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () async {
                    ref.invalidate(myProviderPackagesProvider);
                    await ref.read(myProviderPackagesProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: list.map((p) => _PackageCard(package: p)).toList(),
                  ),
                ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            key: const Key('new_package_button'),
            heroTag: 'new_package',
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PackageEditorScreen()),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Yeni Paket'),
          ),
        ),
      ],
    );
  }
}

class _PackageCard extends ConsumerWidget {
  final ProviderPackageModel package;

  const _PackageCard({required this.package});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(providerOfferingsRepositoryProvider);

    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
        ref.invalidate(myProviderPackagesProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(e)), backgroundColor: AppTheme.error));
        }
      }
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderColor: package.isActive ? AppTheme.primaryBorder : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(package.title, style: _t(16, weight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      package.isActive ? 'Aktif' : 'Pasif',
                      style: _t(12, weight: FontWeight.w600, color: package.isActive ? AppTheme.success : AppTheme.slate500),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatTry(package.price), style: _t(18, weight: FontWeight.w900, color: AppTheme.primary)),
                  Text('${package.durationMinutes} dk', style: _t(12, color: AppTheme.slate500)),
                ],
              ),
            ],
          ),
          if (package.description != null) ...[
            const SizedBox(height: 8),
            Text(package.description!, style: _t(13, color: AppTheme.slate600)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: package.services
                .map((s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.slate100, borderRadius: BorderRadius.circular(20)),
                      child: Text(s.name, style: _t(12, color: AppTheme.slate700)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PackageEditorScreen(existing: package)),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Düzenle'),
              ),
              TextButton(
                onPressed: () => run(() => repo.updatePackage(package.id, isActive: !package.isActive)),
                child: Text(package.isActive ? 'Pasif Yap' : 'Aktif Yap'),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Sil',
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Paketi sil'),
                      content: Text('"${package.title}" silinsin mi? Geçmiş talepler etkilenmez.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
                      ],
                    ),
                  );
                  if (ok == true) await run(() => repo.deletePackage(package.id));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PackageEditorScreen extends ConsumerStatefulWidget {
  final ProviderPackageModel? existing;

  const PackageEditorScreen({super.key, this.existing});

  @override
  ConsumerState<PackageEditorScreen> createState() => _PackageEditorScreenState();
}

class _PackageEditorScreenState extends ConsumerState<PackageEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _duration;
  late final Set<int> _selected;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _title = TextEditingController(text: p?.title ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _price = TextEditingController(text: p != null ? p.price.toStringAsFixed(0) : '');
    _duration = TextEditingController(text: p != null ? '${p.durationMinutes}' : '');
    _selected = {...?p?.services.map((s) => s.serviceId)};
    _active = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final price = double.tryParse(_price.text.replaceAll(',', '.').trim());
    final duration = int.tryParse(_duration.text.trim());
    if (_title.text.trim().length < 3) return setState(() => _error = 'Paket başlığı en az 3 karakter olmalı.');
    if (_selected.isEmpty) return setState(() => _error = 'Pakete en az bir hizmet ekleyin.');
    if (price == null || price <= 0) return setState(() => _error = 'Geçerli bir paket fiyatı girin.');
    if (duration == null || duration < 15) return setState(() => _error = 'Paket süresi en az 15 dakika olmalı.');

    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(providerOfferingsRepositoryProvider);
    try {
      if (widget.existing == null) {
        await repo.createPackage(
          title: _title.text,
          description: _description.text,
          price: price,
          durationMinutes: duration,
          serviceIds: _selected.toList(),
          isActive: _active,
        );
      } else {
        await repo.updatePackage(
          widget.existing!.id,
          title: _title.text,
          description: _description.text,
          price: price,
          durationMinutes: duration,
          serviceIds: _selected.toList(),
          isActive: _active,
        );
      }
      ref.invalidate(myProviderPackagesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = _errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(offeringCatalogProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(widget.existing == null ? 'Yeni Özel Paket' : 'Paketi Düzenle')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('package_title_field'),
            controller: _title,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Başlık', hintText: 'Örn: Damat Hazırlık Paketi', counterText: ''),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLength: 1000,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)', counterText: ''),
          ),
          const SizedBox(height: 16),
          Text('Dahil hizmetler', style: _t(14, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          catalog.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
            ),
            error: (_, _) => Text('Katalog yüklenemedi.', style: _t(13, color: AppTheme.error)),
            data: (cats) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final cat in cats) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 6),
                    child: Text(cat.name, style: _t(12, weight: FontWeight.w700, color: AppTheme.slate500)),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cat.services.map((s) {
                      final on = _selected.contains(s.id);
                      return FilterChip(
                        label: Text(s.name),
                        selected: on,
                        onSelected: (v) => setState(() => v ? _selected.add(s.id) : _selected.remove(s.id)),
                        selectedColor: AppTheme.primaryLight,
                        checkmarkColor: AppTheme.primary,
                        labelStyle: _t(12, weight: on ? FontWeight.w700 : FontWeight.w500, color: on ? AppTheme.primary : AppTheme.slate700),
                        side: BorderSide(color: on ? AppTheme.primary : AppTheme.slate200),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('package_price_field'),
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(labelText: 'Toplam fiyat (₺)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('package_duration_field'),
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Tahmini süre (dk)'),
                ),
              ),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _active,
            activeTrackColor: AppTheme.primary,
            onChanged: (v) => setState(() => _active = v),
            title: Text('Müşterilere görünür (aktif)', style: _t(14, weight: FontWeight.w600)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: _t(13, color: AppTheme.error)),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('package_save_button'),
            onPressed: _saving ? null : _submit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusButton),
            ),
            child: Text(_saving ? 'Kaydediliyor...' : 'Paketi Kaydet'),
          ),
        ],
      ),
    );
  }
}
