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
import 'provider_profile_tab.dart';
import '../appointments/screens/provider_appointment_detail_screen.dart';
import '../appointments/screens/provider_appointments_tab.dart';
import '../instant/screens/provider_home_tab.dart';
import '../instant/screens/provider_job_detail_screen.dart';
import '../instant/screens/provider_jobs_tab.dart';

class ProviderShell extends ConsumerStatefulWidget {
  const ProviderShell({super.key});

  @override
  ConsumerState<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends ConsumerState<ProviderShell> {
  int _currentIndex = 0;
  StreamSubscription<SemanticDeepLink>? _deepLinkSub;

  List<Widget> get _screens => [
    ProviderHomeTab(onNavigateToJobs: () => setState(() => _currentIndex = 1)),
    const ProviderJobsTab(),
    const ProviderAppointmentsTab(),
    const ConversationListScreen(),
    const ProviderProfileTab(),
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

    if (link.resourceId != null &&
        (link.tab == SemanticRouteTab.requests || link.hasRequestDetail)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProviderJobDetailScreen(requestId: link.resourceId!),
        ),
      );
    } else if (link.resourceId != null &&
        (link.tab == SemanticRouteTab.appointments ||
            link.hasAppointmentDetail)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ProviderAppointmentDetailScreen(appointmentId: link.resourceId!),
        ),
      );
    } else if (link.conversationId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversationId: link.conversationId!),
        ),
      );
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
              icon: Icons.work_outline_rounded,
              activeIcon: Icons.work_rounded,
              label: 'İşler',
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
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
