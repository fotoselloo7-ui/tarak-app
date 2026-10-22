import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/screens/public_provider_screen.dart';
import '../../auth/widgets/public_home_body.dart';
import '../../customer/providers/home_content_providers.dart';
import '../../customer/screens/all_providers_screen.dart';
import '../../customer/screens/home_sections.dart';
import '../../shared/widgets/provider_preview_banner.dart';
import '../../shared/widgets/view_mode_switch.dart';
import 'provider_featured_screen.dart';

/// The tabs of the customer view, in order.
enum CustomerViewTab { home, services, providers, modules }

const _tabLabels = {
  CustomerViewTab.home: 'Ana Sayfa',
  CustomerViewTab.services: 'Hizmetler',
  CustomerViewTab.providers: 'Hizmet Verenler',
  CustomerViewTab.modules: 'Müşteri Modülleri',
};

/// "Müşteri görünümü" of a provider account: the same account, the platform the way a customer sees it
/// (home page, services, provider lists with the recommended ads). Nothing here can be changed or bought; it exists
/// to check how the provider's profile and ads look. The customer's own modules (requests, offers, appointments)
/// are described in the last tab; a provider has none of their own as a customer.
class ProviderCustomerViewScreen extends ConsumerStatefulWidget {
  final CustomerViewTab initialTab;
  const ProviderCustomerViewScreen({super.key, this.initialTab = CustomerViewTab.home});

  @override
  ConsumerState<ProviderCustomerViewScreen> createState() => _ProviderCustomerViewScreenState();
}

class _ProviderCustomerViewScreenState extends ConsumerState<ProviderCustomerViewScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: CustomerViewTab.values.length, vsync: this, initialIndex: widget.initialTab.index);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _goTo(CustomerViewTab tab) => _tabs.animateTo(tab.index);

  void _openProvider(int id, String name) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublicProviderScreen(providerUserId: id, fallbackName: name, viewOnly: true)));
  }

  void _openAds() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProviderFeaturedScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('provider_customer_view'),
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(fit: BoxFit.scaleDown, child: ProviderViewModeSwitch(customer: true, onChanged: (_) => Navigator.of(context).maybePop())),
                        ),
                      ),
                      TextButton(key: const Key('customer_view_ads'), onPressed: _openAds, child: const Text('Reklamlarım')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text.rich(
                    TextSpan(
                      style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      children: [
                        TextSpan(text: 'Müşteri görünümündesin'),
                        TextSpan(text: ' · işlem yapılamaz', style: TextStyle(fontWeight: FontWeight.w400, color: AppTheme.slate500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const ProviderAdStatusLine(),
                  const SizedBox(height: 4),
                  TabBar(
                    key: const Key('customer_view_tabs'),
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                    indicatorColor: AppTheme.primary,
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.slate500,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13.5, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13.5, fontWeight: FontWeight.w600),
                    tabs: [for (final tab in CustomerViewTab.values) Tab(key: Key('customer_view_tab_${tab.name}'), text: _tabLabels[tab])],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.slate200),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _KeepAlive(child: _HomeTab(onBook: () => _goTo(CustomerViewTab.providers), onSelectService: () => _goTo(CustomerViewTab.providers), onProviderTap: _openProvider)),
                  _KeepAlive(child: _ServicesTab(onSelect: () => _goTo(CustomerViewTab.providers))),
                  _KeepAlive(child: AllProvidersScreen(preview: true, embedded: true, onProviderTap: _openProvider)),
                  const _KeepAlive(child: _ModulesTab()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps a tab's state (scroll position, loaded list) while another tab is open.
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// The home page a customer sees: same sections as the signed-out home page, without sign-up prompts.
class _HomeTab extends ConsumerWidget {
  final VoidCallback onBook;
  final VoidCallback onSelectService;
  final void Function(int id, String name) onProviderTap;
  const _HomeTab({required this.onBook, required this.onSelectService, required this.onProviderTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        ref.invalidate(siteConfigDataProvider);
        ref.invalidate(homeServicesProvider);
        ref.invalidate(homeCategoriesProvider);
        ref.invalidate(featuredProvidersProvider);
        ref.invalidate(spotlightProvidersProvider);
        ref.invalidate(newestProvidersProvider);
        ref.invalidate(homeStatsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: PublicHomeBody(onBook: onBook, onSelectService: onSelectService, onViewAllProviders: onBook, onProviderTap: onProviderTap),
      ),
    );
  }
}

/// Every category and the services offered on the platform.
class _ServicesTab extends ConsumerWidget {
  final VoidCallback onSelect;
  const _ServicesTab({required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(homeCategoriesProvider).asData?.value ?? const <Map<String, dynamic>>[];
    final categoriesCopy = ref.watch(homeGroupProvider('categories')).asData?.value ?? const <String, dynamic>{};
    final servicesAsync = ref.watch(homeServicesProvider);
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        ref.invalidate(homeServicesProvider);
        ref.invalidate(homeCategoriesProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          const Text('Hizmetler', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: AppTheme.slate900)),
          const SizedBox(height: 4),
          const Text(
            'Müşteriler hizmeti seçer, ardından hizmeti sunan doğrulanmış uzmanlar arasından karşılaştırarak seçim yapar.',
            style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13.5, height: 1.5, color: AppTheme.slate600),
          ),
          const SizedBox(height: 18),
          HomeCategoriesSection(categories: categories, title: (categoriesCopy['title'] ?? 'Hizmet Kategorileri').toString(), onSelect: onSelect),
          servicesAsync.when(
            data: (services) => HomeServicesSection(services: services, onSelect: onSelect),
            loading: () => const HomeServicesSection(loading: true),
            error: (_, _) => HomeServicesSection(onRetry: () => ref.invalidate(homeServicesProvider)),
          ),
        ],
      ),
    );
  }
}

/// A customer's own modules, described: a provider account has no customer requests of its own.
class _ModulesTab extends StatelessWidget {
  const _ModulesTab();

  static const _modules = [
    (Icons.assignment_outlined, 'Taleplerim', 'Müşterinin yayınladığı ilanlar ve hemen çağır talepleri; durumları ve iptal seçenekleri.'),
    (Icons.inbox_outlined, 'Gelen Teklifler', 'İlanlara hizmet verenlerden gelen teklifler; fiyat, süre ve uzman puanıyla karşılaştırma.'),
    (Icons.calendar_month_outlined, 'Randevularım', 'Planlı randevular, onay durumu, konum paylaşımı ve değerlendirme.'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        const Text('Müşteri modülleri', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: AppTheme.slate900)),
        const SizedBox(height: 4),
        const Text(
          'Müşteri hesabında ana sayfanın yanında şu bölümler bulunur. Hizmet veren hesabında müşteri olarak talep açılmadığı için burada boş görünür.',
          style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13.5, height: 1.5, color: AppTheme.slate600),
        ),
        const SizedBox(height: 16),
        for (final (icon, title, text) in _modules)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: AppTheme.radiusCard, border: Border.all(color: AppTheme.slate200)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppTheme.slate100, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 20, color: AppTheme.slate700),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.slate900)),
                      const SizedBox(height: 3),
                      Text(text, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, height: 1.45, color: AppTheme.slate600)),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(color: AppTheme.slate100, borderRadius: BorderRadius.circular(8)),
                        child: const Text('Bu hesapta müşteri olarak kayıt yok.', style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.slate500)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.slate400),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Müşteri akışını (talep açma, teklif alma, randevu) uçtan uca denemek için ayrı bir müşteri hesabıyla giriş yapabilirsin.',
                style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12.5, height: 1.45, color: AppTheme.slate600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
