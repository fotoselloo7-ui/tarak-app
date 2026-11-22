import { r as React } from "./react-vendor-Dj04zrcb.js?v=20261030-nearby-fallback1";
import {
  b as api,
  B as Button,
  Y as MapPin,
  S as ShieldCheck,
  _ as TarakRating,
  a2 as TarakRatingMarks,
  x as VerifiedTick,
  g as Calendar,
  a3 as Clock,
  X as XIcon,
  H as Search,
  N as Users,
} from "./index-Bj5sn6If.js?v=20261030-nearby-fallback1";
import {
  ensureParityStyles,
  formatMoney,
  workModeLabel,
  providerTypeLabel,
  todayDayKey,
  formatShortDate,
  AvatarOrMonogram,
} from "./WebParityShared.js?v=20261122-final1";

const MAPLIBRE_VERSION = "6.16.0";
const STYLE_URL = "https://tiles.openfreemap.org/styles/liberty";
const DEFAULT_CENTER = [35.24, 38.96];

let mapLibrePromise = null;
function loadMapLibre() {
  if (mapLibrePromise) return mapLibrePromise;
  mapLibrePromise = (async () => {
    const cssId = "maplibre-gl-css";
    if (!document.getElementById(cssId)) {
      const link = document.createElement("link");
      link.id = cssId;
      link.rel = "stylesheet";
      link.href = `https://unpkg.com/maplibre-gl@${MAPLIBRE_VERSION}/dist/maplibre-gl.css`;
      document.head.appendChild(link);
    }
    const mod = await import(`https://unpkg.com/maplibre-gl@${MAPLIBRE_VERSION}/dist/maplibre-gl.mjs`);
    return mod.default || mod;
  })();
  return mapLibrePromise;
}

function loadImage(src) {
  return new Promise((resolve) => {
    const img = new Image();
    img.crossOrigin = "anonymous";
    img.onload = () => resolve(img);
    img.onerror = () => resolve(null);
    img.src = src;
  });
}

async function createTarakPinIcons() {
  const brandImg = await loadImage("/brand/tarak-rating-128.png");
  const drawCombFallback = (ctx, cx, cy, s) => {
    ctx.fillStyle = "#FF5722";
    ctx.fillRect(cx - s * 0.45, cy - s * 0.35, s * 0.9, s * 0.22);
    for (let i = -3; i <= 3; i++) {
      ctx.fillRect(cx + i * (s * 0.12) - 1.5, cy - s * 0.15, 3, s * 0.5);
    }
  };

  const makeCirclePin = (size, borderColor, innerAccent = false) => {
    const canvas = document.createElement("canvas");
    canvas.width = size;
    canvas.height = size;
    const ctx = canvas.getContext("2d");
    const c = size / 2;
    const r = size * 0.39;

    // Subtle soft shadow
    ctx.save();
    ctx.beginPath();
    ctx.arc(c, c + 3, r + 2, 0, Math.PI * 2);
    ctx.fillStyle = "rgba(15, 23, 42, 0.22)";
    ctx.fill();
    ctx.restore();

    // Outer white disc
    ctx.beginPath();
    ctx.arc(c, c, r, 0, Math.PI * 2);
    ctx.fillStyle = "#FFFFFF";
    ctx.fill();

    // Colored ring
    ctx.lineWidth = Math.max(4, size * 0.075);
    ctx.strokeStyle = borderColor;
    ctx.stroke();

    if (innerAccent) {
      ctx.beginPath();
      ctx.arc(c, c, r - 6, 0, Math.PI * 2);
      ctx.lineWidth = 2;
      ctx.strokeStyle = "#FF5722";
      ctx.stroke();
    }

    if (brandImg) {
      const iconSize = size * 0.46;
      ctx.drawImage(brandImg, c - iconSize / 2, c - iconSize / 2, iconSize, iconSize);
    } else {
      drawCombFallback(ctx, c, c, size * 0.42);
    }
    return ctx.getImageData(0, 0, size, size);
  };

  return {
    "tarak-pin-barber": makeCirclePin(88, "#2563EB", false),
    "tarak-pin-coiffeur": makeCirclePin(88, "#DC2626", false),
    "tarak-cluster-icon": makeCirclePin(96, "#0F172A", true),
  };
}

function formatDistance(meters) {
  const m = Number(meters || 0);
  if (m >= 1000) return `${(m / 1000).toFixed(1)} km`;
  return `${Math.round(m)} m`;
}

function formatDuration(seconds) {
  const mins = Math.max(1, Math.round(Number(seconds || 0) / 60));
  if (mins >= 60) {
    const h = Math.floor(mins / 60);
    const rem = mins % 60;
    return rem ? `${h} sa ${rem} dk` : `${h} sa`;
  }
  return `${mins} dk`;
}

