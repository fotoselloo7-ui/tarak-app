import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../customer/models/service_request_model.dart';
import '../../../offerings/models/offering_models.dart';
import '../providers/provider_instant_providers.dart';

class ProviderRequestDetailScreen extends ConsumerStatefulWidget {
  final int requestId;

  const ProviderRequestDetailScreen({
    super.key,
    required this.requestId,
  });

  @override
  ConsumerState<ProviderRequestDetailScreen> createState() =>
      _ProviderRequestDetailScreenState();
}

class _ProviderRequestDetailScreenState
    extends ConsumerState<ProviderRequestDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _messageController = TextEditingController();

  // Canonical allowed ETA values: strictly 15, 30, 45, 60
  static const List<int> allowedEtas = [15, 30, 45, 60];
  int _selectedEta = 30;

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _offerSubmitted = false;

  @override
  void dispose() {
    _priceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitOffer(ServiceRequestModel request) async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return; // Prevent double submit

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      setState(() => _errorMessage = 'Geçerli bir teklif tutarı giriniz.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(providerInstantRepositoryProvider);
      await repo.createOffer(
        widget.requestId,
        price: price,
        estimatedArrivalMin: _selectedEta,
        durationMinutes: 30,
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      );

      // Refresh providers
      ref.invalidate(providerMarketplaceRequestsProvider);
      ref.read(providerMyOffersProvider.notifier).refresh();

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _offerSubmitted = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teklifiniz müşteriye başarıyla iletildi!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        // Cash commission affordability clean handling
        final msg = e.message.toLowerCase();
        if (msg.contains('bakiye') ||
            msg.contains('komisyon') ||
            msg.contains('yetersiz')) {
          _errorMessage =
              'Bu teklif için platform komisyonunu karşılayacak yeterli cüzdan bakiyeniz bulunmuyor. Komisyon bakiyesini tarak.app İşletme Finans Merkezi\'nden yükleyebilirsiniz; mevcut randevu ve işleriniz etkilenmez.';
        } else {
          _errorMessage = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Teklif gönderilirken bir hata oluştu: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(activeJobDetailNotifierProvider(widget.requestId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Talep #${widget.requestId}',
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.slate900,
        elevation: 0,
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref
                      .read(activeJobDetailNotifierProvider(widget.requestId).notifier)
                      .refresh(),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
        data: (request) => RefreshIndicator(
          onRefresh: () => ref
              .read(activeJobDetailNotifierProvider(widget.requestId).notifier)
              .refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Request Summary Card ──────────────────────────────
                _buildRequestInfoCard(request),

                const SizedBox(height: 16),

                // ── Direct call (fixed snapshot price): accept / decline ──
                if (request.isOpen && request.isDirect) ...[
                  _buildDirectCallCard(request),
                ]
                // ── Offer Form (if OPEN) ──────────────────────────────
                else if (request.isOpen && !_offerSubmitted) ...[
                  _buildOfferForm(request),
                ] else if (_offerSubmitted) ...[
                  _buildOfferSuccessCard(),
                ] else ...[
                  _buildNonOpenStateCard(request),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _respondDirect(ServiceRequestModel request, {required bool accept}) async {
    if (_isSubmitting) return;
    if (!accept) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Talebi reddet'),
          content: const Text('Bu size özel talebi reddetmek istiyor musunuz? Müşteri bilgilendirilecek.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reddet')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(providerInstantRepositoryProvider);
      if (accept) {
        await repo.acceptDirectRequest(request.id, estimatedArrivalMin: _selectedEta);
      } else {
        await repo.declineDirectRequest(request.id);
      }
        ref.invalidate(providerMarketplaceRequestsProvider);
        ref.invalidate(activeJobDetailNotifierProvider(request.id));
        ref.read(providerAssignedRequestsProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Talebi kabul ettiniz. İş size atandı.' : 'Talep reddedildi.'),
          backgroundColor: accept ? AppTheme.success : AppTheme.slate700,
        ),
      );
      Navigator.of(context).pop();
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'İşlem gerçekleştirilemedi: $e';
      });
    }
  }

  Widget _buildDirectCallCard(ServiceRequestModel request) {
    final offering = request.offering;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: AppTheme.radiusCard,
        border: Border.all(color: AppTheme.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(20)),
            child: const Text(
              'SİZE ÖZEL ÇAĞRI',
              style: TextStyle(fontFamily: AppTheme.fontFamily, color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          if (offering != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offering.title,
                        style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${offering.isPackage ? 'Özel paketiniz' : 'Hizmetiniz'} • ${offering.durationMinutes} dk',
                        style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.slate600),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatTry(offering.price),
                  style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primary),
                ),
              ],
            ),
            if (offering.items.length > 1) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: offering.items
                    .map((n) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.primaryBorder),
                          ),
                          child: Text(n, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.slate700)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Fiyat, müşterinin seçtiği hizmetle talep anında sabitlendi.',
              style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.slate500),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Tahmini varış süreniz',
            style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.slate800),
          ),
          const SizedBox(height: 8),
          Row(
            children: allowedEtas
                .map((eta) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: SizedBox(width: double.infinity, child: Text('$eta dk', textAlign: TextAlign.center)),
                          selected: _selectedEta == eta,
                          onSelected: (_) => setState(() => _selectedEta = eta),
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _selectedEta == eta ? Colors.white : AppTheme.slate700,
                          ),
                          showCheckmark: false,
                        ),
                      ),
                    ))
                .toList(),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.error)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('direct_decline_button'),
                  onPressed: _isSubmitting ? null : () => _respondDirect(request, accept: false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AppTheme.slate700,
                    side: const BorderSide(color: AppTheme.slate300),
                    shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusButton),
                  ),
                  child: const Text('Reddet'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  key: const Key('direct_accept_button'),
                  onPressed: _isSubmitting ? null : () => _respondDirect(request, accept: true),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusButton),
                  ),
                  child: Text(_isSubmitting ? 'İşleniyor...' : 'Kabul Et'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestInfoCard(ServiceRequestModel request) {
    // Safe approximate area text without exact address
    final approxArea = [
      request.approxNeighborhood,
      request.approxDistrict,
      request.approxProvince,
    ].where((String? s) => s != null && s.isNotEmpty).join(', ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: request.isOnline
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.isOnline ? 'Online Ödeme' : 'Nakit Ödeme',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: request.isOnline
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF16A34A),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                request.statusLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Talep Edilen Hizmetler',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 6),
          ...request.services.map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFFFF5722)),
                  const SizedBox(width: 8),
                  Text(
                    s.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  if (s.durationMinutes != null && s.durationMinutes! > 0) ...[
                    const Spacer(),
                    Text(
                      '~${s.durationMinutes} dk',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 24),
          const Text(
            'Yaklaşık Konum',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  approxArea.isNotEmpty ? approxArea : (request.locationText ?? 'Bölge Belirtilmedi'),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),
          if (request.distanceKm != null) ...[
            const SizedBox(height: 4),
            Text(
              'Mesafe: ~${request.distanceKm!.toStringAsFixed(1)} km',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
          if (request.customerNote != null && request.customerNote!.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              'Müşteri Notu',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                request.customerNote!,
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOfferForm(ServiceRequestModel request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Teklif Ver',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),

            // Error display
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Price input
            const Text(
              'Teklif Fiyatı (₺)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                hintText: 'Örn: 350.00',
                prefixIcon: const Icon(Icons.currency_lira, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Lütfen bir teklif tutarı belirtiniz.';
                }
                final p = double.tryParse(val.trim());
                if (p == null || p < 1) {
                  return 'Teklif tutarı en az ₺1.00 olmalıdır.';
                }
                if (p > 50000) {
                  return 'Teklif tutarı en fazla ₺50,000.00 olabilir.';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ETA selection (Canonical: 15, 30, 45, 60)
            const Text(
              'Tahmini Varış Süresi',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: allowedEtas.map((eta) {
                final isSelected = _selectedEta == eta;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text('$eta dk'),
                      selected: isSelected,
                      selectedColor: const Color(0xFFFF5722),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: _isSubmitting
                          ? null
                          : (sel) {
                              if (sel) setState(() => _selectedEta = eta);
                            },
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Optional message
            const Text(
              'Müşteriye Mesaj (İsteğe Bağlı)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _messageController,
              maxLines: 2,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Müşteriye iletmek istediğiniz not...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),

            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : () => _submitOffer(request),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Teklif Gönder',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 48),
          const SizedBox(height: 12),
          const Text(
            'Teklifiniz İletildi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF15803D),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Müşteri teklifinizi onayladığında bildirim alacaksınız ve iş aktif işlerinizde görünecektir.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Geri Dön'),
          ),
        ],
      ),
    );
  }

  Widget _buildNonOpenStateCard(ServiceRequestModel request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          'Bu talep artık teklif kabul etmiyor (${request.statusLabel}).',
          style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
