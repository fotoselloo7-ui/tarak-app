/* Ekranlar, giriş, oyun döngüsü ve sunucu bağlantısı. */
(function () {
  'use strict';
  var C = window.TarakCore, Ciz = window.TarakCiz, Ses = window.TarakSes;
  var U = window.TarakUc, Odul = window.TarakOdul, Uc = window.TarakUcOyun;
  var AYAR = window.TARAK_AYAR || { api: 'api/index.php' };
  var $ = function (s) { return document.querySelector(s); };
  var $$ = function (s) { return Array.prototype.slice.call(document.querySelectorAll(s)); };

  // ---------- Yerel kayıt ----------
  function oku(a, v) { try { var x = JSON.parse(localStorage.getItem(a)); return x === null ? v : x; } catch (e) { return v; } }
  function yaz(a, v) { try { localStorage.setItem(a, JSON.stringify(v)); } catch (e) {} }
  var ilerleme = oku('tm_ilerleme', { acik: 1, yildiz: {}, skor: {}, sonsuz: 0 });
  var isim = oku('tm_isim', '');
  var mod = oku('tm_mod', 'kolay');          // yeni oyuncu Kolay ile başlar
  if (!C.MODLAR[mod]) mod = 'kolay';
  if (!ilerleme.mod) ilerleme.mod = {};
  var MOD_SIRA = { kolay: 1, orta: 2, zor: 3 };
  var kese = Odul.duzelt(oku('tm_kese', null));
  var ucVar = Uc.hazirla();
  var sandikKalan = 0;
  function keseKaydet() { yaz('tm_kese', kese); cuzdanYaz(); }
  function cuzdanYaz() {
    $('#cuzdan-rozet b').textContent = kese.cuzdan;
    $$('.cuzdan-yazi').forEach(function (e) { e.innerHTML = '<span class="tarak-ikon"></span> ' + Math.floor(kese.cuzdan); });
    var n = Odul.bekleyen(kese, Odul.gunAdi());
    $('#odul-nokta').textContent = n;
    $('#odul-nokta').classList.toggle('gizli', !n);
    var sv = Odul.seviyeBilgi(kese.xp);
    $('#seviye-rozet b').textContent = 'Seviye ' + sv.seviye;
    $('#seviye-rozet i').style.width = (sv.enUst ? 100 : Math.round(sv.icinde / sv.gereken * 100)) + '%';
    var sz = Odul.sezonDurum(kese, Odul.gunAdi()), b = $('#btn-sezon');
    b.classList.toggle('gizli', !sz || sz.alindi);
    if (sz) b.textContent = sz.bilgi.simge + ' ' + sz.bilgi.ad + ': hemen al!';
  }
  function sezonHediyesi() {
    if (!Odul.sezonAl(kese, Odul.gunAdi())) return;
    Ses.cal('kazandi'); keseKaydet(); kusan(); magazaCiz();
    denemeYaz('🎄 Yılbaşı kostümün giyildi, iyi seneler!');
  }
  function kusan() { Uc.kusan(kese.takili); Ciz.kusan(kese.takili); kareleriYenile(); }

  // ---------- Karakterler: Koko/Kiki maskotları ve tam vücutlu karakterler (karakterler.js) ----------
  var KR = window.TarakKarakterler;
  var karakterId = oku('tm_karakter', '') || (oku('tm_cinsiyet', '') === 'k' ? 'kiki' : 'koko');
  var sahipKarakter = oku('tm_karakterler', ['koko', 'kiki']);
  if (sahipKarakter.indexOf(karakterId) < 0) karakterId = 'koko';
  var kadin = KR.bul(karakterId).cins === 'k';
  var kareSaati = null, portreC = {};
  // 2D oyunda tam vücutlu karakterin kareleri (kıyafet değişince yeniden üretilir)
  function kareleriYenile(hemen) {
    clearTimeout(kareSaati);
    var t = KR.bul(karakterId);
    if (t.tur !== 'insan' || !window.TarakKare) { Ciz.insanKareleri(null); return; }
    var yap = function () { Ciz.insanKareleri(window.TarakKare.kareler(t.id, kese.takili)); };
    if (hemen) yap(); else kareSaati = setTimeout(yap, 60);
  }
  function portreAl(t, yakin) {
    var a = t.id + (yakin ? '|y' : '');
    if (portreC[a] === undefined) portreC[a] = window.TarakKare ? (yakin ? window.TarakKare.portre(t.id, {}, 160, 160, true) : window.TarakKare.portre(t.id, {}, 240, 300)) : null;
    return portreC[a];
  }
  function musteriAd(b) { return kadin && b.musteriK ? b.musteriK : b.musteri; }
  function fotoAd(f) { return kadin ? ({ 'foto-tiras.jpg': 'foto-yolda.jpg', 'foto-sonuc.jpg': 'foto-sofor.jpg' }[f] || f) : f; }
  function karakterUygula() {
    var t = KR.bul(karakterId);
    kadin = t.cins === 'k';
    if (Uc.kadin) Uc.kadin(kadin);
    if (Uc.karakter) Uc.karakter(t.id);
    Ciz.kadin(kadin);
    document.body.classList.toggle('kadin', kadin);
    Uc.kusan(kese.takili); Ciz.kusan(kese.takili);
    kareleriYenile(true);
    var cip = $('#btn-karakter');
    cip.querySelector('span').textContent = t.ad;
    karakterResmi(cip.querySelector('canvas'), t);
  }
  // Karakter resmi: maskot 2D çiziminden, tam vücutlu karakter 3D portresinden. Her zaman tuvale sığar (kesilmez);
  // küçük tuvalde (menü çipi) tam vücutlu karakterin yakın çekim yüzü kullanılır.
  function karakterResmi(cv, t, o, ay) {
    var c = cv.getContext('2d'), kucuk = cv.height < 120;
    c.clearRect(0, 0, cv.width, cv.height);
    o = Math.min(o || 9, (cv.height - 6) / 132); ay = cv.height - 3;
    if (t.tur === 'insan') {
      var url = portreAl(t, kucuk); if (!url) return;
      var im = new Image();
      im.onload = function () { c.clearRect(0, 0, cv.width, cv.height); var k = Math.min(cv.width / im.width, cv.height / im.height); c.drawImage(im, (cv.width - im.width * k) / 2, cv.height - im.height * k, im.width * k, im.height * k); };
      im.src = url;
      return;
    }
    var onceki = kadin, insanSecili = KR.bul(karakterId).tur === 'insan';
    Ciz.kadin(t.cins === 'k'); Ciz.kusan({});
    if (insanSecili) Ciz.insanKareleri(null);
    Ciz.maskot(c, cv.width / 2, ay, 'dur', 0, { olcek: o });
    Ciz.kadin(onceki); Ciz.kusan(kese.takili);
    if (insanSecili) kareleriYenile(true);
  }
  function karakterSec(t) {
    karakterId = t.id; yaz('tm_karakter', t.id); yaz('tm_cinsiyet', t.cins);
    karakterUygula(); Ses.cal('kalp');
    menuTost((t.cins === 'k' ? '💅 ' : '💈 ') + t.ad + ': “' + t.soz + '”');
  }
  function karakterEkrani() {
    var kap = $('#karakter-liste'); kap.innerHTML = '';
    [['e', '💈 Berberler'], ['k', '💅 Kuaförler']].forEach(function (grup) {
      var h = document.createElement('h3'); h.className = 'karakter-grup'; h.textContent = grup[1]; kap.appendChild(h);
      var izgara = document.createElement('div'); izgara.className = 'karakterler'; kap.appendChild(izgara);
      KR.LISTE.filter(function (t) { return t.cins === grup[0]; }).forEach(function (t) {
        var sahip = sahipKarakter.indexOf(t.id) >= 0, secili = t.id === karakterId;
        var b = document.createElement('button'); b.type = 'button';
        b.className = 'karakter-sec' + (secili ? ' secili' : '') + (sahip ? '' : ' kilitli');
        var cv = document.createElement('canvas'); cv.width = 150; cv.height = 170; b.appendChild(cv);
        var ad = document.createElement('b'); ad.textContent = t.ad; b.appendChild(ad);
        var kis = document.createElement('span'); kis.className = 'kisilik k-' + t.id; kis.textContent = t.kisilik; b.appendChild(kis);
        var ozl = document.createElement('small'); ozl.textContent = t.ozellik ? KR.OZELLIK[t.ozellik] : t.unvan; b.appendChild(ozl);
        var dur = document.createElement('em'); dur.textContent = secili ? '✓ Seçili' : sahip ? 'Seç' : '🔒 ' + t.fiyat + ' tarak'; b.appendChild(dur);
        b.title = t.soz;
        b.addEventListener('click', function () {
          if (sahip) { karakterSec(t); karakterEkrani(); return; }
          if (kese.cuzdan < t.fiyat) { menuTost('🔒 ' + t.ad + ' için ' + (t.fiyat - kese.cuzdan) + ' tarak daha gerekli. Koşarak tarak topla!'); return; }
          if (!confirm(t.ad + ' ' + t.fiyat + ' tarağa açılsın mı?')) return;
          kese.cuzdan -= t.fiyat; keseKaydet();
          sahipKarakter.push(t.id); yaz('tm_karakterler', sahipKarakter);
          karakterSec(t); karakterEkrani();
        });
        izgara.appendChild(b);
        karakterResmi(cv, t, 1.25, 160);
      });
    });
    ekran('karakter');
  }
  tikla('#btn-karakter-kapat', function () { ekran('ana'); });
  var tostZaman = null;
  function menuTost(metin) {
    var t = $('#menu-tost'); t.textContent = metin; t.classList.remove('gizli');
    clearTimeout(tostZaman); tostZaman = setTimeout(function () { t.classList.add('gizli'); }, 4500);
  }
  var yanmaSayisi = {};
  var rota = U.rotaAl(oku('tm_rota', 1));
  var SAAT_AD = { sabah: '🌅 Sabah', oglen: '☀️ Öğle', aksam: '🌇 Akşam', gece: '🌙 Gece' };
  var HAVA_AD = { acik: '', bulutlu: '☁️ Bulutlu', sis: '🌫️ Sisli', yagmur: '🌧️ Yağmurlu', kar: '❄️ Karlı' };
  var DUNYA_KISA = { sehir: 'Şehir', otoyol: 'Otoyol', orman: 'Orman', in: 'Savana' };
  function rotaOzet(r) { return r.dunyalar.map(function (d) { return DUNYA_KISA[d]; }).filter(function (v, i, a) { return a.indexOf(v) === i; }).join(' · ') + ' · ' + SAAT_AD[r.saat] + (HAVA_AD[r.hava] ? ' · ' + HAVA_AD[r.hava] : ''); }
  // ---------- Türkiye haritası: 81 il, 973 ilçe ----------
  // İller: başta İstanbul, Ankara, İzmir açık; her 3 tamamlanan ilçe bir il açma hakkı verir ya da tarakla açılır.
  // İlçeler: ilin ilk iki ilçesi açık; sıradaki ilçe öncekinde 1 müşteriye yetişince ya da tarakla açılır.
  var IL_FIYAT = 300, ILCE_FIYAT = 120, seciliIl = null, haritaArama = '';
  function haritaDurum() {
    if (ilerleme.harita !== 2) { ilerleme.rota = {}; ilerleme.harita = 2; }   // eski 30 rotalık ilerleme yeni haritaya taşınmaz
    ilerleme.rota = ilerleme.rota || {}; ilerleme.bitti = ilerleme.bitti || {}; ilerleme.alinan = ilerleme.alinan || {};
    if (!ilerleme.iller) ilerleme.iller = [34, 6, 35];
    return ilerleme;
  }
  function ilAcik(plaka) { return haritaDurum().iller.indexOf(plaka) >= 0; }
  function bitenSayisi() { return Object.keys(haritaDurum().bitti).length; }
  function ilHakki() { return Math.max(0, 3 + Math.floor(bitenSayisi() / 3) - haritaDurum().iller.length); }
  function rotaAcik(n) {
    var r = U.ROTALAR[n - 1], h = haritaDurum();
    if (!r || !ilAcik(r.plaka)) return false;
    return r.sira < 2 || !!h.bitti[n - 1] || (h.rota[n - 1] || 0) >= 1 || !!h.alinan[n];
  }
  // Eski sürümden kalan ya da kilitli rota seçiliyse başlangıç rotasına dön
  setTimeout(function () { if (!rotaAcik(rota)) { rota = U.VARSAYILAN_ROTA; yaz('tm_rota', rota); } }, 0);
  function ilIlerleme(il) { var h = haritaDurum(), t = 0; for (var n = il.ilk; n <= il.son; n++) if (h.bitti[n]) t++; return t; }
  function rotaSec(y) {
    rota = U.rotaAl(y); yaz('tm_rota', rota);
    if (secim === 'uc') {
      var r = U.ROTALAR[rota - 1], doga = r.dunyalar.some(function (d) { return d === 'orman' || d === 'in'; });
      $('#bildirim-foto').src = 'assets/img/' + (doga ? 'foto-musteri.jpg' : 'foto-yuruyus.jpg');
      $('#bildirim-metin').textContent = '📍 ' + r.il + ' · ' + (r.ilce === 'Merkez' ? 'Merkez' : r.ilce) + ': ' + rotaOzet(r) + '. ' + U.rotaHedefi(rota) + ' müşteri seni bekliyor!';
    }
  }

  // Görselli kartlar için önizleme resimleri
  var onizlemeler = {}, rotaKuyruk = [], ikiOnizlemeler = {};
  function ikiOnizleme(dunya, saat) {
    var k = dunya + '|' + (saat || '');
    if (ikiOnizlemeler[k]) return ikiOnizlemeler[k];
    var c = document.createElement('canvas'); c.width = 320; c.height = 200;
    var g2 = c.getContext('2d'), Wl = 220, Hl = 137.5, zy2 = 108;
    g2.scale(c.width / Wl, c.width / Wl);
    Ciz.arkaPlan(g2, Wl, Hl, zy2, 260, dunya, 1);
    Ciz.zemin(g2, Wl, Hl, zy2, 260, dunya, []);
    Ciz.saatKatmani(g2, Wl, Hl, zy2, saat, 1);
    Ciz.maskot(g2, 70, zy2, 'kos', 1.1, { olcek: 0.95 });
    for (var i = 0; i < 4; i++) Ciz.tarakSimge(g2, 120 + i * 22, zy2 - 40 - Math.sin(i) * 10, 0.9, -0.3);
    try { ikiOnizlemeler[k] = c.toDataURL('image/jpeg', 0.82); } catch (e) { ikiOnizlemeler[k] = ''; }
    return ikiOnizlemeler[k];
  }
  function kartResmi(el, url) { if (el && url) el.style.backgroundImage = 'url(' + url + ')'; }

  function rotaIkon(r) {
    return (SAAT_AD[r.saat] || '').split(' ')[0] + (HAVA_AD[r.hava] ? ' ' + HAVA_AD[r.hava].split(' ')[0] : '') + (r.deniz ? (r.gol ? ' 🏞️' : ' 🌊') : '') + (r.tramvay ? ' 🚋' : '') + (r.balon ? ' 🎈' : '') + (r.aslan ? ' 🦁' : '');
  }
  var onayBekleyen = null;
  function rotalarCiz() {
    // Seçili ilin gerçek cadde verisi önceden yüklenir (Yola Çık'ta beklenmesin)
    if (seciliIl && window.TarakCadde) window.TarakCadde.yukle(seciliIl, function () {});
    var l = $('#rota-liste'); l.innerHTML = '';
    rotaKuyruk = [];
    var h = haritaDurum(), hedef = null;
    var ara = document.createElement('input'); ara.className = 'harita-ara'; ara.placeholder = seciliIl ? 'İlçe ara…' : 'İl ya da ilçe ara…'; ara.value = haritaArama;
    ara.addEventListener('input', function () { haritaArama = ara.value; var p = ara.selectionStart; rotalarCiz(); var y = $('.harita-ara'); y.focus(); y.setSelectionRange(p, p); });
    l.appendChild(ara);
    var q = haritaArama.toLocaleLowerCase('tr-TR').trim();
    if (!seciliIl) {
      $('#ekran-rotalar h2').textContent = 'Türkiye Haritası';
      $('#rota-sayac').textContent = h.iller.length + '/81 il';
      var hak = ilHakki(), bilgi = document.createElement('p'); bilgi.className = 'harita-bilgi';
      bilgi.textContent = hak > 0 ? '🗝️ ' + hak + ' il açma hakkın var: istediğin ili seç!' : '🗝️ Her 3 tamamlanan ilçe yeni bir il açar · ya da ' + IL_FIYAT + ' tarakla aç';
      l.appendChild(bilgi);
      var iz = document.createElement('div'); iz.className = 'il-izgara'; l.appendChild(iz);
      U.ILLER.forEach(function (il) {
        if (q && il.ad.toLocaleLowerCase('tr-TR').indexOf(q) < 0 && !U.ROTALAR.slice(il.ilk - 1, il.son).some(function (r) { return r.ilce.toLocaleLowerCase('tr-TR').indexOf(q) >= 0; })) return;
        var acik = ilAcik(il.plaka), biten = ilIlerleme(il);
        var b = document.createElement('button'); b.className = 'il-kart bolge-' + il.bolge + (acik ? '' : ' kilitli') + (U.ROTALAR[rota - 1].plaka === il.plaka ? ' secili' : '');
        b.innerHTML = '<span class="il-resim"><em></em></span><b></b><small></small><small class="il-durum"></small>';
        b.querySelector('em').textContent = (il.plaka < 10 ? '0' : '') + il.plaka;
        b.querySelector('b').textContent = il.ad;
        b.querySelector('small').textContent = il.bolgeAd + ' · ' + il.ilceSayisi + ' ilçe';
        var dr = b.querySelector('.il-durum');
        if (acik) dr.textContent = biten ? '✅ ' + biten + '/' + il.ilceSayisi + ' tamam' : 'Yeni!';
        else dr.textContent = onayBekleyen === 'il' + il.plaka ? (hak > 0 ? 'Tekrar dokun: hakkınla aç' : 'Tekrar dokun: ' + IL_FIYAT + ' tarakla aç') : '🔒 ' + (hak > 0 ? '1 hakla aç' : IL_FIYAT + ' tarak');
        var resim = b.querySelector('.il-resim'); resim.setAttribute('data-rota-resim', il.ilk);
        if (acik) { if (onizlemeler[il.ilk]) kartResmi(resim, onizlemeler[il.ilk]); else rotaKuyruk.push(il.ilk); }
        b.addEventListener('click', function () {
          Ses.cal('tik');
          if (acik) { seciliIl = il.plaka; haritaArama = ''; rotalarCiz(); return; }
          if (onayBekleyen !== 'il' + il.plaka) { onayBekleyen = 'il' + il.plaka; rotalarCiz(); return; }
          onayBekleyen = null;
          if (hak > 0 || kese.cuzdan >= IL_FIYAT) {
            if (hak <= 0) { kese.cuzdan -= IL_FIYAT; keseKaydet(); cuzdanYaz(); }
            h.iller.push(il.plaka); yaz('tm_ilerleme', ilerleme); Ses.cal('kazandi');
            menuTost('🗝️ ' + il.ad + ' açıldı! ' + il.ilceSayisi + ' ilçe seni bekliyor.');
            seciliIl = il.plaka; haritaArama = ''; rotalarCiz();
          } else { Ses.cal('carpti'); menuTost('Yeterli tarağın yok: ' + IL_FIYAT + ' tarak gerekli. İlçe tamamlayarak da il açabilirsin.'); rotalarCiz(); }
        });
        iz.appendChild(b);
        if (U.ROTALAR[rota - 1].plaka === il.plaka) hedef = b;
      });
    } else {
      var il = U.ILLER.filter(function (x) { return x.plaka === seciliIl; })[0];
      $('#ekran-rotalar h2').textContent = il.ad;
      $('#rota-sayac').textContent = ilIlerleme(il) + '/' + il.ilceSayisi;
      var ust = document.createElement('div'); ust.className = 'il-baslik';
      ust.innerHTML = '<span class="il-resim buyuk" data-rota-resim="' + il.ilk + '"></span><div><b></b><small></small></div>';
      ust.querySelector('b').textContent = il.ad + ' · ' + il.bolgeAd;
      ust.querySelector('small').textContent = il.ilceSayisi + ' ilçe · konumuna bağlı değil, istediğin yerde koş';
      if (onizlemeler[il.ilk]) kartResmi(ust.querySelector('.il-resim'), onizlemeler[il.ilk]); else rotaKuyruk.push(il.ilk);
      l.appendChild(ust);
      for (var n = il.ilk; n <= il.son; n++) (function (no) {
        var r = U.ROTALAR[no - 1];
        if (q && r.ilce.toLocaleLowerCase('tr-TR').indexOf(q) < 0) return;
        var acik = rotaAcik(no), bitti = !!h.bitti[no], rk = h.rota[no] || 0;
        var b = document.createElement('button'); b.className = 'ilce-satir' + (acik ? '' : ' kilitli') + (no === rota ? ' secili' : '') + (bitti ? ' bitti' : '');
        b.innerHTML = '<span class="ilce-no"></span><span class="ilce-govde"><b></b><small></small></span><span class="ilce-durum"></span>';
        b.querySelector('.ilce-no').textContent = bitti ? '✓' : (r.sira + 1);
        b.querySelector('b').textContent = r.ilce;
        b.querySelector('small').textContent = rotaIkon(r) + ' · ' + U.rotaHedefi(no) + ' müşteri';
        b.querySelector('.ilce-durum').textContent = bitti ? 'Tamam' : acik ? (rk ? rk + '/' + U.rotaHedefi(no) : 'Koş →') : onayBekleyen === 'ilce' + no ? 'Dokun: ' + ILCE_FIYAT + ' 🪮' : '🔒 ' + ILCE_FIYAT;
        b.addEventListener('click', function () {
          Ses.cal('tik');
          if (acik) { rotaSec(no); bolumBaslat('uc'); return; }
          if (onayBekleyen !== 'ilce' + no) { onayBekleyen = 'ilce' + no; rotalarCiz(); return; }
          onayBekleyen = null;
          if (kese.cuzdan >= ILCE_FIYAT) { kese.cuzdan -= ILCE_FIYAT; keseKaydet(); cuzdanYaz(); h.alinan[no] = 1; yaz('tm_ilerleme', ilerleme); Ses.cal('kazandi'); rotalarCiz(); }
          else { Ses.cal('carpti'); menuTost('Yeterli tarağın yok: ' + ILCE_FIYAT + ' tarak gerekli. Önceki ilçede 1 müşteriye yetişince de açılır.'); rotalarCiz(); }
        });
        l.appendChild(b);
        if (no === rota) hedef = b;
      })(n);
    }
    ekran('rotalar');
    if (hedef && !q) l.scrollTop = Math.max(0, hedef.offsetTop - 120);
  }

  function modSec(yeni) {
    mod = yeni; yaz('tm_mod', mod);
    $$('#mod-secici button').forEach(function (b) { b.setAttribute('aria-checked', b.dataset.mod === mod ? 'true' : 'false'); });
    $('#mod-tanim').textContent = C.MODLAR[mod].tanim;
  }
  var cihaz = oku('tm_cihaz', '');
  if (!cihaz) {
    cihaz = (window.crypto && crypto.randomUUID) ? crypto.randomUUID() : 'c-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 12);
    yaz('tm_cihaz', cihaz);
  }

  // ---------- Sunucu (bağlantı yoksa oyun yine çalışır) ----------
  var sunucuAyar = { oyunAktif: true, kapaliBolumler: [], hizCarpani: 1, randevuUrl: 'https://tarak.app', randevuMetni: '', duyuru: '', bakimMesaji: '' };
  // Tarak Mobil uygulaması: iPhone/iPad'de App Store, Android'de Google Play, bilgisayarda web sitesi
  var UYGULAMA = { ios: 'https://apps.apple.com/tr/app/tarak-berber-ve-kuaf%C3%B6r-%C3%A7a%C4%9F%C4%B1r/id6826645157?l=tr', android: 'https://play.google.com/store/apps/details?id=app.tarak.mobile&hl=tr', web: 'https://tarak.app/' };
  function platformAl() {
    var ua = navigator.userAgent || '';
    if (/iPhone|iPad|iPod/i.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1)) return 'ios';
    if ((window.TARAK_AYAR && window.TARAK_AYAR.platform === 'android') || /Android/i.test(ua)) return 'android';
    return 'web';
  }
  function uygulamaAdresi() {
    var p = platformAl();
    if (p === 'ios') return sunucuAyar.iosUrl || UYGULAMA.ios;
    if (p === 'android') return sunucuAyar.androidUrl || UYGULAMA.android;
    return sunucuAyar.webUrl || sunucuAyar.uygulamaUrl || UYGULAMA.web;
  }
  var jeton = null, oturumSozu = null;

  function istek(islem, veri) {
    if (!AYAR.api) return Promise.resolve(null);   // sunucusuz beta sürümü
    var url = AYAR.api + '?islem=' + islem;
    var sec = veri ? { method: 'POST', headers: { 'Content-Type': 'text/plain;charset=UTF-8' }, body: JSON.stringify(veri), keepalive: true } : { method: 'GET' };
    return fetch(url, sec).then(function (r) { return r.ok ? r.json() : null; }).catch(function () { return null; });
  }

  function platform() {
    if (AYAR.platform) return AYAR.platform;
    return (window.matchMedia && matchMedia('(display-mode: standalone)').matches) ? 'pwa' : 'web';
  }

  function oturumAc() {
    oturumSozu = istek('oturum', {
      cihaz: cihaz, platform: platform(), isim: isim,
      ekran: screen.width + 'x' + screen.height,
      kaynak: document.referrer ? document.referrer.slice(0, 200) : ''
    }).then(function (c) {
      if (c && c.jeton) { jeton = c.jeton; tarakDurumu = { acik: !!c.tarak, bagli: !!c.tarakBagli, ad: c.ad || '' }; setTimeout(tarakDugmesi, 0); }
      return jeton;
    });
    return oturumSozu;
  }

  function sunucuyaBildir(islem, veri) {
    return (oturumSozu || oturumAc()).then(function (j) {
      if (!j) return null;
      veri.jeton = j;
      return istek(islem, veri);
    });
  }

  function ayarlariUygula() {
    var uyg = uygulamaAdresi(), plt = platformAl();
    $$('.sponsor-kart').forEach(function (a) { a.href = uyg; });
    var indir = plt === 'ios' ? 'App Store’dan indir →' : plt === 'android' ? 'Google Play’den indir →' : 'tarak.app’te randevu al →';
    $$('.sponsor-metin').forEach(function (s) { s.textContent = sunucuAyar.sponsorMetni || ('Oyun, Tarak Mobil sponsorluğunda tamamen ücretsiz · ' + indir); });
    $$('.randevu').forEach(function (a) {
      // Varsayılan (tarak.app) adreste randevu düğmesi de platforma uygun uygulamaya gider; adminde özel adres girilmişse o kullanılır
      var varsayilan = /^https?:\/\/(www\.)?tarak\.app\/?$/i.test(sunucuAyar.randevuUrl || '');
      if (sunucuAyar.randevuUrl) { a.href = varsayilan ? uyg : sunucuAyar.randevuUrl; a.textContent = sunucuAyar.randevuMetni || 'Gerçek randevu al →'; a.classList.remove('gizli'); }
      else a.classList.add('gizli');
    });
    var d = $('#duyuru');
    d.textContent = sunucuAyar.duyuru || '';
    d.classList.toggle('gizli', !sunucuAyar.duyuru);
    if (!sunucuAyar.oyunAktif) {
      $('#bakim-metin').textContent = sunucuAyar.bakimMesaji || 'Oyun kısa süreliğine bakımda.';
      ekran('bakim');
    }
  }

  // ---------- Ekran yönetimi ----------
  var aktifEkran = 'ana';
  function ekran(ad) {
    aktifEkran = ad;
    $$('.ekran').forEach(function (e) { e.classList.add('gizli'); });
    if (ad && ad !== 'oyun') $('#ekran-' + ad).classList.remove('gizli');
    $('#hud').classList.toggle('gizli', !(ad === 'oyun' || ad === 'duraklat'));
    if (ad === 'ana') {
      cuzdanYaz();
      if (bekleyenSeviye && bekleyenSeviye.length) {
        menuTost(seviyeMetni(bekleyenSeviye, true));
        bekleyenSeviye = []; Ses.cal('kazandi');
      }
    }
    if (ad === 'duraklat') $('#ekran-duraklat').classList.remove('gizli');
  }

  // Maskotun görüneceği boş bant: menüde başlık kartı ile mod kartları arası, gardıropta üst boşluk
  function vitrinAlani() {
    var kap = $('#tuval3d').getBoundingClientRect(), ust, alt;
    if (aktifEkran === 'magaza') {
      var mb = $('#magaza-bosluk').getBoundingClientRect(), hb = $('#ekran-magaza header').getBoundingClientRect();
      ust = hb.bottom; alt = mb.bottom;
    } else {
      ust = $('#ekran-ana .ana-ust').getBoundingClientRect().bottom;
      alt = $('#ekran-ana .modlar').getBoundingClientRect().top;
    }
    return { ust: ust - kap.top + 4, alt: alt - kap.top - 2 };
  }

  // ---------- Tuval ----------
  var tuval = $('#tuval'), g = tuval.getContext('2d');
  var W = 470, H = 760, olcek = 1, dpr = 1;
  function boyutla() {
    var cw = tuval.clientWidth, ch = tuval.clientHeight;
    if (!cw || !ch) return;
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    tuval.width = Math.round(cw * dpr); tuval.height = Math.round(ch * dpr);
    olcek = Math.min(cw / 470, ch / 760);
    if (cw > ch) olcek = ch / 560;
    W = cw / olcek; H = ch / olcek;
  }
  window.addEventListener('resize', boyutla);
  if (window.ResizeObserver) new ResizeObserver(boyutla).observe(tuval);

  // ---------- Oyun durumu ----------
  var oyun = null, secim = 1, kosuId = null, kosuSozu = null, bitisZamani = 0;
  var parcaciklar = [], sarsinti = 0, yazilar = [], taklaZ = 0;
  var DT = 1 / 120, birikim = 0, sonZaman = 0, toplamZaman = 0, kosuFaz = 0;

  function bolumBaslat(no) {
    secim = no;
    modSec(mod);
    if (no === 'uc') {
      $('#bildirim-foto').src = 'assets/img/foto-yuruyus.jpg';
      $('#bildirim-metin').textContent = 'Yeni randevular geliyor! Trafiğe dikkat et, her durakta bir müşteri seni bekliyor.';
      $('#bildirim-ipucu').textContent = '3D Koşu · Kaydır: ⬅️ ➡️ şerit, ⬆️ zıpla, ⬇️ kay. En iyi skorun: ' + (ilerleme.uc || 0);
      rotaSec(rota);
      ekran('bildirim');
      Ses.cal('bildirim');
      return;
    }
    if (no === 'sonsuz') {
      $('#bildirim-foto').src = 'assets/img/foto-yolda.jpg';
      $('#bildirim-metin').textContent = 'Sonsuz Mod: randevular bitmiyor! Gidebildiğin kadar git.';
      $('#bildirim-ipucu').textContent = 'En iyi skorun: ' + (ilerleme.sonsuz || 0);
      ekran('bildirim');
      return;
    }
    var b = C.BOLUMLER[no - 1];
    $('#bildirim-foto').src = 'assets/img/' + (b.final ? 'foto-musteri.jpg' : b.dunya === 'otoyol' ? 'foto-sofor.jpg' : 'foto-yuruyus.jpg');
    var m = $('#bildirim-metin');
    m.textContent = '';
    var k = document.createElement('b'); k.textContent = musteriAd(b);
    m.appendChild(k);
    m.appendChild(document.createTextNode(kadin ? ' için ' + b.hizmetK + ' randevusu aldınız. Konumu görüntüleyin ve yola çıkın!' : ' için bir adet saç sakal tıraşı aldınız. Konumu görüntüleyin ve yola çıkın!'));
    $('#bildirim-ipucu').textContent = 'Bölüm ' + no + ' · ' + b.ad + ' — ' + b.ipucu;
    ekran('bildirim');
    Ses.cal('bildirim');
  }

  function hudBicimi(uc) {
    $('#hud').classList.toggle('uc', uc);
    $('#btn-sol').classList.toggle('gizli', !uc);
    $('#btn-sag').classList.toggle('gizli', !uc);
    $('#btn-kay small').textContent = '2× turbo';
    $('#uc-yazi').classList.add('gizli');
  }

  // Gerçek cadde verisi henüz yüklenmediyse önce yüklenir (rota baştan sona gerçek caddede kurulsun)
  function ucBaslat() {
    var U3 = window.TarakUc, r = U3 && U3.ROTALAR[U3.rotaAl(rota) - 1], CD = window.TarakCadde;
    if (r && CD && CD.hazir(r.plaka, r.sira) === undefined && !ucBaslat.bekliyor) {
      ucBaslat.bekliyor = true;
      var bitti = false, devam = function () { if (bitti) return; bitti = true; ucBaslat.bekliyor = false; ucBaslatGercek(); };
      CD.yukle(r.plaka, devam); setTimeout(devam, 2500);
      return;
    }
    ucBaslatGercek();
  }
  function ucBaslatGercek() {
    kosuKapat();
    var gucler = Odul.gucHarca(kese); keseKaydet();
    kusan();
    oyun = Uc.baslat(mod, gucler, sunucuAyar.hizCarpani || 1, rota);
    sandikKalan = 0;
    ekran('oyun'); hudBicimi(true);
    $('#hud-guc').innerHTML = ''; $('#hud-ipucu').classList.add('gizli');
    Ses.muzikBaslat();
    kosuId = null;
    kosuSozu = sunucuyaBildir('basla', { bolum: 100 + oyun.rota, zorluk: oyun.mod }).then(function (c) { kosuId = c && c.kosuId; return kosuId; });
  }

  // 3D koşu "devam" hakkı yüzünden hemen kapanmaz; ekrandan ayrılırken bir kez işlenir.
  function kosuKapat() {
    var o = oyun;
    if (!o || !o.uc || o.islendi) return;
    o.islendi = true;
    kosuyuBildir(o, o.kazandi ? 'kazandi' : o.bitti ? 'kaybetti' : 'cikti');
    var tamam = Odul.kosuIsle(kese, { tarak: o.tarak, mesafe: o.p.s, durak: o.musteri, koli: o.kirilan, ziplama: o.ziplama, kayma: o.kayma, kosu: o.bitti ? 1 : 0 }, Odul.gunAdi());
    ilerleme.rota = ilerleme.rota || {};
    ilerleme.rota[o.rota] = Math.max(ilerleme.rota[o.rota] || 0, o.musteri);
    if (o.kazandi) { haritaDurum().bitti[o.rota] = 1; if (bitenSayisi() % 3 === 0) setTimeout(function () { menuTost('🗝️ Yeni il açma hakkı kazandın! Türkiye haritasından istediğin ili aç.'); }, 600); }
    yaz('tm_ilerleme', ilerleme);
    // Devam ücretine sayılan koşu tarakları ikinci kez eklenmez
    kese.cuzdan = Math.max(0, kese.cuzdan - (o.devamdanDusen || 0));
    // Açılmadan bırakılan sandıklar kaybolmaz
    for (var i = o.acilan || 0; i < o.sandik; i++) Odul.sandikAc(kese);
    sandikKalan = 0;
    keseKaydet();
    seviyeHaberi(tamam);
    return tamam;
  }
  // 2D koşuda toplanan ama açılmayan hediyeler sonuç ekranından çıkarken verilir.
  function kalanSandiklar() {
    if (!oyun || (oyun.uc && !oyun.sandikBekliyor) || !sandikKalan) return;
    for (var i = 0; i < sandikKalan; i++) Odul.sandikAc(kese);
    sandikKalan = 0;
    keseKaydet();
  }
  var bekleyenSeviye = [];
  function seviyeHaberi(sonuc) {
    if (sonuc && sonuc.seviyeler && sonuc.seviyeler.length) bekleyenSeviye = bekleyenSeviye.concat(sonuc.seviyeler);
  }
  function seviyeMetni(liste, kisa) {
    var son = liste[liste.length - 1];
    var tarak = liste.reduce(function (t, x) { return t + x.tarak; }, 0);
    var urunler = liste.filter(function (x) { return x.urun; }).map(function (x) { return x.urun.simge + ' ' + x.urun.ad; });
    if (kisa) return '⭐ Seviye ' + son.seviye + '! +' + tarak + ' tarak' + (urunler.length ? ' · ' + urunler.length + ' yeni kıyafet Gardırop’ta' : '');
    return '⭐ Seviye ' + son.seviye + '! +' + tarak + ' tarak' + (urunler.length ? ' · Yeni: ' + urunler.join(', ') : '');
  }

  function oyunuBaslat(hazirOyun) {
    kalanSandiklar();
    if (secim === 'uc' && !(hazirOyun && hazirOyun.dunya)) { ucBaslat(); return; }
    kosuKapat();
    sandikKalan = 0;
    if (hazirOyun && hazirOyun.dunya) oyun = hazirOyun;
    else {
      oyun = C.yeniOyun(secim, mod);
      oyun.hizCarpani = sunucuAyar.hizCarpani || 1;
      // Karakter özelliği (2D'de karşılığı olanlar)
      var kOz = KR.bul(karakterId).ozellik;
      if (kOz === 'kalkan') oyun.kalkan = true;
      if (kOz === 'miknatis') oyun.miknatis = 12;
      if (kOz === 'can') oyun.can += 1;
    }
    parcaciklar = []; yazilar = []; sarsinti = 0; birikim = 0; onceki2D = null; bitisZamani = 0; taklaZ = 0;
    ekran('oyun'); hudBicimi(false);
    kusan();
    $('#hud-bolum').textContent = (oyun.sonsuz ? 'Sonsuz Mod' : 'Bölüm ' + oyun.bolum + ' · ' + oyun.tanim.ad) + ' · ' + oyun.ayar.simge + ' ' + oyun.ayar.ad;
    $('#hud-yol').style.visibility = oyun.sonsuz ? 'hidden' : 'visible';
    hudSon = '';
    Ses.muzikBaslat();
    kosuId = null;
    kosuSozu = sunucuyaBildir('basla', { bolum: oyun.bolum, zorluk: oyun.mod, devam: oyun.devamli }).then(function (c) { kosuId = c && c.kosuId; return kosuId; });
  }

  function kosuyuBildir(o, sonuc) {
    var veri = o.uc ? {
      sonuc: sonuc, skor: U.skor(o), tarak: o.tarak, can: Math.max(0, o.can),
      sure: Math.round(o.sure * 10) / 10, mesafe: Math.round(o.p.s), yildiz: 0, durak: o.musteri,
      neden: sonuc === 'kaybetti' ? o.sonNeden : ''
    } : {
      sonuc: sonuc, skor: C.skor(o), tarak: o.tarak, can: Math.max(0, o.can),
      sure: Math.round((o.sure - o.sureBaslangic) * 10) / 10, mesafe: Math.round(o.p.x), yildiz: C.yildiz(o),
      neden: sonuc === 'kaybetti' ? o.sonNeden : ''
    };
    veri.parca = o.parca || 0;
    if (o.uc && Uc.gosterilenSponsorlar) veri.sponsor = Uc.gosterilenSponsorlar();
    if (veri.parca) { kese.parca = (kese.parca || 0) + veri.parca; keseKaydet(); }
    var soz = kosuSozu || Promise.resolve(null);
    soz.then(function (id) { if (id) { veri.kosuId = id; sunucuyaBildir('bitir', veri).then(function () { hediyeDurum = null; }); } });
    kosuSozu = null;
  }

  function oyundanCik() {
    kalanSandiklar();
    if (oyun && oyun.uc) kosuKapat();
    else if (oyun && !oyun.bitti) kosuyuBildir(oyun, 'cikti');
    oyun = null;
    Ses.muzikDur();
    ekran('ana');
  }

  function duraklat() {
    if (aktifEkran !== 'oyun' || !oyun || oyun.bitti) return;
    ekran('duraklat'); Ses.muzikDur();
  }
  function devamEt() { if (aktifEkran === 'duraklat') { ekran('oyun'); Ses.muzikBaslat(); sonZaman = 0; } }

  // ---------- Sonuç ----------
  function sandikDugmesi() {
    $('#btn-sandik').classList.toggle('gizli', sandikKalan <= 0);
    $('#btn-sandik').textContent = '🎁 Sandığı Aç' + (sandikKalan > 1 ? ' (' + sandikKalan + ')' : '');
  }
  function devamDugmesi() { $('#btn-devam3d').disabled = !oyun || kese.cuzdan + oyun.tarak < Odul.DEVAM_FIYATI; }
  function sandikAc() {
    if (sandikKalan <= 0) return;
    sandikKalan--;
    if (oyun) oyun.acilan = (oyun.acilan || 0) + 1;
    var s = Odul.sandikAc(kese);
    keseKaydet(); Ses.cal('kalp');
    var y = $('#sandik-sonuc');
    y.textContent = s.simge + ' ' + (s.tur === 'tarak' ? '+' + s.miktar + ' tarak' : s.tur === 'guc' ? s.ad + ' kazandın!' : 'Yeni aksesuar: ' + s.ad + '!');
    y.classList.remove('gizli'); y.style.animation = 'none'; void y.offsetWidth; y.style.animation = '';
    sandikDugmesi();
    if (oyun && oyun.uc) devamDugmesi();
  }
  function gorevHaberi(liste) {
    var k = $('#sonuc-gorev'), satir = [];
    if (bekleyenSeviye.length) { satir.push(seviyeMetni(bekleyenSeviye)); bekleyenSeviye = []; setTimeout(function () { Ses.cal('kazandi'); }, 600); }
    if (liste && liste.length) satir.push('✅ Görev tamam: ' + liste.map(function (g) { return g.metin; }).join(', ') + ' (Ödüller’den al)');
    k.textContent = satir.join('\n');
    k.classList.toggle('gizli', !satir.length);
  }

  function ucSonuc() {
    var o = oyun, s = U.skor(o);
    o.sonucGosterildi = true;
    sandikKalan = o.sandik - (o.acilan || 0);
    var rekor = s > (ilerleme.uc || 0);
    if (rekor) { ilerleme.uc = s; yaz('tm_ilerleme', ilerleme); }
    $('#sonuc-foto1').src = 'assets/img/' + fotoAd(o.musteri ? 'foto-tiras.jpg' : 'foto-musteri.jpg');
    $('#sonuc-foto2').src = 'assets/img/' + fotoAd(o.musteri ? 'foto-sonuc.jpg' : 'foto-musteri.jpg');
    $('#sonuc-baslik').textContent = o.kazandi ? 'Rota tamamlandı! 🏁' : rekor ? 'Yeni rekor! 🎉' : 'Koşu bitti';
    var rt = U.ROTALAR[o.rota - 1], sonraki = U.ROTALAR[o.rota], ayniIl = sonraki && sonraki.plaka === rt.plaka;
    var acilacak = o.musteri >= 1 && ayniIl && !rotaAcik(o.rota + 1);
    $('#sonuc-metin').textContent = rt.il + ' · ' + rt.ilce + ': ' + (o.kazandi ? 'bütün randevulara yetiştin! ' + o.musteri + ' müşteri mutlu.' : Math.floor(o.p.s) + ' m koştun, ' + o.musteri + ' / ' + o.hedefMusteri + ' müşteriye yetiştin.') + (acilacak ? ' 🔓 Sıradaki ilçe açıldı: ' + sonraki.ilce + '!' : '');
    $('#sonuc-yildiz').innerHTML = '';
    $('#sonuc-tablo').classList.remove('gizli');
    $('#sonuc-tablo').innerHTML = '<div>SKOR<b>' + s + '</b></div><div>TARAK<b>' + o.tarak + '</b></div><div>MESAFE<b>' + Math.floor(o.p.s) + ' m</b></div>';
    gorevHaberi(null);
    $('#sandik-sonuc').classList.add('gizli');
    sandikDugmesi();
    // Devam hakkı kalmadıysa koşu hemen işlenir; seviye ödülü bu ekranda görünür
    if (o.devamHakki < 1 || o.kazandi) { var kalanSandik = sandikKalan; kosuKapatErken(o); sandikKalan = kalanSandik; }
    var d = $('#btn-devam3d'), hak = o.devamHakki > 0 && !o.kazandi;
    d.classList.toggle('gizli', !hak);
    devamDugmesi();
    d.textContent = '❤️ Devam Et · ' + Odul.DEVAM_FIYATI + ' tarak';
    $('#btn-sonraki').textContent = o.kazandi ? (ayniIl ? 'Sıradaki İlçe → ' + sonraki.ilce : '🗺️ Türkiye haritasına dön') : '↻ Yeniden Koş';
    $('#btn-sonraki').classList.toggle('sari', !hak);
    $('#btn-tekrar').classList.toggle('gizli', !o.kazandi);
    $('#btn-kontrol').classList.add('gizli'); $('#btn-kolaylas').classList.add('gizli');
    $('#btn-tekrar').parentNode.style.gridTemplateColumns = o.kazandi ? '' : '1fr';
    $('.kart.sonuc').classList.add('kalabalik');
    ekran('sonuc');
    $('#hud').classList.add('gizli');
  }

  // Sandıklar ekranda açılmaya devam edebilsin diye yalnızca kazanç ve görevler işlenir.
  function kosuKapatErken(o) {
    if (o.islendi) return;
    var acilan = o.acilan;
    o.acilan = o.sandik;                    // kosuKapat sandıkları kendisi açmasın
    var tamam = kosuKapat();
    o.acilan = acilan;
    sandikKalan = o.sandik - (acilan || 0);
    o.sandikBekliyor = true;
    gorevHaberi(tamam);
  }

  function ucDevam() {
    var o = oyun;
    if (!o || !o.uc || o.devamHakki < 1) return;
    // Önce bu koşuda toplananlar da sayılır
    var eksik = Odul.DEVAM_FIYATI - kese.cuzdan;
    if (eksik > o.tarak) return;
    var kosudan = Math.max(0, eksik);
    kese.cuzdan += kosudan;
    if (!Odul.devamOde(kese)) return;
    o.devamdanDusen = (o.devamdanDusen || 0) + kosudan;
    keseKaydet();
    U.devamEt(o);
    o.sonucGosterildi = false;
    ekran('oyun'); hudBicimi(true); Ses.muzikBaslat();
  }

  function sonucGoster() {
    $('#btn-devam3d').classList.add('gizli');
    $('.kart.sonuc').classList.remove('kalabalik');
    var o = oyun, s = C.skor(o), y = C.yildiz(o);
    var foto1 = $('#sonuc-foto1'), foto2 = $('#sonuc-foto2');
    var baslik, metin, sonrakiYazi, f1, f2;
    if (o.sonsuz) {
      var rekor = s > (ilerleme.sonsuz || 0);
      if (rekor) ilerleme.sonsuz = s;
      baslik = rekor ? 'Yeni rekor! 🎉' : 'Koşu bitti';
      metin = Math.floor(o.p.x / 20) + ' metre koştun. En iyi skorun: ' + ilerleme.sonsuz;
      sonrakiYazi = '↻ Yeniden Koş'; f1 = 'foto-yolda.jpg'; f2 = 'foto-sofor.jpg';
    } else if (o.kazandi) {
      ilerleme.yildiz[o.bolum] = Math.max(ilerleme.yildiz[o.bolum] || 0, y);
      yanmaSayisi[o.bolum] = 0;
      if (MOD_SIRA[o.mod] > (MOD_SIRA[ilerleme.mod[o.bolum]] || 0)) ilerleme.mod[o.bolum] = o.mod;
      ilerleme.skor[o.bolum] = Math.max(ilerleme.skor[o.bolum] || 0, s);
      ilerleme.acik = Math.max(ilerleme.acik, Math.min(C.BOLUMLER.length, o.bolum + 1));
      var son = o.bolum === C.BOLUMLER.length;
      baslik = son ? (kadin ? 'Kraliçe hazır! 👑' : 'Kral tıraş oldu! 👑') : 'Randevuya yetiştin!';
      metin = son ? (kadin ? 'Bütün randevuları tamamladın. Ormanın kraliçesi yeni saçına bayıldı!' : 'Bütün randevuları tamamladın. Ormanın kralı yeni tarzına bayıldı!')
        : musteriAd(o.tanim) + (kadin ? ' · ' + o.tanim.hizmetK + ' harika oldu! Sıradaki randevu hazır.' : ' çok memnun. Sıradaki randevu hazır.');
      sonrakiYazi = son ? '∞ Sonsuz Modu Dene' : 'Sıradaki Randevu →';
      if (o.bolum >= 10) { f1 = fotoAd('foto-tiras.jpg'); f2 = fotoAd('foto-sonuc.jpg'); }
      else if (o.bolum >= 7) { f1 = 'foto-yuruyus.jpg'; f2 = 'foto-hazirlik.jpg'; }
      else { f1 = 'foto-yolda.jpg'; f2 = 'foto-sofor.jpg'; }
    } else {
      baslik = 'Eyvah, geç kaldın!';
      metin = ({ kutu: 'Engelin biraz öncesinde zıpla.', genis: 'Bankın üstünden biraz geç zıpla.', koli: 'Zıpla ya da 2× kayıp koliyi kır.', cukur: 'Çukura düştün. Kenarına gelince zıpla.', yuksek: 'Yüksek engelde iki kez zıpla.', tabela: 'Tabelanın altından kaymayı dene.', tunel: 'Uzun geçitte KAY’a iki kez bas.', lastik: 'Lastik üstüne gelir, biraz erken zıpla.' })[o.sonNeden] || 'Bir kez daha dene, müşteri bekliyor.';
      sonrakiYazi = '↻ Tekrar Dene'; f1 = 'foto-musteri.jpg'; f2 = 'foto-musteri.jpg';
    }
    yaz('tm_ilerleme', ilerleme);
    var tamam = Odul.kosuIsle(kese, { tarak: o.tarak, mesafe: 0, durak: o.kazandi && !o.sonsuz ? 1 : 0, koli: 0, ziplama: 0, kayma: 0, kosu: 1 }, Odul.gunAdi());
    keseKaydet();
    seviyeHaberi(tamam);
    gorevHaberi(tamam);
    sandikKalan = o.sandik + (o.kazandi && !o.sonsuz ? 1 : 0);
    $('#sandik-sonuc').classList.add('gizli');
    sandikDugmesi();
    if (sandikKalan || !$('#sonuc-gorev').classList.contains('gizli')) $('.kart.sonuc').classList.add('kalabalik');
    foto1.src = 'assets/img/' + f1; foto2.src = 'assets/img/' + f2;
    $('#sonuc-baslik').textContent = baslik;
    $('#sonuc-metin').textContent = metin;
    $('#sonuc-yildiz').innerHTML = (o.kazandi && !o.sonsuz) ? [1, 2, 3].map(function (i) { return i <= y ? '<b>★</b>' : '★'; }).join('') : '';
    $('#sonuc-tablo').innerHTML = '<div>SKOR<b>' + s + '</b></div><div>TARAK<b>' + o.tarak + (o.sonsuz ? '' : '/' + o.dunya.toplamTarak) + '</b></div><div>SÜRE<b>' + Math.round(o.sure) + ' sn</b></div>';
    $('#btn-sonraki').textContent = sonrakiYazi;
    // Oyuncu bıkmasın: yarı yoldan devam ve iki kez yanınca daha kolay mod önerisi
    var yandi = !o.kazandi && !o.sonsuz;
    var devamVar = yandi && o.ayar.devam && !!o.kontrolKaydi;
    if (devamVar) $('#btn-kontrol').textContent = '🚩 Bayraktan Devam Et';
    $('#btn-kontrol').classList.toggle('gizli', !devamVar);
    $('#btn-sonraki').classList.toggle('sari', !devamVar);
    if (devamVar) $('#btn-sonraki').textContent = '↻ Baştan Başla';
    if (yandi) yanmaSayisi[o.bolum] = (yanmaSayisi[o.bolum] || 0) + 1;
    var daha = o.mod === 'zor' ? 'orta' : o.mod === 'orta' ? 'kolay' : '';
    var oner = yandi && !!daha && yanmaSayisi[o.bolum] >= 2;
    var kb = $('#btn-kolaylas');
    kb.classList.toggle('gizli', !oner);
    if (oner) { kb.dataset.mod = daha; kb.textContent = C.MODLAR[daha].simge + ' ' + C.MODLAR[daha].ad + ' modda dene'; }
    // Kart küçük ekrana sığsın diye devam/öneri varken skor tablosu gizlenir
    $('#sonuc-tablo').classList.toggle('gizli', devamVar && oner);
    $('#btn-tekrar').classList.toggle('gizli', !o.kazandi || o.sonsuz);
    $('#btn-tekrar').parentNode.style.gridTemplateColumns = (o.kazandi && !o.sonsuz) ? '' : '1fr';
    ekran('sonuc');
    $('#hud').classList.add('gizli');
  }

  // ---------- Harita / sıralama ----------
  function haritaCiz() {
    var liste = $('#harita-liste'); liste.innerHTML = '';
    var sonDunya = '', toplam = 0, hedef = null;
    var sz = document.createElement('button');
    sz.className = 'bolum sonsuz-kart';
    sz.innerHTML = '<span class="no"><em>∞</em></span><span><b>2D Sonsuz Mod</b><small></small></span><span class="yl">▶</span>';
    kartResmi(sz.querySelector('.no'), ikiOnizleme('otoyol', null));
    sz.querySelector('small').textContent = 'En iyi skorun: ' + (ilerleme.sonsuz || 0);
    sz.addEventListener('click', function () { Ses.cal('tik'); bolumBaslat('sonsuz'); });
    liste.appendChild(sz);
    C.BOLUMLER.forEach(function (b) {
      var grup = b.dunya + '|' + (b.saat || '');
      if (grup !== sonDunya) {
        sonDunya = grup;
        var h = document.createElement('div'); h.className = 'dunya-baslik';
        h.textContent = C.DUNYALAR[b.dunya].ad + (b.saat ? ' · ' + SAAT_AD[b.saat].split(' ')[1] : '');
        liste.appendChild(h);
      }
      var y = ilerleme.yildiz[b.id] || 0; toplam += y;
      var kapali = sunucuAyar.kapaliBolumler.indexOf(b.id) >= 0;
      var kilitli = b.id > ilerleme.acik;
      var d = document.createElement('button');
      d.className = 'bolum' + (b.id === ilerleme.acik && !kapali ? ' siradaki' : '');
      d.disabled = kilitli || kapali;
      d.innerHTML = '<span class="no"><em></em></span><span><b></b><small></small></span><span class="yl"></span>';
      d.querySelector('.no em').textContent = kapali ? '⏸' : kilitli ? '🔒' : b.id;
      kartResmi(d.querySelector('.no'), ikiOnizleme(b.dunya, b.saat));
      d.querySelector('b').textContent = b.ad;
      d.querySelector('small').textContent = kapali ? 'Çok yakında' : (kadin ? '💅 ' : '📍 ') + musteriAd(b) + (ilerleme.skor[b.id] ? ' · ' + ilerleme.skor[b.id] + ' puan' : '');
      var enMod = ilerleme.mod[b.id];
      d.querySelector('.yl').innerHTML = [1, 2, 3].map(function (i) { return i <= y ? '★' : '<i>★</i>'; }).join('') +
        (enMod && C.MODLAR[enMod] ? '<span class="mod-rozet">' + C.MODLAR[enMod].simge + ' ' + C.MODLAR[enMod].ad + '</span>' : '');
      d.addEventListener('click', function () { Ses.cal('tik'); bolumBaslat(b.id); });
      liste.appendChild(d);
      if (b.id === ilerleme.acik) hedef = d;
      var bo = Odul.BOLGE_ODUL[b.id];
      if (bo) {
        var alindi = kese.bolgeler.indexOf(b.id) >= 0;
        var hazir = !alindi && [b.id - 2, b.id - 1, b.id].every(function (no) { return ilerleme.yildiz[no] > 0; });
        var s = document.createElement('button');
        s.className = 'bolge-sandik' + (hazir ? ' hazir' : '');
        s.disabled = !hazir;
        var ek = bo.urun ? ' + ' + Odul.urun(bo.urun).simge + ' ' + Odul.urun(bo.urun).ad : '';
        s.textContent = alindi ? '✔ Bölge ödülü alındı' : '🎁 Bölge sandığı: ' + bo.tarak + ' tarak' + ek + (hazir ? ' — AL!' : ' (' + (b.id - 2) + '-' + b.id + '. bölümleri geç)');
        s.addEventListener('click', function () { if (Odul.bolgeAl(kese, b.id)) { Ses.cal('kazandi'); keseKaydet(); haritaCiz(); } });
        liste.appendChild(s);
      }
    });
    $('#harita-yildiz').textContent = '★ ' + toplam + '/' + C.BOLUMLER.length * 3;
    ekran('harita');
    if (hedef) liste.scrollTop = Math.max(0, hedef.offsetTop - liste.clientHeight / 2);
  }

  function siralamaCiz(tur) {
    $$('.sekmeler button').forEach(function (b) { b.classList.toggle('secili', b.dataset.sekme === tur); });
    var l = $('#siralama-liste');
    function bos(m) { l.innerHTML = ''; var li = document.createElement('li'); li.className = 'bos'; li.textContent = m; l.appendChild(li); }
    bos('Yükleniyor…');
    (oturumSozu || oturumAc()).then(function (j) {
      return istek('siralama&tur=' + tur + (j ? '&jeton=' + encodeURIComponent(j) : ''));
    }).then(function (c) {
      if (!c || !c.liste) { bos(AYAR.beta ? 'Beta sürümünde sıralama kapalı. Oyun yayına alınınca açılacak.' : 'Sıralamaya şu an ulaşılamıyor. İnternet bağlantını kontrol et.'); return; }
      if (!c.liste.length) { bos('Henüz skor yok. İlk sen ol!'); return; }
      l.innerHTML = '';
      c.liste.forEach(function (s, i) {
        var li = document.createElement('li');
        if (s.ben) li.className = 'ben';
        li.innerHTML = '<span class="sira"></span><span></span><span></span>';
        li.children[0].textContent = i + 1; li.children[1].textContent = s.ad; li.children[2].textContent = s.skor;
        l.appendChild(li);
      });
    });
  }

  // ---------- Ödüller ----------
  // ---------- Gerçek hizmet hediyesi (Tarak Mobil'de kullanılır) ----------
  var hediyeDurum = null;
  function hediyeKartCiz() {
    var kart = $('#hediye-kart'), gerekli = (hediyeDurum && hediyeDurum.gerekli) || 20;
    var parca = hediyeDurum ? hediyeDurum.parca : Math.min(gerekli, kese.parca || 0);
    var ad = kadin ? ((hediyeDurum && hediyeDurum.kadinAd) || 'Manikür') : ((hediyeDurum && hediyeDurum.erkek) || 'Sakal Tıraşı');
    var yuzde = Math.min(100, Math.round(parca / gerekli * 100));
    kart.innerHTML = '<div class="hediye-ust"><span>🎟️</span><div><b></b><small></small></div></div><div class="hediye-cubuk"><i></i></div><p class="hediye-alt"></p>';
    kart.querySelector('b').textContent = 'Gerçek hediye: ' + ad;
    kart.querySelector('small').textContent = Math.min(parca, gerekli) + ' / ' + gerekli + ' parça · yılda bir kez';
    kart.querySelector('.hediye-cubuk i').style.width = yuzde + '%';
    var alt = kart.querySelector('.hediye-alt');
    if (hediyeDurum && hediyeDurum.kod) {
      alt.innerHTML = '';
      var kod = document.createElement('div'); kod.className = 'hediye-kod'; kod.textContent = hediyeDurum.kod; alt.appendChild(kod);
      var a = document.createElement('a'); a.className = 'sponsor-kart'; a.href = uygulamaAdresi(); a.target = '_blank'; a.rel = 'noopener';
      var sonT = hediyeDurum.sonTarih ? new Date(hediyeDurum.sonTarih * 1000).toLocaleDateString('tr-TR') : '';
      if (hediyeDurum.durum === 'suresi_doldu') { kod.style.textDecoration = 'line-through'; a.textContent = 'Bu kuponun süresi doldu. Yeni hediye hakkın gelecek yıl açılır.'; }
      else if (hediyeDurum.durum === 'kullanildi') a.textContent = hediyeDurum.ad + ' · Kullanıldı. Afiyet olsun! ✂️';
      else a.textContent = hediyeDurum.ad + ' · ' + (sonT ? sonT + ' tarihine kadar ' : '30 gün içinde ') + 'Tarak Mobil’de randevu alırken kullan →';
      alt.appendChild(a);
    } else if (AYAR.beta || !AYAR.api) {
      alt.textContent = 'Hediye parçaları zor yerlerde: otobüs tavanındaki arabanın ve kulelerin üstünde. Gerçek hediye kodu, oyunun tarak.app sürümünde verilir.';
    } else if (hediyeDurum && !hediyeDurum.aktif) {
      alt.textContent = 'Hediye kodları şu an kapalı. Parçaların birikmeye devam ediyor.';
    } else if (parca >= gerekli && hediyeDurum && hediyeDurum.tarak && !hediyeDurum.tarakBagli) {
      // Kupon Tarak hesabına (müşteri profili) yazılır: önce Tarak ile giriş
      alt.innerHTML = '';
      var tb = document.createElement('button'); tb.className = 'dugme sari tam'; tb.textContent = '🔑 Tarak ile giriş yap, hediyeni al';
      tb.addEventListener('click', function () { tarakGiris(false); });
      var not = document.createElement('small'); not.className = 'hediye-not'; not.textContent = 'Kuponun Tarak hesabındaki müşteri profiline kaydedilir; şifren oyuna değil yalnız Tarak’a gider.';
      alt.appendChild(tb); alt.appendChild(not);
    } else if (parca >= gerekli) {
      var b = document.createElement('button'); b.className = 'dugme sari tam'; b.textContent = '🎁 Hediyemi al: ' + ad;
      b.addEventListener('click', function () {
        b.disabled = true; b.textContent = 'Hazırlanıyor…';
        sunucuyaBildir('hediyeAl', { kadin: kadin }).then(function (c) {
          if (c && c.tarakGerekli) { hediyeDurum = Object.assign({}, hediyeDurum || {}, { tarak: true, tarakBagli: false }); hediyeKartCiz(); return; }
          if (c && c.kod) { hediyeDurum = c; Ses.cal('kazandi'); } else alt.textContent = (c && c.hata) || 'Şu an hediye alınamadı, biraz sonra tekrar dene.';
          if (c && c.kod) hediyeKartCiz();
        });
      });
      alt.innerHTML = ''; alt.appendChild(b);
    } else {
      alt.textContent = 'Parçalar yalnızca zor yerlerde çıkar: otobüs tavanındaki arabanın ve kulelerin üstünde, 2D’de çift zıplama yüksekliğinde. ' + gerekli + ' parçada Tarak Mobil’de kullanabileceğin bir ' + ad + ' kazanırsın.';
    }
  }
  // ---------- Tarak hesabıyla giriş ----------
  // Oyun tarak.app/oyun'da açıldığında sitede zaten giriş yapılmışsa şifresiz bağlanır (aynı oturum);
  // değilse Tarak'ın kendi giriş sayfası açılır, tek kullanımlık kodla oyuna dönülür. Şifre oyuna hiç gelmez.
  var tarakDurumu = { acik: false, bagli: false, ad: '' };
  function tarakJetonu() { try { return localStorage.getItem('berberim_auth_token'); } catch (e) { return null; } }
  function tarakDugmesi() {
    var b = $('#btn-tarak'); if (!b) return;
    b.classList.toggle('gizli', !tarakDurumu.acik);
    b.classList.toggle('bagli', tarakDurumu.bagli);
    $('#tarak-yazi').textContent = tarakDurumu.bagli ? 'Tarak hesabın bağlı' + (tarakDurumu.ad ? ': ' + tarakDurumu.ad : '') + ' ✓' : 'Tarak hesabınla giriş yap';
  }
  function tarakBaglandi(c) {
    tarakDurumu.bagli = true; tarakDurumu.ad = c.oyuncuAd || c.ad || tarakDurumu.ad;
    if (!isim && c.oyuncuAd) { isim = c.oyuncuAd; yaz('tm_isim', isim); isimYazisi(); }
    if (c.il && !(bolge && bolge.il)) { bolge = { il: c.il, ilce: c.ilce || '' }; yaz('tm_bolge', bolge); isimYazisi(); }
    if (c.sponsorlar) sponsorlariAl(c.sponsorlar);
    tarakDugmesi(); hediyeYenile();
  }
  function tarakGiris(sessiz) {
    if (!AYAR.api || AYAR.beta) return;
    var donus = location.href.split('?')[0].split('#')[0];
    sunucuyaBildir('tarakGiris', { donus: donus }).then(function (c) {
      if (!c || !c.url) { if (!sessiz) menuTost('Tarak bağlantısı şu an kullanılamıyor.'); return; }
      var durum = (c.url.match(/[?&]durum=([a-f0-9]+)/) || [])[1] || '';
      var tj = tarakJetonu();
      var ayniSite = /^https?:\/\/(www\.)?tarak\.app\//i.test(c.url) && location.hostname.replace(/^www\./, '') === 'tarak.app';
      if (tj && ayniSite) {
        fetch('/api/game/kod-al', { method: 'POST', headers: { Accept: 'application/json', Authorization: 'Bearer ' + tj } })
          .then(function (r) { return r.ok ? r.json() : null; })
          .then(function (j) {
            if (!j || !j.data || !j.data.kod) { if (!sessiz) location.href = c.url; return; }
            return sunucuyaBildir('tarakBagla', { kod: j.data.kod, durum: durum }).then(function (b) {
              if (b && b.tamam) { tarakBaglandi(b); menuTost('Tarak hesabınla giriş yapıldı' + (b.ad ? ', ' + b.ad : '') + ' ✂️'); }
              else if (!sessiz) menuTost('Tarak ile giriş tamamlanamadı.');
            });
          })
          .catch(function () { if (!sessiz) location.href = c.url; });
      } else if (!sessiz) location.href = c.url;
    });
  }
  function tarakCikis() {
    sunucuyaBildir('tarakCikis', {}).then(function () { tarakDurumu.bagli = false; tarakDugmesi(); hediyeYenile(); menuTost('Tarak hesabının oyunla bağlantısı kaldırıldı.'); });
  }
  function tarakDonusu() {
    var q = new URLSearchParams(location.search), kod = q.get('tarak_kod'), durum = q.get('durum');
    if (!kod) return;
    history.replaceState(null, '', location.pathname + location.hash);   // kod adres çubuğunda kalmasın
    sunucuyaBildir('tarakBagla', { kod: kod, durum: durum || '' }).then(function (c) {
      if (c && c.tamam) {
        menuTost('Tarak hesabın bağlandı' + (c.ad ? ', ' + c.ad : '') + ' ✂️');
        tarakBaglandi(c);
      } else menuTost((c && c.hata) || 'Tarak ile giriş tamamlanamadı.');
    });
  }
  function hediyeYenile() {
    hediyeKartCiz();
    if (!AYAR.api || AYAR.beta) return;
    sunucuyaBildir('hediye', { kadin: kadin }).then(function (c) { if (c && typeof c.parca === 'number') { hediyeDurum = c; hediyeKartCiz(); } });
  }

  function odulCiz() {
    hediyeYenile();
    var bugun = Odul.gunAdi(), d = Odul.gunlukDurum(kese, bugun);
    var iz = $('#gunluk-izgara'); iz.innerHTML = '';
    Odul.GUNLUK.forEach(function (miktar, i) {
      var k = document.createElement('div');
      var alinan = d.alindi ? i <= d.gun : i < d.gun;
      k.className = alinan ? 'alindi' : (!d.alindi && i === d.gun ? 'bugun' : '');
      k.innerHTML = '<span></span><b></b>';
      k.firstChild.textContent = alinan ? '✔ ' + (i + 1) + '. gün' : (i + 1) + '. gün';
      k.lastChild.textContent = miktar;
      iz.appendChild(k);
    });
    var b = $('#btn-gunluk');
    b.disabled = d.alindi;
    b.textContent = d.alindi ? 'Yarın yine gel' : '🎁 Bugünün ödülünü al (+' + d.miktar + ')';
    var sk = $('#sezon-kart'); sk.innerHTML = '';
    var sz = Odul.sezonDurum(kese, bugun);
    if (sz && !sz.alindi) {
      var kart = document.createElement('div'); kart.className = 'sezon-karti';
      kart.innerHTML = '<b></b><p></p><button class="dugme sari">Hediyemi al ve giy</button>';
      kart.querySelector('b').textContent = sz.bilgi.simge + ' ' + sz.bilgi.ad;
      kart.querySelector('p').textContent = sz.bilgi.metin;
      kart.querySelector('button').addEventListener('click', sezonHediyesi);
      sk.appendChild(kart);
    }
    var yolu = $('#seviye-yolu'); yolu.innerHTML = '';
    var sb = Odul.seviyeBilgi(kese.xp);
    for (var n = 2; n <= 12; n++) {
      var od = Odul.seviyeOdulu(n), satir = document.createElement('div');
      satir.className = 'sv' + (n <= sb.seviye ? ' acik' : n === sb.seviye + 1 ? ' siradaki' : '');
      satir.innerHTML = '<i></i><div><b></b><small></small></div><em></em>';
      satir.querySelector('i').textContent = n;
      satir.querySelector('b').textContent = od.urun ? od.urun.ad : od.tarak + ' tarak';
      satir.querySelector('small').textContent = n <= sb.seviye ? '✔ Açıldı' : (od.urun ? '+' + od.tarak + ' tarak da hediye' : 'Tarak ödülü') + (n === sb.seviye + 1 ? ' · ' + (sb.gereken - sb.icinde) + ' puan kaldı' : '');
      satir.querySelector('em').textContent = od.urun ? od.urun.simge : '💰';
      yolu.appendChild(satir);
    }
    var l = $('#gorev-liste'); l.innerHTML = '';
    Odul.gorevleriHazirla(kese, bugun).forEach(function (g) {
      var bl = Odul.gorevBilgi(g);
      var k = document.createElement('div'); k.className = 'gorev';
      k.innerHTML = '<div><b></b><br><small></small></div><button class="dugme"></button><div class="cubuk"><i></i></div>';
      k.querySelector('b').textContent = bl.metin;
      k.querySelector('small').textContent = bl.ilerleme + ' / ' + bl.hedef;
      var btn = k.querySelector('button');
      btn.textContent = bl.alindi ? '✔ Alındı' : '+' + bl.odul + ' tarak';
      btn.disabled = bl.alindi || !bl.tamam;
      if (bl.tamam && !bl.alindi) btn.classList.add('sari');
      btn.addEventListener('click', function () { if (Odul.gorevAl(kese, bl.id)) { Ses.cal('kalp'); keseKaydet(); odulCiz(); } });
      k.querySelector('i').style.width = Math.round(bl.ilerleme / bl.hedef * 100) + '%';
      l.appendChild(k);
    });
    keseKaydet();
    ekran('oduller');
  }

  var denenen = null, denemeZamani = 0;
  function denemeYaz(metin) {
    var y = $('#deneme-yazi');
    y.textContent = metin || '';
    y.classList.toggle('gizli', !metin);
    clearTimeout(denemeZamani);
    if (metin) denemeZamani = setTimeout(function () { y.classList.add('gizli'); }, 4000);
  }
  function denemeyiBitir() { if (denenen) { denenen = null; kusan(); } denemeYaz(''); }
  // Kilitli kıyafetler de K’nin üstünde denenebilir
  function dene(parcalar, metin) {
    var gecici = {};
    for (var y in kese.takili) gecici[y] = kese.takili[y];
    parcalar.forEach(function (id) { gecici[Odul.urun(id).yuva] = id; });
    denenen = parcalar.join();
    Uc.kusan(gecici); Ciz.kusan(gecici);
    denemeYaz(metin);
  }
  function kilitYazisi(x) {
    if (x.seviye) return '🔒 Seviye ' + x.seviye;
    if (x.sezon) { var sz = Odul.sezonDurum(kese, Odul.gunAdi()); return sz && !sz.alindi ? '🎄 Hediye!' : '🔒 Yılbaşında'; }
    if (x.bolge) return '🔒 Final sandığı';
    return x.fiyat + ' tarak';
  }

  function magazaCiz() {
    var l = $('#magaza-liste'), kaydirma = l.scrollTop; l.innerHTML = '';
    function baslik(m) { var h = document.createElement('div'); h.className = 'dunya-baslik'; h.textContent = m; l.appendChild(h); }
    function izgara(sinif) { var d = document.createElement('div'); d.className = sinif || 'urunler'; l.appendChild(d); return d; }
    function kart(hedef, simge, ad, alt, sinif, tikla) {
      var b = document.createElement('button'); b.className = 'urun ' + sinif;
      b.innerHTML = '<i></i><b></b><span></span>';
      b.children[0].textContent = simge; b.children[1].textContent = ad; b.children[2].textContent = alt;
      b.addEventListener('click', tikla);
      hedef.appendChild(b);
    }
    var sz = Odul.sezonDurum(kese, Odul.gunAdi());
    if (sz && !sz.alindi) {
      var sb = document.createElement('button'); sb.className = 'sezon';
      sb.style.width = '100%'; sb.style.marginTop = '10px';
      sb.textContent = sz.bilgi.simge + ' ' + sz.bilgi.ad + ': ücretsiz al ve giy';
      sb.addEventListener('click', sezonHediyesi);
      l.appendChild(sb);
    }
    baslik('Hazır kostümler');
    var kg = izgara('kostumler');
    Odul.KOSTUMLER.forEach(function (x) {
      var tamam = Odul.kostumVar(kese, x.id);
      var eksik = x.parcalar.filter(function (p) { return kese.sahip.indexOf(p) < 0; }).length;
      var giyili = x.parcalar.every(function (p) { return kese.takili[Odul.urun(p).yuva] === p; });
      kart(kg, x.simge, x.ad, giyili ? '✔ Üstünde' : tamam ? 'Giy' : 'Dene', giyili ? 'takili' : tamam ? '' : 'kilitli' + (denenen === x.parcalar.join() ? ' deneniyor' : ''), function () {
        if (tamam) { denenen = null; Odul.kostumGiy(kese, x.id); Ses.cal('kazandi'); keseKaydet(); kusan(); denemeYaz(''); }
        else { Ses.cal('tik'); dene(x.parcalar, '👀 Deneme: ' + x.ad + ' · ' + eksik + ' parça eksik'); }
        magazaCiz();
      });
    });
    Odul.YUVALAR.forEach(function (yuva) {
      baslik(yuva[1]);
      var u = izgara();
      Odul.URUNLER.filter(function (x) { return x.yuva === yuva[0]; }).forEach(function (x) {
        var sahip = kese.sahip.indexOf(x.id) >= 0, takili = kese.takili[x.yuva] === x.id;
        var sinif = takili ? 'takili' : sahip ? '' : (x.fiyat ? (kese.cuzdan < x.fiyat ? 'yetmez kilitli' : '') : 'kilitli') + (denenen === x.id ? ' deneniyor' : '');
        kart(u, x.simge, x.ad, takili ? '✔ Takılı' : sahip ? 'Tak' : kilitYazisi(x), sinif, function () {
          if (sahip) { denenen = null; Odul.takCikar(kese, x.id); Ses.cal('tik'); keseKaydet(); kusan(); denemeYaz(''); }
          else if (x.sezon && sz && !sz.alindi) { sezonHediyesi(); return; }
          else if (x.fiyat && denenen === x.id && Odul.satinAl(kese, x.id)) { denenen = null; Ses.cal('kazandi'); keseKaydet(); kusan(); denemeYaz('Hayırlı olsun! 🎉'); }
          else {
            Ses.cal('tik');
            dene([x.id], '👀 Deneme: ' + x.ad + (x.fiyat ? (kese.cuzdan >= x.fiyat ? ' · almak için tekrar dokun' : ' · ' + (x.fiyat - kese.cuzdan) + ' tarak eksik') : ' · ' + kilitYazisi(x).replace('🔒 ', '') + ' ile açılır'));
          }
          magazaCiz();
        });
      });
    });
    baslik('Güçlendiriciler (3D)');
    var gk = izgara();
    Odul.GUCLER.forEach(function (x) {
      kart(gk, x.simge, x.ad, x.fiyat + ' tarak · ' + kese.gucler[x.id] + ' adet', kese.cuzdan < x.fiyat ? 'yetmez' : '', function () {
        Ses.cal(Odul.satinAl(kese, x.id) ? 'kalp' : 'carpti'); keseKaydet(); magazaCiz();
      });
    });
    ekran('magaza');
    l.scrollTop = kaydirma;
  }

  // ---------- Girişler ----------
  function aksiyon(tur) {
    if (aktifEkran !== 'oyun' || !oyun) return;
    if (oyun.uc) { Uc.aksiyon(oyun, tur); return; }
    if (tur === 'sol' || tur === 'sag') return;
    if (tur === 'zipla') {
      var onceki = oyun.p.zipSayisi;
      C.zipla(oyun);
      if (onceki === 1 && oyun.p.zipSayisi === 2) taklaZ = 0.42;
    } else C.kay(oyun);
  }

  function dugmeBagla(id, tur) {
    var b = $(id);
    b.addEventListener('pointerdown', function (e) { e.preventDefault(); b.classList.add('basili'); aksiyon(tur); });
    ['pointerup', 'pointercancel', 'pointerleave'].forEach(function (o) { b.addEventListener(o, function () { b.classList.remove('basili'); }); });
  }
  dugmeBagla('#btn-zipla', 'zipla');
  dugmeBagla('#btn-kay', 'kay');
  dugmeBagla('#btn-sol', 'sol');
  dugmeBagla('#btn-sag', 'sag');

  // Dokunma: kısa dokunuş = zıpla, aşağı kaydırma = kay
  var parmaklar = {};
  function parmakIndi(e) {
    e.preventDefault();
    var k = { y: e.clientY, x: e.clientX, yapildi: false, uc: !!(oyun && oyun.uc) };
    // 3D'de yana kaydırma beklendiği için basılı tutunca zıplanmaz
    if (!k.uc) k.zaman = setTimeout(function () { if (!k.yapildi) { k.yapildi = true; aksiyon('zipla'); } }, 95);
    parmaklar[e.pointerId] = k;
  }
  tuval.addEventListener('pointerdown', parmakIndi);
  $('#tuval3d').addEventListener('pointerdown', parmakIndi);
  window.addEventListener('pointermove', function (e) {
    var k = parmaklar[e.pointerId];
    if (!k || k.yapildi) return;
    var dy = e.clientY - k.y, dx = e.clientX - k.x;
    if (k.uc) {
      if (Math.abs(dx) < 24 && Math.abs(dy) < 24) return;
      k.yapildi = true;
      aksiyon(Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'sag' : 'sol') : (dy > 0 ? 'kay' : 'zipla'));
      return;
    }
    if (dy > 22 && Math.abs(dy) > Math.abs(e.clientX - k.x)) { k.yapildi = true; clearTimeout(k.zaman); aksiyon('kay'); }
    else if (dy < -22) { k.yapildi = true; clearTimeout(k.zaman); aksiyon('zipla'); }
  });
  function parmakKalkti(e) {
    var k = parmaklar[e.pointerId];
    if (!k) return;
    clearTimeout(k.zaman);
    if (!k.yapildi && e.type === 'pointerup') aksiyon('zipla');
    delete parmaklar[e.pointerId];
  }
  window.addEventListener('pointerup', parmakKalkti);
  window.addEventListener('pointercancel', parmakKalkti);

  window.addEventListener('keydown', function (e) {
    if (e.target.tagName === 'INPUT') return;
    var zip = e.code === 'Space' || e.code === 'ArrowUp' || e.code === 'KeyW';
    var asagi = e.code === 'ArrowDown' || e.code === 'KeyS';
    if (aktifEkran === 'oyun' && (zip || asagi)) { e.preventDefault(); if (!e.repeat) aksiyon(zip ? 'zipla' : 'kay'); }
    var yana = e.code === 'ArrowLeft' || e.code === 'KeyA' ? 'sol' : e.code === 'ArrowRight' || e.code === 'KeyD' ? 'sag' : '';
    if (aktifEkran === 'oyun' && yana) { e.preventDefault(); if (!e.repeat) aksiyon(yana); }
    if (e.code === 'KeyP' || e.code === 'Escape') { if (aktifEkran === 'duraklat') devamEt(); else duraklat(); }
  });
  document.addEventListener('visibilitychange', function () { if (document.hidden) { duraklat(); Ses.muzikDur(); } });
  document.addEventListener('contextmenu', function (e) { e.preventDefault(); });

  // Android geri tuşu (WebView paketinden çağrılır). true: oyun tuşu kullandı.
  window.tarakGeri = function () {
    if (aktifEkran === 'oyun') { duraklat(); return true; }
    if (aktifEkran === 'duraklat') { devamEt(); return true; }
    if (aktifEkran === 'isim') { ekran('ana'); return true; }
    if (aktifEkran === 'sonuc') { oyundanCik(); return true; }
    if (aktifEkran !== 'ana' && aktifEkran !== 'bakim') { denemeyiBitir(); ekran('ana'); return true; }
    return false;
  };

  function tikla(s, f) { $(s).addEventListener('click', function () { Ses.hazirla(); Ses.cal('tik'); f(); }); }
  tikla('#btn-3d', function () { if (ucVar) rotalarCiz(); else haritaCiz(); });
  tikla('#btn-sezon', sezonHediyesi);
  tikla('#btn-oduller', odulCiz);
  tikla('#btn-magaza', magazaCiz);
  tikla('#btn-karakter', karakterEkrani);
  tikla('#btn-gunluk', function () { if (Odul.gunlukAl(kese, Odul.gunAdi())) { Ses.cal('kazandi'); keseKaydet(); odulCiz(); } });
  tikla('#btn-sandik', sandikAc);
  tikla('#btn-devam3d', ucDevam);
  tikla('#btn-bolumler', haritaCiz);
  tikla('#btn-siralama', function () { ekran('siralama'); siralamaCiz('uc'); });
  tikla('#btn-nasil', function () { ekran('nasil'); });
  tikla('#btn-yola', function () { oyunuBaslat(); });
  $$('#mod-secici button').forEach(function (b) { b.addEventListener('click', function () { Ses.hazirla(); Ses.cal('tik'); modSec(b.dataset.mod); }); });
  tikla('#btn-kontrol', function () { var yeni = C.kontroldenDevam(oyun); if (yeni) oyunuBaslat(yeni); });
  tikla('#btn-kolaylas', function () { modSec($('#btn-kolaylas').dataset.mod); oyunuBaslat(); });
  tikla('#btn-duraklat', duraklat);
  tikla('#btn-devam', devamEt);
  tikla('#btn-tekrar-d', function () { if (oyun && !oyun.uc && !oyun.bitti) kosuyuBildir(oyun, 'cikti'); oyunuBaslat(); });
  tikla('#btn-cik-d', oyundanCik);
  tikla('#btn-cik', oyundanCik);
  tikla('#btn-tekrar', function () { oyunuBaslat(); });
  tikla('#btn-sonraki', function () {
    var o = oyun;
    if (o && o.uc && o.kazandi) {
      var sr = U.ROTALAR[o.rota];
      if (sr && sr.plaka === U.ROTALAR[o.rota - 1].plaka) { rotaSec(o.rota + 1); oyunuBaslat(); return; }
      kosuKapat(); oyun = null; seciliIl = null; rotalarCiz(); return;
    }
    if (!o || o.uc || o.sonsuz || !o.kazandi) { oyunuBaslat(); return; }
    bolumBaslat(o.bolum === C.BOLUMLER.length ? 'sonsuz' : o.bolum + 1);
  });
  $$('.geri').forEach(function (b) { b.addEventListener('click', function () {
    Ses.cal('tik');
    if (aktifEkran === 'rotalar' && seciliIl) { seciliIl = null; haritaArama = ''; onayBekleyen = null; rotalarCiz(); return; }
    denemeyiBitir(); ekran('ana');
  }); });
  $$('.sekmeler button').forEach(function (b) { b.addEventListener('click', function () { siralamaCiz(b.dataset.sekme); }); });
  function sesYazisi() { $('#btn-ses').textContent = Ses.acikMi() ? '🔊' : '🔇'; $('#btn-ses-d').textContent = Ses.acikMi() ? '🔊 Ses Açık' : '🔇 Ses Kapalı'; }
  ['#btn-ses', '#btn-ses-d'].forEach(function (s) { $(s).addEventListener('click', function () { if (Ses.degistir()) Ses.cal('kazandi'); sesYazisi(); }); });
  $$('.randevu').forEach(function (a) { a.addEventListener('click', function () { sunucuyaBildir('tiklama', { tur: 'randevu' }); }); });

  function isimYazisi() { $('#isim-yazi').textContent = (isim || 'İsmini yaz') + (bolge && bolge.il ? ' · ' + bolge.il : ''); }
  // Oyuncunun kendi seçtiği bölge: sponsor reklamları ve hediyeler bu bölgeden gelir (oynanan harita serbest)
  var bolge = oku('tm_bolge', { il: '', ilce: '' });
  function bolgeSecici() {
    var si = $('#bolge-il'), sc = $('#bolge-ilce');
    if (si.options.length < 2) U.ILLER.forEach(function (il) { var op = document.createElement('option'); op.value = op.textContent = il.ad; si.appendChild(op); });
    si.value = bolge.il || '';
    function ilceler() {
      sc.innerHTML = '<option value="">İlçe</option>';
      var il = U.ILLER.filter(function (x) { return x.ad === si.value; })[0];
      if (il) U.ROTALAR.slice(il.ilk - 1, il.son).forEach(function (r) { var op = document.createElement('option'); op.value = op.textContent = r.ilce; sc.appendChild(op); });
      sc.disabled = !il;
    }
    si.onchange = function () { ilceler(); sc.value = ''; };
    ilceler(); sc.value = bolge.ilce || '';
  }
  function sponsorlariAl(liste) { if (liste && Uc.sponsorlar) Uc.sponsorlar(liste); }
  tikla('#btn-isim', function () { $('#isim-girdi').value = isim; bolgeSecici(); ekran('isim'); });
  tikla('#btn-isim-kapat', function () { ekran('ana'); });
  tikla('#btn-tarak', function () {
    if (!tarakDurumu.bagli) { tarakGiris(false); return; }
    if (confirm('Tarak hesabının oyunla bağlantısı kaldırılsın mı? Kazandığın kuponlar Tarak hesabında kalır.')) tarakCikis();
  });
  $('#isim-form').addEventListener('submit', function (e) {
    e.preventDefault();
    isim = $('#isim-girdi').value.trim().slice(0, 16);
    var yeni = { il: $('#bolge-il').value, ilce: $('#bolge-ilce').value };
    var degisti = yeni.il !== bolge.il || yeni.ilce !== bolge.ilce;
    bolge = yeni; yaz('tm_bolge', bolge);
    yaz('tm_isim', isim); isimYazisi(); ekran('ana');
    sunucuyaBildir('isim', { isim: isim });
    if (degisti) sunucuyaBildir('bolge', bolge).then(function (c) { sponsorlariAl(c && c.sponsorlar); if (bolge.il) menuTost('📍 ' + bolge.il + (bolge.ilce ? ' · ' + bolge.ilce : '') + ' bölgesindeki berberlerin kampanyaları sana gelecek.'); });
  });

  // ---------- Efektler ----------
  function sac(x, y, adet, renk, guc) {
    for (var i = 0; i < adet; i++) parcaciklar.push({ x: x, y: y, vx: (Math.random() - 0.5) * guc, vy: Math.random() * guc * 0.7, t: 0.5 + Math.random() * 0.35, renk: renk, r: 2 + Math.random() * 3.5 });
  }
  // Uçan yazılar aynı yere düşerse üst üste binmesin: yakındaki taze yazının üstüne kaydır
  function yazi(metin, x, y, renk) {
    for (var d = 0; d < 5; d++) {
      var dolu = yazilar.some(function (z) { return z.t > 0.35 && Math.abs(z.x - x) < 130 && Math.abs(z.y - y) < 34; });
      if (!dolu) break;
      y += 36;
    }
    yazilar.push({ metin: metin, x: x, y: y, t: 0.9, renk: renk || '#fff' });
  }
  function titret(ms) { if (navigator.vibrate && Ses.acikMi()) { try { navigator.vibrate(ms); } catch (e) {} } }

  function olaylariIsle() {
    var o = oyun, p = o.p;
    o.olaylar.forEach(function (e) {
      if (e.tur !== 'indi') Ses.cal(e.tur === 'sandik' ? 'kalp' : e.tur);
      if (e.tur === 'zipla' || e.tur === 'indi') sac(p.x - 6, 2, 6, 'rgba(235,225,205,.9)', 110);
      else if (e.tur === 'zipla2') sac(p.x, p.y + 10, 10, '#ffc400', 170);
      else if (e.tur === 'turbo') { yazi('TURBO!', p.x + 20, 110, '#ffc400'); }
      else if (e.tur === 'tarak') sac(e.ek.x, e.ek.y, 4, '#ffe36e', 120);
      else if (e.tur === 'carpti') { sarsinti = 0.35; titret(120); sac(p.x, p.y + 50, 18, '#ff4d6d', 260); yazi('-1 ♥', p.x, p.y + 140, '#ff4d6d'); }
      else if (e.tur === 'kirdi') { sarsinti = 0.15; titret(40); sac(e.ek.x + 20, 30, 18, '#c99a5f', 320); yazi('+25', e.ek.x, 100, '#ffc400'); }
      else if (e.tur === 'sandik') { sac(e.ek.x, e.ek.y, 22, '#ffd23f', 260); yazi('🎁 HEDİYE!', p.x + 30, p.y + 150, '#ffd23f'); }
      else if (e.tur === 'parca') { sac(e.ek.x, e.ek.y, 26, '#ff3d8b', 300); yazi('🎟️ Hediye parçası!', p.x + 30, p.y + 170, '#ff7eb3'); }
      else if (e.tur === 'kalkan') yazi('KALKAN!', p.x, p.y + 140, '#7fd8ff');
      else if (e.tur === 'kalkanKirildi') { sac(p.x, p.y + 50, 16, '#7fd8ff', 250); yazi('Kalkan korudu', p.x, p.y + 140, '#7fd8ff'); }
      else if (e.tur === 'miknatis') yazi('TARAK ÇEKİCİ!', p.x + 30, p.y + 140, '#ffc400');
      else if (e.tur === 'kalp') yazi('+1 ♥', p.x, p.y + 140, '#ff4d6d');
      else if (e.tur === 'kontrol') { yazi(o.kontrolSayisi > 1 ? 'Az kaldı! 🚩' : 'Bayrak alındı! 🚩', p.x + 60, 190, '#fff'); if (o.dunya.bolgeler && o.dunya.bolgeler.length) yazi('⚡ Hızlanıyorsun!', p.x + 60, 150, '#ffc400'); }
      else if (e.tur === 'kazandi' || e.tur === 'kaybetti') { bitisZamani = e.tur === 'kazandi' ? 1.5 : 0.9; Ses.muzikDur(); kosuyuBildir(o, e.tur); }
    });
    o.olaylar.length = 0;
  }

  // ---------- HUD ----------
  var hudSon = '';
  var IPUCU_METNI = { engel: '⤴ ZIPLA!', yuksek: '⇈ İKİ KEZ ZIPLA!', tabela: '⤵ KAY!', cukur: '⤴ ATLA!', tunel: '⏩ İKİ KEZ KAY!', lastik: '⤴ ZIPLA!', koli: '⏩ 2× KAY, KIR!', buyukCukur: '⇈ ÇİFT ZIPLA!' };
  var TUR_ESLE = { engel: 'kutu', yuksek: 'yuksek', tabela: 'tabela', tunel: 'tunel', lastik: 'lastik', koli: 'koli' };

  function ipucuBul() {
    var o = oyun;
    if (o.sonsuz || o.bitti) return '';
    var p = o.p, v = C.hiz(o);
    // İlk bölümlerde yüksek engel uyarısı hep görünür: en çok takılınan hareket bu.
    var ogret = o.tanim.yeni.slice();
    if (o.bolum <= 4 && ogret.indexOf('yuksek') < 0) ogret.push('yuksek');
    var hepsi = o.mod === 'kolay';
    if (hepsi) ogret = ['yuksek', 'tunel', 'tabela', 'buyukCukur', 'cukur', 'lastik', 'koli', 'engel'];
    for (var i = 0; i < ogret.length; i++) {
      var y = ogret[i], liste;
      if (y === 'cukur' || y === 'buyukCukur') liste = o.dunya.cukurlar.filter(function (c) { return (c.w > v * 0.6) === (y === 'buyukCukur'); });
      else liste = o.dunya.engeller.filter(function (e) { return e.tur === TUR_ESLE[y]; });
      for (var j = 0; j < (hepsi ? liste.length : Math.min(2, liste.length)); j++) {
        var d = liste[j].x - p.x;
        if (d < v * 0.85 && d > -liste[j].w * 0.4) return IPUCU_METNI[y];
      }
    }
    return '';
  }

  function hudGuncelle() {
    var o = oyun;
    var guc = (o.kalkan ? '<span>🛡 Kalkan</span>' : '') + (o.miknatis > 0 ? '<span>🧲 ' + Math.ceil(o.miknatis) + ' sn</span>' : '') + (o.sandik ? '<span>🎁 ' + o.sandik + '</span>' : '');
    var ipucu = ipucuBul();
    var oran = o.sonsuz ? 0 : Math.max(0, Math.min(100, o.p.x / o.dunya.uzunluk * 100));
    $('#hud-yol-dolu').style.width = oran + '%';
    $('#hud-yol-k').style.left = oran + '%';
    var imza = [o.can, o.tarak, C.skor(o), guc, ipucu].join('|');
    if (imza === hudSon) return;
    hudSon = imza;
    var can = '';
    // Android "♥" karakterini renkli emoji çizdiği için kalpler SVG: kaybedilen can gri görünür.
    for (var i = 0; i < o.canMax; i++) can += '<svg viewBox="0 0 24 22"' + (i < o.can ? '' : ' class="bos"') + '><path d="M12 21C5 16 1 12 1 7a5.500 5.500 0 0 1 11-1 5.500 5.500 0 0 1 11 1c0 5-4 9-11 14Z"/></svg>';
    $('#hud-can').innerHTML = can;
    $('#hud-tarak').textContent = o.tarak;
    $('#hud-skor').textContent = C.skor(o);
    $('#hud-guc').innerHTML = guc;
    $('#hud-ipucu').textContent = ipucu;
    $('#hud-ipucu').classList.toggle('gizli', !ipucu);
  }

  // ---------- Çizim ----------
  function ciz(dt) {
    g.setTransform(dpr * olcek, 0, 0, dpr * olcek, 0, 0);
    var zy = Math.round(H * (W > H ? 0.8 : 0.725));

    if (!oyun) { vitrinCiz(zy); return; }

    var o = oyun, p = o.p, d = o.dunya;
    var kx = Math.max(92, Math.min(W * 0.22, 220));
    var kamera = p.x - kx;
    var dunya = o.sonsuz ? ['sehir', 'otoyol', 'orman', 'in'][Math.floor(p.x / 9000) % 4] : o.tanim.dunya;

    if (sarsinti > 0) { sarsinti -= dt; g.translate((Math.random() - 0.5) * sarsinti * 26, (Math.random() - 0.5) * sarsinti * 18); }
    Ciz.arkaPlan(g, W, H, zy, kamera, dunya, toplamZaman);
    g.fillStyle = dunya === 'sehir' ? 'rgba(205,232,250,.3)' : dunya === 'orman' ? 'rgba(220,240,205,.16)' : 'rgba(40,20,50,.14)';
    g.fillRect(0, 0, W, zy);
    Ciz.zemin(g, W, H, zy, kamera, dunya, d.cukurlar);
    Ciz.saatKatmani(g, W, H, zy, o.tanim ? o.tanim.saat : null, toplamZaman);
    if (!o.sonsuz) {
      d.kontroller.forEach(function (kx_, i) {
        var bx = kx_ - kamera;
        if (bx < -60 || bx > W + 60) return;
        g.fillStyle = '#e8e8ee'; g.fillRect(bx, zy - 90, 4, 90);
        g.fillStyle = i < o.kontrolSayisi ? '#35c46a' : '#ffc400';
        g.beginPath(); g.moveTo(bx + 4, zy - 90); g.lineTo(bx + 40, zy - 78); g.lineTo(bx + 4, zy - 64); g.fill();
      });
      if (d.uzunluk - kamera < W + 60) Ciz.bitisCiz(g, d.uzunluk - kamera, zy, o.tanim, toplamZaman);
    }
    d.engeller.forEach(function (e) {
      var sx = e.x - kamera;
      if (e.kirildi || sx > W + 30 || sx + e.w < -30) return;
      Ciz.engelCiz(g, e, sx, zy, dunya, toplamZaman);
    });
    d.nesneler.forEach(function (n) {
      var sx = n.x - kamera;
      if (n.alindi || sx > W + 30 || sx < -30) return;
      Ciz.nesneCiz(g, n, sx, zy - n.y, toplamZaman);
    });

    // Gölge + maskot
    if (!p.dusuyor && p.y >= 0) {
      g.fillStyle = 'rgba(0,0,0,' + Math.max(0.08, 0.3 - p.y / 700) + ')';
      g.beginPath(); g.ellipse(kx + 3, zy + 4, Math.max(10, 30 - p.y / 11), 6, 0, 0, 6.2832); g.fill();
    }
    var poz = 'kos';
    if (p.kayis > 0 && p.yerde) poz = 'kay';
    else if (!p.yerde) poz = 'zipla';
    if (o.bitti && o.kazandi) poz = 'dur';
    var takla = 0;
    if (taklaZ > 0) { taklaZ -= dt; if (!p.yerde) takla = (1 - Math.max(0, taklaZ) / 0.42) * 6.2832; }
    var yanSon = p.dokunulmaz > 0 && Math.floor(toplamZaman * 12) % 2 === 0;
    g.save();
    if (yanSon) g.globalAlpha = 0.35;
    if (p.dusuyor) { g.beginPath(); g.rect(0, 0, W, H); g.clip(); }
    if (poz === 'kay' && p.turbo) {
      for (var i = 3; i >= 1; i--) { g.save(); g.globalAlpha = 0.13 * (4 - i); Ciz.maskot(g, kx - i * 22, zy - p.y, 'kay', 0, { olcek: 1.06 }); g.restore(); }
      g.strokeStyle = 'rgba(255,255,255,.75)'; g.lineWidth = 3;
      for (var s = 0; s < 4; s++) { var yy = zy - 10 - s * 15, off = (toplamZaman * 500 + s * 37) % 50; g.beginPath(); g.moveTo(kx - 62 - off, yy); g.lineTo(kx - 100 - off, yy); g.stroke(); }
    }
    Ciz.maskot(g, kx, zy - p.y, poz, kosuFaz, { vy: p.vy, takla: takla, olcek: poz === 'kay' ? 1.06 : 1.1 });
    g.restore();
    if (poz === 'kay' && Math.random() < 0.6) sac(p.x - 26, 3, 1, p.turbo ? '#ffc400' : 'rgba(235,225,205,.8)', 90);
    if (o.kalkan) {
      g.strokeStyle = 'rgba(127,216,255,.85)'; g.lineWidth = 3;
      g.beginPath(); g.ellipse(kx, zy - p.y - (poz === 'kay' ? 28 : 58), 52, poz === 'kay' ? 40 : 70, 0, 0, 6.2832); g.stroke();
    }

    // Parçacık ve uçan yazılar
    parcaciklar = parcaciklar.filter(function (q) {
      q.t -= dt; q.vy -= 500 * dt; q.x += q.vx * dt; q.y += q.vy * dt;
      if (q.t <= 0) return false;
      g.globalAlpha = Math.min(1, q.t * 2.4); Ciz.daire(g, q.x - kamera, zy - q.y, q.r, q.renk); g.globalAlpha = 1;
      return true;
    });
    yazilar = yazilar.filter(function (q) {
      q.t -= dt; q.y += 45 * dt;
      if (q.t <= 0) return false;
      g.globalAlpha = Math.min(1, q.t * 2); g.font = '900 19px system-ui'; g.textAlign = 'center'; g.textBaseline = 'middle';
      g.lineWidth = 4; g.strokeStyle = 'rgba(20,22,25,.85)'; g.strokeText(q.metin, q.x - kamera, zy - q.y);
      g.fillStyle = q.renk; g.fillText(q.metin, q.x - kamera, zy - q.y); g.globalAlpha = 1;
      return true;
    });
  }

  // Ana menü arkasında koşan maskot
  function vitrinCiz(zy) {
    var kamera = toplamZaman * 150;
    var dunya = ['sehir', 'orman', 'otoyol', 'in'][Math.floor(toplamZaman / 9) % 4];
    var yer = Math.round(H * (W > H ? 0.8 : 0.585));
    Ciz.arkaPlan(g, W, H, yer, kamera, dunya, toplamZaman);
    Ciz.zemin(g, W, H, yer, kamera, dunya, []);
    var t = toplamZaman % 4.2, y = 0, poz = 'kos';
    if (t > 2.6 && t < 3.31) { var u = t - 2.6; y = 780 * u - 1100 * u * u; poz = 'zipla'; }
    g.fillStyle = 'rgba(0,0,0,.25)'; g.beginPath(); g.ellipse(W / 2, yer + 6, 56 - y / 6, 10, 0, 0, 6.2832); g.fill();
    Ciz.maskot(g, W / 2 - 6, yer - y * 0.8, poz, toplamZaman * 10.5, { olcek: 1.75, vy: 780 - 2200 * (t - 2.6), canta: true });
    for (var i = 0; i < 3; i++) {
      var tx = W - ((kamera * 1.2 + i * 190) % (W + 80)) + 30;
      Ciz.tarakSimge(g, tx, yer - 235 - Math.sin(toplamZaman * 3 + i) * 10, 1.3, -0.3);
    }
  }

  function dongu(zaman) {
    requestAnimationFrame(dongu);
    if (!sonZaman) sonZaman = zaman;
    var dt = Math.min(0.05, (zaman - sonZaman) / 1000);
    sonZaman = zaman;
    var ucOyunu = !!(oyun && oyun.uc);
    // Menüde, ödüllerde ve mağazada 3D maskot gösterilir
    var vitrin = ucVar && !oyun && (aktifEkran === 'ana' || aktifEkran === 'magaza' || aktifEkran === 'oduller' || aktifEkran === 'siralama' || aktifEkran === 'nasil' || aktifEkran === 'isim');
    Uc.goster(ucOyunu || vitrin);
    tuval.style.visibility = ucOyunu || vitrin ? 'hidden' : 'visible';
    if (aktifEkran === 'duraklat') return;
    toplamZaman += dt;
    // Rota ekranındayken her karede bir rota kartının resmi çekilir (ekran opak, sahne görünmez)
    if (aktifEkran === 'rotalar' && rotaKuyruk.length && ucVar) {
      var rn = rotaKuyruk.shift(), url = Uc.onizleme(rn);
      if (url) { onizlemeler[rn] = url; kartResmi(document.querySelector('[data-rota-resim="' + rn + '"]'), url); }
    }
    if (ucOyunu) {
      Uc.kare(oyun, dt, toplamZaman, aktifEkran === 'oyun', function () { bitisZamani = oyun.kazandi ? 2.2 : 1.5; Ses.muzikDur(); Ses.cal(oyun.kazandi ? 'kazandi' : 'kaybetti'); });
      if (oyun.bitti && aktifEkran === 'oyun' && bitisZamani > 0) { bitisZamani -= dt; if (bitisZamani <= 0) ucSonuc(); }
      return;
    }
    if (vitrin) {
      if (aktifEkran === 'ana' || aktifEkran === 'magaza') Uc.vitrin(dt, toplamZaman, { alan: vitrinAlani(), sevinc: aktifEkran === 'ana' && toplamZaman % 9 > 6.6 });
      return;
    }
    if (oyun && aktifEkran === 'oyun') {
      birikim += dt;
      while (birikim >= DT) {
        onceki2D = { x: oyun.p.x, y: oyun.p.y };
        C.adim(oyun, DT);
        birikim -= DT;
      }
      kosuFaz += dt * C.hiz(oyun) / 21;
      olaylariIsle();
      hudGuncelle();
      if (oyun.bitti && bitisZamani > 0) { bitisZamani -= dt; if (bitisZamani <= 0) sonucGoster(); }
    }
    // 2D'de de çizim son iki fizik adımı arasında ara değerle (kare hızı farklarında takılma olmasın)
    if (oyun && aktifEkran === 'oyun' && !oyun.bitti && onceki2D && Math.abs(oyun.p.x - onceki2D.x) < 40) {
      var a2 = birikim / DT, gx = oyun.p.x, gy = oyun.p.y;
      oyun.p.x = onceki2D.x + (gx - onceki2D.x) * a2; oyun.p.y = onceki2D.y + (gy - onceki2D.y) * a2;
      try { ciz(dt); } finally { oyun.p.x = gx; oyun.p.y = gy; }
    } else ciz(dt);
  }
  var onceki2D = null;

  // ---------- Başlat ----------
  // Hangi sürümün oynandığını görmek için (her yayında artırılır)
  var SURUM = 'Sürüm 17 · 10 yeni tam vücutlu karakter, açılış ekranı';
  $('#surum').textContent = SURUM;
  boyutla(); sesYazisi(); isimYazisi(); cuzdanYaz();
  if (!ucVar) $('#btn-3d').classList.add('gizli');
  // Açılış ekranı: seçili karakter ortada, yanında kadrodan karakterler; hazır olunca kaybolur (dokununca hemen)
  function acilisKadro() {
    var kap = $('#acilis-kadro'); if (!kap || !window.TarakKare) return;
    var secili = KR.bul(karakterId), digerleri = KR.LISTE.filter(function (t) { return t.tur === 'insan' && t.id !== secili.id; });
    var dizi = [digerleri[1], digerleri[6], digerleri[3], secili, digerleri[8], digerleri[0], digerleri[5]].filter(Boolean);
    dizi.forEach(function (t, i) {
      var u = t.tur === 'insan' ? portreAl(t) : null;
      if (!u) { var cv = document.createElement('canvas'); cv.width = 240; cv.height = 300; karakterResmi(cv, t, 2, 296); u = cv.toDataURL(); }
      var im = new Image(); im.src = u; im.alt = t.ad; im.style.animationDelay = (Math.abs(i - 3) * 0.08) + 's';
      if (t === secili) im.className = 'orta';
      kap.appendChild(im);
    });
  }
  function acilisKapat() { var a = $('#acilis'); if (!a || a.classList.contains('kapan')) return; a.classList.add('kapan'); setTimeout(function () { a.remove(); }, 500); }
  (function () { var a = $('#acilis'); if (a) a.addEventListener('click', acilisKapat); })();
  Ciz.hazir.then(function () {
    try { acilisKadro(); } catch (e) { /* açılış resmi çizilemese de oyun açılır */ }
    setTimeout(acilisKapat, 1700);
    karakterUygula(); requestAnimationFrame(dongu);
    if (oku('tm_cinsiyet', '') === '') setTimeout(karakterEkrani, 400);   // ilk açılışta karakter seçimi
    kartResmi($('#btn-bolumler'), ikiOnizleme('orman', 'aksam'));
    // 3D kartı: seçili rotanın oyun içinden resmi (fotoğraf dokuları yüklenince)
    if (ucVar) setTimeout(function () { var u = Uc.onizleme(rota); if (u) { onizlemeler[rota] = u; kartResmi($('#btn-3d'), u); } }, 1800);
  });
  ayarlariUygula();   // sunucu yoksa da (beta) platforma uygun uygulama bağlantıları kurulur
  istek('ayar').then(function (a) {
    if (a && typeof a.oyunAktif === 'boolean') {
      for (var k in a) sunucuAyar[k] = a[k];
      ayarlariUygula();
    }
  });
  oturumAc();
  tarakDonusu();   // "Tarak ile giriş" sayfasından dönüldüyse hesabı bağla
  // tarak.app'te giriş yapılmışsa oyun aynı hesapla kendiliğinden bağlanır
  (oturumSozu || oturumAc()).then(function () { if (tarakDurumu.acik && !tarakDurumu.bagli && tarakJetonu() && !/[?&]tarak_kod=/.test(location.search)) tarakGiris(true); });
  if (bolge.il) sunucuyaBildir('sponsorlar', {}).then(function (c) { sponsorlariAl(c && c.sponsorlar); });
  setInterval(function () { if (!document.hidden && jeton) istek('nabiz', { jeton: jeton }); }, 45000);

  if (!AYAR.beta && 'serviceWorker' in navigator && location.protocol === 'https:') navigator.serviceWorker.register('sw.js').catch(function () {});

  // Yalnızca yerel geliştirmede test kancası
  if (location.hostname === 'localhost' || location.hostname === '127.0.0.1') {
    window.tarakTest = {
      durum: function () { return { ekran: aktifEkran, oyun: oyun }; }, ekran: function (a) { if (a === 'rotalar') rotalarCiz(); if (a === 'magaza') magazaCiz(); if (a === 'oduller') odulCiz(); if (a === 'karakter') { karakterEkrani(); return; } ekran(a); },
      basla: function (n, z, r) { secim = n; if (z) modSec(z); if (r) rota = r; oyunuBaslat(); },
      kese: function () { return kese; }, keseKaydet: keseKaydet, kusan: kusan, sahne: function () { return Uc.sahneAl(); },
      ilerlet: function (sn) { var s = 0; while (oyun && !oyun.bitti && s < sn) { C.adim(oyun, DT); s += DT; } kosuFaz = oyun ? oyun.p.x / 21 : 0; if (oyun) { oyun.olaylar.length = 0; hudSon = ''; hudGuncelle(); } }
    };
  }
})();
