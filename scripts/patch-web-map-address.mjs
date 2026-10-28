// Asserted, repeatable bridge for the delivered Vite chunks. The original React
// source is absent from this release package; carry these edits into source when
// it becomes available, then remove this patch script.
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..', 'tarak.app', 'assets');
const file = name => resolve(root, name);

function replaceOnce(source, before, after, label) {
  const first = source.indexOf(before);
  if (first < 0 || source.indexOf(before, first + before.length) >= 0) {
    throw new Error(`${label}: expected exactly one original anchor`);
  }
  return source.slice(0, first) + after + source.slice(first + before.length);
}

function patch(name, transform) {
  const path = file(name);
  const source = readFileSync(path, 'utf8');
  if (source.includes('MapAddressPicker.js')) {
    console.log(`${name}: already patched`);
    return;
  }
  const result = transform(source);
  if (result === source || !result.includes('MapAddressPicker.js')) throw new Error(`${name}: no map integration`);
  writeFileSync(path, result, 'utf8');
  console.log(`${name}: patched`);
}

patch('ProfileCreate-Dp8rE1RG.js', source => {
  let s = replaceOnce(source,
    'import{r as s,j as e}from"./react-vendor-Dj04zrcb.js";',
    'import{r as s,j as e}from"./react-vendor-Dj04zrcb.js";import{MapAddressPicker}from"./MapAddressPicker.js";',
    'registration import');
  s = replaceOnce(s,
    'address_detail:K.trim(),bio:',
    'address_detail:K.trim(),neighborhood:E||null,street:A||null,building_no:C||null,latitude:we,longitude:Se,bio:',
    'provider location save');

  const providerAddress = s.indexOf('children:"Salon Açık Adresi / Çalışma Merkezi *"');
  if (providerAddress < 0) throw new Error('provider address label missing');
  const required = 'required:!0})';
  const buttonAt = s.indexOf(required, providerAddress);
  if (buttonAt < 0 || buttonAt - providerAddress > 1000) throw new Error('provider address input missing');
  const insertAt = buttonAt + required.length;
  s = s.slice(0, insertAt) + ',e.jsx("button",{type:"button",onClick:()=>Y(!0),className:"mt-2 text-xs font-bold text-brand-orange underline",children:"Haritadan Seç"})' + s.slice(insertAt);

  const geolocationStart = s.indexOf('navigator.geolocation.getCurrentPosition(t=>{');
  const geolocationEnd = s.indexOf('},t=>{oe(!1)', geolocationStart);
  if (geolocationStart < 0 || geolocationEnd < 0) throw new Error('current-location callback missing');
  s = s.slice(0, geolocationStart) + 'navigator.geolocation.getCurrentPosition(async t=>{const lat=t.coords.latitude,lng=t.coords.longitude;tt(lat),at(lng);try{const response=await fetch(`/api/geo/reverse?lat=${encodeURIComponent(lat)}&lng=${encodeURIComponent(lng)}`),body=await response.json();if(body.success&&body.data){const a=body.data;a.province&&ze(a.province),a.district&&le(a.district),a.neighborhood&&ne(a.neighborhood),a.street&&Qe(a.street),a.building_no&&Xe(a.building_no),n&&a.formatted_address&&De(a.formatted_address)}}catch{}oe(!1),H({type:"success",text:"Konum alındı. Adres alanlarını kontrol edip eksikleri düzenleyin."})' + s.slice(geolocationEnd);

  const modalStart = s.indexOf('rt&&e.jsx(Bt,{className:"fixed inset-0  bg-black/50');
  const modalEnd = s.indexOf(']})};export{qt as default};', modalStart);
  if (modalStart < 0 || modalEnd < 0) throw new Error('placeholder map modal missing');
  const modal = 'rt&&e.jsx(MapAddressPicker,{onClose:()=>Y(!1),initialLatitude:we,initialLongitude:Se,initialQuery:n?K:[A,E,x,c].filter(Boolean).join(" "),onSelect:a=>{const province=a.province||c,district=a.district||x;ze(province),ke(re.find(t=>t.name===province)?.districts||[{id:"geocoded",name:district}]),le(district),ie(a.neighborhood?[{id:"geocoded",name:a.neighborhood}]:[]),ne(a.neighborhood||""),Qe(a.street||""),Xe(a.building_no||""),n&&De(a.formatted_address||[a.street,a.building_no,a.neighborhood,district,province].filter(Boolean).join(" ")),tt(a.latitude),at(a.longitude),H({type:"success",text:"Haritadan seçilen adres dolduruldu. Lütfen alanları kontrol edin."})}})';
  return s.slice(0, modalStart) + modal + s.slice(modalEnd);
});

