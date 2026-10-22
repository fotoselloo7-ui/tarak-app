import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../widgets/common_widgets.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ApiClient api = ref.read(apiClientProvider);
      final res = await api.get('/auth/sessions');
      final data = res.data is Map ? res.data['data'] : null;
      if (data is! List) {
        throw const AppException(message: 'Oturumlar yüklenemedi.');
      }
      final rows = data
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() => _rows = rows);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AppException
              ? error.message
              : 'Oturumlar yüklenemedi. Lütfen tekrar deneyin.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirmRevoke({required bool all}) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(all ? 'Diğer oturumları kapat' : 'Oturumu kapat'),
            content: Text(
              all
                  ? 'Diğer cihazlardaki oturumlar kapatılacak. Bu cihazdaki oturumun açık kalacak.'
                  : 'Seçilen cihazın oturumu kapatılacak. Cihaz tekrar giriş yapabilecek.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Oturumu Kapat'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _revoke(int id) async {
    if (_busy || _loading) return;
    if (!await _confirmRevoke(all: false) || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).delete('/auth/sessions/$id');
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AppException
                  ? error.message
                  : 'Oturum kapatılamadı. Lütfen tekrar deneyin.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeOthers() async {
    if (_busy || _loading) return;
    if (!await _confirmRevoke(all: true) || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).post('/auth/sessions/revoke-others');
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AppException
                  ? error.message
                  : 'Oturumlar kapatılamadı. Lütfen tekrar deneyin.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _lastUsed(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return 'Henüz kullanılmadı';
    String pad(int n) => n.toString().padLeft(2, '0');
    return 'Son kullanım: ${pad(date.day)}.${pad(date.month)}.${date.year} ${pad(date.hour)}:${pad(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final others = _rows.where((r) => r['is_current'] != true).length;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Cihaz Oturumları')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : Column(
              children: [
                Expanded(
                  child: _rows.isEmpty
                      ? const Center(child: Text('Aktif oturum bulunamadı.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _rows.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final r = _rows[i];
                            final isCurrent = r['is_current'] == true;
                            return Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                leading: const Icon(
                                  Icons.smartphone_rounded,
                                  color: AppTheme.primary,
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${r['name'] ?? 'Cihaz'}',
                                        style: const TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (isCurrent)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.successLight,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Text(
                                          'Bu cihaz',
                                          style: TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.success,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  _lastUsed(r['last_used_at']),
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                trailing: isCurrent
                                    ? null
                                    : TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _revoke(r['id'] as int),
                                        child: const Text(
                                          'Kapat',
                                          style: TextStyle(
                                            color: AppTheme.error,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                ),
                if (others > 0)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _revokeOthers,
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Diğer Tüm Oturumları Kapat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.darkNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
