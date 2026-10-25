import {r as React} from "./react-vendor-Dj04zrcb.js";

const h = React.createElement;
const field = "w-full px-3 py-2.5 border border-gray-300 rounded-lg bg-white text-sm focus:outline-none focus:ring-2 focus:ring-[#FF5722]/25 focus:border-[#FF5722]";
const label = "block text-xs font-semibold text-gray-700 mb-1.5";
const button = "inline-flex justify-center items-center gap-2 rounded-lg border border-gray-200 bg-white hover:bg-orange-50 hover:border-orange-300 text-xs font-semibold text-slate-700 px-3 py-2.5 disabled:opacity-50 disabled:cursor-not-allowed transition-colors";
const panel = "rounded-xl border border-gray-200 bg-gray-50/60 p-4 space-y-3";
let googleLoader;
let appleLoader;

function loadScript(src) {
  const found = Array.from(document.scripts).find(s => s.src === src);
  if (found && found.dataset.tarakReady === "true") return Promise.resolve();
  if (found) return new Promise((resolve, reject) => {
    found.addEventListener("load", resolve, {once:true});
    found.addEventListener("error", reject, {once:true});
  });
  return new Promise((resolve, reject) => {
    const s = document.createElement("script");
    s.src = src; s.async = true;
    s.onload = () => {s.dataset.tarakReady="true";resolve();};
    s.onerror = () => reject(new Error("Kimlik hizmetine bağlantı kurulamadı."));
    document.head.appendChild(s);
  });
}
async function jsonApi(path, body) {
  const response = await fetch("/api/auth/" + path, {
    method:"POST", headers:{"Accept":"application/json", "Content-Type":"application/json"},
    body:JSON.stringify(body), credentials:"same-origin"
  });
  const answer = await response.json().catch(() => ({}));
  if (!response.ok || answer.success === false) {
    const messages = answer.errors && typeof answer.errors === "object"
      ? Object.values(answer.errors).flat().slice(0,2).join(" ")
      : "";
    throw new Error(messages || answer.message || "İşlem tamamlanamadı. Yerel backend bağlantısını kontrol edin.");
  }
  return answer.data || {};
}
const notice = (message, good = false) => message ? h("p",{
  role:"status",className: "rounded-lg px-3 py-2 text-xs font-medium border " +
    (good ? "bg-emerald-50 border-emerald-200 text-emerald-800" :
      "bg-amber-50 border-amber-200 text-amber-900")
},message) : null;

