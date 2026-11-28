// tools/osm-ham/ altındaki ham OpenStreetMap verisinden her ilçe için oyun haritasını çıkarır:
// gerçek ana cadde, ona çıkan sokaklar (gerçek sırasıyla), caddenin iki yanındaki dükkânlar ve önemli yapılar.
//   node tools/osm-isle.js   ->   tarak.app/oyun/assets/veri/ilce/<plaka>.json
// Veri © OpenStreetMap katkıcıları (ODbL). Zincir markaların adı yazılmaz, yalnızca dükkân türü gösterilir.
'use strict';
const fs = require('fs');
const path = require('path');
const IL = require('../../../tarak.app/oyun/assets/js/iller.js');

const HAM = path.join(__dirname, 'osm-ham');
const CIKTI = path.join(__dirname, '..', '..', '..', 'tarak.app', 'oyun', 'assets', 'veri', 'ilce');
fs.mkdirSync(CIKTI, { recursive: true });

// Dükkân/yer türü -> oyundaki tabela türü
const TUR = {
  'shop=hairdresser': 'berber', 'craft=hairdresser': 'berber', 'shop=beauty': 'guzellik', 'shop=bakery': 'firin', 'amenity=bakery': 'firin',
  'shop=pastry': 'pastane', 'shop=confectionery': 'pastane', 'shop=supermarket': 'market', 'shop=convenience': 'market', 'shop=greengrocer': 'manav',
  'shop=butcher': 'kasap', 'shop=clothes': 'giyim', 'shop=shoes': 'ayakkabi', 'shop=jewelry': 'kuyumcu', 'craft=jeweller': 'kuyumcu',
  'shop=books': 'kitap', 'shop=stationery': 'kirtasiye', 'shop=mobile_phone': 'telefon', 'shop=electronics': 'elektronik', 'shop=florist': 'cicekci',
  'shop=optician': 'optik', 'shop=hardware': 'hirdavat', 'shop=furniture': 'mobilya', 'shop=kiosk': 'bufe', 'shop=tobacco': 'bufe', 'shop=gift': 'hediyelik',
  'shop=cosmetics': 'kozmetik', 'shop=chemist': 'kozmetik', 'shop=car_repair': 'oto', 'shop=car': 'oto', 'shop=tea': 'cay', 'shop=coffee': 'kahve',
  'craft=tailor': 'terzi', 'shop=tailor': 'terzi', 'craft=shoemaker': 'kundura',
  'amenity=pharmacy': 'eczane', 'amenity=bank': 'banka', 'amenity=cafe': 'kafe', 'amenity=restaurant': 'lokanta', 'amenity=fast_food': 'bufe',
  'amenity=ice_cream': 'dondurma', 'amenity=post_office': 'ptt', 'amenity=police': 'karakol', 'amenity=fuel': 'akaryakit', 'amenity=cinema': 'sinema',
  'amenity=theatre': 'tiyatro', 'amenity=dentist': 'dis', 'amenity=clinic': 'saglik', 'amenity=library': 'kutuphane', 'amenity=marketplace': 'pazar',
  'tourism=hotel': 'otel'
};
// Önemli yapılar (bina yerine özel model)
const SIMGE = {
  'amenity=place_of_worship': 'cami', 'leisure=park': 'park', 'leisure=playground': 'park', 'amenity=school': 'okul', 'amenity=hospital': 'hastane',
  'tourism=museum': 'muze', 'amenity=townhall': 'belediye', 'leisure=stadium': 'stadyum', 'amenity=bus_station': 'otogar',
  'historic=monument': 'anit', 'historic=memorial': 'anit', 'historic=castle': 'kale', 'historic=fort': 'kale', 'historic=tower': 'kule',
  'historic=mosque': 'cami', 'tourism=attraction': 'yapi', 'historic=building': 'yapi'
};
const YOL_PUAN = { pedestrian: 40, primary: 14, trunk: 6, secondary: 10, tertiary: 6, living_street: 4, unclassified: 1, residential: 0 };

function normal(s) { return (s || '').toLocaleLowerCase('tr-TR').replace(/\s+/g, ' ').trim(); }

