// Her ilçenin seçilen ana caddesi boyunca (30 m şerit) sokak eşyasını OpenStreetMap'ten çeker:
// çöp kutusu, geri dönüşüm, bank, çeşme, sokak lambası, durak, trafik ışığı, yaya geçidi, ağaç, bayrak direği,
// kamera, baba, heykel, anıt, posta kutusu, ATM… ve tramvay rayı. Önce `node tools/osm-isle.js` çalışmış olmalı
// (ana cadde yol kimlikleri tools/osm-ham/ana-yollar.json'da). Kaldığı yerden devam eder.
//   node tools/osm-esya.js            -> bütün işlenmiş ilçeler
//   node tools/osm-esya.js 34-0       -> yalnız bu ilçe
// Veri © OpenStreetMap katkıcıları, ODbL.
'use strict';
const fs = require('fs');
const path = require('path');

const HAM = path.join(__dirname, 'osm-ham');
const ESYA = path.join(HAM, 'esya');
fs.mkdirSync(ESYA, { recursive: true });
const SUNUCULAR = ['https://maps.mail.ru/osm/tools/overpass/api/interpreter', 'https://overpass.private.coffee/api/interpreter', 'https://overpass-api.de/api/interpreter', 'https://overpass.kumi.systems/api/interpreter'];
const uyu = ms => new Promise(r => setTimeout(r, ms));

function sorgu(idler) {
  return `[out:json][timeout:90];
way(id:${idler.join(',')})->.c;
(
  node(around.c:30)["amenity"~"^(waste_basket|waste_disposal|recycling|bench|fountain|drinking_water|water_point|post_box|telephone|vending_machine|bicycle_parking|clock|atm|toilets)$"];
  node(around.c:30)["highway"~"^(street_lamp|bus_stop|traffic_signals|crossing)$"];
  node(around.c:30)["public_transport"="platform"];
  node(around.c:30)["natural"="tree"];
  node(around.c:30)["man_made"~"^(flagpole|surveillance|street_cabinet|clock)$"];
  node(around.c:30)["flag:type"];
  node(around.c:30)["barrier"="bollard"];
  node(around.c:30)["tourism"="artwork"];
  node(around.c:30)["historic"~"^(memorial|monument)$"];
  node(around.c:30)["leisure"="picnic_table"];
  node(around.c:30)["advertising"];
);
out qt;
way(around.c:15)["railway"="tram"];
out tags qt;`;
}

async function cek(idler, deneme = 0) {
  let r;
  try {
    r = await fetch(SUNUCULAR[deneme % SUNUCULAR.length], {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'User-Agent': 'tarak-oyun-harita/1.0 (oyun haritasi)' },
      body: 'data=' + encodeURIComponent(sorgu(idler)),
      signal: AbortSignal.timeout(180000)
    });
  } catch (e) {
    // Bağlantı koptu / zaman aşımı: sıradaki sunucuyla, artan beklemeyle yeniden dene
    if (deneme > 5) throw e;
    await uyu(8000 * (deneme + 1));
    return cek(idler, deneme + 1);
  }
  if ([429, 502, 503, 504].includes(r.status)) {
    if (deneme > 6) throw new Error('Overpass ' + r.status);
    await uyu(15000 * (deneme + 1));
    return cek(idler, deneme + 1);
  }
  if (!r.ok) throw new Error('Overpass HTTP ' + r.status);
  return r.json();
}

(async () => {
  const ana = JSON.parse(fs.readFileSync(path.join(HAM, 'ana-yollar.json'), 'utf8'));
  const istenen = process.argv.slice(2);
  let yeni = 0, atlanan = 0, hata = 0;
  for (const k of Object.keys(ana)) {
    if (istenen.length && !istenen.includes(k)) continue;
    const dosya = path.join(ESYA, k + '.json');
    if (fs.existsSync(dosya) && !istenen.length) { atlanan++; continue; }
    const idler = (ana[k] || []).slice(0, 400);
    if (!idler.length) continue;
    try {
      const v = await cek(idler);
      const esya = v.elements.filter(e => e.type === 'node').map(e => ({ lat: e.lat, lon: e.lon, tags: e.tags }));
      const ray = v.elements.filter(e => e.type === 'way').map(e => ({ tags: e.tags }));
      fs.writeFileSync(dosya, JSON.stringify({ zaman: Date.now(), esya, ray }));
      yeni++;
      console.log(`${k}: ${esya.length} eşya, ${ray.length} ray`);
    } catch (e) {
      hata++; console.log(`HATA ${k}: ${e.message}`); await uyu(20000);
    }
    await uyu(3000);
  }
  console.log(`Bitti: ${yeni} yeni, ${atlanan} zaten vardı, ${hata} hata`);
})();
