import {j as jsx,r as React} from "./react-vendor-Dj04zrcb.js";

// Customer-only home section. Uses saved pins, never invents coordinates,
// and requests device position only after a user gesture.
export default function NearbyProviders({onNavigate}) {
  const [radius, setRadius] = React.useState(10);
  const [origin, setOrigin] = React.useState(null);
  const [addresses, setAddresses] = React.useState([]);
  const [items, setItems] = React.useState([]);
  const [loading, setLoading] = React.useState(false);
  const [message, setMessage] = React.useState("");
  const [source, setSource] = React.useState("saved");

  const token = () => {
    try { return localStorage.getItem("berberim_auth_token"); }
    catch (_) { return null; }
  };
  const authHeaders = () => {
    const value = token();
    return value ? {Authorization: "Bearer " + value} : {};
  };
  const coords = (a) => {
    const lat = Number(a?.latitude), lng = Number(a?.longitude);
    return Number.isFinite(lat) && Number.isFinite(lng) &&
      Math.abs(lat) <= 90 && Math.abs(lng) <= 180 &&
      a?.latitude != null && a?.longitude != null ? {lat, lng} : null;
  };

  React.useEffect(() => {
    let live = true;
    fetch("/api/customer/addresses", {headers: authHeaders()})
      .then(r => { if (!r.ok) throw new Error("Adresler alınamadı."); return r.json(); })
      .then(json => {
        if (!live) return;
        const list = Array.isArray(json.data) ? json.data : [];
        const pinned = list.filter(a => coords(a));
        setAddresses(pinned);
        const selected = pinned.find(a => a.is_default) || pinned[0];
        if (selected) setOrigin({...coords(selected), title: selected.title || "Kayıtlı adres"});
      })
      .catch(() => { if (live) setMessage("Adresler yüklenemedi. Profilinizden kontrol edin."); });
    return () => { live = false; };
  }, []);

  React.useEffect(() => {
    if (!origin) { setItems([]); return; }
    let active = true;
    const abort = new AbortController();
    const timer = setTimeout(async () => {
      setLoading(true);
      setMessage("");
      try {
        const qs = new URLSearchParams({
          lat: String(origin.lat), lng: String(origin.lng),
          max_distance_km: String(radius), sort: "distance",
          per_page: "12"
        });
        const response = await fetch("/api/providers?" + qs.toString(), {signal: abort.signal});
        if (!response.ok) throw new Error("Yakındaki uzmanlar alınamadı.");
        const result = await response.json();
        if (active) setItems(Array.isArray(result.data) ? result.data : []);
      } catch (err) {
        if (active && err.name !== "AbortError") {
          setMessage("Yakındaki uzmanlar alınamadı. Lütfen tekrar deneyin.");
          setItems([]);
        }
      } finally { if (active) setLoading(false); }
    }, 220);
    return () => { active = false; clearTimeout(timer); abort.abort(); };
  }, [origin?.lat, origin?.lng, radius]);

  const locate = () => {
    if (!navigator.geolocation) {
      setMessage("Tarayıcınız konum paylaşımını desteklemiyor."); return;
    }
    setMessage("Konum izniniz isteniyor...");
    navigator.geolocation.getCurrentPosition(
      p => {
        setSource("device");
        setOrigin({lat: p.coords.latitude, lng: p.coords.longitude, title: "Cihaz konumum"});
        setMessage("");
      },
      () => setMessage("Konuma erişilemedi. Kayıtlı adresinizden devam edebilirsiniz."),
      {enableHighAccuracy: false, timeout: 10000, maximumAge: 60000}
    );
  };

  const card = p => jsx.jsxs("article", {
    className: "min-w-[245px] max-w-[270px] snap-start bg-white rounded-2xl border border-slate-200 p-4 shadow-sm hover:shadow-md transition-shadow",
    children: [
      jsx.jsxs("div", {className: "flex items-center gap-3", children: [
        jsx.jsx("img", {
          src: p.avatar_url || "/brand/tarak-logo-header.png",
          alt: "", loading: "lazy",
          className: "w-12 h-12 object-cover rounded-xl border border-slate-100"
        }),
        jsx.jsxs("div", {className: "min-w-0 flex-1", children: [
          jsx.jsx("h4", {className: "text-sm font-extrabold truncate text-slate-900", children: p.business_name || p.name || "Hizmet Veren"}),
          jsx.jsx("p", {className: "text-xs text-slate-500", children: p.provider_type === "coiffeur" ? "Kuaför" : "Berber"})
        ]})
      ]}),
      jsx.jsxs("p", {className:"text-xs text-slate-600 mt-3 truncate",children:[
        p.district || "", p.city ? ", " + p.city : ""
      ]}),
      jsx.jsxs("div", {className:"flex items-center justify-between gap-2 mt-2 text-xs font-semibold",children:[
        jsx.jsx("span",{className:"text-brand-orange",children:
          typeof p.distance_km === "number" ? p.distance_km.toFixed(1) + " km uzaklıkta" : "Mesafe yok"}),
        jsx.jsx("span",{className:"text-slate-600",children:
          p.rating == null ? "Yeni uzman" : "★ " + Number(p.rating).toFixed(1)})
      ]}),
      jsx.jsx("button", {
        type:"button",
        className:"w-full mt-4 py-2.5 rounded-xl bg-[#FF5429] hover:bg-[#EA481F] text-white text-xs font-bold",
        onClick:()=>onNavigate("p/detail",{id:p.user_id}),
        children:"Profili Gör"
      })
    ]
  },String(p.user_id));

  return jsx.jsxs("section",{
    className:"bg-[#F8FAFC] border border-slate-200 rounded-3xl p-4 sm:p-6",
    "aria-label":"Size Yakın Berberler",
    children:[
      jsx.jsxs("div",{className:"flex flex-wrap items-start justify-between gap-3",children:[
        jsx.jsxs("div",{children:[
          jsx.jsx("h3",{className:"text-lg sm:text-xl font-extrabold text-slate-900",children:"Size Yakın Berberler"}),
          jsx.jsx("p",{className:"text-xs text-slate-500 mt-1",children:"Kayıtlı konumlara göre, gerçek kilometre mesafesiyle."})
        ]}),
        jsx.jsx("button",{type:"button",onClick:()=>onNavigate("customer",{tab:"profile"}),
          className:"text-xs font-bold text-[#FF5429]",children:"Adreslerim"})
      ]}),
      jsx.jsxs("div",{className:"mt-4 grid gap-2",children:[
        jsx.jsxs("label",{htmlFor:"tarak-nearby-radius",className:"flex items-center justify-between text-sm font-semibold",children:[
          "Arama mesafesi",jsx.jsx("strong",{className:"text-[#FF5429]",children: radius + " km"})
        ]}),
        jsx.jsx("input",{
          type:"range",id:"tarak-nearby-radius",min:1,max:50,step:1,value:radius,
          onChange:event=>setRadius(Number(event.target.value)),
          className:"w-full accent-[#FF5429] cursor-pointer"
        }),
        jsx.jsxs("div",{className:"flex items-center gap-2 flex-wrap mt-2",children:[
          addresses.length > 0 && jsx.jsxs("select",{
            "aria-label":"Mesafe için adres", value:source === "device" ? "device" : (origin?.addressId || "saved"),
            onChange:event=>{
              const a=addresses.find(v=>String(v.id)===event.target.value);
              if(a){setSource("saved");setOrigin({...coords(a),addressId:String(a.id),title:a.title || "Kayıtlı adres"});}
            },
            className:"px-3 py-2 rounded-xl border border-slate-200 bg-white text-xs max-w-full",
            children:[
              ...(source === "device" ? [jsx.jsx("option",{value:"device",children:"Cihaz konumum"})] : []),
              ...addresses.map(a=>jsx.jsx("option",{value:String(a.id),children:a.title || a.district || "Adres"},String(a.id)))
            ]
          }),
          jsx.jsx("button",{type:"button",onClick:locate,
            className:"px-3 py-2 rounded-xl border border-slate-200 bg-white text-xs font-bold text-slate-800",
            children:"Konumumu kullan"})
        ]})
      ]}),
      message && jsx.jsx("p",{role:"status",className:"text-xs text-slate-500 mt-2",children:message}),
      !origin
        ? jsx.jsx("p",{className:"text-sm text-slate-600 mt-4",children:"Yakındaki uzmanları görmek için profilinizde konum pini olan bir adres seçin veya Konumumu kullan düğmesine basın."})
        : loading
          ? jsx.jsx("p",{className:"text-sm text-slate-500 mt-4",children:"Yakındaki berberler aranıyor..."})
          : items.length
            ? jsx.jsx("div",{className:"flex gap-3 overflow-x-auto snap-x snap-mandatory py-4",children:items.map(card)})
            : jsx.jsx("p",{className:"text-sm text-slate-500 mt-4",children:"Bu mesafede konumu kayıtlı uzman bulunamadı."})
    ]
  });
}
