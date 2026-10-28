import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/social_identity_service.dart';

Future<void> showSocialAccountLinkSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _SocialAccountLinkSheet(),
    );

class _SocialAccountLinkSheet extends ConsumerStatefulWidget {
  const _SocialAccountLinkSheet();
  @override
  ConsumerState<_SocialAccountLinkSheet> createState() => _SocialAccountLinkSheetState();
}

class _SocialAccountLinkSheetState extends ConsumerState<_SocialAccountLinkSheet> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _link(String provider) async {
    if (_password.text.isEmpty || _busy) return;
    setState(() { _busy = true; _message = null; });
    try {
      final api = ref.read(apiClientProvider);
      final credential = await SocialIdentityService(api).acquire(provider);
      await api.post('/auth/social/$provider/link', data: {
        ...credential.toJson(), 'current_password': _password.text,
      });
      if (mounted) {
        _password.clear();
        setState(() => _message = 'Sağlayıcı hesabınız güvenle bağlandı.');
      }
    } on AppException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) setState(() => _message = 'Hesap bağlantısı tamamlanamadı. Yeniden deneyin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(
    padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Google / Apple hesabı bağla', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      const Text('Bağlantıyı onaylamak için mevcut Tarak şifrenizi girin, ardından sağlayıcınızı seçin.'),
      const SizedBox(height: 16),
      TextField(controller: _password, obscureText: true, enabled: !_busy,
        onChanged: (_) => setState(() {}), autofillHints: const [AutofillHints.password],
        decoration: const InputDecoration(labelText: 'Mevcut şifreniz')),
      const SizedBox(height: 16),
      OutlinedButton(onPressed: _busy || _password.text.isEmpty ? null : () => _link('google'), child: const Text('Google hesabını bağla')),
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
        OutlinedButton(onPressed: _busy || _password.text.isEmpty ? null : () => _link('apple'), child: const Text('Apple hesabını bağla')),
      if (_busy) const LinearProgressIndicator(),
      if (_message != null) Padding(padding: const EdgeInsets.only(top: 12),
        child: Text(_message!, style: const TextStyle(color: AppTheme.textSecondary))),
    ])),
  ));
}
