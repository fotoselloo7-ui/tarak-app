import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_logo.dart';

/// "Tarak'la bakım her zaman cebinde.": the line under the logo on the loading screen.
const String kTarakSlogan = "Tarak'la bakım her zaman cebinde.";

/// Loading screen while the session is restored. The official wordmark (unaltered, on white with clear space) sits in the
/// optical centre with the slogan under a short gold rule; a thin gold bar shows that the app is working.
class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key});

  static const Color _gold = Color(0xFFE5A32F);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      key: const Key('brand_splash'),
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFFFF8EC)]),
        ),
        child: Stack(
          children: [
            // Soft warm glow behind the logo.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(center: Alignment(0, -0.06), radius: 0.62, colors: [Color(0x26E5A32F), Color(0x00E5A32F)]),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, -0.06),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(offset: Offset(0, (1 - t) * 10), child: child),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TarakLogo(height: 68),
                    const SizedBox(height: 22),
                    Container(width: 40, height: 3, decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 18),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        kTarakSlogan,
                        key: Key('brand_splash_slogan'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 15, height: 1.4, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: AppTheme.slate700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 40 + bottomInset,
              child: Center(
                child: SizedBox(
                  width: 96,
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: const LinearProgressIndicator(
                      backgroundColor: Color(0xFFF1E4C8),
                      valueColor: AlwaysStoppedAnimation<Color>(_gold),
                      semanticsLabel: 'Yükleniyor',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
