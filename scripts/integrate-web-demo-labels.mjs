import fs from 'node:fs';
const assets = new URL('../tarak.app/assets/', import.meta.url);
function patch(name, edits) {
  const file = new URL(name, assets);
  let source = fs.readFileSync(file, 'utf8');
  for (const [before, after] of edits) {
    if (source.includes(after)) continue;
    if (source.split(before).length !== 2) throw new Error(`${name}: ambiguous/missing demo integration: ${before.slice(0, 60)}`);
    source = source.replace(before, after);
  }
  fs.writeFileSync(file, source);
}
patch('index-Bj5sn6If.js', [
  ['or=t=>!!(t&&(t.is_verified??t.is_approved))', 'or=t=>!!(t&&!t.is_demo&&(t.is_verified??t.is_approved))'],
  ['Vs=t=>({name:', 'Vs=t=>({is_demo:!!t.is_demo,is_verified:or(t),name:'],
  ['s.jsx(qe,{size:18,className:"-mt-0.5"})', 'h.is_verified&&!h.is_demo&&s.jsx(qe,{size:18,className:"-mt-0.5"})'],
  ['children:h.role}),s.jsxs("div",{className:"pt-2', 'children:h.is_demo?`${h.role} · Demo profil`:h.role}),s.jsxs("div",{className:"pt-2'],
  ['!nearby&&s.jsxs("span",{className:"absolute top-2 left-2', '(t.is_demo||!nearby)&&s.jsxs("span",{className:"absolute top-2 left-2'],
  ['" Önerilen"]})]})', 't.is_demo?" Demo profil":" Önerilen"]})]})'],
  ['children:[s.jsx(sr,{size:10,"aria-hidden":"true"})," ",xa(l.joined_at)]', 'children:[s.jsx(sr,{size:10,"aria-hidden":"true"})," ",l.is_demo?"Demo profil":xa(l.joined_at)]'],
  ['"Platforma yeni katılan doğrulanmış berber ve kuaförler."', '"Platforma yeni katılan berber ve kuaförler."'],
  ['children:l.label}),l.desc&&', 'children:l.includes_demo?`${l.label} · Demo dahil`:l.label}),l.desc&&'],
]);
patch('CustomerDashboard-AVc8Kzdf.js', [
  ['children:"Mesleki Belgesi Doğrulandı"', 'children:s.is_demo?"Demo profil":s.is_verified?"Mesleki Belgesi Doğrulandı":"Profil bilgilerini inceleyin"'],
]);
console.log('Demo cards and statistics are explicitly labelled; real verification stays conditional.');
