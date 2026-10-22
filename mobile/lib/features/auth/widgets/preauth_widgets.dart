import 'package:flutter/material.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/theme/app_theme.dart';

/// Top Brand Header with refined logo mark, title and value proposition slogan.
class PreAuthHeader extends StatelessWidget {
  final String? subtitle;
  final bool compact;

  const PreAuthHeader({
    super.key,
    this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: compact ? 56 : 68,
          height: compact ? 56 : 68,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF7043), Color(0xFFFF5722)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.content_cut_rounded,
              size: compact ? 28 : 34,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: compact ? 12 : 16),
        TarakLogo(height: compact ? 30 : 38),
        const SizedBox(height: 6),
        Text(
          subtitle ?? 'Kişisel Bakımınız Kapınızda',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.slate600,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

/// Hero Banner emphasizing "Evde berber ve kuaför hizmeti" with unisex market appeal.
class HeroValueCard extends StatelessWidget {
  const HeroValueCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background decorative glow
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'EVDE BERBER & KUAFÖR HİZMETİ',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFAB91),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Kişisel Bakım Konforu\nKapınıza Gelsin',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.25,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sıra beklemeden, randevunuza uygun saatte adresinizde profesyonel saç, sakal ve bakım hizmeti alın.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFCBD5E1),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                // Unisex Category Badges
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCategoryBadge(Icons.face_retouching_natural, 'Erkek Berber'),
                    _buildCategoryBadge(Icons.auto_awesome, 'Kadın Kuaför'),
                    _buildCategoryBadge(Icons.home_outlined, 'Adrese Servis'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFFFCCBC)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// 4 Core Trust Points (Doğrulanmış uzmanlar, evde hizmet, güvenli ödeme, hızlı talep/randevu).
class TrustBadgeGrid extends StatelessWidget {
  const TrustBadgeGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final trustItems = [
      _TrustItem(
        icon: Icons.verified_user_rounded,
        iconColor: const Color(0xFF16A34A),
        iconBg: const Color(0xFFDCFCE7),
        title: 'Doğrulanmış Uzmanlar',
        desc: 'Kimlik ve mesleki yeterliliği onaylanmış berber ve kuaförler',
      ),
      _TrustItem(
        icon: Icons.home_rounded,
        iconColor: const Color(0xFF2563EB),
        iconBg: const Color(0xFFDBEAFE),
        title: 'Evde Hizmet Konforu',
        desc: 'Sıra beklemeden, kendi adresinizde steril ve profesyonel bakım',
      ),
      _TrustItem(
        icon: Icons.security_rounded,
        iconColor: const Color(0xFFD97706),
        iconBg: const Color(0xFFFEF3C7),
        title: 'Güvenli Ödeme',
        desc: 'İster nakit, ister PayTR altyapısı ile güvenceli online ödeme',
      ),
      _TrustItem(
        icon: Icons.bolt_rounded,
        iconColor: AppTheme.primary,
        iconBg: AppTheme.primaryLight,
        title: 'Hızlı & Planlı Randevu',
        desc: 'İster anında çağırın, ister ileri tarihe randevu planlayın',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Neden Tarak?',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkNavy,
              letterSpacing: -0.2,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: trustItems.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final item = trustItems[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.radiusCard,
                border: Border.all(color: AppTheme.slate200),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: item.iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(item.icon, size: 18, color: item.iconColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkNavy,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.slate500,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TrustItem {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String desc;

  const _TrustItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.desc,
  });
}

/// 3-Step "Nasıl Çalışır?" (How It Works) Section.
class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.radiusCard,
        border: Border.all(color: AppTheme.slate200),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Nasıl Çalışır?',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkNavy,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStepRow(
            stepNumber: '1',
            title: 'Hizmetini Seç',
            description:
                'Saç, sakal, manikür, boya veya komple bakım paketini kolayca belirle.',
            isLast: false,
          ),
          _buildStepRow(
            stepNumber: '2',
            title: 'Adres & Zamanını Belirle',
            description:
                'İster acil berber çağır, ister dilediğin güne randevunu planla.',
            isLast: false,
          ),
          _buildStepRow(
            stepNumber: '3',
            title: 'Berberin Kapına Gelsin',
            description:
                'Onaylı usta adresine gelsin, kendi konforunda kaliteli bakımın tadını çıkar.',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required String stepNumber,
    required String title,
    required String description,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: AppTheme.darkNavy,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  stepNumber,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                color: AppTheme.slate200,
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.slate600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Role Selection Card for Register & Pre-auth onboarding (Customer vs Provider).
class RoleSelectionCard extends StatelessWidget {
  final String title;
  final String badgeText;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const RoleSelectionCard({
    super.key,
    required this.title,
    required this.badgeText,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.radiusCard,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight : Colors.white,
          borderRadius: AppTheme.radiusCard,
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.slate200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : AppTheme.secondarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? Colors.white : AppTheme.slate700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : AppTheme.secondarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppTheme.primary : AppTheme.slate600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppTheme.primary : AppTheme.darkNavy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: isSelected ? AppTheme.slate700 : AppTheme.slate500,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic Informative Callout based on selected role in registration.
class RoleInfoBox extends StatelessWidget {
  final String role; // 'CUSTOMER' or 'PROVIDER'

  const RoleInfoBox({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final isProvider = role.toUpperCase() == 'PROVIDER';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isProvider ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF),
        borderRadius: AppTheme.radiusCard,
        border: Border.all(
          color: isProvider ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isProvider ? Icons.business_center_rounded : Icons.home_repair_service_rounded,
                size: 18,
                color: isProvider ? const Color(0xFFD97706) : const Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Text(
                isProvider ? 'Hizmet Veren Başvuru Notu' : 'Müşteri Hizmet Avantajı',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isProvider ? const Color(0xFF92400E) : const Color(0xFF1E40AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isProvider) ...[
            _buildBullet(
              icon: Icons.verified_rounded,
              text: 'Belge Doğrulaması: Başvurunuz ekibimiz tarafından incelenir ve profiliniz onaylanır.',
              color: const Color(0xFF78350F),
            ),
            const SizedBox(height: 4),
            _buildBullet(
              icon: Icons.payments_outlined,
              text: 'Hizmet Vererek Kazanç: Bölgenizdeki talepleri kabul ederek dilediğiniz saatlerde ek gelir sağlayın.',
              color: const Color(0xFF78350F),
            ),
            const SizedBox(height: 4),
            _buildBullet(
              icon: Icons.card_giftcard_rounded,
              text: "İlk 500 TL komisyon Tarak.app'ten! Onaydan sonra tanımlanan hediye hak yalnızca Tarak komisyonunu karşılar; çekilebilir nakit değildir.",
              color: const Color(0xFF78350F),
            ),
          ] else ...[
            _buildBullet(
              icon: Icons.chair_rounded,
              text: 'Evde Konfor: Salonlarda sıra beklemeden berber ve kuaför adresinize gelsin.',
              color: const Color(0xFF1E3A8A),
            ),
            const SizedBox(height: 4),
            _buildBullet(
              icon: Icons.flash_on_rounded,
              text: 'Hızlı Çağrı & Planlı Randevu: İster anında usta talep edin, ister dilediğiniz tarihe randevu oluşturun.',
              color: const Color(0xFF1E3A8A),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBullet({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: color,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
