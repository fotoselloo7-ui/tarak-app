import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/instant_request_provider.dart';

/// Completion / dispute screen — customer confirms service or reports problem.
class CompletionScreen extends ConsumerStatefulWidget {
  final int requestId;

  const CompletionScreen({super.key, required this.requestId});

  @override
  ConsumerState<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends ConsumerState<CompletionScreen> {
  bool _disputeMode = false;
  final _reasonCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(activeRequestProvider(widget.requestId).notifier)
          .complete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hizmet başarıyla tamamlandı!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _reportProblem() async {
    if (_reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Lütfen sorun nedenini yazın.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(activeRequestProvider(widget.requestId).notifier)
          .reportProblem(
            _reasonCtrl.text.trim(),
            note: _noteCtrl.text.trim().isEmpty
                ? null
                : _noteCtrl.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Uyuşmazlık bildiriminiz alındı. İncelemeye alınacak.'),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Hizmet Değerlendirme',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.slate900,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Completion banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.successLight,
                  borderRadius: AppTheme.radiusCard,
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: AppTheme.success, size: 48),
                    SizedBox(height: 10),
                    Text(
                      'Berber hizmetini tamamladı',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Hizmeti onaylayın ya da sorun bildiriminde bulunun.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.slate500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              if (!_disputeMode) ...[
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _complete,
                  icon: const Icon(Icons.thumb_up_rounded),
                  label: const Text('Hizmeti Onayla'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.radiusButton,
                    ),
                    textStyle: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _disputeMode = true),
                  icon: const Icon(Icons.report_problem_outlined,
                      color: AppTheme.warning),
                  label: const Text(
                    'Sorun Bildir',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.warning),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.radiusButton,
                    ),
                  ),
                ),
              ] else ...[
                // Dispute form
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warningLight,
                    borderRadius: AppTheme.radiusCard,
                    border: Border.all(color: const Color(0xFFFDE68A)),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppTheme.warning),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Uyuşmazlık bildiriminiz admin ekibimiz tarafından incelenecek.',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: Color(0xFF92400E),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reasonCtrl,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    labelText: 'Sorun Nedeni *',
                    hintText:
                        'ör. Hizmet yapılmadı, anlaştığımızdan farklı...',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteCtrl,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (İsteğe Bağlı)',
                    hintText: 'Detayları paylaşın...',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _reportProblem,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Uyuşmazlık Bildir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warning,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.radiusButton,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _disputeMode = false),
                  child: const Text('Geri Dön'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
