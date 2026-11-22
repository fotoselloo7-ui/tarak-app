import { r as React } from "./react-vendor-Dj04zrcb.js?v=20261030-nearby-fallback1";
import { b as api } from "./index-Bj5sn6If.js?v=20261030-nearby-fallback1";
import { ensureParityStyles } from "./WebParityShared.js?v=20261122-web-parity1";

const PRESET_MINUTES = [15, 30, 45, 60, 120];

function ToggleRow({ id, title, subtitle, checked, disabled, onChange }) {
  const h = React.createElement;
  return h("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      gap: 12,
      padding: "10px 0",
      borderBottom: "1px solid #F1F5F9",
    },
  },
    h("div", { style: { minWidth: 0, flex: 1 } },
      h("label", { htmlFor: id, style: { display: "block", fontSize: 13, fontWeight: 700, color: "#0F172A", cursor: "pointer" } }, title),
      subtitle && h("div", { style: { fontSize: 11, color: "#64748B", marginTop: 2, lineHeight: 1.4 } }, subtitle)
    ),
    h("label", { className: "relative inline-flex items-center cursor-pointer", style: { flexShrink: 0 } },
      h("input", {
        id,
        type: "checkbox",
        checked: !!checked,
        disabled: !!disabled,
        onChange: (e) => onChange(e.target.checked),
        className: "sr-only peer",
      }),
      h("div", {
        className: "w-9 h-5 bg-slate-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-[#FF5722]",
      })
    )
  );
}

