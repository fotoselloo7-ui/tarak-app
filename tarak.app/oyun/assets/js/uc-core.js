/* 3D koşu (üç şeritli) çekirdeği — DOM'suz; testlerde Node ile de çalışır.
 * s = yol üzerindeki mesafe (metre), serit = -1 | 0 | 1, y = yerden yükseklik (metre). */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory(require('./iller.js'));
  else root.TarakUc = factory(root.TarakIller);
})(typeof self !== 'undefined' ? self : this, function (IL) {
  'use strict';

  var S = {
    serit: 1.8, yercekimi: 36, zipla1: 10.2, zipla2: 8.95, hizliDusus: 16,
    boy: 1.75, boyKayarken: 0.75, yarimEn: 0.42, yarimDerinlik: 0.3,
    turboCarpan: 1.32, seritHizi: 19
  };

  var MODLAR = {
    kolay: { ad: 'Kolay', simge: '😊', hiz: 11.5, ustHiz: 19, artis: 2200, can: 5, ara: 1.45, kayis: 0.95, turbo: 1.9, durak: 350, puan: 1, dokunulmaz: 2.2, hareketli: false, pay: 0.12 },
    orta:  { ad: 'Orta', simge: '😎', hiz: 13, ustHiz: 23, artis: 2000, can: 4, ara: 1.18, kayis: 0.82, turbo: 1.65, durak: 450, puan: 1.5, dokunulmaz: 1.9, hareketli: true, pay: 0.07 },
    zor:   { ad: 'Zor', simge: '🔥', hiz: 15, ustHiz: 27, artis: 1800, can: 3, ara: 0.98, kayis: 0.7, turbo: 1.45, durak: 550, puan: 2, dokunulmaz: 1.6, hareketli: true, pay: 0.03 }
  };

  // y0..y1: engelin kapladığı yükseklik; boy: yol yönündeki uzunluk
  var ENGELLER = {
    bariyer: { y0: 0, y1: 0.85, boy: 0.5, gec: 'zipla' },
    koli:    { y0: 0, y1: 0.95, boy: 0.8, gec: 'zipla', kirilir: true },
    cukur:   { y0: -1, y1: 0.04, boy: 2.2, gec: 'zipla' },
    kapi:    { y0: 1.05, y1: 3.6, boy: 0.6, gec: 'kay' },
    tunel:   { y0: 1.05, y1: 3.6, boy: 14, gec: 'turbo' },
    kule:    { y0: 0, y1: 1.95, boy: 0.8, gec: 'cift' },
    arac:    { y0: 0, y1: 4, boy: 4.4, gec: 'serit' },
    // Rampa: üstünden koşulur, otobüsün tavanına çıkarır (çarpışmaz)
    rampa:   { y0: 0, y1: 0, boy: 6, gec: 'bos', zemin: true },
    // Park etmiş otobüs: tavanı zemin olur; önüne ya da yanına çarpılır
    otobus:  { y0: 0, y1: 2.4, boy: 11, gec: 'ust', zemin: true },
    // Otobüsün üstüne park edilmiş küçük araba: çift zıplayarak aşılır
    aracUstu: { y0: 2.4, y1: 3.5, boy: 3, gec: 'cift' }
  };
  var TAVAN = 2.4;

  var MUSTERILER = ['Mehmet Bey', 'Hasan Usta', 'Emre Abi', 'Burak Bey', 'Kemal Amca', 'Onur Bey', 'Orman Bekçisi', 'Kampçı Can', 'Balıkçı Rıza', 'Avcı Selim', 'Bakıcı Ayşe', 'Aslan Kral'];
  var MUSTERILER_ORMAN = ['Orman Bekçisi', 'Kampçı Can', 'Safari Rehberi Ali', 'Balıkçı Rıza', 'Avcı Selim', 'Bakıcı Ayşe', 'Aslan Kral'];
  // Kadın kuaför modu (tarak.app Kadın Kuaför hizmetleri)
  var MUSTERILER_K = ['Ayşe Hanım', 'Zeynep Hanım', 'Elif Hanım', 'Selin Hanım', 'Merve Hanım', 'Derya Abla', 'Gelin Buse', 'Esra Hanım', 'Defne Hanım', 'Nazlı Hanım', 'Ece Hanım', 'Kraliçe Leyla'];
  var MUSTERILER_ORMAN_K = ['Bekçi Gül', 'Kampçı Ece', 'Safari Rehberi Defne', 'Balıkçı Nazlı', 'Bakıcı Ayşe', 'Aslan Kraliçe'];
  var HIZMETLER_K = ['Manikür', 'Pedikür', 'Fön', 'Saç Kesimi', 'Dip Boya', 'Röfle / Ombre', 'Gelin Başı', 'Günlük Makyaj', 'Kaş Tasarımı', 'Manikür + Pedikür', 'Tüm Boya', 'Porselen Makyaj'];
  var HIZMETLER_E = ['Saç Kesimi', 'Sakal Tıraşı', 'Saç & Sakal (VIP)', 'Fön', 'Çocuk Tıraşı'];
  var DUNYALAR = ['sehir', 'otoyol', 'orman', 'in'];
  var DOGA = { orman: true, in: true };
  /* 30 rota: dünyalar sırayla döner. saat: sabah | oglen | aksam | gece ; hava: acik | bulutlu | sis | yagmur | kar
   * trafik: hareketli araç sıklığı çarpanı ; hiz: koşu hızı çarpanı */
  /* Rotalar: Türkiye'nin 81 ilinin 973 ilçesi (iller.js). Konuma bağlı değil; herkes istediği ili açıp oynayabilir. */
  var ROTALAR = IL.ROTALAR;
  var VARSAYILAN_ROTA = (function () { for (var i = 0; i < ROTALAR.length; i++) if (ROTALAR[i].il === 'İstanbul' && ROTALAR[i].ilce === 'Beyoğlu') return i + 1; return 1; })();
  function rotaAl(r) {
    if (typeof r === 'number' && ROTALAR[r - 1]) return r;
    var n = parseInt(r, 10);
    if (n && ROTALAR[n - 1]) return n;
    return VARSAYILAN_ROTA;
  }
  function musteriAdi(o, no) {
    var d = o.rotaT.dunyalar, doga = DOGA[d[no % d.length]];
    var l = o.kadin ? (doga ? MUSTERILER_ORMAN_K : MUSTERILER_K) : (doga ? MUSTERILER_ORMAN : MUSTERILER);
    return l[no % l.length];
  }
  function hizmetAdi(o, no) { var l = o.kadin ? HIZMETLER_K : HIZMETLER_E; return l[(no + (o.rota || 1)) % l.length]; }

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

  function yeniOyun(modAdi, secenek) {
    secenek = secenek || {};
    var ad = MODLAR[modAdi] ? modAdi : 'kolay';
    var m = MODLAR[ad];
    var o = {
      mod: ad, ayar: m, canMax: m.can, can: m.can, kadin: !!secenek.kadin, rota: rotaAl(secenek.rota), rotaT: ROTALAR[rotaAl(secenek.rota) - 1],
      p: { s: 0, serit: 0, oncekiSerit: 0, x: 0, y: 0, vy: 0, yerde: true, zipSayisi: 0, kayis: 0, turbo: false, kuyrukKayis: false, dokunulmaz: 0, tampon: 0 },
      engeller: [], nesneler: [], duraklar: [], olaylar: [],
      tarak: 0, bonus: 0, sure: 0, mesafePuani: 0, musteri: 0, sandik: 0, kirilan: 0, ziplama: 0, kayma: 0, parca: 0,
      kalkan: !!secenek.kalkan, miknatis: secenek.miknatis ? 12 : 0, ikiKat: 0, jet: 0,
      bitti: false, kazandi: false, sonNeden: '', devamHakki: 1, hizCarpani: 1,
      hedefMusteri: secenek.sinirsiz ? Infinity : rotaHedefi(rotaAl(secenek.rota)),
      _r: rastgele(secenek.tohum || ((Date.now() & 0x7fffffff) || 1)), _uretim: 34, _sira: 0, _durakSira: m.durak, _id: 0, _guvenli: 0
    };
    // Gerçek cadde (OpenStreetMap verisi olan ilçe): rotanın tamamı o caddede geçer (otoyol/orman/in kesimleri yok),
    // duraklar caddenin boyuna yayılır; son durak caddenin sonundadır, cadde tekrar etmez.
    var g = secenek.gercek;
    if (g && g.uzunluk > 0 && !secenek.sinirsiz) {
      o.rotaT = Object.assign({}, o.rotaT, { dunyalar: ['sehir'], gercek: true });
      var L = Math.max(320, g.uzunluk - 30);
      o.hedefMusteri = Math.max(2, Math.min(o.hedefMusteri, Math.floor(L / 200)));
      o._gercekAralik = L / o.hedefMusteri;
      o._durakSira = o._gercekAralik;
    }
    uret(o);
    return o;
  }

  // Rota sonu: ilk rotalarda 3 müşteri, sonrakilerde 6'ya kadar artar
  // Rota sonu: il merkezi ve ilk ilçeler 3 müşteri, ilin sonraki ilçelerinde 6'ya kadar artar
  function rotaHedefi(r) { var t = ROTALAR[r - 1]; return Math.min(6, 3 + Math.floor(((t && t.sira) || 0) / 5)); }

  function temelHiz(o, s) {
    var m = o.ayar;
    return (m.hiz + (m.ustHiz - m.hiz) * Math.min(1, (s === undefined ? o.p.s : s) / m.artis)) * o.hizCarpani;
  }
  function hiz(o) { return temelHiz(o) * (o.p.turbo && o.p.kayis > 0 ? S.turboCarpan : 1) * (o.jet > 0 ? 1.45 : 1); }

  function engelEkle(o, tur, serit, s, ek) {
    var t = ENGELLER[tur];
    var e = { id: ++o._id, tur: tur, serit: serit, s: s, boy: t.boy, y0: t.y0, y1: t.y1, gecti: false, kirildi: false, hareket: 0, tetik: false, cesit: Math.floor(o._r() * 3) };
    if (ek) for (var k in ek) e[k] = ek[k];
    o.engeller.push(e);
    return e;
  }
  function nesne(o, tur, serit, s, y) { o.nesneler.push({ id: ++o._id, tur: tur, x: serit * S.serit, serit: serit, s: s, y: y, alindi: false }); }

  function tarakDizisi(o, serit, s, adet, y) { for (var i = 0; i < adet; i++) nesne(o, 'tarak', serit, s + i * 1.5, y); }
  function tarakYayi(o, serit, merkez, v) {
    for (var i = 0; i < 5; i++) {
      var k = i / 4;
      nesne(o, 'tarak', serit, merkez - v * 0.26 + k * v * 0.52, 0.7 + Math.sin(k * Math.PI) * 0.95);
    }
  }

  function karistir(r, dizi) {
    for (var i = dizi.length - 1; i > 0; i--) { var j = Math.floor(r() * (i + 1)); var t = dizi[i]; dizi[i] = dizi[j]; dizi[j] = t; }
    return dizi;
  }

  /* Her satırda en az bir şerit şerit değiştirmeden ya da tek hareketle geçilebilir olur. */
  function satirUret(o, s) {
    var r = o._r, v = temelHiz(o, s), uzaklik = s;
    var seritler = karistir(r, [-1, 0, 1]);
    var havuz = ['tekli', 'tekli', 'ikili'];
    if (uzaklik > 90) havuz.push('kapili', 'araclar', 'ikili');
    if (uzaklik > 220) havuz.push('kuleli', 'koliler', 'cukurlu', 'duzSira');
    if (uzaklik > 420) havuz.push('tunelli', 'karisik', 'araclar');
    if (uzaklik > 150) havuz.push('konvoy');
    if (uzaklik > 380) havuz.push('konvoy');
    if (uzaklik > 520 && o.ayar.hareketli) havuz.push('gelenArac');
    if (uzaklik > 60) for (var tq = 0; tq < Math.round(2 * o.rotaT.trafik); tq++) havuz.push('trafik');
    var ilk = [['tekli'], ['trafik'], ['kapili']];
    var kalip = o._sira < ilk.length ? ilk[o._sira][0] : havuz[Math.floor(r() * havuz.length)];
    o._sira++;
    var a = seritler[0], b = seritler[1], c = seritler[2], uz = 1;

    if (kalip === 'tekli') {
      engelEkle(o, r() < 0.7 ? 'bariyer' : 'koli', a, s);
      tarakYayi(o, a, s, v);
      tarakDizisi(o, b, s - 3, 5, 0.7);
    } else if (kalip === 'ikili') {
      engelEkle(o, 'bariyer', a, s); engelEkle(o, r() < 0.5 ? 'koli' : 'bariyer', b, s);
      tarakDizisi(o, c, s - 4, 6, 0.7);
    } else if (kalip === 'kapili') {
      engelEkle(o, 'kapi', a, s); engelEkle(o, 'kapi', b, s);
      if (r() < 0.5) engelEkle(o, 'kapi', c, s);
      tarakDizisi(o, a, s - 3, 5, 0.4);
    } else if (kalip === 'araclar') {
      uz = ENGELLER.arac.boy;
      engelEkle(o, 'arac', a, s);
      if (r() < 0.65) engelEkle(o, 'arac', b, s + (r() < 0.5 ? 0 : 0.6));
      tarakDizisi(o, c, s - 2, 6, 0.7);
    } else if (kalip === 'kuleli') {
      engelEkle(o, 'kule', a, s); engelEkle(o, 'kule', b, s); engelEkle(o, 'bariyer', c, s);
      tarakYayi(o, c, s, v);
      nesne(o, 'tarak', a, s - v * 0.08, 2.3); nesne(o, 'tarak', a, s + v * 0.08, 2.7);
      if (r() < 0.25) nesne(o, 'parca', b, s + 0.4, 3.9);   // kulenin tepesinde: çift zıplama
    } else if (kalip === 'koliler') {
      engelEkle(o, 'koli', -1, s); engelEkle(o, 'koli', 0, s); engelEkle(o, 'koli', 1, s);
      tarakDizisi(o, a, s - 6, 4, 0.4); tarakDizisi(o, a, s + 2, 3, 0.4);
    } else if (kalip === 'cukurlu') {
      uz = ENGELLER.cukur.boy;
      engelEkle(o, 'cukur', a, s); engelEkle(o, 'cukur', b, s);
      tarakYayi(o, a, s + 1.1, v);
    } else if (kalip === 'duzSira') {
      var tur = r() < 0.5 ? 'bariyer' : 'kapi';
      engelEkle(o, tur, -1, s); engelEkle(o, tur, 0, s); engelEkle(o, tur, 1, s);
      if (tur === 'bariyer') tarakYayi(o, 0, s, v); else tarakDizisi(o, 0, s - 3, 5, 0.4);
    } else if (kalip === 'tunelli') {
      uz = Math.round(v * 1.15);
      engelEkle(o, 'tunel', a, s, { boy: uz }); engelEkle(o, 'arac', b, s, { boy: uz });
      tarakDizisi(o, a, s + 1, Math.floor(uz / 1.5), 0.4);
    } else if (kalip === 'karisik') {
      engelEkle(o, 'bariyer', a, s); engelEkle(o, 'kapi', b, s); engelEkle(o, 'arac', c, s);
      uz = ENGELLER.arac.boy;
      tarakDizisi(o, b, s - 3, 5, 0.4);
    } else if (kalip === 'trafik') {
      // Aynı yönde yavaş ilerleyen araç. Oyuncu ona yetişene kadar o şerit boş tutulur.
      var vNow = temelHiz(o), u = vNow * 0.32;
      var bulus = Math.max(0, s - o.p.s) * u / (vNow - u);
      uz = Math.round(bulus + 34);
      if (s + uz > o._durakSira - 30) {
        engelEkle(o, 'bariyer', a, s); tarakYayi(o, a, s, v); tarakDizisi(o, b, s - 3, 5, 0.7);
        uz = 1;
      } else {
        engelEkle(o, 'arac', a, s, { ileri: u, cesit: 4 });
        tarakDizisi(o, a, s - 7, 4, 0.7);
        var adimK = Math.max(16, v * o.ayar.ara * 0.95);
        for (var kk = s + 12; kk < s + uz - 6; kk += adimK) {
          var dolu = r() < 0.5 ? b : c, bos = dolu === b ? c : b, t = r();
          engelEkle(o, t < 0.45 ? 'bariyer' : t < 0.75 ? 'kapi' : 'koli', dolu, kk);
          tarakDizisi(o, bos, kk - 3, 4, 0.7);
        }
      }
    } else if (kalip === 'konvoy' && s + 50 < o._durakSira - 30) {
      // Rampa + arka arkaya park etmiş otobüsler: üstüne çıkıp tavanlarda koşulur
      var adet = 2 + (uzaklik > 380 && r() < 0.5 ? 1 : 0), ob = ENGELLER.otobus.boy, x = s + ENGELLER.rampa.boy;
      engelEkle(o, 'rampa', a, s, { ust: TAVAN });
      for (var oi = 0; oi < adet; oi++) {
        engelEkle(o, 'otobus', a, x, { ust: TAVAN, cesit: oi });
        if (oi === adet - 1 && r() < 0.75) {
          engelEkle(o, 'aracUstu', a, x + 4, { taban: TAVAN });
          // Hediye parçası: tavandaki arabanın üstünde, ancak çift zıplamayla alınır
          if (r() < 0.45) nesne(o, 'parca', a, x + 5.5, TAVAN + 3.3);
        }
        tarakDizisi(o, a, x + 0.8, 6, TAVAN + 0.7);
        x += ob + 0.4;
      }
      uz = x - s;
      tarakDizisi(o, a, s + 1, 4, 0.9);
      // Yandaki şeritlerden biri engelli, biri serbest
      engelEkle(o, 'bariyer', b, s + 3);
      engelEkle(o, r() < 0.5 ? 'kapi' : 'koli', b, s + uz * 0.55);
      tarakDizisi(o, c, s + 2, 6, 0.7);
    } else if (kalip === 'konvoy') {
      engelEkle(o, 'bariyer', a, s); tarakYayi(o, a, s, v); tarakDizisi(o, b, s - 3, 5, 0.7);
    } else if (kalip === 'gelenArac') {
      uz = ENGELLER.arac.boy + 16;
      engelEkle(o, 'arac', a, s + 22, { hareket: 5.5, cesit: 3 });
      tarakDizisi(o, b, s + 4, 8, 0.7);
    }

    // Arada bir güç, kalp ve sandık
    var z = s - v * 0.55;
    var zar = r();
    if (zar < 0.035) nesne(o, 'miknatis', c, z, 0.9);
    else if (zar < 0.065) nesne(o, 'kalkan', c, z, 0.9);
    else if (zar < 0.095) nesne(o, 'ikikat', c, z, 0.9);
    else if (zar < 0.115 && uzaklik > 150) nesne(o, 'jet', c, z, 0.9);
    else if (zar < 0.14 && uzaklik > 200) nesne(o, 'kalp', c, z, 0.9);
    else if (zar < 0.165) nesne(o, 'sandik', c, z, 0.7);
    return uz;
  }

  function uret(o) {
    while (o._uretim < o.p.s + 150) {
      var s = o._uretim;
      // Müşteri durağının çevresi boş bırakılır
      if (o.duraklar.length >= o.hedefMusteri) { o._uretim = Infinity; break; }   // son duraktan sonra yol boş: bitiş
      if (s > o._durakSira - 26) {
        var no = o.duraklar.length;
        o.duraklar.push({ no: no, s: o._durakSira, ad: musteriAdi(o, no), hizmet: hizmetAdi(o, no), gecildi: false, son: no + 1 >= o.hedefMusteri });
        tarakDizisi(o, 0, o._durakSira - 14, 8, 0.7);
        o._uretim = o._durakSira + 24;
        o._durakSira += o._gercekAralik || (o.ayar.durak + no * 40);
        continue;
      }
      var uz = satirUret(o, s);
      var v = temelHiz(o, s);
      o._uretim = s + uz + v * o.ayar.ara * (1 + o._r() * 0.3);
    }
    var sinir = o.p.s - 12;
    o.engeller = o.engeller.filter(function (e) { return e.s + e.boy > sinir; });
    o.nesneler = o.nesneler.filter(function (n) { return n.s > sinir && !n.alindi; });
  }

  function olay(o, tur, ek) { o.olaylar.push({ tur: tur, ek: ek }); }

  function seritDegistir(o, yon) {
    if (o.bitti) return;
    var p = o.p, hedef = Math.max(-1, Math.min(1, p.serit + yon));
    if (hedef === p.serit) return;
    p.oncekiSerit = p.serit; p.serit = hedef;
    olay(o, 'serit');
  }

  function zipla(o) {
    if (o.bitti || o.jet > 0) return;
    var p = o.p;
    if (p.yerde) {
      p.vy = S.zipla1; p.yerde = false; p.zipSayisi = 1; p.kayis = 0; p.turbo = false; p.kuyrukKayis = false; p.tampon = 0;
      o.ziplama++; olay(o, 'zipla');
    } else if (p.zipSayisi < 2) {
      p.vy = S.zipla2; p.zipSayisi = 2; p.kuyrukKayis = false; o.ziplama++; olay(o, 'zipla2');
    } else p.tampon = 0.16;
  }

  function kay(o) {
    if (o.bitti || o.jet > 0) return;
    var p = o.p;
    if (!p.yerde) {
      if (p.kuyrukKayis) p.turbo = true;
      p.kuyrukKayis = true; p.vy = Math.min(p.vy, -S.hizliDusus);
      return;
    }
    if (p.kayis > 0) {
      if (!p.turbo) { p.turbo = true; p.kayis = o.ayar.turbo; olay(o, 'turbo'); }
      return;
    }
    p.kayis = o.ayar.kayis; p.turbo = false; o.kayma++; olay(o, 'kay');
  }

  function altindaTunel(o) {
    var p = o.p;
    return o.engeller.some(function (e) { return e.tur === 'tunel' && !e.gecti && e.serit === p.serit && p.s + 0.3 > e.s && p.s - 0.3 < e.s + e.boy; });
  }

  // Oyuncunun bulunduğu yerdeki zemin yüksekliği (rampa ve otobüs tavanları). rampa: en yüksek zemin rampa mı
  function zeminAl(o, s, x) {
    var z = 0, rampa = false;
    for (var i = 0; i < o.engeller.length; i++) {
      var e = o.engeller[i];
      if (!e.ust || e.gecti) continue;
      if (Math.abs(x - e.serit * S.serit) > 0.7) continue;
      if (e.tur === 'rampa') {
        var on = s + 0.4;
        if (on > e.s && s - S.yarimDerinlik < e.s + e.boy) { var h = e.ust * Math.min(1, (on - e.s) / e.boy); if (h > z) { z = h; rampa = true; } }
      } else if (s + S.yarimDerinlik > e.s && s - S.yarimDerinlik < e.s + e.boy && e.ust >= z) { z = e.ust; rampa = false; }
    }
    return { y: z, rampa: rampa };
  }

  function hasar(o, neden) {
    if (o.p.dokunulmaz > 0) return;
    if (o.kalkan) { o.kalkan = false; o.p.dokunulmaz = o.ayar.dokunulmaz; olay(o, 'kalkanKirildi'); return; }
    o.can--; o.sonNeden = neden; o.p.dokunulmaz = o.ayar.dokunulmaz;
    olay(o, 'carpti', neden);
    if (o.can <= 0) { o.bitti = true; olay(o, 'kaybetti'); }
  }

  // Bir kez: tükenen oyuncu kaldığı yerden devam eder (arayüz bunun karşılığında tarak alır).
  function devamEt(o) {
    if (!o.bitti || o.devamHakki < 1) return false;
    o.devamHakki--; o.bitti = false; o.can = 2; o.p.dokunulmaz = 3;
    var s = o.p.s;
    o.engeller = o.engeller.filter(function (e) { return e.s > s + 30 || e.s + e.boy < s - 2; });
    o.p.y = 0; o.p.vy = 0; o.p.yerde = true; o.p.zipSayisi = 0; o.p.kayis = 0; o.p.turbo = false; o.p.kuyrukKayis = false;
    olay(o, 'devam');
    return true;
  }

  function adim(o, dt) {
    if (o.bitti) return;
    var p = o.p;
    o.sure += dt;
    if (p.dokunulmaz > 0) p.dokunulmaz -= dt;
    if (p.tampon > 0) p.tampon -= dt;
    if (o.miknatis > 0) o.miknatis -= dt;
    if (o.ikiKat > 0) o.ikiKat -= dt;

    var v = hiz(o), ilerleme = v * dt;
    p.s += ilerleme;
    o.mesafePuani += ilerleme * (o.ikiKat > 0 ? 2 : 1);

    var hedefX = p.serit * S.serit, fark = hedefX - p.x, adimX = S.seritHizi * dt;
    p.x += Math.abs(fark) <= adimX ? fark : (fark > 0 ? adimX : -adimX);

    if (o.jet > 0) {
      o.jet -= dt;
      p.y += (3.4 - p.y) * Math.min(1, dt * 6);
      p.yerde = false; p.vy = 0; p.kayis = 0; p.turbo = false; p.zipSayisi = 2;
      if (o.jet <= 0) { o.jet = 0; p.dokunulmaz = Math.max(p.dokunulmaz, 2.4); olay(o, 'jetBitti'); }
    } else {
      var zm = zeminAl(o, p.s, p.x);
      if (p.yerde) {
        if (zm.y < p.y - 0.05) { p.yerde = false; p.vy = 0; p.zipSayisi = Math.max(1, p.zipSayisi); }   // kenardan düştü
        else if (zm.y <= p.y + (zm.rampa ? 1.6 : 0.6)) p.y = zm.y;                                         // rampa / tavan
      }
    }
    if (o.jet <= 0 && !p.yerde) {
      var onceY = p.y;
      p.vy -= S.yercekimi * dt;
      p.y += p.vy * dt;
      var zz = zeminAl(o, p.s, p.x), taban = (onceY >= zz.y - 0.35 || zz.rampa) ? zz.y : 0;
      if (p.y <= taban) {
        p.y = taban; p.vy = 0; p.yerde = true; p.zipSayisi = 0; olay(o, 'indi');
        if (p.tampon > 0) zipla(o);
        else if (p.kuyrukKayis) {
          var t = p.turbo;
          p.kuyrukKayis = false; p.kayis = t ? o.ayar.turbo : o.ayar.kayis; o.kayma++;
          olay(o, t ? 'turbo' : 'kay');
        }
      }
    }
    if (p.kayis > 0 && p.yerde) {
      p.kayis -= dt;
      if (p.kayis <= 0) {
        if (p.turbo && altindaTunel(o)) p.kayis = 0.05;
        else { p.kayis = 0; p.turbo = false; }
      }
    }

    var boy = (p.kayis > 0 && p.yerde) ? S.boyKayarken : S.boy;
    for (var i = 0; i < o.engeller.length; i++) {
      var e = o.engeller[i];
      if (e.ileri) e.s += e.ileri * dt;
      if (e.hareket) {
        if (!e.tetik && e.s - p.s < 48) { e.tetik = true; olay(o, 'korna'); }
        if (e.tetik) e.s -= e.hareket * dt;
      }
      // Yan şeritten geçen aracın sesi
      if ((e.ileri || e.hareket) && !e.vin && !e.gecti && p.s > e.s + e.boy * 0.5 && Math.abs(e.serit - p.serit) === 1) { e.vin = true; olay(o, 'vin'); }
      if (e.gecti || e.kirildi || o.jet > 0) continue;
      if (p.s + S.yarimDerinlik <= e.s || p.s - S.yarimDerinlik >= e.s + e.boy) continue;
      var yanFark = Math.abs(p.x - e.serit * S.serit);
      var en = S.yarimEn + 0.62 - o.ayar.pay;
      if (yanFark >= en) continue;
      var payY = o.ayar.pay;
      if (!(p.y < e.y1 - payY && p.y + boy > e.y0 + 0.04)) continue;
      if (ENGELLER[e.tur].kirilir && p.turbo && p.kayis > 0) { e.kirildi = true; o.kirilan++; o.bonus += 25; olay(o, 'kirdi', e); continue; }
      // Uzun engele yandan girildiyse oyuncu eski şeridine geri seker
      var yandan = p.s > e.s + 0.5 && p.serit === e.serit && p.oncekiSerit !== e.serit && yanFark > 0.25;
      if (yandan) { p.serit = p.oncekiSerit; p.dokunulmaz > 0 || hasar(o, 'yan'); }
      else { e.gecti = true; e.ileri = 0; hasar(o, e.tur); }
      if (o.bitti) return;
    }

    var merkezY = p.y + boy / 2;
    for (var j = 0; j < o.nesneler.length; j++) {
      var n = o.nesneler[j];
      if (n.alindi) continue;
      var ds = n.s - p.s;
      if (o.miknatis > 0 && n.tur === 'tarak' && ds < 9 && ds > -1.5) {
        n.x += (p.x - n.x) * Math.min(1, dt * 10); n.y += (merkezY - n.y) * Math.min(1, dt * 10); n.s -= ds * Math.min(1, dt * 7);
        ds = n.s - p.s;
      }
      if (Math.abs(ds) < 0.7 + ilerleme / 2 && Math.abs(n.x - p.x) < 0.85 && n.y > p.y - 0.35 && n.y < p.y + boy + 0.45) {
        n.alindi = true;
        if (n.tur === 'tarak') { o.tarak += o.ikiKat > 0 ? 2 : 1; olay(o, 'tarak', n); }
        else if (n.tur === 'kalkan') { o.kalkan = true; olay(o, 'kalkan'); }
        else if (n.tur === 'miknatis') { o.miknatis = 8; olay(o, 'miknatis'); }
        else if (n.tur === 'ikikat') { o.ikiKat = 10; olay(o, 'ikikat'); }
        else if (n.tur === 'kalp') { o.can = Math.min(o.canMax, o.can + 1); olay(o, 'kalp'); }
        else if (n.tur === 'sandik') { o.sandik++; olay(o, 'sandik'); }
        else if (n.tur === 'parca') { o.parca++; olay(o, 'parca'); }
        else if (n.tur === 'jet') {
          o.jet = 6; olay(o, 'jet');
          var jv = temelHiz(o) * 1.45;
          for (var k = 0; k < 36; k++) nesne(o, 'tarak', [0, 1, 0, -1][Math.floor(k / 9)], p.s + jv * 0.7 + k * (jv * 4.6 / 36), 3.9);
        }
      }
    }

    for (var d = 0; d < o.duraklar.length; d++) {
      var dr = o.duraklar[d];
      if (!dr.gecildi && p.s >= dr.s) {
        dr.gecildi = true; o.musteri++;
        var odul = 150 + dr.no * 50;
        o.bonus += odul; o.sandik++;
        o.can = Math.min(o.canMax, o.can + 1);
        olay(o, 'durak', { ad: dr.ad, hizmet: dr.hizmet, no: dr.no, odul: odul, son: dr.son });
        if (dr.son) { o.bonus += 300 + o.rota * 20; o.bitti = true; o.kazandi = true; olay(o, 'rotaBitti', { rota: o.rota }); return; }
      }
    }
    uret(o);
  }

  function skor(o) { return Math.floor((o.mesafePuani + o.tarak * 10 + o.bonus) * o.ayar.puan); }
  function dunya(o, s) {
    var n = 0, x = s === undefined ? o.p.s : s;
    for (var i = 0; i < o.duraklar.length; i++) if (x > o.duraklar[i].s + 4) n = i + 1;
    var sira = o.rotaT ? o.rotaT.dunyalar : DUNYALAR;
    return sira[n % sira.length];
  }

  return { ILLER: IL.ILLER, BOLGE_AD: IL.BOLGE_AD, VARSAYILAN_ROTA: VARSAYILAN_ROTA, rotaHedefi: rotaHedefi, ROTALAR: ROTALAR, rotaAl: rotaAl, MUSTERILER: MUSTERILER, MUSTERILER_K: MUSTERILER_K, HIZMETLER_K: HIZMETLER_K, musteriAdi: musteriAdi, hizmetAdi: hizmetAdi, S: S, MODLAR: MODLAR, ENGELLER: ENGELLER, yeniOyun: yeniOyun, adim: adim, zipla: zipla, kay: kay, seritDegistir: seritDegistir, devamEt: devamEt, hiz: hiz, temelHiz: temelHiz, skor: skor, dunya: dunya };
});
