import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/service_icon.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/custom_button.dart';
import '../providers/instant_request_provider.dart';
import '../../offerings/screens/customer_offering_screens.dart';
import 'address_selection_screen.dart';

/// Step 1 — Service selection screen for Hemen Çağır flow.
class ServiceSelectionScreen extends ConsumerStatefulWidget {
  const ServiceSelectionScreen({super.key});

  @override
  ConsumerState<ServiceSelectionScreen> createState() =>
      _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState
    extends ConsumerState<ServiceSelectionScreen> {
  String? _activeCategoryId;

  @override
  void initState() {
    super.initState();
    // Reset any previous wizard state on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(createRequestProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(serviceCategoriesProvider);
    final services = ref.watch(servicesProvider(_activeCategoryId));
    final selectedIds = ref.watch(
        createRequestProvider.select((s) => s.selectedServiceIds));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Hizmet Seç'),
      ),
      body: Column(
        children: [
          // Category filter chips
          categories.when(
            data: (cats) => _CategoryChips(
              categories: cats.map((c) => (c.id, c.name)).toList(),
              selected: _activeCategoryId,
              onSelect: (id) => setState(() => _activeCategoryId = id),
            ),
            loading: () => const SizedBox(
              height: 56,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const Divider(height: 1),
          // Services list
          Expanded(
            child: services.when(
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.content_cut_rounded,
                    title: 'Hizmet Bulunamadı',
                    description: 'Bu kategoride henüz aktif hizmet bulunmamaktadır.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    final isSelected = selectedIds.contains(item.id);
                    return _ServiceTile(
                      name: item.name,
                      iconClass: item.iconClass,
                      durationMinutes: item.durationMinutes,
                      isSelected: isSelected,
                      onTap: () => ref
                          .read(createRequestProvider.notifier)
                          .toggleService(item.id),
                      onShowProviders: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServiceProvidersScreen(serviceId: item.id, serviceName: item.name),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
              error: (e, _) => ErrorState(
                message: 'Hizmetler yüklenemedi: $e',
                onRetry: () {
                  ref.invalidate(serviceCategoriesProvider);
                  ref.invalidate(servicesProvider(_activeCategoryId));
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: selectedIds.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.slate200)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${selectedIds.length} hizmet seçildi',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.slate600,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      text: 'Devam Et — Adres Seç',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddressSelectionScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<(String, String)> categories;
  final String? selected;
  final void Function(String?) onSelect;

  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _chip('Tümü', null, selected == null),
          ...categories.map((c) => _chip(c.$2, c.$1, selected == c.$1)),
        ],
      ),
    );
  }

  Widget _chip(String label, String? id, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onSelect(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : AppTheme.slate100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.slate200,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: isSelected ? Colors.white : AppTheme.slate700,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final String name;
  final String? iconClass;
  final int? durationMinutes;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onShowProviders;

  const _ServiceTile({
    required this.name,
    required this.iconClass,
    required this.durationMinutes,
    required this.isSelected,
    required this.onTap,
    required this.onShowProviders,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight : Colors.white,
          borderRadius: AppTheme.radiusCard,
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.slate200,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            ServiceIconBox(iconClass: iconClass, name: name, size: 40, iconSize: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            if (durationMinutes != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.slate100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '~$durationMinutes dk',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.slate600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppTheme.primary : AppTheme.slate300,
              size: 22,
            ),
            TextButton(
              onPressed: onShowProviders,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text(
                'Uzmanlar',
                style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
