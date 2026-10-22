import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import '../instant/providers/provider_instant_providers.dart';
import 'provider_profile_tab.dart' show providerDocumentsProvider;

/// Professional document (KYC) management for the provider.
///
/// Matches the web profile's "Belgeler ve Doğrulama" card: list the uploaded
/// documents with their real review status, upload a new one and remove one.
/// Files go to private storage — this screen never renders their contents.
class ProviderDocumentsScreen extends ConsumerStatefulWidget {
  const ProviderDocumentsScreen({super.key});

  @override
  ConsumerState<ProviderDocumentsScreen> createState() =>
      _ProviderDocumentsScreenState();
}

class _ProviderDocumentsScreenState
    extends ConsumerState<ProviderDocumentsScreen> {
  static const Map<String, String> _typeLabels = {
    'MASTER_CERTIFICATE': 'Ustalık Belgesi',
    'JOURNEYMAN_CERTIFICATE': 'Kalfalık Belgesi',
    'DIPLOMA': 'Diploma',
  };

  bool _busy = false;

  void _refresh() {
    ref.invalidate(providerDocumentsProvider);
    ref.invalidate(providerProfileNotifierProvider);
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppTheme.error : AppTheme.success,
      ),
    );
  }

  String _statusLabel(String? raw) => switch (raw) {
    'APPROVED' => 'Onaylandı',
    'REJECTED' => 'Reddedildi',
    'REUPLOAD_REQUIRED' => 'Yeniden Yükleyin',
    _ => 'İnceleniyor',
  };

  Color _statusColor(String? raw) => switch (raw) {
    'APPROVED' => AppTheme.success,
    'REJECTED' => AppTheme.error,
    _ => AppTheme.warning,
  };

  Future<void> _upload() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Belge Türü',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in _typeLabels.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.description_outlined,
                  color: AppTheme.primary,
                ),
                title: Text(
                  entry.value,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, entry.key),
              ),
          ],
        ),
      ),
    );
    if (type == null) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 90,
      );
      if (picked == null || !mounted) return;
      setState(() => _busy = true);
      final extension = picked.path.split('.').last.toLowerCase();
      final formData = dio.FormData.fromMap({
        'document_type': type,
        'document': await dio.MultipartFile.fromFile(
          picked.path,
          filename: 'document.$extension',
        ),
      });
      final ApiClient api = ref.read(apiClientProvider);
      await api.post('/provider/documents', data: formData);
      _refresh();
      _toast('Belge yüklendi. İnceleme sonrası durumu güncellenecek.');
    } on AppException catch (e) {
      _toast(e.message, error: true);
    } catch (_) {
      _toast('Belge yüklenemedi. Lütfen tekrar deneyin.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Belgeyi sil'),
        content: Text(
          '"${_typeLabels[doc['document_type']?.toString()] ?? 'Belge'}" kaydını silmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final ApiClient api = ref.read(apiClientProvider);
      await api.delete('/provider/documents/${doc['id']}');
      _refresh();
      _toast('Belge silindi.');
    } on AppException catch (e) {
      _toast(e.message, error: true);
    } catch (_) {
      _toast('Belge silinemedi.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(providerDocumentsProvider);
    final profile = ref.watch(providerProfileNotifierProvider).value;
    final identityStatus = profile?.identityStatus ?? 'PENDING';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        title: const Text(
          'Belgeler ve Doğrulama',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    identityStatus == 'APPROVED'
                        ? Icons.verified_user_rounded
                        : Icons.hourglass_bottom_rounded,
                    color: _statusColor(identityStatus),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kimlik Doğrulama',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          _statusLabel(identityStatus),
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(identityStatus),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Mesleki Belgeler',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            documents.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              ),
              error: (_, _) => const Text(
                'Belgeler yüklenemedi.',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.textSecondary,
                ),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return const AppCard(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Henüz mesleki belge yüklemediniz. Onaylı hesap için en az bir belge yükleyin.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final doc in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _documentCard(doc),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: _busy ? null : _upload,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded, size: 18),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              label: const Text(
                'Belge Fotoğrafı Yükle',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'JPG veya PNG belge görseli · en fazla 5 MB. Belgeleriniz gizli alanda saklanır ve yalnızca doğrulama ekibi tarafından görüntülenir.',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11.5,
                color: AppTheme.slate400,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _documentCard(Map<String, dynamic> doc) {
    final status = doc['status']?.toString();
    final reason = doc['rejection_reason']?.toString();

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _typeLabels[doc['document_type']?.toString()] ?? 'Belge',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(status),
                  ),
                ),
              ),
              IconButton(
                onPressed: _busy ? null : () => _delete(doc),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: AppTheme.slate400,
                ),
                tooltip: 'Sil',
              ),
            ],
          ),
          Text(
            doc['original_name']?.toString() ?? '',
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (doc['uploaded_at'] != null)
            Text(
              'Yüklendi: ${doc['uploaded_at'].toString().split('T').first}',
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                color: AppTheme.slate400,
              ),
            ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Red gerekçesi: $reason',
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11.5,
                color: AppTheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
