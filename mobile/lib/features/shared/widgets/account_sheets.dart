import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tarak_rating.dart';
import '../../auth/providers/auth_provider.dart';
import 'geo_select_fields.dart';

TextStyle _t(double s, {FontWeight w = FontWeight.w500, Color c = AppTheme.textPrimary}) =>
    TextStyle(fontFamily: AppTheme.fontFamily, fontSize: s, fontWeight: w, color: c);

InputDecoration _dec(String label) => InputDecoration(
      labelText: label,
      counterText: '',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );

Future<void> showChangePasswordSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _ChangePasswordSheet(),
  );
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_current.text.isEmpty) return setState(() => _error = 'Mevcut şifrenizi giriniz.');
    if (_next.text.length < 8) return setState(() => _error = 'Yeni şifre en az 8 karakter olmalıdır.');
    if (_next.text != _confirm.text) return setState(() => _error = 'Yeni şifre tekrarı eşleşmiyor.');
    if (_next.text == _current.text) return setState(() => _error = 'Yeni şifre mevcut şifreden farklı olmalıdır.');

    setState(() => _saving = true);
    try {
      final ApiClient api = ref.read(apiClientProvider);
      await api.post('/auth/change-password', data: {
        'current_password': _current.text,
        'new_password': _next.text,
        'new_password_confirmation': _confirm.text,
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifreniz başarıyla güncellendi.'), backgroundColor: AppTheme.success),
      );
    } on AppException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Şifre güncellenemedi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Şifre Değiştir', style: _t(18, w: FontWeight.w800)),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.errorLight, borderRadius: BorderRadius.circular(10)),
              child: Text(_error!, style: _t(13, c: AppTheme.error)),
            ),
            const SizedBox(height: 10),
          ],
          TextField(controller: _current, obscureText: _obscure, decoration: _dec('Mevcut Şifre')),
          const SizedBox(height: 12),
          TextField(
            controller: _next,
            obscureText: _obscure,
            decoration: _dec('Yeni Şifre').copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _confirm, obscureText: _obscure, decoration: _dec('Yeni Şifre (Tekrar)')),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_saving ? 'Kaydediliyor...' : 'Şifreyi Güncelle', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Leave a review for a completed appointment or service request.
Future<bool?> showLeaveReviewSheet(
  BuildContext context, {
  int? appointmentId,
  int? serviceRequestId,
  String? providerName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _LeaveReviewSheet(
      appointmentId: appointmentId,
      serviceRequestId: serviceRequestId,
      providerName: providerName,
    ),
  );
}

class _LeaveReviewSheet extends ConsumerStatefulWidget {
  final int? appointmentId;
  final int? serviceRequestId;
  final String? providerName;
  const _LeaveReviewSheet({this.appointmentId, this.serviceRequestId, this.providerName});

  @override
  ConsumerState<_LeaveReviewSheet> createState() => _LeaveReviewSheetState();
}

