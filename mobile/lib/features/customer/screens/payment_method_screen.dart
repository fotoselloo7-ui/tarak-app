import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/custom_button.dart';
import '../payment/providers/customer_payment_providers.dart';
import '../providers/instant_request_provider.dart';
import 'request_tracking_screen.dart';

/// Step 3 — Payment method selection & note, then submit.
class PaymentMethodScreen extends ConsumerStatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  ConsumerState<PaymentMethodScreen> createState() =>
      _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends ConsumerState<PaymentMethodScreen> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final note = _noteCtrl.text.trim();
    if (note.isNotEmpty) {
      ref.read(createRequestProvider.notifier).setCustomerNote(note);
    }

    final result = await ref.read(createRequestProvider.notifier).submit();

    if (!mounted) return;

    if (result != null) {
      // Navigate to tracking, removing wizard screens from stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => RequestTrackingScreen(requestId: result.id),
        ),
        (route) => route.isFirst,
      );
    } else {
      final errorMsg =
          ref.read(createRequestProvider).errorMessage ??
          'Talep oluşturulamadı.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMsg,
            style: const TextStyle(fontFamily: AppTheme.fontFamily),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wizardState = ref.watch(createRequestProvider);
    final isSubmitting = wizardState.isSubmitting;
    // Unknown (still loading) counts as available; a confirmed "no" disables the option.
    final onlineAvailable =
        ref.watch(onlinePaymentAvailableProvider).asData?.value ?? true;
    ref.listen<AsyncValue<bool>>(onlinePaymentAvailableProvider, (_, next) {
      if (next.asData?.value == false &&
          ref.read(createRequestProvider).paymentMethod == 'ONLINE') {
        ref.read(createRequestProvider.notifier).setPaymentMethod('CASH');
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Ödeme & Gönder')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Ödeme Yöntemi'),
            const SizedBox(height: 6),
            _PaymentOption(
              icon: Icons.payments_outlined,
              title: 'Nakit',
              subtitle: 'Hizmet sonrasında elden ödeme yapın',
              value: 'CASH',
              selected: wizardState.paymentMethod,
              onTap: () => ref
                  .read(createRequestProvider.notifier)
                  .setPaymentMethod('CASH'),
            ),
            const SizedBox(height: 10),
            _PaymentOption(
              icon: Icons.credit_card_rounded,
              title: 'Online Ödeme',
              subtitle: onlineAvailable
                  ? 'Kredi veya banka kartı ile güvenli ödeme'
                  : onlinePaymentUnavailableHint,
              value: 'ONLINE',
              selected: wizardState.paymentMethod,
              enabled: onlineAvailable,
              onTap: () => ref
                  .read(createRequestProvider.notifier)
                  .setPaymentMethod('ONLINE'),
            ),
            const SizedBox(height: 24),

            const SectionHeader(
              title: 'Notunuz',
              subtitle: 'Berbere iletmek istediğiniz özel bir talimat varsa belirtebilirsiniz.',
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _noteCtrl,
              maxLines: 3,
              maxLength: 1000,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Örn: Saç kesimi ve sakal düzeltme tercihi, zil çalınmasın vb.',
              ),
            ),
            const SizedBox(height: 20),

            // Summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.radiusCard,
                border: Border.all(color: AppTheme.slate200),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Talep Özeti',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Divider(height: 16),
                  InfoRow(
                    icon: Icons.content_cut_rounded,
                    label: 'Seçilen Hizmet',
                    value: '${wizardState.selectedServiceIds.length} hizmet',
                  ),
                  if (wizardState.selectedAddressId != null)
                    const InfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Adres',
                      value: 'Kayıtlı Adres',
                    )
                  else if (wizardState.approxDistrict != null)
                    InfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Bölge',
                      value:
                          '${wizardState.approxDistrict}, ${wizardState.approxProvince}',
                    ),
                  InfoRow(
                    icon: Icons.payment_rounded,
                    label: 'Ödeme',
                    value: wizardState.paymentMethod == 'ONLINE'
                        ? 'Online Ödeme'
                        : 'Nakit',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.slate200)),
        ),
        child: SafeArea(
          child: PrimaryButton(
            text: 'Talebi Gönder',
            isLoading: isSubmitting,
            onPressed: _submit,
          ),
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String selected;
  final VoidCallback onTap;
  final bool enabled;

  const _PaymentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value && enabled;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withAlpha(25)
                      : AppTheme.slate100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? AppTheme.primary : AppTheme.slate600,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected ? AppTheme.primary : AppTheme.slate300,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
