/* 3D koşunun arayüz bağlantısı: sahne, göstergeler ve olaylar. */
(function () {
  'use strict';
  var U = window.TarakUc, Ses = window.TarakSes;
  var $ = function (s) { return document.querySelector(s); };
  var DT = 1 / 120;

  var sahne = null, denendi = false, birikim = 0, hudSon = '', yaziZaman = 0, kadinMod = false;
  function kadin(k) { kadinMod = !!k; if (sahne) sahne.kadin(kadinMod); }
  var karakterId = 'koko';
  function karakter(id) { karakterId = id || 'koko'; if (sahne && sahne.karakter) sahne.karakter(karakterId); }
  function karakterTanim() { return window.TarakKarakterler ? window.TarakKarakterler.bul(karakterId) : null; }

  // WebGL yoksa oyun 2D olarak çalışmaya devam eder.
  function hazirla() {
    if (denendi) return !!sahne;
    denendi = true;
    try {
      if (window.THREE && window.TarakSahne) sahne = window.TarakSahne.olustur($('#tuval3d'), $('#kap3d'), { ses: function (ad) { Ses.cal(ad); } });
      if (sahne && kadinMod) sahne.kadin(true);
      if (sahne && sahne.karakter && karakterId !== 'koko') sahne.karakter(karakterId);
      if (sahne && sponsorListesi.length) sahne.sponsorlar(sponsorListesi);
    } catch (e) { sahne = null; if (window.console) console.warn('3D başlatılamadı: ' + e.message); }
    return !!sahne;
  }

  function goster(acik) { $('#kap3d').classList.toggle('gizli', !acik); }

  function baslat(mod, gucler, hizCarpani, rota) {
    gucler = gucler || {}; gucler.rota = rota; gucler.kadin = kadinMod;
    // Karakter özelliği: koşuya küçük bir başlangıç avantajı
    var kt = karakterTanim(), ozl = kt && kt.ozellik;
    if (ozl === 'kalkan') gucler.kalkan = true;
    if (ozl === 'miknatis') gucler.miknatis = true;
    // İlçenin gerçek caddesi yüklendiyse rota baştan sona o caddede kurulur
    var rt = U.ROTALAR[U.rotaAl(rota) - 1], gv = rt && window.TarakCadde ? window.TarakCadde.hazir(rt.plaka, rt.sira) : null;
    if (gv && gv.uzunluk) gucler.gercek = { uzunluk: gv.uzunluk };
    var o = U.yeniOyun(mod, gucler);
    o.uc = true; o.hizCarpani = (hizCarpani || 1) * o.rotaT.hiz;
    if (ozl === 'ikikat') o.ikiKat = 12;
    if (ozl === 'can') { o.canMax += 1; o.can += 1; }
    o.bildirildi = false; o.islendi = false;
    setTimeout(function () {
      if (!o.rotaT) return;
      var gc = sahne && sahne.cadde && sahne.cadde();
      var ad = gc ? gc.ad.split(' ').map(function (s) { return s.charAt(0).toLocaleUpperCase('tr-TR') + s.slice(1); }).join(' ') : o.rotaT.cadde;
      buyukYazi('📍 ' + o.rotaT.il + ' · ' + o.rotaT.ilce + '\n' + ad, 2.4);
    }, 400);
    birikim = 0; hudSon = ''; yaziZaman = 0; onceki = null;
    sahne.temizle();
    $('#uc-yazi').classList.add('gizli');
    return o;
  }

  function buyukYazi(metin, sure) {
    var y = $('#uc-yazi');
    y.textContent = metin; y.classList.remove('gizli');
    y.style.animation = 'none'; void y.offsetWidth; y.style.animation = '';
    yaziZaman = sure || 1.4;
  }

  function titret(ms) { if (navigator.vibrate && Ses.acikMi() && navigator.userActivation && navigator.userActivation.hasBeenActive) { try { navigator.vibrate(ms); } catch (e) {} } }

  function olaylar(o, bitince) {
    var p = o.p;
    o.olaylar.forEach(function (e) {
      var ses = { serit: 'tik', durak: 'kazandi', ikikat: 'miknatis', jet: 'turbo', sandik: 'kalp', korna: 'korna', devam: 'kalp', jetBitti: 'tik' }[e.tur] || e.tur;
      if (e.tur !== 'indi') Ses.cal(ses);
      if (e.tur === 'tarak') sahne.sac(e.ek.x, e.ek.y, -0.2, 0xffe36e, 3, 3);
      else if (e.tur === 'carpti') { sahne.sars(0.4); titret(130); sahne.sac(p.x, p.y + 1, -0.3, 0xff4d6d, 18, 6); }
      else if (e.tur === 'kirdi') { sahne.sars(0.18); titret(40); sahne.sac(e.ek.serit * U.S.serit, 0.6, -0.8, 0xc99a5f, 22, 7); }
      else if (e.tur === 'zipla2') sahne.sac(p.x, p.y + 0.2, 0, 0xffc400, 10, 3);
      else if (e.tur === 'zipla') sahne.sac(p.x, p.y + 0.05, 0.1, 0xe8dcc4, 6, 2.2);
      else if (e.tur === 'indi') { sahne.sars(0.09); sahne.sac(p.x, p.y + 0.05, 0.1, 0xe8dcc4, 8, 2.6); }
      else if (e.tur === 'serit') sahne.yatir(p.serit - p.oncekiSerit);
      else if (e.tur === 'turbo') buyukYazi('TURBO!', 0.8);
      else if (e.tur === 'kalkan') buyukYazi('🛡️ Kalkan');
      else if (e.tur === 'kalkanKirildi') buyukYazi('🛡️ Kalkan korudu');
      else if (e.tur === 'miknatis') buyukYazi('🧲 Tarak Çekici');
      else if (e.tur === 'ikikat') buyukYazi('2× Çift Kazanç');
      else if (e.tur === 'jet') buyukYazi('🚀 FÖN JET!', 1.8);
      else if (e.tur === 'kalp') buyukYazi('❤️ +1 Can');
      else if (e.tur === 'sandik') buyukYazi('🎁 Sandık kazandın!');
      else if (e.tur === 'parca') { buyukYazi('🎟️ Hediye parçası!\nGerçek hizmet hediyesine bir adım', 1.8); sahne.sac(p.x, p.y + 1.2, -0.2, 0xff3d8b, 26, 6); }
      else if (e.tur === 'durak') {
        if (!e.ek.son) buyukYazi((kadinMod ? '💅 ' + e.ek.ad + ' · ' + e.ek.hizmet + ' tamam!' : '📍 ' + e.ek.ad + ' tıraş oldu!') + '\n+' + e.ek.odul + ' puan · 🎁 sandık', 2.6);
        sahne.sac(0, 3, -1, kadinMod ? 0xff6fa5 : 0xffc400, 40, 9);
      }
      else if (e.tur === 'kaybetti') bitince();
      else if (e.tur === 'rotaBitti') { buyukYazi('🏁 Rota tamamlandı!\n+' + (300 + e.ek.rota * 20) + ' puan', 2.4); sahne.sac(0, 3, -1, 0xffc400, 60, 10); bitince(); }
    });
    o.olaylar.length = 0;
  }

  function hud(o) {
    var guc = (o.kalkan ? '<span>🛡️ Kalkan</span>' : '') + (o.miknatis > 0 ? '<span>🧲 ' + Math.ceil(o.miknatis) + ' sn</span>' : '') +
      (o.ikiKat > 0 ? '<span>2× ' + Math.ceil(o.ikiKat) + ' sn</span>' : '') + (o.jet > 0 ? '<span>🚀 ' + Math.ceil(o.jet) + ' sn</span>' : '') +
      (o.sandik > 0 ? '<span>🎁 ' + o.sandik + '</span>' : '');
    var hedef = null;
    for (var i = 0; i < o.duraklar.length; i++) if (!o.duraklar[i].gecildi) { hedef = o.duraklar[i]; break; }
    var metre = Math.floor(o.p.s);
    if (!hedef) hedef = o.kazandi ? { ad: 'Rota tamamlandı', s: o.p.s, son: true } : { ad: U.musteriAdi(o, o.duraklar.length), s: o._durakSira };
    var alt = (hedef.son ? '🏁 ' : '📍 ') + hedef.ad + ' · ' + Math.max(0, Math.ceil((hedef.s - o.p.s) / 5) * 5) + ' m  |  👤 ' + Math.min(o.musteri + 1, o.hedefMusteri) + '/' + o.hedefMusteri;
    // İlk metrelerde kontrol anlatımı
    var ipucu = o.p.s < 24 ? '⬅️ ➡️ kaydır: şerit değiştir' : o.p.s < 60 ? '⬆️ zıpla · ⬇️ kay (2× turbo)' : '';
    var imza = [o.can, o.tarak, U.skor(o), guc, alt, ipucu, yaziZaman > 0].join('|');
    if (imza === hudSon) return;
    hudSon = imza;
    var can = '';
    for (var c = 0; c < o.canMax; c++) can += '<svg viewBox="0 0 24 22"' + (c < o.can ? '' : ' class="bos"') + '><path d="M12 21C5 16 1 12 1 7a5.500 5.500 0 0 1 11-1 5.500 5.500 0 0 1 11 1c0 5-4 9-11 14Z"/></svg>';
    $('#hud-can').innerHTML = can;
    $('#hud-tarak').textContent = o.tarak;
    $('#hud-skor').textContent = U.skor(o);
    $('#hud-guc').innerHTML = guc;
    $('#hud-bolum').textContent = alt;
    $('#hud-ipucu').textContent = ipucu;
    // Büyük yazı (il · cadde, güç adı) görünürken ipucu gizlenir: ikisi aynı yerde üst üste biniyordu
    $('#hud-ipucu').classList.toggle('gizli', !ipucu || yaziZaman > 0);
  }

  // Oyun sürerken her karede
  // Fizik saniyede 120 adım; ekran 60/90/120/144 Hz olabilir. Çizim son iki adım arasında ara değerle yapılır
  // (yoksa bir karede 0, ötekinde 2-3 adım düşer ve koşu kare kare kayar / takılır).
  var onceki = null;
  function anlik(o) {
    var e = [], s0 = o.p.s;
    for (var i = 0; i < o.engeller.length; i++) { var x = o.engeller[i]; if ((x.ileri || x.tetik) && x.s > s0 - 15 && x.s < s0 + 220) e.push(x, x.s); }
    return { s: o.p.s, x: o.p.x, y: o.p.y, e: e };
  }
  function kare(o, dt, zaman, calisiyor, bitince) {
    var a = 0;
    if (calisiyor) {
      birikim += dt;
      while (birikim >= DT) { onceki = anlik(o); U.adim(o, DT); birikim -= DT; }
      a = birikim / DT;
      olaylar(o, bitince);
      hud(o);
      if (yaziZaman > 0) { yaziZaman -= dt; if (yaziZaman <= 0) $('#uc-yazi').classList.add('gizli'); }
    }
    var p = o.p, ara = calisiyor && onceki && !o.bitti && Math.abs(p.s - onceki.s) < 3 && Math.abs(p.x - onceki.x) < 2;
    if (!ara) { sahne.ciz(o, calisiyor ? dt : 0, zaman); return; }
    var gs = p.s, gx = p.x, gy = p.y, es = [], i;
    p.s = onceki.s + (gs - onceki.s) * a; p.x = onceki.x + (gx - onceki.x) * a; p.y = onceki.y + (gy - onceki.y) * a;
    for (i = 0; i < onceki.e.length; i += 2) { var e = onceki.e[i]; es.push(e.s); e.s = onceki.e[i + 1] + (e.s - onceki.e[i + 1]) * a; }
    try { sahne.ciz(o, dt, zaman); }
    finally {
      p.s = gs; p.x = gx; p.y = gy;
      for (i = 0; i < onceki.e.length; i += 2) onceki.e[i].s = es[i / 2];
    }
  }

  function vitrin(dt, zaman, secenek) { sahne.ciz(null, dt, zaman, secenek); }

  function aksiyon(o, tur) {
    if (tur === 'zipla') U.zipla(o);
    else if (tur === 'kay') U.kay(o);
    else if (tur === 'sol') U.seritDegistir(o, -1);
    else if (tur === 'sag') U.seritDegistir(o, 1);
  }

  function kusan(takili) { if (sahne) sahne.maskot.kusan(takili || {}); }
  var sponsorListesi = [];
  function sponsorlar(l) { sponsorListesi = l || []; if (sahne) sahne.sponsorlar(sponsorListesi); }
  function gosterilenSponsorlar() { return sahne ? sahne.gosterilen() : []; }

  // Rota kartları için oyun sahnesinden çekilmiş küçük resim
  function onizleme(no, w, h) { return sahne ? sahne.onizleme(U.ROTALAR[no - 1], w || 320, h || 200) : null; }

  window.TarakUcOyun = { karakter: karakter, sponsorlar: sponsorlar, gosterilenSponsorlar: gosterilenSponsorlar, kadin: kadin, onizleme: onizleme, hazirla: hazirla, goster: goster, baslat: baslat, kare: kare, vitrin: vitrin, aksiyon: aksiyon, kusan: kusan, sahneAl: function () { return sahne; } };
})();
