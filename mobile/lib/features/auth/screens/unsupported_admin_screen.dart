import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class UnsupportedAdminScreen extends ConsumerWidget {
  const UnsupportedAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.admin_panel_settings_outlined,
                size: 80,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(height: 24),
              const Text(
                'Yönetici Hesabı',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Yönetici (Admin) hesapları mobil uygulamada desteklenmemektedir. Lütfen web yönetim panelini kullanınız.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
                icon: const Icon(Icons.logout),
                label: const Text('Farklı Bir Hesapla Giriş Yap'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
