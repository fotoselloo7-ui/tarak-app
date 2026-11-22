import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../../customer/appointments/screens/create_appointment_screen.dart';
import '../../customer/screens/service_selection_screen.dart';
import '../../customer/widgets/tarak_provider_profile_content.dart';
import '../../shared/widgets/common_widgets.dart';
import '../models/map_business_model.dart';
import '../services/directions_launcher.dart';

/// Unified business profile screen (reuses the exact original Tarak profile
/// layout and rating system rather than maintaining a separate showcase UI).
class BusinessShowcaseScreen extends ConsumerStatefulWidget {
  final String identifier;
  final MapBusinessSummary? initialSummary;
  final bool isGuest;
  final ExternalUriLauncher? directionsLauncher;

  const BusinessShowcaseScreen({
    super.key,
    required this.identifier,
    this.initialSummary,
    this.isGuest = false,
    this.directionsLauncher,
  });

  @override
  ConsumerState<BusinessShowcaseScreen> createState() =>
      _BusinessShowcaseScreenState();
}

class _BusinessShowcaseScreenState
    extends ConsumerState<BusinessShowcaseScreen> {
  TarakProviderProfileData? _profile;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final api = ref.read(apiClientProvider);
      final data = await CanonicalProviderProfileLoader.load(
        api: api,
        providerUserId: int.tryParse(widget.initialSummary?.userId ?? '') ??
            int.tryParse(widget.identifier),
        slugOrIdentifier: widget.identifier,
        fallbackName: widget.initialSummary?.businessName,
        initialSummary: widget.initialSummary,
        isGuest: widget.isGuest,
      );
      if (!mounted) return;
      setState(() {
        _profile = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  void _openBooking(BuildContext context, {int? staffId}) {
    if (widget.isGuest) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    final uid = _profile?.userId ??
        int.tryParse(widget.initialSummary?.userId ?? '');
    if (uid == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateAppointmentScreen(
          initialProviderUserId: uid,
          initialStaffId: staffId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _profile;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Hizmet Veren'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error || data == null)
              ? ErrorState(
                  message: 'Hizmet veren yüklenemedi.',
                  onRetry: _load,
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TarakProviderProfileContent(
                      data: data,
                      isGuest: widget.isGuest,
                      onBookAppointment: () => _openBooking(context),
                      onInstantCall: () {
                        if (widget.isGuest) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ServiceSelectionScreen(),
                          ),
                        );
                      },
                      onSelectStaff: (staff) =>
                          _openBooking(context, staffId: staff.id),
                      uriLauncher: widget.directionsLauncher,
                    ),
                  ],
                ),
    );
  }
}
