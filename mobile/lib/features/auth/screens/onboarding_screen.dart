import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/onboarding_provider.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'welcome_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      title: 'Kuaför & Berber Konforu Kapınızda',
      subtitle:
          'Sıra beklemeden, dilediğiniz saatte evinizde veya ofisinizde profesyonel saç, sakal ve kişisel bakım hizmeti alın.',
      icon: Icons.content_cut_rounded,
      badge: 'EVDE KİŞİSEL BAKIM',
      badgeColor: AppTheme.primary,
      features: [
        'Adresinize gelen usta kuaför ve berberler',
        'Erkek berber & kadın kuaför seçenekleri',
        'Kişisel hijyen ve steril ekipman güvencesi',
      ],
    ),
    _OnboardingItem(
      title: 'Doğrulanmış Uzmanlar & Güvenli Ödeme',
      subtitle:
          'Tüm hizmet verenler kimlik ve mesleki yeterlilik onayından geçer. Nakit veya PayTR ile güvenle ödeyin.',
      icon: Icons.verified_user_rounded,
      badge: 'GÜVENLİ PAZARYERİ',
      badgeColor: Color(0xFF16A34A),
      features: [
        'Belge kontrolünden geçmiş onaylı ustalar',
        'Nakit veya online güvenli PayTR ödeme',
        'Gerçek müşteri puanları ve yorumları',
      ],
    ),
    _OnboardingItem(
      title: 'Hemen Başlayın: Hizmet Alın veya Kazanın',
      subtitle:
          'Müşteri olarak anında randevu oluşturabilir, berber veya kuaför olarak ekibinize yeni müşteriler kazandırabilirsiniz.',
      icon: Icons.rocket_launch_rounded,
      badge: 'İKİ YÖNLÜ DENEYİM',
      badgeColor: Color(0xFF2563EB),
      features: [
        'Müşteriler için anında çağrı veya planlı randevu',
        'Hizmet verenler için esnek çalışma ve kazanç',
        'Tek platformda zahmetsiz randevu yönetimi',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeAndNavigate(Widget destination) async {
    await ref.read(onboardingNotifierProvider.notifier).completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  Future<void> _skipToWelcome() async {
    await _completeAndNavigate(const WelcomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _items.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo mark
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.content_cut_rounded,
                          size: 18,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Tarak',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkNavy,
                        ),
                      ),
                    ],
                  ),
                  // Skip button
                  TextButton(
                    onPressed: _skipToWelcome,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.slate600,
                    ),
                    child: const Text(
                      'Atla',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // PageView Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        // Icon Illustration
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                item.badgeColor.withValues(alpha: 0.15),
                                item.badgeColor.withValues(alpha: 0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: item.badgeColor.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              item.icon,
                              size: 40,
                              color: item.badgeColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Badge Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: item.badgeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item.badge,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: item.badgeColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Title
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkNavy,
                            letterSpacing: -0.4,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          item.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.slate600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Key Highlights
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: AppTheme.radiusCard,
                            border: Border.all(color: AppTheme.slate200),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            children: item.features.map((feature) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 16,
                                      color: Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        feature,
                                        style: const TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.slate700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Actions & Page Indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  // Dot Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_items.length, (idx) {
                      final isActive = idx == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.primary : AppTheme.slate300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  if (isLastPage) ...[
                    // Hizmet Al / Hizmet Ver direct access
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _completeAndNavigate(
                              const RegisterScreen(initialRole: 'CUSTOMER'),
                            ),
                            icon: const Icon(Icons.person_rounded, size: 18),
                            label: const Text('Hizmet Al'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _completeAndNavigate(
                              const RegisterScreen(initialRole: 'PROVIDER'),
                            ),
                            icon: const Icon(Icons.content_cut_rounded, size: 18, color: AppTheme.darkNavy),
                            label: const Text(
                              'Hizmet Ver',
                              style: TextStyle(color: AppTheme.darkNavy),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.darkNavy, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => _completeAndNavigate(const LoginScreen()),
                      child: const Text(
                        'Zaten bir hesabınız var mı? Giriş Yapın',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.slate700,
                        ),
                      ),
                    ),
                  ] else ...[
                    // Next Page Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.darkNavy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Devam Et',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String badge;
  final Color badgeColor;
  final List<String> features;

  const _OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
    required this.badgeColor,
    required this.features,
  });
}
