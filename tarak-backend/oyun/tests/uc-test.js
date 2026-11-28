// 3D koşunun her zaman geçilebilir olduğunu kanıtlayan bot testi:  node tests/uc-test.js
'use strict';
const U = require('../../../tarak.app/oyun/assets/js/uc-core.js');
const DT = 1 / 120;

// Bot: yaklaşan satıra bakar; her şerit için "ne yapmalıyım" maliyetini hesaplar.
function botAdim(o, durum) {
  const p = o.p, v = U.hiz(o);
  const MALIYET = { bos: 0, ust: 0, zipla: 1, kay: 1, cift: 3, turbo: 4, serit: 100 };
  const zemin = e => !!U.ENGELLER[e.tur].zemin;
  const onunde = serit => o.engeller
    .filter(e => e.serit === serit && !e.gecti && !e.kirildi && e.s + e.boy > p.s - 0.3)
    .sort((a, b) => a.s - b.s);
  if (o.jet > 0) return;
  const adaylar = [-1, 0, 1].map(serit => {
    const liste = onunde(serit), ilk = liste[0] || null;
    let e = ilk, engelli = false;
    // Rampa üstünden geçilir; otobüsün tavanındayken asıl engel sonraki (üstteki araba). Otobüsün yanına geçilmez.
    if (e && zemin(e)) {
      const ustte = p.serit === serit && p.y > 0.3;
      if (e.tur === 'rampa' || ustte) e = liste.find(x => !zemin(x)) || null;
      else engelli = true;
    }
    const uzaklik = ilk ? ilk.s - p.s : 999, eu = e ? e.s - p.s : 999;
    const hareketli = e && e.hareket;
    let m = engelli ? (uzaklik > v * 1.0 ? 0 : 100) : (!e || eu > v * 1.0 + (hareketli ? 14 : 0) ? 0 : MALIYET[U.ENGELLER[e.tur].gec]);
    return { serit, e, ilk, uzaklik, m };
  });
  const su = adaylar[p.serit + 1];
  // Yalnızca yere basarken ve yol açıkken şerit değiştir
  const hedef = adaylar
    .filter(a => {
      const yol = a.serit - p.serit;
      if (Math.abs(yol) === 2) { const orta = adaylar[1]; if (orta.ilk && orta.uzaklik < v * 0.3) return false; }
      if (p.y > 0.3) return a.serit === p.serit;   // tavandayken şerit değiştirme
      return a.serit === p.serit || !a.ilk || a.uzaklik > v * 0.28;
    })
    .sort((a, b) => a.m - b.m || (a.serit === p.serit ? -1 : b.serit === p.serit ? 1 : b.uzaklik - a.uzaklik))[0];
  if (hedef && hedef.m < su.m && p.yerde && p.kayis <= 0 && Math.abs(p.x - p.serit * U.S.serit) < 0.05) {
    U.seritDegistir(o, Math.sign(hedef.serit - p.serit));
    return;
  }
  const e = su.e;
  if (e && !durum.yapildi.has(e.id)) {
    const gec = U.ENGELLER[e.tur].gec, d = e.s - p.s;
    if (gec === 'zipla' && p.yerde && d <= v * 0.2) { U.zipla(o); durum.yapildi.add(e.id); }
    else if (gec === 'cift' && p.yerde && d <= v * 0.36) { U.zipla(o); durum.ikinci = true; durum.yapildi.add(e.id); }
    else if (gec === 'kay' && d <= v * 0.22) { U.kay(o); durum.yapildi.add(e.id); }
    else if (gec === 'turbo' && d <= v * 0.22) { U.kay(o); U.kay(o); durum.yapildi.add(e.id); }
  }
  if (durum.ikinci && !p.yerde && p.vy < 1.2 && p.zipSayisi === 1) { U.zipla(o); durum.ikinci = false; }
}

