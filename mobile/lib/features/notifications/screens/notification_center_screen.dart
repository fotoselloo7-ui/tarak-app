import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../core/widgets/verified_tick.dart';

Future<void> openNotificationCenter(BuildContext context, WidgetRef ref) async {
  final payload = await Navigator.of(context).push<Map<String, dynamic>>(
    MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
  );
  if (context.mounted && payload != null) {
    ref.read(pushNotificationServiceProvider).handleIncomingPayload(payload);
  }
}

class NotificationCenterButton extends ConsumerWidget {
  final Color? color;

  const NotificationCenterButton({super.key, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Bildirimler',
      icon: Icon(Icons.notifications_outlined, color: color),
      onPressed: () => openNotificationCenter(context, ref),
    );
  }
}

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _error;
  int _page = 0;
  int _lastPage = 1;
  int? _openingId;
  bool _unreadOnly = false;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading || _openingId != null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .get(
            '/notifications',
            queryParameters: {
              'page': more ? _page + 1 : 1,
              'per_page': 20,
              if (_unreadOnly) 'unread': true,
            },
          );
      final data = Map<String, dynamic>.from(response.data as Map);
      final rows = (data['data'] as List).map(
        (row) => Map<String, dynamic>.from(row as Map),
      );
      final meta = Map<String, dynamic>.from(data['meta'] as Map);
      // A notification can move between pages when a new one arrives.
      final byId = <int, Map<String, dynamic>>{
        if (more)
          for (final item in _items) item['id'] as int: item,
        for (final row in rows) row['id'] as int: row,
      };
      if (!mounted) return;
      setState(() {
        _items = byId.values.toList();
        _page = meta['current_page'] as int;
        _lastPage = meta['last_page'] as int;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AppException
              ? error.message
              : 'Bildirimler yüklenemedi. Lütfen tekrar deneyin.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    if (_openingId != null || _loading) return;
    setState(() => _openingId = item['id'] as int);
    try {
      if (item['read_at'] == null) {
        await ref
            .read(apiClientProvider)
            .post('/notifications/${item['id']}/read');
      }
      final metadata = item['metadata'];
      final payload = <String, dynamic>{
        'type': item['type'],
        'resource_type': item['resource_type'],
        'resource_id': item['resource_id'],
        if (metadata is Map) 'conversation_id': metadata['conversation_id'],
      };
      if (mounted) Navigator.of(context).pop(payload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AppException
                  ? error.message
                  : 'Bildirim açılamadı. Lütfen tekrar deneyin.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  Future<void> _markAllRead() async {
    if (_loading || _markingAll || _openingId != null) return;
    setState(() => _markingAll = true);
    try {
      await ref.read(apiClientProvider).post('/notifications/read-all');
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AppException
                  ? error.message
                  : 'Bildirimler okundu olarak işaretlenemedi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${pad(date.day)}.${pad(date.month)}.${date.year} '
        '${pad(date.hour)}:${pad(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          IconButton(
            tooltip: 'Tümünü Okundu İşaretle',
            onPressed: _loading || _markingAll ? null : _markAllRead,
            icon: const Icon(Icons.done_all),
          ),
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final unread in [false, true])
                    ChoiceChip(
                      label: Text(unread ? 'Okunmamış' : 'Tümü'),
                      selected: _unreadOnly == unread,
                      onSelected: _loading || _markingAll
                          ? null
                          : (_) {
                              setState(() {
                                _unreadOnly = unread;
                                _items = [];
                              });
                              _load();
                            },
                    ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              ErrorState(message: _error!, onRetry: () => _load()),
            if (!_loading && _error == null && _items.isEmpty)
              EmptyState(
                icon: Icons.notifications_none_rounded,
                title: _unreadOnly
                    ? 'Okunmamış bildiriminiz yok'
                    : 'Henüz bildiriminiz yok',
                description: _unreadOnly
                    ? 'Tüm bildirimlerinizi okudunuz.'
                    : 'İşlem ve mesaj bildirimleriniz burada görünür.',
              ),
            for (final item in _items)
              if (item['type'] == 'PROVIDER_CAMPAIGN' && item['metadata'] is Map)
                _CampaignTile(
                  key: ValueKey('notification-${item['id']}'),
                  item: item,
                  enabled: _openingId == null && !_loading,
                  opening: _openingId == item['id'],
                  date: _date(item['created_at']),
                  onTap: () => _open(item),
                )
              else
              ListTile(
                key: ValueKey('notification-${item['id']}'),
                enabled: _openingId == null && !_loading,
                isThreeLine: true,
                leading: _openingId == item['id']
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        item['read_at'] == null
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_none_outlined,
                        color: item['read_at'] == null
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                title: Text(
                  item['title']?.toString() ?? 'Bildirim',
                  style: TextStyle(
                    fontWeight: item['read_at'] == null
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
                subtitle: Text(
                  '${item['message'] ?? ''}\n${_date(item['created_at'])}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(item),
              ),
            if (_page < _lastPage && !_loading && _error == null)
              TextButton(
                onPressed: () => _load(more: true),
                child: const Text('Daha fazla göster'),
              ),
          ],
        ),
      ),
    );
  }
}

/// A provider's discount campaign: the percentage up front, who offers it (with the verified tick), the copy they
/// wrote and how long it is valid. Tapping opens the provider's profile.
class _CampaignTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool enabled;
  final bool opening;
  final String date;
  final VoidCallback onTap;
  const _CampaignTile({super.key, required this.item, required this.enabled, required this.opening, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = Map<String, dynamic>.from(item['metadata'] as Map);
    final unread = item['read_at'] == null;
    final until = DateTime.tryParse('${meta['valid_until'] ?? ''}')?.toLocal();
    const months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        color: unread ? const Color(0x0FFF5722) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
              child: opening
                  ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                  : Padding(
                      padding: const EdgeInsets.all(4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('%${meta['discount_percent']}', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                            const Text('İNDİRİM', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5, height: 1.1)),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProviderNameRow(
                    name: '${meta['provider_name'] ?? 'Hizmet Veren'}',
                    verified: meta['is_verified'] == true,
                    tickSize: 15,
                    style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 14, fontWeight: unread ? FontWeight.w800 : FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text('${meta['headline'] ?? ''}', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  Text('${meta['description'] ?? ''}', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12.5, color: AppTheme.slate600, height: 1.35)),
                  const SizedBox(height: 4),
                  Text(
                    '${until == null ? '' : '${until.day} ${months[until.month - 1]} tarihine kadar geçerli · '}Profili gör',
                    style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary),
                  ),
                  Text(date, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 10.5, color: AppTheme.slate400)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.slate400),
          ],
        ),
      ),
    );
  }
}
