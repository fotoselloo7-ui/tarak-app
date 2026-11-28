/* Tarak Mobil: Randevuya Koş — oyun çekirdeği (DOM'suz, testlerde Node ile de çalışır).
 * Koordinatlar: x = yol üzerindeki mesafe (px), y = ayakların yerden yüksekliği (yukarı +). */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.TarakCore = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var S = {
    yercekimi: 2800,
    zipla1: 880,
    zipla2: 767,
    kayisSure: 0.7,
    turboSure: 1.4,
    turboCarpan: 1.35,
    hizliDusus: 1150,
    boyAyakta: 100,
    boyKayarken: 46,
    genislik: 40,
    tavan: 66,          // alçak engellerin alt kenarı
    kojot: 0.08,
    tampon: 0.12,
    dokunulmazlik: 1.5,
    canSayisi: 3
  };

  // Zorluk modları: yalnızca hız değil; can, engel boyu, çukur, aralık ve zamanlama payı da değişir.
  var MODLAR = {
    kolay: { ad: 'Kolay', simge: '😊', hiz: 0.88, can: 5, bosluk: 1.3, parca: 0.75, engelBoy: 0.8, yuksek: 112, cukur: 0.8, tunel: 1.15,
             kayis: 0.98, turbo: 1.85, kojot: 0.15, tampon: 0.2, pay: 6, lastik: 55, dokunulmaz: 2.1, puan: 1, devam: true, hizlanma: 0.06,
             tanim: '5 can · yavaş · geniş aralıklar · bayraktan devam' },
    orta:  { ad: 'Orta', simge: '😎', hiz: 0.99, can: 4, bosluk: 1.14, parca: 0.9, engelBoy: 0.92, yuksek: 128, cukur: 0.9, tunel: 1.2,
             kayis: 0.83, turbo: 1.6, kojot: 0.11, tampon: 0.16, pay: 3, lastik: 75, dokunulmaz: 1.75, puan: 1.5, devam: true, hizlanma: 0.08,
             tanim: '4 can · dengeli hız · bayraktan devam · 1,5× puan' },
    zor:   { ad: 'Zor', simge: '🔥', hiz: 1.08, can: 3, bosluk: 1, parca: 1, engelBoy: 1, yuksek: 142, cukur: 1, tunel: 1.2,
             kayis: 0.7, turbo: 1.4, kojot: 0.08, tampon: 0.12, pay: 0, lastik: 95, dokunulmaz: 1.5, puan: 2, devam: false, hizlanma: 0.1,
             tanim: '3 can · tam hız · devam yok · 2× puan' }
  };
  function modAl(ad) { return MODLAR[ad] || MODLAR.zor; }

  var DUNYALAR = {
    sehir:  { ad: 'Şehir Sokakları' },
    otoyol: { ad: 'Otoyol' },
    orman:  { ad: 'Orman Patikası' },
    in:     { ad: 'Aslanın İni' }
  };

  // Her bölüm = bir randevu. "yeni" listesi o bölümde ilk kez öğretilen hareketlerdir.
  var BOLUMLER = [
    { id: 1,  dunya: 'sehir',  ad: 'İlk Randevu',      musteri: 'Mehmet Bey',   hiz: 235, parca: 18, seed: 11,
      yeni: ['engel'], havuz: ['engel', 'engel', 'ikiEngel'],
      ipucu: 'Engele yaklaşınca ZIPLA tuşuna bas ya da ekrana dokun.' },
    { id: 2,  dunya: 'sehir',  ad: 'Çifte Zıplama',    musteri: 'Hasan Usta',   hiz: 245, parca: 20, seed: 23,
      yeni: ['yuksek'], havuz: ['engel', 'yuksek', 'genis'],
      ipucu: 'Yüksek engel için havadayken BİR KEZ DAHA zıpla.' },
    { id: 3,  dunya: 'sehir',  ad: 'Tabela Altı',      musteri: 'Emre Abi',     hiz: 250, parca: 22, seed: 37,
      yeni: ['tabela'], havuz: ['engel', 'tabela', 'yuksek', 'ikiEngel'],
      ipucu: 'Tabelanın altından KAY: KAY tuşu ya da parmağını aşağı kaydır.' },
    { id: 4,  dunya: 'otoyol', ad: 'Yol Çalışması',    musteri: 'Burak Bey',    hiz: 265, parca: 24, seed: 41,
      yeni: ['cukur'], havuz: ['engel', 'cukur', 'tabela', 'yuksek'],
      ipucu: 'Çukurun kenarında zıpla!' },
    { id: 5,  dunya: 'otoyol', ad: 'Uzun Tünel',       musteri: 'Kemal Amca',   hiz: 270, parca: 24, seed: 53,
      yeni: ['tunel'], havuz: ['tunel', 'engel', 'cukur', 'tabela'],
      ipucu: 'Uzun geçitte KAY’a İKİ KEZ bas: TURBO KAYIŞ!' },
    { id: 6,  dunya: 'otoyol', ad: 'Kaçak Lastik',     musteri: 'Onur Bey',     hiz: 280, parca: 26, seed: 67,
      yeni: ['lastik', 'koli'], havuz: ['lastik', 'koli', 'tunel', 'yuksek', 'cukur', 'ikiEngel'],
      ipucu: 'Turbo kayış kolileri parçalar. Yuvarlanan lastiğe dikkat!' },
    { id: 7,  dunya: 'orman',  ad: 'Patikaya Giriş',   musteri: 'Orman Bekçisi', hiz: 285, parca: 26, seed: 71,
      yeni: ['buyukCukur'], havuz: ['buyukCukur', 'engel', 'tabela', 'lastik', 'yuksek'],
      ipucu: 'Geniş uçurumda çift zıpla.' },
    { id: 8,  dunya: 'orman',  ad: 'Sık Ağaçlar',      musteri: 'Kampçı Can',   hiz: 295, parca: 28, seed: 89,
      yeni: ['karisik'], havuz: ['karisik', 'tunel', 'yuksek', 'buyukCukur', 'koli', 'ikiEngel'],
      ipucu: 'Hareketleri art arda yap: ritmi yakala.' },
    { id: 9,  dunya: 'orman',  ad: 'Dere Boyu',        musteri: 'Balıkçı Rıza', hiz: 305, parca: 30, seed: 97,
      yeni: [], havuz: ['cukur', 'buyukCukur', 'karisik', 'tabela', 'lastik', 'tunel', 'yuksek'],
      ipucu: 'Taraklar sana doğru yolu gösterir.' },
    { id: 10, dunya: 'in',     ad: 'İz Peşinde',       musteri: 'Avcı Selim',   hiz: 315, parca: 30, seed: 101,
      yeni: [], havuz: ['karisik', 'buyukCukur', 'tunel', 'lastik', 'yuksek', 'koli', 'ikiEngel'],
      ipucu: 'Fön spreyi kalkan verir, tıraş makinesi tarakları çeker.' },
    { id: 11, dunya: 'in',     ad: 'Kükreme Vadisi',   musteri: 'Bakıcı Ayşe',  hiz: 325, parca: 32, seed: 113,
      yeni: [], havuz: ['karisik', 'karisik', 'buyukCukur', 'tunel', 'lastik', 'yuksek', 'cukur'],
      ipucu: 'Aslana çok az kaldı!' },
    { id: 12, dunya: 'in',     ad: 'Kralın Huzurunda',    musteri: 'Aslan Kral',   hiz: 335, parca: 38, seed: 127,
      yeni: [], havuz: ['karisik', 'karisik', 'buyukCukur', 'tunel', 'lastik', 'yuksek', 'koli', 'tabela'],
      ipucu: 'Aslan Kral’ın huzuruna çıkıyorsun!' }
  ];
  // 13-30: tüm hareketler karışık; günün saati değişir (akşam, gece, sabah)
  [
    ['sehir', 'aksam', 'Akşam Mesaisi', 'Kuaför Selin', 'Gün batıyor, sokaklar kalabalık.'],
    ['sehir', 'gece', 'Gece Vardiyası', 'Fırıncı Yusuf', 'Gece karanlığında engelleri iyi izle.'],
    ['sehir', 'sabah', 'Erken Kalkan', 'Esnaf Cemil', 'Sabah serinliğinde hızlan!'],
    ['otoyol', 'aksam', 'Gün Batımı Otoyolu', 'Kamyoncu Rıfat', 'Lastikler akşam daha hızlı yuvarlanıyor.'],
    ['otoyol', 'gece', 'Gece Otoyolu', 'Taksici Murat', 'Farlara dikkat!'],
    ['otoyol', 'sabah', 'Sabah Trafiği', 'Kurye Deniz', 'Turbo kayışı unutma.'],
    ['orman', 'sabah', 'Çiğli Patika', 'Kampçı Elif', 'Sabah sisi patikayı kaplamış.'],
    ['orman', 'aksam', 'Akşam Ormanı', 'Oduncu Hüseyin', 'Kütüklerin üstünden çift zıpla.'],
    ['orman', 'gece', 'Gece Patikası', 'Bekçi Ramazan', 'Karanlıkta uçurumlar daha sinsi.'],
    ['in', 'sabah', 'Şafak Vadisi', 'Fotoğrafçı Arda', 'Aslanlar uyanıyor!'],
    ['in', 'gece', 'Ay Işığında', 'Rehber Zeynep', 'Ay ışığında koş.'],
    ['in', 'aksam', 'Kızıl Savana', 'Veteriner Ece', 'Neredeyse kralın inindesin.'],
    ['sehir', 'gece', 'Neon Sokaklar', 'Berber Kemal', 'Şehrin en hızlı gecesi.'],
    ['otoyol', 'gece', 'Gece Yarısı Sürüşü', 'Tır Şoförü Ali', 'Hız hiç düşmüyor!'],
    ['orman', 'gece', 'Karanlık Orman', 'Avcı Selim', 'Son ormanı geç.'],
    ['in', 'gece', 'Kükreyen Gece', 'Bakıcı Ayşe', 'Kükremeler yaklaşıyor.'],
    ['orman', 'aksam', 'Kraliçenin Ormanı', 'Kraliçe Aslan', 'Kraliçe tıraş istiyor!'],
    ['in', 'aksam', 'Kralın Taç Töreni', 'Aslan Kral', 'Final! Aslan Kral taç töreni için tıraş bekliyor.']
  ].forEach(function (b, i) {
    var id = 13 + i;
    BOLUMLER.push({ id: id, dunya: b[0], saat: b[1], ad: b[2], musteri: b[3], hiz: 341 + i * 3, parca: 30 + Math.round(i * 0.7), seed: 131 + i * 17,
      yeni: [], havuz: ['karisik', 'karisik', 'buyukCukur', 'tunel', 'lastik', 'yuksek', 'koli', 'tabela', 'cukur', 'ikiEngel'], ipucu: b[4], final: id === 30 });
  });

  function rastgele(seed) {
    var a = seed >>> 0;
    return function () {
      a = (a + 0x6D2B79F5) >>> 0;
      var t = a;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  // ---------- Bölüm üretimi ----------
  function yeniDunya(mod) { return { engeller: [], cukurlar: [], nesneler: [], mod: modAl(mod) }; }

  function tarak(d, x, y) { d.nesneler.push({ tur: 'tarak', x: x, y: y, alindi: false }); }

  function tarakYayi(d, merkez, v, tepe, adet) {
    var yari = v * 0.27;
    for (var i = 0; i < adet; i++) {
      var o = adet === 1 ? 0.5 : i / (adet - 1);
      tarak(d, merkez - yari + o * yari * 2, 35 + Math.sin(o * Math.PI) * (tepe - 35));
    }
  }

  function tarakSirasi(d, x, adet, y, aralik) {
    for (var i = 0; i < adet; i++) tarak(d, x + i * (aralik || 34), y);
  }

  function engel(d, tur, x, w, y0, y1, ek) {
    var e = { tur: tur, x: x, w: w, y0: y0, y1: y1, gecti: false, kirildi: false, cesit: 0 };
    if (ek) for (var k in ek) e[k] = ek[k];
    d.engeller.push(e);
    return e;
  }

  // Her kalıp, kapladığı uzunluğu döndürür.
  var KALIPLAR = {
    engel: function (d, x, v, r) {
      var h = Math.round((44 + Math.floor(r() * 16)) * d.mod.engelBoy);
      engel(d, 'kutu', x, 44, 0, h, { cesit: Math.floor(r() * 3) });
      tarakYayi(d, x + 22, v, 135, 5);
      return 44;
    },
    ikiEngel: function (d, x, v, r) {
      KALIPLAR.engel(d, x, v, r);
      KALIPLAR.engel(d, x + v * 0.95, v, r);
      return v * 0.95 + 44;
    },
    genis: function (d, x, v) {
      var w = Math.round(68 * d.mod.cukur);
      engel(d, 'genis', x, w, 0, Math.round(46 * d.mod.engelBoy));
      tarakYayi(d, x + w / 2, v, 140, 5);
      return w;
    },
    yuksek: function (d, x, v) {
      engel(d, 'yuksek', x, 38, 0, d.mod.yuksek);
      tarak(d, x - v * 0.22, 130);
      tarak(d, x - v * 0.08, 190);
      tarak(d, x + 22, 225);
      tarak(d, x + 44 + v * 0.14, 190);
      return 44;
    },
    tabela: function (d, x, v) {
      engel(d, 'tabela', x, 46, S.tavan, 420);
      tarakSirasi(d, x - 52, 5, 26);
      return 46;
    },
    tunel: function (d, x, v) {
      var w = Math.round(v * d.mod.tunel);
      engel(d, 'tunel', x, w, S.tavan, 420);
      tarakSirasi(d, x + 20, Math.floor((w - 20) / 36), 26, 36);
      return w;
    },
    cukur: function (d, x, v) {
      var w = Math.round(v * 0.4 * d.mod.cukur);
      d.cukurlar.push({ x: x, w: w });
      tarakYayi(d, x + w / 2, v, 135, 5);
      return w;
    },
    buyukCukur: function (d, x, v) {
      var w = Math.round(v * 0.9 * d.mod.cukur);
      d.cukurlar.push({ x: x, w: w });
      for (var i = 0; i < 6; i++) {
        var o = i / 5;
        tarak(d, x - 20 + o * (w + 40), 70 + Math.sin(o * Math.PI) * 145);
      }
      return w;
    },
    lastik: function (d, x, v) {
      var h = Math.round(48 * Math.max(0.88, d.mod.engelBoy));
      engel(d, 'lastik', x, h, 0, h, { hareket: d.mod.lastik, x0: x, tetik: false });
      tarakSirasi(d, x - v * 0.5, 3, 30);
      return 48;
    },
    koli: function (d, x, v) {
      engel(d, 'koli', x, 50, 0, Math.round(56 * d.mod.engelBoy));
      tarakSirasi(d, x - 80, 6, 28, 36);
      return 52;
    },
    karisik: function (d, x, v, r) {
      var sira = [
        ['engel', 'tabela', 'yuksek'],
        ['tabela', 'cukur', 'engel'],
        ['cukur', 'yuksek', 'tabela'],
        ['yuksek', 'engel', 'tabela']
      ][Math.floor(r() * 4)];
      var cx = x;
      for (var i = 0; i < sira.length; i++) {
        var uz = KALIPLAR[sira[i]](d, cx, v, r);
        if (i < sira.length - 1) cx += uz + v * 1.05;
        else cx += uz;
      }
      return cx - x;
    }
  };

  // Kadın kuaför modu: her bölümün kadın müşterisi ve istediği hizmet
  var KADIN_MUSTERI = ['Ayşe Hanım', 'Zeynep Hanım', 'Elif Hanım', 'Selin Hanım', 'Merve Hanım', 'Derya Abla', 'Bekçi Gül', 'Kampçı Ece', 'Balıkçı Nazlı', 'Rehber Defne',
    'Bakıcı Ayşe', 'Aslan Kraliçe', 'Esra Hanım', 'Gelin Buse', 'Nazan Teyze', 'Ece Hanım', 'Pınar Hanım', 'Seda Hanım', 'Gizem Hanım', 'Burcu Hanım',
    'Ebru Hanım', 'Melis Hanım', 'Dilara Hanım', 'Sevgi Teyze', 'Hande Hanım', 'Damla Hanım', 'Yasemin Hanım', 'Ceren Hanım', 'Kraliçe Leyla', 'Aslan Kraliçe'];
  var KADIN_HIZMET = ['Manikür', 'Fön', 'Saç Kesimi', 'Pedikür', 'Dip Boya', 'Röfle / Ombre', 'Kaş Tasarımı', 'Günlük Makyaj', 'Manikür + Pedikür', 'Tüm Boya',
    'Fön', 'Porselen Makyaj', 'Saç Kesimi', 'Gelin Başı', 'Manikür', 'Röfle / Ombre', 'Pedikür', 'Fön', 'Kaş Tasarımı', 'Dip Boya',
    'Günlük Makyaj', 'Manikür + Pedikür', 'Tüm Boya', 'Saç Kesimi', 'Fön', 'Porselen Makyaj', 'Röfle / Ombre', 'Manikür', 'Gelin Başı', 'Porselen Makyaj'];
  BOLUMLER.forEach(function (b, i) { b.musteriK = KADIN_MUSTERI[i % KADIN_MUSTERI.length]; b.hizmetK = KADIN_HIZMET[i % KADIN_HIZMET.length]; });

  function bolumKur(no, mod) {
    var b = BOLUMLER[no - 1];
    var r = rastgele(b.seed * 7919);
    var d = yeniDunya(mod);
    var v = Math.round(b.hiz * d.mod.hiz);
    var parcaSayisi = Math.max(b.yeni.length * 2 + 6, Math.round(b.parca * d.mod.parca));
    var x = 640;
    var sira = [];
    // Yeni hareket önce iki kez tek başına öğretilir.
    b.yeni.forEach(function (p) { sira.push(p, p); });
    var onceki = '';
    while (sira.length < parcaSayisi) {
      var p = b.havuz[Math.floor(r() * b.havuz.length)];
      if (p === onceki && (p === 'tunel' || p === 'karisik' || p === 'buyukCukur')) continue;
      sira.push(p); onceki = p;
    }
    // Uzun bölümlerde iki ara bayrak
    var bayraklar = [Math.floor(sira.length / 3), Math.floor(sira.length * 2 / 3)];
    var kontroller = [], bolgeler = [], v0 = v, art = d.mod.hizlanma || 0;
    for (var i = 0; i < sira.length; i++) {
      if (bayraklar.indexOf(i) >= 0) {
        kontroller.push(Math.round(x));
        // Bayraktan sonra hızlanma bölgesi (ilk iki bölümde yumuşak)
        v = Math.round(v0 * (1 + art * (no <= 2 ? 0.5 : 1) * kontroller.length));
        bolgeler.push({ x: Math.round(x), v: v, no: kontroller.length });
        x += 120;
      }
      if (i === Math.floor(sira.length * 0.3) && no >= 3) { d.nesneler.push({ tur: 'miknatis', x: x - v * 0.5, y: 34, alindi: false }); }
      if (i === Math.floor(sira.length * 0.65) && no >= 4) { d.nesneler.push({ tur: 'kalkan', x: x - v * 0.5, y: 34, alindi: false }); }
      if (i === Math.floor(sira.length * 0.8) && no >= 7) { d.nesneler.push({ tur: 'kalp', x: x - v * 0.5, y: 34, alindi: false }); }
      // Aralara ödül: bölümün %20, %50 ve %80 civarında hediye kutusu
      if (i === Math.floor(sira.length * 0.2) || i === Math.floor(sira.length * 0.5) || i === Math.floor(sira.length * 0.85)) {
        d.nesneler.push({ tur: 'sandik', x: x - v * 0.5, y: 36, alindi: false });
      }
      // Hediye parçası: ancak çift zıplamayla ulaşılan yükseklikte, 3. bölümden sonra
      if (no >= 3 && (i === Math.floor(sira.length * 0.45) || (no >= 8 && i === Math.floor(sira.length * 0.75)))) {
        d.nesneler.push({ tur: 'parca', x: x - v * 0.62, y: 268, alindi: false });
      }
      var uz = KALIPLAR[sira[i]](d, x, v, r);
      var bosluk = v * (1.15 + r() * 0.45) * (1 - bolgeler.length * 0.04);
      if (no <= 2) bosluk = v * (1.45 + r() * 0.4);
      x += uz + bosluk * d.mod.bosluk;
    }
    d.uzunluk = Math.round(x + 360);
    d.kontroller = kontroller;
    d.kontrol = kontroller[0] || 0;
    d.hiz = v0;
    d.bolgeler = bolgeler;
    d.toplamTarak = d.nesneler.filter(function (n) { return n.tur === 'tarak'; }).length;
    return d;
  }

  // ---------- Oyun durumu ----------
  function yeniOyun(secim, mod) {
    var sonsuz = secim === 'sonsuz';
    var modAdi = MODLAR[mod] ? mod : 'zor';
    var d;
    if (sonsuz) {
      d = yeniDunya(modAdi);
      d.uzunluk = Infinity; d.kontrol = 0; d.kontroller = []; d.hiz = 250; d.toplamTarak = 0;
    } else {
      d = bolumKur(secim, modAdi);
    }
    var o = {
      sonsuz: sonsuz, bolum: sonsuz ? 0 : secim, dunya: d,
      tanim: sonsuz ? null : BOLUMLER[secim - 1],
      p: { x: 0, y: 0, vy: 0, yerde: true, zipSayisi: 0, kayis: 0, turbo: false, kuyrukKayis: false,
           kojot: 0, tampon: 0, dokunulmaz: 0, dusuyor: false },
      mod: modAdi, ayar: d.mod, canMax: d.mod.can, kontrolKaydi: null, devamli: false, sureBaslangic: 0,
      can: d.mod.can, tarak: 0, sandik: 0, bonus: 0, sure: 0, kalkan: false, miknatis: 0, parca: 0,
      bitti: false, kazandi: false, hasar: 0, kontrolSayisi: 0, sonNeden: '', olaylar: [],
      hizCarpani: 1, _r: rastgele((Date.now() & 0xffffff) | 1), _uretim: 700
    };
    if (sonsuz) sonsuzUret(o);
    return o;
  }

  function sonsuzUret(o) {
    var d = o.dunya;
    while (o._uretim < o.p.x + 2200) {
      var seviye = Math.min(1, o._uretim / 40000);
      var havuz = ['engel', 'engel', 'ikiEngel', 'tabela', 'yuksek'];
      if (o._uretim > 4000) havuz.push('cukur', 'genis', 'koli');
      if (o._uretim > 9000) havuz.push('tunel', 'lastik');
      if (o._uretim > 15000) havuz.push('buyukCukur', 'karisik');
      var v = (250 + seviye * 120) * d.mod.hiz;
      var p = havuz[Math.floor(o._r() * havuz.length)];
      var uz = KALIPLAR[p](d, o._uretim, v, o._r);
      if (o._uretim > (o._parcaSira || 7000)) {
        d.nesneler.push({ tur: 'parca', x: o._uretim + uz + v * 0.6, y: 268, alindi: false });
        o._parcaSira = o._uretim + 9000;
      }
      if (o._uretim > (o._hediyeSira || 3200)) {
        d.nesneler.push({ tur: 'sandik', x: o._uretim + uz + v * 0.55, y: 36, alindi: false });
        o._hediyeSira = o._uretim + 4200;
      } else if (o._r() < 0.05) {
        var ozel = ['miknatis', 'kalkan', 'kalp'][Math.floor(o._r() * 3)];
        d.nesneler.push({ tur: ozel, x: o._uretim + uz + v * 0.55, y: 34, alindi: false });
      }
      o._uretim += uz + v * (1.15 + o._r() * 0.45) * d.mod.bosluk;
    }
    var sinir = o.p.x - 600;
    d.engeller = d.engeller.filter(function (e) { return e.x + e.w > sinir; });
    d.cukurlar = d.cukurlar.filter(function (c) { return c.x + c.w > sinir; });
    d.nesneler = d.nesneler.filter(function (n) { return n.x > sinir; });
  }

  function hiz(o) {
    var v = o.sonsuz ? (250 + Math.min(1, o.p.x / 40000) * 120) * o.ayar.hiz : o.dunya.hiz;
    if (!o.sonsuz && o.dunya.bolgeler) for (var i = 0; i < o.dunya.bolgeler.length; i++) if (o.p.x >= o.dunya.bolgeler[i].x) v = o.dunya.bolgeler[i].v;
    return v * o.hizCarpani;
  }

  function olay(o, tur, ek) { o.olaylar.push({ tur: tur, ek: ek }); }

  function zipla(o) {
    if (o.bitti || o.p.dusuyor) return;
    var p = o.p;
    if (p.yerde || p.kojot > 0) {
      p.vy = S.zipla1; p.yerde = false; p.kojot = 0; p.zipSayisi = 1;
      p.kayis = 0; p.turbo = false; p.kuyrukKayis = false; p.tampon = 0;
      olay(o, 'zipla');
    } else if (p.zipSayisi < 2) {
      p.vy = S.zipla2; p.zipSayisi = 2; p.kuyrukKayis = false;
      olay(o, 'zipla2');
    } else {
      p.tampon = o.ayar.tampon;
    }
  }

  function kay(o) {
    if (o.bitti || o.p.dusuyor) return;
    var p = o.p;
    if (!p.yerde) {
      // Havada: hızlı in ve yere değince kay. İkinci basış turbo olur.
      if (p.kuyrukKayis) p.turbo = true;
      p.kuyrukKayis = true;
      p.vy = Math.min(p.vy, -S.hizliDusus);
      return;
    }
    if (p.kayis > 0) {
      if (!p.turbo) { p.turbo = true; p.kayis = o.ayar.turbo; olay(o, 'turbo'); }
      return;
    }
    p.kayis = o.ayar.kayis; p.turbo = false;
    olay(o, 'kay');
  }

  function cukurda(o, x) {
    var c = o.dunya.cukurlar;
    for (var i = 0; i < c.length; i++) if (x > c[i].x + 12 && x < c[i].x + c[i].w - 12) return c[i];
    return null;
  }

  function altindaTavanVar(o) {
    var p = o.p, sol = p.x - S.genislik / 2, sag = p.x + S.genislik / 2;
    return o.dunya.engeller.some(function (e) {
      return (e.tur === 'tunel') && !e.gecti && sag > e.x && sol < e.x + e.w;
    });
  }

  function hasarVer(o, neden) {
    if (o.p.dokunulmaz > 0) return false;
    if (o.kalkan) {
      o.kalkan = false; o.p.dokunulmaz = o.ayar.dokunulmaz; olay(o, 'kalkanKirildi');
      return false;
    }
    o.can -= 1; o.hasar += 1; o.sonNeden = neden;
    o.p.dokunulmaz = o.ayar.dokunulmaz;
    olay(o, 'carpti', neden);
    if (o.can <= 0) { o.bitti = true; o.kazandi = false; olay(o, 'kaybetti'); }
    return true;
  }

  function adim(o, dt) {
    if (o.bitti) return;
    var p = o.p, d = o.dunya;
    o.sure += dt;
    if (p.dokunulmaz > 0) p.dokunulmaz -= dt;
    if (p.tampon > 0) p.tampon -= dt;
    if (o.miknatis > 0) o.miknatis -= dt;
    if (o.sonsuz) sonsuzUret(o);

    var v = hiz(o) * (p.turbo && p.kayis > 0 ? S.turboCarpan : 1);
    if (!p.dusuyor) p.x += v * dt;

    // Dikey hareket
    var delik = cukurda(o, p.x);
    if (p.yerde && delik) { p.yerde = false; p.kojot = o.ayar.kojot; p.vy = 0; if (p.zipSayisi === 0) p.zipSayisi = 1; }
    if (!p.yerde) {
      if (p.kojot > 0) p.kojot -= dt;
      p.vy -= S.yercekimi * dt;
      p.y += p.vy * dt;
      if (p.y <= 0) {
        if (cukurda(o, p.x) && !p.dusuyor && p.y > -26 && p.vy < 0) {
          p.dusuyor = true; p.kayis = 0; p.turbo = false;
        } else if (!p.dusuyor && !cukurda(o, p.x)) {
          p.y = 0; p.vy = 0; p.yerde = true; p.zipSayisi = 0; p.kojot = 0;
          olay(o, 'indi');
          if (p.tampon > 0) { zipla(o); }
          else if (p.kuyrukKayis) {
            var t = p.turbo;
            p.kuyrukKayis = false;
            p.kayis = t ? o.ayar.turbo : o.ayar.kayis;
            olay(o, t ? 'turbo' : 'kay');
          }
        }
      }
      if (p.dusuyor && p.y < -170) {
        var c = cukurda(o, p.x);
        var sonra = c ? c.x + c.w + 46 : p.x + 60;
        p.dokunulmaz = 0;
        o.kalkan = false;
        hasarVer(o, 'cukur');
        p.dusuyor = false; p.x = sonra; p.y = 0; p.vy = 0; p.yerde = true; p.zipSayisi = 0; p.kuyrukKayis = false;
      }
    }

    // Kayış süresi
    if (p.kayis > 0 && p.yerde) {
      p.kayis -= dt;
      if (p.kayis <= 0) {
        if (p.turbo && altindaTavanVar(o)) p.kayis = 0.05;
        else { p.kayis = 0; p.turbo = false; }
      }
    }

    var boy = (p.kayis > 0 && p.yerde) ? S.boyKayarken : S.boyAyakta;
    var sol = p.x - S.genislik / 2, sag = p.x + S.genislik / 2;

    // Engeller
    for (var i = 0; i < d.engeller.length; i++) {
      var e = d.engeller[i];
      if (e.hareket) {
        if (!e.tetik && e.x - p.x < 560) e.tetik = true;
        if (e.tetik) e.x -= e.hareket * dt;
      }
      if (e.gecti || e.kirildi) continue;
      var pay = (e.y0 > 0 ? 2 : (e.tur === 'yuksek' ? 9 : 5)) + (e.tur === 'tunel' ? 0 : o.ayar.pay); // affedici kenar payı
      if (sag > e.x + pay && sol < e.x + e.w - pay && p.y < e.y1 - 6 && p.y + boy > e.y0 + 2) {
        if (e.tur === 'koli' && p.turbo && p.kayis > 0) {
          e.kirildi = true; o.bonus += 25; olay(o, 'kirdi', e);
        } else if (!p.dusuyor) {
          e.gecti = true;
          hasarVer(o, e.tur);
          if (o.bitti) return;
        }
      }
    }

    // Toplanabilirler
    var merkezY = p.y + boy / 2;
    for (var j = 0; j < d.nesneler.length; j++) {
      var n = d.nesneler[j];
      if (n.alindi) continue;
      if (o.miknatis > 0 && n.tur === 'tarak') {
        var dx = p.x - n.x, dy = merkezY - n.y, uzaklik = Math.sqrt(dx * dx + dy * dy);
        if (uzaklik < 190) { n.x += dx * Math.min(1, dt * 11) + v * dt; n.y += dy * Math.min(1, dt * 11); }
      }
      if (Math.abs(n.x - p.x) < 34 && n.y > p.y - 18 && n.y < p.y + boy + 18) {
        n.alindi = true;
        if (n.tur === 'tarak') { o.tarak += 1; olay(o, 'tarak', n); }
        else if (n.tur === 'kalkan') { o.kalkan = true; olay(o, 'kalkan', n); }
        else if (n.tur === 'miknatis') { o.miknatis = 7; olay(o, 'miknatis', n); }
        else if (n.tur === 'sandik') { o.sandik += 1; olay(o, 'sandik', n); }
        else if (n.tur === 'parca') { o.parca += 1; olay(o, 'parca', n); }
        else if (n.tur === 'kalp') { o.can = Math.min(o.canMax, o.can + 1); olay(o, 'kalp', n); }
      }
    }

    if (!o.sonsuz) {
      var sonraki = d.kontroller[o.kontrolSayisi];
      if (sonraki && p.x >= sonraki) {
        o.kontrolSayisi++;
        o.kontrolKaydi = { x: sonraki, no: o.kontrolSayisi, tarak: o.tarak, bonus: o.bonus, sure: o.sure, hasar: o.hasar };
        olay(o, 'kontrol');
      }
      if (p.x >= d.uzunluk && !p.dusuyor) { o.bitti = true; o.kazandi = true; olay(o, 'kazandi'); }
    }
  }

  // Yarı yoldaki bayraktan devam eder (yalnızca izin veren modlarda). Devam eden koşu 3. yıldızı alamaz.
  function kontroldenDevam(eski) {
    if (!eski || eski.sonsuz || !eski.ayar.devam || !eski.kontrolKaydi) return null;
    var o = yeniOyun(eski.bolum, eski.mod), k = eski.kontrolKaydi, x = k.x;
    o.hizCarpani = eski.hizCarpani;
    o.p.x = x; o.p.dokunulmaz = 1.2;
    o.tarak = k.tarak; o.bonus = k.bonus; o.sure = k.sure; o.sureBaslangic = k.sure;
    o.hasar = Math.max(1, k.hasar);
    o.kontrolSayisi = k.no; o.kontrolKaydi = k; o.devamli = true;
    o.dunya.engeller.forEach(function (e) { if (e.x < x) e.gecti = true; });
    o.dunya.nesneler.forEach(function (n) { if (n.x < x + 10) n.alindi = true; });
    return o;
  }

  function skor(o) {
    var s = o.tarak * 10 + o.bonus;
    if (o.sonsuz) s += Math.floor(o.p.x / 20);
    else if (o.kazandi) s += 500 + o.bolum * 50 + Math.min(3, o.can) * 150;
    return Math.floor(s * o.ayar.puan);
  }

  function yildiz(o) {
    if (!o.kazandi) return 0;
    var oran = o.dunya.toplamTarak ? o.tarak / o.dunya.toplamTarak : 1;
    return 1 + (oran >= 0.6 ? 1 : 0) + (o.hasar === 0 ? 1 : 0);
  }

  return {
    S: S, MODLAR: MODLAR, DUNYALAR: DUNYALAR, BOLUMLER: BOLUMLER,
    bolumKur: bolumKur, yeniOyun: yeniOyun, kontroldenDevam: kontroldenDevam, adim: adim, zipla: zipla, kay: kay,
    hiz: hiz, skor: skor, yildiz: yildiz
  };
});