function isle(ham, onerilen) {
  const els = ham.elements;
  const yollar = els.filter(e => e.type === 'way' && e.tags && e.tags.highway && e.geometry && e.tags.name);
  const noktalar = els.filter(e => !(e.type === 'way' && e.tags && e.tags.highway)).map(e => ({ lat: e.lat || (e.center && e.center.lat), lon: e.lon || (e.center && e.center.lon), t: e.tags || {} })).filter(p => p.lat);
  if (!yollar.length) return null;
  // Yerel düzlem (metre)
  let lat0 = 0, lon0 = 0, say = 0;
  yollar.forEach(w => w.geometry.forEach(g => { lat0 += g.lat; lon0 += g.lon; say++; }));
  lat0 /= say; lon0 /= say;
  const kx = Math.cos(lat0 * Math.PI / 180) * 111320, ky = 110540;
  const P = (lat, lon) => [(lon - lon0) * kx, (lat - lat0) * ky];

  // Ada göre yol grupları ve parça listesi
  const grup = new Map();
  yollar.forEach(w => {
    // "İstiklal caddesi" ile "İstiklal Caddesi" aynı yoldur: büyük/küçük harf farkı birleştirilir
    const ad = w.tags.name, ak = normal(ad), g = grup.get(ak) || { ad, parca: [], uzunluk: 0, puan: 0, noktaSay: 0, yazilis: {}, idler: [], tur: {}, yuzey: {}, serit: 0, genislik: 0, cizgiler: [] };
    const pts = w.geometry.map(q => P(q.lat, q.lon));
    let u = 0;
    for (let i = 1; i < pts.length; i++) { const a = pts[i - 1], b = pts[i]; g.parca.push([a, b]); u += Math.hypot(b[0] - a[0], b[1] - a[1]); }
    g.uzunluk += u; g.yazilis[ad] = (g.yazilis[ad] || 0) + u + 1;
    g.idler.push(w.id); g.cizgiler.push({ id: w.id, pts });
    g.tur[w.tags.highway] = (g.tur[w.tags.highway] || 0) + u;
    if (w.tags.surface) g.yuzey[w.tags.surface] = (g.yuzey[w.tags.surface] || 0) + u;
    if (+w.tags.lanes) g.serit = Math.max(g.serit, +w.tags.lanes);
    if (parseFloat(w.tags.width)) g.genislik = Math.max(g.genislik, parseFloat(w.tags.width));
    g.puan = Math.max(g.puan, YOL_PUAN[w.tags.highway] || 0);
    grup.set(ak, g);
  });
  // Caddenin gerçek boyu (kutu köşegeni): çift yönlü yollarda toplam parça uzunluğu iki katı çıkar
  grup.forEach(g => { let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity; g.parca.forEach(s => s.forEach(v => { x0 = Math.min(x0, v[0]); x1 = Math.max(x1, v[0]); y0 = Math.min(y0, v[1]); y1 = Math.max(y1, v[1]); })); g.boy = Math.hypot(x1 - x0, y1 - y0); });
  // En çok kullanılan yazılış; eşitlikte kelimeleri büyük harfle başlayan
  grup.forEach(g => { const buyuk = a => / [A-ZÇĞİÖŞÜ]/.test(a) ? 1e9 : 0; g.ad = Object.keys(g.yazilis).sort((a, b) => (g.yazilis[b] + buyuk(b)) - (g.yazilis[a] + buyuk(a)))[0]; });
  // Izgara dizini: noktaları en yakın yol parçasına atamak için
  const H = 40, izgara = new Map();
  const anahtar = (x, y) => Math.floor(x / H) + ',' + Math.floor(y / H);
  grup.forEach(g => g.parca.forEach((s, i) => {
    const minx = Math.min(s[0][0], s[1][0]), maxx = Math.max(s[0][0], s[1][0]), miny = Math.min(s[0][1], s[1][1]), maxy = Math.max(s[0][1], s[1][1]);
    for (let x = Math.floor(minx / H); x <= Math.floor(maxx / H); x++) for (let y = Math.floor(miny / H); y <= Math.floor(maxy / H); y++) {
      const k = x + ',' + y; (izgara.get(k) || izgara.set(k, []).get(k)).push([g, s]);
    }
  }));
  function enYakin(p, sinir) {
    let en = null, ed = sinir;
    const gx = Math.floor(p[0] / H), gy = Math.floor(p[1] / H);
    for (let x = gx - 1; x <= gx + 1; x++) for (let y = gy - 1; y <= gy + 1; y++) (izgara.get(x + ',' + y) || []).forEach(([g, s]) => {
      const ax = s[0][0], ay = s[0][1], bx = s[1][0] - ax, by = s[1][1] - ay, L = bx * bx + by * by || 1;
      const u = Math.max(0, Math.min(1, ((p[0] - ax) * bx + (p[1] - ay) * by) / L)), dx = ax + bx * u - p[0], dy = ay + by * u - p[1], d = Math.hypot(dx, dy);
      if (d < ed) { ed = d; en = g; }
    });
    return en;
  }
  const noktaP = noktalar.map(n => ({ n, p: P(n.lat, n.lon) }));
  noktaP.forEach(o => { const tur = turBul(o.n.t); if (!tur.dukkan) return; const g = enYakin(o.p, 30); if (g) g.noktaSay++; });

  // Ana cadde: ilçenin tanınmış caddesi varsa o; yoksa dükkânı ve önemi en yüksek, yeterince uzun cadde
  let ana = null;
  if (onerilen) { const a = normal(onerilen).replace(/ \(.*\)$/, ''); grup.forEach(g => { if (!ana && normal(g.ad) === a && g.boy >= 300) ana = g; }); }
  if (!ana) {
    // Çarşı caddesi: dükkân sayısı belirleyici; çok uzun şehirlerarası yollar dükkân yoğunluğu düşük olduğu için geride kalır
    let enIyi = -1;
    grup.forEach(g => { if (g.boy < 250) return; const yog = g.noktaSay / Math.max(1, g.uzunluk / 1000); const p = g.noktaSay * 4 + Math.min(yog, 60) + g.puan + Math.min(g.uzunluk, 1500) / 150; if (p > enIyi) { enIyi = p; ana = g; } });
    if (!ana) grup.forEach(g => { if (!ana || g.boy > ana.boy) ana = g; });
  }

  // Aynı adlı ama ilçenin başka yerindeki yolları ayır: birbirine bağlı (uçları 25 m içinde) en uzun yol grubunu al
  {
    const W = ana.cizgiler, ata = W.map((_, i) => i), bul = i => ata[i] === i ? i : (ata[i] = bul(ata[i]));
    const yakin = (a, b) => [a.pts[0], a.pts[a.pts.length - 1]].some(u => b.pts.some(v => Math.hypot(u[0] - v[0], u[1] - v[1]) < 25));
    for (let i = 0; i < W.length; i++) for (let j = i + 1; j < W.length; j++) if (bul(i) !== bul(j) && (yakin(W[i], W[j]) || yakin(W[j], W[i]))) ata[bul(i)] = bul(j);
    const boyu = {}; W.forEach((w, i) => { let u = 0; for (let k = 1; k < w.pts.length; k++) u += Math.hypot(w.pts[k][0] - w.pts[k - 1][0], w.pts[k][1] - w.pts[k - 1][1]); boyu[bul(i)] = (boyu[bul(i)] || 0) + u; });
    const enK = Object.keys(boyu).sort((a, b) => boyu[b] - boyu[a])[0];
    const sec = W.filter((_, i) => String(bul(i)) === enK);
    if (sec.length && sec.length < W.length) {
      ana.parca = []; sec.forEach(w => { for (let k = 1; k < w.pts.length; k++) ana.parca.push([w.pts[k - 1], w.pts[k]]); });
      ana.idler = sec.map(w => w.id);
    }
  }
  // Caddenin ana ekseni (PCA) üzerinde sıralama
  const vs = []; ana.parca.forEach(s => { vs.push(s[0], s[1]); });
  let mx = 0, my = 0; vs.forEach(v => { mx += v[0]; my += v[1]; }); mx /= vs.length; my /= vs.length;
  let sxx = 0, syy = 0, sxy = 0; vs.forEach(v => { const dx = v[0] - mx, dy = v[1] - my; sxx += dx * dx; syy += dy * dy; sxy += dx * dy; });
  const aci = 0.5 * Math.atan2(2 * sxy, sxx - syy), ex = Math.cos(aci), ey = Math.sin(aci);
  const proj = p => (p[0] - mx) * ex + (p[1] - my) * ey, dik = p => -(p[0] - mx) * ey + (p[1] - my) * ex;
  let tmin = Infinity, tmax = -Infinity; vs.forEach(v => { const t = proj(v); tmin = Math.min(tmin, t); tmax = Math.max(tmax, t); });
  // Çok uzun caddelerde dükkânların en yoğun olduğu 2 km'lik kesim alınır (oyundaki koşu bu kesimi gezer)
  const PENCERE = 2000;
  if (tmax - tmin > PENCERE * 1.25) {
    const ps = noktaP.filter(o => turBul(o.n.t).dukkan && anayaUzaklikHam(o.p) <= 32).map(o => proj(o.p)).sort((a, b) => a - b);
    let enI = tmin, enS = -1;
    for (let i = 0, j = 0; i < ps.length; i++) { while (ps[j] < ps[i] - PENCERE) j++; if (i - j + 1 > enS) { enS = i - j + 1; enI = ps[i] - PENCERE; } }
    tmin = Math.max(tmin, Math.min(enI, tmax - PENCERE)); tmax = tmin + PENCERE;
  }
  const L = Math.max(1, tmax - tmin), icinde = p => { const t = proj(p); return t >= tmin - 5 && t <= tmax + 5; };
  const tn = p => Math.round(Math.max(0, Math.min(1, (proj(p) - tmin) / L)) * 1000) / 1000;
  function anayaUzaklikHam(p) {
    let ed = Infinity;
    ana.parca.forEach(s => { const ax = s[0][0], ay = s[0][1], bx = s[1][0] - ax, by = s[1][1] - ay, Lq = bx * bx + by * by || 1; const u = Math.max(0, Math.min(1, ((p[0] - ax) * bx + (p[1] - ay) * by) / Lq)); ed = Math.min(ed, Math.hypot(ax + bx * u - p[0], ay + by * u - p[1])); });
    return ed;
  }
  function anayaUzaklik(p) {
    let ed = Infinity;
    ana.parca.forEach(s => { const ax = s[0][0], ay = s[0][1], bx = s[1][0] - ax, by = s[1][1] - ay, Lq = bx * bx + by * by || 1; const u = Math.max(0, Math.min(1, ((p[0] - ax) * bx + (p[1] - ay) * by) / Lq)); ed = Math.min(ed, Math.hypot(ax + bx * u - p[0], ay + by * u - p[1])); });
    return ed;
  }
  // Yanı (sol/sağ): caddenin yerel doğrultusuna göre
  function yan(p) {
    let en = null, ed = Infinity;
    ana.parca.forEach(s => { const ax = s[0][0], ay = s[0][1], bx = s[1][0] - ax, by = s[1][1] - ay, Lq = bx * bx + by * by || 1; const u = Math.max(0, Math.min(1, ((p[0] - ax) * bx + (p[1] - ay) * by) / Lq)); const d = Math.hypot(ax + bx * u - p[0], ay + by * u - p[1]); if (d < ed) { ed = d; en = s; } });
    let bx = en[1][0] - en[0][0], by = en[1][1] - en[0][1];
    if (bx * ex + by * ey < 0) { bx = -bx; by = -by; }
    return (bx * (p[1] - en[0][1]) - by * (p[0] - en[0][0])) > 0 ? -1 : 1;   // sol = -1, sağ = 1 (ilerleme yönüne göre)
  }

  // Caddedeki dükkânlar ve yapılar
  const dukkan = [], simge = [];
  noktaP.forEach(o => {
    const tur = turBul(o.n.t); if ((!tur.dukkan && !tur.simge) || !icinde(o.p)) return;
    const d = anayaUzaklik(o.p);
    if (tur.dukkan && d <= 32) {
      const zincir = !!(o.n.t.brand || o.n.t['brand:wikidata']);
      const ad = !zincir && o.n.t.name ? o.n.t.name.slice(0, 26) : '';
      dukkan.push([tn(o.p), yan(o.p), tur.dukkan, ad]);
    } else if (tur.simge && d <= 90) {
      simge.push([tn(o.p), yan(o.p), tur.simge, (o.n.t.name || '').slice(0, 30)]);
    }
  });
  // Kesişen sokaklar: başka adlı bir yol caddeye 6 m'den yakın geçiyorsa; caddenin hangi yanına açıldığı (0: iki yana)
  const sokak = new Map();
  grup.forEach(g => {
    if (g === ana) return;
    let t = null, sol = 0, sag = 0, kes = null, uzak = null;
    g.parca.forEach(s => s.forEach(v => {
      const d = anayaUzaklik(v);
      if (d < 6 && t === null && icinde(v)) { t = tn(v); kes = v; }
      else if (d > 20 && d < 150) { if (yan(v) < 0) sol++; else sag++; }
    }));
    if (t === null) return;
    // Sokağın caddeyle yaptığı gerçek açı (90 = dik; <90 ileri doğru, >90 geriye doğru sapar)
    g.parca.forEach(s => s.forEach(v => { const dd = Math.hypot(v[0] - kes[0], v[1] - kes[1]); if (dd > 18 && dd < 45 && (!uzak || Math.abs(dd - 30) < Math.abs(Math.hypot(uzak[0] - kes[0], uzak[1] - kes[1]) - 30))) uzak = v; }));
    let aci = 90;
    if (uzak) { const vx = uzak[0] - kes[0], vy = uzak[1] - kes[1], ileri = vx * ex + vy * ey, dikl = Math.abs(-vx * ey + vy * ex); aci = Math.round(Math.atan2(dikl, ileri) * 180 / Math.PI); aci = Math.max(25, Math.min(155, aci)); }
    sokak.set(g.ad, [t, sol && sag ? 0 : sol ? -1 : 1, aci]);
  });
  // Caddenin gerçek şekli: eksene göre yanal sapma, her 10 m'de bir (desimetre). Oyunda yol bu kıvrımla bükülür
  const ADIM = 10, nb = Math.max(2, Math.ceil(L / ADIM) + 1), top = new Array(nb).fill(0), say2 = new Array(nb).fill(0);
  ana.parca.forEach(s => { const n = Math.max(1, Math.ceil(Math.hypot(s[1][0] - s[0][0], s[1][1] - s[0][1]) / 2)); for (let k = 0; k <= n; k++) { const v = [s[0][0] + (s[1][0] - s[0][0]) * k / n, s[0][1] + (s[1][1] - s[0][1]) * k / n]; const tt = proj(v); if (tt < tmin - 5 || tt > tmax + 5) continue; const b = Math.max(0, Math.min(nb - 1, Math.round((tt - tmin) / ADIM))); top[b] += dik(v); say2[b]++; } });
  let sekil = top.map((x, i) => say2[i] ? x / say2[i] : null);
  for (let i = 0; i < nb; i++) if (sekil[i] === null) { let a = i - 1, b = i + 1; while (b < nb && sekil[b] === null) b++; sekil[i] = a >= 0 && b < nb ? sekil[a] + (sekil[b] - sekil[a]) * (i - a) / (b - a) : a >= 0 ? sekil[a] : b < nb ? sekil[b] : 0; }
  // Baştan sona doğru doğrultuya göre (eğim farkı kaldırılır; yalnız kıvrım kalır)
  // Yol parçalarının ortalamasından gelen küçük titreşimleri yumuşat (50 m'lik pencere, iki geçiş)
  for (let gec = 0; gec < 2; gec++) { const k = [1, 2, 3, 2, 1]; sekil = sekil.map((_, i) => { let t = 0, w = 0; for (let j = -2; j <= 2; j++) { const q = i + j; if (q < 0 || q >= nb) continue; t += sekil[q] * k[j + 2]; w += k[j + 2]; } return t / w; }); }
  const s0 = sekil[0], s1 = sekil[nb - 1]; sekil = sekil.map((x, i) => Math.round((x - s0 - (s1 - s0) * i / (nb - 1)) * 10));
  const enCok = o => Object.keys(o).sort((a, b) => o[b] - o[a])[0] || '';
  const yol = { tur: enCok(ana.tur), yuzey: enCok(ana.yuzey), serit: ana.serit, genislik: ana.genislik };
  // Sokak eşyası (osm-esya.js ile çekildiyse): çöp kutusu, bayrak, bank, ağaç, lamba, durak, çeşme…
  const esya = [];
  (ham.esya || []).forEach(e => {
    const tip = esyaTuru(e.tags || {}); if (!tip || !e.lat) return;
    const p = P(e.lat, e.lon); if (!icinde(p)) return;
    const d = anayaUzaklik(p); if (d > 30) return;
    esya.push([tn(p), yan(p), tip, Math.round(d * 10) / 10]);
  });
  (ham.ray || []).forEach(w => { if (w.tags && w.tags.railway === 'tram') yol.tramvay = 1; });
  const sirala = (a, b) => a[0] - b[0];
  // Çok kalabalık caddelerde caddenin tamamından eşit aralıkla seç (yalnız başını değil)
  const esit = (l, n) => l.length <= n ? l : l.filter((_, i) => i % Math.ceil(l.length / n) === 0);
  return {
    cadde: ana.ad, uzunluk: Math.round(L),
    dukkan: esit(dukkan.sort(sirala), 240),
    sokak: esit([...sokak.entries()].map(([ad, v]) => [v[0], v[1], ad, v[2]]).sort(sirala), 48),
    simge: esit(simge.sort(sirala), 40),
    esya: esit(esya.sort(sirala), 400),
    sekil, yol, idler: ana.idler
  };
}
function esyaTuru(t) {
  const a = t.amenity, h = t.highway, m = t.man_made;
  if (a === 'waste_basket' || a === 'waste_disposal') return 'cop';
  if (a === 'recycling') return 'geridonusum';
  if (a === 'bench') return 'bank';
  if (a === 'fountain' || a === 'drinking_water' || a === 'water_point') return 'cesme';
  if (a === 'post_box') return 'postakutusu';
  if (a === 'telephone') return 'telefon';
  if (a === 'vending_machine') return 'otomat';
  if (a === 'bicycle_parking') return 'bisiklet';
  if (a === 'clock' || t.man_made === 'clock') return 'saat';
  if (a === 'atm') return 'atm';
  if (a === 'toilets') return 'wc';
  if (h === 'street_lamp') return 'lamba';
  if (h === 'bus_stop' || t.public_transport === 'platform') return 'durak';
  if (h === 'traffic_signals') return 'isik';
  if (h === 'crossing') return 'gecit';
  if (t.natural === 'tree') return 'agac';
  if (m === 'flagpole' || t['flag:type'] || t.flag) return 'bayrak';
  if (m === 'surveillance') return 'kamera';
  if (m === 'street_cabinet') return 'kabin';
  if (t.barrier === 'bollard') return 'baba';
  if (t.tourism === 'artwork') return 'heykel';
  if (t.historic === 'memorial' || t.historic === 'monument') return 'anit';
  if (t.leisure === 'picnic_table') return 'masa';
  if (t.advertising) return 'reklam';
  return null;
}
function turBul(t) {
  let dukkan = null, simge = null;
  for (const k of ['shop', 'craft', 'amenity', 'tourism', 'historic', 'leisure']) {
    if (!t[k]) continue;
    const a = k + '=' + t[k];
    if (!dukkan && TUR[a]) dukkan = TUR[a];
    if (!simge && SIMGE[a]) simge = SIMGE[a];
    if (!dukkan && k === 'shop') dukkan = 'dukkan';
  }
  if (simge === 'cami' && t.religion && t.religion !== 'muslim') simge = 'ibadet';
  return { dukkan, simge };
}

