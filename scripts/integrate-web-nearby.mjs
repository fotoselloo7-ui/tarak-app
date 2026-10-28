import fs from 'node:fs';
const file = new URL('../tarak.app/assets/index-Bj5sn6If.js', import.meta.url);
let source = fs.readFileSync(file, 'utf8');
if (source.includes('TarakNearbyProviders')) { console.log('Nearby integration already applied.'); process.exit(0); }
function replaceOnce(from, to) {
  if (source.split(from).length !== 2) throw new Error(`Expected one integration point: ${from.slice(0, 80)}`);
  source = source.replace(from, to);
}
source = 'import{NearbyProviders as TarakNearbyProviders}from"./NearbyProviders.js";\n' + source;
replaceOnce('ga=({provider:t,onOpen:e})=>', 'ga=({provider:t,onOpen:e,nearby:nearby=!1})=>');
replaceOnce('s.jsxs("span",{className:"absolute top-2 left-2 inline-flex items-center gap-1 rounded-full bg-white/95', '!nearby&&s.jsxs("span",{className:"absolute top-2 left-2 inline-flex items-center gap-1 rounded-full bg-white/95');
replaceOnce('children:v.filter(h=>ti(a,h)).map(h=>_[h]||null)', 'children:v.filter(h=>ti(a,h)).flatMap(h=>h==="stats"&&r?.role===w.CUSTOMER?[_[h],s.jsx(TarakNearbyProviders,{api:K,onEditAddress:()=>i?.("customer/profile"),renderCard:N=>s.jsxs("div",{className:"min-w-0 grid",children:[s.jsx(ga,{provider:N,onOpen:u,nearby:!0}),s.jsxs("p",{className:"text-xs font-semibold text-brand-orange mt-2 text-center",children:[Number(N.distance_km).toLocaleString("tr-TR",{maximumFractionDigits:2})," km"]})]},N.user_id)},"nearby")]:[_[h]||null])');
fs.writeFileSync(file, source);
console.log('Customer home now reuses the existing showcase card for nearby providers.');
