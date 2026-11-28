import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../auth/providers/auth_provider.dart';

/// "Randevuya Koş" oyunu: müşterinin oyundan kazandığı hediyeler ve işletmenin "Oyuna Sponsor Ol" ekranı.
/// Kuponlar Tarak'ta üretilir; müşteri ve sponsor işletme aynı kaydı görür.

Map<String, dynamic> _harita(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _liste(dynamic v) => v is List ? v.map(_harita).toList() : <Map<String, dynamic>>[];

String _tarih(String? s) {
  final d = DateTime.tryParse(s ?? '');
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

String _durumYazi(String? d) => switch (d) { 'used' => 'Kullanıldı', 'expired' => 'Süresi doldu', _ => 'Geçerli' };
Color _durumRenk(String? d) => switch (d) { 'used' => AppTheme.slate500, 'expired' => Colors.red, _ => Colors.green };

final gameLinksProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final ApiClient api = ref.read(apiClientProvider);
  final res = await api.get('/game/linkler');
  return _harita(res.data is Map ? res.data['data'] : null);
});

Future<void> _oyunuAc(BuildContext context, Map<String, dynamic> linkler) async {
  final adres = (Theme.of(context).platform == TargetPlatform.iOS ? linkler['link_ios'] : linkler['link_android']) ?? linkler['link_web'];
  final uri = Uri.tryParse((adres ?? 'https://tarak.app/oyun').toString());
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// ---------------------------------------------------------------- müşteri
final gameCouponsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final ApiClient api = ref.read(apiClientProvider);
  final res = await api.get('/customer/game-coupons');
  return _liste(res.data is Map ? res.data['data'] : null);
});

class GameCouponsScreen extends ConsumerWidget {
  const GameCouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kuponlar = ref.watch(gameCouponsProvider);
    final linkler = ref.watch(gameLinksProvider).value ?? const <String, dynamic>{};
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Oyun Hediyelerim')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(gameCouponsProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.slate900, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Oyun oyna, bedava tıraş kazan ✂️', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Randevuya Koş’ta zor yerlerdeki hediye parçalarını topla. Parçalar tamamlanınca bölgendeki sponsor işletmeden gerçek bir hizmet kuponu kazanırsın (yılda bir kez, 30 gün geçerli).',
                    style: TextStyle(color: AppTheme.slate300, fontSize: 13)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _oyunuAc(context, linkler),
                  icon: const Icon(Icons.sports_esports_rounded),
                  label: const Text('Oyunu aç'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFC21A), foregroundColor: Colors.black),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            kuponlar.when(
              loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
              error: (_, _) => const Padding(padding: EdgeInsets.all(24), child: Text('Hediyeler yüklenemedi. Aşağı çekip yenile.')),
              data: (l) => l.isEmpty
                  ? const Padding(padding: EdgeInsets.all(24), child: Text('Henüz oyundan kazanılmış bir hediyen yok.', textAlign: TextAlign.center))
                  : Column(children: l.map((k) => _KuponKarti(k: k)).toList()),
            ),
          ],
        ),
      ),
    );
  }
}

class _KuponKarti extends StatelessWidget {
  final Map<String, dynamic> k;
  final String? musteri;
  const _KuponKarti({required this.k, this.musteri});

