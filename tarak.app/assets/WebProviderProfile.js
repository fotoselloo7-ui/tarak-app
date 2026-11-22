import { r as React } from "./react-vendor-Dj04zrcb.js?v=20261030-nearby-fallback1";
import {
  b as api,
  B as Button,
  C as Card,
  M as Modal,
  X as XIcon,
  Y as MapPin,
  S as ShieldCheck,
  _ as TarakRating,
  a2 as TarakRatingMarks,
  x as VerifiedTick,
  g as Calendar,
  a3 as Clock,
  a1 as Heart,
  $ as ChevronLeft,
  Z as ChevronRight,
  N as Users,
  a8 as Sparkles,
  z as UserRole,
  a as AppError,
} from "./index-Bj5sn6If.js?v=20261030-nearby-fallback1";
import { P as PackageIcon } from "./package-EwImrd5m.js?v=20261030-nearby-fallback1";
import { Z as ZapIcon } from "./zap-B7W1YZ3g.js?v=20261030-nearby-fallback1";
import { F as FlagIcon, R as ReportDialog } from "./ReportDialog-ewsJj7En.js?v=20261030-nearby-fallback1";
import {
  ensureParityStyles,
  formatMoney,
  workModeLabel,
  providerTypeLabel,
  todayDayKey,
  formatShortDate,
  AvatarOrMonogram,
} from "./WebParityShared.js?v=20261122-final1";

function PriceBlock({ price, original, percent }) {
  const h = React.createElement;
  return h("span", { className: "inline-flex flex-wrap items-baseline gap-2" },
    h("span", { style: { fontWeight: 800, color: "#0F172A" } }, formatMoney(price)),
    original != null && Number(original) > Number(price) && h(React.Fragment, null,
      h("s", { style: { fontSize: 12, color: "#94A3B8", fontWeight: 600 } }, formatMoney(original)),
      !!percent && h("span", {
        style: {
          background: "#FF5722", color: "#FFFFFF", borderRadius: 6,
          padding: "2px 6px", fontSize: 10, fontWeight: 800,
        },
      }, `%${percent} indirim`)
    )
  );
}