patch('MyProfile-BIpUeyuq.js', source => {
  let s = replaceOnce(source,
    'import{a as ys}from"./LocationFields-CwjRJiSe.js";',
    'import{a as ys}from"./LocationFields-CwjRJiSe.js";import{MapAddressPicker}from"./MapAddressPicker.js";',
    'provider settings import');
  s = replaceOnce(s,
    'city:t.city||"",district:t.district||"",address_detail:t.address_detail||""}),[D,S]',
    'city:t.city||"",district:t.district||"",neighborhood:t.neighborhood||"",street:t.street||"",building_no:t.building_no||"",address_detail:t.address_detail||"",latitude:t.latitude??null,longitude:t.longitude??null}),[mapPicker,setMapPicker]=n.useState(!1),[D,S]',
    'provider settings state');
  s = replaceOnce(s,
    'city:t.city||"",district:t.district||"",address_detail:t.address_detail||"",name:u?.name||""',
    'city:t.city||"",district:t.district||"",neighborhood:t.neighborhood||"",street:t.street||"",building_no:t.building_no||"",address_detail:t.address_detail||"",latitude:t.latitude??null,longitude:t.longitude??null,name:u?.name||""',
    'provider settings refresh');
  s = replaceOnce(s,
    'city:i.city,district:i.district,address_detail:i.address_detail}),await c.updateUser',
    'city:i.city,district:i.district,neighborhood:i.neighborhood,street:i.street,building_no:i.building_no,address_detail:i.address_detail,latitude:i.latitude,longitude:i.longitude}),await c.updateUser',
    'provider settings save');
  s = replaceOnce(s,
    'value:{province:i.city,district:i.district,neighborhood:""},onChange:s=>f({...i,city:s.province,district:s.district})',
    'value:{province:i.city,district:i.district,neighborhood:i.neighborhood},showNeighborhood:!0,onChange:s=>f({...i,city:s.province,district:s.district,neighborhood:s.neighborhood})',
    'provider settings location fields');
  const addressLabel = 'e.jsx(z,{label:"Açık Adres",value:i.address_detail,onChange:s=>f({...i,address_detail:s.target.value}),placeholder:"Mahalle, Cadde, No..."})';
  s = replaceOnce(s, addressLabel, addressLabel + ',e.jsx("button",{type:"button",onClick:()=>setMapPicker(!0),className:"mb-4 text-xs font-semibold text-brand-orange underline",children:"Haritadan Seç"})', 'provider settings map button');
  s = replaceOnce(s,
    'max-w-4xl mx-auto space-y-6 pb-20",children:[e.jsxs("div",{className:"relative bg-white',
    'max-w-4xl mx-auto space-y-6 pb-20",children:[mapPicker&&e.jsx(MapAddressPicker,{onClose:()=>setMapPicker(!1),initialLatitude:i.latitude,initialLongitude:i.longitude,initialQuery:i.address_detail||[i.street,i.neighborhood,i.district,i.city].filter(Boolean).join(" "),onSelect:a=>f(v=>({...v,city:a.province||v.city,district:a.district||v.district,neighborhood:a.neighborhood||"",street:a.street||"",building_no:a.building_no||"",address_detail:a.formatted_address||v.address_detail,latitude:a.latitude,longitude:a.longitude}))}),e.jsxs("div",{className:"relative bg-white',
    'provider settings map dialog');
  return s;
});