  @override
  Widget build(BuildContext context) {
    final sp = _harita(k['sponsor']);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text((k['hizmet'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            Text(_durumYazi(k['durum'] as String?), style: TextStyle(color: _durumRenk(k['durum'] as String?), fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          SelectableText((k['kod'] ?? '').toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          if (sp.isNotEmpty) Text('${sp['ad']} · ${sp['ilce'] ?? sp['il'] ?? ''}', style: const TextStyle(color: AppTheme.slate600)),
          if (musteri != null) Text('Müşteri: $musteri', style: const TextStyle(color: AppTheme.slate600)),
          Text(k['durum'] == 'used' ? 'Kullanma: ${_tarih(k['kullanildi'] as String?)}' : 'Son gün: ${_tarih(k['son_tarih'] as String?)}',
              style: const TextStyle(color: AppTheme.slate500, fontSize: 12)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- işletme: Oyuna Sponsor Ol
final providerSponsorshipProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final ApiClient api = ref.read(apiClientProvider);
  final res = await api.get('/provider/game-sponsorship');
  return _harita(res.data is Map ? res.data['data'] : null);
});
final providerGameStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final ApiClient api = ref.read(apiClientProvider);
  final res = await api.get('/provider/game-stats');
  return _harita(res.data is Map ? res.data['data'] : null);
});
final providerGameCouponsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final ApiClient api = ref.read(apiClientProvider);
  final res = await api.get('/provider/game-coupons');
  return _liste(res.data is Map ? res.data['data'] : null);
});

class ProviderGameSponsorScreen extends ConsumerStatefulWidget {
  const ProviderGameSponsorScreen({super.key});
  @override
  ConsumerState<ProviderGameSponsorScreen> createState() => _ProviderGameSponsorScreenState();
}

class _ProviderGameSponsorScreenState extends ConsumerState<ProviderGameSponsorScreen> {
  final _kod = TextEditingController();
  String? _hizmet;
  String _kitle = 'erkek';
  String _kapsam = 'district';
  double _kota = 10;
  bool _aktif = true;
  int? _id;
  bool _yuklendi = false, _gonderiliyor = false;

  @override
  void dispose() { _kod.dispose(); super.dispose(); }

  void _mesaj(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _hataMesaji(Object e, String varsayilan) => e is AppException && e.message.isNotEmpty ? e.message : varsayilan;

  Future<void> _kaydet() async {
    if (_hizmet == null) { _mesaj('Hediye edeceğin hizmeti seç.'); return; }
    setState(() => _gonderiliyor = true);
    try {
      final ApiClient api = ref.read(apiClientProvider);
      await api.post('/provider/game-sponsorship', data: {
        if (_id != null) 'id': _id, 'service_name': _hizmet, 'audience': _kitle, 'scope': _kapsam,
        'monthly_quota': _kota.round(), 'is_active': _aktif,
      });
      ref.invalidate(providerSponsorshipProvider);
      _mesaj(_aktif ? 'Sponsorluğun kaydedildi. Logon bölgendeki oyunculara görünecek.' : 'Sponsorluk duraklatıldı.');
    } catch (e) {
      _mesaj(_hataMesaji(e, 'Kaydedilemedi.'));
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  Future<void> _dogrula(bool kullan) async {
    final kod = _kod.text.trim();
    if (kod.isEmpty) return;
    try {
      final ApiClient api = ref.read(apiClientProvider);
      final res = await api.post('/provider/game-coupons/verify', data: {'kod': kod, 'kullan': kullan});
      final k = _harita(res.data is Map ? res.data['data'] : null);
      _mesaj(kullan ? '${k['hizmet']} kuponu kullanıldı olarak işaretlendi.' : 'Geçerli kupon: ${k['hizmet']} · son gün ${_tarih(k['son_tarih'] as String?)}');
      if (kullan) { _kod.clear(); ref.invalidate(providerGameCouponsProvider); ref.invalidate(providerGameStatsProvider); }
    } catch (e) {
      _mesaj(_hataMesaji(e, 'Kupon doğrulanamadı.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = ref.watch(providerSponsorshipProvider);
    final ist = ref.watch(providerGameStatsProvider).value ?? const <String, dynamic>{};
    final kuponlar = ref.watch(providerGameCouponsProvider);
    final veri = sp.value ?? const <String, dynamic>{};
    final hizmetler = (veri['hizmetler'] is List ? (veri['hizmetler'] as List).map((e) => e.toString()).toList() : <String>[]);
    final mevcut = _liste(veri['sponsorluklar']);
    if (!_yuklendi && sp.hasValue) {
      _yuklendi = true;
      if (mevcut.isNotEmpty) {
        final s = mevcut.first;
        _id = s['id'] as int?; _hizmet = s['service_name'] as String?; _kitle = (s['audience'] ?? 'erkek') as String;
        _kapsam = (s['scope'] ?? 'district') as String; _kota = ((s['monthly_quota'] ?? 10) as num).toDouble();
        _aktif = s['is_active'] == true || s['is_active'] == 1;
      }
    }
    final secenekler = {...hizmetler, if (_hizmet != null) _hizmet!}.toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Oyuna Sponsor Ol')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Randevuya Koş oyununda logon, bölgendeki oyunculara hangi haritayı oynarlarsa oynasınlar tabela ve pano olarak görünür. '
            'Oyuncular hediye parçalarını tamamlayınca senin hizmetinden kupon kazanır ve randevu alarak sana gelir.',
            style: TextStyle(color: AppTheme.slate600)),
        const SizedBox(height: 16),
        Row(children: [
          _Sayi(baslik: 'Reklam görüldü', deger: '${ist['toplam_gosterim'] ?? 0}'),
          _Sayi(baslik: 'Son 30 gün', deger: '${ist['son_30_gun'] ?? 0}'),
          _Sayi(baslik: 'Kupon', deger: '${_harita(ist['kuponlar'])['kullanilan'] ?? 0}/${_harita(ist['kuponlar'])['toplam'] ?? 0}'),
        ]),
        if (_liste(ist['haritalar']).isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Reklamının göründüğü haritalar', style: TextStyle(fontWeight: FontWeight.w700)),
          ..._liste(ist['haritalar']).take(8).map((h) => ListTile(dense: true, contentPadding: EdgeInsets.zero,
              title: Text((h['route'] ?? '').toString()), trailing: Text('${h['gosterim']} gösterim · ${h['oyuncu']} oyuncu'))),
        ],
        const Divider(height: 32),
        const Text('Sponsorluk', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _hizmet,
          items: secenekler.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
          onChanged: (v) => setState(() => _hizmet = v),
          decoration: const InputDecoration(labelText: 'Hediye edeceğin hizmet'),
        ),
        if (secenekler.isEmpty) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Önce "Hizmetlerim" bölümünden hizmet ekle.', style: TextStyle(color: Colors.red))),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'erkek', label: Text('Berber')), ButtonSegment(value: 'kadin', label: Text('Kuaför')), ButtonSegment(value: 'hepsi', label: Text('İkisi'))],
          selected: {_kitle}, onSelectionChanged: (s) => setState(() => _kitle = s.first),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'district', label: Text('İlçemdeki oyuncular')), ButtonSegment(value: 'city', label: Text('İlimdeki oyuncular'))],
          selected: {_kapsam}, onSelectionChanged: (s) => setState(() => _kapsam = s.first),
        ),
        const SizedBox(height: 12),
        Text('Aylık en fazla ${_kota.round()} hediye'),
        Slider(value: _kota, min: 1, max: 50, divisions: 49, label: '${_kota.round()}', onChanged: (v) => setState(() => _kota = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Sponsorluk açık'), value: _aktif, onChanged: (v) => setState(() => _aktif = v)),
        FilledButton(onPressed: _gonderiliyor ? null : _kaydet, child: Text(_gonderiliyor ? 'Kaydediliyor…' : 'Kaydet')),
        const Divider(height: 32),
        const Text('Kupon doğrula', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        TextField(controller: _kod, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Müşterinin kodu (TRK-XXXX-XXXX)')),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => _dogrula(false), child: const Text('Kontrol et'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton(onPressed: () => _dogrula(true), child: const Text('Kullanıldı işaretle'))),
        ]),
        const Divider(height: 32),
        const Text('Oyun kuponların', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        kuponlar.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('Kuponlar yüklenemedi.'),
          data: (l) => l.isEmpty ? const Text('Henüz kupon yok.') : Column(children: l.map((k) => _KuponKarti(k: k, musteri: k['musteri']?.toString())).toList()),
        ),
      ]),
    );
  }
}

class _Sayi extends StatelessWidget {
  final String baslik, deger;
  const _Sayi({required this.baslik, required this.deger});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.slate200)),
          child: Column(children: [
            Text(deger, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            Text(baslik, style: const TextStyle(fontSize: 12, color: AppTheme.slate500)),
          ]),
        ),
      );
}
