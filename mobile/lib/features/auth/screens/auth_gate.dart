import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_icon/app_icon_service.dart';
import '../../customer/screens/customer_shell.dart';
import '../../provider/screens/provider_shell.dart';
import '../../shared/screens/app_icon_screen.dart';
import '../providers/auth_provider.dart';
import '../widgets/brand_splash.dart';
import 'unsupported_admin_screen.dart';
import 'welcome_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _iconPromptChecked = false;

  /// Right after the splash of a fresh install: offer the app-icon colours once (skippable, changeable in Profil later).
  Future<void> _maybePromptAppIcon() async {
    if (_iconPromptChecked) return;
    _iconPromptChecked = true;
    await WidgetsBinding.instance.endOfFrame; // let the first screen draw
    if (!mounted || !await ref.read(appIconServiceProvider).shouldPrompt() || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const AppIconScreen(firstRun: true)));
  }

  @override
  void initState() {
    super.initState();
    // Restore session on startup only if initial
    Future.microtask(() {
      if (ref.read(authNotifierProvider).status == AuthStatus.initial) {
        ref.read(authNotifierProvider.notifier).restoreSession();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    if (authState.status != AuthStatus.initial && authState.status != AuthStatus.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptAppIcon());
    }

    switch (authState.status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        if (authState.user == null) {
          return const BrandSplash();
        }
        // If user already loaded but updating, stay on current shell
        if (authState.isCustomer) return const CustomerShell();
        if (authState.isProvider) return const ProviderShell();
        return const BrandSplash();

      case AuthStatus.unsupportedAdmin:
        return const UnsupportedAdminScreen();

      case AuthStatus.authenticated:
        if (authState.isCustomer) {
          return const CustomerShell();
        } else if (authState.isProvider) {
          return const ProviderShell();
        }
        return const WelcomeScreen();

      case AuthStatus.unauthenticated:
        return const WelcomeScreen();
    }
  }
}