export function SocialPrefill({onProfile}) {
  const [config,setConfig] = React.useState({});
  const [status,setStatus] = React.useState("");
  const [busy,setBusy] = React.useState(false);
  const [googleState,setGoogleState] = React.useState("idle");
  const area = React.useRef(null);
  const callback = React.useRef(onProfile);
  callback.current = onProfile;

  React.useEffect(() => {
    let active = true;
    fetch("/api/auth/registration/config",{headers:{"Accept":"application/json"}})
      .then(r=>r.json()).then(x=>{if(active)setConfig(x.data || {});})
      .catch(()=>{if(active)setConfig({});});
    return () => {active=false;};
  },[]);

  React.useEffect(() => {
    if(!config.google_client_id || !area.current) return;
    let active = true;
    (googleLoader ||= loadScript("https://accounts.google.com/gsi/client"))
      .then(() => {
        if(!active || !area.current || !window.google?.accounts?.id)return;
        setGoogleState("ready");
        area.current.replaceChildren();
        window.google.accounts.id.initialize({
          client_id: config.google_client_id,
          auto_select: false,
          callback: async result => {
            if(!active)return;
            setBusy(true);setStatus("");
            try {
              const profile = await jsonApi("social/preview",{
                provider:"google",identity_token:result.credential
              });
              if(active){callback.current(profile);setStatus("Google bilgileri forma aktarıldı. Hesap açılmadı.");}
            } catch(error){if(active)setStatus(error.message);}
            finally {if(active)setBusy(false);}
          }
        });
        window.google.accounts.id.renderButton(area.current,{
          type:"standard",theme:"outline",size:"large",text:"continue_with",
          shape:"rectangular",locale:"tr",width:280
        });
      }).catch(error=>{if(active)setStatus(error.message);});
    return () => {active=false;};
  },[config.google_client_id]);

  const apple = async () => {
    if(!config.apple_client_id){
      setStatus("Apple web bağlantısı henüz yapılandırılmadı. Manuel kayıt kullanabilirsiniz.");
      return;
    }
    setBusy(true);setStatus("");
    try {
      appleLoader ||= loadScript("https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js");
      await appleLoader;
      if(!window.AppleID?.auth)throw Error("Apple bağlantısı açılamadı.");
      window.AppleID.auth.init({
        clientId:config.apple_client_id,
        scope:"name email",
        redirectURI:config.apple_redirect_uri || location.origin + "/auth/register",
        state:self.crypto.randomUUID(),
        nonce:self.crypto.randomUUID(),
        usePopup:true
      });
      const response=await window.AppleID.auth.signIn();
      const identityToken=response?.authorization?.id_token;
      if(!identityToken)throw Error("Apple kimlik bilgisi alınamadı.");
      const user=response?.user?.name || {};
      const profile=await jsonApi("social/preview",{
        provider:"apple",identity_token:identityToken,
        first_name:user.firstName || "",last_name:user.lastName || ""
      });
      callback.current(profile);
      setStatus("Apple bilgileri forma aktarıldı. Hesap açılmadı.");
    }catch(error){
      setStatus(error?.error==="user_cancelled_authorize"?"Apple işlemi iptal edildi.":
        error?.message || "Apple ile bilgi alma işlemi tamamlanamadı.");
    }finally{setBusy(false);}
  };

  const googleIcon = h("svg",{width:20,height:20,viewBox:"0 0 24 24","aria-hidden":"true"},
    h("path",{fill:"#4285F4",d:"M21.35 12.24c0-.77-.07-1.5-.19-2.21H12v4.18h5.24a4.49 4.49 0 0 1-1.94 2.94v2.44h3.13c1.83-1.69 2.92-4.19 2.92-7.35Z"}),
    h("path",{fill:"#34A853",d:"M12 21.6c2.62 0 4.82-.86 6.43-2.31l-3.13-2.44c-.87.58-1.98.93-3.3.93-2.54 0-4.69-1.71-5.46-4H3.3v2.51A9.6 9.6 0 0 0 12 21.6Z"}),
    h("path",{fill:"#FBBC05",d:"M6.54 13.78a5.76 5.76 0 0 1 0-3.56V7.71H3.3a9.6 9.6 0 0 0 0 8.58l3.24-2.51Z"}),
    h("path",{fill:"#EA4335",d:"M12 6.22c1.43 0 2.72.49 3.73 1.47l2.8-2.8A9.14 9.14 0 0 0 12 2.4a9.6 9.6 0 0 0-8.7 5.31l3.24 2.51c.77-2.29 2.92-4 5.46-4Z"})
  );
  const appleIcon=h("svg",{viewBox:"0 0 24 24",width:19,height:19,fill:"currentColor","aria-hidden":"true"},
    h("path",{d:"M17.05 20.28c-.98.95-2.05.8-3.09.35-1.1-.46-2.1-.48-3.26 0-1.45.62-2.2.44-3.06-.35-4.91-5.03-4.18-12.69 1.64-12.96 1.4.08 2.38.78 3.2.84 1.22-.23 2.4-.9 3.7-.81 1.56.13 2.74.74 3.51 1.84-3.22 1.93-2.46 6.13.5 7.32-.6 1.56-1.38 3.1-2.75 4.76zM12.03 7.25c-.15-2.38 1.77-4.33 4.02-4.52.31 2.74-2.5 4.78-4.02 4.52z"})
  );
  const fallbackGoogle=h("button",{type:"button",className:
    "flex h-11 w-full items-center justify-center gap-2.5 px-3 rounded-xl border border-slate-200 bg-white text-slate-800 text-[13px] font-bold hover:bg-orange-50/50 hover:border-orange-200 transition-all",
    onClick:()=>setStatus("Google OAuth Web Client ID ayarlanmamış. Devam etmek için aşağıdaki alanları doldurabilir veya yerel Google kurulumunu tamamlayabilirsiniz.")},
    googleIcon,"Google ile devam et");
  return h("section",{className:"rounded-2xl border border-orange-100 bg-gradient-to-br from-orange-50/80 via-white to-slate-50 p-4 sm:p-5 shadow-sm space-y-3.5",
      "aria-label":"Google veya Apple ile kayıt bilgilerini doldur"},
    h("div",{className:"flex items-center justify-between gap-3"},
      h("div",null,
        h("div",{className:"text-[10px] tracking-[.14em] uppercase font-extrabold text-[#EE5528] mb-1"},"HIZLI KAYIT"),
        h("p",{className:"text-[15px] sm:text-base font-extrabold text-slate-900 leading-snug"},"Hesap bilgilerini tek dokunuşla getir"),
        h("p",{className:"text-[11px] sm:text-xs text-slate-500 mt-1"},"Bilgileri düzenle, e-postanı doğrula, kararını sen ver.")),
      h("span",{className:"hidden sm:flex shrink-0 items-center gap-1 px-2.5 py-1.5 rounded-full bg-white border border-emerald-100 text-[10px] text-emerald-700 font-bold"},
        "✓ Kontrol sende")
    ),
    h("div",{className:"grid grid-cols-1 sm:grid-cols-2 gap-2.5 items-center"},
      h("div",{className:"min-w-0 rounded-xl overflow-hidden",style:{minHeight:44}},
        config.google_client_id
        ? h("div",{ref:area,className:"flex items-center justify-center sm:justify-start bg-white rounded-xl min-h-[44px] overflow-hidden",style:{minWidth:0}},
            googleState==="ready" ? null : h("span",{className:"text-xs px-2 text-slate-500"},"Google hazırlanıyor..."))
        : fallbackGoogle),
      h("button",{type:"button",onClick:apple,disabled:busy,
        className:"min-h-[44px] w-full flex items-center justify-center gap-2.5 px-3 rounded-xl bg-[#15191F] text-white hover:bg-[#303743] transition-colors text-[13px] font-bold disabled:opacity-50"},
        appleIcon,"Apple ile devam et")
    ),
    h("div",{className:"flex items-center gap-3"},
      h("span",{className:"h-px bg-slate-200 flex-1"}),
      h("span",{className:"text-[10px] uppercase tracking-[.12em] font-semibold text-slate-400"},"veya bilgileri kendin gir"),
      h("span",{className:"h-px bg-slate-200 flex-1"})
    ),
    notice(status,status.includes("aktarıldı"))
  );
}
export function EmailVerification({email,onProof}) {
  const [challenge,setChallenge]=React.useState("");
  const [code,setCode]=React.useState("");
  const [done,setDone]=React.useState(false);
  const [busy,setBusy]=React.useState(false);
  const [status,setStatus]=React.useState("");
  const [lastSent,setLastSent]=React.useState(0);
  React.useEffect(()=> {
    setChallenge("");setCode("");setDone(false);setStatus("");onProof(null);
  },[email]);
  const valid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
  const send=async()=>{
    if(!valid){setStatus("Önce geçerli e-posta adresini yazın.");return;}
    if(Date.now()-lastSent < 60000){
      setStatus("Yeni kod için 60 saniye bekleyin.");return;
    }
    setBusy(true);setStatus("");
    try{
      const data=await jsonApi("registration/start",{email:email.trim()});
      setChallenge(data.challenge_id);setDone(false);setCode("");onProof(null);
      setLastSent(Date.now());setStatus("6 haneli kod gönderildi. E-postanızı kontrol edin.");
    }catch(error){setStatus(error.message);}finally{setBusy(false);}
  };
  const confirm=async()=>{
    if(!challenge || !/^\d{6}$/.test(code)){
      setStatus("Önce kod isteyin ve 6 haneli kodu girin.");return;
    }
    setBusy(true);setStatus("");
    try{
      const data=await jsonApi("registration/confirm",{
        email:email.trim(),challenge_id:challenge,code
      });
      if(!data.registration_proof)throw Error("Doğrulama kanıtı alınamadı.");
      onProof(data.registration_proof);setDone(true);
      setStatus("E-posta doğrulandı. Bilgileri kontrol ederek kaydı tamamlayabilirsiniz.");
    }catch(error){setDone(false);onProof(null);setStatus(error.message);}
    finally{setBusy(false);}
  };
  return h("section",{className:panel,"aria-label":"E-posta kodu doğrulaması"},
    h("div",{className:"flex flex-wrap justify-between items-center gap-2"},
      h("span",{className:"text-sm font-bold text-gray-900"},"E-posta doğrulaması *"),
      done?h("span",{className:"text-xs text-emerald-700 font-bold"},"✓ Doğrulandı"):null),
    h("div",{className:"grid grid-cols-1 sm:grid-cols-[auto_1fr_auto] gap-2"},
      h("button",{type:"button",className:button,onClick:send,disabled:busy||!valid},
        busy?"İşleniyor...":"Kod Gönder"),
      h("input",{type:"text",inputMode:"numeric",autoComplete:"one-time-code",
        maxLength:6,placeholder:"6 haneli kod",className:field,value:code,
        onChange:e=>setCode(e.target.value.replace(/\D/g,"")),"aria-label":"E-posta kodu"}),
      h("button",{type:"button",className:button,onClick:confirm,
        disabled:busy||!challenge||done||code.length!==6},"Doğrula")),
    notice(status,done),
    h("p",{className:"text-[11px] text-gray-500"},
      "Kod 10 dakika geçerlidir. Kod doğrulanmadan hesap açılmaz.")
  );
}

