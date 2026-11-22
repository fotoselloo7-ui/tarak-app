import { r as React } from './react-vendor-Dj04zrcb.js?v=20261030-nearby-fallback1';

/**
 * Bildirim Kontrol Merkezi — Tarak Admin Panel Modülü
 * Sekmeler: Gönderim Geçmişi | Hizmet Verenler | Doğum Günü Bildirimleri | Bildirim Reklamları | Fiyatlandırma ve Limitler
 */
const h = React.createElement;
const C = {
  ink: '#0f172a',
  muted: '#64748b',
  accent: '#ff5125',
  border: '#e2e8f0',
  card: '#ffffff',
  pale: '#f8fafc',
};

const TABS = [
  ['dispatches', 'Gönderim Geçmişi'],
  ['providers', 'Hizmet Verenler'],
  ['birthdays', 'Doğum Günü Bildirimleri'],
  ['ads', 'Bildirim Reklamları'],
  ['pricing', 'Fiyatlandırma ve Limitler'],
];

const money = (v) =>
  new Intl.NumberFormat('tr-TR', {
    style: 'currency',
    currency: 'TRY',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Number(v || 0));

const numFmt = (v) => new Intl.NumberFormat('tr-TR').format(Number(v || 0));

const dateFmt = (iso) => {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleString('tr-TR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return String(iso);
  }
};

const qs = (obj) => {
  const p = new URLSearchParams();
  Object.entries(obj || {}).forEach(([k, v]) => {
    if (v !== undefined && v !== null && v !== '') p.set(k, String(v));
  });
  const s = p.toString();
  return s ? `?${s}` : '';
};

const badgeTone = (status) => {
  switch (String(status || '').toUpperCase()) {
    case 'COMPLETED':
    case 'SENT':
    case 'FCM_ACCEPTED':
    case 'CAPTURED':
    case 'CHARGED_CAMPAIGN':
      return { bg: '#ecfdf5', fg: '#047857', bd: '#a7f3d0' };
    case 'BLOCKED':
    case 'BLOCKED_BY_ADMIN':
    case 'FAILED':
    case 'INVALID_TOKEN':
    case 'OPEN':
      return { bg: '#fef2f2', fg: '#b91c1c', bd: '#fecaca' };
    case 'RESERVED':
    case 'QUEUED':
    case 'PROCESSING':
    case 'PARTIAL':
      return { bg: '#fffbeb', fg: '#b45309', bd: '#fde68a' };
    default:
      return { bg: '#f1f5f9', fg: '#475569', bd: '#cbd5e1' };
  }
};

function Badge({ status, label }) {
  const t = badgeTone(status);
  return h(
    'span',
    {
      style: {
        display: 'inline-block',
        padding: '2px 8px',
        borderRadius: 999,
        fontSize: 11,
        fontWeight: 700,
        background: t.bg,
        color: t.fg,
        border: `1px solid ${t.bd}`,
        whiteSpace: 'nowrap',
      },
    },
    label || status || '—',
  );
}

function StatCard({ label, value, detail, tone }) {
  return h(
    'div',
    {
      style: {
        background: C.card,
        border: `1px solid ${C.border}`,
        borderRadius: 16,
        padding: '14px 16px',
      },
    },
    h('div', { style: { fontSize: 11, fontWeight: 700, color: C.muted, textTransform: 'uppercase', letterSpacing: 0.4 } }, label),
    h('div', { style: { fontSize: 22, fontWeight: 900, color: tone || C.ink, marginTop: 4, fontVariantNumeric: 'tabular-nums' } }, value),
    detail && h('div', { style: { fontSize: 11.5, color: C.muted, marginTop: 3 } }, detail),
  );
}

const styles = {
  card: { background: C.card, border: `1px solid ${C.border}`, borderRadius: 16, padding: 18 },
  input: {
    width: '100%',
    minHeight: 38,
    border: '1px solid #cbd5e1',
    borderRadius: 10,
    padding: '6px 11px',
    fontSize: 13,
    color: C.ink,
    background: '#fff',
  },
  btnPrimary: {
    background: C.accent,
    color: '#fff',
    border: 0,
    borderRadius: 10,
    padding: '8px 14px',
    fontSize: 12.5,
    fontWeight: 800,
    cursor: 'pointer',
  },
  btnSecondary: {
    background: '#fff',
    color: C.ink,
    border: '1px solid #cbd5e1',
    borderRadius: 10,
    padding: '8px 13px',
    fontSize: 12.5,
    fontWeight: 700,
    cursor: 'pointer',
  },
  th: { padding: '10px 12px', textAlign: 'left', fontSize: 11.5, fontWeight: 800, color: '#475569', background: '#f8fafc' },
  td: { padding: '10px 12px', fontSize: 12.5, color: C.ink, borderTop: '1px solid #f1f5f9', verticalAlign: 'top' },
};

export function NotificationControlCenter({ api }) {
  const [tab, setTab] = React.useState('dispatches');
  const [overview, setOverview] = React.useState(null);
  const [notice, setNotice] = React.useState(null);
  const [loadingOverview, setLoadingOverview] = React.useState(true);

  // Dispatches tab state
  const [dispatches, setDispatches] = React.useState([]);
  const [dispatchMeta, setDispatchMeta] = React.useState({});
  const [dispatchFilters, setDispatchFilters] = React.useState({ q: '', type: '', status: '', date_from: '', date_to: '', page: 1 });

  // Recipient modal state
  const [selectedDispatch, setSelectedDispatch] = React.useState(null);
  const [recipients, setRecipients] = React.useState([]);
  const [recipientMeta, setRecipientMeta] = React.useState({});
  const [recipientFilters, setRecipientFilters] = React.useState({ q: '', delivery_status: '', page: 1 });
  const [loadingRecipients, setLoadingRecipients] = React.useState(false);

  // Providers tab state
  const [providers, setProviders] = React.useState([]);
  const [providerMeta, setProviderMeta] = React.useState({});
  const [providerFilters, setProviderFilters] = React.useState({ q: '', restricted: '', page: 1 });
  const [editingProvider, setEditingProvider] = React.useState(null);
  const [controlForm, setControlForm] = React.useState(null);
  const [savingControl, setSavingControl] = React.useState(false);

  // Birthday tab state
  const [birthdays, setBirthdays] = React.useState([]);
  const [birthdayMeta, setBirthdayMeta] = React.useState({});
  const [birthdayFilters, setBirthdayFilters] = React.useState({ q: '', delivery_status: '', billing_status: '', page: 1 });

  // Ads tab state
  const [ads, setAds] = React.useState([]);
  const [adsMeta, setAdsMeta] = React.useState({});
  const [adsFilters, setAdsFilters] = React.useState({ q: '', page: 1 });

  // Pricing & limits tab state
  const [settingsForm, setSettingsForm] = React.useState(null);
  const [savingSettings, setSavingSettings] = React.useState(false);
  const [auditLogs, setAuditLogs] = React.useState([]);

  const flash = (type, text) => setNotice({ type, text });

  const loadOverview = React.useCallback(async () => {
    setLoadingOverview(true);
    try {
      const res = await api.get('/admin/notification-center/overview');
      setOverview(res.data || null);
      if (res.data?.settings) {
        setSettingsForm((cur) => cur || { ...res.data.settings });
      }
    } catch (e) {
      flash('error', e?.message || 'Bildirim kontrol merkezi verileri yüklenemedi.');
    } finally {
      setLoadingOverview(false);
    }
  }, [api]);

  const loadDispatches = React.useCallback(async () => {
    try {
      const res = await api.get('/admin/notification-center/dispatches' + qs(dispatchFilters));
      setDispatches(res.data || []);
      setDispatchMeta(res.meta || {});
    } catch {
      setDispatches([]);
    }
  }, [api, dispatchFilters]);

  const loadProviders = React.useCallback(async () => {
    try {
      const res = await api.get('/admin/notification-center/providers' + qs(providerFilters));
      setProviders(res.data || []);
      setProviderMeta(res.meta || {});
    } catch {
      setProviders([]);
    }
  }, [api, providerFilters]);

  const loadBirthdays = React.useCallback(async () => {
    try {
      const res = await api.get('/admin/notification-center/birthday-deliveries' + qs(birthdayFilters));
      setBirthdays(res.data || []);
      setBirthdayMeta(res.meta || {});
    } catch {
      setBirthdays([]);
    }
  }, [api, birthdayFilters]);

  const loadAds = React.useCallback(async () => {
    try {
      const res = await api.get('/admin/notification-ads' + qs(adsFilters));
      setAds(res.data || []);
      setAdsMeta(res.meta || {});
    } catch {
      setAds([]);
    }
  }, [api, adsFilters]);

  const loadAudit = React.useCallback(async () => {
    try {
      const res = await api.get('/admin/notification-center/audit-logs?per_page=15');
      setAuditLogs(res.data || []);
    } catch {
      setAuditLogs([]);
    }
  }, [api]);

  React.useEffect(() => {
    loadOverview();
  }, [loadOverview]);

  React.useEffect(() => {
    if (tab === 'dispatches') loadDispatches();
    else if (tab === 'providers') loadProviders();
    else if (tab === 'birthdays') loadBirthdays();
    else if (tab === 'ads') loadAds();
    else if (tab === 'pricing') loadAudit();
  }, [tab, loadDispatches, loadProviders, loadBirthdays, loadAds, loadAudit]);

  const openRecipients = React.useCallback(
    async (dispatchId, overrideFilters = null) => {
      const flt = overrideFilters || recipientFilters;
      setLoadingRecipients(true);
      try {
        const res = await api.get(`/admin/notification-center/dispatches/${dispatchId}/recipients` + qs(flt));
        setSelectedDispatch(res.dispatch || null);
        setRecipients(res.data || []);
        setRecipientMeta(res.meta || {});
      } catch (e) {
        flash('error', e?.message || 'Alıcı detayı yüklenemedi.');
      } finally {
        setLoadingRecipients(false);
      }
    },
    [api, recipientFilters],
  );

  const openProviderControlModal = (row) => {
    const c = row.controls || {};
    setEditingProvider(row);
    setControlForm({
      block_mode: c.is_restricted ? '' : 'enable',
      can_send_notification_ads: Boolean(c.can_send_notification_ads ?? true),
      can_send_birthday_greetings: Boolean(c.can_send_birthday_greetings ?? true),
      can_send_auto_special_day: Boolean(c.can_send_auto_special_day ?? true),
      blocked_until: '',
      daily_paid_notification_limit: c.daily_paid_notification_limit ?? '',
      daily_unique_recipient_limit: c.daily_unique_recipient_limit ?? '',
      reason: c.restriction_reason || '',
    });
  };

  const saveProviderControl = async (e) => {
    e.preventDefault();
    if (!editingProvider || !controlForm) return;
    setSavingControl(true);
    try {
      const payload = {
        can_send_notification_ads: Boolean(controlForm.can_send_notification_ads),
        can_send_birthday_greetings: Boolean(controlForm.can_send_birthday_greetings),
        can_send_auto_special_day: Boolean(controlForm.can_send_auto_special_day),
        daily_paid_notification_limit:
          controlForm.daily_paid_notification_limit === '' ? null : Number(controlForm.daily_paid_notification_limit),
        daily_unique_recipient_limit:
          controlForm.daily_unique_recipient_limit === '' ? null : Number(controlForm.daily_unique_recipient_limit),
        reason: controlForm.reason?.trim() || null,
      };
      if (controlForm.block_mode) {
        payload.block_mode = controlForm.block_mode;
      }
      if (controlForm.block_mode === 'until' && controlForm.blocked_until) {
        payload.blocked_until = new Date(controlForm.blocked_until).toISOString();
      }
      const res = await api.put(`/admin/notification-center/providers/${editingProvider.provider_user_id}/controls`, payload);
      flash('success', res.message || 'Yetkiler güncellendi.');
      setEditingProvider(null);
      await Promise.all([loadProviders(), loadOverview(), loadDispatches()]);
    } catch (err) {
      flash('error', err?.message || 'Yetkiler kaydedilemedi.');
    } finally {
      setSavingControl(false);
    }
  };

  const resolveAlert = async (alertId) => {
    try {
      await api.post(`/admin/notification-center/alerts/${alertId}/resolve`, {});
      flash('success', 'Şüpheli gönderim uyarısı kapatıldı.');
      await loadOverview();
    } catch (e) {
      flash('error', e?.message || 'Uyarı güncellenemedi.');
    }
  };

  const saveSettings = async (e) => {
    e.preventDefault();
    if (!settingsForm) return;
    setSavingSettings(true);
    try {
      const res = await api.put('/admin/notification-center/settings', settingsForm);
      setSettingsForm({ ...res.data });
      flash('success', res.message || 'Fiyatlandırma ve limit ayarları kaydedildi.');
      await Promise.all([loadOverview(), loadAudit()]);
    } catch (err) {
      flash('error', err?.message || 'Ayarlar kaydedilemedi.');
    } finally {
      setSavingSettings(false);
    }
  };

  const t = overview?.totals || {};
  const rev = overview?.revenue || {};
  const alerts = overview?.open_alerts || [];

  return h(
    'div',
    { 'data-testid': 'admin-notification-control-center', style: { display: 'flex', flexDirection: 'column', gap: 18 } },
    // Header
    h(
      'div',
      { style: { display: 'flex', flexWrap: 'wrap', alignItems: 'center', justifyContent: 'space-between', gap: 12 } },
      h(
        'div',
        null,
        h('h1', { style: { fontSize: 22, fontWeight: 900, color: C.ink, margin: 0 } }, 'Bildirim Kontrol Merkezi'),
        h('p', { style: { fontSize: 13, color: C.muted, margin: '4px 0 0' } }, 'Ücretlendirme, promosyon bakiyesi kullanımı, hizmet veren yetkileri, gönderim/alıcı denetimi ve kötüye kullanım koruması.'),
      ),
      h(
        'button',
        { type: 'button', style: styles.btnSecondary, onClick: () => { loadOverview(); loadDispatches(); } },
        'Yenile',
      ),
    ),

    // Status banner
    notice &&
      h(
        'div',
        {
          role: 'status',
          style: {
            padding: '10px 14px',
            borderRadius: 12,
            fontSize: 13,
            fontWeight: 700,
            background: notice.type === 'error' ? '#fef2f2' : '#ecfdf5',
            color: notice.type === 'error' ? '#b91c1c' : '#047857',
            border: `1px solid ${notice.type === 'error' ? '#fecaca' : '#a7f3d0'}`,
          },
        },
        notice.text,
      ),

    // Overview KPI Cards
    loadingOverview && !overview
      ? h('div', { style: styles.card }, 'Yükleniyor...')
      : h(
          React.Fragment,
          null,
          h(
            'div',
            { className: 'grid grid-cols-2 lg:grid-cols-4 gap-3' },
            h(StatCard, { label: 'Toplam Gönderim', value: numFmt(t.total_dispatches), detail: `Hedef: ${numFmt(t.total_targeted_users)} · Aktif İşletme: ${numFmt(t.active_providers_count)}` }),
            h(StatCard, {
              label: 'FCM Kabul / Başarısız',
              value: `${numFmt(t.total_fcm_accepted)} / ${numFmt(t.total_failed)}`,
              detail: `Denenen: ${numFmt(t.total_attempted)} · Atlanan: ${numFmt(t.total_skipped)}`,
              tone: '#047857',
            }),
            h(StatCard, {
              label: 'Toplam Bildirim Geliri',
              value: money(rev.total),
              detail: `Bugün: ${money(rev.today)} · 7G: ${money(rev.last_7_days)} · 30G: ${money(rev.last_30_days)}`,
              tone: C.accent,
            }),
            h(StatCard, {
              label: 'Promosyon / Nakit Harcama',
              value: `${money(rev.promo_spent_total)}`,
              detail: `Nakit: ${money(rev.cash_spent_total)} · Kısıtlı: ${numFmt(t.restricted_providers_count)} · Uyarı: ${numFmt(t.open_alerts_count)}`,
            }),
          ),

          // Honest FCM Delivery Disclaimer
          h(
            'div',
            {
              style: {
                padding: '10px 14px',
                borderRadius: 12,
                background: '#f8fafc',
                border: '1px solid #e2e8f0',
                fontSize: 12,
                color: '#475569',
              },
            },
            h('strong', { style: { color: C.ink } }, 'Teslimat Doğruluğu Notu: '),
            overview?.delivery_disclaimer || 'FCM kabulü cihazda kesin gösterim anlamına gelmez; yalnızca push sunucusuna iletildiğini ifade eder.',
          ),

          // Open Abuse Alerts
          alerts.length > 0 &&
            h(
              'div',
              { style: { ...styles.card, background: '#fffbeb', borderColor: '#fde68a' } },
              h('div', { style: { fontSize: 13.5, fontWeight: 800, color: '#92400e', marginBottom: 8 } }, `Şüpheli Gönderim Uyarıları (${alerts.length})`),
              h(
                'div',
                { style: { display: 'flex', flexDirection: 'column', gap: 8 } },
                alerts.map((a) =>
                  h(
                    'div',
                    {
                      key: a.id,
                      style: {
                        display: 'flex',
                        flexWrap: 'wrap',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        gap: 8,
                        background: '#fff',
                        padding: '8px 12px',
                        borderRadius: 10,
                        border: '1px solid #fde68a',
                      },
                    },
                    h(
                      'div',
                      { style: { minWidth: 0, flex: '1 1 260px' } },
                      h('div', { style: { fontSize: 12.5, fontWeight: 800, color: C.ink } }, `${a.provider_name || 'İşletme'} · ${a.alert_type_label}`),
                      h('div', { style: { fontSize: 12, color: C.muted } }, `${a.summary} (${dateFmt(a.created_at)})`),
                    ),
                    h(
                      'button',
                      { type: 'button', style: styles.btnSecondary, onClick: () => resolveAlert(a.id) },
                      'İncelendi / Kapat',
                    ),
                  ),
                ),
              ),
            ),
        ),

    // Sub-tabs Bar
    h(
      'div',
      { role: 'tablist', style: { display: 'flex', flexWrap: 'wrap', gap: 8 } },
      TABS.map(([id, label]) =>
        h(
          'button',
          {
            key: id,
            type: 'button',
            role: 'tab',
            'aria-selected': tab === id,
            onClick: () => setTab(id),
            style: {
              padding: '9px 14px',
              borderRadius: 12,
              fontSize: 13,
              fontWeight: 800,
              cursor: 'pointer',
              border: `1.5px solid ${tab === id ? C.accent : C.border}`,
              background: tab === id ? '#fff5f2' : '#fff',
              color: tab === id ? C.accent : C.ink,
            },
          },
          label,
        ),
      ),
    ),

    // TAB 1: Gönderim Geçmişi
    tab === 'dispatches' &&
      h(
        'div',
        { style: styles.card },
        h(
          'div',
          { className: 'grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-2.5', style: { marginBottom: 14 } },
          h('input', {
            style: styles.input,
            placeholder: 'Hizmet veren, başlık veya referans ara',
            value: dispatchFilters.q,
            onChange: (e) => setDispatchFilters((f) => ({ ...f, q: e.target.value, page: 1 })),
          }),
          h(
            'select',
            {
              style: styles.input,
              value: dispatchFilters.type,
              onChange: (e) => setDispatchFilters((f) => ({ ...f, type: e.target.value, page: 1 })),
            },
            h('option', { value: '' }, 'Tüm Bildirim Türleri'),
            h('option', { value: 'NOTIFICATION_AD' }, 'Bildirim Reklamı'),
            h('option', { value: 'BIRTHDAY_GREETING' }, 'Doğum Günü Kutlaması'),
          ),
          h(
            'select',
            {
              style: styles.input,
              value: dispatchFilters.status,
              onChange: (e) => setDispatchFilters((f) => ({ ...f, status: e.target.value, page: 1 })),
            },
            h('option', { value: '' }, 'Tüm Durumlar'),
            h('option', { value: 'COMPLETED' }, 'İşlendi'),
            h('option', { value: 'PARTIAL' }, 'Kısmi İletim'),
            h('option', { value: 'QUEUED' }, 'Kuyrukta'),
            h('option', { value: 'BLOCKED' }, 'Yönetici Durdurdu'),
            h('option', { value: 'FAILED' }, 'Başarısız'),
          ),
          h('input', {
            type: 'date',
            style: styles.input,
            value: dispatchFilters.date_from,
            onChange: (e) => setDispatchFilters((f) => ({ ...f, date_from: e.target.value, page: 1 })),
          }),
          h('input', {
            type: 'date',
            style: styles.input,
            value: dispatchFilters.date_to,
            onChange: (e) => setDispatchFilters((f) => ({ ...f, date_to: e.target.value, page: 1 })),
          }),
        ),
        h(
          'div',
          { style: { overflowX: 'auto' } },
          h(
            'table',
            { style: { width: '100%', borderCollapse: 'collapse', minWidth: 880 } },
            h(
              'thead',
              null,
              h(
                'tr',
                null,
                ['İşletme / ID', 'Tür ve İçerik', 'Tarih', 'Alıcılar (Hedef / Uygun / FCM / Başarısız / Atlanan)', 'Birim / Maliyet', 'Bakiye Türü', 'Durum', 'Detay'].map((col) =>
                  h('th', { key: col, style: styles.th }, col),
                ),
              ),
            ),
            h(
              'tbody',
              null,
              dispatches.length
                ? dispatches.map((d) =>
                    h(
                      'tr',
                      { key: d.id, style: { cursor: 'pointer' }, onClick: () => { setRecipientFilters({ q: '', delivery_status: '', page: 1 }); openRecipients(d.id, { q: '', delivery_status: '', page: 1 }); } },
                      h(
                        'td',
                        { style: styles.td },
                        h('div', { style: { fontWeight: 800 } }, d.provider?.business_name || '—'),
                        h('div', { style: { fontSize: 11, color: C.muted } }, `${d.provider?.name || ''} (#${d.provider?.id})`),
                      ),
                      h(
                        'td',
                        { style: { ...styles.td, maxWidth: 260 } },
                        h('div', { style: { fontSize: 11, fontWeight: 700, color: C.accent } }, `${d.notification_type_label} · ${d.reference_code}`),
                        h('div', { style: { fontWeight: 700 } }, d.title),
                        h('div', { style: { fontSize: 11.5, color: C.muted, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' } }, d.body),
                      ),
                      h(
                        'td',
                        { style: { ...styles.td, whiteSpace: 'nowrap', fontSize: 11.5 } },
                        h('div', null, `Oluşt.: ${dateFmt(d.created_at)}`),
                        d.sent_at && h('div', { style: { color: C.muted } }, `Gönd.: ${dateFmt(d.sent_at)}`),
                      ),
                      h(
                        'td',
                        { style: { ...styles.td, fontVariantNumeric: 'tabular-nums' } },
                        `${d.targeted_count} / ${d.eligible_count} / `,
                        h('strong', { style: { color: '#047857' } }, d.fcm_accepted_count),
                        ` / ${d.failed_count} / ${d.skipped_count}`,
                      ),
                      h(
                        'td',
                        { style: { ...styles.td, fontVariantNumeric: 'tabular-nums' } },
                        h('div', { style: { fontWeight: 800 } }, money(d.total_cost)),
                        h('div', { style: { fontSize: 11, color: C.muted } }, `Birim: ${money(d.unit_price)}`),
                      ),
                      h('td', { style: styles.td }, d.balance_source_label),
                      h('td', { style: styles.td }, h(Badge, { status: d.status, label: d.status_label })),
                      h(
                        'td',
                        { style: styles.td },
                        h(
                          'button',
                          {
                            type: 'button',
                            style: styles.btnSecondary,
                            onClick: (ev) => {
                              ev.stopPropagation();
                              setRecipientFilters({ q: '', delivery_status: '', page: 1 });
                              openRecipients(d.id, { q: '', delivery_status: '', page: 1 });
                            },
                          },
                          'Alıcılar',
                        ),
                      ),
                    ),
                  )
                : h('tr', null, h('td', { colSpan: 8, style: { ...styles.td, textAlign: 'center', color: C.muted, padding: 24 } }, 'Kayıtlı bildirim gönderimi bulunamadı.')),
            ),
          ),
        ),
        (dispatchMeta.last_page || 1) > 1 &&
          h(
            'div',
            { style: { marginTop: 12, display: 'flex', justifyContent: 'space-between', alignItems: 'center' } },
            h('span', { style: { fontSize: 12, color: C.muted } }, `Toplam ${dispatchMeta.total || 0} işlem`),
            h(
              'div',
              { style: { display: 'flex', gap: 8 } },
              h('button', { type: 'button', style: styles.btnSecondary, disabled: (dispatchFilters.page || 1) <= 1, onClick: () => setDispatchFilters((f) => ({ ...f, page: f.page - 1 })) }, 'Önceki'),
              h('button', { type: 'button', style: styles.btnSecondary, disabled: (dispatchFilters.page || 1) >= (dispatchMeta.last_page || 1), onClick: () => setDispatchFilters((f) => ({ ...f, page: f.page + 1 })) }, 'Sonraki'),
            ),
          ),
      ),

    // TAB 2: Hizmet Verenler
    tab === 'providers' &&
      h(
        'div',
        { style: styles.card },
        h(
          'div',
          { style: { display: 'flex', flexWrap: 'wrap', gap: 10, marginBottom: 14 } },
          h('input', {
            style: { ...styles.input, maxWidth: 280 },
            placeholder: 'İşletme adı veya hizmet veren ID ara',
            value: providerFilters.q,
            onChange: (e) => setProviderFilters((f) => ({ ...f, q: e.target.value, page: 1 })),
          }),
          h(
            'select',
            {
              style: { ...styles.input, maxWidth: 220 },
              value: providerFilters.restricted,
              onChange: (e) => setProviderFilters((f) => ({ ...f, restricted: e.target.value, page: 1 })),
            },
            h('option', { value: '' }, 'Tüm Hizmet Verenler'),
            h('option', { value: '1' }, 'Yalnızca Kısıtlı / Engelliler'),
          ),
        ),
        h(
          'div',
          { style: { overflowX: 'auto' } },
          h(
            'table',
            { style: { width: '100%', borderCollapse: 'collapse', minWidth: 820 } },
            h(
              'thead',
              null,
              h('tr', null, ['İşletme / ID', 'Bakiye (Promosyon / Nakit)', 'Son 30 Gün (Gönderim / Alıcı / Harcama)', 'Yetki Durumu', 'İşlem'].map((col) => h('th', { key: col, style: styles.th }, col))),
            ),
            h(
              'tbody',
              null,
              providers.map((p) => {
                const c = p.controls || {};
                const w = p.wallet || {};
                const st = p.stats_30d || {};
                return h(
                  'tr',
                  { key: p.provider_user_id },
                  h(
                    'td',
                    { style: styles.td },
                    h('div', { style: { fontWeight: 800 } }, p.business_name),
                    h('div', { style: { fontSize: 11.5, color: C.muted } }, `${p.name} (#${p.provider_user_id}) ${p.city ? '· ' + p.city : ''}`),
                  ),
                  h(
                    'td',
                    { style: { ...styles.td, fontVariantNumeric: 'tabular-nums' } },
                    h('div', null, `Promosyon: ${money(w.usable_promo_balance)}`),
                    h('div', { style: { color: C.muted } }, `Nakit: ${money(w.usable_cash_balance)}`),
                  ),
                  h(
                    'td',
                    { style: { ...styles.td, fontVariantNumeric: 'tabular-nums' } },
                    h('div', null, `${numFmt(st.dispatches)} gönderim · ${numFmt(st.recipients)} alıcı`),
                    h('div', { style: { fontWeight: 700, color: C.ink } }, `Harcama: ${money(st.spent_total)}`),
                  ),
                  h(
                    'td',
                    { style: styles.td },
                    h(
                      'div',
                      { style: { display: 'flex', flexWrap: 'wrap', gap: 4 } },
                      h(Badge, { status: c.can_send_notification_ads ? 'COMPLETED' : 'BLOCKED', label: c.can_send_notification_ads ? 'Reklam Açık' : 'Reklam Kapalı' }),
                      h(Badge, { status: c.can_send_birthday_greetings ? 'COMPLETED' : 'BLOCKED', label: c.can_send_birthday_greetings ? 'Doğum Günü Açık' : 'Doğum Günü Kapalı' }),
                      h(Badge, { status: c.can_send_auto_special_day ? 'COMPLETED' : 'BLOCKED', label: c.can_send_auto_special_day ? 'Oto. Özel Gün Açık' : 'Oto. Kapalı' }),
                    ),
                    c.restriction_reason && h('div', { style: { fontSize: 11, color: '#b91c1c', marginTop: 4 } }, c.restriction_reason),
                  ),
                  h(
                    'td',
                    { style: styles.td },
                    h('button', { type: 'button', style: styles.btnSecondary, onClick: () => openProviderControlModal(p) }, 'Yetki & Limitler'),
                  ),
                );
              }),
            ),
          ),
        ),
      ),

    // TAB 3: Doğum Günü Bildirimleri
    tab === 'birthdays' &&
      h(
        'div',
        { style: styles.card },
        h(
          'div',
          { style: { display: 'flex', flexWrap: 'wrap', gap: 10, marginBottom: 14 } },
          h('input', {
            style: { ...styles.input, maxWidth: 260 },
            placeholder: 'İşletme, müşteri adı veya ID ara',
            value: birthdayFilters.q,
            onChange: (e) => setBirthdayFilters((f) => ({ ...f, q: e.target.value, page: 1 })),
          }),
          h(
            'select',
            {
              style: { ...styles.input, maxWidth: 200 },
              value: birthdayFilters.delivery_status,
              onChange: (e) => setBirthdayFilters((f) => ({ ...f, delivery_status: e.target.value, page: 1 })),
            },
            h('option', { value: '' }, 'Tüm İletim Durumları'),
            h('option', { value: 'FCM_ACCEPTED' }, 'FCM Kabul Etti'),
            h('option', { value: 'QUEUED' }, 'Kuyrukta'),
            h('option', { value: 'BLOCKED_BY_ADMIN' }, 'Yönetici Engelledi'),
            h('option', { value: 'OPTED_OUT' }, 'İzin Kapalı'),
            h('option', { value: 'FAILED' }, 'Başarısız'),
          ),
        ),
        h(
          'div',
          { style: { overflowX: 'auto' } },
          h(
            'table',
            { style: { width: '100%', borderCollapse: 'collapse', minWidth: 780 } },
            h('thead', null, h('tr', null, ['İşletme', 'Alıcı (Ad / ID)', 'Yıl', 'Birim / Kesilen', 'Kaynak', 'Durum', 'Tarih'].map((col) => h('th', { key: col, style: styles.th }, col)))),
            h(
              'tbody',
              null,
              birthdays.length
                ? birthdays.map((b) =>
                    h(
                      'tr',
                      { key: b.id },
                      h('td', { style: styles.td }, h('strong', null, b.provider?.business_name || '—')),
                      h('td', { style: styles.td }, `${b.recipient?.display_name || '—'} (#${b.recipient?.user_id})`),
                      h('td', { style: styles.td }, b.birthday_year),
                      h('td', { style: { ...styles.td, fontVariantNumeric: 'tabular-nums' } }, `${money(b.unit_price)} / ${money(b.charged_amount)}`),
                      h('td', { style: styles.td }, b.balance_source),
                      h('td', { style: styles.td }, h(Badge, { status: b.delivery_status, label: b.delivery_status_label })),
                      h('td', { style: { ...styles.td, whiteSpace: 'nowrap' } }, dateFmt(b.sent_at)),
                    ),
                  )
                : h('tr', null, h('td', { colSpan: 7, style: { ...styles.td, textAlign: 'center', color: C.muted, padding: 24 } }, 'Doğum günü gönderim kaydı yok.')),
            ),
          ),
        ),
      ),

    // TAB 4: Bildirim Reklamları
    tab === 'ads' &&
      h(
        'div',
        { style: styles.card },
        h(
          'div',
          { style: { display: 'flex', flexWrap: 'wrap', gap: 10, justifyContent: 'space-between', marginBottom: 14 } },
          h('input', {
            style: { ...styles.input, maxWidth: 260 },
            placeholder: 'Hizmet veren ara',
            value: adsFilters.q,
            onChange: (e) => setAdsFilters((f) => ({ ...f, q: e.target.value, page: 1 })),
          }),
          h('div', { style: { fontSize: 12.5, color: C.muted } }, `30G Ciro: ${money(adsMeta.revenue_30d)} · Toplam: ${money(adsMeta.revenue_total)}`),
        ),
        h(
          'div',
          { style: { overflowX: 'auto' } },
          h(
            'table',
            { style: { width: '100%', borderCollapse: 'collapse', minWidth: 780 } },
            h('thead', null, h('tr', null, ['İşletme', 'Kampanya', 'Hedef', 'Ücret / Kaynak', 'Alıcı', 'Durum', 'Tarih', 'Detay'].map((col) => h('th', { key: col, style: styles.th }, col)))),
            h(
              'tbody',
              null,
              ads.length
                ? ads.map((a) =>
                    h(
                      'tr',
                      { key: a.id },
                      h('td', { style: styles.td }, h('strong', null, a.provider?.name || '—')),
                      h('td', { style: styles.td }, h('div', { style: { fontWeight: 700 } }, a.title), h('div', { style: { fontSize: 11.5, color: C.muted } }, `%${a.discount_percent} · ${a.discount_days} gün`)),
                      h('td', { style: styles.td }, a.audience_name),
                      h('td', { style: styles.td }, h('div', { style: { fontWeight: 700 } }, money(a.amount)), h('div', { style: { fontSize: 11, color: C.muted } }, a.balance_source || a.payment_source || '—')),
                      h('td', { style: styles.td }, numFmt(a.recipients_count)),
                      h('td', { style: styles.td }, h(Badge, { status: a.status })),
                      h('td', { style: { ...styles.td, whiteSpace: 'nowrap' } }, dateFmt(a.sent_at || a.created_at)),
                      h('td', { style: styles.td }, a.dispatch_id ? h('button', { type: 'button', style: styles.btnSecondary, onClick: () => openRecipients(a.dispatch_id, { q: '', delivery_status: '', page: 1 }) }, 'Alıcılar') : '—'),
                    ),
                  )
                : h('tr', null, h('td', { colSpan: 8, style: { ...styles.td, textAlign: 'center', color: C.muted, padding: 24 } }, 'Kayıtlı bildirim reklamı yok.')),
            ),
          ),
        ),
      ),

    // TAB 5: Fiyatlandırma ve Limitler
    tab === 'pricing' &&
      settingsForm &&
      h(
        'form',
        { onSubmit: saveSettings, style: { display: 'flex', flexDirection: 'column', gap: 16 } },
        h(
          'div',
          { style: styles.card },
          h('h3', { style: { fontSize: 15, fontWeight: 900, margin: '0 0 12px', color: C.ink } }, 'Doğum Günü Bildirimi ve Promosyon Bakiye Kuralları'),
          h(
            'div',
            { className: 'grid grid-cols-1 md:grid-cols-2 gap-4', style: { marginBottom: 14 } },
            h(
              'label',
              { style: { display: 'block', fontSize: 12.5, fontWeight: 700, color: C.ink } },
              'Doğum Günü Bildirim Ücreti — Bir Alıcı İçin (₺)',
              h('input', {
                type: 'number',
                min: 0,
                step: '0.01',
                'data-testid': 'birthday-unit-price-input',
                style: { ...styles.input, marginTop: 6 },
                value: settingsForm.birthday_unit_price ?? 0,
                onChange: (e) => setSettingsForm((s) => ({ ...s, birthday_unit_price: Number(e.target.value) })),
              }),
              h('span', { style: { fontSize: 11, color: C.muted, display: 'block', marginTop: 4 } }, '0,00 TL yapılırsa doğum günü kutlamaları ücretsiz çalışır. Değişiklik yalnızca yeni gönderimleri etkiler.'),
            ),
            h(
              'label',
              { style: { display: 'block', fontSize: 12.5, fontWeight: 700, color: C.ink } },
              'Günlük Doğum Günü Limiti (İşletme Başına)',
              h('input', {
                type: 'number',
                min: 1,
                style: { ...styles.input, marginTop: 6 },
                value: settingsForm.birthday_max_per_provider_per_day ?? 100,
                onChange: (e) => setSettingsForm((s) => ({ ...s, birthday_max_per_provider_per_day: Number(e.target.value) })),
              }),
            ),
          ),
          h(
            'div',
            { className: 'grid grid-cols-1 md:grid-cols-3 gap-3', style: { marginBottom: 14 } },
            [
              ['allow_promo_for_birthday', 'Doğum günü bildirimlerinde promosyon bakiyesi kullanımı'],
              ['allow_promo_for_notification_ads', 'Bildirim reklamlarında promosyon bakiyesi kullanımı'],
              ['fallback_to_cash_when_promo_insufficient', 'Promosyon bakiyesi yetmezse nakit bakiyeye geç'],
            ].map(([key, label]) =>
              h(
                'label',
                { key, style: { display: 'flex', alignItems: 'center', gap: 8, fontSize: 12.5, fontWeight: 700, padding: 10, border: `1px solid ${C.border}`, borderRadius: 10, cursor: 'pointer' } },
                h('input', {
                  type: 'checkbox',
                  checked: Boolean(settingsForm[key]),
                  onChange: (e) => setSettingsForm((s) => ({ ...s, [key]: e.target.checked })),
                }),
                label,
              ),
            ),
          ),
          h('h4', { style: { fontSize: 13.5, fontWeight: 800, margin: '10px 0 8px', color: C.ink } }, 'Kampanya Başına Sabit Bildirim Reklamı Fiyatları (₺)'),
          h(
            'div',
            { className: 'grid grid-cols-1 md:grid-cols-3 gap-3', style: { marginBottom: 14 } },
            [
              ['price_service_area', 'Hizmet Bölgesi Fiyatı'],
              ['price_location', 'Seçilen Konum (İl / İlçe)'],
              ['price_all', 'Tüm Kullanıcılar'],
            ].map(([key, label]) =>
              h(
                'label',
                { key, style: { fontSize: 12, fontWeight: 700, color: C.ink } },
                label,
                h('input', {
                  type: 'number',
                  min: 0,
                  step: '0.01',
                  style: { ...styles.input, marginTop: 4 },
                  value: settingsForm[key] ?? 0,
                  onChange: (e) => setSettingsForm((s) => ({ ...s, [key]: Number(e.target.value) })),
                }),
              ),
            ),
          ),
          h('h4', { style: { fontSize: 13.5, fontWeight: 800, margin: '10px 0 8px', color: C.ink } }, 'Günlük Limitler ve Kötüye Kullanım Eşikleri'),
          h(
            'div',
            { className: 'grid grid-cols-2 md:grid-cols-4 gap-3', style: { marginBottom: 14 } },
            [
              ['default_daily_paid_notification_limit', 'Günlük Ücretli Limit'],
              ['default_daily_unique_recipient_limit', 'Günlük Benzersiz Alıcı Limiti'],
              ['rapid_campaign_threshold', 'Hızlı Kampanya Eşiği'],
              ['duplicate_content_window_hours', 'Aynı İçerik Penceresi (Saat)'],
            ].map(([key, label]) =>
              h(
                'label',
                { key, style: { fontSize: 12, fontWeight: 700, color: C.ink } },
                label,
                h('input', {
                  type: 'number',
                  min: 1,
                  style: { ...styles.input, marginTop: 4 },
                  value: settingsForm[key] ?? 1,
                  onChange: (e) => setSettingsForm((s) => ({ ...s, [key]: Number(e.target.value) })),
                }),
              ),
            ),
          ),
          h(
            'div',
            { style: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 10 } },
            h(
              'label',
              { style: { display: 'flex', alignItems: 'center', gap: 8, fontSize: 12.5, fontWeight: 700 } },
              h('input', {
                type: 'checkbox',
                checked: Boolean(settingsForm.auto_suspend_on_abuse),
                onChange: (e) => setSettingsForm((s) => ({ ...s, auto_suspend_on_abuse: e.target.checked })),
              }),
              'Otomatik sınır ihlalinde ücretli gönderimleri geçici durdur',
            ),
            h('button', { type: 'submit', style: styles.btnPrimary, disabled: savingSettings }, savingSettings ? 'Kaydediliyor...' : 'Ayarları Kaydet'),
          ),
        ),
        auditLogs.length > 0 &&
          h(
            'div',
            { style: styles.card },
            h('h4', { style: { fontSize: 14, fontWeight: 800, margin: '0 0 10px' } }, 'Son Yönetici İşlem Günlüğü (AdminLog)'),
            auditLogs.slice(0, 8).map((l) =>
              h(
                'div',
                { key: l.id, style: { fontSize: 12, padding: '6px 0', borderBottom: '1px solid #f1f5f9', display: 'flex', justifyContent: 'space-between', gap: 8 } },
                h('span', null, `${l.action} · Hedef #${l.target_id} (${l.admin || 'Admin'})`),
                h('span', { style: { color: C.muted } }, dateFmt(l.created_at)),
              ),
            ),
          ),
      ),

    // MODAL 1: Alıcı Detayı
    selectedDispatch &&
      h(
        'div',
        { style: { position: 'fixed', inset: 0, background: 'rgba(15,23,42,0.55)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16, zIndex: 60 } },
        h(
          'div',
          { style: { background: '#fff', borderRadius: 18, maxWidth: 820, width: '100%', maxHeight: '88vh', display: 'flex', flexDirection: 'column', overflow: 'hidden' } },
          h(
            'div',
            { style: { padding: '16px 20px', borderBottom: `1px solid ${C.border}`, display: 'flex', justifyContent: 'space-between', alignItems: 'center' } },
            h(
              'div',
              null,
              h('div', { style: { fontSize: 16, fontWeight: 900, color: C.ink } }, `Alıcı Detayı · ${selectedDispatch.title}`),
              h('div', { style: { fontSize: 12, color: C.muted } }, `${selectedDispatch.provider?.business_name || ''} · FCM Kabul: ${selectedDispatch.fcm_accepted_count} · Doğum tarihi ve FCM tokenları gizlidir`),
            ),
            h('button', { type: 'button', style: styles.btnSecondary, onClick: () => setSelectedDispatch(null) }, 'Kapat'),
          ),
          h(
            'div',
            { style: { padding: 16, overflowY: 'auto', flex: 1 } },
            loadingRecipients
              ? h('p', { style: { color: C.muted } }, 'Yükleniyor...')
              : h(
                  'table',
                  { style: { width: '100%', borderCollapse: 'collapse' } },
                  h('thead', null, h('tr', null, ['Kullanıcı ID', 'Ad / Görünen Ad', 'Gönderim Deneme', 'Teslimat Girişimi Durumu', 'Ücret / Bakiye'].map((c) => h('th', { key: c, style: styles.th }, c)))),
                  h(
                    'tbody',
                    null,
                    recipients.length
                      ? recipients.map((r) =>
                          h(
                            'tr',
                            { key: r.id },
                            h('td', { style: styles.td }, `#${r.recipient_user_id}`),
                            h('td', { style: styles.td }, h('strong', null, r.display_name)),
                            h('td', { style: styles.td }, dateFmt(r.attempted_at || r.created_at)),
                            h('td', { style: styles.td }, h(Badge, { status: r.delivery_status, label: r.delivery_status_label }), r.delivery_error_code && h('span', { style: { marginLeft: 6, fontSize: 11, color: C.muted } }, r.delivery_error_code)),
                            h('td', { style: styles.td }, `${money(r.captured_amount || r.unit_price)} (${r.billing_status})`),
                          ),
                        )
                      : h('tr', null, h('td', { colSpan: 5, style: { ...styles.td, textAlign: 'center', color: C.muted } }, 'Alıcı kaydı bulunamadı.')),
                  ),
                ),
            (recipientMeta.last_page || 1) > 1 &&
              h(
                'div',
                { style: { marginTop: 12, display: 'flex', justifyContent: 'space-between' } },
                h('button', { type: 'button', style: styles.btnSecondary, disabled: (recipientFilters.page || 1) <= 1, onClick: () => { const next = { ...recipientFilters, page: recipientFilters.page - 1 }; setRecipientFilters(next); openRecipients(selectedDispatch.id, next); } }, 'Önceki'),
                h('span', { style: { fontSize: 12, color: C.muted } }, `${recipientMeta.page || 1} / ${recipientMeta.last_page || 1}`),
                h('button', { type: 'button', style: styles.btnSecondary, disabled: (recipientFilters.page || 1) >= (recipientMeta.last_page || 1), onClick: () => { const next = { ...recipientFilters, page: recipientFilters.page + 1 }; setRecipientFilters(next); openRecipients(selectedDispatch.id, next); } }, 'Sonraki'),
              ),
          ),
        ),
      ),

    // MODAL 2: Hizmet Veren Yetki & Limit Yönetimi
    editingProvider &&
      controlForm &&
      h(
        'div',
        { style: { position: 'fixed', inset: 0, background: 'rgba(15,23,42,0.55)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16, zIndex: 60 } },
        h(
          'form',
          { onSubmit: saveProviderControl, style: { background: '#fff', borderRadius: 18, maxWidth: 520, width: '100%', padding: 20, display: 'flex', flexDirection: 'column', gap: 12 } },
          h('div', { style: { fontSize: 16, fontWeight: 900, color: C.ink } }, `Bildirim Yetkileri · ${editingProvider.business_name}`),
          h('p', { style: { fontSize: 12, color: C.muted, margin: 0 } }, 'Kısıtlamalar yalnızca işletmenin kendi başlattığı pazarlama ve doğum günü bildirimlerini durdurur; randevu ve sohbet bildirimleri etkilenmez.'),
          [
            ['can_send_notification_ads', 'Bildirim reklamı gönderme'],
            ['can_send_birthday_greetings', 'Doğum günü kutlaması gönderme'],
            ['can_send_auto_special_day', 'Otomatik özel gün mesajları'],
          ].map(([k, lbl]) =>
            h(
              'label',
              { key: k, style: { display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, fontWeight: 700 } },
              h('input', { type: 'checkbox', checked: Boolean(controlForm[k]), onChange: (e) => setControlForm((f) => ({ ...f, [k]: e.target.checked, block_mode: '' })) }),
              lbl,
            ),
          ),
          h(
            'select',
            { style: styles.input, value: controlForm.block_mode, onChange: (e) => setControlForm((f) => ({ ...f, block_mode: e.target.value })) },
            h('option', { value: '' }, 'Üstteki kanallara göre uygula (süresiz/açık)'),
            h('option', { value: 'indefinite' }, 'Seçili/kapalı kanalları süresiz kapat'),
            h('option', { value: 'until' }, 'Belirlenen tarihe kadar kapat'),
            h('option', { value: 'enable' }, 'Tüm gönderim yetkilerini yeniden etkinleştir'),
          ),
          controlForm.block_mode === 'until' &&
            h('input', {
              type: 'datetime-local',
              style: styles.input,
              value: controlForm.blocked_until,
              onChange: (e) => setControlForm((f) => ({ ...f, blocked_until: e.target.value })),
            }),
          h(
            'div',
            { className: 'grid grid-cols-2 gap-2' },
            h(
              'label',
              { style: { fontSize: 11.5, fontWeight: 700 } },
              'Günlük Ücretli Limit',
              h('input', { type: 'number', min: 0, style: { ...styles.input, marginTop: 4 }, placeholder: 'Varsayılan', value: controlForm.daily_paid_notification_limit, onChange: (e) => setControlForm((f) => ({ ...f, daily_paid_notification_limit: e.target.value })) }),
            ),
            h(
              'label',
              { style: { fontSize: 11.5, fontWeight: 700 } },
              'Günlük Benzersiz Alıcı',
              h('input', { type: 'number', min: 0, style: { ...styles.input, marginTop: 4 }, placeholder: 'Varsayılan', value: controlForm.daily_unique_recipient_limit, onChange: (e) => setControlForm((f) => ({ ...f, daily_unique_recipient_limit: e.target.value })) }),
            ),
          ),
          h('textarea', {
            rows: 3,
            style: { ...styles.input, minHeight: 72 },
            placeholder: 'Engelleme / işlem gerekçesi (AdminLog kaydına yazılır)...',
            value: controlForm.reason,
            onChange: (e) => setControlForm((f) => ({ ...f, reason: e.target.value })),
          }),
          h(
            'div',
            { style: { display: 'flex', justifyContent: 'flex-end', gap: 8 } },
            h('button', { type: 'button', style: styles.btnSecondary, onClick: () => setEditingProvider(null) }, 'Vazgeç'),
            h('button', { type: 'submit', style: styles.btnPrimary, disabled: savingControl }, savingControl ? 'Kaydediliyor...' : 'Kaydet'),
          ),
        ),
      ),
  );
}