export function WebTarakMap({ user, onNavigate, params = {} }) {
  const h = React.createElement;
  ensureParityStyles();

  const isCustomer = user?.role === "CUSTOMER";
  const mapContainerRef = React.useRef(null);
  const mapRef = React.useRef(null);
  const mlRef = React.useRef(null);
  const customerMarkerRef = React.useRef(null);
  const pinsGeoRef = React.useRef({ type: "FeatureCollection", features: [] });
  const routeGeoRef = React.useRef({ type: "FeatureCollection", features: [] });

  const [mapReady, setMapReady] = React.useState(false);
  const [mapError, setMapError] = React.useState("");
  const [viewMode, setViewMode] = React.useState("map"); // map | list
  const [loading, setLoading] = React.useState(true);
  const [pins, setPins] = React.useState([]);
  const [mobileProviders, setMobileProviders] = React.useState([]);
  const [totalEligible, setTotalEligible] = React.useState(0);

  // Filters
  const [searchQ, setSearchQ] = React.useState("");
  const [typeFilter, setTypeFilter] = React.useState("");
  const [workModeFilter, setWorkModeFilter] = React.useState("");
  const [cityFilter, setCityFilter] = React.useState("");
  const [districtFilter, setDistrictFilter] = React.useState("");

  // Addresses & Initial location Rule #1
  const [addresses, setAddresses] = React.useState([]);
  const [selectedOriginAddrId, setSelectedOriginAddrId] = React.useState("gps");
  const [gpsCoords, setGpsCoords] = React.useState(null);
  const [originLabel, setOriginLabel] = React.useState("");

  // Selected Panel Detail (canonical Tarak business only)
  const [selectedBiz, setSelectedBiz] = React.useState(null);
  const [detailLoading, setDetailLoading] = React.useState(false);
  const [lightboxUrls, setLightboxUrls] = React.useState(null);
  const [lightboxIndex, setLightboxIndex] = React.useState(0);

  // Route State
  const [routeProfile, setRouteProfile] = React.useState("driving");
  const [routeData, setRouteData] = React.useState(null);
  const [routeBusy, setRouteBusy] = React.useState(false);
  const [routeErr, setRouteErr] = React.useState("");

  const pushSourceData = React.useCallback((sourceId, data) => {
    const map = mapRef.current;
    if (!map) return;
    const src = map.getSource(sourceId);
    if (src && typeof src.setData === "function") src.setData(data);
  }, []);

  const fetchBusinesses = React.useCallback(async (opts = {}) => {
    setLoading(true);
    try {
      const sp = new URLSearchParams();
      const t = opts.type !== undefined ? opts.type : typeFilter;
      const wm = opts.workMode !== undefined ? opts.workMode : workModeFilter;
      const q = opts.q !== undefined ? opts.q : searchQ;
      const c = opts.city !== undefined ? opts.city : cityFilter;
      const d = opts.district !== undefined ? opts.district : districtFilter;
      if (t) sp.set("type", t);
      if (wm) sp.set("work_mode", wm);
      if (q.trim()) sp.set("q", q.trim());
      if (c.trim()) sp.set("city", c.trim());
      if (d.trim()) sp.set("district", d.trim());
      if (opts.bounds) {
        sp.set("min_lat", String(opts.bounds.getSouth().toFixed(5)));
        sp.set("max_lat", String(opts.bounds.getNorth().toFixed(5)));
        sp.set("min_lng", String(opts.bounds.getWest().toFixed(5)));
        sp.set("max_lng", String(opts.bounds.getEast().toFixed(5)));
      }
      sp.set("limit", "1000");

      const res = await api.get(`/map/businesses?${sp.toString()}`);
      if (res?.success) {
        const list = Array.isArray(res.data) ? res.data : [];
        const mobList = Array.isArray(res.mobile_providers) ? res.mobile_providers : [];
        setPins(list);
        setMobileProviders(mobList);
        setTotalEligible(Number(res.meta?.total_eligible_pins || list.length));

        pinsGeoRef.current = {
          type: "FeatureCollection",
          features: list
            .filter((p) => p.has_public_pin && Number.isFinite(Number(p.latitude)) && Number.isFinite(Number(p.longitude)))
            .map((p) => ({
              type: "Feature",
              geometry: { type: "Point", coordinates: [Number(p.longitude), Number(p.latitude)] },
              properties: {
                id: String(p.id),
                user_id: String(p.user_id),
                slug: String(p.slug || p.user_id),
                business_name: p.business_name || p.name || "",
                provider_type: p.provider_type || "barber",
                icon_key: p.provider_type === "coiffeur" ? "tarak-pin-coiffeur" : "tarak-pin-barber",
              },
            })),
        };
        pushSourceData("tarak-pins", pinsGeoRef.current);

        if (!opts.bounds && (c.trim() || d.trim() || q.trim()) && mapRef.current) {
          const feats = pinsGeoRef.current.features;
          if (feats.length === 1) {
            mapRef.current.flyTo({ center: feats[0].geometry.coordinates, zoom: 13.5, duration: 700 });
          } else if (feats.length > 1) {
            let minLng = 180, minLat = 90, maxLng = -180, maxLat = -90;
            for (const f of feats) {
              const [lng, lat] = f.geometry.coordinates;
              if (lng < minLng) minLng = lng;
              if (lng > maxLng) maxLng = lng;
              if (lat < minLat) minLat = lat;
              if (lat > maxLat) maxLat = lat;
            }
            if (Math.abs(maxLng - minLng) < 0.004 && Math.abs(maxLat - minLat) < 0.004) {
              mapRef.current.flyTo({ center: [(minLng + maxLng) / 2, (minLat + maxLat) / 2], zoom: 13.5, duration: 700 });
            } else {
              mapRef.current.fitBounds([[minLng, minLat], [maxLng, maxLat]], { padding: 60, maxZoom: 13.5, duration: 700 });
            }
          } else if (c.trim() || d.trim()) {
            try {
              const g = await api.get(`/geo/search?q=${encodeURIComponent([d, c].filter(Boolean).join(", "))}`);
              const gd = g?.data;
              const lat = Number(gd?.latitude);
              const lng = Number(gd?.longitude);
              if (Number.isFinite(lat) && Number.isFinite(lng) && mapRef.current) {
                mapRef.current.flyTo({ center: [lng, lat], zoom: d.trim() ? 12.5 : 11, duration: 700 });
              }
            } catch {}
          }
        }
      }
    } catch {
      // keep previous markers on transient failure
    } finally {
      setLoading(false);
    }
  }, [typeFilter, workModeFilter, searchQ, cityFilter, districtFilter, pushSourceData]);

  const closeRoute = React.useCallback(() => {
    setRouteData(null);
    setRouteErr("");
    routeGeoRef.current = { type: "FeatureCollection", features: [] };
    pushSourceData("tarak-route", routeGeoRef.current);
  }, [pushSourceData]);

  const openBusinessDetail = React.useCallback(async (identifier, triggerRoute = false, originCoords = null) => {
    if (!identifier) return;
    setDetailLoading(true);
    closeRoute();
    try {
      const res = await api.get(`/map/businesses/${encodeURIComponent(String(identifier))}`);
      if (res?.success && res.data) {
        const biz = res.data;
        setSelectedBiz(biz);
        if (biz.has_public_pin && Number.isFinite(Number(biz.latitude)) && Number.isFinite(Number(biz.longitude)) && mapRef.current) {
          mapRef.current.flyTo({ center: [Number(biz.longitude), Number(biz.latitude)], zoom: Math.max(mapRef.current.getZoom(), 14), duration: 700 });
        }
        if (triggerRoute && biz.can_get_directions && biz.has_public_pin) {
          const orig = originCoords;
          if (orig) {
            // Delay slightly so selectedBiz state settles cleanly
            setTimeout(() => requestRoute(biz, orig, "driving"), 200);
          }
        }
      }
    } catch {
      // ignore missing business
    } finally {
      setDetailLoading(false);
    }
  }, [closeRoute]);

  const resolveActiveOrigin = React.useCallback((overrideAddrId) => {
    const id = overrideAddrId !== undefined ? overrideAddrId : selectedOriginAddrId;
    if (id && id !== "gps") {
      const a = addresses.find((x) => String(x.id) === String(id));
      if (a && Number.isFinite(Number(a.latitude)) && Number.isFinite(Number(a.longitude))) {
        return { lat: Number(a.latitude), lng: Number(a.longitude), label: a.title || "Kayıtlı Adres" };
      }
    }
    if (gpsCoords) return { lat: gpsCoords.lat, lng: gpsCoords.lng, label: "Mevcut Konumunuz" };
    return null;
  }, [addresses, selectedOriginAddrId, gpsCoords]);

  const requestRoute = React.useCallback(async (destBiz, explicitOrigin = null, profile = routeProfile) => {
    const biz = destBiz || selectedBiz;
    if (!biz) return;
    if (!biz.has_public_pin || !biz.can_get_directions) {
      setRouteErr("Gezici uzmanın özel konumuna yol tarifi oluşturulamaz.");
      return;
    }

    let orig = explicitOrigin || resolveActiveOrigin();
    if (!orig && typeof navigator !== "undefined" && navigator.geolocation) {
      try {
        orig = await new Promise((resolve) => {
          navigator.geolocation.getCurrentPosition(
            (pos) => {
              const g = { lat: pos.coords.latitude, lng: pos.coords.longitude, label: "Mevcut Konumunuz" };
              setGpsCoords({ lat: g.lat, lng: g.lng });
              resolve(g);
            },
            () => resolve(null),
            { timeout: 4000, maximumAge: 60000 }
          );
        });
      } catch {
        orig = null;
      }
    }

    if (!orig) {
      setRouteErr("Rota hesaplamak için lütfen üst menüden başlangıç adresinizi seçin veya tarayıcı konum izni verin.");
      return;
    }

    setRouteBusy(true);
    setRouteErr("");
    try {
      const sp = new URLSearchParams({
        origin_lat: String(orig.lat),
        origin_lng: String(orig.lng),
        dest_lat: String(biz.latitude),
        dest_lng: String(biz.longitude),
        profile,
      });
      const res = await api.get(`/map/route?${sp.toString()}`);
      if (!res?.success || !res.data?.geometry) {
        throw new Error(res?.message || "Yol tarifi hesaplanamadı.");
      }
      setRouteData({ ...res.data, origin: orig, dest: { lat: Number(biz.latitude), lng: Number(biz.longitude), name: biz.business_name || biz.name } });
      routeGeoRef.current = {
        type: "FeatureCollection",
        features: [{
          type: "Feature",
          geometry: res.data.geometry,
          properties: {},
        }],
      };
      pushSourceData("tarak-route", routeGeoRef.current);

      if (mapRef.current && res.data.bounds) {
        const b = res.data.bounds;
        const west = Number(b.west ?? b.min_lng);
        const south = Number(b.south ?? b.min_lat);
        const east = Number(b.east ?? b.max_lng);
        const north = Number(b.north ?? b.max_lat);
        if ([west, south, east, north].every(Number.isFinite)) {
          try {
            mapRef.current.fitBounds(
              [[west, south], [east, north]],
              { padding: 70, duration: 700, maxZoom: 16 }
            );
          } catch {}
        }
      }
    } catch (e) {
      setRouteErr(e?.message || "Rota servisi şu anda yanıt vermedi.");
    } finally {
      setRouteBusy(false);
    }
  }, [selectedBiz, routeProfile, resolveActiveOrigin, pushSourceData]);

  // Initial Rule #1 Centering + MapLibre Mount
  React.useEffect(() => {
    let alive = true;
    (async () => {
      // 1. Determine initial camera target cleanly (Rule #1: Customer Default Address -> ?business -> GPS -> Turkey)
      let initCenter = DEFAULT_CENTER;
      let initZoom = 5.4;
      let initialOriginForRoute = null;

      if (isCustomer) {
        try {
          const addrRes = await api.customer.getAddresses();
          const addrList = Array.isArray(addrRes?.data) ? addrRes.data : [];
          if (!alive) return;
          setAddresses(addrList);
          const defAddr = addrList.find((a) => a.is_default && a.latitude != null && a.longitude != null)
            || addrList.find((a) => a.latitude != null && a.longitude != null);
          if (defAddr) {
            const lat = Number(defAddr.latitude);
            const lng = Number(defAddr.longitude);
            initCenter = [lng, lat];
            initZoom = 13.5;
            setSelectedOriginAddrId(String(defAddr.id));
            setOriginLabel(`${defAddr.title || "Varsayılan Adres"} (${defAddr.district}, ${defAddr.province})`);
            initialOriginForRoute = { lat, lng, label: defAddr.title || "Varsayılan Adres" };
          }
        } catch {
          // fallback below
        }
      }

      // 2. If URL has ?business=..., peek business coordinates if no saved default centered yet
      let initialBusiness = null;
      if (params?.business) {
        try {
          const r = await api.get(`/map/businesses/${encodeURIComponent(String(params.business))}`);
          if (r?.success && r.data) {
            initialBusiness = r.data;
            if (r.data.has_public_pin && Number.isFinite(Number(r.data.latitude)) && Number.isFinite(Number(r.data.longitude))) {
              initCenter = [Number(r.data.longitude), Number(r.data.latitude)];
              initZoom = 14.5;
            }
          }
        } catch {}
      }

      // 3. Fallback to browser geolocation only if still at Turkey default
      if (initCenter === DEFAULT_CENTER && typeof navigator !== "undefined" && navigator.geolocation) {
        try {
          const pos = await new Promise((resolve) => {
            navigator.geolocation.getCurrentPosition(resolve, () => resolve(null), { timeout: 2500, maximumAge: 120000 });
          });
          if (pos?.coords) {
            initCenter = [pos.coords.longitude, pos.coords.latitude];
            initZoom = 13;
            setGpsCoords({ lat: pos.coords.latitude, lng: pos.coords.longitude });
            setOriginLabel("Mevcut Konumunuz");
            initialOriginForRoute = { lat: pos.coords.latitude, lng: pos.coords.longitude, label: "Mevcut Konumunuz" };
          }
        } catch {}
      }

      if (!alive || !mapContainerRef.current) return;

      let ml;
      try {
        ml = await loadMapLibre();
        mlRef.current = ml;
      } catch {
        if (alive) setMapError("Harita kütüphanesi yüklenemedi. İnternet bağlantınızı kontrol edin.");
        return;
      }
      if (!alive || !mapContainerRef.current) return;

      const map = new ml.Map({
        container: mapContainerRef.current,
        style: STYLE_URL,
        center: initCenter,
        zoom: initZoom,
        attributionControl: true,
      });
      mapRef.current = map;

      map.addControl(new ml.NavigationControl({ showCompass: false }), "top-right");
      map.doubleClickZoom.enable();
      map.scrollZoom.enable();

      map.on("load", async () => {
        if (!alive) return;
        try {
          const imgs = await createTarakPinIcons();
          for (const [k, img] of Object.entries(imgs)) {
            if (!map.hasImage(k)) map.addImage(k, img);
          }
        } catch {}

        // Route layer
        map.addSource("tarak-route", { type: "geojson", data: routeGeoRef.current });
        map.addLayer({
          id: "tarak-route-casing",
          type: "line",
          source: "tarak-route",
          layout: { "line-join": "round", "line-cap": "round" },
          paint: { "line-color": "#FFFFFF", "line-width": 8, "line-opacity": 0.9 },
        });
        map.addLayer({
          id: "tarak-route-line",
          type: "line",
          source: "tarak-route",
          layout: { "line-join": "round", "line-cap": "round" },
          paint: { "line-color": "#FF5722", "line-width": 4.5, "line-opacity": 0.96 },
        });

        // Tarak Businesses Clustered Source (NUMBERLESS Tarak comb cluster icon!)
        map.addSource("tarak-pins", {
          type: "geojson",
          data: pinsGeoRef.current,
          cluster: true,
          clusterRadius: 46,
          clusterMaxZoom: 14,
        });
        map.addLayer({
          id: "tarak-clusters",
          type: "symbol",
          source: "tarak-pins",
          filter: ["has", "point_count"],
          layout: {
            "icon-image": "tarak-cluster-icon",
            "icon-size": 0.56,
            "icon-allow-overlap": true,
          },
        });
        map.addLayer({
          id: "tarak-unclustered",
          type: "symbol",
          source: "tarak-pins",
          filter: ["!", ["has", "point_count"]],
          layout: {
            "icon-image": ["get", "icon_key"],
            "icon-size": 0.58,
            "icon-allow-overlap": true,
          },
        });

        // Draw subtle origin marker if we have saved default/GPS center
        if (initialOriginForRoute) {
          const dot = document.createElement("div");
          dot.title = initialOriginForRoute.label;
          dot.style.cssText = "width:16px;height:16px;border-radius:999px;background:#0F172A;border:3px solid #FFFFFF;box-shadow:0 2px 8px rgba(15,23,42,0.45);";
          customerMarkerRef.current = new ml.Marker({ element: dot })
            .setLngLat([initialOriginForRoute.lng, initialOriginForRoute.lat])
            .addTo(map);
        }

        // Click handlers
        map.on("click", "tarak-clusters", async (e) => {
          const feat = e.features?.[0];
          if (!feat) return;
          const clusterId = feat.properties.cluster_id;
          try {
            const zoom = await map.getSource("tarak-pins").getClusterExpansionZoom(clusterId);
            map.easeTo({ center: feat.geometry.coordinates, zoom: Math.min(Number(zoom || 13) + 0.6, 17), duration: 500 });
          } catch {}
        });

        map.on("click", "tarak-unclustered", (e) => {
          const feat = e.features?.[0];
          if (!feat?.properties) return;
          openBusinessDetail(feat.properties.slug || feat.properties.user_id, false);
        });

        for (const layerId of ["tarak-clusters", "tarak-unclustered"]) {
          map.on("mouseenter", layerId, () => { map.getCanvas().style.cursor = "pointer"; });
          map.on("mouseleave", layerId, () => { map.getCanvas().style.cursor = ""; });
        }

        setMapReady(true);
        await fetchBusinesses({ bounds: null });
        if (initialBusiness) {
          setSelectedBiz(initialBusiness);
          if (params?.route === "1" && initialBusiness.can_get_directions && initialBusiness.has_public_pin && initialOriginForRoute) {
            setTimeout(() => requestRoute(initialBusiness, initialOriginForRoute, "driving"), 200);
          }
        }
      });
    })();

    return () => {
      alive = false;
      if (customerMarkerRef.current) {
        customerMarkerRef.current.remove();
        customerMarkerRef.current = null;
      }
      if (mapRef.current) {
        mapRef.current.remove();
        mapRef.current = null;
      }
    };
  }, []);

  // Re-fetch when filters change cleanly
  const applyFilters = (e) => {
    if (e) e.preventDefault();
    fetchBusinesses({ bounds: null });
  };

  const searchInArea = () => {
    const map = mapRef.current;
    if (!map) return;
    fetchBusinesses({ bounds: map.getBounds() });
  };

  const onOriginSelectChange = (newId) => {
    setSelectedOriginAddrId(newId);
    const orig = resolveActiveOrigin(newId);
    if (orig) {
      setOriginLabel(orig.label);
      if (mapRef.current) {
        mapRef.current.flyTo({ center: [orig.lng, orig.lat], zoom: 13.8, duration: 600 });
        if (customerMarkerRef.current) customerMarkerRef.current.setLngLat([orig.lng, orig.lat]);
      }
    }
    if (routeData && selectedBiz) {
      requestRoute(selectedBiz, orig, routeProfile);
    }
  };

  React.useEffect(() => {
    const timer = setTimeout(() => {
      try {
        mapRef.current?.resize();
      } catch {}
    }, 60);
    return () => clearTimeout(timer);
  }, [selectedBiz, detailLoading, viewMode]);

  const handleClosePanel = () => {
    setSelectedBiz(null);
    closeRoute();
  };

  const todayKey = todayDayKey();
  const canBookSelected = selectedBiz
    ? (selectedBiz.accepts_tarak_bookings !== false && selectedBiz.is_verified === true && !selectedBiz.is_demo)
    : false;
  const selectedReviews = Array.isArray(selectedBiz?.reviews) ? selectedBiz.reviews : [];
  const selectedPackages = Array.isArray(selectedBiz?.packages) ? selectedBiz.packages : [];
  const selectedHours = Array.isArray(selectedBiz?.working_hours) ? selectedBiz.working_hours : [];
  const selectedAreas = Array.isArray(selectedBiz?.service_areas) ? selectedBiz.service_areas : [];

  return h("div", { className: "twp-map-shell", "data-testid": "web-tarak-harita" },
    // Top filter toolbar
    h("form", {
      onSubmit: applyFilters,
      style: {
        background: "#FFFFFF",
        borderBottom: "1px solid #E2E8F0",
        padding: "10px 14px",
        display: "flex",
        flexWrap: "wrap",
        alignItems: "center",
        gap: 8,
        zIndex: 25,
      },
    },
      h("div", { style: { display: "flex", alignItems: "center", gap: 6, flex: "1 1 200px", minWidth: 160 } },
        h(Search, { size: 15, className: "text-gray-400 shrink-0" }),
        h("input", {
          type: "text",
          value: searchQ,
          onChange: (e) => setSearchQ(e.target.value),
          placeholder: "İşletme, semt veya hizmet ara…",
          "aria-label": "Haritada ara",
          style: {
            width: "100%", padding: "7px 10px", borderRadius: 10, border: "1px solid #CBD5E1",
            fontSize: 12, outline: "none",
          },
        })
      ),

      h("select", {
        value: typeFilter,
        onChange: (e) => { setTypeFilter(e.target.value); fetchBusinesses({ type: e.target.value }); },
        "aria-label": "Kategori filtresi",
        style: { padding: "7px 10px", borderRadius: 10, border: "1px solid #CBD5E1", fontSize: 12, background: "#fff" },
      },
        h("option", { value: "" }, "Tüm Kategoriler"),
        h("option", { value: "barber" }, "Erkek Berberi"),
        h("option", { value: "coiffeur" }, "Kadın Kuaförü")
      ),

      h("select", {
        value: workModeFilter,
        onChange: (e) => { setWorkModeFilter(e.target.value); fetchBusinesses({ workMode: e.target.value }); },
        "aria-label": "Çalışma biçimi",
        style: { padding: "7px 10px", borderRadius: 10, border: "1px solid #CBD5E1", fontSize: 12, background: "#fff" },
      },
        h("option", { value: "" }, "Tüm Çalışma Şekilleri"),
        h("option", { value: "venue" }, "İşletmede"),
        h("option", { value: "mobile" }, "Adreste"),
        h("option", { value: "both" }, "Her İkisi")
      ),

      h("input", {
        type: "text",
        value: cityFilter,
        onChange: (e) => setCityFilter(e.target.value),
        placeholder: "İl (örn: İstanbul)",
        "aria-label": "İl filtresi",
        style: { width: 118, padding: "7px 10px", borderRadius: 10, border: "1px solid #CBD5E1", fontSize: 12 },
      }),

      h("input", {
        type: "text",
        value: districtFilter,
        onChange: (e) => setDistrictFilter(e.target.value),
        placeholder: "İlçe (örn: Şişli)",
        "aria-label": "İlçe filtresi",
        style: { width: 118, padding: "7px 10px", borderRadius: 10, border: "1px solid #CBD5E1", fontSize: 12 },
      }),

      addresses.length > 0 && h("select", {
        value: selectedOriginAddrId,
        onChange: (e) => onOriginSelectChange(e.target.value),
        "aria-label": "Başlangıç konumu",
        style: { padding: "7px 10px", borderRadius: 10, border: "1px solid #FDBA74", background: "#FFF7ED", fontSize: 12, fontWeight: 700, color: "#9A3412", maxWidth: 190 },
      },
        addresses.map((a) => h("option", { key: a.id, value: String(a.id) }, `${a.is_default ? "★ " : ""}${a.title || "Adres"} (${a.district})`)),
        h("option", { value: "gps" }, "Mevcut Konum (GPS)")
      ),

      h("button", {
        type: "submit",
        style: { padding: "7px 13px", borderRadius: 10, background: "#FF5722", color: "#fff", fontSize: 12, fontWeight: 700, border: "none", cursor: "pointer" },
      }, "Filtrele"),

      h("button", {
        type: "button",
        onClick: searchInArea,
        style: { padding: "7px 13px", borderRadius: 10, background: "#0F172A", color: "#fff", fontSize: 12, fontWeight: 700, border: "none", cursor: "pointer" },
      }, "Bu Alanda Ara"),

      h("div", { className: "inline-flex p-0.5 rounded-xl bg-slate-100 border border-slate-200 ml-auto" },
        [["map", "Harita"], ["list", `Liste (${pins.length})`]].map(([m, label]) =>
          h("button", {
            key: m,
            type: "button",
            onClick: () => setViewMode(m),
            style: {
              padding: "6px 12px",
              borderRadius: 9,
              fontSize: 12,
              fontWeight: 700,
              background: viewMode === m ? "#FFFFFF" : "transparent",
              color: viewMode === m ? "#0F172A" : "#64748B",
              boxShadow: viewMode === m ? "0 1px 3px rgba(15,23,42,0.1)" : "none",
              border: "none",
              cursor: "pointer",
            },
          }, label)
        )
      )
    ),

    // Main split body
    h("div", { className: "twp-map-body" },
      // Map or List area
      h("div", { className: "twp-map-canvas-wrap" },
        h("div", {
          ref: mapContainerRef,
          style: {
            width: "100%",
            height: "100%",
            display: viewMode === "map" ? "block" : "none",
          },
        }),

        // Origin / Legend overlay badge on Map
        viewMode === "map" && h("div", {
          style: {
            position: "absolute",
            top: 12,
            left: 12,
            zIndex: 10,
            display: "flex",
            flexWrap: "wrap",
            gap: 8,
            pointerEvents: "none",
          },
        },
          originLabel && h("span", {
            style: {
              background: "rgba(255,255,255,0.95)",
              border: "1px solid #E2E8F0",
              borderRadius: 999,
              padding: "5px 11px",
              fontSize: 11,
              fontWeight: 700,
              color: "#0F172A",
              boxShadow: "0 2px 8px rgba(15,23,42,0.1)",
            },
          }, `Konum: ${originLabel}`),
          h("span", {
            style: {
              background: "rgba(255,255,255,0.95)",
              border: "1px solid #E2E8F0",
              borderRadius: 999,
              padding: "5px 11px",
              fontSize: 11,
              fontWeight: 600,
              color: "#334155",
              display: "inline-flex",
              alignItems: "center",
              gap: 8,
              boxShadow: "0 2px 8px rgba(15,23,42,0.1)",
            },
          },
            h("span", null, "🔵 Berber"),
            h("span", null, "🔴 Kuaför"),
            loading ? h("span", { style: { color: "#FF5722" } }, "· Yükleniyor…") : h("span", null, `· ${pins.length}/${totalEligible} sabit`)
          )
        ),

        // Quick Search & In-App Route Status Bar overlay at bottom-left of Map
        viewMode === "map" && routeData && h("div", {
          "data-testid": "inapp-route-banner",
          style: {
            position: "absolute",
            bottom: 16,
            left: 16,
            right: 16,
            maxWidth: 460,
            zIndex: 15,
            background: "#0F172A",
            color: "#FFFFFF",
            borderRadius: 16,
            padding: "12px 16px",
            boxShadow: "0 12px 28px rgba(15,23,42,0.35)",
          },
        },
          h("div", { style: { display: "flex", alignItems: "center", justifyContent: "space-between", gap: 10 } },
            h("div", null,
              h("div", { style: { fontSize: 11, color: "#94A3B8", fontWeight: 700 } }, `Uygulama İçi Yol Tarifi → ${routeData.dest.name}`),
              h("div", { style: { fontSize: 16, fontWeight: 800, marginTop: 2 } },
                `${formatDistance(routeData.distance_meters)} • ${formatDuration(routeData.duration_seconds)}`
              )
            ),
            h("button", {
              type: "button",
              onClick: closeRoute,
              style: {
                padding: "7px 12px", borderRadius: 10, background: "#FF5722", color: "#fff",
                fontSize: 12, fontWeight: 800, border: "none", cursor: "pointer",
              },
            }, "Rotayı Kapat")
          ),
          h("div", { style: { display: "flex", alignItems: "center", gap: 8, marginTop: 8, flexWrap: "wrap" } },
            ["driving", "walking"].map((p) =>
              h("button", {
                key: p,
                type: "button",
                onClick: () => { setRouteProfile(p); requestRoute(selectedBiz, routeData.origin, p); },
                style: {
                  padding: "4px 10px",
                  borderRadius: 8,
                  fontSize: 11,
                  fontWeight: 700,
                  background: routeProfile === p ? "#FFFFFF" : "rgba(255,255,255,0.12)",
                  color: routeProfile === p ? "#0F172A" : "#E2E8F0",
                  border: "none",
                  cursor: "pointer",
                },
              }, p === "driving" ? "Araç Rotası" : "Yürüyüş")
            ),
            h("a", {
              href: `https://www.google.com/maps/dir/?api=1&destination=${routeData.dest.lat},${routeData.dest.lng}`,
              target: "_blank",
              rel: "noreferrer",
              style: { marginLeft: "auto", fontSize: 11, color: "#FDBA74", textDecoration: "underline" },
            }, "Harici Haritada Aç")
          )
        ),

        mapError && viewMode === "map" && h("div", {
          style: {
            position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center",
            background: "rgba(248,250,252,0.95)", zIndex: 20, padding: 24, textAlign: "center",
          },
        }, h("div", { className: "max-w-sm text-sm text-rose-700 font-semibold" }, mapError)),

        // List View
        viewMode === "list" && h("div", { style: { height: "100%", overflowY: "auto", padding: "16px" } },
          h("div", { className: "max-w-5xl mx-auto space-y-6" },
            h("div", null,
              h("h2", { className: "text-base font-bold text-gray-900 mb-3" }, `Harita İşletmeleri (${pins.length})`),
              pins.length === 0
                ? h("div", { className: "p-8 text-center text-sm text-gray-500 bg-white rounded-2xl border border-gray-200" },
                    "Filtrelere uygun sabit işletme bulunamadı."
                  )
                : h("div", { className: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3" },
                    pins.map((p) =>
                      h("button", {
                        key: p.id,
                        type: "button",
                        onClick: () => openBusinessDetail(p.slug || p.user_id, false),
                        className: "text-left p-4 rounded-2xl bg-white border border-gray-200 hover:border-[#FF5722] shadow-sm transition-all flex items-start gap-3",
                      },
                        h(AvatarOrMonogram, { src: p.pin_image_url || p.logo_url || p.avatar_url, name: p.business_name || p.name, size: 48 }),
                        h("div", { className: "min-w-0 flex-1" },
                          h("div", { className: "font-bold text-sm text-gray-900 flex items-center gap-1" },
                            h("span", { className: "truncate" }, p.business_name || p.name),
                            p.is_verified && h(VerifiedTick, { size: 15 })
                          ),
                          h("div", { className: "text-xs text-gray-500 mt-0.5" },
                            `${providerTypeLabel(p.provider_type)} • ${[p.district, p.city].filter(Boolean).join(", ")}`
                          ),
                          h("div", { className: "mt-1.5 flex items-center gap-2 text-xs" },
                            typeof p.rating === "number" && p.review_count > 0
                              ? h(TarakRating, { value: p.rating, count: p.review_count, size: 12 })
                              : h("span", { className: "text-gray-400" }, "Yeni profil"),
                            p.distance_km != null && h("span", { className: "text-gray-400" }, `· ~${p.distance_km} km`)
                          )
                        )
                      )
                    )
                  )
            ),

            mobileProviders.length > 0 && h("div", null,
              h("h2", { className: "text-base font-bold text-gray-900 mb-2" },
                `Bölgenize Adreste Hizmet Veren Gezici Uzmanlar (${mobileProviders.length})`
              ),
              h("p", { className: "text-xs text-gray-500 mb-3" }, "Gezici uzmanların özel adresleri ve harita pinleri gizlilik gereği haritada gösterilmez."),
              h("div", { className: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3" },
                mobileProviders.map((m) =>
                  h("button", {
                    key: m.id,
                    type: "button",
                    onClick: () => openBusinessDetail(m.slug || m.user_id, false),
                    className: "text-left p-4 rounded-2xl bg-white border border-gray-200 hover:border-[#FF5722] shadow-sm flex items-start gap-3",
                  },
                    h(AvatarOrMonogram, { src: m.logo_url || m.avatar_url, name: m.business_name || m.name, size: 46 }),
                    h("div", { className: "min-w-0 flex-1" },
                      h("div", { className: "font-bold text-sm text-gray-900 flex items-center gap-1" },
                        h("span", { className: "truncate" }, m.business_name || m.name),
                        m.is_verified && h(VerifiedTick, { size: 15 })
                      ),
                      h("div", { className: "text-xs text-gray-500 mt-0.5" }, `${workModeLabel(m.work_mode)} • ${[m.district, m.city].filter(Boolean).join(", ")}`),
                      h("div", { className: "text-[11px] text-[#FF5722] font-semibold mt-1" }, `Servis yarıçapı: ${m.service_radius_km || 15} km`)
                    )
                  )
                )
              )
            )
          )
        )
      ),

      // Desktop Side Panel / Mobile Bottom Sheet when business selected (Canonical Original Tarak Profile)
      (detailLoading || selectedBiz) && h("aside", {
        className: "twp-map-sidepanel",
        "data-testid": "map-detail-panel",
      },
        detailLoading && h("div", { className: "p-6 text-center text-sm text-gray-500" }, "İşletme detayı yükleniyor…"),

        !detailLoading && selectedBiz && h("div", { className: "pb-6" },
          // Side panel cover + close
          h("div", {
            style: {
              position: "relative",
              height: selectedBiz.cover_url ? 136 : 84,
              background: "linear-gradient(135deg, #0F172A 0%, #1E293B 100%)",
              borderBottom: "2px solid #FF5722",
            },
          },
            selectedBiz.cover_url && h("img", {
              src: selectedBiz.cover_url,
              alt: selectedBiz.business_name,
              style: { width: "100%", height: "100%", objectFit: "cover", objectPosition: "50% 35%" },
            }),
            h("button", {
              type: "button",
              onClick: handleClosePanel,
              "aria-label": "Paneli kapat",
              style: {
                position: "absolute", top: 10, right: 10, width: 32, height: 32,
                borderRadius: 999, background: "rgba(15,23,42,0.72)", color: "#FFFFFF",
                display: "flex", alignItems: "center", justifyContent: "center", border: "none", cursor: "pointer",
              },
            }, h(XIcon, { size: 16 }))
          ),

          h("div", { className: "px-4 pt-3 space-y-4" },
            // Header
            h("div", { className: "flex items-start gap-3" },
              h(AvatarOrMonogram, {
                src: selectedBiz.logo_url || selectedBiz.avatar_url,
                name: selectedBiz.business_name || selectedBiz.name,
                size: 56,
              }),
              h("div", { className: "min-w-0 flex-1" },
                h("h3", { className: "font-extrabold text-base text-gray-900 flex items-center gap-1 flex-wrap" },
                  h("span", { className: "truncate" }, selectedBiz.business_name || selectedBiz.name),
                  selectedBiz.is_verified && h(VerifiedTick, { size: 17 })
                ),
                h("div", { className: "text-xs text-gray-500 mt-0.5" },
                  `${providerTypeLabel(selectedBiz.provider_type)} • ${[selectedBiz.district, selectedBiz.city].filter(Boolean).join(", ")}`
                ),
                h("div", { className: "mt-1.5 flex flex-wrap items-center gap-1.5 text-xs" },
                  selectedBiz.review_count > 0
                    ? h(TarakRating, { value: selectedBiz.rating, count: selectedBiz.review_count, size: 13 })
                    : h("span", { className: "text-gray-400" }, "Yeni profil"),
                  h("span", { className: "px-2 py-0.5 rounded bg-slate-100 text-slate-700 text-[10px] font-bold" },
                    workModeLabel(selectedBiz.work_mode)
                  ),
                  selectedBiz.is_verified && h("span", { className: "inline-flex items-center gap-1 px-2 py-0.5 rounded bg-emerald-50 text-emerald-700 text-[10px] font-bold" },
                    h(ShieldCheck, { size: 11 }), "Doğrulanmış"
                  )
                )
              )
            ),

            // Primary CTAs inside side panel (no direct external contact!)
            h("div", { className: "grid grid-cols-2 gap-2" },
              canBookSelected
                ? h("button", {
                    type: "button",
                    onClick: () => {
                      if (!isCustomer) { onNavigate("auth/login"); return; }
                      onNavigate("customer/create-job", {
                        mode: "scheduled",
                        providerId: String(selectedBiz.user_id),
                        locationType: selectedBiz.work_mode === "mobile" ? "mobile" : "venue",
                      });
                    },
                    className: "py-2.5 px-3 rounded-xl bg-[#FF5722] hover:bg-orange-600 text-white text-xs font-bold flex items-center justify-center gap-1.5",
                  }, h(Calendar, { size: 14 }), "Randevu Al")
                : h("div", { className: "py-2 px-2 rounded-xl bg-slate-100 text-slate-600 text-[11px] font-semibold flex items-center justify-center text-center" },
                    selectedBiz.is_demo ? "Önizleme Kaydı" : "Rehber Kaydı"
                  ),

              selectedBiz.has_public_pin && selectedBiz.can_get_directions
                ? h("button", {
                    type: "button",
                    disabled: routeBusy,
                    onClick: () => requestRoute(selectedBiz),
                    className: "py-2.5 px-3 rounded-xl bg-[#0F172A] hover:bg-slate-800 text-white text-xs font-bold flex items-center justify-center gap-1.5",
                  }, h(MapPin, { size: 14 }), routeBusy ? "Hesaplanıyor…" : "Yol Tarifi")
                : h("div", { className: "py-2 px-2 rounded-xl bg-amber-50 text-amber-800 text-[11px] font-semibold flex items-center justify-center text-center" },
                    "Özel Adres Gizli"
                  )
            ),

            h("button", {
              type: "button",
              onClick: () => onNavigate("p/detail", { id: String(selectedBiz.user_id) }),
              className: "w-full py-2 px-3 rounded-xl border border-gray-200 hover:bg-gray-50 text-xs font-bold text-gray-800",
            }, "Tam İşletme Profilini Aç →"),

            routeErr && h("div", { className: "p-2.5 rounded-xl bg-rose-50 border border-rose-200 text-xs text-rose-700" }, routeErr),

            // Section: İşletme Hakkında
            (selectedBiz.title || selectedBiz.bio) && h("div", { className: "space-y-1", "data-section": "bio" },
              h("div", { className: "text-xs font-bold text-gray-900" }, "İşletme Hakkında"),
              selectedBiz.title && h("div", { className: "text-xs font-semibold text-[#FF5722]" }, selectedBiz.title),
              selectedBiz.bio && h("p", { className: "text-xs text-gray-600 leading-relaxed whitespace-pre-line" }, selectedBiz.bio)
            ),

            // Section: Konum & Hizmet Bölgeleri
            h("div", { className: "p-3 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-700 space-y-2", "data-section": "location" },
              selectedBiz.has_public_pin && selectedBiz.formatted_address
                ? h("div", null,
                    h("strong", { className: "block text-slate-900 mb-0.5" }, "İşletme Adresi"),
                    h("span", null, selectedBiz.formatted_address)
                  )
                : h("div", { className: "text-amber-800" },
                    "Adrese gelen mobil hizmet vermektedir. Gizlilik gereği açık adres ve konum pini paylaşılmaz."
                  ),
              selectedAreas.length > 0 && h("div", { className: "flex flex-wrap gap-1 pt-1" },
                selectedAreas.map((a, i) =>
                  h("span", { key: a.id || i, className: "px-2 py-0.5 rounded-full bg-white border border-slate-200 text-[10px] font-semibold text-slate-700" },
                    [a.district, a.neighborhood, a.province].filter(Boolean).join(" · ")
                  )
                )
              )
            ),

            // Section: Çalışmalarım (Gallery)
            Array.isArray(selectedBiz.gallery) && selectedBiz.gallery.length > 0 && h("div", { "data-section": "gallery" },
              h("div", { className: "text-xs font-bold text-gray-900 mb-2" }, `Çalışmalarım (${selectedBiz.gallery.length})`),
              h("div", { style: { display: "flex", gap: 8, overflowX: "auto", paddingBottom: 4 } },
                selectedBiz.gallery.map((u, idx) =>
                  h("button", {
                    key: `${u}-${idx}`,
                    type: "button",
                    onClick: () => { setLightboxUrls(selectedBiz.gallery); setLightboxIndex(idx); },
                    style: { width: 72, height: 72, borderRadius: 10, overflow: "hidden", flexShrink: 0, border: "1px solid #E2E8F0" },
                  }, h("img", { src: u, alt: "", style: { width: "100%", height: "100%", objectFit: "cover" } }))
                )
              )
            ),

            // Section: Ustalarımız
            Array.isArray(selectedBiz.staff) && selectedBiz.staff.length > 0 && h("div", { "data-section": "staff" },
              h("div", { className: "flex items-center justify-between gap-2 mb-2" },
                h("div", { className: "text-xs font-bold text-gray-900" }, `Ustalarımız (${selectedBiz.staff.length})`),
                canBookSelected && h("button", {
                  type: "button",
                  onClick: () => {
                    if (!isCustomer) { onNavigate("auth/login"); return; }
                    onNavigate("customer/create-job", { mode: "scheduled", providerId: String(selectedBiz.user_id) });
                  },
                  className: "text-[10px] font-bold text-[#FF5722] hover:underline",
                }, "Fark Etmez — İlk Müsait Usta")
              ),
              h("div", { className: "space-y-2" },
                selectedBiz.staff.map((st) =>
                  h("div", { key: st.id, className: "p-2.5 rounded-xl border border-gray-200 flex items-center justify-between gap-2" },
                    h("div", { className: "flex items-center gap-2.5 min-w-0" },
                      h(AvatarOrMonogram, { src: st.photo_url, name: st.full_name, size: 38, rounded: "10px" }),
                      h("div", { className: "min-w-0" },
                        h("div", { className: "text-xs font-bold text-gray-900 truncate" }, st.full_name),
                        (st.title || st.specialty) && h("div", { className: "text-[11px] text-gray-500 truncate" }, st.title || st.specialty)
                      )
                    ),
                    canBookSelected && st.accepts_appointments !== false && h("button", {
                      type: "button",
                      onClick: () => {
                        if (!isCustomer) { onNavigate("auth/login"); return; }
                        onNavigate("customer/create-job", { mode: "scheduled", providerId: String(selectedBiz.user_id), staffId: String(st.id) });
                      },
                      className: "px-2.5 py-1 rounded-lg bg-orange-50 hover:bg-[#FF5722] text-[#FF5722] hover:text-white text-[11px] font-bold shrink-0",
                    }, "Seç")
                  )
                )
              )
            ),

            // Section: Hizmetler
            Array.isArray(selectedBiz.services) && selectedBiz.services.length > 0 && h("div", { "data-section": "services" },
              h("div", { className: "text-xs font-bold text-gray-900 mb-2" }, `Hizmetler (${selectedBiz.services.length})`),
              h("div", { className: "space-y-1.5" },
                selectedBiz.services.map((sv) =>
                  h("div", { key: sv.provider_service_id || sv.id, className: "flex items-center justify-between gap-2 text-xs py-1.5 border-b border-gray-100 last:border-0" },
                    h("div", { className: "min-w-0" },
                      h("div", { className: "font-medium text-gray-800 truncate" }, sv.name),
                      h("div", { className: "text-[11px] text-gray-400" }, `${sv.duration_minutes || 30} dk`)
                    ),
                    h("div", { className: "flex items-center gap-2 shrink-0" },
                      h("span", { className: "font-bold text-gray-900" }, formatMoney(sv.price)),
                      canBookSelected && h("button", {
                        type: "button",
                        onClick: () => {
                          if (!isCustomer) { onNavigate("auth/login"); return; }
                          onNavigate("customer/create-job", { mode: "scheduled", providerId: String(selectedBiz.user_id), serviceId: String(sv.service_id ?? sv.id) });
                        },
                        className: "px-2 py-0.5 rounded-md bg-orange-50 text-[#FF5722] font-bold text-[10px] hover:bg-[#FF5722] hover:text-white",
                      }, "Seç")
                    )
                  )
                )
              )
            ),

            // Section: Paketler
            selectedPackages.length > 0 && h("div", { "data-section": "packages" },
              h("div", { className: "text-xs font-bold text-gray-900 mb-2" }, `Paketler (${selectedPackages.length})`),
              h("div", { className: "space-y-2" },
                selectedPackages.map((pkg) => {
                  const pkgId = String(pkg.provider_package_id ?? pkg.id);
                  return h("div", { key: pkgId, className: "p-2.5 rounded-xl border border-gray-200 flex items-center justify-between gap-2 text-xs" },
                    h("div", { className: "min-w-0" },
                      h("div", { className: "font-bold text-gray-900 truncate" }, pkg.title),
                      h("div", { className: "text-[11px] text-gray-500" }, `${pkg.duration_minutes || 60} dk`)
                    ),
                    h("div", { className: "flex items-center gap-2 shrink-0" },
                      h("span", { className: "font-extrabold text-gray-900" }, formatMoney(pkg.price)),
                      canBookSelected && h("button", {
                        type: "button",
                        onClick: () => {
                          if (!isCustomer) { onNavigate("auth/login"); return; }
                          onNavigate("customer/create-job", { mode: "scheduled", providerId: String(selectedBiz.user_id), packageId: pkgId });
                        },
                        className: "px-2 py-0.5 rounded-md bg-orange-50 text-[#FF5722] font-bold text-[10px]",
                      }, "Al")
                    )
                  );
                })
              )
            ),

            // Section: Çalışma Saatleri
            selectedHours.length > 0 && h("div", { "data-section": "hours" },
              h("div", { className: "text-xs font-bold text-gray-900 mb-2" }, "Çalışma Saatleri"),
              h("div", { className: "space-y-1 text-[11px]" },
                selectedHours.map((day) => {
                  const isToday = day.day === todayKey;
                  return h("div", {
                    key: day.day,
                    className: `flex items-center justify-between px-2.5 py-1.5 rounded-lg border ${isToday ? "bg-orange-50/70 border-orange-200" : "bg-white border-gray-100"}`,
                  },
                    h("span", { className: "font-semibold text-gray-800" }, `${day.label}${isToday ? " (Bugün)" : ""}`),
                    h("span", { className: day.enabled ? "font-bold text-gray-900" : "text-gray-400" },
                      day.enabled ? `${day.start_time || "09:00"} – ${day.end_time || "21:00"}` : "Kapalı"
                    )
                  );
                })
              )
            ),

            // Section: Müşteri Değerlendirmeleri (TarakRatingMarks ONLY — NO yellow stars!)
            h("div", { "data-section": "reviews" },
              h("div", { className: "flex items-center justify-between mb-2" },
                h("div", { className: "text-xs font-bold text-gray-900" }, "Müşteri Değerlendirmeleri"),
                selectedBiz.review_count > 0 && h(TarakRating, { value: selectedBiz.rating, count: selectedBiz.review_count, size: 12 })
              ),
              selectedReviews.length === 0
                ? h("div", { className: "text-xs text-gray-400" }, "Henüz müşteri yorumu bulunmuyor.")
                : h("div", { className: "space-y-2.5" },
                    selectedReviews.slice(0, 5).map((rv) =>
                      h("div", { key: rv.id, className: "p-2.5 rounded-xl border border-gray-100 bg-slate-50/60 text-xs" },
                        h("div", { className: "flex items-center justify-between gap-2 mb-1" },
                          h("span", { className: "font-semibold text-gray-800 truncate" }, rv.customer_name || "Müşteri"),
                          h(TarakRatingMarks, { value: rv.rating, size: 12 })
                        ),
                        rv.comment && h("p", { className: "text-gray-600 leading-relaxed" }, rv.comment)
                      )
                    )
                  )
            )
          )
        )
      )
    ),

    // Lightbox for panel gallery
    lightboxUrls && h("div", {
      role: "dialog",
      "aria-modal": "true",
      onClick: () => setLightboxUrls(null),
      style: {
        position: "fixed", inset: 0, zIndex: 100, background: "rgba(0,0,0,0.9)",
        display: "flex", alignItems: "center", justifyContent: "center", padding: 16,
      },
    },
      h("div", { onClick: (e) => e.stopPropagation(), className: "relative max-w-3xl w-full text-center" },
        h("img", { src: lightboxUrls[lightboxIndex], alt: "", className: "mx-auto max-h-[82vh] rounded-xl object-contain" }),
        h("div", { className: "mt-2 text-xs text-white/80 font-bold" }, `${lightboxIndex + 1} / ${lightboxUrls.length}`),
        h("button", {
          type: "button",
          onClick: () => setLightboxUrls(null),
          className: "mt-3 px-4 py-1.5 rounded-lg bg-white/15 text-white text-xs font-bold",
        }, "Kapat")
      )
    )
  );
}

export default WebTarakMap;
