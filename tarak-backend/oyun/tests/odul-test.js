// Ödül sistemi testi:  node tests/odul-test.js
'use strict';
const O = require('../../../tarak.app/oyun/assets/js/odul.js');
let hata = 0;
const bekle = (ad, kosul) => { if (!kosul) { hata++; console.log('KALDI  ' + ad); } };

const k = O.bos();
bekle('günlük ilk gün 50', O.gunlukAl(k, '2026-11-27') === 50 && k.cuzdan === 50);
bekle('aynı gün ikinci kez yok', O.gunlukAl(k, '2026-11-27') === 0);
bekle('ertesi gün seri artar', O.gunlukAl(k, '2026-11-28') === 75);
bekle('ay geçişinde seri sürer', (() => { const a = O.bos(); O.gunlukAl(a, '2026-11-30'); return O.gunlukAl(a, '2026-12-01') === 75; })());
bekle('gün atlanınca seri sıfırlanır', O.gunlukAl(k, '2026-12-05') === 50);
bekle('7. günden sonra başa döner', (() => { const a = O.bos(); let son = 0; for (let g = 1; g <= 8; g++) son = O.gunlukAl(a, '2026-12-0' + g); return son === 50; })());

const g = O.gorevleriHazirla(k, '2026-11-27').map(x => x.id);
bekle('3 farklı görev', new Set(g).size === 3);
bekle('aynı gün aynı görevler', O.gorevleriHazirla(O.bos(), '2026-11-27').map(x => x.id).join() === g.join());
const once = k.cuzdan;
const sonuc = O.kosuIsle(k, { tarak: 100000, mesafe: 100000, durak: 100, koli: 100, ziplama: 1000, kayma: 1000, kosu: 100 }, '2026-11-27');
bekle('taraklar ve seviye ödülleri cüzdana', k.cuzdan === once + 100000 + sonuc.seviyeler.reduce((t, x) => t + x.tarak, 0) && sonuc.xp > 0);
const id = k.gorevler[0].id, odul = O.gorevAl(k, id);
bekle('görev ödülü bir kez', odul > 0 && O.gorevAl(k, id) === 0);

bekle('satın alınca takılır', O.satinAl(k, 'tac') && k.takili.bas === 'tac' && k.sahip.includes('tac'));
bekle('ikinci kez alınamaz', !O.satinAl(k, 'tac'));
O.takCikar(k, 'tac'); bekle('çıkarılır', !k.takili.bas);
bekle('parasız alınamaz', !O.satinAl(O.bos(), 'tac'));
bekle('güç alınır ve harcanır', O.satinAl(k, 'kalkan') && O.gucHarca(k).kalkan === true && k.gucler.kalkan === 0);
bekle('devam ücreti', (() => { const a = O.bos(); a.cuzdan = 149; if (O.devamOde(a)) return false; a.cuzdan = 150; return O.devamOde(a) && a.cuzdan === 0; })());

const turler = new Set();
for (let i = 0; i < 3000; i++) turler.add(O.sandikAc(O.bos()).tur);
bekle('sandıktan üç tür de çıkar', turler.size === 3);
bekle('bozuk kayıt güvenli', O.duzelt({ cuzdan: -5, sahip: ['yok', 'tac'], takili: { bas: 'sapka' } }).sahip.join() === 'tac' && O.duzelt(null).cuzdan === 0);

// Seviye yolu
const s = O.bos();
bekle('başlangıç seviye 1', O.seviyeBilgi(0).seviye === 1);
bekle('200 xp seviye 2', O.seviyeBilgi(199).seviye === 1 && O.seviyeBilgi(200).seviye === 2);
const od = O.xpEkle(s, 5000);
bekle('çok seviye birden atlanır, hepsi ödül verir', od.length >= 6 && s.sahip.includes('parti') && s.sahip.includes('atki') && s.cuzdan > 0);
bekle('aynı seviye ödülü ikinci kez verilmez', O.xpEkle(s, 0).length === 0);
bekle('seviye ürünü parayla alınamaz', !O.satinAl(Object.assign(O.bos(), { cuzdan: 99999 }), 'kanat'));
bekle('her seviye ürünü ulaşılabilir', O.URUNLER.filter(u => u.seviye).every(u => O.seviyeOdulu(u.seviye).urun.id === u.id));
bekle('her ürünün tek kazanılma yolu', O.URUNLER.every(u => [u.fiyat, u.seviye, u.sezon, u.bolge].filter(Boolean).length === 1));

// Yılbaşı sezonu
const y = O.bos();
bekle('sezon 19 Kasım kapalı', O.sezonDurum(y, '2026-11-19') === null);
bekle('sezon 27 Kasım açık', O.sezonDurum(y, '2026-11-27').alindi === false);
bekle('sezon 16 Ocak kapalı', O.sezonDurum(y, '2027-01-16') === null);
bekle('hediye alınır ve giyilir', O.sezonAl(y, '2026-12-20') && y.takili.bas === 'yilbasi' && y.takili.yuz === 'nsakal');
bekle('ocakta ikinci kez verilmez', !O.sezonAl(y, '2027-01-05'));
bekle('ertesi yıl yeniden açılır', O.sezonDurum(y, '2027-12-01').alindi === false);
bekle('yılbaşı kostümü giyilebilir', O.kostumGiy(y, 'k-yilbasi') && !O.kostumGiy(y, 'k-kral'));

// Bölge sandıkları
const b = O.bos();
bekle('bölge ödülü bir kez', O.bolgeAl(b, 3).tarak === 300 && O.bolgeAl(b, 3) === null);
bekle('son bölge aslan yelesi verir', O.bolgeAl(b, 12).urun.id === 'yele' && b.sahip.includes('yele'));
bekle('olmayan bölge', O.bolgeAl(b, 4) === null);
bekle('bütün kostüm parçaları tanımlı', O.KOSTUMLER.every(c => c.parcalar.every(p => O.urun(p))));
bekle('yanlış yuvadaki takılı eşya ayıklanır', !O.duzelt({ sahip: ['tac'], takili: { yuz: 'tac' } }).takili.yuz);

console.log(hata ? `BAŞARISIZ: ${hata}` : 'TÜM ÖDÜL TESTLERİ GEÇTİ');
process.exit(hata ? 1 : 0);