let hata = 0;
console.log('Mod   | tohum sayısı | ort. mesafe | ort. hasar | hasarsız | durak');
for (const mod of Object.keys(U.MODLAR)) {
  let mesafe = 0, hasar = 0, temiz = 0, durak = 0; const N = 40, nedenler = {};
  for (let t = 1; t <= N; t++) {
    const o = U.yeniOyun(mod, { tohum: t * 7919, rota: 1 + (t * 97) % U.ROTALAR.length, sinirsiz: true });
    o.canMax = o.can = 99;
    const d = { yapildi: new Set(), ikinci: false };
    while (o.p.s < 2000 && !o.bitti) {
      botAdim(o, d); U.adim(o, DT);
      for (const ev of o.olaylar) if (ev.tur === 'carpti') nedenler[ev.ek] = (nedenler[ev.ek] || 0) + 1;
      o.olaylar.length = 0;
    }
    mesafe += o.p.s; hasar += 99 - o.can; if (99 - o.can === 0) temiz++; durak += o.musteri;
  }
  console.log(`${mod.padEnd(5)} | ${String(N).padStart(12)} | ${(mesafe / N).toFixed(0).padStart(11)} | ${(hasar / N).toFixed(2).padStart(10)} | ${temiz}/${N} | ${(durak / N).toFixed(1)}  ${JSON.stringify(nedenler)}`);
  // Kusursuz olmayan botta bile kilometrede ortalama hasar düşük kalmalı: aksi halde geçilemeyen dizilim vardır.
  if (hasar / N > 1.5) { hata++; console.log('HATA: ' + mod + ' modunda çok fazla kaçınılamayan çarpışma'); }
}