export function PhoneVerification({phone,onProof}) {
  const [open,setOpen]=React.useState(false);
  const [challenge,setChallenge]=React.useState("");
  const [code,setCode]=React.useState("");
  const [done,setDone]=React.useState(false);
  const [busy,setBusy]=React.useState(false);
  const [status,setStatus]=React.useState("");
  const [lastSent,setLastSent]=React.useState(0);
  React.useEffect(()=>{setChallenge("");setCode("");setDone(false);onProof(null);},[phone]);
  const send=async()=>{
    if(!phone || phone.replace(/\D/g,"").length<10){setStatus("Geçerli cep telefonu girin.");return;}
    if(Date.now()-lastSent<60000){setStatus("Yeni kod için 60 saniye bekleyin.");return;}
    setBusy(true);setStatus("");
    try{
      const data=await jsonApi("registration/sms/start",{phone:phone.trim()});
      setChallenge(data.challenge_id);setLastSent(Date.now());setCode("");setDone(false);
      setStatus("Telefonunuza SMS gönderildi.");
    }catch(error){setStatus(error.message);}finally{setBusy(false);}
  };
  const confirm=async()=>{
    setBusy(true);setStatus("");
    try{
      const data=await jsonApi("registration/sms/confirm",{
        phone:phone.trim(),challenge_id:challenge,code
      });
      if(!data.sms_proof)throw Error("SMS kanıtı alınamadı.");
      onProof(data.sms_proof);setDone(true);setStatus("Telefon doğrulandı.");
    }catch(error){onProof(null);setStatus(error.message);}finally{setBusy(false);}
  };
  return h("div",{className:"rounded-xl border border-gray-200 p-3.5"},
    h("button",{type:"button",className:"w-full flex items-center justify-between text-xs font-semibold text-gray-700",
      onClick:()=>setOpen(x=>!x)},
      "Telefon doğrulaması (isteğe bağlı)",h("span",null,done?"✓":open?"−":"+")),
    open?h("div",{className:"mt-3 space-y-2"},
      h("div",{className:"flex flex-wrap gap-2"},
        h("button",{type:"button",className:button,onClick:send,disabled:busy||!phone},"SMS gönder"),
        h("input",{value:code,maxLength:6,inputMode:"numeric",placeholder:"SMS kodu",
          onChange:e=>setCode(e.target.value.replace(/\D/g,"")),
          className:field+" flex-1 min-w-[110px]","aria-label":"SMS doğrulama kodu"}),
        h("button",{type:"button",className:button,onClick:confirm,
          disabled:busy||!challenge||done||code.length!==6},"Doğrula")),
      notice(status,done),
      h("p",{className:"text-[11px] text-gray-500"},"SMS sağlayıcısı etkin değilse e-posta doğrulamasıyla devam edebilirsiniz.")
    ):null
  );
}