export function WebNotificationPreferences({ role = "CUSTOMER", onNotice, onNavigate }) {
  const h = React.createElement;
  ensureParityStyles();

  const [prefs, setPrefs] = React.useState(null);
  const [loading, setLoading] = React.useState(true);
  const [saving, setSaving] = React.useState(false);
  const [error, setError] = React.useState("");
  const [customOpen, setCustomOpen] = React.useState(false);
  const [customInput, setCustomInput] = React.useState("90");

  const load = React.useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const data = await api.notifications.getPushPreferences();
      setPrefs(data);
      const mins = Number(data?.appointment_reminder_minutes || 30);
      if (!PRESET_MINUTES.includes(mins)) {
        setCustomOpen(true);
        setCustomInput(String(mins));
      } else {
        setCustomOpen(false);
      }
    } catch (e) {
      setError(e?.message || "Bildirim tercihleri yüklenemedi.");
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => { load(); }, [load]);

  const persist = async (patch, successText = "Bildirim tercihiniz kaydedildi.") => {
    if (saving || !prefs) return;
    setSaving(true);
    setError("");
    const prev = prefs;
    setPrefs({ ...prefs, ...patch });
    try {
      const updated = await api.put("/push/preferences", patch);
      setPrefs(updated);
      onNotice?.(successText);
    } catch (e) {
      setPrefs(prev);
      const msg = e?.message || "Bildirim tercihi kaydedilemedi.";
      setError(msg);
      onNotice?.(msg);
    } finally {
      setSaving(false);
    }
  };

  const applyCustomMinutes = (e) => {
    e.preventDefault();
    const n = parseInt(String(customInput).trim(), 10);
    if (!Number.isFinite(n) || n < 5 || n > 1440) {
      setError("Özel hatırlatma süresi 5 ile 1440 dakika arasında olmalıdır.");
      return;
    }
    persist({ appointment_reminder_minutes: n }, `Hatırlatma süresi ${n} dakika olarak kaydedildi.`);
  };

  if (loading) {
    return h("div", { className: "bg-white rounded-2xl border border-slate-200 shadow-sm p-5 text-xs text-slate-500" },
      "Bildirim tercihleri yükleniyor…"
    );
  }

  if (!prefs) {
    return h("div", { className: "bg-white rounded-2xl border border-slate-200 shadow-sm p-5 text-xs text-rose-600" },
      error || "Bildirim tercihleri yüklenemedi. ",
      h("button", { type: "button", onClick: load, className: "underline font-bold ml-1 text-[#FF5722]" }, "Tekrar Dene")
    );
  }

  const mins = Number(prefs.appointment_reminder_minutes || 30);
  const isCustomActive = customOpen || !PRESET_MINUTES.includes(mins);
  const reminderOn = !!prefs.appointment_reminder_enabled;

  return h("div", { className: "bg-white rounded-2xl border border-slate-200 shadow-sm p-5", "data-testid": "notification-preferences-card" },
    h("div", { className: "flex items-center justify-between gap-2 pb-3 border-b border-slate-100 mb-2" },
      h("div", null,
        h("h3", { className: "text-sm font-bold text-slate-900" }, "Bildirim Tercihleri & Hatırlatmalar"),
        h("p", { style: { fontSize: 11, color: "#64748B", marginTop: 2 } },
          "Tercihleriniz hesabınızla senkronize edilir ve mobil push cihazlarınıza uygulanır."
        )
      ),
      saving && h("span", { style: { fontSize: 11, color: "#FF5722", fontWeight: 700 } }, "Kaydediliyor…")
    ),

    error && h("div", {
      role: "alert",
      style: { marginBottom: 10, padding: "8px 10px", borderRadius: 10, background: "#FEF2F2", border: "1px solid #FECACA", color: "#B91C1C", fontSize: 12 },
    }, error),

    h("div", null,
      h(ToggleRow, {
        id: `pref-push-${role}`,
        title: "Push Bildirimleri",
        subtitle: "Randevu, anlık talep, sohbet ve sistem bildirimleri",
        checked: prefs.push_enabled,
        disabled: saving,
        onChange: (val) => persist({ push_enabled: val }),
      }),

      role === "CUSTOMER" && h(ToggleRow, {
        id: "pref-campaign-cust",
        title: "Kampanya ve İndirim Bildirimleri",
        subtitle: "Yakınınızdaki veya geçmiş hizmet aldığınız işletmelerin indirim duyuruları",
        checked: prefs.campaign_enabled !== false,
        disabled: saving,
        onChange: (val) => persist({ campaign_enabled: val }),
      }),

      role === "CUSTOMER" && h(ToggleRow, {
        id: "pref-birthday-cust",
        title: "Doğum günü tebrikleri al",
        subtitle: "Hizmet aldığınız işletmelerin doğum günü kutlama mesajlarını almayı onaylayın",
        checked: !!prefs.birthday_greeting_enabled,
        disabled: saving,
        onChange: (val) => persist({ birthday_greeting_enabled: val }),
      }),

      h(ToggleRow, {
        id: `pref-rem-${role}`,
        title: "Randevu Hatırlatması",
        subtitle: "Planlı randevu başlamadan seçtiğiniz dakika önce bildirim alın (birim: dakika)",
        checked: reminderOn,
        disabled: saving,
        onChange: (val) => persist({ appointment_reminder_enabled: val }),
      }),

      reminderOn && h("div", { style: { padding: "10px 0", borderBottom: "1px solid #F1F5F9" } },
        h("div", { style: { fontSize: 11, fontWeight: 700, color: "#475569", marginBottom: 8 } },
          `Hatırlatma süresi (${mins} dakika önce)`
        ),
        h("div", { className: "twp-minute-row", role: "group", "aria-label": "Randevu hatırlatma dakikası" },
          PRESET_MINUTES.map((m) => {
            const active = !isCustomActive && mins === m;
            return h("button", {
              key: m,
              type: "button",
              disabled: saving,
              "aria-pressed": active,
              onClick: () => {
                setCustomOpen(false);
                persist({ appointment_reminder_minutes: m }, `Hatırlatma süresi ${m} dakika olarak kaydedildi.`);
              },
              className: `twp-minute-btn ${active ? "is-active" : ""}`,
            }, String(m));
          }),
          h("button", {
            type: "button",
            disabled: saving,
            "aria-pressed": isCustomActive,
            onClick: () => {
              setCustomOpen(true);
              if (PRESET_MINUTES.includes(mins)) setCustomInput(String(mins));
            },
            className: `twp-minute-btn ${isCustomActive ? "is-active" : ""}`,
          }, "Özel")
        ),
        isCustomActive && h("form", {
          onSubmit: applyCustomMinutes,
          style: { display: "flex", alignItems: "center", gap: 8, marginTop: 8, flexWrap: "wrap" },
        },
          h("input", {
            type: "number",
            min: 5,
            max: 1440,
            value: customInput,
            onChange: (e) => setCustomInput(e.target.value),
            "aria-label": "Özel hatırlatma dakikası (5-1440)",
            style: { width: 96, padding: "6px 10px", borderRadius: 8, border: "1px solid #CBD5E1", fontSize: 12 },
          }),
          h("span", { style: { fontSize: 11, color: "#64748B" } }, "dakika (5–1440)"),
          h("button", {
            type: "submit",
            disabled: saving,
            style: {
              padding: "6px 12px", borderRadius: 8, background: "#0F172A", color: "#fff",
              fontSize: 12, fontWeight: 700, border: "none", cursor: "pointer",
            },
          }, "Uygula")
        )
      ),

      h(ToggleRow, {
        id: `pref-start-alert-${role}`,
        title: "Tam Randevu Saati Bildirimi",
        subtitle: role === "CUSTOMER"
          ? "Randevu saatinde hizmet veren adı ve saat bilgisiyle anlık bildirim gönderilir"
          : "Randevu saati geldiğinde müşteri ve hizmet bilgisiyle bildirim alın",
        checked: prefs.appointment_start_alert_enabled !== false,
        disabled: saving,
        onChange: (val) => persist({ appointment_start_alert_enabled: val }),
      })
    ),

    role === "PROVIDER" && onNavigate && h("div", {
      style: {
        marginTop: 12,
        paddingTop: 12,
        display: "flex",
        flexWrap: "wrap",
        gap: 8,
      },
    },
      h("button", {
        type: "button",
        onClick: () => onNavigate("barber", { tab: "featured" }),
        style: { padding: "6px 11px", borderRadius: 9, border: "1px solid #FDBA74", background: "#FFF7ED", color: "#C2410C", fontSize: 11, fontWeight: 700, cursor: "pointer" },
      }, "Bildirim Reklamları"),
      h("button", {
        type: "button",
        onClick: () => onNavigate("barber", { tab: "birthday" }),
        style: { padding: "6px 11px", borderRadius: 9, border: "1px solid #E2E8F0", background: "#F8FAFC", color: "#0F172A", fontSize: 11, fontWeight: 700, cursor: "pointer" },
      }, "Özel Gün Asistanı"),
      h("button", {
        type: "button",
        onClick: () => onNavigate("barber", { tab: "wallet" }),
        style: { padding: "6px 11px", borderRadius: 9, border: "1px solid #E2E8F0", background: "#F8FAFC", color: "#0F172A", fontSize: 11, fontWeight: 700, cursor: "pointer" },
      }, "Bildirim Bakiye & Raporu")
    ),

    h("p", {
      style: {
        marginTop: 10,
        fontSize: 11,
        color: "#64748B",
        background: "#F8FAFC",
        border: "1px solid #E2E8F0",
        borderRadius: 10,
        padding: "8px 10px",
        lineHeight: 1.45,
      },
    }, "Bilgi: Web tarayıcı masaüstü push aboneliği şu an etkin değildir; bildirimleriniz uygulama içi bildirim kutunuza ve kayıtlı Tarak mobil cihazlarınıza iletilir.")
  );
}

export default WebNotificationPreferences;
