import { r as React } from "./react-vendor-Dj04zrcb.js?v=20261030-nearby-fallback1";
import {
  b as api,
  B as Button,
  C as Card,
  M as Modal,
  X as XIcon,
  a8 as Sparkles,
} from "./index-Bj5sn6If.js?v=20261030-nearby-fallback1";
import { formatMoney } from "./WebParityShared.js?v=20261122-web-parity1";

export function WebBirthdayAssistant({ onNotice, onOpenWallet }) {
  const h = React.createElement;
  const [data, setData] = React.useState(null);
  const [loading, setLoading] = React.useState(true);
  const [saving, setSaving] = React.useState(false);
  const [error, setError] = React.useState("");

  const [form, setForm] = React.useState({
    is_enabled: false,
    send_on_birthday: true,
    send_one_day_before: false,
    send_two_days_before: false,
    send_time: "10:00",
    template_key: "classic",
    custom_message: "",
  });

  const load = React.useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const res = await api.get("/provider/birthday-assistant");
      if (!res?.success || !res.data) throw new Error("Özel Gün Asistanı verisi yüklenemedi.");
      setData(res.data);
      setForm({
        is_enabled: !!res.data.is_enabled,
        send_on_birthday: res.data.send_on_birthday !== false,
        send_one_day_before: !!res.data.send_one_day_before,
        send_two_days_before: !!res.data.send_two_days_before,
        send_time: res.data.send_time || "10:00",
        template_key: res.data.template_key || "classic",
        custom_message: res.data.custom_message || "",
      });
    } catch (e) {
      setError(e?.message || "Özel Gün Asistanı yüklenemedi.");
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => { load(); }, [load]);

  const save = async (e) => {
    e.preventDefault();
    if (saving) return;
    setSaving(true);
    setError("");
    try {
      const res = await api.put("/provider/birthday-assistant", form);
      if (!res?.success) throw new Error(res?.message || "Ayarlar kaydedilemedi.");
      onNotice?.("Özel Gün Asistanı ayarları kaydedildi.");
      await load();
    } catch (e2) {
      setError(e2?.message || "Ayarlar kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  };

  if (loading) return h("div", { className: "p-10 text-center text-sm text-gray-500" }, "Özel Gün Asistanı yükleniyor…");
  if (!data) {
    return h("div", { className: "p-6 rounded-2xl bg-rose-50 border border-rose-200 text-sm text-rose-700" },
      error || "Veriler alınamadı.",
      h("button", { type: "button", onClick: load, className: "ml-2 underline font-bold" }, "Tekrar Dene")
    );
  }

  const wallet = data.wallet || {};
  const pricing = data.pricing || {};
  const monthly = data.monthly_summary || {};
  const perms = data.permissions || {};
  const blocked = perms.birthday_blocked || perms.auto_special_day_blocked;
  const templates = Array.isArray(data.templates) ? data.templates : [];
  const selectedTplObj = templates.find((t) => t.key === form.template_key);
  const previewText = form.template_key === "custom"
    ? (form.custom_message || "Özel tebrik mesajınızı yazın…")
    : (selectedTplObj?.body || "");

  return h("div", { className: "space-y-5", "data-testid": "birthday-assistant-panel" },
    h("div", { className: "bg-white rounded-2xl border border-gray-200 p-5 shadow-2xs flex flex-col sm:flex-row sm:items-center justify-between gap-3" },
      h("div", null,
        h("h1", { className: "text-xl font-extrabold text-gray-950 flex items-center gap-2" },
          h(Sparkles, { size: 22, className: "text-[#FF5722]" }), "Özel Gün / Doğum Günü Asistanı"
        ),
        h("p", { className: "text-xs text-gray-500 mt-1" },
          "İzinli müşterilerinize doğum günlerinde otomatik tebrik bildirimi gönderin. Doğum tarihleri gizlilik gereği asla açık listelenmez."
        )
      ),
      onOpenWallet && h(Button, { variant: "outline", size: "sm", onClick: onOpenWallet }, "Cüzdan & Rapor")
    ),

    blocked && h("div", { className: "p-4 rounded-2xl bg-rose-50 border border-rose-200 text-xs text-rose-800 font-semibold" },
      `Yönetici Kısıtlaması: Doğum günü bildirimi gönderim yetkiniz kısıtlanmıştır. ${perms.restriction_reason || ""}`
    ),

    error && h("div", { className: "p-3 rounded-xl bg-rose-50 border border-rose-200 text-xs text-rose-700" }, error),

    // KPI Cards from Server (Single source of truth)
    h("div", { className: "grid grid-cols-2 lg:grid-cols-4 gap-3" },
      h(Card, { className: "!p-4 border border-purple-200 bg-purple-50/40" },
        h("div", { className: "text-[11px] font-bold text-purple-800 uppercase" }, "Promosyon Bakiyesi"),
        h("div", { className: "text-xl font-black text-purple-900 mt-1" }, formatMoney(wallet.usable_promo_balance)),
        h("div", { className: "text-[11px] text-purple-700 mt-0.5" }, "İlk 500 TL hoş geldin promosyonu")
      ),
      h(Card, { className: "!p-4 border border-blue-200 bg-blue-50/40" },
        h("div", { className: "text-[11px] font-bold text-blue-800 uppercase" }, "Nakit Bakiye"),
        h("div", { className: "text-xl font-black text-blue-900 mt-1" }, formatMoney(wallet.usable_cash_balance)),
        h("div", { className: "text-[11px] text-blue-700 mt-0.5" }, "Promosyon yetersizse kullanılır")
      ),
      h(Card, { className: "!p-4 border border-gray-200" },
        h("div", { className: "text-[11px] font-bold text-gray-500 uppercase" }, "Birim Doğum Günü Ücreti"),
        h("div", { className: "text-xl font-black text-gray-900 mt-1" }, formatMoney(pricing.birthday_unit_price)),
        h("div", { className: "text-[11px] text-gray-500 mt-0.5" }, `Komisyondan bağımsızdır · Bu ay ${formatMoney(monthly.total_spent ?? monthly.total_cost)}`)
      ),
      h(Card, { className: "!p-4 border border-emerald-200 bg-emerald-50/30" },
        h("div", { className: "text-[11px] font-bold text-emerald-800 uppercase" }, "İzinli Müşteri / 30 Gün"),
        h("div", { className: "text-xl font-black text-emerald-900 mt-1" },
          `${data.eligible_customer_count || 0} / ${data.upcoming_eligible_birthdays_30d || 0}`
        ),
        h("div", { className: "text-[11px] text-emerald-700 mt-0.5" }, `Bu yıl gönderilen: ${data.sent_this_year_count || 0}`)
      )
    ),

    // Settings Form
    h(Card, { className: "!p-5 border border-gray-200" },
      h("form", { onSubmit: save, className: "space-y-4 text-xs" },
        h("div", { className: "flex items-center justify-between gap-3 pb-3 border-b border-gray-100" },
          h("div", null,
            h("div", { className: "text-sm font-bold text-gray-900" }, "Otomatik Doğum Günü Kutlamaları"),
            h("div", { className: "text-gray-500 mt-0.5" }, "Aktifleştirildiğinde yalnızca izinli müşterilere belirlediğiniz zamanlamada gönderilir.")
          ),
          h("label", { className: "relative inline-flex items-center cursor-pointer" },
            h("input", {
              type: "checkbox",
              checked: !!form.is_enabled,
              disabled: blocked,
              onChange: (e) => setForm((p) => ({ ...p, is_enabled: e.target.checked })),
              className: "sr-only peer",
            }),
            h("div", { className: "w-10 h-5 bg-slate-200 rounded-full peer peer-checked:after:translate-x-full after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-[#FF5722]" })
          )
        ),

        h("div", { className: "grid grid-cols-1 sm:grid-cols-2 gap-4" },
          h("div", { className: "space-y-2" },
            h("div", { className: "font-bold text-gray-800" }, "Gönderim Günü Seçenekleri"),
            [
              ["send_on_birthday", "Tam doğum gününde (0 gün önce)"],
              ["send_one_day_before", "1 gün önce gönder"],
              ["send_two_days_before", "2 gün önce gönder"],
            ].map(([key, label]) =>
              h("label", { key, className: "flex items-center gap-2 cursor-pointer text-gray-700" },
                h("input", {
                  type: "checkbox",
                  checked: !!form[key],
                  onChange: (e) => setForm((p) => ({ ...p, [key]: e.target.checked })),
                }),
                label
              )
            )
          ),

          h("div", null,
            h("label", { className: "block font-bold text-gray-800 mb-1" }, "Gönderim Saati"),
            h("input", {
              type: "time",
              required: true,
              value: form.send_time,
              onChange: (e) => setForm((p) => ({ ...p, send_time: e.target.value })),
              className: "w-full sm:w-44 px-3 py-2 rounded-xl border border-gray-300 text-sm",
            }),
            h("p", { className: "text-[11px] text-gray-400 mt-1" }, "Türkiye saatiyle (Europe/Istanbul) gönderim saati.")
          )
        ),

        h("div", null,
          h("div", { className: "font-bold text-gray-800 mb-2" }, "Tebrik Mesajı Şablonu"),
          h("div", { className: "grid grid-cols-1 sm:grid-cols-2 gap-2" },
            templates.map((tpl) =>
              h("label", {
                key: tpl.key,
                className: `p-3 rounded-xl border cursor-pointer ${form.template_key === tpl.key ? "border-[#FF5722] bg-orange-50" : "border-gray-200"}`,
              },
                h("div", { className: "flex items-center gap-2 font-bold text-gray-900" },
                  h("input", {
                    type: "radio",
                    name: "bday_template",
                    checked: form.template_key === tpl.key,
                    onChange: () => setForm((p) => ({ ...p, template_key: tpl.key })),
                  }),
                  tpl.label
                ),
                h("div", { className: "text-[11px] text-gray-600 mt-1" }, tpl.body)
              )
            ),
            h("label", {
              className: `p-3 rounded-xl border cursor-pointer ${form.template_key === "custom" ? "border-[#FF5722] bg-orange-50" : "border-gray-200"}`,
            },
              h("div", { className: "flex items-center gap-2 font-bold text-gray-900" },
                h("input", {
                  type: "radio",
                  name: "bday_template",
                  checked: form.template_key === "custom",
                  onChange: () => setForm((p) => ({ ...p, template_key: "custom" })),
                }),
                "Özel Mesaj Şablonu"
              ),
              h("div", { className: "text-[11px] text-gray-600 mt-1" }, "Kendi tebrik mesajınızı yazın (telefon/link içeremez).")
            )
          ),

          form.template_key === "custom" && h("textarea", {
            rows: 3,
            maxLength: 500,
            value: form.custom_message,
            onChange: (e) => setForm((p) => ({ ...p, custom_message: e.target.value })),
            placeholder: "Mutlu yıllar dileriz! Sizi salonumuzda ağırlamaktan mutluluk duyarız.",
            className: "mt-3 w-full px-3 py-2 rounded-xl border border-gray-300 text-sm",
          }),

          h("div", { className: "mt-3 p-3 rounded-xl bg-slate-900 text-white" },
            h("div", { className: "text-[10px] uppercase tracking-wider text-slate-400 font-bold mb-1" }, "Müşteri Bildirim Önizlemesi"),
            h("div", { className: "text-xs text-slate-100" }, previewText)
          )
        ),

        h("div", { className: "flex justify-end pt-2" },
          h(Button, { type: "submit", disabled: saving || blocked, className: "bg-[#FF5722] hover:bg-orange-600 text-white font-bold" },
            saving ? "Kaydediliyor…" : "Özel Gün Ayarlarını Kaydet"
          )
        )
      )
    ),

    // Masked Delivery History
    h(Card, { className: "!p-5 border border-gray-200" },
      h("h2", { className: "text-sm font-bold text-gray-900 mb-3" }, "Son Doğum Günü Gönderimleri (Maskeli Gizlilik Kaydı)"),
      (data.recent_deliveries || []).length === 0
        ? h("p", { className: "text-xs text-gray-500 py-4 text-center" }, "Henüz gönderilmiş doğum günü tebriği bulunmuyor.")
        : h("div", { className: "overflow-x-auto" },
            h("table", { className: "w-full text-left text-xs" },
              h("thead", null,
                h("tr", { className: "text-gray-400 border-b border-gray-100" },
                  h("th", { className: "pb-2" }, "Yıl"),
                  h("th", { className: "pb-2" }, "Birim Ücret"),
                  h("th", { className: "pb-2" }, "Tahsilat"),
                  h("th", { className: "pb-2" }, "Kaynak"),
                  h("th", { className: "pb-2" }, "Durum"),
                  h("th", { className: "pb-2" }, "Tarih")
                )
              ),
              h("tbody", { className: "divide-y divide-gray-100" },
                data.recent_deliveries.map((d) =>
                  h("tr", { key: d.id },
                    h("td", { className: "py-2.5 font-bold text-gray-800" }, d.birthday_year),
                    h("td", { className: "py-2.5" }, formatMoney(d.unit_price)),
                    h("td", { className: "py-2.5 font-bold" }, formatMoney(d.charged_amount)),
                    h("td", { className: "py-2.5" }, d.balance_source),
                    h("td", { className: "py-2.5" }, d.delivery_status),
                    h("td", { className: "py-2.5 text-gray-500" }, d.sent_at ? new Date(d.sent_at).toLocaleDateString("tr-TR") : "—")
                  )
                )
              )
            )
          )
    )
  );
}

export function WebNotificationFinanceSection({ onOpenBirthday, onOpenAds }) {
  const h = React.createElement;
  const [report, setReport] = React.useState(null);
  const [loading, setLoading] = React.useState(true);
  const [detail, setDetail] = React.useState(null);

  React.useEffect(() => {
    api.get("/provider/notification-report").then((r) => {
      if (r?.success && r.data) setReport(r.data);
    }).catch(() => {}).finally(() => setLoading(false));
  }, []);

  if (loading) return h("div", { className: "p-4 text-xs text-gray-500" }, "Bildirim ücret & bakiye raporu yükleniyor…");
  if (!report) return null;

  const w = report.wallet || {};
  const pr = report.pricing || {};
  const ms = report.monthly_summary || {};
  const bdayHist = Array.isArray(report.birthday_history) ? report.birthday_history : [];
  const adHist = Array.isArray(report.notification_ad_history) ? report.notification_ad_history : [];
  const dispatches = [
    ...bdayHist.map((d) => ({ ...d, _kind: "birthday", notification_type_label: "Doğum Günü Tebriği", canDetail: true })),
    ...adHist.map((a) => ({
      id: a.id,
      dispatch_id: a.notification_dispatch_id || a.dispatch_id || null,
      title: a.title || a.target_scope_label || "Bildirim Reklamı",
      notification_type_label: a.target_scope_label || "Bildirim Reklamı",
      targeted_count: a.targeted_count ?? a.estimated_recipients ?? 0,
      balance_source_label: a.balance_source_label || a.payment_method || "Cüzdan",
      total_cost: a.total_cost ?? a.price_tl ?? 0,
      canDetail: !!(a.notification_dispatch_id || a.dispatch_id),
      _kind: "ad",
    })),
  ];

  const openDispatch = async (id) => {
    if (!id) return;
    try {
      const res = await api.get(`/provider/notification-report/dispatches/${id}`);
      if (res?.success && res.data) setDetail(res.data);
    } catch {}
  };

  return h("div", { "data-testid": "provider-notification-finance" },
    h(Card, { className: "!p-5 border border-gray-200 space-y-4" },
      h("div", { className: "flex flex-wrap items-center justify-between gap-2 border-b border-gray-100 pb-3" },
        h("div", null,
          h("h3", { className: "text-base font-extrabold text-gray-900" }, "Bildirim Ücretleri & Promosyon Bakiye Raporu"),
          h("p", { className: "text-xs text-gray-500" }, "500 TL hoş geldin promosyonu komisyondan bağımsızdır; reklam ve doğum günü bildirimlerinde kullanılır.")
        ),
        h("div", { className: "flex gap-2" },
          onOpenAds && h("button", { type: "button", onClick: onOpenAds, className: "px-3 py-1.5 rounded-lg border border-orange-200 bg-orange-50 text-[#FF5722] text-xs font-bold" }, "Bildirim Reklamları"),
          onOpenBirthday && h("button", { type: "button", onClick: onOpenBirthday, className: "px-3 py-1.5 rounded-lg border border-slate-200 bg-slate-50 text-slate-800 text-xs font-bold" }, "Doğum Günü Asistanı")
        )
      ),

      h("div", { className: "grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs" },
        h("div", { className: "p-3 rounded-xl bg-purple-50 border border-purple-100" },
          h("div", { className: "text-purple-700 font-bold" }, "Kullanılabilir Promosyon"),
          h("div", { className: "text-lg font-black text-purple-900 mt-0.5" }, formatMoney(w.usable_promo_balance))
        ),
        h("div", { className: "p-3 rounded-xl bg-blue-50 border border-blue-100" },
          h("div", { className: "text-blue-700 font-bold" }, "Kullanılabilir Nakit"),
          h("div", { className: "text-lg font-black text-blue-900 mt-0.5" }, formatMoney(w.usable_cash_balance))
        ),
        h("div", { className: "p-3 rounded-xl bg-slate-50 border border-slate-200" },
          h("div", { className: "text-slate-600 font-bold" }, "Bu Ay Bildirim Harcaması"),
          h("div", { className: "text-lg font-black text-slate-900 mt-0.5" }, formatMoney(ms.total_spent ?? ms.total_cost)),
          h("div", { className: "text-[10px] text-slate-500" }, `Promo: ${formatMoney(ms.promo_spent)} · Nakit: ${formatMoney(ms.cash_spent)}`)
        ),
        h("div", { className: "p-3 rounded-xl bg-orange-50 border border-orange-100" },
          h("div", { className: "text-orange-800 font-bold" }, "Bildirim Birim Ücretleri"),
          h("div", { className: "text-xs font-bold text-gray-800 mt-1" }, `Doğum Günü: ${formatMoney(pr.birthday_unit_price)}`),
          h("div", { className: "text-[11px] text-gray-600" },
            `Promosyon: Doğum günü ${pr.allow_promo_for_birthday !== false ? "aktif" : "kapalı"} · Reklam ${pr.allow_promo_for_notification_ads !== false ? "aktif" : "kapalı"}`
          )
        )
      ),

      dispatches.length > 0 && h("div", null,
        h("div", { className: "text-xs font-bold text-gray-800 mb-2" }, "Son Bildirim Gönderimleriniz"),
        h("div", { className: "divide-y divide-gray-100 border border-gray-200 rounded-xl overflow-hidden text-xs" },
          dispatches.map((d) =>
            h("div", { key: `${d._kind}-${d.id}`, className: "p-3 flex items-center justify-between gap-2 hover:bg-gray-50" },
              h("div", { className: "min-w-0" },
                h("div", { className: "font-bold text-gray-900 truncate" }, d.title || d.notification_type_label),
                h("div", { className: "text-[11px] text-gray-500" }, `${d.notification_type_label} · Hedef: ${d.targeted_count} · Kaynak: ${d.balance_source_label}`)
              ),
              h("div", { className: "flex items-center gap-3 shrink-0" },
                h("span", { className: "font-extrabold text-gray-900" }, formatMoney(d.total_cost)),
                d.canDetail && h("button", { type: "button", onClick: () => openDispatch(d.dispatch_id || d.id), className: "text-[#FF5722] font-bold underline" }, "Detay")
              )
            )
          )
        )
      ),

      detail && h(Modal, { onClose: () => setDetail(null), className: "fixed inset-0 bg-black/50 flex items-center justify-center p-4" },
        h("div", { className: "bg-white rounded-2xl max-w-md w-full p-5 shadow-xl text-xs space-y-2" },
          h("div", { className: "flex items-center justify-between border-b border-gray-100 pb-2" },
            h("h4", { className: "font-bold text-sm text-gray-900" }, detail.title || detail.reference_code),
            h("button", { type: "button", onClick: () => setDetail(null) }, h(XIcon, { size: 16 }))
          ),
          h("p", { className: "text-gray-600" }, detail.body),
          h("div", { className: "grid grid-cols-2 gap-2 pt-2" },
            h("div", null, `Tip: ${detail.notification_type_label}`),
            h("div", null, `Durum: ${detail.status_label}`),
            h("div", null, `Toplam: ${formatMoney(detail.total_cost)}`),
            h("div", null, `Kaynak: ${detail.balance_source_label}`),
            h("div", null, `Hedef: ${detail.targeted_count}`),
            h("div", null, `İletilen: ${detail.fcm_accepted_count}`)
          )
        )
      )
    )
  );
}

export default WebBirthdayAssistant;
