/* Randevuya Koş karakterleri. Koko ve Kiki Tarak maskotu (K); diğerleri tam vücutlu, özgün karakterler (uc-insan.js).
 * Hepsi aynı iskeleti kullandığı için bütün kıyafet ve kostümler hepsine giyer.
 * Kişiliği şekil dili anlatır: huysuz = çatık kaş, yarı kapalı göz, somurtma, kambur duruş;
 * kötü = sivri V kaş, kısık parlayan göz, sinsi gülüş, öne eğik duruş; zarif = ince kemer kaş, kapalı sakin göz, dik duruş;
 * güzel/karizmatik = iri parlak göz, yaylanan adım; neşeli = mutlu kapalı göz, kocaman gülüş.
 * ozellik: 3D koşuya küçük başlangıç avantajı (kalkan | miknatis | ikikat | can). */
(function (root) {
  'use strict';
  var KARAKTERLER = [
    // ---------- Maskotlar ----------
    { id: 'koko', tur: 'maskot', ad: 'Koko', cins: 'e', kisilik: 'Neşeli', unvan: 'Tarak maskotu', fiyat: 0, ozellik: null, soz: 'Hadi, randevuya geç kalmayalım!' },
    { id: 'kiki', tur: 'maskot', ad: 'Kiki', cins: 'k', kisilik: 'Neşeli', unvan: 'Tarak maskotu', fiyat: 0, ozellik: null, soz: 'Manikür, fön, makyaj: hepsi bende!' },
    // ---------- Erkek (berber) ----------
    { id: 'emir', tur: 'insan', ad: 'Çırak Emir', cins: 'e', kisilik: 'Neşeli', unvan: 'Neşeli çırak berber', fiyat: 300, ozellik: null,
      yuz: 'neseli', durus: 'neseli', ten: '#f2c19b', sac: 'kisa', sacRenk: '#3b2314', ust: '#e94e3c', alt: '#2b3a55', onluk: true, onlukRenk: '#ffffff', ayakkabi: '#ffffff', taban: '#ffbf0a',
      soz: 'Usta, ben de geliyorum!' },
    { id: 'husnu', tur: 'insan', ad: 'Hüsnü Usta', cins: 'e', kisilik: 'Huysuz', unvan: 'Huysuz yaşlı usta', fiyat: 600, ozellik: 'kalkan',
      yuz: 'huysuz', durus: 'huysuz', ten: '#e9b48e', sac: 'kel', sacRenk: '#c9c9c9', kasRenk: '#d9d9d9', biyik: 'gri', biyikRenk: '#d0d0d0', gobek: true,
      ust: '#8a5a3a', alt: '#4a4f5a', hirka: true, yakaRenk: '#6b432a', uzunKol: true, ayakkabi: '#5a3a24', taban: '#2a1a10',
      soz: 'Hıh! Bu yolları kim yaptı böyle?' },
    { id: 'kemal', tur: 'insan', ad: 'Kara Kemal', cins: 'e', kisilik: 'Kötü', unvan: 'Sinsi rakip berber', fiyat: 1200, ozellik: 'miknatis',
      yuz: 'kotu', durus: 'kotu', ten: '#d9b08c', sac: 'geri', sacRenk: '#111111', biyik: 'burma', sakal: 'keci', biyikRenk: '#111111', gozIsik: '#ff3b3b',
      ust: '#1f2027', alt: '#15161b', ceket: true, yakaRenk: '#0c0c10', gomlek: '#3a0d14', kravat: '#e53935', uzunKol: true, ayakkabi: '#111111', taban: '#e53935',
      soz: 'Muhahaha! Bütün taraklar benim!' },
    { id: 'selim', tur: 'insan', ad: 'Selim Bey', cins: 'e', kisilik: 'Zarif', unvan: 'Centilmen berber', fiyat: 900, ozellik: 'ikikat',
      yuz: 'zarif', durus: 'zarif', ten: '#f0c6a0', sac: 'yan', sacRenk: '#1a1a1a', biyik: 'ince', monokl: true,
      ust: '#2f4a8c', alt: '#24365f', ceket: true, yakaRenk: '#1c2c55', gomlek: '#ffffff', kravat: '#e8c45a', uzunKol: true, ayakkabi: '#3a2416', taban: '#1a1008',
      soz: 'Efendim, tıraş vaktiniz geldi.' },
    { id: 'yagiz', tur: 'insan', ad: 'Yakışıklı Yağız', cins: 'e', kisilik: 'Karizmatik', unvan: 'Stil ikonu', fiyat: 1500, ozellik: 'can',
      yuz: 'guzel', tekKas: true, durus: 'guzel', ten: '#c99671', sac: 'percem', sacRenk: '#2b1608', iris: '#5a3a1a',
      ust: '#2b2b2b', alt: '#3a5a8c', mont: true, yakaRenk: '#1a1a1a', uzunKol: true, ayakkabi: '#ffffff', taban: '#17b3b0',
      soz: 'Saçım hep yerinde, randevu da!' },
    // ---------- Kadın (kuaför) ----------
    { id: 'defne', tur: 'insan', ad: 'Defne', cins: 'k', kisilik: 'Neşeli', unvan: 'Neşeli kuaför', fiyat: 300, ozellik: null,
      yuz: 'neseli', durus: 'neseli', allik: true, ten: '#f5c9a6', sac: 'atKuyrugu', sacRenk: '#6b3a1e', tokaRenk: '#ff3d8b',
      ust: '#ff7eb3', alt: '#7a4fa0', onluk: true, onlukRenk: '#ffe1ee', ruj: '#e0457b', ayakkabi: '#ffffff', taban: '#ff7eb3',
      soz: 'Fön makinesi hazır, koşuyorum!' },
    { id: 'hulya', tur: 'insan', ad: 'Hülya Hanım', cins: 'k', kisilik: 'Huysuz', unvan: 'Huysuz kuaför', fiyat: 600, ozellik: 'kalkan',
      yuz: 'huysuz', durus: 'huysuz', ten: '#eebc98', sac: 'topuz', bigudi: true, sacRenk: '#7a5240', kasRenk: '#5a3a2a',
      ust: '#9c88c9', alt: '#5a4a7a', hirka: true, yakaRenk: '#7a68a8', uzunKol: true, etek: 'uzun', etekRenk: '#5a4a7a', ruj: '#9a3a5a', ayakkabi: '#5a4a7a', taban: '#2a2238',
      soz: 'Ay, yine mi sıra var! Tamam, koşuyorum…' },
    { id: 'leyla', tur: 'insan', ad: 'Kara Leyla', cins: 'k', kisilik: 'Kötü', unvan: 'Gölge kuaför', fiyat: 1200, ozellik: 'miknatis',
      yuz: 'kotu', durus: 'kotu', ten: '#e6c2a8', sac: 'uzun', tutam: true, sacRenk: '#141016', tutamRenk: '#ff2d6f', gozIsik: '#c64dff',
      ust: '#3a1f4d', alt: '#22122e', etek: 'uzun', etekRenk: '#22122e', ruj: '#d1002f', uzunKol: true, ayakkabi: '#141016', taban: '#ff2d6f',
      soz: 'Taraklar bana, sıra sana!' },
    { id: 'lale', tur: 'insan', ad: 'Leydi Lale', cins: 'k', kisilik: 'Zarif', unvan: 'Zarif kuaför', fiyat: 900, ozellik: 'ikikat',
      yuz: 'zarif', durus: 'zarif', allik: true, ten: '#f6d2b8', sac: 'topuz', inciToka: true, sacRenk: '#3b2416',
      ust: '#f1dfbf', alt: '#d9c29a', etek: 'uzun', etekRenk: '#e8d3ad', ruj: '#c2185b', ayakkabi: '#b8862b', taban: '#6a4a14',
      soz: 'Zarafet acele etmez, ama geç de kalmaz.' },
    { id: 'ayla', tur: 'insan', ad: 'Prenses Ayla', cins: 'k', kisilik: 'Güzel', unvan: 'Masal kuaförü', fiyat: 1500, ozellik: 'can',
      yuz: 'guzel', durus: 'guzel', allik: true, ten: '#f7d6bf', sac: 'dalgali', sacRenk: '#d8952e', cicekToka: true, iris: '#2bb3a5',
      ust: '#62d2c4', alt: '#3fa89b', etek: 'kisa', etekRenk: '#62d2c4', ruj: '#ff5c8a', ayakkabi: '#ffffff', taban: '#62d2c4', corap: '#fff1f5',
      soz: 'Her randevu bir masal!' }
  ];
  var OZELLIK = {
    kalkan: '🛡️ Koşuya kalkanla başlar',
    miknatis: '🧲 Koşuya tarak çekiciyle başlar',
    ikikat: '✨ İlk 12 saniye çift kazanç',
    can: '💖 1 fazla canla başlar'
  };
  function bul(id) { for (var i = 0; i < KARAKTERLER.length; i++) if (KARAKTERLER[i].id === id) return KARAKTERLER[i]; return KARAKTERLER[0]; }
  var api = { LISTE: KARAKTERLER, OZELLIK: OZELLIK, bul: bul };
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.TarakKarakterler = api;
})(typeof self !== 'undefined' ? self : this);
