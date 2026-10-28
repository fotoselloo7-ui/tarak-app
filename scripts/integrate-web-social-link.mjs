import fs from 'node:fs';
const assets = new URL('../tarak.app/assets/', import.meta.url);
for (const [name, marker, api] of [
  ['CustomerWebProfile-DuHSmJdA.js', 'className:"space-y-3 text-xs",children:[', 'u'],
  ['ProviderWebProfile-CsOb2E0C.js', 'className:"flex flex-col gap-2 text-xs",children:[', 'x'],
]) {
  const file = new URL(name, assets);
  let source = fs.readFileSync(file, 'utf8');
  if (source.includes('TarakSocialAccountLink')) continue;
  if (source.split(marker).length !== 2) throw new Error(`${name}: security section changed.`);
  source = 'import{SocialAccountLink as TarakSocialAccountLink}from"./AuthControls.js";\n' + source;
  source = source.replace(marker, marker + `e.jsx(TarakSocialAccountLink,{api:${api}}),`);
  fs.writeFileSync(file, source);
}
const detail = new URL('PublicProviderProfile--rPbmHay.js', assets);
let source = fs.readFileSync(detail, 'utf8');
const marker = 'children:m.business_name||m.name||"Hizmet Veren"}),Y(m)&&';
if (!source.includes('children:"Demo profil"')) {
  if (source.split(marker).length !== 2) throw new Error('Public provider header changed.');
  source = source.replace(marker, 'children:m.business_name||m.name||"Hizmet Veren"}),m.is_demo&&e.jsx("span",{className:"text-xs font-semibold text-brand-orange",children:"Demo profil"}),Y(m)&&');
  fs.writeFileSync(detail, source);
}
const customerMarker = 'children:[t.business_name,Y(t)&&';
if (source.includes(customerMarker)) {
  source = source.replace(customerMarker, 'children:[t.business_name,t.is_demo&&e.jsx("span",{className:"text-xs font-semibold text-brand-orange",children:"Demo profil"}),Y(t)&&');
  fs.writeFileSync(detail, source);
}
console.log('Existing profile security areas now support password-confirmed provider linking.');
