import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/web_landing_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Geçerli bir e-posta adresi giriniz.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });

    try {
      final response = await ref.read(apiClientProvider).post(
        '/auth/password/forgot',
        data: {'email': email},
      );
      final body = response.data;
      setState(() {
        _codeSent = true;
        _message = body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Şifre yenileme kodu gönderildi.';
      });
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Şifre yenileme kodu gönderilemedi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirmation = _passwordConfirmController.text;

    if (code.length != 6) {
      setState(() => _error = '6 haneli doğrulama kodunu giriniz.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Yeni şifre en az 8 karakter olmalıdır.');
      return;
    }
    if (password != confirmation) {
      setState(() => _error = 'Şifre tekrarı eşleşmiyor.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });

    try {
      final response = await ref.read(apiClientProvider).post(
        '/auth/password/reset',
        data: {
          'email': email,
          'code': code,
          'password': password,
          'password_confirmation': confirmation,
        },
      );
      final body = response.data;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            body is Map && body['message'] != null
                ? body['message'].toString()
                : 'Şifreniz yenilendi.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Şifre yenilenemedi. Lütfen tekrar deneyiniz.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Şifremi Unuttum'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: WebBrandLogo(iconSize: 40)),
                const SizedBox(height: 18),
                const Text(
                  'Şifrenizi yenileyin',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _codeSent
                      ? 'E-postanıza gelen 6 haneli kodu ve yeni şifrenizi girin.'
                      : 'Hesabınızda kayıtlı e-posta adresine tek kullanımlık kod göndereceğiz.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorLight,
                      borderRadius: AppTheme.radiusMedium,
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_message != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: AppTheme.radiusMedium,
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Text(
                      _message!,
                      style: const TextStyle(
                        color: Color(0xFF166534),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                CustomTextField(
                  controller: _emailController,
                  label: 'E-posta Adresi',
                  hint: 'ornek@mail.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined, size: 20, color: AppTheme.slate400),
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _codeController,
                    label: 'Doğrulama Kodu',
                    hint: '6 haneli kod',
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.verified_user_outlined, size: 20, color: AppTheme.slate400),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Yeni Şifre',
                    hint: 'En az 8 karakter',
                    obscureText: _obscurePassword,
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppTheme.slate400),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppTheme.slate400,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _passwordConfirmController,
                    label: 'Yeni Şifre Tekrar',
                    hint: 'Şifrenizi tekrar girin',
                    obscureText: _obscurePasswordConfirm,
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppTheme.slate400),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePasswordConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppTheme.slate400,
                      ),
                      onPressed: () => setState(() => _obscurePasswordConfirm = !_obscurePasswordConfirm),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                PrimaryButton(
                  text: _codeSent ? 'Şifreyi Yenile' : 'Kod Gönder',
                  isLoading: _busy,
                  onPressed: _codeSent ? _resetPassword : _sendCode,
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : _sendCode,
                    child: const Text('Kodu tekrar gönder'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