const iller = {}, anaYollar = {};
let tamam = 0, bos = 0;
for (const f of fs.readdirSync(HAM).filter(f => /^\d\d-\d+\.json$/.test(f))) {
  const ham = JSON.parse(fs.readFileSync(path.join(HAM, f), 'utf8'));
  const ef = path.join(HAM, 'esya', f);
  if (fs.existsSync(ef)) { const e = JSON.parse(fs.readFileSync(ef, 'utf8')); ham.esya = e.esya; ham.ray = e.ray; }
  const r = IL.ROTALAR.find(x => x.plaka === ham.plaka && x.sira === ham.sira);
  const v = isle(ham, r && r.cadde);
  if (!v) { bos++; continue; }
  anaYollar[String(ham.plaka).padStart(2, '0') + '-' + ham.sira] = v.idler; delete v.idler;
  (iller[ham.plaka] = iller[ham.plaka] || {})[ham.sira] = v;
  tamam++;
}
fs.writeFileSync(path.join(HAM, 'ana-yollar.json'), JSON.stringify(anaYollar));
let boyut = 0;
for (const p in iller) { const j = JSON.stringify(iller[p]); boyut += j.length; fs.writeFileSync(path.join(CIKTI, String(p).padStart(2, '0') + '.json'), j); }
console.log(`${tamam} ilçe işlendi, ${bos} ilçede yol verisi yok; ${Object.keys(iller).length} il dosyası, toplam ${(boyut / 1024).toFixed(0)} KB`);
