import { r as React } from "./react-vendor-Dj04zrcb.js?v=20261030-nearby-fallback1";
import {
  b as api,
  B as Button,
  M as Modal,
  X as XIcon,
  g as Calendar,
  a3 as Clock,
} from "./index-Bj5sn6If.js?v=20261030-nearby-fallback1";
import { d as dataService } from "./dataService-BAucGhk0.js?v=20261030-nearby-fallback1";
import { formatMoney } from "./WebParityShared.js?v=20261122-web-parity1";

export function WebProviderManualAppointmentModal({
  open,
  mode = "create", // "create" | "edit"
  appointment = null,
  providerUserId,
  onClose,
  onSaved,
}) {
  const h = React.createElement;

  const [customerMode, setCustomerMode] = React.useState("guest"); // registered | guest
  const [custQuery, setCustQuery] = React.useState("");
  const [customers, setCustomers] = React.useState([]);
  const [selectedCustomerId, setSelectedCustomerId] = React.useState("");
  const [guestName, setGuestName] = React.useState("");
  const [guestPhone, setGuestPhone] = React.useState("");
  const [guestConsent, setGuestConsent] = React.useState(false);

  const [services, setServices] = React.useState([]);
  const [packages, setPackages] = React.useState([]);
  const [staffList, setStaffList] = React.useState([]);
  const [metaLoading, setMetaLoading] = React.useState(false);

  const [selectedServiceIds, setSelectedServiceIds] = React.useState([]);
  const [selectedPackageId, setSelectedPackageId] = React.useState("");
  const [selectedStaffId, setSelectedStaffId] = React.useState("");
  const [date, setDate] = React.useState(() => {
    const d = new Date();
    d.setDate(d.getDate() + 1);
    return d.toISOString().slice(0, 10);
  });
  const [slots, setSlots] = React.useState([]);
  const [slotsLoading, setSlotsLoading] = React.useState(false);
  const [time, setTime] = React.useState("");
  const [note, setNote] = React.useState("");
  const [busy, setBusy] = React.useState(false);
  const [err, setErr] = React.useState("");

  React.useEffect(() => {
    if (!open) return;
    let active = true;
    setErr("");
    if (mode === "edit" && appointment) {
      const apptDate = (appointment.start_time || "").split("T")[0] || date;
      const apptTime = ((appointment.start_time || "").split("T")[1] || "").slice(0, 5);
      setDate(apptDate);
      setTime(apptTime);
      setSelectedStaffId(appointment.staff_id ? String(appointment.staff_id) : "");
      setSelectedServiceIds((appointment.service_ids || []).map(String));
      setSelectedPackageId(appointment.provider_package_id ? String(appointment.provider_package_id) : "");
      setNote(appointment.note || "");
    }
    setMetaLoading(true);
    Promise.all([
      api.provider.getServices().catch(() => ({ data: [] })),
      api.provider.getPackages().catch(() => ({ data: [] })),
      api.get("/provider/staff").catch(() => ({ data: [] })),
      api.get("/provider/customers").catch(() => ({ data: [] })),
    ]).then(([svRes, pkRes, stRes, cuRes]) => {
      if (!active) return;
      const svList = Array.isArray(svRes?.data) ? svRes.data : [];
      const pkList = Array.isArray(pkRes?.data) ? pkRes.data : [];
      const stRaw = Array.isArray(stRes?.data) ? stRes.data : [];
      const cuRaw = Array.isArray(cuRes?.data) ? cuRes.data : [];
      const svs = svList.filter((x) => x.is_active !== false);
      const pks = pkList.filter((x) => x.is_active !== false);
      const sts = stRaw.filter((x) => x.is_active && x.accepts_appointments);
      setServices(svs);
      setPackages(pks);
      setStaffList(sts);
      setCustomers(cuRaw);

      if (mode !== "edit" || !appointment) {
        setCustomerMode("guest");
        setSelectedCustomerId("");
        setGuestName("");
        setGuestPhone("");
        setGuestConsent(false);
        setSelectedPackageId("");
        setSelectedServiceIds(svs[0] ? [String(svs[0].service_id || svs[0].id)] : []);
        setSelectedStaffId(sts[0] ? String(sts[0].id) : "");
        setNote("");
        setTime("");
      }
    }).finally(() => {
      if (active) setMetaLoading(false);
    });
    return () => { active = false; };
  }, [open, mode, appointment]);

  React.useEffect(() => {
    if (!open || !custQuery.trim() || customerMode !== "registered") return;
    const t = setTimeout(() => {
      api.get(`/provider/customers?q=${encodeURIComponent(custQuery.trim())}`).then((r) => {
        if (r?.success && Array.isArray(r.data)) setCustomers(r.data);
      }).catch(() => {});
    }, 250);
    return () => clearTimeout(t);
  }, [custQuery, customerMode, open]);

  // Fetch real staff-aware slots
  React.useEffect(() => {
    if (!open || !providerUserId || !date) return;
    if (!selectedPackageId && selectedServiceIds.length === 0) {
      setSlots([]);
      return;
    }
    let cancelled = false;
    setSlotsLoading(true);
    setErr("");
    dataService.getProviderAvailability(
      providerUserId,
      date,
      selectedPackageId ? [] : selectedServiceIds,
      selectedPackageId || null,
      { staffId: selectedStaffId || null, manual: true }
    ).then((res) => {
      if (cancelled) return;
      const list = Array.isArray(res?.data?.available_slots)
        ? res.data.available_slots.map((s) => s.start_time)
        : [];
      setSlots(list);
      if (mode === "edit" && appointment) {
        const curTime = ((appointment.start_time || "").split("T")[1] || "").slice(0, 5);
        setTime((prev) => prev || curTime || list[0] || "");
      } else {
        setTime((prev) => (list.includes(prev) ? prev : (list[0] || "")));
      }
    }).catch(() => {
      if (!cancelled) setSlots([]);
    }).finally(() => {
      if (!cancelled) setSlotsLoading(false);
    });
    return () => { cancelled = true; };
  }, [open, providerUserId, date, selectedServiceIds, selectedPackageId, selectedStaffId, mode, appointment]);

  if (!open) return null;

  const submit = async (e) => {
    e.preventDefault();
    if (busy) return;
    setErr("");

    if (!time) {
      setErr("Lütfen uygun bir randevu saati seçin.");
      return;
    }

    setBusy(true);
    try {
      if (mode === "edit" && appointment) {
        await api.put(`/provider/appointments/${appointment.id}`, {
          date,
          time,
          staff_id: selectedStaffId ? Number(selectedStaffId) : null,
          note: note.trim() || null,
        });
        onSaved?.("Randevu güncellendi.");
        onClose();
        return;
      }

      if (!selectedPackageId && selectedServiceIds.length === 0) {
        throw new Error("En az bir hizmet veya paket seçmelisiniz.");
      }

      if (customerMode === "registered") {
        if (!selectedCustomerId) throw new Error("Lütfen kayıtlı müşterinizi seçiniz.");
      } else {
        if (guestName.trim().length < 2) throw new Error("Misafir müşteri adını giriniz.");
        if (!guestConsent) throw new Error("Misafir müşteri kaydı için müşteri onayı işaretlenmelidir.");
      }

      await api.post("/provider/appointments", {
        customer_mode: customerMode,
        customer_user_id: customerMode === "registered" ? Number(selectedCustomerId) : null,
        guest_customer_name: customerMode === "guest" ? guestName.trim() : null,
        guest_customer_phone: customerMode === "guest" ? (guestPhone.trim() || null) : null,
        guest_customer_consent: customerMode === "guest" ? guestConsent : false,
        ...(selectedPackageId
          ? { provider_package_id: Number(selectedPackageId) }
          : { service_ids: selectedServiceIds.map(Number) }),
        staff_id: selectedStaffId ? Number(selectedStaffId) : null,
        date,
        time,
        note: note.trim() || null,
      });

      onSaved?.("Manuel randevu takvime başarıyla eklendi.");
      onClose();
    } catch (e2) {
      setErr(e2?.message || "Randevu kaydedilemedi.");
    } finally {
      setBusy(false);
    }
  };

  const toggleService = (sid) => {
    setSelectedPackageId("");
    setSelectedServiceIds((prev) => prev.includes(sid) ? prev.filter((x) => x !== sid) : [...prev, sid]);
  };

  return h(Modal, { onClose, className: "fixed inset-0 bg-black/60 flex items-center justify-center p-3 sm:p-4" },
    h("div", { className: "bg-white rounded-2xl w-full max-w-xl max-h-[90vh] flex flex-col shadow-2xl overflow-hidden", "data-testid": "manual-appointment-modal" },
      h("div", { className: "flex items-center justify-between px-5 py-4 border-b border-gray-100" },
        h("div", { className: "flex items-center gap-2" },
          h(Calendar, { size: 18, className: "text-[#FF5722]" }),
          h("h3", { className: "font-extrabold text-base text-gray-900" },
            mode === "edit" ? `Randevuyu Düzenle (#${appointment?.public_id || appointment?.id})` : "Manuel Randevu Oluştur"
          )
        ),
        h("button", { type: "button", onClick: onClose, className: "p-1 rounded-lg text-gray-400 hover:bg-gray-100" }, h(XIcon, { size: 18 }))
      ),

      h("form", { onSubmit: submit, className: "overflow-y-auto p-5 space-y-4 text-xs" },
        err && h("div", { className: "p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 font-semibold" }, err),

        mode === "create" && h("div", { className: "space-y-3" },
          h("div", { className: "grid grid-cols-2 gap-2 p-1 rounded-xl bg-gray-100" },
            [["guest", "Misafir Müşteri"], ["registered", "Kayıtlı Tarak Müşterisi"]].map(([k, lbl]) =>
              h("button", {
                key: k,
                type: "button",
                onClick: () => setCustomerMode(k),
                className: `py-2 rounded-lg font-bold ${customerMode === k ? "bg-white text-gray-900 shadow-sm" : "text-gray-500"}`,
              }, lbl)
            )
          ),

          customerMode === "guest"
            ? h("div", { className: "space-y-2.5 p-3 rounded-xl bg-slate-50 border border-slate-200" },
                h("div", { className: "grid grid-cols-1 sm:grid-cols-2 gap-2.5" },
                  h("label", null, "Müşteri Adı Soyadı *",
                    h("input", {
                      required: true,
                      value: guestName,
                      onChange: (e) => setGuestName(e.target.value),
                      placeholder: "Örn: Ahmet Yılmaz",
                      className: "mt-1 w-full px-3 py-2 border border-gray-300 rounded-lg bg-white text-sm",
                    })
                  ),
                  h("label", null, "Telefon (Opsiyonel)",
                    h("input", {
                      value: guestPhone,
                      onChange: (e) => setGuestPhone(e.target.value),
                      placeholder: "05XX...",
                      className: "mt-1 w-full px-3 py-2 border border-gray-300 rounded-lg bg-white text-sm",
                    })
                  )
                ),
                h("label", { className: "flex items-start gap-2 cursor-pointer text-gray-700" },
                  h("input", {
                    type: "checkbox",
                    checked: guestConsent,
                    onChange: (e) => setGuestConsent(e.target.checked),
                    className: "mt-0.5",
                  }),
                  h("span", null, "Müşteriden randevu kaydı oluşturulması için açık sözlü/yazılı onay alındı.")
                )
              )
            : h("div", { className: "space-y-2 p-3 rounded-xl bg-slate-50 border border-slate-200" },
                h("input", {
                  type: "text",
                  value: custQuery,
                  onChange: (e) => setCustQuery(e.target.value),
                  placeholder: "İşletmenizle etkileşimli müşteri adıyla arayın…",
                  className: "w-full px-3 py-2 border border-gray-300 rounded-lg bg-white text-sm",
                }),
                customers.length === 0
                  ? h("p", { className: "text-gray-500" }, "Kayıtlı etkileşimli müşteri bulunamadı; misafir modunu kullanabilirsiniz.")
                  : h("select", {
                      value: selectedCustomerId,
                      onChange: (e) => setSelectedCustomerId(e.target.value),
                      className: "w-full px-3 py-2 border border-gray-300 rounded-lg bg-white text-sm",
                    },
                      h("option", { value: "" }, "Müşteri seçiniz…"),
                      customers.map((c) => h("option", { key: c.id, value: String(c.id) }, c.name))
                    )
              ),

          // Services
          h("div", null,
            h("div", { className: "font-bold text-gray-800 mb-1.5" }, "Hizmet Seçimi"),
            h("div", { className: "grid grid-cols-1 sm:grid-cols-2 gap-2" },
              services.map((sv) => {
                const sid = String(sv.service_id || sv.id);
                const checked = !selectedPackageId && selectedServiceIds.includes(sid);
                return h("button", {
                  key: sid,
                  type: "button",
                  onClick: () => toggleService(sid),
                  className: `p-2.5 rounded-xl border text-left flex justify-between items-center ${checked ? "border-[#FF5722] bg-orange-50 text-gray-900 font-bold" : "border-gray-200 bg-white text-gray-700"}`,
                },
                  h("span", { className: "truncate pr-2" }, sv.name || sv.service?.name),
                  h("span", { className: "shrink-0 text-[11px]" }, formatMoney(sv.custom_price ?? sv.price))
                );
              })
            )
          ),

          packages.length > 0 && h("div", null,
            h("div", { className: "font-bold text-gray-800 mb-1.5" }, "Veya Paket Seçin"),
            h("select", {
              value: selectedPackageId,
              onChange: (e) => {
                setSelectedPackageId(e.target.value);
                if (e.target.value) setSelectedServiceIds([]);
              },
              className: "w-full px-3 py-2 border border-gray-300 rounded-lg bg-white text-sm",
            },
              h("option", { value: "" }, "Paket seçilmedi (Hizmet seçimi geçerli)"),
              packages.map((p) => {
                const pid = String(p.provider_package_id ?? p.id);
                return h("option", { key: pid, value: pid }, `${p.title} (${formatMoney(p.price)} · ${p.duration_minutes} dk)`);
              })
            )
          )
        ),

        // Staff Picker
        staffList.length > 0 && h("div", null,
          h("label", { className: "block font-bold text-gray-800 mb-1" }, "İlgilenecek Çalışan / Usta"),
          h("select", {
            value: selectedStaffId,
            onChange: (e) => setSelectedStaffId(e.target.value),
            className: "w-full px-3 py-2 border border-gray-300 rounded-lg bg-white text-sm",
          },
            h("option", { value: "" }, "Fark Etmez — İlk Müsait Usta"),
            staffList.map((st) => h("option", { key: st.id, value: String(st.id) }, `${st.full_name}${st.title ? ` (${st.title})` : ""}`))
          )
        ),

        // Date + Slots
        h("div", { className: "grid grid-cols-1 sm:grid-cols-2 gap-3" },
          h("label", { className: "block font-bold text-gray-800" }, "Randevu Tarihi",
            h("input", {
              type: "date",
              required: true,
              value: date,
              min: new Date().toISOString().slice(0, 10),
              onChange: (e) => setDate(e.target.value),
              className: "mt-1 w-full px-3 py-2 border border-gray-300 rounded-lg bg-white text-sm",
            })
          ),
          h("label", { className: "block font-bold text-gray-800" }, "Seçili Saat",
            h("input", {
              type: "time",
              required: true,
              value: time,
              onChange: (e) => setTime(e.target.value),
              className: "mt-1 w-full px-3 py-2 border border-gray-300 rounded-lg bg-white text-sm",
            })
          )
        ),

        h("div", null,
          h("div", { className: "font-bold text-gray-800 mb-1.5 flex items-center gap-1.5" },
            h(Clock, { size: 13 }), "Müsait Takvim Saatleri"
          ),
          (metaLoading || slotsLoading)
            ? h("div", { className: "text-gray-500 py-2" }, metaLoading ? "Hizmetler ve çalışanlar yükleniyor…" : "Saatler hesaplanıyor…")
            : slots.length === 0
              ? h("div", { className: "p-2.5 rounded-xl bg-amber-50 border border-amber-200 text-amber-800" },
                  "Bu gün veya çalışanda müsait slot görünmüyor. Tarih veya çalışanı değiştirebilirsiniz."
                )
              : h("div", { className: "grid grid-cols-4 sm:grid-cols-6 gap-1.5 max-h-36 overflow-y-auto" },
                  slots.map((sl) =>
                    h("button", {
                      key: sl,
                      type: "button",
                      onClick: () => setTime(sl),
                      className: `py-1.5 rounded-lg border font-bold ${time === sl ? "bg-blue-600 text-white border-blue-600" : "bg-white text-gray-700 border-gray-200 hover:border-blue-400"}`,
                    }, sl)
                  )
                )
        ),

        h("label", { className: "block font-bold text-gray-800" }, "Randevu Notu (Opsiyonel)",
          h("textarea", {
            rows: 2,
            value: note,
            onChange: (e) => setNote(e.target.value),
            placeholder: "Örn: Telefon ile alınan randevu",
            className: "mt-1 w-full px-3 py-2 border border-gray-300 rounded-lg text-sm",
          })
        ),

        h("div", { className: "flex justify-end gap-2 pt-3 border-t border-gray-100" },
          h(Button, { type: "button", variant: "ghost", onClick: onClose }, "Vazgeç"),
          h(Button, { type: "submit", disabled: busy || metaLoading, className: "bg-[#FF5722] hover:bg-orange-600 text-white font-bold" },
            busy ? "Kaydediliyor…" : (mode === "edit" ? "Değişiklikleri Kaydet" : "Randevuyu Oluştur")
          )
        )
      )
    )
  );
}

export default WebProviderManualAppointmentModal;
