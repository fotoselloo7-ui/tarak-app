import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

const _faq = <List<String>>[
  ['Nasıl randevu oluştururum?', 'Ana sayfadan hizmet seçip uygun bir hizmet veren belirleyerek randevu oluşturabilir veya "Hemen Çağır" ile size en yakın uygun profesyonelden anlık teklif alabilirsiniz.'],
  ['Hemen Çağır nasıl çalışır?', 'Talebiniz oluşturulduğunda yakındaki uygun ve onaylı hizmet verenler bilgilendirilir. Gelen teklifler arasından seçim yaparsınız.'],
  ['Ödemeyi nasıl yaparım?', 'Talep veya randevu oluştururken sunulan ödeme yöntemlerinden seçim yapın. Nakit ödemeyi hizmet verene yapabilirsiniz. Online ödeme kullanıma açıksa güvenli ödeme ekranına yönlendirilirsiniz; kart bilgileriniz uygulamada saklanmaz.'],
  ['İade sürecim nasıl işler?', 'İade talepleri ilgili randevu ve platform kuralları çerçevesinde değerlendirilir.'],
  ['Bir sorun yaşarsam ne yapmalıyım?', 'Randevu veya hizmetle ilgili sorunlar için uygulama içinden uyuşmazlık kaydı açabilir ya da bu ekrandan destek talebi oluşturabilirsiniz.'],
  ['Bilgilerim güvende mi?', 'Hizmet verenler başlangıçta yalnızca yaklaşık bölgenizi görür. Tam adresinizi seçtiğiniz uzmana hizmet ekranından siz paylaşırsınız; paylaşımı durdurabilirsiniz.'],
];

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _category = 'general';
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).user;
    _name.text = user?.name ?? '';
    _email.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    setState(() => _error = null);
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _subject.text.trim().isEmpty || _message.text.trim().isEmpty) {
      setState(() => _error = 'Lütfen tüm alanları doldurun.');
      return;
    }
    setState(() => _sending = true);
    try {
      final ApiClient api = ref.read(apiClientProvider);
      await api.post('/support/tickets', data: {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'category': _category,
        'subject': _subject.text.trim(),
        'message': _message.text.trim(),
      });
      if (!mounted) return;
      setState(() => _sent = true);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Talebiniz gönderilemedi.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Destek Merkezi')),
      body: _sent
          ? const _SentView()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Sık Sorulan Sorular',
                    style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                ..._faq.map((f) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        title: Text(f[0], style: const TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w600, fontSize: 14)),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(f[1],
                                style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, height: 1.5, color: AppTheme.textSecondary)),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                const Text('Bize Ulaşın',
                    style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.errorLight, borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, color: AppTheme.error)),
                  ),
                _field(_name, 'Adınız Soyadınız', maxLength: 120),
                const SizedBox(height: 10),
                _field(_email, 'E-posta', keyboardType: TextInputType.emailAddress, maxLength: 160),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: _dec('Kategori'),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('Genel')),
                    DropdownMenuItem(value: 'account', child: Text('Hesap')),
                    DropdownMenuItem(value: 'appointment', child: Text('Randevu')),
                    DropdownMenuItem(value: 'instant', child: Text('Hemen Çağır')),
                    DropdownMenuItem(value: 'payment', child: Text('Ödeme')),
                    DropdownMenuItem(value: 'refund', child: Text('İade')),
                    DropdownMenuItem(value: 'dispute', child: Text('Uyuşmazlık')),
                    DropdownMenuItem(value: 'security', child: Text('Güvenlik')),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? 'general'),
                ),
                const SizedBox(height: 10),
                _field(_subject, 'Konu', maxLength: 160),
                const SizedBox(height: 10),
                _field(_message, 'Mesajınız', maxLines: 4, maxLength: 4000),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_sending ? 'Gönderiliyor...' : 'Gönder',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
    );
  }

  // Limits mirror the support ticket API so a long entry cannot fail server-side.
  Widget _field(TextEditingController c, String label, {int maxLines = 1, TextInputType? keyboardType, int? maxLength}) =>
      TextField(controller: c, maxLines: maxLines, keyboardType: keyboardType, maxLength: maxLength, decoration: _dec(label));

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}

class _SentView extends StatelessWidget {
  const _SentView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 56),
          const SizedBox(height: 12),
          const Text('Talebiniz alındı!',
              style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('En kısa sürede dönüş yapacağız.',
              style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}