patch('CustomerWebProfile-DuHSmJdA.js', source => {
  let s = replaceOnce(source,
    'import{A as Oe,S as Ns,D as ys,a as Re}from"./LocationFields-CwjRJiSe.js";',
    'import{A as Oe,S as Ns,D as ys,a as Re}from"./LocationFields-CwjRJiSe.js";import{MapAddressPicker}from"./MapAddressPicker.js";',
    'customer profile import');
  s = replaceOnce(s,
    'building_no:"",apartment_no:""},[i,q]=l.useState(We),j=s=>',
    'building_no:"",apartment_no:"",latitude:null,longitude:null},[i,q]=l.useState(We),[mapPicker,setMapPicker]=l.useState(null),[newGeo,setNewGeo]=l.useState(null),j=s=>',
    'customer profile state');
  s = replaceOnce(s,
    'building_no:s?.building_no||"",apartment_no:s?.apartment_no||""}),z(!0)',
    'building_no:s?.building_no||"",apartment_no:s?.apartment_no||"",latitude:s?.latitude??null,longitude:s?.longitude??null}),z(!0)',
    'customer profile edit state');
  s = replaceOnce(s,
    'latitude:y?.latitude??null,longitude:y?.longitude??null}}const v=',
    'latitude:i.latitude??null,longitude:i.longitude??null}}const v=',
    'customer profile edit coordinates');
  s = replaceOnce(s,
    'street:L,is_default:U.length===0});if(!t.success',
    'street:L,building_no:newGeo?.building_no||null,apartment_no:newGeo?.apartment_no||null,latitude:newGeo?.latitude??null,longitude:newGeo?.longitude??null,is_default:U.length===0});if(!t.success',
    'customer new address coordinates');
  s = replaceOnce(s,
    '_e(""),c("Yeni adresiniz başarıyla kaydedildi.")',
    '_e(""),setNewGeo(null),c("Yeni adresiniz başarıyla kaydedildi.")',
    'customer new address reset');
  s = replaceOnce(s,
    'onChange:s=>q(t=>({...t,...s})),showNeighborhood:!0,labelClassName:h,selectClassName:p})}),e.jsxs("div",{className:"sm:col-span-2",children:[e.jsx("label",{htmlFor:"edit-street"',
    'onChange:s=>q(t=>({...t,...s})),showNeighborhood:!0,labelClassName:h,selectClassName:p})}),e.jsx("button",{type:"button",onClick:()=>setMapPicker("edit"),className:"sm:col-span-2 text-left text-xs font-semibold text-[#FF5722] underline",children:"Haritadan Seç"}),e.jsxs("div",{className:"sm:col-span-2",children:[e.jsx("label",{htmlFor:"edit-street"',
    'customer edit map button');
  s = replaceOnce(s,
    'showNeighborhood:!0,required:!0}),e.jsxs("div",{children:[e.jsx("label",{htmlFor:"field-customerwebprofile-9"',
    'showNeighborhood:!0,required:!0}),e.jsx("button",{type:"button",onClick:()=>setMapPicker("new"),className:"text-xs font-semibold text-[#FF5722] underline",children:"Haritadan Seç"}),e.jsxs("div",{children:[e.jsx("label",{htmlFor:"field-customerwebprofile-9"',
    'customer new address map button');
  s = replaceOnce(s,
    'rows:3,className:"w-full px-3.5 py-2 rounded-xl border border-slate-300 text-sm focus:ring-2 focus:ring-[#FF5722] focus:border-[#FF5722] outline-none"})]}),e.jsxs("div",{className:"flex justify-end',
    'rows:3,className:"w-full px-3.5 py-2 rounded-xl border border-slate-300 text-sm focus:ring-2 focus:ring-[#FF5722] focus:border-[#FF5722] outline-none"})]}),e.jsx("input",{type:"text",value:newGeo?.building_no||"",onChange:s=>setNewGeo(a=>({...a,building_no:s.target.value})),placeholder:"Bina No (isteğe bağlı)",className:p}),e.jsxs("div",{className:"flex justify-end',
    'customer new address editable building number');
  s = replaceOnce(s,
    'className:"profile-page",children:[ze&&e.jsxs(ms,',
    'className:"profile-page",children:[mapPicker&&e.jsx(MapAddressPicker,{onClose:()=>setMapPicker(null),initialLatitude:mapPicker==="edit"?i.latitude:newGeo?.latitude,initialLongitude:mapPicker==="edit"?i.longitude:newGeo?.longitude,initialQuery:mapPicker==="edit"?[i.street,i.neighborhood,i.district,i.province].filter(Boolean).join(" "):[L,W,T,P].filter(Boolean).join(" "),onSelect:a=>{mapPicker==="edit"?q(v=>({...v,province:a.province||v.province,district:a.district||v.district,neighborhood:a.neighborhood||"",street:a.street||"",building_no:a.building_no||"",latitude:a.latitude,longitude:a.longitude})):(ls(a.province||P),we(a.district||T),ke(a.neighborhood||W),_e(a.street||a.formatted_address||L),setNewGeo(a))}}),ze&&e.jsxs(ms,',
    'customer profile map dialog');
  return s;
});

