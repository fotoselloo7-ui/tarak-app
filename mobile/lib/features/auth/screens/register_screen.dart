import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/preauth_widgets.dart';
import '../widgets/web_landing_widgets.dart';
import 'login_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final String? initialRole;

  const RegisterScreen({
    super.key,
    this.initialRole,
  });

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _businessNameController = TextEditingController();

  late String _selectedRole;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  @override
  void initState() {
    super.initState();
    final role = widget.initialRole?.toUpperCase().trim();
    if (role == 'PROVIDER') {
      _selectedRole = 'PROVIDER';
    } else {
      _selectedRole = 'CUSTOMER';
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authNotifierProvider.notifier).register(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          role: _selectedRole,
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          passwordConfirmation: _passwordConfirmController.text,
          businessName: _selectedRole == 'PROVIDER'
              ? _businessNameController.text.trim()
              : null,
        );

    if (success && mounted) {
      // Return to root where AuthGate presents CustomerShell or ProviderShell
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _selectedRole == 'PROVIDER'
              ? 'Hizmet Veren Kaydı'
              : 'Müşteri Kaydı',
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkNavy,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Logo
                const Center(
                  child: WebBrandLogo(iconSize: 36),
                ),
                const SizedBox(height: 16),

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
                  const SizedBox(height: 16),
                ],

                // Role Selection Cards
                const Text(
                  'Hesap Türünü Belirleyin',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkNavy,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: RoleSelectionCard(
                        title: 'Müşteri',
                        badgeText: 'Hizmet Al',
                        subtitle: 'Evde ve ofiste randevu alın',
                        icon: Icons.person_rounded,
                        isSelected: _selectedRole == 'CUSTOMER',
                        onTap: () => setState(() => _selectedRole = 'CUSTOMER'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RoleSelectionCard(
                        title: 'Hizmet Veren',
                        badgeText: 'Kazanç Sağla',
                        subtitle: 'Berber & kuaför olarak çalışın',
                        icon: Icons.content_cut_rounded,
                        isSelected: _selectedRole == 'PROVIDER',
                        onTap: () => setState(() => _selectedRole = 'PROVIDER'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Dynamic Role Info / Highlights
                RoleInfoBox(role: _selectedRole),
                const SizedBox(height: 20),

                // Name and Surname Inputs
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _firstNameController,
                        label: 'Ad',
                        hint: 'Adınız',
                        prefixIcon: const Icon(Icons.person_outline_rounded,
                            size: 18, color: AppTheme.slate400),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Ad gereklidir' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: _lastNameController,
                        label: 'Soyad',
                        hint: 'Soyadınız',
                        prefixIcon: const Icon(Icons.person_outline_rounded,
                            size: 18, color: AppTheme.slate400),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Soyad gereklidir' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // If Provider: Business Name field
                if (_selectedRole == 'PROVIDER') ...[
                  CustomTextField(
                    controller: _businessNameController,
                    label: 'İşletme / Salon Adı (İsteğe Bağlı)',
                    hint: 'Örn: Usta Eller Berber Salonu',
                    prefixIcon: const Icon(Icons.storefront_outlined,
                        size: 18, color: AppTheme.slate400),
                  ),
                  const SizedBox(height: 16),
                ],

                // Email
                CustomTextField(
                  controller: _emailController,
                  label: 'E-posta Adresi',
                  hint: 'ornek@mail.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined,
                      size: 18, color: AppTheme.slate400),
                  validator: (v) {
                    if ((v == null || v.trim().isEmpty) &&
                        _phoneController.text.trim().isEmpty) {
                      return 'E-posta veya telefon numarasından en az biri girilmelidir.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone
                CustomTextField(
                  controller: _phoneController,
                  label: 'Telefon Numarası',
                  hint: '05XXXXXXXXX',
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(Icons.phone_outlined,
                      size: 18, color: AppTheme.slate400),
                  validator: (v) {
                    if ((v == null || v.trim().isEmpty) &&
                        _emailController.text.trim().isEmpty) {
                      return 'Telefon veya e-posta girilmelidir.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                CustomTextField(
                  controller: _passwordController,
                  label: 'Şifre',
                  hint: 'En az 8 karakter',
                  obscureText: _obscurePassword,
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      size: 18, color: AppTheme.slate400),
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
                  validator: (v) {
                    if (v == null || v.length < 8) {
                      return 'Şifre en az 8 karakter olmalıdır.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Confirm
                CustomTextField(
                  controller: _passwordConfirmController,
                  label: 'Şifre Tekrar',
                  hint: 'Şifrenizi tekrar girin',
                  obscureText: _obscurePasswordConfirm,
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      size: 18, color: AppTheme.slate400),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePasswordConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppTheme.slate400,
                    ),
                    onPressed: () => setState(
                        () => _obscurePasswordConfirm = !_obscurePasswordConfirm),
                  ),
                  validator: (v) {
                    if (v != _passwordController.text) {
                      return 'Şifre onayı eşleşmiyor.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Submit Button
                PrimaryButton(
                  text: _selectedRole == 'PROVIDER'
                      ? 'Hizmet Veren Olarak Kaydol'
                      : 'Müşteri Olarak Kaydol',
                  isLoading: authState.isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 20),

                // Direct to Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Zaten bir hesabınız var mı? ',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Giriş Yapın',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: AppTheme.primary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
