import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

const _acceptedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
const _maxBytes = 4 * 1024 * 1024; // 4MB, matches backend cap

String _initialsOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'K';
  final parts = trimmed.split(RegExp(r'\s+'));
  final letters = parts.take(2).map((w) => w.isNotEmpty ? w[0] : '').join();
  return letters.toUpperCase();
}

/// Canonical avatar picker: shows the current avatar (or an initials
/// fallback consistent with the design system — never a stock/demo photo),
/// a camera button to pick+upload from the gallery, and a remove button.
/// Updates the shared auth user avatar app-wide on success.
class AvatarPicker extends ConsumerStatefulWidget {
  final String? avatarUrl;
  final String name;
  final double radius;

  const AvatarPicker({super.key, required this.avatarUrl, required this.name, this.radius = 44});

  @override
  ConsumerState<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<AvatarPicker> {
  bool _uploading = false;
  String? _localPreviewPath;

  Future<void> _pickAndUpload() async {
    setState(() => _uploading = false);
    final XFile? picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final ext = picked.path.split('.').last.toLowerCase();
    if (!_acceptedExtensions.contains(ext)) {
      _showError('Yalnızca JPG, PNG veya WEBP formatı kabul edilir.');
      return;
    }
    final file = File(picked.path);
    final size = await file.length();
    if (size > _maxBytes) {
      _showError('Görsel boyutu en fazla 4 MB olabilir.');
      return;
    }

    setState(() {
      _uploading = true;
      _localPreviewPath = picked.path;
    });

    try {
      final ApiClient api = ref.read(apiClientProvider);
      final formData = dio.FormData.fromMap({
        'avatar': await dio.MultipartFile.fromFile(picked.path, filename: 'avatar.$ext'),
      });
      final res = await api.post('/profile/avatar', data: formData);
      final data = res.data is Map ? res.data['data'] : null;
      final newUrl = data is Map ? data['avatar_url']?.toString() : null;

      ref.read(authNotifierProvider.notifier).updateAvatarUrl(newUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil fotoğrafınız güncellendi.'), backgroundColor: AppTheme.success),
        );
      }
    } on AppException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Yükleme başarısız oldu.');
    } finally {
      if (mounted) setState(() { _uploading = false; _localPreviewPath = null; });
    }
  }

  Future<void> _remove() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final ApiClient api = ref.read(apiClientProvider);
      await api.delete('/profile/avatar');
      ref.read(authNotifierProvider.notifier).updateAvatarUrl(null);
    } catch (_) {
      _showError('Kaldırma işlemi başarısız oldu.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.radius * 2;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryLight,
              image: _localPreviewPath != null
                  ? DecorationImage(image: FileImage(File(_localPreviewPath!)), fit: BoxFit.cover)
                  : (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                      ? DecorationImage(image: NetworkImage(widget.avatarUrl!), fit: BoxFit.cover)
                      : null),
            ),
            child: (_localPreviewPath == null && (widget.avatarUrl == null || widget.avatarUrl!.isEmpty))
                ? Center(
                    child: Text(
                      _initialsOf(widget.name),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: widget.radius * 0.6,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                  )
                : null,
          ),
          if (_uploading)
            Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black38),
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
            ),
          Positioned(
            bottom: -2,
            right: -2,
            child: GestureDetector(
              onTap: _uploading ? null : _pickAndUpload,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
              ),
            ),
          ),
          if (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty && !_uploading)
            Positioned(
              bottom: -2,
              left: -2,
              child: GestureDetector(
                onTap: _remove,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.error, width: 1.5),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, size: 13, color: AppTheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