// Tuşa basmayan oyuncu bir süre sonra kaybetmeli
for (const mod of Object.keys(U.MODLAR)) {
  const o = U.yeniOyun(mod, { tohum: 5 });
  while (!o.bitti && o.sure < 200) { U.adim(o, DT); o.olaylar.length = 0; }
  if (!o.bitti) { hata++; console.log('HATA: ' + mod + ' tuşsuz bitmiyor'); }
  else {
    const once = o.p.s;
    if (!U.devamEt(o) || o.can !== 2) { hata++; console.log('HATA: devam çalışmıyor'); }
    for (let i = 0; i < 100; i++) U.adim(o, DT);
    if (o.p.s <= once) { hata++; console.log('HATA: devam sonrası ilerlemiyor'); }
    o.bitti = true;
    if (U.devamEt(o)) { hata++; console.log('HATA: ikinci kez devam edilebiliyor'); }
  }
}
// Hareketli trafik ve orman rotası
(function () {
  const ormanNo = U.ROTALAR.findIndex(r => r.dunyalar.every(d => d === 'orman' || d === 'in')) + 1;
  const o = U.yeniOyun('orta', { tohum: 77, rota: ormanNo, sinirsiz: true });
  while (o.p.s < 1500) { o.p.dokunulmaz = 9; U.adim(o, DT); o.olaylar.length = 0; }
  const dunyalar = new Set(); for (let s = 0; s < 1500; s += 50) dunyalar.add(U.dunya(o, s));
  if ([...dunyalar].some(d => d !== 'orman' && d !== 'in')) { hata++; console.log('HATA: orman rotasında şehir var', [...dunyalar]); }
  if (!o.duraklar[0] || o.duraklar[0].ad !== 'Orman Bekçisi') { hata++; console.log('HATA: orman müşterisi yok'); }
  const s2 = U.yeniOyun('kolay', { tohum: 9, sinirsiz: true }); let ileri = 0, enAz = Infinity;
  while (s2.p.s < 900) { s2.p.dokunulmaz = 9; U.adim(s2, DT); s2.olaylar.length = 0; s2.engeller.forEach(e => { if (e.ileri) { ileri++; enAz = Math.min(enAz, e.ileri); } }); }
  if (!ileri) { hata++; console.log('HATA: hareketli trafik yok'); }
  console.log('Hareketli araç görüldü: ' + (ileri ? 'evet' : 'hayır') + ', orman rotası dünyaları: ' + [...dunyalar].join(','));
})();
// Örnek rotalar (her bölgeden, en yoğun trafik dahil) çarpmadan geçilebilmeli
(function () {
  let toplam = 0; const kotu = [];
  const ornek = U.ROTALAR.map((r, i) => [r, i]).filter(([r, i]) => i % 24 === 0 || r.trafik >= 1.7 || r.aslan);
  ornek.forEach(([r, i]) => {
    const o = U.yeniOyun('orta', { tohum: 1000 + i * 31, rota: i + 1 });
    o.canMax = o.can = 99; o.hizCarpani = r.hiz;
    const d = { yapildi: new Set(), ikinci: false };
    while (o.p.s < 1400 && !o.bitti) { botAdim(o, d); U.adim(o, DT); o.olaylar.length = 0; }
    const h = 99 - o.can; toplam += h; if (h) kotu.push(r.ad + ':' + h);
  });
  console.log(ornek.length + ' örnek rota × 1400 m, toplam çarpma: ' + toplam + (kotu.length ? ' (' + kotu.join(', ') + ')' : ''));
  if (U.ROTALAR.length !== 973 || U.ILLER.length !== 81) { hata++; console.log('HATA: rota/il sayısı ' + U.ROTALAR.length + '/' + U.ILLER.length); }
  if (toplam > 3) { hata++; console.log('HATA: rotalarda kaçınılamayan çarpışma'); }
})();
// Rampadan otobüs tavanına çıkılmalı ve üstte koşulabilmeli
(function () {
  let enYuksek = 0, konvoy = 0, ustArac = 0;
  for (let t = 1; t <= 12 && enYuksek < 2.3; t++) {
    const o = U.yeniOyun('kolay', { tohum: t * 131, sinirsiz: true }); o.canMax = o.can = 99;
    const d = { yapildi: new Set(), ikinci: false };
    while (o.p.s < 1500 && !o.bitti) {
      // rampaya doğru şeride geç
      const r = o.engeller.find(e => e.tur === 'rampa' && e.s > o.p.s + 8 && e.s < o.p.s + 40);
      if (r && o.p.yerde && o.p.y < 0.1 && o.p.serit !== r.serit) U.seritDegistir(o, Math.sign(r.serit - o.p.serit));
      else botAdim(o, d);
      U.adim(o, DT); o.olaylar.length = 0;
      if (o.p.yerde) enYuksek = Math.max(enYuksek, o.p.y);
    }
    konvoy += o.engeller.filter(e => e.tur === 'otobus').length;
    ustArac += o.engeller.filter(e => e.tur === 'aracUstu').length;
  }
  console.log('Otobüs tavanında koşuldu: ' + (enYuksek >= 2.3 ? 'evet' : 'hayır') + ' (en yüksek zemin ' + enYuksek.toFixed(2) + ' m)');
  if (enYuksek < 2.3) { hata++; console.log('HATA: otobüs tavanına çıkılamıyor'); }
})();
// Rota sonu: hedef müşteriye ulaşınca rota tamamlanır ve oyuncu durur
(function () {
  let biten = 0;
  for (const r of [1, 100, 422, 973]) {
    const o = U.yeniOyun('kolay', { tohum: 4242 + r, rota: r }); o.canMax = o.can = 99;
    const d = { yapildi: new Set(), ikinci: false };
    while (!o.bitti && o.sure < 600) { botAdim(o, d); U.adim(o, DT); o.olaylar.length = 0; }
    if (o.kazandi && o.musteri === U.rotaHedefi(r)) biten++;
    else { hata++; console.log('HATA: rota ' + r + ' bitmedi', o.musteri, o.bitti, o.kazandi); }
  }
  console.log('Rota sonu: ' + biten + '/4 rota tamamlandı (hedef müşteri: ' + [1, 100, 422, 973].map(U.rotaHedefi).join(', ') + ')');
})();
console.log(hata ? `\nBAŞARISIZ: ${hata}` : '\nTÜM 3D TESTLERİ GEÇTİ');
process.exit(hata ? 1 : 0);