class _LeaveReviewSheetState extends ConsumerState<_LeaveReviewSheet> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating < 1) return setState(() => _error = 'Lütfen bir puan seçin.');
    setState(() { _saving = true; _error = null; });
    try {
      final ApiClient api = ref.read(apiClientProvider);
      await api.post('/customer/reviews', data: {
        if (widget.appointmentId != null) 'appointment_id': widget.appointmentId,
        if (widget.serviceRequestId != null) 'service_request_id': widget.serviceRequestId,
        'rating': _rating,
        if (_comment.text.trim().isNotEmpty) 'comment': _comment.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Değerlendirmeniz kaydedildi.'), backgroundColor: AppTheme.success),
      );
    } on AppException catch (e) {
      setState(() { _saving = false; _error = e.message; });
    } catch (_) {
      setState(() { _saving = false; _error = 'Değerlendirme kaydedilemedi.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Değerlendir', style: _t(18, w: FontWeight.w800)),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
          if (widget.providerName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${widget.providerName} için deneyiminizi paylaşın.', style: _t(13, c: AppTheme.textSecondary)),
            ),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.errorLight, borderRadius: BorderRadius.circular(10)),
              child: Text(_error!, style: _t(13, c: AppTheme.error)),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final idx = i + 1;
              return IconButton(
                onPressed: () => setState(() => _rating = idx),
                tooltip: 'Tarak Puanı $idx / 5',
                icon: TarakMark(size: 36, muted: idx > _rating),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLines: 3,
            maxLength: 1000,
            decoration: _dec('Yorumunuz (opsiyonel)'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_saving ? 'Gönderiliyor...' : 'Değerlendirmeyi Gönder', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic profile editor. [fields] maps a label to an initial value; the returned
/// payload uses the same keys. Persists via [endpoint] with PUT.
Future<bool?> showProfileEditSheet(
  BuildContext context, {
  required String title,
  required String endpoint,
  required List<ProfileEditField> fields,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _ProfileEditSheet(title: title, endpoint: endpoint, fields: fields),
  );
}

/// How a [ProfileEditField] is edited. [province] + [district] render as the il / ilçe pickers (all of Turkey,
/// bundled with the app) instead of free text; the value saved is still the plain name under the field's key.
enum ProfileEditKind { text, province, district }

class ProfileEditField {
  final String key;
  final String label;
  final String initial;
  final TextInputType keyboardType;
  final int maxLength;
  final ProfileEditKind kind;

  const ProfileEditField({
    required this.key,
    required this.label,
    this.initial = '',
    this.keyboardType = TextInputType.text,
    this.maxLength = 120,
    this.kind = ProfileEditKind.text,
  });
}

class _ProfileEditSheet extends ConsumerStatefulWidget {
  final String title;
  final String endpoint;
  final List<ProfileEditField> fields;

  const _ProfileEditSheet({required this.title, required this.endpoint, required this.fields});

  @override
  ConsumerState<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<_ProfileEditSheet> {
  late final Map<String, TextEditingController> _controllers;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controllers = {for (final f in widget.fields) f.key: TextEditingController(text: f.initial)};
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final payload = <String, dynamic>{};
      for (final f in widget.fields) {
        final v = _controllers[f.key]!.text.trim();
        if (f.keyboardType == TextInputType.number) {
          payload[f.key] = int.tryParse(v) ?? 0;
        } else {
          payload[f.key] = v;
        }
      }
      await api.put(widget.endpoint, data: payload);
      // Refresh the cached auth user so name/etc. update across the app.
      await ref.read(authNotifierProvider.notifier).restoreSession();
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bilgileriniz güncellendi.'), backgroundColor: AppTheme.success),
      );
    } on AppException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Bilgiler güncellenemedi.';
      });
    }
  }

  /// Text inputs, with the province field (and the district field next to it) turned into the il / ilçe pickers.
  List<Widget> _buildFields() {
    ProfileEditField? provinceField;
    ProfileEditField? districtField;
    for (final f in widget.fields) {
      if (f.kind == ProfileEditKind.province) provinceField ??= f;
      if (f.kind == ProfileEditKind.district) districtField ??= f;
    }
    final geoPair = provinceField != null && districtField != null;

    final widgets = <Widget>[];
    for (final f in widget.fields) {
      if (geoPair && f.kind == ProfileEditKind.district) continue; // rendered together with the province
      final Widget input;
      if (geoPair && f.kind == ProfileEditKind.province) {
        input = GeoSelectFields(
          province: _controllers[provinceField.key]!,
          district: _controllers[districtField.key]!,
          provinceLabel: provinceField.label,
          districtLabel: districtField.label,
          decoration: _dec,
        );
      } else {
        input = TextField(
          controller: _controllers[f.key],
          keyboardType: f.keyboardType,
          maxLength: f.maxLength,
          decoration: _dec(f.label),
        );
      }
      widgets.add(Padding(padding: const EdgeInsets.only(bottom: 12), child: input));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.title, style: _t(18, w: FontWeight.w800)),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 8),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.errorLight, borderRadius: BorderRadius.circular(10)),
              child: Text(_error!, style: _t(13, c: AppTheme.error)),
            ),
            const SizedBox(height: 10),
          ],
          ..._buildFields(),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Self-service account deletion/deactivation. Requires password + a typed
/// "SİL" confirmation. On success, revokes the session locally via
/// [AuthNotifier.logout] (best-effort server call; token is already revoked
/// server-side by the delete endpoint).
Future<void> showDeleteAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _DeleteAccountSheet(),
  );
}

class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();

  @override
  ConsumerState<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final _password = TextEditingController();
  final _confirmText = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmText.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_password.text.isEmpty) return setState(() => _error = 'Devam etmek için şifrenizi giriniz.');
    if (_confirmText.text.trim().toUpperCase() != 'SİL') {
      return setState(() => _error = 'Onaylamak için kutuya "SİL" yazınız.');
    }

    setState(() => _saving = true);
    try {
      final ApiClient api = ref.read(apiClientProvider);
      await api.delete('/profile/account', data: {'current_password': _password.text});
      if (!mounted) return;
      setState(() => _done = true);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      Navigator.pop(context);
      await ref.read(authNotifierProvider.notifier).logout();
    } on AppException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Hesabınız silinemedi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 48),
            const SizedBox(height: 12),
            Text('Hesabınız kapatıldı.', style: _t(16, w: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Çıkış yapılıyor...', style: _t(12, c: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Hesabımı Sil', style: _t(18, w: FontWeight.w800, c: AppTheme.error)),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.errorLight, borderRadius: BorderRadius.circular(12)),
            child: Text(
              'Bu işlem geri alınamaz. Hesabınız kapatılır, kişisel bilgileriniz anonimleştirilir ve bir daha giriş yapamazsınız. '
              'Devam eden bir randevunuz, talebiniz veya uyuşmazlığınız varsa önce onu tamamlamanız ya da destek ekibiyle çözüme kavuşturmanız gerekir.',
              style: _t(11.5, c: AppTheme.error),
            ),
          ),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.errorLight, borderRadius: BorderRadius.circular(10)),
              child: Text(_error!, style: _t(13, c: AppTheme.error)),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _password,
            obscureText: _obscure,
            decoration: _dec('Şifreniz').copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _confirmText, decoration: _dec('Onaylamak için "SİL" yazınız')),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_saving ? 'Siliniyor...' : 'Hesabımı Kalıcı Olarak Sil', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
