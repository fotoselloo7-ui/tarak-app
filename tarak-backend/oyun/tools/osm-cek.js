// OpenStreetMap'ten (Overpass API) her ilçenin adlandırılmış yollarını ve dükkân/yer noktalarını çeker.
// Kaldığı yerden devam eder; ham veriler tools/osm-ham/ altına yazılır (depoya girmez).
//   node tools/osm-cek.js                 -> bütün iller
//   node tools/osm-cek.js 34 6 35         -> yalnızca bu plakalar
// Veri © OpenStreetMap katkıcıları, ODbL lisansı.
'use strict';
const fs = require('fs');
const path = require('path');
const IL = require('../../../tarak.app/oyun/assets/js/iller.js');

const HAM = path.join(__dirname, 'osm-ham');
fs.mkdirSync(HAM, { recursive: true });
const SUNUCULAR = ['https://overpass-api.de/api/interpreter', 'https://overpass.kumi.systems/api/interpreter'];
const uyu = ms => new Promise(r => setTimeout(r, ms));

function sorgu(il, ilce, yedek) {
  // İlçe sınırı: admin_level=6. Merkez ilçeler OSM'de çoğunlukla il adıyla ya da "Merkez" adıyla geçer.
  // Yedek sorgu (ilk sorgu boş dönerse): ad eşleşmesi gevşek, "ilçesi" ekli adlar ve 6-8 arası düzeyler
  const adlar = ilce === 'Merkez' ? [il, 'Merkez', il + ' Merkez'] : [ilce];
  const temiz = (ilce === 'Merkez' ? il : ilce).replace(/[^\p{L}\p{N} '-]/gu, '');
  const alan = yedek
    ? `area["boundary"="administrative"]["admin_level"~"^[678]$"]["name"~"^${temiz}( İlçesi| Merkez)?$",i](area.il);`
    : adlar.map(a => `area["boundary"="administrative"]["admin_level"="6"]["name"="${a}"](area.il);`).join('');
  return `[out:json][timeout:120];
area["boundary"="administrative"]["admin_level"="4"]["name"="${il}"]->.il;
(${alan})->.a;
way["highway"~"^(trunk|primary|secondary|tertiary|pedestrian|living_street|unclassified|residential)$"]["name"](area.a);
out tags geom qt;
(
  node["shop"](area.a);
  node["amenity"~"^(pharmacy|bank|cafe|restaurant|fast_food|bakery|hospital|clinic|school|place_of_worship|post_office|atm|fuel|marketplace|police|library|theatre|cinema|bus_station|townhall|ice_cream|dentist)$"](area.a);
  node["craft"~"^(hairdresser|tailor|shoemaker|jeweller)$"](area.a);
  node["tourism"~"^(museum|attraction|hotel|viewpoint)$"](area.a);
  node["historic"~"^(monument|memorial|castle|mosque|fort|tower|ruins|building)$"](area.a);
  node["leisure"~"^(park|playground|stadium)$"](area.a);
  way["leisure"="park"]["name"](area.a);
  way["amenity"="place_of_worship"]["name"](area.a);
  way["historic"]["name"](area.a);
);
out tags center qt;`;
}

async function cek(il, ilce, deneme = 0, yedek = false) {
  const sunucu = SUNUCULAR[deneme % SUNUCULAR.length];
  const r = await fetch(sunucu, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'User-Agent': 'tarak-oyun-harita/1.0 (oyun haritasi)' },
    body: 'data=' + encodeURIComponent(sorgu(il, ilce, yedek))
  });
  if (r.status === 429 || r.status === 502 || r.status === 504 || r.status === 503) {
    if (deneme > 6) throw new Error('Overpass ' + r.status);
    await uyu(15000 * (deneme + 1));
    return cek(il, ilce, deneme + 1, yedek);
  }
  if (!r.ok) throw new Error('Overpass HTTP ' + r.status);
  return r.json();
}

(async () => {
  const istenen = process.argv.slice(2).map(Number).filter(Boolean);
  // Büyük iller önce (oyuncuların çoğu oralarda oynar), sonra plaka sırası
  const ONCE = [34, 6, 35, 16, 7, 1, 42, 27, 55, 61, 21, 33, 26, 41, 10, 9, 48, 20];
  const iller = IL.ILLER.filter(il => !istenen.length || istenen.includes(il.plaka))
    .sort((a, b) => ((ONCE.indexOf(a.plaka) + 1) || 99) - ((ONCE.indexOf(b.plaka) + 1) || 99) || a.plaka - b.plaka);
  let yeni = 0, atlanan = 0, hata = 0;
  for (const il of iller) {
    for (let n = il.ilk; n <= il.son; n++) {
      const r = IL.ROTALAR[n - 1];
      const dosya = path.join(HAM, `${String(r.plaka).padStart(2, '0')}-${r.sira}.json`);
      if (fs.existsSync(dosya) && JSON.parse(fs.readFileSync(dosya, 'utf8')).elements.length) { atlanan++; continue; }
      try {
        let v = await cek(r.il, r.ilce);
        if (!v.elements.length) { await uyu(4000); v = await cek(r.il, r.ilce, 0, true); }
        const yol = v.elements.filter(e => e.type === 'way' && e.tags && e.tags.highway).length;
        const nokta = v.elements.length - yol;
        fs.writeFileSync(dosya, JSON.stringify({ il: r.il, ilce: r.ilce, plaka: r.plaka, sira: r.sira, zaman: Date.now(), elements: v.elements }));
        yeni++;
        console.log(`${r.il} / ${r.ilce}: ${yol} yol, ${nokta} nokta`);
      } catch (e) {
        hata++;
        console.log(`HATA ${r.il} / ${r.ilce}: ${e.message}`);
        await uyu(20000);
      }
      await uyu(4000);   // Overpass'i yormamak için
    }
  }
  console.log(`Bitti: ${yeni} yeni, ${atlanan} zaten vardı, ${hata} hata`);
})();
