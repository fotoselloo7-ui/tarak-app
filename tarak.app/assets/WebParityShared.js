import { r as React } from "./react-vendor-Dj04zrcb.js?v=20261030-nearby-fallback1";

const STYLE_ID = "tarak-web-parity-styles";

export function ensureParityStyles() {
  if (typeof document === "undefined") return;
  if (document.getElementById(STYLE_ID)) return;
  const style = document.createElement("style");
  style.id = STYLE_ID;
  style.textContent = `
    .twp-profile-grid {
      display: grid;
      grid-template-columns: minmax(0, 1fr);
      gap: 24px;
      align-items: start;
    }
    @media (min-width: 1024px) {
      .twp-profile-grid {
        grid-template-columns: minmax(0, 1fr) 340px;
      }
      .twp-sticky-aside {
        position: sticky;
        top: 84px;
      }
    }
    .twp-gallery-strip {
      display: grid;
      grid-auto-flow: column;
      grid-auto-columns: calc(50% - 6px);
      gap: 12px;
      overflow-x: auto;
      scroll-snap-type: x mandatory;
      padding-bottom: 6px;
      -webkit-overflow-scrolling: touch;
    }
    @media (min-width: 640px) {
      .twp-gallery-strip {
        grid-auto-columns: calc(33.333% - 8px);
      }
    }
    @media (min-width: 1024px) {
      .twp-gallery-strip {
        grid-auto-columns: calc(25% - 9px);
      }
    }
    .twp-gallery-strip > * {
      scroll-snap-align: start;
    }
    .twp-staff-grid {
      display: grid;
      grid-template-columns: minmax(0, 1fr);
      gap: 12px;
    }
    @media (min-width: 640px) {
      .twp-staff-grid {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }
    }
    .twp-hours-grid {
      display: grid;
      grid-template-columns: minmax(0, 1fr);
      gap: 8px;
    }
    @media (min-width: 640px) {
      .twp-hours-grid {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }
    }
    .twp-minute-row {
      display: flex;
      flex-wrap: nowrap;
      align-items: center;
      gap: 6px;
      overflow-x: auto;
      padding-bottom: 4px;
      -webkit-overflow-scrolling: touch;
      scrollbar-width: thin;
    }
    .twp-minute-btn {
      flex: 0 0 auto;
      min-height: 34px;
      padding: 0 12px;
      border-radius: 9px;
      font-size: 12px;
      font-weight: 700;
      border: 1px solid #E2E8F0;
      background: #FFFFFF;
      color: #334155;
      white-space: nowrap;
      cursor: pointer;
      transition: all .15s ease;
    }
    .twp-minute-btn.is-active {
      background: #FF5722;
      border-color: #FF5722;
      color: #FFFFFF;
      box-shadow: 0 2px 6px rgba(255,87,34,0.28);
    }
    .twp-map-shell {
      display: flex;
      flex-direction: column;
      margin-top: 16px;
      height: clamp(540px, calc(100vh - 152px), 780px);
      width: 100%;
      max-width: 100%;
      background: #F8FAFC;
      border: 1px solid #E2E8F0;
      border-radius: 18px;
      box-shadow: 0 4px 20px rgba(15,23,42,0.06);
      overflow: hidden;
    }
    @media (max-width: 767px) {
      .twp-map-shell {
        margin-top: 10px;
        border-radius: 14px;
        height: calc(100vh - 122px);
        min-height: 480px;
      }
    }
    .twp-map-body {
      position: relative;
      flex: 1 1 auto;
      min-height: 0;
      min-width: 0;
      display: flex;
    }
    .twp-map-canvas-wrap {
      position: relative;
      flex: 1 1 auto;
      min-width: 0;
      min-height: 360px;
    }
    .twp-map-sidepanel {
      width: 390px;
      max-width: 42%;
      flex: 0 0 auto;
      background: #FFFFFF;
      border-left: 1px solid #E2E8F0;
      overflow-y: auto;
      z-index: 20;
      box-shadow: -8px 0 24px rgba(15,23,42,0.08);
    }
    @media (max-width: 1023px) {
      .twp-map-sidepanel {
        position: fixed;
        left: 0;
        right: 0;
        bottom: 0;
        width: 100%;
        max-width: 100%;
        max-height: 76vh;
        border-left: none;
        border-top: 1px solid #E2E8F0;
        border-radius: 20px 20px 0 0;
        box-shadow: 0 -10px 30px rgba(15,23,42,0.18);
        z-index: 40;
      }
    }
  `;
  document.head.appendChild(style);
}

export function formatMoney(value) {
  const num = Number(value || 0);
  if (!Number.isFinite(num)) return "₺0";
  return "₺" + num.toLocaleString("tr-TR", {
    minimumFractionDigits: num % 1 ? 2 : 0,
    maximumFractionDigits: 2,
  });
}

export function workModeLabel(mode) {
  if (mode === "venue") return "İşletmede Hizmet";
  if (mode === "mobile") return "Adreste Hizmet";
  if (mode === "both") return "İşletmede & Adreste";
  return "Hizmet";
}

export function providerTypeLabel(type) {
  return type === "coiffeur" ? "Kadın Kuaförü" : "Erkek Berberi";
}

export function initialsOf(name) {
  const clean = String(name || "T").trim();
  if (!clean) return "T";
  const parts = clean.split(/\s+/).filter(Boolean);
  if (parts.length >= 2) {
    return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
  }
  return clean.slice(0, 2).toUpperCase();
}

export const DAY_LABELS_TR = {
  monday: "Pazartesi",
  tuesday: "Salı",
  wednesday: "Çarşamba",
  thursday: "Perşembe",
  friday: "Cuma",
  saturday: "Cumartesi",
  sunday: "Pazar",
};

export function todayDayKey() {
  const keys = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
  return keys[new Date().getDay()] || "monday";
}

export function formatShortDate(iso) {
  if (!iso) return "";
  try {
    const d = new Date(iso.length === 10 ? `${iso}T00:00:00` : iso);
    if (Number.isNaN(d.getTime())) return iso;
    return d.toLocaleDateString("tr-TR", { day: "numeric", month: "long", year: "numeric" });
  } catch {
    return iso;
  }
}

export function AvatarOrMonogram({ src, name, size = 48, rounded = "14px", bg = "#FFF3ED", color = "#FF5722" }) {
  const h = React.createElement;
  const [failed, setFailed] = React.useState(false);
  React.useEffect(() => setFailed(false), [src]);
  const baseStyle = {
    width: size,
    height: size,
    borderRadius: rounded,
    overflow: "hidden",
    flexShrink: 0,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    background: bg,
    color,
    fontWeight: 800,
    fontSize: Math.max(12, Math.round(size * 0.34)),
  };
  if (src && !failed) {
    return h("div", { style: { ...baseStyle, background: "#F1F5F9" } },
      h("img", {
        src,
        alt: name || "",
        onError: () => setFailed(true),
        style: { width: "100%", height: "100%", objectFit: "cover", objectPosition: "50% 25%" },
      })
    );
  }
  return h("div", { style: baseStyle, "aria-hidden": "true" }, initialsOf(name));
}
