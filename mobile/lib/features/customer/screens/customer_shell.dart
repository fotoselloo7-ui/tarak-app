import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/push_notification_service.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_providers.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/screens/conversation_list_screen.dart';
import 'customer_profile_tab.dart';
import '../appointments/screens/customer_appointment_detail_screen.dart';
import '../appointments/screens/customer_appointments_tab.dart';
import 'customer_home_tab.dart';
import 'request_tracking_screen.dart';
import 'requests_tab.dart';
import 'provider_detail_screen.dart';

class CustomerShell extends ConsumerStatefulWidget {
  const CustomerShell({super.key});

  @override
  ConsumerState<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends ConsumerState<CustomerShell> {
  int _currentIndex = 0;
  StreamSubscription<SemanticDeepLink>? _deepLinkSub;

  final List<Widget> _screens = const [
    CustomerHomeTab(),
    RequestsTab(),
    CustomerAppointmentsTab(),
    ConversationListScreen(),
    CustomerProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    final pushService = ref.read(pushNotificationServiceProvider);
    _deepLinkSub = pushService.deepLinkStream.listen(_onDeepLinkReceived);
  }

  void _onDeepLinkReceived(SemanticDeepLink link) {
    if (!mounted) return;
    setState(() {
      switch (link.tab) {
        case SemanticRouteTab.home:
          _currentIndex = 0;
          break;
        case SemanticRouteTab.requests:
          _currentIndex = 1;
          break;
        case SemanticRouteTab.appointments:
          _currentIndex = 2;
          break;
        case SemanticRouteTab.messages:
          _currentIndex = 3;
          break;
        case SemanticRouteTab.profile:
          _currentIndex = 4;
          break;
      }
    });

    // Directly open request tracking detail screen when target is an instant request
    if (link.hasRequestDetail && link.resourceId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RequestTrackingScreen(requestId: link.resourceId!),
          ),
        );
      });
    }

    // Directly open appointment detail screen when target is a scheduled appointment
    if (link.hasAppointmentDetail && link.resourceId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerAppointmentDetailScreen(
              appointmentId: link.resourceId!,
            ),
          ),
        );
      });
    }

    // A provider's discount campaign: straight to that provider's profile (prices already carry the discount)
    if (link.hasProviderProfile && link.resourceId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProviderDetailScreen(providerUserId: link.resourceId!),
          ),
        );
      });
    }

    // Directly open chat screen when conversation_id is explicitly provided
    if (link.conversationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(conversationId: link.conversationId!),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadCountProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: AppBottomNav(
          currentIndex: _currentIndex,
          onTap: (index) {
            // IndexedStack keeps the list alive; refresh previews when the tab is reopened.
            if (index == 3 && _currentIndex != 3) {
              ref.read(conversationsProvider.notifier).refresh();
            }
            setState(() => _currentIndex = index);
          },
          items: [
            const AppNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Ana Sayfa',
            ),
            const AppNavItem(
              icon: Icons.flash_on_outlined,
              activeIcon: Icons.flash_on_rounded,
              label: 'Talepler',
            ),
            const AppNavItem(
              icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month_rounded,
              label: 'Randevular',
            ),
            AppNavItem(
              icon: Icons.chat_bubble_outline_rounded,
              activeIcon: Icons.chat_bubble_rounded,
              label: 'Mesajlar',
              badge: unreadCount,
            ),
            const AppNavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profilim',
            ),
          ],
        ),
      ),
    );
  }
}
