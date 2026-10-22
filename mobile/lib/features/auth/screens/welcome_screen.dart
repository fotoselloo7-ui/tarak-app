import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/public_home_body.dart';
import '../widgets/web_landing_widgets.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'public_provider_screen.dart';
import '../../customer/screens/all_providers_screen.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  void _navigateToLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  void _navigateToRegister(BuildContext context, [String role = 'CUSTOMER']) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterScreen(initialRole: role),
      ),
    );
  }

  /// "Tüm Uzmanları Gör": the full filterable list; a tapped provider opens the public profile.
  void _openAllProviders(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AllProvidersScreen(
          onProviderTap: (id, name) => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProviderScreen(providerUserId: id, fallbackName: name))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void openProvider(int id, String name) => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProviderScreen(providerUserId: id, fallbackName: name)));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // Web-Identical Mobile Navbar
            WebNavbarMobile(
              onLoginClick: () => _navigateToLogin(context),
              onRegisterClick: () => _navigateToRegister(context, 'CUSTOMER'),
            ),

            // Full Scrollable Native Content: same site-config, same section visibility/order as the web homepage.
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PublicHomeBody(
                      onBook: () => _navigateToRegister(context, 'CUSTOMER'),
                      onProviderSignUp: () => _navigateToRegister(context, 'PROVIDER'),
                      onSelectService: () => _navigateToRegister(context),
                      onViewAllProviders: () => _openAllProviders(context),
                      onProviderTap: openProvider,
                    ),
                    const WebFooterSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