function GalleryLightbox({ urls, startIndex = 0, onClose }) {
  const h = React.createElement;
  const [idx, setIdx] = React.useState(Math.min(Math.max(startIndex, 0), urls.length - 1));
  const touchX = React.useRef(null);
  const step = React.useCallback((delta) => setIdx((i) => (i + delta + urls.length) % urls.length), [urls.length]);

  React.useEffect(() => {
    const onKey = (e) => {
      if (e.key === "ArrowRight") step(1);
      else if (e.key === "ArrowLeft") step(-1);
      else if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [step, onClose]);

  if (!urls || !urls.length) return null;

  return h(Modal, {
    onClose,
    className: "fixed inset-0 bg-black/90 flex items-center justify-center p-4",
  },
    h("div", {
      className: "relative w-full max-w-4xl",
      "aria-label": "Çalışmalarım galeri görüntüleyici",
      onTouchStart: (e) => { touchX.current = e.touches?.[0]?.clientX ?? null; },
      onTouchEnd: (e) => {
        if (touchX.current == null) return;
        const endX = e.changedTouches?.[0]?.clientX ?? touchX.current;
        const dx = endX - touchX.current;
        if (Math.abs(dx) > 40) step(dx < 0 ? 1 : -1);
        touchX.current = null;
      },
    },
      h("img", {
        src: urls[idx],
        alt: `Çalışma görseli ${idx + 1} / ${urls.length}`,
        className: "mx-auto max-h-[82vh] w-auto max-w-full rounded-xl object-contain",
      }),
      h("div", { className: "mt-3 text-center text-sm font-semibold text-white/80 tabular-nums" },
        `${idx + 1} / ${urls.length}`
      ),
      h("button", {
        type: "button",
        onClick: onClose,
        "aria-label": "Galeriyi kapat",
        className: "absolute -top-2 right-0 sm:-right-12 grid h-10 w-10 place-items-center rounded-full bg-white/15 text-white hover:bg-white/25 transition-colors",
      }, h(XIcon, { size: 20 })),
      urls.length > 1 && h(React.Fragment, null,
        h("button", {
          type: "button",
          onClick: () => step(-1),
          "aria-label": "Önceki fotoğraf",
          className: "absolute left-1 sm:-left-14 top-1/2 -translate-y-1/2 grid h-11 w-11 place-items-center rounded-full bg-white/15 text-white hover:bg-white/25 transition-colors",
        }, h(ChevronLeft, { size: 22 })),
        h("button", {
          type: "button",
          onClick: () => step(1),
          "aria-label": "Sonraki fotoğraf",
          className: "absolute right-1 sm:-right-14 top-1/2 -translate-y-1/2 grid h-11 w-11 place-items-center rounded-full bg-white/15 text-white hover:bg-white/25 transition-colors",
        }, h(ChevronRight, { size: 22 }))
      )
    )
  );
}

function InstantCallDialog({ providerName, selected, addresses, initialAddressId, onClose, onNavigate }) {
  const h = React.createElement;
  const [addressId, setAddressId] = React.useState(initialAddressId || "");
  const [paymentMethod, setPaymentMethod] = React.useState("CASH");
  const [note, setNote] = React.useState("");
  const [busy, setBusy] = React.useState(false);
  const [err, setErr] = React.useState("");

  const item = selected.item;
  const title = selected.kind === "service" ? item.name : item.title;

  const submit = async () => {
    if (!addressId) {
      setErr("Uzmanın adresinize gelebilmesi için kayıtlı bir adres seçmelisiniz.");
      return;
    }
    setBusy(true);
    setErr("");
    try {
      await api.customer.createDirectRequest({
        ...(selected.kind === "service"
          ? { provider_service_id: item.provider_service_id }
          : { provider_package_id: item.provider_package_id }),
        customer_address_id: addressId,
        payment_method: paymentMethod,
        customer_note: note.trim() || undefined,
      });
      onNavigate("customer", { tab: "jobs" });
    } catch (e) {
      setErr(e?.message || "Hemen çağır talebi oluşturulamadı.");
    } finally {
      setBusy(false);
    }
  };

  return h(Modal, { className: "fixed inset-0 bg-black/60 flex items-center justify-center p-4", onClose },
    h("div", { className: "bg-white rounded-2xl w-full max-w-md p-6 shadow-xl" },
      h("div", { className: "flex items-center justify-between mb-4" },
        h("h3", { className: "text-lg font-bold text-gray-900" }, "Hemen Çağır (Adrese Hizmet)"),
        h("button", { type: "button", onClick: onClose, className: "p-1 rounded-lg text-gray-400 hover:bg-gray-100", "aria-label": "Kapat" },
          h(XIcon, { size: 18 })
        )
      ),
      h("div", { className: "p-4 rounded-xl bg-orange-50 border border-orange-200 mb-4" },
        h("div", { className: "text-xs text-gray-500" }, providerName),
        h("div", { className: "font-bold text-gray-900" }, title),
        h("div", { className: "flex items-center justify-between mt-1 text-sm" },
          h("span", { className: "text-gray-600 flex items-center gap-1" }, h(Clock, { size: 13 }), `${item.duration_minutes} dk`),
          h("span", { className: "text-lg font-extrabold text-brand-orange" },
            h(PriceBlock, { price: item.price, original: item.original_price, percent: item.discount_percent })
          )
        )
      ),
      err && h("div", { className: "p-2.5 mb-3 bg-red-50 border border-red-200 text-red-700 text-xs rounded-lg" }, err),
      addresses.length === 0
        ? h("div", { className: "p-3 mb-3 rounded-lg bg-amber-50 border border-amber-200 text-xs text-amber-800" },
          "Kayıtlı adresiniz yok. ",
          h("button", { type: "button", className: "underline font-semibold", onClick: () => onNavigate("profile") }, "Adres ekleyin")
        )
        : h("label", { className: "block text-xs font-bold text-gray-700 mb-3" },
          "Hizmet adresi",
          h("select", {
            value: addressId,
            onChange: (e) => setAddressId(e.target.value),
            className: "mt-1 w-full border border-gray-300 rounded-lg p-2 text-sm font-normal bg-white",
          },
            addresses.map((a) => h("option", { key: a.id, value: a.id }, `${a.title || "Adres"} — ${a.district}, ${a.province}`))
          )
        ),
      h("div", { className: "text-xs font-bold text-gray-700 mb-1.5" }, "Ödeme yöntemi"),
      h("div", { className: "grid grid-cols-2 gap-2 mb-3" },
        [["CASH", "Nakit (hizmet sonrası)"], ["ONLINE", "Online (kart)"]].map(([code, lbl]) =>
          h("button", {
            key: code,
            type: "button",
            onClick: () => setPaymentMethod(code),
            className: `py-2 rounded-lg border text-xs font-semibold ${paymentMethod === code ? "border-brand-orange bg-orange-50 text-brand-orange" : "border-gray-200 text-gray-700"}`,
          }, lbl)
        )
      ),
      h("label", { className: "block text-xs font-bold text-gray-700 mb-4" },
        "Not (isteğe bağlı)",
        h("input", {
          value: note,
          onChange: (e) => setNote(e.target.value),
          maxLength: 1000,
          className: "mt-1 w-full border border-gray-300 rounded-lg p-2 text-sm font-normal",
          placeholder: "Örn: Kapı zili çalışmıyor, arayın.",
        })
      ),
      h("div", { className: "flex justify-end gap-2" },
        h(Button, { variant: "ghost", onClick: onClose }, "Vazgeç"),
        h(Button, { disabled: busy || addresses.length === 0, onClick: submit, className: "gap-1.5 bg-brand-orange hover:bg-orange-600 text-white" },
          h(ZapIcon, { size: 14 }),
          busy ? "Gönderiliyor..." : `${formatMoney(item.price)} ile Çağır`
        )
      )
    )
  );
}

export function WebProviderProfile({ id, user, onNavigate, embedded = false }) {
  const h = React.createElement;
  ensureParityStyles();

  const isCustomer = user?.role === "CUSTOMER" || user?.role === UserRole?.CUSTOMER;
  const [detail, setDetail] = React.useState(null);
  const [offerings, setOfferings] = React.useState(null);
  const [addresses, setAddresses] = React.useState([]);
  const [selectedAddressId, setSelectedAddressId] = React.useState("");
  const [reviewsState, setReviewsState] = React.useState({ average: 0, count: 0, reviews: [] });
  const [isFavorite, setIsFavorite] = React.useState(false);
  const [favBusy, setFavBusy] = React.useState(false);
  const [activeTab, setActiveTab] = React.useState("services");
  const [lightboxIdx, setLightboxIdx] = React.useState(null);
  const [reportReview, setReportReview] = React.useState(null);
  const [instantSelected, setInstantSelected] = React.useState(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState("");
  const [coverBroken, setCoverBroken] = React.useState(false);

  const loadOfferings = React.useCallback(async (userId, addrId) => {
    try {
      const res = await api.customer.getProviderOfferings(userId, addrId || null);
      if (res?.success && res.data) setOfferings(res.data);
    } catch {
      // Offerings stay optional if provider is directory-only or user is guest
    }
  }, []);

  React.useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError("");
    setCoverBroken(false);
    setOfferings(null);

    (async () => {
      let business = null;
      try {
        const mapRes = await api.get(`/map/businesses/${encodeURIComponent(String(id))}`);
        if (mapRes?.success && mapRes.data) business = mapRes.data;
      } catch {
        // Fallback for verified providers without directory status or numeric fallback
        try {
          const pubRes = await api.providers.publicDetail(id);
          if (pubRes?.success && pubRes.data) business = pubRes.data;
        } catch (e2) {
          if (!cancelled) setError(e2?.status === 404 ? "İşletme bulunamadı veya yayında değil." : (e2?.message || "Profil yüklenemedi."));
        }
      }

      if (cancelled) return;
      if (!business) {
        setDetail(null);
        setLoading(false);
        return;
      }

      const targetUserId = String(business.user_id || id);
      setDetail(business);

      if ((business.services || []).length === 0 && (business.packages || []).length > 0) {
        setActiveTab("packages");
      } else {
        setActiveTab("services");
      }

      // Refresh canonical reviews summary so reviews parity matches mobile identically
      api.reviews.forProvider(targetUserId).then((r) => {
        if (!cancelled && r?.success && r.data) {
          setReviewsState({
            average: r.data.average ?? business.rating ?? 0,
            count: r.data.count ?? business.review_count ?? 0,
            reviews: r.data.reviews || business.reviews || [],
          });
        }
      }).catch(() => {
        if (!cancelled) {
          setReviewsState({
            average: business.rating ?? 0,
            count: business.review_count ?? 0,
            reviews: business.reviews || [],
          });
        }
      });

      if (isCustomer) {
        const addrRes = await api.customer.getAddresses().catch(() => ({ data: [] }));
        const addrList = Array.isArray(addrRes?.data) ? addrRes.data : [];
        if (!cancelled) {
          setAddresses(addrList);
          const defAddr = addrList.find((a) => a.is_default) || addrList[0];
          const initId = defAddr ? String(defAddr.id) : "";
          setSelectedAddressId(initId);
          await loadOfferings(targetUserId, initId);
        }
        api.customer.getFavorites().then((f) => {
          if (!cancelled && f?.success && Array.isArray(f.data)) {
            setIsFavorite(f.data.some((row) => String(row.provider_user_id) === targetUserId));
          }
        }).catch(() => {});
      }

      if (!cancelled) setLoading(false);
    })();

    return () => { cancelled = true; };
  }, [id, isCustomer, loadOfferings]);

  const handleAddressChange = async (addrId) => {
    setSelectedAddressId(addrId);
    if (isCustomer && detail) {
      await loadOfferings(detail.user_id || id, addrId);
    }
  };

  const toggleFavorite = async () => {
    if (!isCustomer) {
      onNavigate("auth/login");
      return;
    }
    if (favBusy || !detail) return;
    setFavBusy(true);
    const targetId = Number(detail.user_id || id);
    try {
      if (isFavorite) {
        await api.customer.removeFavorite(targetId);
        setIsFavorite(false);
      } else {
        await api.customer.addFavorite(targetId);
        setIsFavorite(true);
      }
    } catch {
      // ignore toggle failure
    } finally {
      setFavBusy(false);
    }
  };

  const startScheduledBooking = ({ serviceId, packageId, staffId, locationType } = {}) => {
    if (!isCustomer) {
      onNavigate("auth/login");
      return;
    }
    const params = {
      mode: "scheduled",
      providerId: String(detail.user_id || id),
    };
    if (serviceId) params.serviceId = String(serviceId);
    if (packageId) params.packageId = String(packageId);
    if (staffId) params.staffId = String(staffId);
    if (locationType) params.locationType = String(locationType);
    onNavigate("customer/create-job", params);
  };

  const openMapDirections = () => {
    if (!detail) return;
    onNavigate("harita", {
      business: detail.slug || detail.user_id,
      route: "1",
    });
  };

  if (loading) {
    return h("div", { className: "py-20 text-center text-sm text-gray-500" }, "İşletme profili yükleniyor…");
  }
  if (error || !detail) {
    return h("div", { className: "max-w-lg mx-auto py-16 text-center" },
      h("p", { className: "text-gray-700 font-semibold mb-4" }, error || "İşletme bulunamadı."),
      h(Button, { variant: "outline", onClick: () => onNavigate("providers") }, "Hizmet Verenlere Dön")
    );
  }

  const targetUserId = String(detail.user_id || id);
  const avatarSrc = detail.logo_url || detail.avatar_url || "";
  const gallery = Array.isArray(detail.gallery) ? detail.gallery : [];
  const staffList = Array.isArray(detail.staff) ? detail.staff : [];
  const services = (offerings?.services && offerings.services.length > 0)
    ? offerings.services
    : (detail.services || []);
  const packages = (offerings?.packages && offerings.packages.length > 0)
    ? offerings.packages
    : (detail.packages || []);
  const workingHours = Array.isArray(detail.working_hours) ? detail.working_hours : [];
  const closedDates = Array.isArray(detail.closed_dates) ? detail.closed_dates : [];
  const serviceAreas = Array.isArray(detail.service_areas) ? detail.service_areas : [];
  const canBook = detail.accepts_tarak_bookings !== false && detail.is_verified === true && !detail.is_demo;
  const supportsMobileCall = detail.work_mode !== "venue";
  const ratingCount = Number(reviewsState.count ?? detail.review_count ?? 0);
  const ratingAvg = ratingCount > 0 ? Number(reviewsState.average ?? detail.rating ?? 0) : 0;
  const locationText = [detail.district, detail.city].filter(Boolean).join(", ");
  const todayKey = todayDayKey();

  // Build map of service_id -> staff names offering that service
  const staffByServiceId = {};
  for (const st of staffList) {
    for (const ss of (st.services || [])) {
      const k = String(ss.service_id);
      if (!staffByServiceId[k]) staffByServiceId[k] = [];
      staffByServiceId[k].push(st.full_name || `${st.first_name || ""} ${st.last_name || ""}`.trim());
    }
  }

  const bookingSidebarCard = h(Card, { className: "!p-5 border border-gray-200 shadow-sm" },
    h("div", { style: { display: "flex", alignItems: "center", justifyContent: "space-between", gap: 8, marginBottom: 12 } },
      h("span", { style: { fontSize: 12, fontWeight: 800, textTransform: "uppercase", letterSpacing: "0.04em", color: "#64748B" } },
        "Randevu & İşlemler"
      ),
      !!detail.discount_percent && h("span", {
        style: { background: "#FFF1EC", color: "#FF5722", border: "1px solid #FDBA74", borderRadius: 999, padding: "2px 8px", fontSize: 11, fontWeight: 800 },
      }, `%${detail.discount_percent} Kampanya`)
    ),

    canBook
      ? h("div", { className: "space-y-2.5" },
          h(Button, {
            fullWidth: true,
            onClick: () => startScheduledBooking({ locationType: detail.work_mode === "mobile" ? "mobile" : "venue" }),
            className: "gap-2 bg-[#FF5722] hover:bg-orange-600 text-white font-bold",
          }, h(Calendar, { size: 16 }), isCustomer ? "Planlı Randevu Al" : "Randevu Almak İçin Giriş Yap"),

          staffList.length > 0 && h("button", {
            type: "button",
            onClick: () => document.getElementById("twp-staff-section")?.scrollIntoView({ behavior: "smooth", block: "start" }),
            className: "w-full py-2.5 px-3 rounded-xl border border-slate-200 hover:border-[#FF5722] hover:bg-orange-50/40 text-xs font-bold text-slate-800 flex items-center justify-center gap-1.5 transition-colors",
          }, h(Users, { size: 15, className: "text-[#FF5722]" }), `Usta Seç (${staffList.length} Uzman)`)
        )
      : h("div", { className: "p-3 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-600 leading-relaxed mb-2" },
          detail.is_demo
            ? "Bu bir önizleme demo kaydıdır; gerçek randevu oluşturulamaz."
            : "Bu işletme şu anda yalnızca Tarak İşletme Rehberi'nde listelenmektedir; uygulama içi randevu kabul etmemektedir."
        ),

    h("div", { className: "mt-3 space-y-2" },
      detail.can_get_directions && detail.has_public_pin && h("button", {
        type: "button",
        onClick: openMapDirections,
        className: "w-full py-2.5 px-3 rounded-xl border border-slate-200 bg-slate-50 hover:bg-slate-100 text-xs font-bold text-slate-800 flex items-center justify-center gap-1.5 transition-colors",
      }, h(MapPin, { size: 15, className: "text-[#FF5722]" }), "Haritada Gör / Yol Tarifi"),

      h("button", {
        type: "button",
        onClick: toggleFavorite,
        disabled: favBusy,
        className: `w-full py-2 px-3 rounded-xl border text-xs font-bold flex items-center justify-center gap-1.5 transition-colors ${isFavorite ? "bg-rose-50 text-rose-600 border-rose-200" : "bg-white text-slate-600 border-slate-200 hover:border-rose-200"}`,
      }, h(Heart, { size: 14, className: isFavorite ? "fill-rose-500 text-rose-500" : "" }), isFavorite ? "Favorilerimde" : "Favorilere Ekle")
    )
  );

  return h("div", { className: embedded ? "py-2" : "max-w-6xl mx-auto py-5 px-1 sm:px-2" },
    !embedded && h("div", { className: "mb-4 flex items-center justify-between gap-2" },
      h(Button, { variant: "ghost", size: "sm", onClick: () => onNavigate("providers") }, "← Tüm İşletmeler"),
      detail.slug && h("span", { style: { fontSize: 11, color: "#94A3B8" } }, `tarak.app/isletme/${detail.slug}`)
    ),

    // Section 1: Kapak, avatar, ad, rozet, Tarak puanı (Full-width Hero card at top of grid flow)
    h("div", { className: "bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden mb-6", "data-section": "hero" },
      // Cover / Clean slate fallback (never flat orange rectangle)
      h("div", {
        style: {
          position: "relative",
          height: detail.cover_url && !coverBroken ? 210 : 128,
          background: "linear-gradient(135deg, #0F172A 0%, #1E293B 65%, #334155 100%)",
          borderBottom: "3px solid #FF5722",
          overflow: "hidden",
        },
      },
        detail.cover_url && !coverBroken && h("img", {
          src: detail.cover_url,
          alt: `${detail.business_name || detail.name} kapak fotoğrafı`,
          onError: () => setCoverBroken(true),
          style: { width: "100%", height: "100%", objectFit: "cover", objectPosition: "50% 35%" },
        }),
        detail.cover_url && !coverBroken && h("div", {
          style: { position: "absolute", inset: 0, background: "linear-gradient(to top, rgba(15,23,42,0.52), rgba(15,23,42,0.08))" },
        })
      ),

      h("div", { className: "px-4 sm:px-6 pb-5" },
        h("div", { className: "flex flex-col sm:flex-row sm:items-end justify-between gap-4 -mt-10 sm:-mt-12 relative z-10 mb-3" },
          h("div", { className: "flex flex-col sm:flex-row sm:items-end gap-3 sm:gap-4 min-w-0" },
            h("div", {
              style: {
                border: "4px solid #FFFFFF",
                borderRadius: 18,
                boxShadow: "0 8px 20px rgba(15,23,42,0.12)",
                width: 96,
                height: 96,
                overflow: "hidden",
                background: "#FFFFFF",
                flexShrink: 0,
              },
            },
              h(AvatarOrMonogram, {
                src: avatarSrc,
                name: detail.business_name || detail.name,
                size: 88,
                rounded: "14px",
                bg: "#FFF3ED",
                color: "#FF5722",
              })
            ),
            h("div", { className: "min-w-0 sm:pb-1" },
              h("h1", { className: "text-xl sm:text-2xl font-extrabold text-gray-900 flex items-center gap-1.5 flex-wrap" },
                h("span", null, detail.business_name || detail.name),
                detail.is_verified && h(VerifiedTick, { size: 22 })
              ),
              h("div", { className: "flex flex-wrap items-center gap-x-3 gap-y-1 text-xs sm:text-sm text-gray-500 mt-1" },
                h("span", { style: { fontWeight: 600, color: "#334155" } }, providerTypeLabel(detail.provider_type)),
                locationText && h("span", { className: "inline-flex items-center gap-1" }, h(MapPin, { size: 13 }), locationText),
                !!detail.experience_years && h("span", null, `• ${detail.experience_years} yıl deneyim`),
                h("span", null, `• ${detail.service_count ?? services.length} hizmet`)
              )
            )
          ),

          h("div", { className: "flex flex-wrap items-center gap-3 shrink-0 sm:pb-1" },
            ratingCount > 0
              ? h("div", { className: "px-3 py-1.5 rounded-xl bg-slate-50 border border-slate-200" },
                  h(TarakRating, { value: ratingAvg, count: ratingCount, size: 15, className: "font-extrabold text-gray-900 text-sm" })
                )
              : h("span", { className: "text-xs text-gray-400 font-medium px-2.5 py-1 rounded-lg bg-gray-50 border border-gray-200" }, "Henüz değerlendirme yok"),
            h("button", {
              type: "button",
              onClick: toggleFavorite,
              disabled: favBusy,
              className: `inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border transition-colors ${isFavorite ? "bg-rose-50 text-rose-600 border-rose-200" : "bg-white text-slate-600 border-slate-200 hover:border-rose-200"}`,
            }, h(Heart, { size: 14, className: isFavorite ? "fill-rose-500 text-rose-500" : "" }), isFavorite ? "Favorilerde" : "Favori")
          )
        ),

        h("div", { className: "flex flex-wrap gap-2 mt-2" },
          detail.is_verified
            ? h("span", { className: "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-bold bg-emerald-50 text-emerald-700 border border-emerald-200" },
                h(ShieldCheck, { size: 14 }), "Mesleki Belgesi Doğrulanmış İşletme"
              )
            : detail.directory_listed && h("span", { className: "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-bold bg-slate-100 text-slate-700 border border-slate-200" },
                "Rehber İşletmesi (Doğrulanmamış)"
              ),
          h("span", { className: "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-bold bg-blue-50 text-blue-700 border border-blue-200" },
            workModeLabel(detail.work_mode)
          ),
          h("span", {
            className: `inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-bold border ${detail.is_online ? "bg-emerald-50 text-emerald-700 border-emerald-200" : "bg-gray-50 text-gray-500 border-gray-200"}`,
          },
            h("span", { className: `w-2 h-2 rounded-full ${detail.is_online ? "bg-emerald-500" : "bg-gray-400"}` }),
            detail.is_online ? "Şu An Çevrimiçi" : "Çevrimdışı"
          ),
          canBook && h("span", { className: "inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-bold bg-orange-50 text-[#FF5722] border border-orange-200" },
            "Randevu Kabul Ediyor"
          )
        )
      )
    ),

    h("div", { className: "twp-profile-grid" },
      // MAIN LEFT COLUMN (Sections 2 through 8)
      h("div", { className: "min-w-0 space-y-6" },

        // Section 2: İşletme açıklaması ve bilgileri
        (detail.bio || detail.title) && h(Card, { className: "!p-5 border border-gray-200", "data-section": "bio" },
          h("h2", { className: "text-base font-bold text-gray-900 mb-2" }, "İşletme Hakkında"),
          detail.title && h("p", { className: "text-xs font-bold text-[#FF5722] mb-1.5" }, detail.title),
          detail.bio && h("p", { className: "text-sm text-gray-600 leading-relaxed whitespace-pre-line" }, detail.bio)
        ),

        // Section 3: Çalışmalarım (Gallery — hidden completely if empty)
        gallery.length > 0 && h(Card, { className: "!p-5 border border-gray-200", "data-section": "gallery" },
          h("div", { className: "flex items-center justify-between gap-2 mb-3" },
            h("div", { className: "flex items-baseline gap-2" },
              h("h2", { className: "text-base font-bold text-gray-900" }, "Çalışmalarım"),
              h("span", { className: "text-xs text-gray-400 font-semibold" }, `${gallery.length} fotoğraf`)
            ),
            h("span", { className: "text-[11px] text-gray-400 hidden sm:inline" }, "Büyütmek için fotoğrafa tıklayın")
          ),
          h("div", { className: "twp-gallery-strip", "data-section": "gallery" },
            gallery.map((url, idx) =>
              h("button", {
                key: `${url}-${idx}`,
                type: "button",
                onClick: () => setLightboxIdx(idx),
                "aria-label": `Çalışma fotoğrafı ${idx + 1} / ${gallery.length}`,
                className: "group aspect-square rounded-xl overflow-hidden border border-gray-200 bg-gray-50",
              },
                h("img", {
                  src: url,
                  alt: `${detail.business_name || "İşletme"} çalışması ${idx + 1}`,
                  loading: "lazy",
                  className: "w-full h-full object-cover transition-transform duration-300 group-hover:scale-105",
                })
              )
            )
          )
        ),

        // Section 4: Ustalarımız / Uzmanlarımız (Staff — hidden if empty)
        staffList.length > 0 && h(Card, { className: "!p-5 border border-gray-200", "data-section": "staff" },
          h("div", { id: "twp-staff-section", className: "flex flex-wrap items-center justify-between gap-2 mb-4" },
            h("div", null,
              h("h2", { className: "text-base font-bold text-gray-900" }, `Ustalarımız / Uzmanlarımız (${staffList.length})`),
              h("p", { className: "text-xs text-gray-500 mt-0.5" }, "Dilediğiniz ustadan veya ilk müsait uzmandan randevu alabilirsiniz.")
            ),
            canBook && h("button", {
              type: "button",
              onClick: () => startScheduledBooking({}),
              className: "px-3 py-1.5 rounded-xl bg-slate-900 hover:bg-slate-800 text-white text-xs font-bold transition-colors whitespace-nowrap",
            }, "Fark Etmez — İlk Müsait Usta")
          ),
          h("div", { className: "twp-staff-grid", "data-section": "staff" },
            staffList.map((st) => {
              const sName = st.full_name || `${st.first_name || ""} ${st.last_name || ""}`.trim();
              const svcs = Array.isArray(st.services) ? st.services : [];
              const accepts = st.accepts_appointments !== false;
              return h("div", {
                key: st.id,
                className: "p-3.5 rounded-xl border border-gray-200 bg-white flex flex-col justify-between gap-3",
              },
                h("div", { className: "flex items-start gap-3 min-w-0" },
                  h(AvatarOrMonogram, { src: st.photo_url, name: sName, size: 54, rounded: "14px" }),
                  h("div", { className: "min-w-0 flex-1" },
                    h("div", { className: "font-bold text-sm text-gray-900 truncate" }, sName),
                    st.title && h("div", { className: "text-xs font-semibold text-[#FF5722] truncate" }, st.title),
                    st.specialty && h("div", { className: "text-[11px] text-gray-500 mt-0.5" }, st.specialty),
                    h("span", {
                      className: `inline-block mt-1.5 text-[10px] font-bold px-2 py-0.5 rounded-full ${accepts ? "bg-emerald-50 text-emerald-700" : "bg-gray-100 text-gray-500"}`,
                    }, accepts ? "Randevuya Açık" : "Şu An Müsait Değil")
                  )
                ),
                svcs.length > 0 && h("div", { className: "flex flex-wrap gap-1" },
                  svcs.slice(0, 4).map((ss) =>
                    h("span", {
                      key: ss.service_id,
                      className: "px-2 py-0.5 rounded-md bg-slate-50 border border-slate-200 text-[11px] text-slate-600",
                    }, ss.service_name || `#${ss.service_id}`)
                  ),
                  svcs.length > 4 && h("span", { className: "text-[11px] text-gray-400 px-1" }, `+${svcs.length - 4}`)
                ),
                canBook && accepts && h("button", {
                  type: "button",
                  onClick: () => startScheduledBooking({ staffId: st.id }),
                  className: "w-full py-2 px-3 rounded-xl bg-orange-50 hover:bg-[#FF5722] text-[#FF5722] hover:text-white border border-orange-200 text-xs font-bold transition-colors",
                }, "Bu Ustadan Randevu Al")
              );
            })
          )
        ),

        // Section 5: Hizmetler ve Paketler
        h(Card, { className: "!p-5 border border-gray-200", "data-section": "services" },
          h("div", { className: "flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4" },
            h("div", { className: "inline-flex p-1 rounded-xl bg-gray-100 self-start" },
              [
                ["services", `Hizmetler (${services.length})`, Sparkles],
                ["packages", `Paketler (${packages.length})`, PackageIcon],
              ].map(([tabKey, label, Icon]) =>
                h("button", {
                  key: tabKey,
                  type: "button",
                  onClick: () => setActiveTab(tabKey),
                  className: `px-3.5 py-2 rounded-lg text-xs sm:text-sm font-semibold flex items-center gap-1.5 ${activeTab === tabKey ? "bg-white shadow-sm text-gray-900" : "text-gray-500"}`,
                }, h(Icon, { size: 15 }), label)
              )
            ),
            isCustomer && supportsMobileCall && (
              addresses.length > 0
                ? h("label", { className: "text-xs text-gray-500 flex items-center gap-2" },
                    "Adres:",
                    h("select", {
                      value: selectedAddressId,
                      onChange: (e) => handleAddressChange(e.target.value),
                      className: "border border-gray-300 rounded-lg px-2 py-1.5 text-xs text-gray-800 bg-white max-w-[200px]",
                    },
                      addresses.map((a) => h("option", { key: a.id, value: a.id }, `${a.title || "Adres"} — ${a.district}`))
                    )
                  )
                : h("button", {
                    type: "button",
                    onClick: () => onNavigate("customer", { tab: "addresses" }),
                    className: "text-xs font-semibold text-[#FF5722] underline",
                  }, "Adrese Hemen Çağır için Adres Ekle")
            )
          ),

          activeTab === "services" && (
            services.length === 0
              ? h("div", { className: "py-6 text-center text-sm text-gray-500" }, "Bu işletmede şu anda aktif hizmet listelenmiyor.")
              : h("div", { className: "space-y-3" },
                  services.map((svc) => {
                    const sId = String(svc.service_id ?? svc.id);
                    const capableStaff = staffByServiceId[sId] || [];
                    const instantAvail = svc.availability || null;
                    return h("div", {
                      key: svc.provider_service_id || sId,
                      className: "p-4 rounded-xl border border-gray-200 bg-white flex flex-col sm:flex-row sm:items-center justify-between gap-3",
                    },
                      h("div", { className: "min-w-0 flex-1" },
                        h("div", { className: "font-bold text-sm sm:text-base text-gray-900" }, svc.name),
                        svc.description && h("p", { className: "text-xs text-gray-500 mt-0.5" }, svc.description),
                        h("div", { className: "flex flex-wrap items-center gap-3 mt-2 text-xs text-gray-500" },
                          h("span", { className: "inline-flex items-center gap-1" }, h(Clock, { size: 12 }), `${svc.duration_minutes || 30} dk`),
                          capableStaff.length > 0 && h("span", { className: "inline-flex items-center gap-1 text-slate-600" },
                            h(Users, { size: 12 }), `Ustalar: ${capableStaff.slice(0, 3).join(", ")}${capableStaff.length > 3 ? ` +${capableStaff.length - 3}` : ""}`
                          )
                        ),
                        isCustomer && supportsMobileCall && instantAvail && (
                          instantAvail.available
                            ? h("div", { className: "mt-1.5 text-[11px] font-semibold text-emerald-700" },
                                `Adrese hemen çağrılabilir${instantAvail.distance_km != null ? ` • ~${instantAvail.distance_km} km` : ""}`
                              )
                            : h("div", { className: "mt-1.5 text-[11px] text-amber-700" },
                                instantAvail.reason || "Şu an anlık çağrıya kapalı"
                              )
                        )
                      ),
                      h("div", { className: "flex sm:flex-col items-center sm:items-end justify-between gap-2 shrink-0" },
                        h("div", { className: "text-base sm:text-lg font-extrabold text-gray-900" },
                          h(PriceBlock, { price: svc.price, original: svc.original_price, percent: svc.discount_percent })
                        ),
                        canBook && h("div", { className: "flex flex-wrap items-center gap-2" },
                          h(Button, {
                            size: "sm",
                            onClick: () => startScheduledBooking({ serviceId: sId }),
                            className: "gap-1.5 bg-[#FF5722] hover:bg-orange-600 text-white text-xs",
                          }, h(Calendar, { size: 13 }), "Randevu Al"),
                          isCustomer && supportsMobileCall && svc.provider_service_id && instantAvail?.available && h(Button, {
                            size: "sm",
                            variant: "outline",
                            onClick: () => setInstantSelected({ kind: "service", item: svc }),
                            className: "gap-1 text-xs border-orange-300 text-[#FF5722] hover:bg-orange-50",
                          }, h(ZapIcon, { size: 13 }), "Hemen Çağır")
                        )
                      )
                    );
                  })
                )
          ),

          activeTab === "packages" && (
            packages.length === 0
              ? h("div", { className: "py-6 text-center text-sm text-gray-500" }, "Bu işletmenin aktif paketi bulunmuyor.")
              : h("div", { className: "space-y-3" },
                  packages.map((pkg) => {
                    const pkgId = String(pkg.provider_package_id ?? pkg.id);
                    const pkgItems = Array.isArray(pkg.service_items)
                      ? pkg.service_items.map((x) => x.name)
                      : (Array.isArray(pkg.services) ? pkg.services.map((x) => typeof x === "string" ? x : x.name) : []);
                    const instantAvail = pkg.availability || null;
                    return h("div", {
                      key: pkgId,
                      className: "p-4 rounded-xl border border-gray-200 bg-white flex flex-col sm:flex-row sm:items-center justify-between gap-3",
                    },
                      h("div", { className: "min-w-0 flex-1" },
                        h("div", { className: "font-bold text-sm sm:text-base text-gray-900" }, pkg.title),
                        pkg.description && h("p", { className: "text-xs text-gray-500 mt-0.5" }, pkg.description),
                        pkgItems.length > 0 && h("div", { className: "flex flex-wrap gap-1.5 mt-2" },
                          pkgItems.map((name, i) => h("span", {
                            key: `${name}-${i}`,
                            className: "px-2 py-0.5 rounded-full bg-slate-100 text-slate-700 text-[11px] font-medium",
                          }, name))
                        ),
                        h("div", { className: "mt-2 text-xs text-gray-500 flex items-center gap-1" },
                          h(Clock, { size: 12 }), `${pkg.duration_minutes || 60} dk`
                        )
                      ),
                      h("div", { className: "flex sm:flex-col items-center sm:items-end justify-between gap-2 shrink-0" },
                        h("div", { className: "text-base sm:text-lg font-extrabold text-gray-900" },
                          h(PriceBlock, { price: pkg.price, original: pkg.original_price, percent: pkg.discount_percent })
                        ),
                        canBook && h("div", { className: "flex flex-wrap items-center gap-2" },
                          h(Button, {
                            size: "sm",
                            onClick: () => startScheduledBooking({ packageId: pkgId }),
                            className: "gap-1.5 bg-[#FF5722] hover:bg-orange-600 text-white text-xs",
                          }, h(Calendar, { size: 13 }), "Paketle Randevu Al"),
                          isCustomer && supportsMobileCall && instantAvail?.available && h(Button, {
                            size: "sm",
                            variant: "outline",
                            onClick: () => setInstantSelected({ kind: "package", item: { ...pkg, provider_package_id: Number(pkgId) } }),
                            className: "gap-1 text-xs border-orange-300 text-[#FF5722] hover:bg-orange-50",
                          }, h(ZapIcon, { size: 13 }), "Hemen Çağır")
                        )
                      )
                    );
                  })
                )
          )
        ),

        // Section 6: Çalışma saatleri ve kapalı günler
        workingHours.length > 0 && h(Card, { className: "!p-5 border border-gray-200", "data-section": "hours" },
          h("h2", { className: "text-base font-bold text-gray-900 mb-3" }, "Çalışma Saatleri & Kapalı Günler"),
          h("div", { className: "twp-hours-grid" },
            workingHours.map((day) => {
              const isToday = day.day === todayKey;
              return h("div", {
                key: day.day,
                style: {
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "space-between",
                  padding: "9px 12px",
                  borderRadius: 10,
                  border: isToday ? "1px solid #FDBA74" : "1px solid #E2E8F0",
                  background: isToday ? "#FFF7ED" : "#FFFFFF",
                  fontSize: 12,
                },
              },
                h("div", null,
                  h("span", { style: { fontWeight: 700, color: "#0F172A" } }, day.label),
                  isToday && h("span", { style: { marginLeft: 6, fontSize: 10, fontWeight: 800, color: "#FF5722" } }, "Bugün"),
                  day.enabled && Array.isArray(day.breaks) && day.breaks.length > 0 && h("div", { style: { fontSize: 10, color: "#64748B", marginTop: 2 } },
                    `Mola: ${day.breaks.map((b) => `${b.start_time}-${b.end_time}`).join(", ")}`
                  )
                ),
                h("span", { style: { fontWeight: 700, color: day.enabled ? "#0F172A" : "#94A3B8" } },
                  day.enabled ? `${day.start_time || "09:00"} – ${day.end_time || "21:00"}` : "Kapalı"
                )
              );
            })
          ),
          closedDates.length > 0 && h("div", { className: "mt-3 pt-3 border-t border-gray-100" },
            h("div", { className: "text-xs font-bold text-gray-700 mb-2" }, "Planlı Kapalı Günler"),
            h("div", { className: "flex flex-wrap gap-2" },
              closedDates.map((cd) =>
                h("span", {
                  key: cd.id || cd.date,
                  className: "px-2.5 py-1 rounded-lg bg-rose-50 border border-rose-200 text-xs text-rose-800 font-semibold",
                }, `${formatShortDate(cd.date)}${cd.reason ? ` • ${cd.reason}` : ""}`)
              )
            )
          )
        ),

        // Section 7: Konum ve hizmet bölgeleri (Privacy-safe!)
        h(Card, { className: "!p-5 border border-gray-200", "data-section": "location" },
          h("h2", { className: "text-base font-bold text-gray-900 mb-3" }, "Konum & Hizmet Bölgeleri"),
          h("div", { className: "grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs mb-3" },
            h("div", { className: "p-3 rounded-xl bg-slate-50 border border-slate-200" },
              h("div", { className: "text-gray-500 mb-0.5" }, "Çalışma Biçimi"),
              h("div", { className: "font-bold text-gray-900" }, workModeLabel(detail.work_mode))
            ),
            h("div", { className: "p-3 rounded-xl bg-slate-50 border border-slate-200" },
              h("div", { className: "text-gray-500 mb-0.5" }, "Hizmet Yarıçapı"),
              h("div", { className: "font-bold text-gray-900" }, `${detail.service_radius_km || 15} km`)
            )
          ),

          detail.has_public_pin
            ? h("div", { className: "p-3.5 rounded-xl bg-white border border-gray-200 flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-3" },
                h("div", { className: "min-w-0" },
                  h("div", { className: "text-xs font-bold text-gray-800" }, "İşletme Adresi"),
                  h("div", { className: "text-xs text-gray-600 mt-0.5" }, detail.formatted_address || locationText)
                ),
                h(Button, { size: "sm", variant: "outline", onClick: openMapDirections, className: "gap-1.5 text-xs shrink-0" },
                  h(MapPin, { size: 13, className: "text-[#FF5722]" }), "Yol Tarifi Al"
                )
              )
            : h("div", { className: "p-3 rounded-xl bg-amber-50/70 border border-amber-200 text-xs text-amber-900 mb-3" },
                `${locationText ? `${locationText} bölgesinde ` : ""}adrese gelen mobil hizmet vermektedir. Gizlilik nedeniyle gezici uzmanın özel konumu herkese açık gösterilmez.`
              ),

          serviceAreas.length > 0 && h("div", null,
            h("div", { className: "text-xs font-bold text-gray-700 mb-2" }, "Hizmet Verilen İlçeler ve Mahalleler"),
            h("div", { className: "flex flex-wrap gap-1.5" },
              serviceAreas.map((a, i) =>
                h("span", {
                  key: a.id || i,
                  className: "px-2.5 py-1 rounded-full bg-slate-100 text-slate-700 text-xs font-medium",
                }, [a.district, a.neighborhood, a.province].filter(Boolean).join(" · "))
              )
            )
          )
        ),

        // Section 8: Müşteri değerlendirmeleri (Tarak Rating ONLY, NO yellow stars!)
        h(Card, { className: "!p-5 border border-gray-200", "data-section": "reviews" },
          h("div", { className: "flex flex-wrap items-center justify-between gap-2 mb-4" },
            h("h2", { className: "text-base font-bold text-gray-900" }, "Müşteri Değerlendirmeleri"),
            ratingCount > 0 && h("div", { className: "flex items-center gap-2" },
              h(TarakRating, { value: ratingAvg, count: ratingCount, size: 15, className: "text-sm font-bold text-gray-900" })
            )
          ),
          (reviewsState.reviews || []).length === 0
            ? h("div", { className: "text-sm text-gray-500 py-3" }, "Bu işletme için henüz müşteri yorumu bulunmuyor.")
            : h("div", { className: "space-y-3" },
                reviewsState.reviews.slice(0, 12).map((rv) =>
                  h("div", { key: rv.id, className: "border-b border-gray-100 last:border-0 pb-3 last:pb-0" },
                    h("div", { className: "flex items-center justify-between gap-2 mb-1" },
                      h("span", { className: "text-sm font-semibold text-gray-800" }, rv.customer_name || "Müşteri"),
                      h("div", { className: "flex items-center gap-2" },
                        h(TarakRatingMarks, { value: rv.rating, size: 13 }),
                        rv.created_at && h("span", { className: "text-[11px] text-gray-400" },
                          new Date(rv.created_at).toLocaleDateString("tr-TR")
                        )
                      )
                    ),
                    rv.comment && h("p", { className: "text-sm text-gray-600 leading-relaxed" }, rv.comment),
                    user && h("button", {
                      type: "button",
                      onClick: () => setReportReview(rv),
                      className: "mt-1.5 inline-flex items-center gap-1 text-[11px] font-semibold text-gray-400 hover:text-rose-600 transition-colors",
                    }, h(FlagIcon, { size: 12 }), " Bildir")
                  )
                )
              )
        )
      ),

      // Section 9: Sticky Right CTA & Contact Sidebar (Desktop right col; Mobile stacked naturally below)
      h("aside", { className: "twp-sticky-aside", "data-section": "booking-actions" }, bookingSidebarCard)
    ),

    instantSelected && h(InstantCallDialog, {
      providerName: detail.business_name || detail.name,
      selected: instantSelected,
      addresses,
      initialAddressId: selectedAddressId,
      onClose: () => setInstantSelected(null),
      onNavigate,
    }),

    lightboxIdx !== null && h(GalleryLightbox, {
      urls: gallery,
      startIndex: lightboxIdx,
      onClose: () => setLightboxIdx(null),
    }),

    reportReview && h(ReportDialog, {
      contentType: "REVIEW",
      contentId: reportReview.id,
      preview: reportReview.comment || undefined,
      onClose: () => setReportReview(null),
    })
  );
}

export default WebProviderProfile;
