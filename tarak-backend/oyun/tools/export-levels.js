// Bölüm bilgilerini sunucunun hile kontrolü için dışa aktarır:  node tools/export-levels.js
'use strict';
const fs = require('fs');
const path = require('path');
const C = require('../../../tarak.app/oyun/assets/js/core.js');

const liste = C.BOLUMLER.map(b => {
  const modlar = {};
  for (const mod of Object.keys(C.MODLAR)) {
    const d = C.bolumKur(b.id, mod);
    modlar[mod] = {
      hiz: d.hiz, uzunluk: d.uzunluk, kontrol: d.kontrol, tarak: d.toplamTarak,
      koli: d.engeller.filter(e => e.tur === 'koli').length
    };
  }
  return { id: b.id, ad: b.ad, musteri: b.musteri, dunya: C.DUNYALAR[b.dunya].ad, modlar };
});
fs.writeFileSync(path.join(__dirname, '..', '..', '..', 'tarak.app', 'oyun', 'inc', 'bolumler.json'), JSON.stringify(liste, null, 2) + '\n');
console.log(liste.length + ' bölüm yazıldı -> tarak.app/oyun/inc/bolumler.json');
const U = require('../../../tarak.app/oyun/assets/js/uc-core.js');
fs.writeFileSync(path.join(__dirname, '..', '..', '..', 'tarak.app', 'oyun', 'inc', 'rotalar.json'), JSON.stringify(U.ROTALAR.map((r, i) => ({ no: i + 1, ad: r.il + ' · ' + r.ilce, il: r.il, ilce: r.ilce, plaka: r.plaka, dunyalar: r.dunyalar, saat: r.saat, hava: r.hava }))) + '\n');
console.log(U.ROTALAR.length + ' rota yazıldı -> tarak.app/oyun/inc/rotalar.json');
