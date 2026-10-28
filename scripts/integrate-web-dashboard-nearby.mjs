import fs from 'node:fs';
const base = new URL('../tarak.app/assets/', import.meta.url);
const mainFile = new URL('index-Bj5sn6If.js', base);
let main = fs.readFileSync(mainFile, 'utf8');
main = main.replace('onEditAddress:()=>i?.("customer/profile")', 'onEditAddress:()=>i?.("profile")');
if (!main.includes('ga as ShowcaseProviderCard')) {
  const exportEnd = main.lastIndexOf('};');
  if (exportEnd < 0) throw new Error('Main export not found.');
  main = main.slice(0, exportEnd) + ',ga as ShowcaseProviderCard' + main.slice(exportEnd);
}
fs.writeFileSync(mainFile, main);
const file = new URL('CustomerDashboard-AVc8Kzdf.js', base);
let source = fs.readFileSync(file, 'utf8');
if (source.includes('TarakNearbyProviders')) { console.log('Dashboard nearby already integrated.'); process.exit(0); }
source = 'import{NearbyProviders as TarakNearbyProviders}from"./NearbyProviders.js";import{ShowcaseProviderCard as TarakShowcaseCard}from"./index-Bj5sn6If.js";\n' + source;
const marker = 'e.jsx(Lt,{embedded:!0,onOpenProvider:s=>x("p/detail",{id:s})})';
if (source.split(marker).length !== 2) throw new Error('Customer home integration point changed.');
source = source.replace(marker, marker + ',e.jsx(TarakNearbyProviders,{api:V,embedded:!0,onEditAddress:()=>c("addresses"),renderCard:s=>e.jsxs("div",{className:"min-w-0 grid",children:[e.jsx(TarakShowcaseCard,{provider:s,onOpen:a=>x("p/detail",{id:a}),nearby:!0}),e.jsxs("p",{className:"text-xs font-semibold text-brand-orange mt-2 text-center",children:[Number(s.distance_km).toLocaleString("tr-TR",{maximumFractionDigits:2})," km"]})]},s.user_id)})');
source = source.replace('"Yakınındaki Profesyoneller"', '"Onaylı Profesyoneller"');
fs.writeFileSync(file, source);
console.log('Customer dashboard nearby section integrated with the same showcase card.');
