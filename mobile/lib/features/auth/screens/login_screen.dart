import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/web_landing_widgets.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authNotifierProvider.notifier).login(
          login: _loginController.text.trim(),
          password: _passwordController.text,
        );

    if (success && mounted) {
      // Pop back to AuthGate if pushed from Landing
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _navigateToRegister(String role) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterScreen(initialRole: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Header
                  const Center(
                    child: WebBrandLogo(iconSize: 42),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'Giriş Yaparak Hizmet Almaya Başlayın',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Info / Trust Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: AppTheme.radiusMedium,
                      border: Border.all(color: AppTheme.primaryBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: AppTheme.primary,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Müşteriler ve hizmet verenler tek giriş ekranından hesaplarına erişebilir.',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.darkNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Error Banner
                  if (authState.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorLight,
                        borderRadius: AppTheme.radiusMedium,
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppTheme.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              authState.errorMessage!,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: Color(0xFF991B1B),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Form Fields
                  CustomTextField(
                    controller: _loginController,
                    label: 'E-posta veya Telefon Numarası',
                    hint: 'ornek@mail.com veya 05XXXXXXXXX',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.person_outline_rounded,
                        size: 20, color: AppTheme.slate400),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Lütfen e-posta veya telefon numaranızı girin.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _passwordController,
                    label: 'Şifre',
                    hint: '••••••••',
                    obscureText: _obscurePassword,
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        size: 20, color: AppTheme.slate400),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: AppTheme.slate400,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Lütfen şifrenizi girin.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  PrimaryButton(
                    text: 'Giriş Yap',
                    isLoading: authState.isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 24),

                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const RegisterScreen(initialSocialProvider: 'google'))),
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Text('Google ile bilgileri getir'),
                  ),
                  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const RegisterScreen(initialSocialProvider: 'apple'))),
                      icon: const Icon(Icons.apple),
                      label: const Text('Apple ile bilgileri getir'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Register divider and options
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppTheme.slate200)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Henüz hesabınız yok mu?',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.slate500,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: AppTheme.slate200)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Dual Register Buttons: Customer or Provider
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _navigateToRegister('CUSTOMER'),
                          icon: const Icon(Icons.person_add_outlined, size: 16),
                          label: const Text(
                            'Hizmet Al',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primaryBorder),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _navigateToRegister('PROVIDER'),
                          icon: const Icon(Icons.content_cut_rounded, size: 16),
                          label: const Text(
                            'Hizmet Ver',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.darkNavy,
                            side: const BorderSide(color: AppTheme.slate300),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