export function AddressFields({value,onChange,role}) {
  const [config,setConfig]=React.useState({});
  const [busy,setBusy]=React.useState(false);
  const [status,setStatus]=React.useState("");
  const mapRef=React.useRef(null);
  const mapObject=React.useRef(null);
  const marker=React.useRef(null);
  const geo=React.useRef(null);
  React.useEffect(()=>{
    let active=true;
    fetch("/api/auth/registration/config",{headers:{"Accept":"application/json"}})
      .then(r=>r.json()).then(x=>{if(active)setConfig(x.data||{});}).catch(()=>{});
    return()=>{active=false;};
  },[]);
  const latest=React.useRef(value);latest.current=value;
  const change=(key,next)=>{
    const v={...latest.current,[key]:next};
    // A previous pin no longer proves a changed physical address.
    if(["province","district","neighborhood","street","building_no"].includes(key)){
      delete v.latitude;delete v.longitude;
      if(marker.current)marker.current.setMap(null);
      marker.current=null;
      setStatus("Adres değişti. Haritadaki pini yeniden doğrulayın.");
    }
    onChange(v);
  };
  const script=async()=>{
    const key=config.maps_browser_api_key;
    if(!key){setStatus("Google Harita henüz yapılandırılmadı. Adres metnini yine kaydedebilirsiniz.");return false;}
    if(!window.google?.maps){
      await loadScript("https://maps.googleapis.com/maps/api/js?key="+encodeURIComponent(key));
    }
    return !!window.google?.maps;
  };
  const putPin=(point,google)=>{
    if(marker.current)marker.current.setMap(null);
    marker.current=new google.maps.Marker({map:mapObject.current,position:point,draggable:true});
    const update=coord=>{
      onChange({...latest.current,latitude:coord.lat(),longitude:coord.lng()});
      setStatus("Konum seçildi. Pinin bina girişinde olduğunu kontrol edin.");
    };
    marker.current.addListener("dragend",ev=>update(ev.latLng));
    update(point);
  };
  const locate=async()=>{
    if(!value.province?.trim()||!value.district?.trim()){
      setStatus("Önce il ve ilçeyi girin.");return;
    }
    setBusy(true);setStatus("");
    try{
      if(!(await script()))return;
      const google=window.google;
      mapRef.current.style.display="block";
      if(!mapObject.current){
        mapObject.current=new google.maps.Map(mapRef.current,{
          center:{lat:39,lng:35},zoom:5,streetViewControl:false,mapTypeControl:false
        });
        mapObject.current.addListener("click",ev=>putPin(ev.latLng,google));
        geo.current=new google.maps.Geocoder();
      }
      const address=[value.street,value.neighborhood,value.district,value.province,"Türkiye"]
        .filter(Boolean).join(", ");
      const results=await new Promise((resolve,reject)=>
        geo.current.geocode({address},(x,status)=>
          status==="OK"&&x?.length?resolve(x):reject(Error("Adres bulunamadı. Haritadan pin seçin."))));
      const point=results[0].geometry.location;
      mapObject.current.setCenter(point);mapObject.current.setZoom(17);putPin(point,google);
    }catch(error){setStatus(error.message || "Harita yüklenemedi.");}
    finally{setBusy(false);}
  };
  const inputs=[
    ["province","İl *"],["district","İlçe *"],["neighborhood","Mahalle / Köy"],
    ["street","Cadde / Sokak"],["building_no","Bina No"],["apartment_no","Daire No"]
  ];
  return h("section",{className:panel,"aria-label":"Adres ve harita seçimi"},
    h("div",null,h("p",{className:"font-bold text-sm text-gray-900"},
      role==="PROVIDER"?"İşletme / Salon Adresi *":"Hizmet Adresiniz *"),
      h("p",{className:"text-xs text-gray-500 mt-1"},
        "Adres bilgilerinizi yazın; harita etkinse pini binanın girişine yerleştirin.")),
    h("div",{className:"grid grid-cols-1 sm:grid-cols-2 gap-x-3"},
      ...inputs.map(([key,name])=>h("div",{key,className:"mb-2"},
        h("label",{className:label,htmlFor:"tarak-address-"+key},name),
        h("input",{id:"tarak-address-"+key,value:value[key]||"",className:field,
          onChange:ev=>change(key,ev.target.value),maxLength:150,
          required:key==="province"||key==="district"})))),
    h("div",null,
      h("label",{className:label,htmlFor:"tarak-address-directions"},"Adres Tarifi"),
      h("textarea",{id:"tarak-address-directions",className:field,minRows:2,rows:2,
        value:value.directions||"",maxLength:500,
        onChange:ev=>change("directions",ev.target.value)})),
    h("div",{className:"flex flex-wrap gap-2 items-center"},
      h("button",{type:"button",className:button,disabled:busy,onClick:locate},
        busy?"Haritada aranıyor...":"Yazdığım adresi haritada bul"),
      value.latitude != null && value.longitude != null
        ? h("span",{className:"text-xs text-emerald-700 font-semibold"},"✓ Harita pini belirlendi")
        : h("span",{className:"text-xs text-gray-500"},"Konum pini seçilmedi")),
    h("div",{ref:mapRef,style:{display:"none",height:"260px",borderRadius:"12px"},
      "aria-label":"İşaretlenebilir Google haritası"}),
    notice(status,!!value.latitude)
  );
}

