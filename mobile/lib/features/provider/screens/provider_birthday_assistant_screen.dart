import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../staff/models/provider_staff_model.dart';
import '../staff/repositories/provider_staff_repository.dart';

class ProviderBirthdayAssistantScreen extends ConsumerStatefulWidget {
  const ProviderBirthdayAssistantScreen({super.key});

  @override
  ConsumerState<ProviderBirthdayAssistantScreen> createState() =>
      _ProviderBirthdayAssistantScreenState();
}

class _ProviderBirthdayAssistantScreenState
    extends ConsumerState<ProviderBirthdayAssistantScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  late BirthdayAssistantSettingsModel _settings;
  bool _isEnabled = false;
  bool _sendOnBirthday = true;
  bool _sendOneDayBefore = false;
  bool _sendTwoDaysBefore = false;
  String _sendTime = '10:00';
  String _templateKey = 'classic';
  final TextEditingController _customMessageCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customMessageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(providerStaffRepositoryProvider)
          .fetchBirthdaySettings();
      if (!mounted) return;
      setState(() {
        _settings = data;
        _isEnabled = data.isEnabled;
        _sendOnBirthday = data.sendOnBirthday;
        _sendOneDayBefore = data.sendOneDayBefore;
        _sendTwoDaysBefore = data.sendTwoDaysBefore;
        _sendTime = data.sendTime;
        _templateKey = data.templateKey;
        _customMessageCtrl.text = data.customMessage ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is AppException && e.message.isNotEmpty
            ? e.message
            : 'Özel Gün Asistanı ayarları yüklenemedi.';
        _loading = false;
      });
    }
  }

  Future<void> _pickSendTime() async {
    final parts = _sendTime.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 10,
        minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _sendTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_templateKey == 'custom' && _customMessageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Özel mesaj şablonu seçildiğinde tebrik mesajı boş olamaz.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(providerStaffRepositoryProvider)
          .updateBirthdaySettings({
        'is_enabled': _isEnabled,
        'send_on_birthday': _sendOnBirthday,
        'send_one_day_before': _sendOneDayBefore,
        'send_two_days_before': _sendTwoDaysBefore,
        'send_time': _sendTime,
        'template_key': _templateKey,
        'custom_message': _customMessageCtrl.text.trim().isEmpty
            ? null
            : _customMessageCtrl.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _settings = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Özel Gün Asistanı ayarları kaydedildi.'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = e is AppException && e.message.isNotEmpty
          ? e.message
          : 'Ayarlar kaydedilemedi.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Tarak Özel Gün Asistanı',
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            label: 'Uygun Müşteri Sayısı',
                            value: '${_settings.eligibleCustomerCount}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricTile(
                            label: 'Bu Yıl Gönderilen',
                            value: '${_settings.sentThisYearCount}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      key: const Key('birthday_pricing_summary_card'),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.slate200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Bildirim Ücreti ve Bakiye',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                _settings.unitPrice <= 0
                                    ? 'Ücretsiz'
                                    : '₺${_settings.unitPrice.toStringAsFixed(2).replaceAll('.', ',')} / alıcı',
                                key: const Key('birthday_unit_price_label'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Promosyon bakiyesi: ₺${_settings.usablePromoBalance.toStringAsFixed(2).replaceAll('.', ',')}  •  Nakit bakiye: ₺${_settings.usableCashBalance.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Önümüzdeki 30 gün yaklaşan: ${_settings.upcomingEligibleBirthdays30d}  •  Bu ay harcanan: ₺${_settings.monthlyTotalSpent.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.slate500),
                          ),
                        ],
                      ),
                    ),
                    if (_settings.isRestrictedByAdmin) ...[
                      const SizedBox(height: 10),
                      Container(
                        key: const Key('birthday_admin_restricted_banner'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.block_rounded, size: 18, color: Color(0xFFB91C1C)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _settings.restrictionReason?.isNotEmpty == true
                                    ? 'Doğum günü / özel gün bildirim yetkiniz yönetici tarafından kısıtlanmıştır. Neden: ${_settings.restrictionReason}'
                                    : 'Doğum günü / özel gün bildirim yetkiniz yönetici tarafından kısıtlanmıştır.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFB91C1C),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.privacy_tip_outlined,
                            size: 18,
                            color: AppTheme.primary,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Müşteri gizliliği gereği müşterilerin bireysel doğum tarihleri işletmelere açılmaz. Kutlamalar yalnızca sizden hizmet almış ve doğum günü tebriğine izin vermiş müşterilere otomatik iletilir.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppTheme.slate200),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SwitchListTile(
                        key: const Key('birthday_assistant_enabled_switch'),
                        title: const Text(
                          'Otomatik Doğum Günü Kutlaması',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text(
                          'Uygun müşterilerinize otomatik doğum günü bildirimi gönderin.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                        value: _isEnabled,
                        activeThumbColor: AppTheme.primary,
                        onChanged: _settings.isRestrictedByAdmin
                            ? null
                            : (v) => setState(() => _isEnabled = v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppTheme.slate200),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gönderim Zamanlaması',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _sendOnBirthday,
                              activeColor: AppTheme.primary,
                              title: const Text('Doğum Gününde'),
                              onChanged: (v) =>
                                  setState(() => _sendOnBirthday = v ?? true),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _sendOneDayBefore,
                              activeColor: AppTheme.primary,
                              title: const Text('1 Gün Önce Hatırlatmalı Tebrik'),
                              onChanged: (v) =>
                                  setState(() => _sendOneDayBefore = v ?? false),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _sendTwoDaysBefore,
                              activeColor: AppTheme.primary,
                              title: const Text('2 Gün Önce Hatırlatmalı Tebrik'),
                              onChanged: (v) =>
                                  setState(() => _sendTwoDaysBefore = v ?? false),
                            ),
                            const Divider(),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Gönderim Saati (Europe/Istanbul)'),
                              subtitle: Text(_sendTime),
                              trailing: OutlinedButton.icon(
                                onPressed: _pickSendTime,
                                icon: const Icon(Icons.access_time, size: 16),
                                label: const Text('Saat Seç'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppTheme.slate200),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: RadioGroup<String>(
                          groupValue: _templateKey,
                          onChanged: (val) {
                            if (val != null) setState(() => _templateKey = val);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Kutlama Mesajı Şablonu',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              for (final tpl in _settings.templates)
                                RadioListTile<String>(
                                  contentPadding: EdgeInsets.zero,
                                  activeColor: AppTheme.primary,
                                  value: tpl.key,
                                  title: Text(tpl.label),
                                  subtitle: Text(
                                    tpl.body,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              const RadioListTile<String>(
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppTheme.primary,
                                value: 'custom',
                                title: Text('Özel Tebrik Mesajı Yaz'),
                              ),
                              if (_templateKey == 'custom') ...[
                                const SizedBox(height: 8),
                                TextField(
                                  key: const Key('birthday_custom_message_input'),
                                  controller: _customMessageCtrl,
                                  maxLines: 3,
                                  maxLength: 500,
                                  decoration: const InputDecoration(
                                    labelText: 'Özel Tebrik Mesajı',
                                    hintText:
                                        'Örn. İyi ki doğdun {customer_name}! {business_name} olarak seni bekliyoruz.',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        key: const Key('save_birthday_assistant_btn'),
                        onPressed:
                            (_saving || _settings.isRestrictedByAdmin) ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Ayarları Kaydet'),
                      ),
                    ),
                  ],
                  ),
                ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
