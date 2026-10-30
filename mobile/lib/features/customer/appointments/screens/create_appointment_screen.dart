import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/tarak_rating.dart';
import '../../../shared/widgets/provider_list_tools.dart';

import '../../providers/instant_request_provider.dart';
import '../../screens/address_selection_screen.dart';
import '../../../offerings/models/offering_models.dart';
import '../models/scheduled_provider_model.dart';
import '../providers/customer_appointment_providers.dart';
import 'customer_appointment_detail_screen.dart';
import '../../payment/providers/customer_payment_providers.dart';
import '../../../../core/widgets/verified_tick.dart';

class CreateAppointmentScreen extends ConsumerStatefulWidget {
  const CreateAppointmentScreen({super.key});

  @override
  ConsumerState<CreateAppointmentScreen> createState() =>
      _CreateAppointmentScreenState();
}

class _CreateAppointmentScreenState
    extends ConsumerState<CreateAppointmentScreen> {
  int _currentStep = 0;
  final TextEditingController _noteController = TextEditingController();

  /// Address created from this flow; selected once the refreshed list contains it.
  int? _pendingAddressId;

  static const _dateStep = 3;

  /// The recommended cards of the provider step change every few seconds.
  final RecommendedTicker _ticker = RecommendedTicker();

  @override
  void initState() {
    super.initState();
    Future.microtask(() { if (mounted) ref.read(appointmentWizardProvider.notifier).reset(); });
  }

  @override
  void dispose() {
    _ticker.stop();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appointmentWizardProvider);
    final notifier = ref.read(appointmentWizardProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _getStepTitle(_currentStep),
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Step progress bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: List.generate(6, (index) {
                final isPassed = index <= _currentStep;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isPassed
                          ? const Color(0xFFFF5722)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          if (state.errorMessage != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildCurrentStepView(state, notifier)),
          _buildBottomAction(state, notifier),
        ],
      ),
    );
  }

  String _getStepTitle(int step) => switch (step) {
    0 => '1. Adres Seçimi', 1 => '2. Hizmet Seçimi', 2 => '3. Hizmet Veren Seçimi',
    3 => '4. Tarih & Saat', 4 => '5. Ödeme Yöntemi', 5 => '6. İncele ve Onayla', _ => 'Randevu Oluştur',
  };

  Widget _buildCurrentStepView(AppointmentWizardState state, AppointmentWizardNotifier notifier) {
    return switch (_currentStep) {
      0 => _buildAddressStep(state, notifier), 1 => _buildServiceSelectionStep(state, notifier),
      2 => _buildProviderSelectionStep(state, notifier), 3 => _buildDateTimeStep(state, notifier),
      4 => _buildPaymentStep(state, notifier), 5 => _buildReviewStep(state, notifier), _ => const SizedBox.shrink(),
    };
  }

  // ── Step 1: Services ───────────────────────────────────────────────────────

  Widget _buildServiceSelectionStep(
    AppointmentWizardState state,
    AppointmentWizardNotifier notifier,
  ) {
    final servicesAsync = ref.watch(servicesProvider(null));

    return servicesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5722)),
      ),
      error: (err, _) => _RetryView(
        message: 'Hizmetler yüklenemedi.',
        onRetry: () => ref.invalidate(servicesProvider(null)),
      ),
      data: (services) {
        if (services.isEmpty) {
          return const Center(child: Text('Kayıtlı aktif hizmet bulunamadı.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: services.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final service = services[index];
            final isSelected = state.selectedServices.any(
              (s) => s.id == service.id,
            );

            return Card(
              key: Key('service_item_${service.id}'),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFFFF5722)
                      : const Color(0xFFE2E8F0),
                  width: isSelected ? 2 : 1,
                ),
              ),
              color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
              child: CheckboxListTile(
                value: isSelected,
                activeColor: const Color(0xFFFF5722),
                title: Text(
                  service.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                subtitle: service.durationMinutes != null
                    ? Text('${service.durationMinutes} dakika')
                    : null,
                onChanged: (_) => notifier.toggleService(service),
              ),
            );
          },
        );
      },
    );
  }

  // ── Step 2: Providers ──────────────────────────────────────────────────────

  Widget _buildProviderSelectionStep(
    AppointmentWizardState state,
    AppointmentWizardNotifier notifier,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_currentStep == 2 && state.sponsoredProviders.isNotEmpty) {
        _ticker.start(state.rotationSeconds, notifier.refreshRecommended);
      } else {
        _ticker.stop();
      }
    });

    // A provider in the recommended slots is not listed again below while it is there.
    final shown = recommendedIds(state.sponsoredProviders.map((p) => p.userId));
    final organicProviders = [for (final p in state.availableProviders) if (!shown.contains('${p.userId}')) p];
    final hasResults = organicProviders.isNotEmpty || state.sponsoredProviders.isNotEmpty;
    final filtered = state.providerFilters.isActive;

    Widget status;
    if (state.providersError != null && !hasResults) {
      status = _RetryView(
        message: state.providersError!,
        onRetry: notifier.loadProviders,
      );
    } else if (state.isLoadingProviders && !hasResults) {
      status = const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5722)),
        ),
      );
    } else if (!hasResults) {
      status = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.person_off_outlined,
              size: 56,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            Text(
              filtered
                  ? 'Bu filtrelere uygun uzman bulunamadı.'
                  : 'Seçilen hizmetler için uygun uzman bulunamadı.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: filtered
                  ? () => notifier.setProviderFilters(const ProviderListFilters())
                  : () => notifier.loadProviders(),
              child: Text(filtered ? 'Filtreleri temizle' : 'Tekrar Dene'),
            ),
          ],
        ),
      );
    } else {
      status = Opacity(
        opacity: state.isLoadingProviders ? 0.55 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.sponsoredProviders.isNotEmpty) ...[
              RecommendedSlot(
                signature: state.sponsoredProviders.map((p) => p.userId).join(','),
                children: [
                  for (final provider in state.sponsoredProviders)
                    _providerCard(provider, state, notifier, recommended: true),
                ],
              ),
              const SizedBox(height: 12),
            ],
            for (final provider in organicProviders) ...[
              _providerCard(provider, state, notifier),
              const SizedBox(height: 12),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFFF5722),
      onRefresh: notifier.loadProviders,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          ProviderFilterBar(
            value: state.providerFilters,
            onChanged: notifier.setProviderFilters,
            sorts: const [
              ProviderSort.relevance,
              ProviderSort.rating,
              ProviderSort.distance,
              ProviderSort.reviews,
            ],
            searchHint: 'Uzman veya semt ara',
          ),
          const SizedBox(height: 4),
          status,
        ],
      ),
    );
  }

  Widget _providerCard(
    ScheduledProviderModel provider,
    AppointmentWizardState state,
    AppointmentWizardNotifier notifier, {
    bool recommended = false,
  }) {
    final isSelected = state.selectedProvider?.id == provider.id;

    return Card(
      key: Key('provider_card_${provider.id}'),
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? const Color(0xFFFF5722) : const Color(0xFFE2E8F0),
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
      child: InkWell(
        onTap: () => notifier.selectProvider(provider),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFFFECE5),
                backgroundImage: provider.avatarUrl != null
                    ? NetworkImage(provider.avatarUrl!)
                    : null,
                child: provider.avatarUrl == null
                    ? const Icon(
                        Icons.person,
                        size: 28,
                        color: Color(0xFFFF5722),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (recommended)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: RecommendedTag(),
                      ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            provider.displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (provider.isVerified) ...[
                          const SizedBox(width: 6),
                          const VerifiedTick(size: 18),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (provider.rating != null && provider.reviewCount > 0)
                          TarakRatingLabel(
                            value: provider.rating!,
                            count: provider.reviewCount,
                            size: 13,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        if (provider.locationSummary.isNotEmpty)
                          Text(
                            provider.locationSummary,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        DistancePill(km: provider.distanceKm),
                      ],
                    ),
                    if (provider.services.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        provider.services.map((s) => s.name).join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    if (provider.providerType != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          provider.providerType == 'barber'
                              ? 'Berber'
                              : 'Kuaför',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Radio<int>(
                value: provider.id,
                groupValue: state.selectedProvider?.id,
                activeColor: const Color(0xFFFF5722),
                onChanged: (_) => notifier.selectProvider(provider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 3: Date & Slots ───────────────────────────────────────────────────

  Widget _buildPackageSelector(
    AppointmentWizardState state,
    AppointmentWizardNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 18,
              color: Color(0xFFFF5722),
            ),
            const SizedBox(width: 6),
            const Text(
              'Özel Paketler',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          'İsterseniz uzmanın hazır paketlerinden birini seçin (tekil hizmet seçimini geçersiz kılar).',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 10),
        ...state.providerPackages.map((pkg) {
          final selected = state.selectedPackage?.id == pkg.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => notifier.selectPackage(selected ? null : pkg),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFFFF7ED) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFFF5722)
                        : const Color(0xFFE2E8F0),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      size: 20,
                      color: selected
                          ? const Color(0xFFFF5722)
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pkg.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (pkg.services.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                pkg.services.map((s) => s.name).join(' + '),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatTry(pkg.price),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFFFF5722),
                          ),
                        ),
                        Text(
                          '${pkg.durationMinutes} dk',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDateTimeStep(
    AppointmentWizardState state,
    AppointmentWizardNotifier notifier,
  ) {
    final selectedDate = state.selectedDate;

    return RefreshIndicator(
      color: const Color(0xFFFF5722),
      onRefresh: notifier.loadAvailability,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.providerPackages.isNotEmpty) ...[
              _buildPackageSelector(state, notifier),
              const SizedBox(height: 16),
            ],
            const Text(
              'Tarih Seçin',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                key: const Key('date_picker_tile'),
                leading: const Icon(
                  Icons.calendar_month,
                  color: Color(0xFFFF5722),
                ),
                title: Text(
                  selectedDate != null
                      ? '${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}'
                      : 'Tarih Belirleyin',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate:
                        selectedDate ?? now.add(const Duration(days: 1)),
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    notifier.selectDate(picked);
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Uygun Randevu Saatleri',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (state.isLoadingAvailability)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFF5722),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (selectedDate == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Saatleri görmek için lütfen önce bir tarih seçin.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              )
            else if (state.isLoadingAvailability)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5722)),
                ),
              )
            else if (state.availabilityError != null)
              _RetryView(
                message: state.availabilityError!,
                onRetry: notifier.loadAvailability,
              )
            else if (state.availableSlots.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.event_busy,
                        size: 48,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Seçilen tarihte uygun randevu saati bulunmuyor.',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Lütfen başka bir gün seçin.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: state.availableSlots.map((slot) {
                  final isSelected = state.selectedSlot == slot;
                  return ChoiceChip(
                    key: Key('slot_chip_$slot'),
                    label: Text(
                      slot,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF334155),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFFFF5722),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFFFF5722)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    onSelected: (_) => notifier.selectSlot(slot),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ── Step 4: Address ────────────────────────────────────────────────────────

  Widget _buildAddressStep(
    AppointmentWizardState state,
    AppointmentWizardNotifier notifier,
  ) {
    final addressesAsync = ref.watch(customerAddressesProvider);

    return addressesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5722)),
      ),
      error: (err, _) => _RetryView(
        message: 'Adresler yüklenemedi.',
        onRetry: () => ref.invalidate(customerAddressesProvider),
      ),
      data: (addresses) {
        // A just-created address is selected once the refreshed list has it.
        final pending = _pendingAddressId;
        if (pending != null) {
          final match = addresses.where((a) => a.id == pending);
          if (match.isNotEmpty) {
            _pendingAddressId = null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) notifier.selectAddress(match.first);
            });
          }
        }

        if (addresses.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_off_outlined,
                    size: 56,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Kayıtlı adresiniz bulunmuyor.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Randevu oluşturabilmek için bir adres kaydedin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  _addAddressButton(),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: addresses.length + 1,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == addresses.length) return _addAddressButton();
            final addr = addresses[index];
            final isSelected = state.selectedAddress?.id == addr.id;

            return Card(
              key: Key('address_item_${addr.id}'),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFFFF5722)
                      : const Color(0xFFE2E8F0),
                  width: isSelected ? 2 : 1,
                ),
              ),
              color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
              child: InkWell(
                onTap: () => notifier.selectAddress(addr),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.home_outlined,
                        color: Color(0xFFFF5722),
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              addr.title ?? 'Adres',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              addr.displayLine,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Radio<int>(
                        value: addr.id,
                        groupValue: state.selectedAddress?.id,
                        activeColor: const Color(0xFFFF5722),
                        onChanged: (_) => notifier.selectAddress(addr),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Step 5: Payment ────────────────────────────────────────────────────────

  Widget _buildPaymentStep(
    AppointmentWizardState state,
    AppointmentWizardNotifier notifier,
  ) {
    // Unknown (still loading) counts as available; a confirmed "no" disables the option.
    final onlineAvailable =
        ref.watch(onlinePaymentAvailableProvider).asData?.value ?? true;
    ref.listen<AsyncValue<bool>>(onlinePaymentAvailableProvider, (_, next) {
      if (next.asData?.value == false && state.paymentMethod == 'ONLINE') {
        notifier.setPaymentMethod('CASH');
      }
    });
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ödeme Yöntemini Seçin',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          _buildPaymentOption(
            key: const Key('payment_option_cash'),
            title: 'Nakit Ödeme',
            subtitle: 'Hizmet bedelini hizmet verene doğrudan ödersiniz.',
            icon: Icons.payments_outlined,
            isSelected: state.paymentMethod == 'CASH',
            onTap: () => notifier.setPaymentMethod('CASH'),
          ),
          const SizedBox(height: 12),
          _buildPaymentOption(
            key: const Key('payment_option_online'),
            title: 'Online Ödeme',
            subtitle: onlineAvailable
                ? 'Ödeme onaylandıktan sonra hizmet başlayabilir.'
                : onlinePaymentUnavailableHint,
            icon: Icons.credit_card_outlined,
            isSelected: state.paymentMethod == 'ONLINE' && onlineAvailable,
            enabled: onlineAvailable,
            onTap: () => notifier.setPaymentMethod('ONLINE'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Hizmet Verene Not (İsteğe Bağlı)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('appointment_note_input'),
            controller: _noteController,
            maxLines: 3,
            maxLength: 1000, // customer_note limit in the appointment API
            decoration: InputDecoration(
              hintText: 'Örn: Zili çalmayınız, kapıya vurunuz...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            onChanged: (text) => notifier.setCustomerNote(text),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required Key key,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Card(
        key: key,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFFFF5722)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? const Color(0xFFFF5722)
                      : const Color(0xFF64748B),
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Radio<bool>(
                  value: true,
                  groupValue: isSelected,
                  activeColor: const Color(0xFFFF5722),
                  onChanged: enabled ? (_) => onTap() : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 6: Review ─────────────────────────────────────────────────────────

  Widget _buildReviewStep(
    AppointmentWizardState state,
    AppointmentWizardNotifier notifier,
  ) {
    final selectedDate = state.selectedDate;
    final dateStr = selectedDate != null
        ? '${selectedDate.day.toString().padLeft(2, '0')}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.year}'
        : '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Randevu Detayları',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          _buildReviewCard(
            title: 'Hizmet Veren',
            content: state.selectedProvider?.displayName ?? '-',
            subcontent: state.selectedProvider?.locationSummary,
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 10),
          _buildReviewCard(
            title: state.selectedPackage != null ? 'Paket' : 'Hizmetler',
            content: state.selectedPackage != null
                ? state.selectedPackage!.title
                : state.selectedServices.map((s) => s.name).join(', '),
            subcontent: state.selectedPackage?.services
                .map((s) => s.name)
                .join(' + '),
            icon: Icons.cut_outlined,
          ),
          const SizedBox(height: 10),
          _buildReviewCard(
            title: 'Tarih & Saat',
            content: '$dateStr ${state.selectedSlot ?? '-'}',
            icon: Icons.event_outlined,
          ),
          const SizedBox(height: 10),
          _buildReviewCard(
            title: 'Adres',
            content: state.selectedAddress?.displayLine ?? '-',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 10),
          _buildReviewCard(
            title: 'Ödeme Yöntemi',
            content: state.paymentMethod == 'CASH'
                ? 'Nakit Ödeme (Hizmet Verene)'
                : 'Online Ödeme',
            icon: Icons.payment_outlined,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Toplam Tutar',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                    if (state.estimatedDurationMinutes != null)
                      Text(
                        'Tahmini süre: ${state.estimatedDurationMinutes} dk',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                  ],
                ),
                Text(
                  state.estimatedPrice != null
                      ? '₺${state.estimatedPrice!.toStringAsFixed(0)}'
                      : '-',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF5722),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard({
    required String title,
    required String content,
    String? subcontent,
    required IconData icon,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: const Color(0xFFFF5722)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (subcontent != null && subcontent.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subcontent,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Action ──────────────────────────────────────────────────────────

  Widget _buildBottomAction(
    AppointmentWizardState state,
    AppointmentWizardNotifier notifier,
  ) {
    bool canProceed = false;
    switch (_currentStep) {
      case 0: canProceed = state.selectedAddress != null; break;
      case 1: canProceed = state.canProceedToProvider; break;
      case 2: canProceed = state.canProceedToDateTime; break;
      case 3: canProceed = state.canProceedToAddress; break;
      case 4: canProceed = state.canReview; break;
      case 5: canProceed = !state.isSubmitting; break;
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            key: _currentStep == 5
                ? const Key('submit_appointment_btn')
                : const Key('wizard_next_btn'),
            onPressed: canProceed
                ? () async {
                    if (_currentStep < 5) {
                      setState(() => _currentStep++);
                    } else {
                      // Submit appointment (errors are kept in wizard state)
                      final created = await notifier.submitAppointment();
                      if (!mounted) return;
                      if (created == null) {
                        if (ref.read(appointmentWizardProvider).slotConflict) {
                          setState(() => _currentStep = _dateStep);
                        }
                        return;
                      }
                      {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerAppointmentDetailScreen(
                              appointmentId: created.id,
                            ),
                          ),
                        );
                      }
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5722),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              disabledBackgroundColor: const Color(0xFFCBD5E1),
            ),
            child: state.isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _currentStep == 5 ? 'Randevu Oluştur' : 'Devam Et',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _addAddressButton() {
    return OutlinedButton.icon(
      key: const Key('add_address_btn'),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddressSelectionScreen(
              onAddressSaved: (id) => setState(() => _pendingAddressId = id),
            ),
          ),
        );
      },
      icon: const Icon(
        Icons.add_location_alt_outlined,
        color: Color(0xFFFF5722),
      ),
      label: const Text(
        'Yeni Adres Ekle',
        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF5722)),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        side: const BorderSide(color: Color(0xFFFF5722)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _RetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RetryView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_outlined,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('retry_btn'),
              onPressed: onRetry,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}