export function ConsentFields({terms,onTerms,privacy,onPrivacy,marketing,onMarketing}) {
  const checkbox=(key,checked,set,copy,href)=>
    h("label",{key,className:"flex items-start gap-2 text-xs text-gray-600 leading-relaxed cursor-pointer"},
      h("input",{type:"checkbox",checked,onChange:ev=>set(ev.target.checked),
        className:"mt-0.5 w-4 h-4 accent-[#FF5722] shrink-0"}),
      h("span",null,copy," ",
        href?h("a",{href, target:"_blank",rel:"noopener noreferrer",
          onClick:ev=>ev.stopPropagation(),className:"text-[#FF5722] underline"},"Metni oku ↗"):null));
  return h("section",{className:"border-t border-gray-100 pt-4 space-y-3"},
    h("p",{className:"text-sm font-semibold text-gray-800"},"Onaylar"),
    checkbox("terms",terms,onTerms,"Kullanım Koşullarını kabul ediyorum. *","/legal/terms"),
    checkbox("privacy",privacy,onPrivacy,"KVKK Aydınlatma Metnini okudum. *","/legal/privacy"),
    checkbox("marketing",marketing,onMarketing,"Kampanya ve tanıtım iletilerini almak istiyorum (isteğe bağlı).")
  );
}
