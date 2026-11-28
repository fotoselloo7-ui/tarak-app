/* Ödül sistemi: tarak cüzdanı, günlük ödül, görevler, sandık ve aksesuar mağazası. DOM'suz.
 * Tüm ödüller oyun içidir; gerçek para ya da indirim içermez. */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.TarakOdul = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var GUNLUK = [50, 75, 100, 150, 200, 275, 500];

  /* Her ürünün tek bir kazanılma yolu vardır:
   *   fiyat   -> tarakla satın alınır
   *   seviye  -> oyuncu seviyesi atlayınca hediye
   *   sezon   -> kutlama döneminde hediye
   *   bolge   -> 2D haritadaki bölge sandığından */
  var URUNLER = [
    { id: 'yilbasi',  yuva: 'bas',      ad: 'Yılbaşı Şapkası',  simge: '🎅', sezon: 'yilbasi' },
    { id: 'parti',    yuva: 'bas',      ad: 'Parti Şapkası',    simge: '🥳', seviye: 2 },
    { id: 'kulaklik', yuva: 'bas',      ad: 'Kulaklık',         simge: '🎧', seviye: 4 },
    { id: 'kovboy',   yuva: 'bas',      ad: 'Kovboy Şapkası',   simge: '🤠', seviye: 6 },
    { id: 'silindir', yuva: 'bas',      ad: 'Sihirbaz Şapkası', simge: '🎩', seviye: 9 },
    { id: 'yele',     yuva: 'bas',      ad: 'Aslan Yelesi',     simge: '🦁', bolge: 12 },
    { id: 'sapka',    yuva: 'bas',      ad: 'Berber Kepi',      simge: '💈', fiyat: 300 },
    { id: 'kasket',   yuva: 'bas',      ad: 'Ters Kasket',      simge: '🧢', fiyat: 500 },
    { id: 'tac',      yuva: 'bas',      ad: 'Kral Tacı',        simge: '👑', fiyat: 2500 },
    { id: 'nsakal',   yuva: 'yuz',      ad: 'Beyaz Sakal',      simge: '🎅', sezon: 'yilbasi' },
    { id: 'biyik',    yuva: 'yuz',      ad: 'Usta Bıyığı',      simge: '👨', fiyat: 400 },
    { id: 'gozluk',   yuva: 'yuz',      ad: 'Güneş Gözlüğü',    simge: '🕶️', fiyat: 650 },
    { id: 'ylatki',   yuva: 'boyun',    ad: 'Yılbaşı Atkısı',   simge: '🧣', sezon: 'yilbasi' },
    { id: 'atki',     yuva: 'boyun',    ad: 'Sarı Atkı',        simge: '🧣', seviye: 3 },
    { id: 'papyon',   yuva: 'boyun',    ad: 'Papyon',           simge: '🎀', fiyat: 250 },
    { id: 'canta',    yuva: 'sirt',     ad: 'Berber Çantası',   simge: '🎒', seviye: 5 },
    { id: 'pelerin',  yuva: 'sirt',     ad: 'Kahraman Pelerini', simge: '🦸', seviye: 7 },
    { id: 'balon',    yuva: 'sirt',     ad: 'Kutlama Balonları', simge: '🎈', seviye: 8 },
    { id: 'kanat',    yuva: 'sirt',     ad: 'Melek Kanatları',  simge: '🪽', seviye: 12 },
    { id: 'kirmizi',  yuva: 'ayakkabi', ad: 'Kırmızı Tabanlar', simge: '👟', fiyat: 450 },
    { id: 'neon',     yuva: 'ayakkabi', ad: 'Neon Tabanlar',    simge: '⚡', fiyat: 900 },
    { id: 'altin',    yuva: 'eldiven',  ad: 'Altın Eldiven',    simge: '🧤', fiyat: 1800 },
    { id: 'fiyonk',   yuva: 'bas',      ad: 'Pembe Fiyonk',     simge: '🎀', fiyat: 350 },
    { id: 'cicektac', yuva: 'bas',      ad: 'Çiçek Tacı',       simge: '🌸', fiyat: 700 },
    { id: 'kedigoz',  yuva: 'yuz',      ad: 'Kedi Gözlük',      simge: '😺', fiyat: 650 },
    { id: 'inci',     yuva: 'boyun',    ad: 'İnci Kolye',       simge: '📿', fiyat: 600 },
    { id: 'pembe',    yuva: 'ayakkabi', ad: 'Pembe Tabanlar',   simge: '💗', fiyat: 450 }
  ];

  var YUVALAR = [['bas', 'Şapkalar'], ['yuz', 'Yüz'], ['boyun', 'Boyun'], ['sirt', 'Sırt'], ['ayakkabi', 'Ayakkabı'], ['eldiven', 'Eldiven']];

  // Hazır kostümler: parçaların hepsi sahipse tek dokunuşla giyilir.
  var KOSTUMLER = [
    { id: 'k-yilbasi', ad: 'Yılbaşı',  simge: '🎄', parcalar: ['yilbasi', 'nsakal', 'ylatki'] },
    { id: 'k-kutlama', ad: 'Kutlama',  simge: '🎉', parcalar: ['parti', 'papyon', 'balon'] },
    { id: 'k-kahraman', ad: 'Kahraman', simge: '🦸', parcalar: ['gozluk', 'pelerin'] },
    { id: 'k-kral',    ad: 'Kral',     simge: '👑', parcalar: ['tac', 'pelerin', 'altin'] },
    { id: 'k-gelin',   ad: 'Gelin Başı', simge: '👰', parcalar: ['cicektac', 'inci', 'pembe'] },
    { id: 'k-sik',     ad: 'Şık Kuaför', simge: '💅', parcalar: ['fiyonk', 'kedigoz'] }
  ];

  var SEZONLAR = {
    // 20 Kasım - 15 Ocak
    yilbasi: { ad: 'Yılbaşı Hediyesi', simge: '🎄', metin: 'Yeni yıl kostümün hazır! 15 Ocak’a kadar ücretsiz.',
      acik: function (gun) { var a = +gun.slice(5, 7), g = +gun.slice(8, 10); return a === 12 || (a === 11 && g >= 20) || (a === 1 && g <= 15); } }
  };

  var BOLGE_ODUL = { 3: { tarak: 300 }, 6: { tarak: 500 }, 9: { tarak: 700 }, 12: { tarak: 1000, urun: 'yele' }, 15: { tarak: 1200 }, 18: { tarak: 1400 }, 21: { tarak: 1600 }, 24: { tarak: 1800 }, 27: { tarak: 2000 }, 30: { tarak: 3000 } };
  var EN_UST_SEVIYE = 20;

  // Bir sonraki seviye için gereken deneyim her seviyede artar.
  function gerekenXp(seviye) { return 200 + (seviye - 1) * 100; }
  function seviyeBilgi(xp) {
    var s = 1, kalan = Math.max(0, Math.floor(xp || 0));
    while (s < EN_UST_SEVIYE && kalan >= gerekenXp(s)) { kalan -= gerekenXp(s); s++; }
    return { seviye: s, icinde: kalan, gereken: gerekenXp(s), enUst: s >= EN_UST_SEVIYE };
  }
  function seviyeOdulu(s) {
    var u = URUNLER.filter(function (x) { return x.seviye === s; })[0] || null;
    return { seviye: s, tarak: 80 + s * 20, urun: u };
  }

  var GUCLER = [
    { id: 'kalkan',   ad: 'Kalkanla Başla',        simge: '🛡️', fiyat: 120, tanim: 'Sonraki 3D koşuya kalkanla başlarsın.' },
    { id: 'miknatis', ad: 'Tarak Çekiciyle Başla', simge: '🧲', fiyat: 100, tanim: 'Sonraki 3D koşunun ilk 12 saniyesi.' }
  ];

  var GOREV_HAVUZU = [
    { id: 'tarak',   metin: '{n} tarak topla',              hedef: 150,  odul: 120, alan: 'tarak' },
    { id: 'mesafe',  metin: '3D koşuda {n} metre koş',      hedef: 1200, odul: 150, alan: 'mesafe' },
    { id: 'durak',   metin: '{n} müşteriye yetiş',          hedef: 3,    odul: 200, alan: 'durak' },
    { id: 'koli',    metin: 'Turbo kayışla {n} koli kır',   hedef: 6,    odul: 160, alan: 'koli' },
    { id: 'ziplama', metin: '{n} kez zıpla',                hedef: 40,   odul: 90,  alan: 'ziplama' },
    { id: 'kayma',   metin: '{n} kez kay',                  hedef: 20,   odul: 90,  alan: 'kayma' },
    { id: 'kosu',    metin: '{n} koşu tamamla',             hedef: 5,    odul: 100, alan: 'kosu' }
  ];

  var DEVAM_FIYATI = 150;

  function bos() {
    return { cuzdan: 0, xp: 0, sahip: [], takili: {}, gucler: { kalkan: 0, miknatis: 0 }, gunluk: { sonGun: '', seri: 0 }, gorevGunu: '', gorevler: [], sezonlar: [], bolgeler: [] };
  }

  // Kayıt bozuk ya da eski olsa bile güvenli bir durum döndürür.
  function duzelt(k) {
    var d = bos();
    if (!k || typeof k !== 'object') return d;
    if (k.cuzdan > 0) d.cuzdan = Math.floor(k.cuzdan);
    if (Array.isArray(k.sahip)) d.sahip = k.sahip.filter(function (x) { return urun(x); });
    if (k.takili) for (var y in k.takili) if (d.sahip.indexOf(k.takili[y]) >= 0 && urun(k.takili[y]).yuva === y) d.takili[y] = k.takili[y];
    if (k.xp > 0) d.xp = Math.floor(k.xp);
    if (Array.isArray(k.sezonlar)) d.sezonlar = k.sezonlar.map(String);
    if (Array.isArray(k.bolgeler)) d.bolgeler = k.bolgeler.filter(function (b) { return BOLGE_ODUL[b]; });
    if (k.gucler) { d.gucler.kalkan = Math.max(0, k.gucler.kalkan | 0); d.gucler.miknatis = Math.max(0, k.gucler.miknatis | 0); }
    if (k.gunluk) d.gunluk = { sonGun: String(k.gunluk.sonGun || ''), seri: k.gunluk.seri | 0 };
    if (Array.isArray(k.gorevler)) { d.gorevGunu = String(k.gorevGunu || ''); d.gorevler = k.gorevler.filter(function (g) { return g && havuzdan(g.id); }); }
    return d;
  }

  function urun(id) { for (var i = 0; i < URUNLER.length; i++) if (URUNLER[i].id === id) return URUNLER[i]; return null; }
  function guc(id) { for (var i = 0; i < GUCLER.length; i++) if (GUCLER[i].id === id) return GUCLER[i]; return null; }
  function havuzdan(id) { for (var i = 0; i < GOREV_HAVUZU.length; i++) if (GOREV_HAVUZU[i].id === id) return GOREV_HAVUZU[i]; return null; }

  function gunAdi(t) {
    var d = t || new Date();
    return d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2);
  }
  function dun(gun) {
    var p = gun.split('-');
    var d = new Date(+p[0], +p[1] - 1, +p[2], 12);
    d.setDate(d.getDate() - 1);
    return gunAdi(d);
  }

  function gunlukDurum(k, bugun) {
    var alindi = k.gunluk.sonGun === bugun;
    var seri = alindi ? k.gunluk.seri : (k.gunluk.sonGun === dun(bugun) ? k.gunluk.seri : 0);
    var siradaki = alindi ? (seri - 1) % GUNLUK.length : seri % GUNLUK.length;
    return { alindi: alindi, seri: seri, gun: siradaki, miktar: GUNLUK[siradaki] };
  }
  function gunlukAl(k, bugun) {
    var d = gunlukDurum(k, bugun);
    if (d.alindi) return 0;
    k.gunluk = { sonGun: bugun, seri: d.seri + 1 };
    k.cuzdan += d.miktar;
    return d.miktar;
  }

  // Her gün havuzdan 3 farklı görev (güne göre sabit)
  function gorevleriHazirla(k, bugun) {
    if (k.gorevGunu === bugun && k.gorevler.length === 3) return k.gorevler;
    var tohum = 0;
    for (var i = 0; i < bugun.length; i++) tohum = (tohum * 31 + bugun.charCodeAt(i)) >>> 0;
    var kalan = GOREV_HAVUZU.slice(), secilen = [];
    while (secilen.length < 3) {
      tohum = (Math.imul(tohum, 1664525) + 1013904223) >>> 0;
      secilen.push(kalan.splice((tohum >>> 8) % kalan.length, 1)[0]);
    }
    k.gorevGunu = bugun;
    k.gorevler = secilen.map(function (g) { return { id: g.id, ilerleme: 0, alindi: false }; });
    return k.gorevler;
  }
  function gorevBilgi(g) {
    var h = havuzdan(g.id);
    return { id: g.id, metin: h.metin.replace('{n}', h.hedef), hedef: h.hedef, odul: h.odul, ilerleme: Math.min(g.ilerleme, h.hedef), tamam: g.ilerleme >= h.hedef, alindi: g.alindi };
  }
  function gorevAl(k, id) {
    for (var i = 0; i < k.gorevler.length; i++) {
      var g = k.gorevler[i], b = gorevBilgi(g);
      if (g.id === id && b.tamam && !g.alindi) { g.alindi = true; k.cuzdan += b.odul; return b.odul; }
    }
    return 0;
  }

  /* Koşu sonu: toplanan taraklar cüzdana eklenir, görevler ilerler.
   * ozet = {tarak, mesafe, durak, koli, ziplama, kayma, kosu} */
  function kosuIsle(k, ozet, bugun) {
    gorevleriHazirla(k, bugun);
    var yeniTamam = [];
    k.gorevler.forEach(function (g) {
      var once = gorevBilgi(g).tamam;
      g.ilerleme += Math.max(0, Math.floor(ozet[havuzdan(g.id).alan] || 0));
      if (!once && gorevBilgi(g).tamam) yeniTamam.push(gorevBilgi(g));
    });
    k.cuzdan += Math.max(0, Math.floor(ozet.tarak || 0));
    // Deneyim ve seviye ödülleri (dönen dizinin "seviyeler" alanında)
    var kazanilan = Math.max(0, Math.floor((ozet.tarak || 0) + (ozet.mesafe || 0) / 8 + (ozet.durak || 0) * 60 + (ozet.kosu || 0) * 25));
    yeniTamam.xp = kazanilan;
    yeniTamam.seviyeler = xpEkle(k, kazanilan);
    return yeniTamam;
  }

  function xpEkle(k, miktar) {
    var once = seviyeBilgi(k.xp).seviye;
    k.xp += miktar;
    var sonra = seviyeBilgi(k.xp).seviye, odul = [];
    for (var s = once + 1; s <= sonra; s++) {
      var od = seviyeOdulu(s);
      k.cuzdan += od.tarak;
      if (od.urun && k.sahip.indexOf(od.urun.id) < 0) k.sahip.push(od.urun.id);
      odul.push(od);
    }
    return odul;
  }

  function sezonDurum(k, bugun) {
    for (var ad in SEZONLAR) {
      if (!SEZONLAR[ad].acik(bugun)) continue;
      // Ocak ayındaki hediye bir önceki yılın sezonuna aittir
      var yil = +bugun.slice(0, 4) - (bugun.slice(5, 7) === '01' ? 1 : 0);
      var anahtar = ad + '-' + yil;
      return { id: ad, anahtar: anahtar, bilgi: SEZONLAR[ad], alindi: k.sezonlar.indexOf(anahtar) >= 0 };
    }
    return null;
  }
  // Sezon kostümünü verir ve hemen giydirir.
  function sezonAl(k, bugun) {
    var d = sezonDurum(k, bugun);
    if (!d || d.alindi) return false;
    k.sezonlar.push(d.anahtar);
    URUNLER.forEach(function (u) {
      if (u.sezon !== d.id) return;
      if (k.sahip.indexOf(u.id) < 0) k.sahip.push(u.id);
      k.takili[u.yuva] = u.id;
    });
    return true;
  }

  function bolgeAl(k, no) {
    var o = BOLGE_ODUL[no];
    if (!o || k.bolgeler.indexOf(no) >= 0) return null;
    k.bolgeler.push(no);
    k.cuzdan += o.tarak;
    if (o.urun && k.sahip.indexOf(o.urun) < 0) k.sahip.push(o.urun);
    return { tarak: o.tarak, urun: o.urun ? urun(o.urun) : null };
  }

  function kostumVar(k, id) {
    var x = KOSTUMLER.filter(function (c) { return c.id === id; })[0];
    return !!x && x.parcalar.every(function (p) { return k.sahip.indexOf(p) >= 0; });
  }
  function kostumGiy(k, id) {
    if (!kostumVar(k, id)) return false;
    k.takili = {};
    KOSTUMLER.filter(function (c) { return c.id === id; })[0].parcalar.forEach(function (p) { k.takili[urun(p).yuva] = p; });
    return true;
  }

  // Sandık içeriği: çoğunlukla tarak, ara sıra güç, nadiren bedava aksesuar
  function sandikAc(k, rnd) {
    var r = rnd || Math.random;
    var zar = r();
    if (zar < 0.04) {
      var yok = URUNLER.filter(function (u) { return u.fiyat && u.fiyat <= 700 && k.sahip.indexOf(u.id) < 0; });
      if (yok.length) { var u = yok[Math.floor(r() * yok.length)]; k.sahip.push(u.id); return { tur: 'aksesuar', ad: u.ad, simge: u.simge }; }
    }
    if (zar < 0.2) {
      var gc = GUCLER[Math.floor(r() * GUCLER.length)];
      k.gucler[gc.id]++;
      return { tur: 'guc', ad: gc.ad, simge: gc.simge };
    }
    var miktar = 30 + Math.floor(r() * 10) * 10 + (zar > 0.95 ? 200 : 0);
    k.cuzdan += miktar;
    return { tur: 'tarak', miktar: miktar, ad: miktar + ' tarak', simge: '💰' };
  }

  function satinAl(k, id) {
    var u = urun(id);
    if (u) {
      if (!u.fiyat || k.sahip.indexOf(id) >= 0 || k.cuzdan < u.fiyat) return false;
      k.cuzdan -= u.fiyat; k.sahip.push(id); k.takili[u.yuva] = id;
      return true;
    }
    var gc = guc(id);
    if (!gc || k.cuzdan < gc.fiyat) return false;
    k.cuzdan -= gc.fiyat; k.gucler[id]++;
    return true;
  }
  function takCikar(k, id) {
    var u = urun(id);
    if (!u || k.sahip.indexOf(id) < 0) return;
    if (k.takili[u.yuva] === id) delete k.takili[u.yuva]; else k.takili[u.yuva] = id;
  }
  // Koşu başında varsa birer güç harcanır
  function gucHarca(k) {
    var s = {};
    ['kalkan', 'miknatis'].forEach(function (a) { if (k.gucler[a] > 0) { k.gucler[a]--; s[a] = true; } });
    return s;
  }
  function devamOde(k) {
    if (k.cuzdan < DEVAM_FIYATI) return false;
    k.cuzdan -= DEVAM_FIYATI;
    return true;
  }
  function bekleyen(k, bugun) {
    gorevleriHazirla(k, bugun);
    var sz = sezonDurum(k, bugun);
    return (sz && !sz.alindi ? 1 : 0) + (gunlukDurum(k, bugun).alindi ? 0 : 1) + k.gorevler.filter(function (g) { var b = gorevBilgi(g); return b.tamam && !b.alindi; }).length;
  }

  return {
    GUNLUK: GUNLUK, URUNLER: URUNLER, GUCLER: GUCLER, DEVAM_FIYATI: DEVAM_FIYATI,
    bos: bos, duzelt: duzelt, gunAdi: gunAdi, gunlukDurum: gunlukDurum, gunlukAl: gunlukAl,
    gorevleriHazirla: gorevleriHazirla, gorevBilgi: gorevBilgi, gorevAl: gorevAl, kosuIsle: kosuIsle,
    YUVALAR: YUVALAR, KOSTUMLER: KOSTUMLER, BOLGE_ODUL: BOLGE_ODUL, urun: urun,
    seviyeBilgi: seviyeBilgi, seviyeOdulu: seviyeOdulu, xpEkle: xpEkle, sezonDurum: sezonDurum, sezonAl: sezonAl,
    bolgeAl: bolgeAl, kostumVar: kostumVar, kostumGiy: kostumGiy,
    sandikAc: sandikAc, satinAl: satinAl, takCikar: takCikar, gucHarca: gucHarca, devamOde: devamOde, bekleyen: bekleyen
  };
});
