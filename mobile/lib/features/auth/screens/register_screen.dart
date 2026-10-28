import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_exception.dart';
import '../../shared/screens/legal_screen.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';
import '../services/social_identity_service.dart';
import '../widgets/preauth_widgets.dart';
import '../widgets/google_auth_button.dart';
import '../widgets/verification_code_dialog.dart';
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

  String? _emailProof;
  String? _phoneProof;
  String? _socialProof;
  String? _socialEmail;
  bool _socialEmailVerified = false;
  String? _flowError;
  bool _acceptTerms = false;
  bool _acceptKvkk = false;
  bool _marketingConsent = false;
  bool _socialBusy = false;
  bool _emailBusy = false;
  bool _smsBusy = false;
  bool _smsVerificationEnabled = false;
  DateTime? _emailResendAt;
  DateTime? _smsResendAt;
  String? _emailCodeDestination;
  String? _smsCodeDestination;

  late String _selectedRole;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  bool get _hasVerifiedSocialEmail => _socialProof != null && _socialEmailVerified &&
      _socialEmail?.toLowerCase() == _emailController.text.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      if (_emailProof != null || _socialProof != null) {
        setState(() {
          _emailProof = null;
        });
      }
    });
    _phoneController.addListener(() {
      if (_phoneProof != null) setState(() => _phoneProof = null);
    });
    final role = widget.initialRole?.toUpperCase().trim();
    if (role == 'PROVIDER') {
      _selectedRole = 'PROVIDER';
    } else {
      _selectedRole = 'CUSTOMER';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadVerificationConfig());
  }

  Future<void> _loadVerificationConfig() async {
    try {
      final response = await ref.read(apiClientProvider).get('/auth/verification/config');
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      final enabled = data is Map && data['sms_enabled'] == true;
      if (mounted) {
        setState(() {
          _smsVerificationEnabled = enabled;
          if (!enabled) _phoneProof = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _smsVerificationEnabled = false);
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
    if (!_acceptTerms || !_acceptKvkk) {
      setState(() => _flowError = 'Kullanım koşulları ve KVKK onayı gereklidir.');
      return;
    }
    if (_emailController.text.trim().isNotEmpty && _emailProof == null && !_hasVerifiedSocialEmail) {
      setState(() => _flowError = 'E-posta adresinizi doğrulayın.');
      return;
    }
    if (_smsVerificationEnabled &&
        _phoneController.text.trim().isNotEmpty &&
        _phoneProof == null) {
      setState(() => _flowError = 'Telefon numaranızı SMS koduyla doğrulayın.');
      return;
    }

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
          emailVerificationToken: _emailProof,
          phoneVerificationToken: _phoneProof,
          socialPrefillToken: _socialProof,
          acceptTerms: _acceptTerms,
          acceptKvkk: _acceptKvkk,
          marketingConsent: _marketingConsent,
        );

    if (success && mounted) {
      // Return to root where AuthGate presents CustomerShell or ProviderShell
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<DateTime> _sendCode(String channel) async {
    final controller = channel == 'email' ? _emailController : _phoneController;
    final value = controller.text.trim();
    if (value.isEmpty) {
      throw AppException(message: channel == 'email' ? 'E-posta adresinizi girin.' : 'Telefon numaranızı girin.');
    }
    setState(() {
      if (channel == 'email') { _emailBusy = true; } else { _smsBusy = true; }
    });
    try {
      final response = await ref.read(apiClientProvider).post('/auth/verification/$channel/send',
          data: {channel == 'email' ? 'email' : 'phone': value});
      final data = response.data is Map ? response.data['data'] : null;
      if (!mounted || value != controller.text.trim()) {
        throw const AppException(message: 'İletişim bilgisi değişti. Yeni bir kod isteyin.');
      }
      final seconds = data is Map ? (data['resend_after_seconds'] as num?)?.toInt() ?? 60 : 60;
      final deadline = DateTime.now().add(Duration(seconds: seconds));
      setState(() {
        if (channel == 'email') {
          _emailResendAt = deadline;
          _emailCodeDestination = value;
        } else {
          _smsResendAt = deadline;
          _smsCodeDestination = value;
        }
      });
      return deadline;
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException(message: 'Doğrulama kodu gönderilemedi.');
    } finally {
      if (mounted) {
        setState(() {
          if (channel == 'email') { _emailBusy = false; } else { _smsBusy = false; }
        });
      }
    }
  }

  Future<void> _confirmCode(String channel, String code) async {
    final controller = channel == 'email' ? _emailController : _phoneController;
    final value = controller.text.trim();
    final response = await ref.read(apiClientProvider).post('/auth/verification/$channel/confirm',
        data: {channel == 'email' ? 'email' : 'phone': value, 'code': code});
    final data = response.data is Map ? response.data['data'] : null;
    final token = data is Map ? data['verification_token']?.toString() : null;
    if (token == null || token.isEmpty) {
      throw const AppException(message: 'Doğrulama yanıtı geçersiz.');
    }
    if (!mounted || value != controller.text.trim()) {
      throw const AppException(message: 'İletişim bilgisi değişti. Yeni bir kod isteyin.');
    }
    setState(() {
      if (channel == 'email') { _emailProof = token; } else { _phoneProof = token; }
    });
  }

  Future<void> _openVerification(String channel) async {
    setState(() => _flowError = null);
    try {
      final destination = (channel == 'email' ? _emailController : _phoneController).text.trim();
      final sentTo = channel == 'email' ? _emailCodeDestination : _smsCodeDestination;
      var deadline = channel == 'email' ? _emailResendAt : _smsResendAt;
      if (sentTo != destination || deadline == null || !deadline.isAfter(DateTime.now())) {
        deadline = await _sendCode(channel);
      }
      if (!mounted) return;
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => VerificationCodeDialog(
          channel: channel,
          destination: destination,
          resendAt: deadline!,
          onConfirm: (code) => _confirmCode(channel, code),
          onResend: () => _sendCode(channel),
        ),
      );
    } on AppException catch (e) {
      if (mounted) setState(() => _flowError = e.message);
    }
  }

  Future<void> _prefillSocial(String provider) async {
    setState(() { _socialBusy = true; _flowError = null; });
    try {
      final api = ref.read(apiClientProvider);
      final credential = await SocialIdentityService(api).acquire(provider);
      final response = await api.post('/auth/social/$provider/prefill', data: credential.toJson());
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is! Map || data['social_prefill_token'] == null) {
        throw const AppException(message: 'Sağlayıcı bilgileri alınamadı.');
      }
      if (!mounted) return;
      final firstName = data['first_name']?.toString() ?? '';
      final lastName = data['last_name']?.toString() ?? '';
      if (firstName.isNotEmpty) _firstNameController.text = firstName;
      if (lastName.isNotEmpty) _lastNameController.text = lastName;
      _emailController.text = data['email']?.toString() ?? '';
      setState(() {
        _socialEmail = _emailController.text.trim();
        _socialEmailVerified = data['email_verified'] == true;
        _socialProof = data['social_prefill_token'].toString();
        _emailProof = null;
      });
    } on AppException catch (e) {
      if (mounted) setState(() => _flowError = e.message);
    } catch (_) {
      if (mounted) setState(() => _flowError = 'Sağlayıcı bilgileri alınamadı.');
    } finally {
      if (mounted) setState(() => _socialBusy = false);
    }
  }

  Widget? _verificationAction(String channel) {
    if (channel == 'sms' && !_smsVerificationEnabled) return null;
    final verified = channel == 'email' ? _emailProof != null || _hasVerifiedSocialEmail : _phoneProof != null;
    final busy = channel == 'email' ? _emailBusy : _smsBusy;
    if (verified) {
      return const Tooltip(
        message: 'Doğrulandı',
        child: Icon(Icons.check_circle_rounded, color: Color(0xFF16803D), size: 22),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton(
        onPressed: busy ? null : () => _openVerification(channel),
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: busy
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Kod gönder'),
      ),
    );
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
                if (authState.errorMessage != null || _flowError != null) ...[
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
                            _flowError ?? authState.errorMessage!,
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

                // Provider identity only pre-fills editable fields. The user
                // still completes this existing form and grants each consent.
                Row(children: [
                  Expanded(child: GoogleAuthButton(
                    onPressed: _socialBusy ? null : () => _prefillSocial('google'),
                    isLoading: _socialBusy,
                    label: 'Google ile doldur',
                  )),
                  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: _socialBusy ? null : () => _prefillSocial('apple'),
                      icon: const Icon(Icons.apple, size: 18),
                      label: const Text('Apple ile doldur'),
                    )),
                  ],
                ]),
                const SizedBox(height: 16),

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
                  suffixIcon: _verificationAction('email'),
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
                  suffixIcon: _verificationAction('sms'),
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
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _acceptTerms,
                  onChanged: (value) => setState(() => _acceptTerms = value ?? false),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppTheme.primary,
                  title: const Text('Kullanım koşullarını kabul ediyorum.', style: TextStyle(fontSize: 12)),
                  secondary: IconButton(
                    tooltip: 'Kullanım koşullarını oku',
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                        const LegalDetailScreen(docKey: 'terms', fallbackTitle: 'Kullanım Koşulları'))),
                    icon: const Icon(Icons.open_in_new, size: 18),
                  ),
                ),
                CheckboxListTile(
                  value: _acceptKvkk,
                  onChanged: (value) => setState(() => _acceptKvkk = value ?? false),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppTheme.primary,
                  title: const Text('KVKK aydınlatma metnini okudum.', style: TextStyle(fontSize: 12)),
                  secondary: IconButton(
                    tooltip: 'KVKK metnini oku',
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                        const LegalDetailScreen(docKey: 'kvkk', fallbackTitle: 'KVKK Aydınlatma Metni'))),
                    icon: const Icon(Icons.open_in_new, size: 18),
                  ),
                ),
                CheckboxListTile(
                  value: _marketingConsent,
                  onChanged: (value) => setState(() => _marketingConsent = value ?? false),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppTheme.primary,
                  title: const Text('Ticari ileti almak istiyorum (isteğe bağlı).', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(height: 16),

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
