import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'core/network/network_retry.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final secureStorage = SecureStorageService();
  await secureStorage.init();

  final container = ProviderContainer(
    retry: networkRetry,
    overrides: [
      secureStorageProvider.overrideWithValue(secureStorage),
    ],
  );

  // Initialize Firebase in background without blocking UI startup
  container.read(pushNotificationServiceProvider).initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TarakApp(),
    ),
  );
}

class TarakApp extends StatelessWidget {
  const TarakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tarak',
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}
