import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/custom_button.dart';
import '../models/service_offer.dart';
import '../providers/instant_request_provider.dart';
import '../../../core/widgets/verified_tick.dart';

/// Offers list screen — Customer reviews and accepts a provider offer.
class OffersScreen extends ConsumerWidget {
  final int requestId;

  const OffersScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(offersProvider(requestId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Gelen Teklifler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(offersProvider(requestId)),
          ),
        ],
      ),
      body: offersAsync.when(
        data: (offers) {
          final pending = offers.where((o) => o.isPending).toList();
          final other = offers.where((o) => !o.isPending).toList();

          if (offers.isEmpty) {
            return RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: () async => ref.invalidate(offersProvider(requestId)),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.55,
                    child: const EmptyState(
                      icon: Icons.hourglass_empty_rounded,
                      title: 'Henüz teklif gelmedi',
                      description: 'Yakındaki berberler talebinizi inceliyor. Teklifler geldikçe burada listelenecektir.',
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async => ref.invalidate(offersProvider(requestId)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pending.isNotEmpty) ...[
                  const SectionHeader(title: 'Bekleyen Teklifler'),
                  const SizedBox(height: 6),
                  ...pending.map((o) => _OfferCard(offer: o, requestId: requestId)),
                ],
                if (other.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionHeader(title: 'Diğer Teklifler'),
                  const SizedBox(height: 6),
                  ...other.map((o) => _OfferCard(offer: o, requestId: requestId)),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (e, _) => ErrorState(
          message: 'Teklifler yüklenemedi: $e',
          onRetry: () => ref.invalidate(offersProvider(requestId)),
        ),
      ),
    );
  }
}

class _OfferCard extends ConsumerStatefulWidget {
  final ServiceOffer offer;
  final int requestId;

  const _OfferCard({required this.offer, required this.requestId});

  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  bool _isAccepting = false;

  Future<void> _accept() async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Teklifi Kabul Et',
      message:
          '${widget.offer.provider?.displayName ?? 'Berber'} tarafından sunulan ₺${widget.offer.price.toStringAsFixed(2)} tutarındaki teklifi kabul etmek istiyor musunuz?',
      confirmText: 'Kabul Et',
      cancelText: 'Vazgeç',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isAccepting = true);
    try {
      await ref
          .read(activeRequestProvider(widget.requestId).notifier)
          .acceptOffer(widget.offer.id);
      if (mounted) {
        Navigator.pop(context); // go back to tracking screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teklif kabul edildi, berber atandı!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final prov = offer.provider;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.radiusCard,
        border: Border.all(
          color: offer.isPending ? AppTheme.primaryBorder : AppTheme.slate200,
          width: offer.isPending ? 1.2 : 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Provider header
          Row(
            children: [
              AppAvatar(
                name: prov?.displayName ?? 'Berber',
                imageUrl: prov?.avatarUrl,
                radius: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProviderNameRow(
                      name: prov?.displayName ?? 'Berber',
                      verified: prov?.isVerified == true,
                      tickSize: 16,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (prov?.district != null)
                      Text(
                        '${prov!.district}${prov.city != null ? ', ${prov.city}' : ''}',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              PriceText(amount: offer.price, fontSize: 18),
            ],
          ),
          const Divider(height: 20),

          // Offer details
          Row(
            children: [
              _DetailChip(
                icon: Icons.schedule_rounded,
                label: '${offer.durationMinutes} dk hizmet',
              ),
              if (offer.estimatedArrivalMin != null) ...[
                const SizedBox(width: 8),
                _DetailChip(
                  icon: Icons.directions_walk_rounded,
                  label: '~${offer.estimatedArrivalMin} dk varış',
                ),
              ],
            ],
          ),
          if (offer.message != null && offer.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              offer.message!,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.slate600,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Accept button
          if (offer.isPending)
            PrimaryButton(
              text: 'Teklifi Kabul Et',
              isLoading: _isAccepting,
              onPressed: _isAccepting ? null : _accept,
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: offer.isAccepted ? AppTheme.successLight : AppTheme.slate100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                offer.isAccepted ? 'Kabul Edildi' : 'Reddedildi',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: offer.isAccepted ? AppTheme.success : AppTheme.slate600,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.slate500),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