function enhance(name, marker, transform) {
  const path = file(name);
  const source = readFileSync(path, 'utf8');
  if (source.includes(marker)) return;
  const result = transform(source);
  if (result === source || !result.includes(marker)) throw new Error(`${name}: supplemental address fields missing`);
  writeFileSync(path, result, 'utf8');
  console.log(`${name}: structured provider fields patched`);
}

enhance('ProfileCreate-Dp8rE1RG.js', 'label:"Mahalle (isteğe bağlı)"', source => {
  let s = replaceOnce(source,
    'r.address_detail&&!K&&De(r.address_detail),r.bio&&!me',
    'r.address_detail&&!K&&De(r.address_detail),r.neighborhood&&ne(r.neighborhood),r.street&&Qe(r.street),r.building_no&&Xe(r.building_no),r.latitude!=null&&tt(r.latitude),r.longitude!=null&&at(r.longitude),r.bio&&!me',
    'provider registration location restore');
  const button = 'e.jsx("button",{type:"button",onClick:()=>Y(!0),className:"mt-2 text-xs font-bold text-brand-orange underline",children:"Haritadan Seç"})';
  s = replaceOnce(s, button, button + ',e.jsxs("div",{className:"grid grid-cols-1 sm:grid-cols-3 gap-3 mt-3",children:[e.jsx(h,{label:"Mahalle (isteğe bağlı)",value:E,onChange:t=>ne(t.target.value)}),e.jsx(h,{label:"Cadde / Sokak",value:A,onChange:t=>Qe(t.target.value)}),e.jsx(h,{label:"Bina No",value:C,onChange:t=>Xe(t.target.value)})]})', 'provider registration structured fields');
  return s;
});

enhance('MyProfile-BIpUeyuq.js', 'label:"Mahalle",value:i.neighborhood', source => {
  const button = 'e.jsx("button",{type:"button",onClick:()=>setMapPicker(!0),className:"mb-4 text-xs font-semibold text-brand-orange underline",children:"Haritadan Seç"})';
  return replaceOnce(source, button,
    button + ',e.jsxs("div",{className:"grid grid-cols-1 sm:grid-cols-3 gap-3",children:[e.jsx(z,{label:"Mahalle",value:i.neighborhood,onChange:s=>f({...i,neighborhood:s.target.value})}),e.jsx(z,{label:"Cadde / Sokak",value:i.street,onChange:s=>f({...i,street:s.target.value})}),e.jsx(z,{label:"Bina No",value:i.building_no,onChange:s=>f({...i,building_no:s.target.value})})]})',
    'provider settings structured fields');
});

enhance('ProfileCreate-Dp8rE1RG.js', 'ke(re.find(t=>t.name===a.province)', source => replaceOnce(source,
  'a.province&&ze(a.province),a.district&&le(a.district),a.neighborhood&&ne(a.neighborhood),a.street&&Qe(a.street)',
  'a.province&&(ze(a.province),ke(re.find(t=>t.name===a.province)?.districts||[])),a.district&&le(a.district),a.neighborhood&&(ie([{id:"geocoded",name:a.neighborhood}]),ne(a.neighborhood)),a.street&&Qe(a.street)',
  'current location address dropdowns'));
