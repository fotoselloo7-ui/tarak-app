import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'registration_location_screen.dart';
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
  final String? initialSocialProvider;

  const RegisterScreen({
    super.key,
    this.initialRole,
    this.initialSocialProvider,
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
  final _otpCtrl = TextEditingController();
  final _smsOtpCtrl = TextEditingController();
  String? _smsChallengeId;
  String? _smsProof;
  String? _verifiedPhone;
  String? _challengeId;
  String? _verificationProof;
  String? _verifiedEmail;
  Map<String,dynamic>? _address;
  bool _termsAccepted = false;
  bool _privacyAcknowledged = false;
  bool _marketingConsent = false;
  bool _busyAction = false;
  String? _statusMessage;
  static const googleClientId = String.fromEnvironment('GOOGLE_OAUTH_WEB_CLIENT_ID');
  static Future<void>? _googleInitialize;

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
    if (widget.initialSocialProvider != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _socialPreview(widget.initialSocialProvider!);
      });
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
    _otpCtrl.dispose();
    _smsOtpCtrl.dispose();
    super.dispose();
  }


  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _statusMessage = 'Geçerli e-posta adresinizi girin.');
      return;
    }
    setState(() { _busyAction = true; _statusMessage = null; _verificationProof = null; });
    try {
      final result = await ref.read(apiClientProvider).post('/auth/registration/start', data: {'email': email});
      final data = (result.data as Map<String,dynamic>)['data'] as Map<String,dynamic>;
      if (!mounted) return;
      setState(() {
        _challengeId = data['challenge_id'].toString();
        _statusMessage = 'Altı haneli kod gönderildi. Gelen kutunuzu kontrol edin.';
      });
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Kod gönderilemedi: $e');
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _confirmCode() async {
    if (_challengeId == null) return;
    setState(() { _busyAction = true; _statusMessage = null; });
    try {
      final email = _emailController.text.trim();
      final result = await ref.read(apiClientProvider).post('/auth/registration/confirm', data: {
        'challenge_id': _challengeId, 'email': email, 'code': _otpCtrl.text.trim(),
      });
      final data = (result.data as Map<String,dynamic>)['data'] as Map<String,dynamic>;
      if (!mounted) return;
      setState(() {
        _verifiedEmail = email;
        _verificationProof = data['registration_proof'].toString();
        _statusMessage = 'E-posta doğrulandı. Diğer bilgileri kontrol edip kaydı onaylayın.';
      });
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Kod onaylanamadı: $e');
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _socialPreview(String provider) async {
    setState(() { _busyAction = true; _statusMessage = null; });
    try {
      String token;
      String? givenName;
      String? familyName;
      if (provider == 'google') {
        if (googleClientId.isEmpty) throw StateError('Google OAuth Client ID eksik.');
        _googleInitialize ??= GoogleSignIn.instance.initialize(serverClientId: googleClientId);
        await _googleInitialize;
        final user = await GoogleSignIn.instance.authenticate();
        token = user.authentication.idToken ?? '';
      } else {
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        );
        token = credential.identityToken ?? '';
        givenName = credential.givenName;
        familyName = credential.familyName;
      }
      if (token.isEmpty) throw StateError('Kimlik bilgisi alınamadı.');
      final response = await ref.read(apiClientProvider).post('/auth/social/preview', data: {
        'provider': provider, 'identity_token': token,
        if (givenName != null) 'first_name': givenName,
        if (familyName != null) 'last_name': familyName,
      });
      final data = (response.data as Map<String,dynamic>)['data'] as Map<String,dynamic>;
      if (!mounted) return;
      setState(() {
        _firstNameController.text = (data['first_name'] ?? '').toString();
        _lastNameController.text = (data['last_name'] ?? '').toString();
        _emailController.text = (data['email'] ?? '').toString();
        _challengeId = null;
        _verificationProof = null;
        _verifiedEmail = null;
        _statusMessage = 'Bilgiler forma getirildi. Düzenleyebilirsiniz; hesap açılmadı.';
      });
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Kimlik bilgisi getirilemedi: $e');
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }


  Future<void> _sendSmsCode() async {
    if (_phoneController.text.trim().isEmpty) return;
    setState(() { _busyAction = true; _statusMessage = null; _smsProof = null; });
    try {
      final response = await ref.read(apiClientProvider).post('/auth/registration/sms/start',
        data: {'phone': _phoneController.text.trim()});
      final body = (response.data as Map<String,dynamic>)['data'] as Map<String,dynamic>;
      if (!mounted) return;
      setState(() { _smsChallengeId = body['challenge_id'].toString(); _statusMessage = 'SMS doğrulama kodu gönderildi.'; });
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'SMS gönderilemedi. E-posta doğrulamasıyla devam edebilirsiniz. $e');
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _confirmSmsCode() async {
    if (_smsChallengeId == null) return;
    setState(() => _busyAction = true);
    try {
      final phone = _phoneController.text.trim();
      final response = await ref.read(apiClientProvider).post('/auth/registration/sms/confirm', data: {
        'phone': phone, 'challenge_id': _smsChallengeId, 'code': _smsOtpCtrl.text.trim(),
      });
      final body = (response.data as Map<String,dynamic>)['data'] as Map<String,dynamic>;
      if (!mounted) return;
      setState(() { _smsProof = body['sms_proof'].toString(); _verifiedPhone = phone;
        _statusMessage = 'Telefon numarası doğrulandı.'; });
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'SMS kodu geçersiz: $e');
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _chooseAddress() async {
    final chosen = await Navigator.of(context).push<Map<String,dynamic>>(
      MaterialPageRoute(builder: (_) => RegistrationLocationScreen(initial: _address)),
    );
    if (chosen != null && mounted) setState(() => _address = chosen);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_verificationProof == null || _verifiedEmail != _emailController.text.trim()) {
      setState(() => _statusMessage = 'E-postanıza gelen doğrulama kodunu önce onaylayın.');
      return;
    }
    if (!_termsAccepted || !_privacyAcknowledged) {
      setState(() => _statusMessage = 'Kullanım koşulları ve KVKK bilgilendirmesi zorunludur.');
      return;
    }
    if (_address == null) {
      setState(() => _statusMessage = 'Lütfen adresinizi girin.');
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
          registrationProof: _verificationProof,
          smsProof: _verifiedPhone == _phoneController.text.trim() ? _smsProof : null,
          address: _address,
          termsAccepted: _termsAccepted,
          privacyAcknowledged: _privacyAcknowledged,
          marketingConsent: _marketingConsent,
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

                if (_statusMessage != null) ...[
                  Container(padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(12)),
                    child: Text(_statusMessage!, style: const TextStyle(fontSize: 12, color: AppTheme.darkNavy))),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(onPressed: _busyAction ? null : () => _socialPreview('google'),
                  icon: const Icon(Icons.account_circle_outlined), label: const Text('Google ile bilgileri doldur')),
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: _busyAction ? null : () => _socialPreview('apple'),
                    icon: const Icon(Icons.apple), label: const Text('Apple ile bilgileri doldur')),
                ],
                const Text('Hesap, bilgiler kontrol edilip onaylanmadan açılmaz.', style: TextStyle(fontSize: 11)),
                const SizedBox(height: 16),
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
                        label: 'Ad *',
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
                        label: 'Soyad *',
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
                  label: 'E-posta Adresi *',
                  hint: 'ornek@mail.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined,
                      size: 18, color: AppTheme.slate400),
                  validator: (v) {
                    if (v == null || !v.contains('@')) return 'E-posta zorunlu.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone
                CustomTextField(
                  controller: _phoneController,
                  label: 'Telefon Numarası (isteğe bağlı)',
                  hint: '05XXXXXXXXX',
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(Icons.phone_outlined,
                      size: 18, color: AppTheme.slate400),
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty && !RegExp(r'^(\+90|0)?5\d{9}
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                OutlinedButton.icon(onPressed: _busyAction ? null : _sendCode,
                  icon: const Icon(Icons.mark_email_read_outlined), label: const Text('E-posta Kodu Gönder')),
                const SizedBox(height: 12),
                if (_challengeId != null && _verificationProof == null) ...[
                  TextFormField(controller: _otpCtrl, keyboardType: TextInputType.number, maxLength: 6,
                    decoration: const InputDecoration(labelText: '6 Haneli Kod', border: OutlineInputBorder())),
                  OutlinedButton(onPressed: _busyAction ? null : _confirmCode, child: const Text('Kodu Doğrula')),
                  const SizedBox(height: 12),
                ],
                if (_phoneController.text.trim().isNotEmpty) ...[
                  OutlinedButton.icon(onPressed: _busyAction ? null : _sendSmsCode,
                    icon: const Icon(Icons.sms_outlined),
                    label: const Text('Telefonu SMS ile Doğrula (isteğe bağlı)')),
                  if (_smsChallengeId != null && _smsProof == null) ...[
                    const SizedBox(height: 8),
                    TextFormField(controller: _smsOtpCtrl, keyboardType: TextInputType.number,
                      maxLength: 6, decoration: const InputDecoration(labelText: 'SMS Kodu', border: OutlineInputBorder())),
                    OutlinedButton(onPressed: _busyAction ? null : _confirmSmsCode, child: const Text('SMS Kodunu Doğrula')),
                  ],
                  const SizedBox(height: 12),
                ],
                // Password
                CustomTextField(
                  controller: _passwordController,
                  label: 'Şifre *',
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
                  label: 'Şifre Tekrar *',
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

                OutlinedButton.icon(onPressed: _chooseAddress, icon: const Icon(Icons.map_outlined),
                  label: Text(_address == null ? 'Adres Ekle *' :
                    (_address!['district'].toString() + ', ' + _address!['province'].toString() + ' · Düzenle'))),
                const SizedBox(height: 12),
                CheckboxListTile(value: _termsAccepted,
                  onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                  title: const Text('Kullanım Koşullarını kabul ediyorum *', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('tarak.app/legal/terms', style: TextStyle(fontSize: 11)),
                  controlAffinity: ListTileControlAffinity.leading),
                CheckboxListTile(value: _privacyAcknowledged,
                  onChanged: (v) => setState(() => _privacyAcknowledged = v ?? false),
                  title: const Text('KVKK aydınlatma metnini okudum *', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('tarak.app/legal/privacy', style: TextStyle(fontSize: 11)),
                  controlAffinity: ListTileControlAffinity.leading),
                CheckboxListTile(value: _marketingConsent,
                  onChanged: (v) => setState(() => _marketingConsent = v ?? false),
                  title: const Text('Kampanya bildirimleri almak istiyorum (isteğe bağlı)', style: TextStyle(fontSize: 13)),
                  controlAffinity: ListTileControlAffinity.leading),
                const SizedBox(height: 14),
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
).hasMatch(v.trim())) return 'Geçerli cep numarası girin.';
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
