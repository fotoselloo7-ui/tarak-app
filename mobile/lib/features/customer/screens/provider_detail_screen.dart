import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/widgets/common_widgets.dart';
import '../appointments/screens/create_appointment_screen.dart';
import '../widgets/tarak_provider_profile_content.dart';
import 'service_selection_screen.dart';

/// Native customer-facing provider detail. Reuses the real offerings endpoint
/// (`/customer/providers/{id}/offerings`) + real reviews + staff + favourites.
class ProviderDetailScreen extends ConsumerStatefulWidget {
  final int providerUserId;
  final String? fallbackName;

  const ProviderDetailScreen({
    super.key,
    required this.providerUserId,
    this.fallbackName,
  });

  @override
  ConsumerState<ProviderDetailScreen> createState() =>
      _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends ConsumerState<ProviderDetailScreen> {
  TarakProviderProfileData? _profile;
  bool _loading = true;
  bool _error = false;
  bool _isFav = false;
  bool _favBusy = false;

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
    final ApiClient api = ref.read(apiClientProvider);
    try {
      final profile = await CanonicalProviderProfileLoader.load(
        api: api,
        providerUserId: widget.providerUserId,
        fallbackName: widget.fallbackName,
      );
      _profile = profile;

      // Favourite state (best-effort).
      try {
        final favs = await api.get('/customer/favorites');
        final fd = favs.data is Map ? favs.data['data'] : null;
        if (fd is List) {
          _isFav = fd.any(
            (f) => (f['provider_user_id'] as num?)?.toInt() == widget.providerUserId,
          );
        }
      } catch (_) {/* ignore */}
    } catch (_) {
      _error = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFav() async {
    if (_favBusy) return;
    setState(() => _favBusy = true);
    final ApiClient api = ref.read(apiClientProvider);
    try {
      if (_isFav) {
        await api.delete('/customer/favorites/${widget.providerUserId}');
        _isFav = false;
      } else {
        await api.post(
          '/customer/favorites',
          data: {'provider_user_id': widget.providerUserId},
        );
        _isFav = true;
      }
    } catch (_) {/* ignore */} finally {
      if (mounted) setState(() => _favBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _profile;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Hizmet Veren'),
        actions: [
          IconButton(
            icon: Icon(
              _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isFav ? AppTheme.error : null,
            ),
            onPressed: _favBusy ? null : _toggleFav,
          ),
        ],
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
                      onBookAppointment: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateAppointmentScreen(
                              initialProviderUserId: widget.providerUserId,
                            ),
                          ),
                        );
                      },
                      onInstantCall: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ServiceSelectionScreen(),
                        ),
                      ),
                      onSelectStaff: (staff) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateAppointmentScreen(
                              initialProviderUserId: widget.providerUserId,
                              initialStaffId: staff.id,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
    );
  }
}
