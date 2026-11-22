import { r as React } from "./react-vendor-Dj04zrcb.js?v=20261030-nearby-fallback1";
import {
  b as api,
  B as Button,
  C as Card,
  M as Modal,
  X as XIcon,
  g as Calendar,
  a3 as Clock,
  N as Users,
} from "./index-Bj5sn6If.js?v=20261030-nearby-fallback1";
import { DAY_LABELS_TR, AvatarOrMonogram } from "./WebParityShared.js?v=20261122-web-parity1";

const ORDERED_DAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];

function buildDefaultSchedule(existing = []) {
  const byDay = {};
  for (const row of existing || []) {
    const k = String(row.day_of_week || row.day || "").toLowerCase();
    if (k) byDay[k] = row;
  }
  return ORDERED_DAYS.map((day) => {
    const row = byDay[day];
    return {
      day_of_week: day,
      is_enabled: row ? !!row.is_enabled : day !== "sunday",
      start_time: row?.start_time ? String(row.start_time).slice(0, 5) : "09:00",
      end_time: row?.end_time ? String(row.end_time).slice(0, 5) : "20:00",
      breaks: Array.isArray(row?.breaks)
        ? row.breaks.map((b) => ({ start_time: String(b.start_time).slice(0, 5), end_time: String(b.end_time).slice(0, 5) }))
        : [],
    };
  });
}

