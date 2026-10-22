import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/common_widgets.dart';
import '../models/service_request_model.dart';
import '../providers/instant_request_provider.dart';
import 'request_tracking_screen.dart';
import 'service_selection_screen.dart';

/// Taleplerim tab — lists all customer service requests with status chips.
class RequestsTab extends ConsumerWidget {
  const RequestsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myServiceRequestsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Taleplerim'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(myServiceRequestsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: () => ref.read(myServiceRequestsProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.55,
                    child: EmptyState(
                      icon: Icons.flash_on_outlined,
                      title: 'Henüz talebiniz yok',
                      description: 'Hemen Çağır ile en yakın berberi anında kapınıza çağırabilirsiniz.',
                      actionText: 'Berber Çağır',
                      onAction: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ServiceSelectionScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () => ref.read(myServiceRequestsProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (ctx, i) => _RequestCard(request: requests[i]),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.read(myServiceRequestsProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ServiceRequestModel request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RequestTrackingScreen(requestId: request.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.radiusCard,
          border: Border.all(
            color: request.isActive ? AppTheme.primaryBorder : AppTheme.slate200,
            width: request.isActive ? 1.2 : 1,
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(status: request.status, isSmall: true),
                const Spacer(),
                Text(
                  '#${request.id}',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.slate400,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Services
            Text(
              request.services.isNotEmpty
                  ? request.services.map((s) => s.name).join(', ')
                  : 'Hizmet Talebi',
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppTheme.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Location
            if (request.locationText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.slate400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        request.locationText!,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: AppTheme.slate500,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 16),
            Row(
              children: [
                // Payment method badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.slate100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        request.paymentMethod == 'ONLINE'
                            ? Icons.credit_card_rounded
                            : Icons.payments_outlined,
                        size: 13,
                        color: AppTheme.slate600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        request.paymentMethod == 'ONLINE' ? 'Online' : 'Nakit',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.slate600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (request.offersCount > 0 && request.isOpen) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${request.offersCount} teklif',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (request.createdAt != null)
                  Text(
                    _formatDate(request.createdAt!),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppTheme.slate400,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk önce';
    if (diff.inHours < 24) return '${diff.inHours}s önce';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}
