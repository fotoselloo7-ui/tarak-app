import { r as React } from "./react-vendor-Dj04zrcb.js?v=20261030-nearby-fallback1";
import {
  b as api,
  N as Users,
  Y as MapPin,
} from "./index-Bj5sn6If.js?v=20261030-nearby-fallback1";
import { AvatarOrMonogram, workModeLabel } from "./WebParityShared.js?v=20261122-web-parity1";

export function WebJobLocationModeSelector({ providerDetail, locationType, onChange }) {
  const h = React.createElement;
  const wm = providerDetail?.work_mode || "both";
  const allowVenue = wm !== "mobile";
  const allowMobile = wm !== "venue";

  return h("div", { className: "mt-4 pt-4 border-t border-gray-100", "data-testid": "service-location-mode" },
    h("div", { className: "text-xs font-bold text-gray-800 mb-2 flex items-center justify-between gap-2" },
      h("span", null, "Hizmet Biçimi"),
      providerDetail && h("span", { className: "text-[11px] font-semibold text-gray-500" }, workModeLabel(wm))
    ),
    h("div", { className: "grid grid-cols-1 sm:grid-cols-2 gap-2" },
      h("button", {
        type: "button",
        disabled: !allowVenue,
        onClick: () => allowVenue && onChange("venue"),
        className: `p-3 rounded-xl border text-left transition-all ${
          locationType === "venue"
            ? "border-[#FF5722] bg-orange-50/70 ring-2 ring-[#FF5722]/25"
            : allowVenue
              ? "border-gray-200 bg-white hover:border-gray-300"
              : "border-gray-200 bg-gray-50 opacity-50 cursor-not-allowed"
        }`,
      },
        h("div", { className: "text-xs font-bold text-gray-900" }, "İşletmede (Salonda)"),
        h("div", { className: "text-[11px] text-gray-500 mt-0.5" },
          allowVenue ? "Randevu saatinde işletme adresine gidersiniz. Ev adresi zorunlu değildir." : "Bu uzman yalnızca adrese gelir."
        )
      ),
      h("button", {
        type: "button",
        disabled: !allowMobile,
        onClick: () => allowMobile && onChange("mobile"),
        className: `p-3 rounded-xl border text-left transition-all ${
          locationType === "mobile"
            ? "border-[#FF5722] bg-orange-50/70 ring-2 ring-[#FF5722]/25"
            : allowMobile
              ? "border-gray-200 bg-white hover:border-gray-300"
              : "border-gray-200 bg-gray-50 opacity-50 cursor-not-allowed"
        }`,
      },
        h("div", { className: "text-xs font-bold text-gray-900" }, "Adreste (Ev / Ofis)"),
        h("div", { className: "text-[11px] text-gray-500 mt-0.5" },
          allowMobile ? "Uzman seçtiğiniz kayıtlı adresinize gelir." : "Bu işletme yalnızca salonunda hizmet verir."
        )
      )
    ),
    locationType === "venue" && providerDetail?.formatted_address && h("div", {
      className: "mt-2 p-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-700 flex items-center gap-2",
    },
      h(MapPin, { size: 14, className: "text-[#FF5722] shrink-0" }),
      h("span", null, `İşletme Konumu: ${providerDetail.formatted_address}`)
    )
  );
}

export function WebJobStaffPicker({
  providerId,
  serviceIds = [],
  packageId = "",
  date = "",
  staffId = "",
  onSelectStaff,
  onStaffLoaded,
}) {
  const h = React.createElement;
  const [staffList, setStaffList] = React.useState([]);
  const [loading, setLoading] = React.useState(false);

  const svcKey = serviceIds.join(",");

  React.useEffect(() => {
    if (!providerId) {
      setStaffList([]);
      onStaffLoaded?.([]);
      return;
    }
    let cancelled = false;
    setLoading(true);
    const sp = new URLSearchParams();
    if (packageId) sp.set("provider_package_id", String(packageId));
    else if (serviceIds.length > 0) sp.set("service_ids", serviceIds.join(","));
    if (date) sp.set("date", date);

    api.get(`/customer/providers/${providerId}/staff${sp.toString() ? `?${sp.toString()}` : ""}`)
      .then((res) => {
        if (cancelled) return;
        const rows = res?.success && Array.isArray(res.data) ? res.data : [];
        setStaffList(rows);
        onStaffLoaded?.(rows);
        if (staffId && !rows.some((r) => String(r.id) === String(staffId))) {
          onSelectStaff?.("", null);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setStaffList([]);
          onStaffLoaded?.([]);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => { cancelled = true; };
  }, [providerId, svcKey, packageId, date]);

  if (!providerId) return null;
  if (loading && staffList.length === 0) {
    return h("div", { className: "mt-4 pt-4 border-t border-gray-100 text-xs text-gray-500" }, "Uzman çalışanlar yükleniyor…");
  }
  if (!staffList.length) return null; // Legacy salon without staff keeps existing flow unchanged

  return h("div", { className: "mt-4 pt-4 border-t border-gray-100 space-y-2.5", "data-testid": "booking-staff-picker" },
    h("div", { className: "flex items-center justify-between gap-2" },
      h("div", { className: "text-xs font-bold text-gray-900 flex items-center gap-1.5" },
        h(Users, { size: 15, className: "text-[#FF5722]" }), "Usta / Çalışan Seçimi"
      ),
      h("span", { className: "text-[11px] text-gray-500" }, `${staffList.length} uygun uzman`)
    ),
    h("div", { className: "grid grid-cols-1 sm:grid-cols-2 gap-2" },
      h("button", {
        type: "button",
        "aria-pressed": !staffId,
        onClick: () => onSelectStaff?.("", null),
        className: `p-3 rounded-xl border text-left transition-all ${
          !staffId
            ? "border-[#FF5722] bg-orange-50/70 ring-2 ring-[#FF5722]/25"
            : "border-gray-200 bg-white hover:border-gray-300"
        }`,
      },
        h("div", { className: "text-xs font-extrabold text-gray-900" }, "Fark Etmez — İlk Müsait Usta"),
        h("div", { className: "text-[11px] text-gray-500 mt-0.5" }, "Seçtiğiniz saatte müsait ilk ustaya otomatik atanır.")
      ),

      staffList.map((st) => {
        const selected = String(staffId) === String(st.id);
        return h("button", {
          key: st.id,
          type: "button",
          "aria-pressed": selected,
          onClick: () => onSelectStaff?.(String(st.id), st),
          className: `p-3 rounded-xl border text-left transition-all flex items-center gap-3 ${
            selected
              ? "border-[#FF5722] bg-orange-50/70 ring-2 ring-[#FF5722]/25"
              : "border-gray-200 bg-white hover:border-gray-300"
          }`,
        },
          h(AvatarOrMonogram, { src: st.photo_url, name: st.full_name, size: 42, rounded: "12px" }),
          h("div", { className: "min-w-0 flex-1" },
            h("div", { className: "text-xs font-extrabold text-gray-900 truncate" }, st.full_name),
            (st.title || st.specialty) && h("div", { className: "text-[11px] text-gray-500 truncate" }, st.title || st.specialty),
            typeof st.available_slots_count === "number" && h("div", {
              className: `text-[10px] font-bold mt-0.5 ${st.available_slots_count > 0 ? "text-emerald-700" : "text-amber-700"}`,
            }, st.available_slots_count > 0 ? `${st.available_slots_count} müsait saat` : "Seçili tarihte dolu")
          )
        );
      })
    )
  );
}

export default WebJobStaffPicker;
