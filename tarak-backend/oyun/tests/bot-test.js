// Her bölümün hasarsız bitirilebildiğini kanıtlayan bot testi:  node tests/bot-test.js
'use strict';
const C = require('../../../tarak.app/oyun/assets/js/core.js');
const DT = 1 / 120;

// tepki: botun tuşa basma noktasına eklenen sapma (saniye). Zamanlama toleransını ölçer.
function oyna(secim, tepki, sinirSure, mod) {
  const o = C.yeniOyun(secim, mod);
  const yapildi = new Set();
  let ikinci = false;
  while (!o.bitti && o.sure < sinirSure) {
    const p = o.p, v = C.hiz(o);
    const adaylar = [
      ...o.dunya.engeller.filter(e => !e.gecti && !e.kirildi).map(e => ({ e, tur: e.tur, x: e.x, w: e.w })),
      ...o.dunya.cukurlar.map(c => ({ e: c, tur: c.w > v * 0.6 ? 'buyukCukur' : 'cukur', x: c.x, w: c.w }))
    ].filter(a => !yapildi.has(a.e) && a.x + a.w > p.x - 10).sort((a, b) => a.x - b.x);
    const a = adaylar[0];
    if (a) {
      const mesafe = a.x - (p.x + C.S.genislik / 2) + tepki * v;
      const yap = () => yapildi.add(a.e);
      if ((a.tur === 'kutu' || a.tur === 'genis' || a.tur === 'koli') && p.yerde && mesafe <= v * (a.tur === 'genis' ? 0.13 : 0.17)) { C.zipla(o); yap(); }
      else if (a.tur === 'lastik' && p.yerde && mesafe <= v * 0.24) { C.zipla(o); yap(); }
      else if (a.tur === 'yuksek' && p.yerde && mesafe <= v * 0.38) { C.zipla(o); ikinci = true; yap(); }
      else if (a.tur === 'tabela' && p.yerde && mesafe <= v * 0.14) { C.kay(o); yap(); }
      else if (a.tur === 'tunel' && p.yerde && mesafe <= v * 0.18) { C.kay(o); C.kay(o); yap(); }
      else if ((a.tur === 'cukur' || a.tur === 'buyukCukur') && p.yerde && a.x - p.x + tepki * v <= v * 0.05) {
        C.zipla(o); if (a.tur === 'buyukCukur') ikinci = true; yap();
      }
    }
    if (ikinci && !p.yerde && p.vy < 60 && p.zipSayisi === 1) { C.zipla(o); ikinci = false; }
    C.adim(o, DT);
    o.olaylar.length = 0;
  }
  return o;
}

let hata = 0;
const SAPMA = [-0.08, -0.05, -0.03, 0, 0.03, 0.05, 0.08];
const toplamTolerans = {};
for (const mod of Object.keys(C.MODLAR)) {
  console.log(`\n== ${C.MODLAR[mod].ad.toUpperCase()} ==`);
  console.log('Bölüm | süre  | tarak     | hasar | kusursuz geçilen zamanlama sapmaları (sn)');
  toplamTolerans[mod] = 0;
  for (const b of C.BOLUMLER) {
    const o = oyna(b.id, 0, 200, mod);
    const sapmalar = SAPMA.filter(t => { const r = oyna(b.id, t, 200, mod); return r.kazandi && r.hasar === 0; });
    toplamTolerans[mod] += sapmalar.length;
    console.log(`${String(b.id).padStart(5)} | ${o.sure.toFixed(1).padStart(5)} | ${String(o.tarak).padStart(3)}/${String(o.dunya.toplamTarak).padEnd(5)} | ${String(o.hasar).padStart(5)} | ${sapmalar.join(', ')}`);
    if (!o.kazandi || o.hasar > 0) { hata++; console.log(`   HATA: ${mod} bölüm ${b.id} kusursuz bitirilemedi (son neden: ${o.sonNeden}, x=${o.p.x.toFixed(0)})`); }
    // Hiç tuşa basmayan oyuncu mutlaka kaybetmeli.
    const bos = C.yeniOyun(b.id, mod);
    while (!bos.bitti && bos.sure < 200) { C.adim(bos, DT); bos.olaylar.length = 0; }
    if (bos.kazandi) { hata++; console.log(`HATA: ${mod} bölüm ${b.id} tuşsuz bitiyor`); }
  }
}
console.log('\nZamanlama toleransı (yüksek = affedici):', toplamTolerans);
if (!(toplamTolerans.kolay >= toplamTolerans.zor)) { hata++; console.log('HATA: Kolay mod Zor moddan daha affedici değil'); }

// Yarı yoldan devam: Kolay/Orta'da var, Zor'da yok; devam eden koşu 3 yıldız alamaz.
for (const mod of Object.keys(C.MODLAR)) {
  const o = C.yeniOyun(6, mod);
  o.p.x = o.dunya.kontrol - 5; o.p.dokunulmaz = 1;
  o.tarak = 20; C.adim(o, 0.05);
  const y = C.kontroldenDevam(o);
  if (mod === 'zor') { if (y) { hata++; console.log('HATA: zor modda devam olmamalı'); } continue; }
  if (!y || y.tarak !== o.kontrolKaydi.tarak || y.can !== y.canMax || Math.abs(y.p.x - o.kontrolKaydi.x) > 1) { hata++; console.log('HATA: devam bozuk', mod); continue; }
  while (!y.bitti && y.sure < 200) { y.p.dokunulmaz = 1; if (y.p.dusuyor) y.p.y = -200; if (y.p.yerde && y.dunya.cukurlar.some(c => c.x - y.p.x < 12 && c.x - y.p.x > 0)) C.zipla(y); C.adim(y, DT); y.olaylar.length = 0; }
  if (!y.kazandi || C.yildiz(y) > 2) { hata++; console.log('HATA: devam sonrası bitiş/yıldız', mod, y.kazandi, C.yildiz(y)); }
}

// Tek kayış uzun tünele yetmemeli, turbo yetmeli.
for (const mod of Object.keys(C.MODLAR)) (function () {
  function tunelDene(cift) {
    const o = C.yeniOyun(5, mod);
    const t = o.dunya.engeller.find(e => e.tur === 'tunel');
    o.p.x = t.x - 70;
    C.kay(o); if (cift) C.kay(o);
    while (o.p.x < t.x + t.w + 60) C.adim(o, DT);
    return o.hasar;
  }
  const tek = tunelDene(false), cift = tunelDene(true);
  console.log(`Tünel (${mod}): tek kayış hasar=${tek}, turbo hasar=${cift}`);
  if (tek !== 1 || cift !== 0) { hata++; console.log('HATA: tünel kuralı bozuk'); }
})();

const s = oyna('sonsuz', 0, 90, 'zor');
console.log(`Sonsuz mod: ${s.sure.toFixed(0)} sn, mesafe ${(s.p.x / 20).toFixed(0)} m, hasar ${s.hasar}`);

console.log(hata ? `\nBAŞARISIZ: ${hata} hata` : '\nTÜM TESTLER GEÇTİ');
process.exit(hata ? 1 : 0);