export function WebProviderStaffManager({ appointments = [], onNotice, onSelectStaffForCalendar }) {
  const h = React.createElement;
  const [staff, setStaff] = React.useState([]);
  const [providerServices, setProviderServices] = React.useState([]);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState("");
  const [showArchived, setShowArchived] = React.useState(false);

  // Modal state
  const [editing, setEditing] = React.useState(null); // null | "new" | staff object
  const [saving, setSaving] = React.useState(false);
  const [formErr, setFormErr] = React.useState("");
  const [form, setForm] = React.useState({
    first_name: "",
    last_name: "",
    title: "",
    specialty: "",
    is_active: true,
    accepts_appointments: true,
    visible_to_customers: true,
    serviceMap: {}, // service_id -> { enabled, custom_duration_minutes }
    schedule: buildDefaultSchedule([]),
  });
  const [photoFile, setPhotoFile] = React.useState(null);
  const [photoPreview, setPhotoPreview] = React.useState("");

  // Time-off modal state
  const [timeOffTarget, setTimeOffTarget] = React.useState(null);
  const [timeOffForm, setTimeOffForm] = React.useState({
    start_date: new Date().toISOString().slice(0, 10),
    end_date: new Date().toISOString().slice(0, 10),
    start_time: "",
    end_time: "",
    reason: "izin",
    note: "",
  });
  const [timeOffBusy, setTimeOffBusy] = React.useState(false);

  // Selected staff appointments viewer
  const [apptViewStaff, setApptViewStaff] = React.useState(null);

  const loadAll = React.useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const [sRes, svcRes] = await Promise.all([
        api.get("/provider/staff"),
        api.provider.getServices(),
      ]);
      setStaff(Array.isArray(sRes?.data) ? sRes.data : []);
      setProviderServices(Array.isArray(svcRes?.data) ? svcRes.data : []);
    } catch (e) {
      setError(e?.message || "Çalışan listesi yüklenemedi.");
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => { loadAll(); }, [loadAll]);

  const openNewModal = () => {
    const svcMap = {};
    for (const ps of providerServices) {
      if (ps.is_active !== false) {
        const sid = String(ps.service_id || ps.service?.id || ps.id);
        svcMap[sid] = { enabled: true, custom_duration_minutes: "" };
      }
    }
    setForm({
      first_name: "",
      last_name: "",
      title: "",
      specialty: "",
      is_active: true,
      accepts_appointments: true,
      visible_to_customers: true,
      serviceMap: svcMap,
      schedule: buildDefaultSchedule([]),
    });
    setPhotoFile(null);
    setPhotoPreview("");
    setFormErr("");
    setEditing("new");
  };

  const openEditModal = (st) => {
    const svcMap = {};
    for (const ps of providerServices) {
      const sid = String(ps.service_id || ps.service?.id || ps.id);
      const existing = (st.services || []).find((x) => String(x.service_id) === sid && x.is_active !== false);
      svcMap[sid] = {
        enabled: !!existing,
        custom_duration_minutes: existing?.custom_duration_minutes ? String(existing.custom_duration_minutes) : "",
      };
    }
    setForm({
      first_name: st.first_name || "",
      last_name: st.last_name || "",
      title: st.title || "",
      specialty: st.specialty || "",
      is_active: st.is_active !== false,
      accepts_appointments: st.accepts_appointments !== false,
      visible_to_customers: st.visible_to_customers !== false,
      serviceMap: svcMap,
      schedule: buildDefaultSchedule(st.schedule || []),
    });
    setPhotoFile(null);
    setPhotoPreview(st.photo_url || "");
    setFormErr("");
    setEditing(st);
  };

  const saveStaff = async (e) => {
    e.preventDefault();
    if (saving) return;
    if (!form.first_name.trim() || !form.last_name.trim()) {
      setFormErr("Ad ve soyad alanları zorunludur.");
      return;
    }

    setSaving(true);
    setFormErr("");
    try {
      const servicesPayload = Object.entries(form.serviceMap)
        .filter(([, cfg]) => cfg.enabled)
        .map(([sid, cfg]) => ({
          service_id: Number(sid),
          custom_duration_minutes: cfg.custom_duration_minutes ? Number(cfg.custom_duration_minutes) : null,
          is_active: true,
        }));

      const payload = {
        first_name: form.first_name.trim(),
        last_name: form.last_name.trim(),
        title: form.title.trim() || null,
        specialty: form.specialty.trim() || null,
        is_active: !!form.is_active,
        accepts_appointments: !!form.accepts_appointments,
        visible_to_customers: !!form.visible_to_customers,
        services: servicesPayload,
        schedule: form.schedule,
      };

      let savedStaffId = editing === "new" ? null : editing.id;
      if (editing === "new") {
        const res = await api.post("/provider/staff", payload);
        savedStaffId = res?.data?.id;
      } else {
        await api.put(`/provider/staff/${editing.id}`, payload);
      }

      if (photoFile && savedStaffId) {
        const fd = new FormData();
        fd.append("photo", photoFile);
        await api.provider.uploadStaffPhoto(savedStaffId, fd);
      }

      onNotice?.(editing === "new" ? "Yeni çalışan eklendi." : "Çalışan bilgileri güncellendi.");
      setEditing(null);
      await loadAll();
    } catch (err) {
      setFormErr(err?.message || "Çalışan kaydedilemedi.");
    } finally {
      setSaving(false);
    }
  };

  const removeCurrentPhoto = async () => {
    if (editing && editing !== "new" && editing.photo_url) {
      try {
        await api.delete(`/provider/staff/${editing.id}/photo`);
        setPhotoPreview("");
        setPhotoFile(null);
        await loadAll();
        onNotice?.("Çalışan fotoğrafı kaldırıldı.");
      } catch (err) {
        setFormErr(err?.message || "Fotoğraf silinemedi.");
      }
    } else {
      setPhotoFile(null);
      setPhotoPreview("");
    }
  };

  const toggleArchive = async (st) => {
    try {
      if (st.is_active) {
        if (!window.confirm(`${st.full_name} pasife (arşive) alınsın mı? Geçmiş randevuları korunur.`)) return;
        await api.delete(`/provider/staff/${st.id}`);
        onNotice?.(`${st.full_name} arşive alındı.`);
      } else {
        await api.put(`/provider/staff/${st.id}`, { is_active: true, visible_to_customers: true, accepts_appointments: true });
        onNotice?.(`${st.full_name} tekrar aktifleştirildi.`);
      }
      await loadAll();
    } catch (err) {
      setError(err?.message || "Durum güncellenemedi.");
    }
  };

  const saveTimeOff = async (e) => {
    e.preventDefault();
    if (!timeOffTarget || timeOffBusy) return;
    setTimeOffBusy(true);
    try {
      await api.post(`/provider/staff/${timeOffTarget.id}/time-offs`, {
        start_date: timeOffForm.start_date,
        end_date: timeOffForm.end_date,
        start_time: timeOffForm.start_time || null,
        end_time: timeOffForm.end_time || null,
        reason: timeOffForm.reason || "izin",
        note: timeOffForm.note.trim() || null,
      });
      onNotice?.("Çalışan izni eklendi.");
      await loadAll();
      // Keep target synced with reloaded row
      setTimeOffTarget((prev) => prev ? ({ ...prev }) : null);
      setTimeOffForm((p) => ({ ...p, note: "", start_time: "", end_time: "" }));
    } catch (err) {
      alert(err?.message || "İzin kaydedilemedi.");
    } finally {
      setTimeOffBusy(false);
    }
  };

  const deleteTimeOff = async (staffId, toId) => {
    try {
      await api.delete(`/provider/staff/${staffId}/time-offs/${toId}`);
      await loadAll();
      onNotice?.("İzin kaydı silindi.");
    } catch (err) {
      alert(err?.message || "İzin silinemedi.");
    }
  };

  const visibleStaff = staff.filter((s) => showArchived ? true : (s.is_active && !s.archived_at));
  const currentTargetFresh = timeOffTarget ? staff.find((x) => x.id === timeOffTarget.id) || timeOffTarget : null;

  return h("div", { className: "space-y-5", "data-testid": "provider-staff-manager" },
    h("div", { className: "flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-white rounded-2xl border border-gray-200 p-5 shadow-2xs" },
      h("div", null,
        h("h1", { className: "text-xl font-extrabold text-gray-950 flex items-center gap-2" },
          h(Users, { size: 22, className: "text-[#FF5722]" }), "Çalışanlarım & Uzman Takvimleri"
        ),
        h("p", { className: "text-xs text-gray-500 mt-1" },
          "İşletmenizdeki ustaları, sundukları hizmetleri, özel mesai/mola ve izin günlerini yönetin. Müşteriler randevuda çalışan seçebilir."
        )
      ),
      h("div", { className: "flex items-center gap-2.5 shrink-0" },
        h("button", {
          type: "button",
          onClick: () => setShowArchived((v) => !v),
          className: "px-3 py-2 rounded-xl border border-gray-200 text-xs font-bold text-gray-600 hover:bg-gray-50",
        }, showArchived ? "Sadece Aktifler" : `Arşiv Dahil (${staff.length})`),
        h(Button, { onClick: openNewModal, size: "sm", className: "bg-[#FF5722] hover:bg-orange-600 text-white font-bold" },
          "+ Yeni Çalışan"
        )
      )
    ),

    error && h("div", { className: "p-4 rounded-xl bg-rose-50 border border-rose-200 text-xs text-rose-700" }, error),

    loading
      ? h("div", { className: "p-12 text-center text-sm text-gray-500" }, "Çalışanlar yükleniyor…")
      : visibleStaff.length === 0
        ? h(Card, { className: "text-center !py-10" },
            h("p", { className: "text-sm font-semibold text-gray-700 mb-1" }, "Henüz eklenmiş bir çalışan yok."),
            h("p", { className: "text-xs text-gray-500 mb-4" }, "Çalışan eklemediğinizde salonunuz tekli işletme takvimi ile çalışmaya devam eder."),
            h(Button, { onClick: openNewModal, size: "sm" }, "İlk Çalışanı Ekle")
          )
        : h("div", { className: "grid grid-cols-1 md:grid-cols-2 gap-4" },
            visibleStaff.map((st) => {
              const staffAppts = appointments.filter((a) => String(a.staff_id) === String(st.id));
              return h(Card, { key: st.id, className: `!p-4 border ${st.is_active ? "border-gray-200" : "border-gray-200 bg-gray-50/80 opacity-80"}` },
                h("div", { className: "flex items-start gap-3" },
                  h(AvatarOrMonogram, { src: st.photo_url, name: st.full_name, size: 58, rounded: "14px" }),
                  h("div", { className: "min-w-0 flex-1" },
                    h("div", { className: "flex items-center justify-between gap-2" },
                      h("h3", { className: "font-extrabold text-sm text-gray-950 truncate" }, st.full_name),
                      h("span", {
                        className: `text-[10px] font-bold px-2 py-0.5 rounded-full ${st.is_active ? "bg-emerald-50 text-emerald-700" : "bg-gray-200 text-gray-700"}`,
                      }, st.is_active ? "Aktif" : "Pasif / Arşiv")
                    ),
                    st.title && h("div", { className: "text-xs font-semibold text-[#FF5722] truncate" }, st.title),
                    st.specialty && h("div", { className: "text-[11px] text-gray-500 mt-0.5 truncate" }, st.specialty),
                    h("div", { className: "flex flex-wrap gap-1.5 mt-2 text-[10px] font-bold" },
                      h("span", { className: `px-2 py-0.5 rounded ${st.accepts_appointments ? "bg-blue-50 text-blue-700" : "bg-amber-50 text-amber-700"}` },
                        st.accepts_appointments ? "Randevuya Açık" : "Randevu Kapalı"
                      ),
                      h("span", { className: `px-2 py-0.5 rounded ${st.visible_to_customers ? "bg-slate-100 text-slate-700" : "bg-slate-100 text-slate-400"}` },
                        st.visible_to_customers ? "Müşteriye Görünür" : "Gizli"
                      ),
                      h("span", { className: "px-2 py-0.5 rounded bg-orange-50 text-orange-800" },
                        `${(st.services || []).filter((x) => x.is_active !== false).length} hizmet · ${staffAppts.length} randevu`
                      )
                    )
                  )
                ),

                h("div", { className: "mt-3 pt-3 border-t border-gray-100 flex flex-wrap gap-2" },
                  h("button", {
                    type: "button",
                    onClick: () => openEditModal(st),
                    className: "px-3 py-1.5 rounded-lg bg-slate-900 hover:bg-slate-800 text-white text-xs font-bold",
                  }, "Düzenle"),
                  h("button", {
                    type: "button",
                    onClick: () => setTimeOffTarget(st),
                    className: "px-3 py-1.5 rounded-lg border border-gray-200 hover:bg-gray-50 text-gray-700 text-xs font-bold",
                  }, `İzinler (${(st.time_offs || []).length})`),
                  h("button", {
                    type: "button",
                    onClick: () => {
                      if (onSelectStaffForCalendar) onSelectStaffForCalendar(st);
                      else setApptViewStaff(st);
                    },
                    className: "px-3 py-1.5 rounded-lg border border-orange-200 bg-orange-50 text-[#FF5722] text-xs font-bold",
                  }, `Randevuları (${staffAppts.length})`),
                  h("button", {
                    type: "button",
                    onClick: () => toggleArchive(st),
                    className: `ml-auto px-3 py-1.5 rounded-lg text-xs font-bold ${st.is_active ? "text-rose-600 hover:bg-rose-50" : "text-emerald-700 hover:bg-emerald-50"}`,
                  }, st.is_active ? "Arşivle" : "Aktifleştir")
                )
              );
            })
          ),

    // Staff appointments quick drawer modal if callback not provided
    apptViewStaff && h(Modal, { onClose: () => setApptViewStaff(null), className: "fixed inset-0 bg-black/50 flex items-center justify-center p-4" },
      h("div", { className: "bg-white rounded-2xl w-full max-w-lg max-h-[80vh] overflow-y-auto p-5 shadow-xl" },
        h("div", { className: "flex items-center justify-between mb-3 pb-2 border-b border-gray-100" },
          h("h3", { className: "font-bold text-base text-gray-900" }, `${apptViewStaff.full_name} — Randevular`),
          h("button", { type: "button", onClick: () => setApptViewStaff(null), className: "p-1 text-gray-400" }, h(XIcon, { size: 18 }))
        ),
        (() => {
          const list = appointments.filter((a) => String(a.staff_id) === String(apptViewStaff.id));
          if (!list.length) return h("p", { className: "text-sm text-gray-500 py-6 text-center" }, "Bu çalışana atanmış randevu bulunmuyor.");
          return h("div", { className: "space-y-2.5" },
            list.map((a) =>
              h("div", { key: a.id, className: "p-3 rounded-xl border border-gray-200 text-xs flex justify-between gap-2" },
                h("div", null,
                  h("div", { className: "font-bold text-gray-900" }, a.customer_name || a.guest_customer_name || "Müşteri"),
                  h("div", { className: "text-gray-600" }, a.service_name),
                  h("div", { className: "text-gray-400 mt-0.5" }, a.start_time.replace("T", " ").slice(0, 16))
                ),
                h("div", { className: "text-right font-bold text-[#FF5722]" }, `₺${a.price}`)
              )
            )
          );
        })()
      )
    ),

    // Add / Edit Staff Modal
    editing && h(Modal, { onClose: () => setEditing(null), className: "fixed inset-0 bg-black/60 flex items-center justify-center p-3 sm:p-4" },
      h("div", { className: "bg-white rounded-2xl w-full max-w-2xl max-h-[90vh] flex flex-col shadow-2xl overflow-hidden" },
        h("div", { className: "flex items-center justify-between px-5 py-4 border-b border-gray-100" },
          h("h3", { className: "font-extrabold text-base text-gray-900" }, editing === "new" ? "Yeni Çalışan Ekle" : `Çalışanı Düzenle — ${editing.full_name}`),
          h("button", { type: "button", onClick: () => setEditing(null), className: "p-1 rounded-lg text-gray-400 hover:bg-gray-100" }, h(XIcon, { size: 18 }))
        ),
        h("form", { onSubmit: saveStaff, className: "overflow-y-auto p-5 space-y-5" },
          formErr && h("div", { className: "p-3 rounded-xl bg-rose-50 border border-rose-200 text-xs text-rose-700" }, formErr),

          // Photo upload row
          h("div", { className: "flex items-center gap-4 p-3 rounded-xl bg-slate-50 border border-slate-200" },
            h(AvatarOrMonogram, { src: photoPreview, name: `${form.first_name} ${form.last_name}`.trim() || "U", size: 64, rounded: "16px" }),
            h("div", { className: "space-y-1.5" },
              h("div", { className: "text-xs font-bold text-gray-800" }, "Çalışan Profil Fotoğrafı"),
              h("div", { className: "flex flex-wrap items-center gap-2" },
                h("label", { className: "px-3 py-1.5 rounded-lg bg-white border border-gray-300 text-xs font-bold text-gray-700 cursor-pointer hover:bg-gray-50" },
                  "Fotoğraf Seç",
                  h("input", {
                    type: "file",
                    accept: "image/jpeg,image/png,image/webp",
                    className: "hidden",
                    onChange: (e) => {
                      const f = e.target.files?.[0];
                      if (f) {
                        setPhotoFile(f);
                        setPhotoPreview(URL.createObjectURL(f));
                      }
                    },
                  })
                ),
                photoPreview && h("button", {
                  type: "button",
                  onClick: removeCurrentPhoto,
                  className: "px-2.5 py-1.5 rounded-lg text-xs font-semibold text-rose-600 hover:bg-rose-50",
                }, "Kaldır")
              )
            )
          ),

          h("div", { className: "grid grid-cols-1 sm:grid-cols-2 gap-3" },
            h("div", null,
              h("label", { className: "block text-xs font-bold text-gray-700 mb-1" }, "Ad *"),
              h("input", {
                required: true,
                value: form.first_name,
                onChange: (e) => setForm((p) => ({ ...p, first_name: e.target.value })),
                className: "w-full px-3 py-2 rounded-xl border border-gray-300 text-sm",
              })
            ),
            h("div", null,
              h("label", { className: "block text-xs font-bold text-gray-700 mb-1" }, "Soyad *"),
              h("input", {
                required: true,
                value: form.last_name,
                onChange: (e) => setForm((p) => ({ ...p, last_name: e.target.value })),
                className: "w-full px-3 py-2 rounded-xl border border-gray-300 text-sm",
              })
            ),
            h("div", null,
              h("label", { className: "block text-xs font-bold text-gray-700 mb-1" }, "Unvan / Pozisyon"),
              h("input", {
                placeholder: "Örn: Baş Berber",
                value: form.title,
                onChange: (e) => setForm((p) => ({ ...p, title: e.target.value })),
                className: "w-full px-3 py-2 rounded-xl border border-gray-300 text-sm",
              })
            ),
            h("div", null,
              h("label", { className: "block text-xs font-bold text-gray-700 mb-1" }, "Uzmanlık Alanı"),
              h("input", {
                placeholder: "Örn: Skin Fade & Sakal",
                value: form.specialty,
                onChange: (e) => setForm((p) => ({ ...p, specialty: e.target.value })),
                className: "w-full px-3 py-2 rounded-xl border border-gray-300 text-sm",
              })
            )
          ),

          h("div", { className: "grid grid-cols-1 sm:grid-cols-3 gap-2 text-xs" },
            [
              ["is_active", "Aktif Çalışan"],
              ["accepts_appointments", "Randevu Kabul Ediyor"],
              ["visible_to_customers", "Müşteri Seçiminde Görünür"],
            ].map(([k, lbl]) =>
              h("label", { key: k, className: "flex items-center gap-2 p-2.5 rounded-xl border border-gray-200 cursor-pointer" },
                h("input", {
                  type: "checkbox",
                  checked: !!form[k],
                  onChange: (e) => setForm((p) => ({ ...p, [k]: e.target.checked })),
                }),
                h("span", { className: "font-semibold text-gray-800" }, lbl)
              )
            )
          ),

          // Services & Custom Durations
          providerServices.length > 0 && h("div", null,
            h("div", { className: "text-xs font-bold text-gray-900 mb-2" }, "Verdiği Hizmetler ve Özel Süreler (dk)"),
            h("div", { className: "space-y-2 max-h-48 overflow-y-auto pr-1" },
              providerServices.map((ps) => {
                const sid = String(ps.service_id || ps.service?.id || ps.id);
                const cfg = form.serviceMap[sid] || { enabled: false, custom_duration_minutes: "" };
                return h("div", { key: sid, className: "flex items-center justify-between gap-2 p-2 rounded-xl border border-gray-200 text-xs" },
                  h("label", { className: "flex items-center gap-2 cursor-pointer flex-1 min-w-0" },
                    h("input", {
                      type: "checkbox",
                      checked: !!cfg.enabled,
                      onChange: (e) => setForm((p) => ({
                        ...p,
                        serviceMap: { ...p.serviceMap, [sid]: { ...cfg, enabled: e.target.checked } },
                      })),
                    }),
                    h("span", { className: "font-semibold text-gray-800 truncate" }, ps.name || ps.service?.name || `Hizmet #${sid}`)
                  ),
                  cfg.enabled && h("input", {
                    type: "number",
                    min: 5,
                    max: 480,
                    placeholder: "Varsayılan dk",
                    value: cfg.custom_duration_minutes,
                    onChange: (e) => setForm((p) => ({
                      ...p,
                      serviceMap: { ...p.serviceMap, [sid]: { ...cfg, custom_duration_minutes: e.target.value } },
                    })),
                    style: { width: 105, padding: "4px 8px", borderRadius: 8, border: "1px solid #CBD5E1" },
                  })
                );
              })
            )
          ),

          // Weekly Schedule & Breaks
          h("div", null,
            h("div", { className: "text-xs font-bold text-gray-900 mb-2" }, "Haftalık Çalışma Saatleri & Molalar"),
            h("div", { className: "space-y-2" },
              form.schedule.map((row, idx) =>
                h("div", { key: row.day_of_week, className: "p-2.5 rounded-xl border border-gray-200 text-xs space-y-2" },
                  h("div", { className: "flex flex-wrap items-center justify-between gap-2" },
                    h("label", { className: "flex items-center gap-2 font-bold text-gray-800 min-w-[110px]" },
                      h("input", {
                        type: "checkbox",
                        checked: !!row.is_enabled,
                        onChange: (e) => setForm((p) => ({
                          ...p,
                          schedule: p.schedule.map((r, i) => i === idx ? { ...r, is_enabled: e.target.checked } : r),
                        })),
                      }),
                      DAY_LABELS_TR[row.day_of_week] || row.day_of_week
                    ),
                    row.is_enabled
                      ? h("div", { className: "flex items-center gap-1.5 flex-wrap" },
                          h("input", {
                            type: "time",
                            value: row.start_time,
                            onChange: (e) => setForm((p) => ({
                              ...p,
                              schedule: p.schedule.map((r, i) => i === idx ? { ...r, start_time: e.target.value } : r),
                            })),
                            className: "border border-gray-300 rounded-lg px-2 py-1",
                          }),
                          h("span", null, "–"),
                          h("input", {
                            type: "time",
                            value: row.end_time,
                            onChange: (e) => setForm((p) => ({
                              ...p,
                              schedule: p.schedule.map((r, i) => i === idx ? { ...r, end_time: e.target.value } : r),
                            })),
                            className: "border border-gray-300 rounded-lg px-2 py-1",
                          }),
                          h("button", {
                            type: "button",
                            onClick: () => setForm((p) => ({
                              ...p,
                              schedule: p.schedule.map((r, i) => i === idx ? { ...r, breaks: [...r.breaks, { start_time: "12:30", end_time: "13:30" }] } : r),
                            })),
                            className: "px-2 py-1 rounded bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-[11px]",
                          }, "+ Mola")
                        )
                      : h("span", { className: "text-gray-400" }, "Kapalı")
                  ),
                  row.is_enabled && row.breaks.length > 0 && h("div", { className: "pl-6 flex flex-wrap gap-2" },
                    row.breaks.map((b, bIdx) =>
                      h("div", { key: bIdx, className: "inline-flex items-center gap-1 bg-orange-50 border border-orange-200 rounded-lg px-2 py-1" },
                        h("input", {
                          type: "time",
                          value: b.start_time,
                          onChange: (e) => setForm((p) => ({
                            ...p,
                            schedule: p.schedule.map((r, i) => i === idx ? {
                              ...r,
                              breaks: r.breaks.map((x, j) => j === bIdx ? { ...x, start_time: e.target.value } : x),
                            } : r),
                          })),
                          className: "bg-transparent text-[11px]",
                        }),
                        h("span", null, "-"),
                        h("input", {
                          type: "time",
                          value: b.end_time,
                          onChange: (e) => setForm((p) => ({
                            ...p,
                            schedule: p.schedule.map((r, i) => i === idx ? {
                              ...r,
                              breaks: r.breaks.map((x, j) => j === bIdx ? { ...x, end_time: e.target.value } : x),
                            } : r),
                          })),
                          className: "bg-transparent text-[11px]",
                        }),
                        h("button", {
                          type: "button",
                          onClick: () => setForm((p) => ({
                            ...p,
                            schedule: p.schedule.map((r, i) => i === idx ? { ...r, breaks: r.breaks.filter((_, j) => j !== bIdx) } : r),
                          })),
                          className: "text-rose-600 font-bold ml-1",
                        }, "×")
                      )
                    )
                  )
                )
              )
            )
          ),

          h("div", { className: "flex justify-end gap-2 pt-3 border-t border-gray-100" },
            h(Button, { type: "button", variant: "ghost", onClick: () => setEditing(null) }, "Vazgeç"),
            h(Button, { type: "submit", disabled: saving, className: "bg-[#FF5722] hover:bg-orange-600 text-white" },
              saving ? "Kaydediliyor…" : "Kaydet"
            )
          )
        )
      )
    ),

    // Staff Time-Off Modal
    currentTargetFresh && h(Modal, { onClose: () => setTimeOffTarget(null), className: "fixed inset-0 bg-black/60 flex items-center justify-center p-4" },
      h("div", { className: "bg-white rounded-2xl w-full max-w-md max-h-[85vh] overflow-y-auto p-5 shadow-2xl space-y-4" },
        h("div", { className: "flex items-center justify-between pb-2 border-b border-gray-100" },
          h("h3", { className: "font-bold text-base text-gray-900" }, `${currentTargetFresh.full_name} — İzin & Kapalı Saatler`),
          h("button", { type: "button", onClick: () => setTimeOffTarget(null), className: "p-1 text-gray-400" }, h(XIcon, { size: 18 }))
        ),

        (currentTargetFresh.time_offs || []).length > 0 && h("div", { className: "space-y-2" },
          currentTargetFresh.time_offs.map((t) =>
            h("div", { key: t.id, className: "p-2.5 rounded-xl bg-slate-50 border border-slate-200 flex items-center justify-between gap-2 text-xs" },
              h("div", null,
                h("div", { className: "font-bold text-gray-900" }, `${t.start_date} → ${t.end_date}`),
                h("div", { className: "text-gray-500" },
                  `${t.start_time && t.end_time ? `${t.start_time}-${t.end_time}` : "Tüm gün"} · ${t.reason || "izin"}`
                )
              ),
              h("button", {
                type: "button",
                onClick: () => deleteTimeOff(currentTargetFresh.id, t.id),
                className: "text-rose-600 font-bold hover:underline",
              }, "Sil")
            )
          )
        ),

        h("form", { onSubmit: saveTimeOff, className: "space-y-3 pt-2 border-t border-gray-100 text-xs" },
          h("div", { className: "grid grid-cols-2 gap-2" },
            h("label", null, "Başlangıç",
              h("input", {
                type: "date",
                required: true,
                value: timeOffForm.start_date,
                onChange: (e) => setTimeOffForm((p) => ({ ...p, start_date: e.target.value })),
                className: "mt-1 w-full px-2.5 py-2 border border-gray-300 rounded-lg",
              })
            ),
            h("label", null, "Bitiş",
              h("input", {
                type: "date",
                required: true,
                value: timeOffForm.end_date,
                onChange: (e) => setTimeOffForm((p) => ({ ...p, end_date: e.target.value })),
                className: "mt-1 w-full px-2.5 py-2 border border-gray-300 rounded-lg",
              })
            )
          ),
          h("div", { className: "grid grid-cols-2 gap-2" },
            h("label", null, "Saat Başlangıç (Opsiyonel)",
              h("input", {
                type: "time",
                value: timeOffForm.start_time,
                onChange: (e) => setTimeOffForm((p) => ({ ...p, start_time: e.target.value })),
                className: "mt-1 w-full px-2.5 py-2 border border-gray-300 rounded-lg",
              })
            ),
            h("label", null, "Saat Bitiş (Opsiyonel)",
              h("input", {
                type: "time",
                value: timeOffForm.end_time,
                onChange: (e) => setTimeOffForm((p) => ({ ...p, end_time: e.target.value })),
                className: "mt-1 w-full px-2.5 py-2 border border-gray-300 rounded-lg",
              })
            )
          ),
          h("label", { className: "block" }, "Neden",
            h("input", {
              value: timeOffForm.reason,
              onChange: (e) => setTimeOffForm((p) => ({ ...p, reason: e.target.value })),
              placeholder: "izin / yıllık izin / eğitim",
              className: "mt-1 w-full px-2.5 py-2 border border-gray-300 rounded-lg",
            })
          ),
          h("div", { className: "flex justify-end gap-2 pt-2" },
            h(Button, { type: "submit", size: "sm", disabled: timeOffBusy }, timeOffBusy ? "Ekleniyor…" : "İzin Ekle")
          )
        )
      )
    )
  );
}

export default WebProviderStaffManager;
