/* Tuval çizimi: arka planlar, engeller ve maskot K. */
(function () {
  'use strict';
  var C = window.TarakCore;

  var resim = {};
  function yukle(ad, dosya) {
    return new Promise(function (tamam) {
      var im = new Image();
      im.onload = function () { resim[ad] = im; tamam(); };
      im.onerror = function () { tamam(); };
      im.src = 'assets/img/' + dosya;
    });
  }
  // Arkadaki kol/bacak için koyu kopyalar bir kez üretilir (her karede filtre telefonda yavaşlatır).
  function koyuKopya(ad) {
    var im = resim[ad];
    if (!im) return;
    var t = document.createElement('canvas'); t.width = im.width; t.height = im.height;
    var c = t.getContext('2d');
    c.drawImage(im, 0, 0);
    c.globalCompositeOperation = 'source-atop';
    c.fillStyle = 'rgba(0,0,0,.22)'; c.fillRect(0, 0, t.width, t.height);
    resim[ad + 'Koyu'] = t;
  }
  var hazir = Promise.all([
    yukle('govde', 'k-govde.png'), yukle('eldiven', 'k-eldiven.png'), yukle('ayakkabi', 'k-ayakkabi.png'), yukle('logo', 'logo-acik.svg')
  ]).then(function () { koyuKopya('eldiven'); koyuKopya('ayakkabi'); pembeKopya('govde'); pembeKopya('ayakkabi'); pembeKopya('ayakkabiKoyu'); });

  // Kadın modu (Kiki): sarı tonlar gül pembesine çevrilir (siyah, beyaz ve gri olduğu gibi kalır)
  var kadinMod = false;
  function pembeKopya(ad) {
    var im = resim[ad];
    if (!im) return;
    var t = document.createElement('canvas'); t.width = im.width; t.height = im.height;
    var c = t.getContext('2d'); c.drawImage(im, 0, 0);
    try {
      var v = c.getImageData(0, 0, t.width, t.height), d = v.data;
      for (var i = 0; i < d.length; i += 4) {
        var r = d[i], g = d[i + 1], b = d[i + 2], mx = Math.max(r, g, b), mn = Math.min(r, g, b);
        if (mx - mn < 60 || r < 120 || b > g) continue;           // gri/siyah/beyaz ve mavi tonlar
        var h = (g - b) / (mx - mn) * 60;                          // r en büyükken ton açısı
        if (r !== mx || h < 12 || h > 75) continue;                // yalnızca sarı-turuncu
        var l = (mx + mn) / 2 / 255, s2 = (mx - mn) / 255;
        d[i] = Math.min(255, 255 * (l + s2 * 0.42)); d[i + 1] = Math.max(0, 255 * (l - s2 * 0.2)); d[i + 2] = Math.min(255, 255 * (l + s2 * 0.08));
      }
      c.putImageData(v, 0, 0);
    } catch (e) { return; }
    resim[ad + 'K'] = t;
  }
  function kadin(k) { kadinMod = !!k; }

  var TEMA = {
    sehir: { gok: ['#7ecbff', '#cdeeff', '#ffe7bf'], uzak: '#9db7d6', orta: '#e9a16b', zemin: '#c9c3b8', zeminUst: '#e6e0d3', toprak: '#4a4640', cizgi: '#aaa398' },
    otoyol: { gok: ['#4a3f86', '#e0698a', '#ffc36b'], uzak: '#7a4d7e', orta: '#4f3560', zemin: '#41424b', zeminUst: '#575964', toprak: '#26262d', cizgi: '#ffd23f' },
    orman: { gok: ['#a9dcc0', '#dcf0bd', '#f6f3c4'], uzak: '#6e9f6a', orta: '#3f7444', zemin: '#8a6442', zeminUst: '#6e9a3c', toprak: '#4b3323', cizgi: '#a87d52' },
    in: { gok: ['#2b1b47', '#a03d52', '#ff9a42'], uzak: '#6d2f3f', orta: '#3f1e2b', zemin: '#a96f35', zeminUst: '#d99a43', toprak: '#4a2a18', cizgi: '#7e4f27' }
  };

  function tohum(n) { var s = Math.sin(n * 127.1) * 43758.5453; return s - Math.floor(s); }

  function yuvarlak(g, x, y, w, h, r) {
    r = Math.min(r, w / 2, h / 2);
    g.beginPath();
    g.moveTo(x + r, y);
    g.arcTo(x + w, y, x + w, y + h, r);
    g.arcTo(x + w, y + h, x, y + h, r);
    g.arcTo(x, y + h, x, y, r);
    g.arcTo(x, y, x + w, y, r);
    g.closePath();
  }
  function kutu(g, x, y, w, h, r, renk) { g.fillStyle = renk; yuvarlak(g, x, y, w, h, r); g.fill(); }
  function daire(g, x, y, r, renk) { g.fillStyle = renk; g.beginPath(); g.arc(x, y, r, 0, 6.2832); g.fill(); }
  function cokgen(g, n, renk) {
    g.fillStyle = renk; g.beginPath(); g.moveTo(n[0], n[1]);
    for (var i = 2; i < n.length; i += 2) g.lineTo(n[i], n[i + 1]);
    g.closePath(); g.fill();
  }

  // Ekran üzerinde tekrar eden parallax katmanı
  function katman(g, W, kamera, oran, aralik, ciz) {
    var ofs = kamera * oran;
    var ilk = Math.floor(ofs / aralik) - 2;
    var son = Math.ceil((ofs + W) / aralik) + 2;
    for (var i = ilk; i <= son; i++) ciz(i * aralik - ofs, i);
  }

  // ---------- Arka planlar ----------
  function arkaPlan(g, W, H, zy, kamera, dunya, t) {
    var T = TEMA[dunya];
    var gr = g.createLinearGradient(0, 0, 0, zy);
    gr.addColorStop(0, T.gok[0]); gr.addColorStop(0.58, T.gok[1]); gr.addColorStop(1, T.gok[2]);
    g.fillStyle = gr; g.fillRect(0, 0, W, H);

    if (dunya === 'sehir') {
      daire(g, W * 0.78, zy * 0.2, 34, '#fff3b0');
      bulutlar(g, W, zy, kamera, t, 'rgba(255,255,255,.85)');
      katman(g, W, kamera, 0.12, 74, function (x, i) {
        var h = 110 + tohum(i) * 190;
        kutu(g, x, zy - h, 66, h, 4, T.uzak);
        g.fillStyle = 'rgba(255,255,255,.35)';
        for (var yy = zy - h + 14; yy < zy - 20; yy += 22) for (var xx = x + 10; xx < x + 56; xx += 18) g.fillRect(xx, yy, 9, 11);
      });
      katman(g, W, kamera, 0.45, 168, function (x, i) { dukkan(g, x, zy, i); });
    } else if (dunya === 'otoyol') {
      daire(g, W * 0.7, zy * 0.62, 52, '#ffd98a');
      bulutlar(g, W, zy, kamera, t, 'rgba(255,190,190,.4)');
      tepeler(g, W, zy, kamera, 0.1, 230, 150, T.uzak);
      tepeler(g, W, zy, kamera, 0.2, 180, 95, T.orta);
      katman(g, W, kamera, 0.45, 210, function (x) {
        g.fillStyle = '#2f2440'; g.fillRect(x, zy - 150, 5, 150); g.fillRect(x, zy - 150, 30, 5);
        daire(g, x + 30, zy - 144, 6, '#ffeaa0');
        daire(g, x + 30, zy - 144, 16, 'rgba(255,234,160,.18)');
      });
      katman(g, W, kamera, 0.7, 62, function (x) { g.fillStyle = '#b9b7c9'; g.fillRect(x, zy - 34, 6, 34); });
      g.fillStyle = '#d6d4e4'; g.fillRect(0, zy - 34, W, 8); g.fillStyle = '#8f8da3'; g.fillRect(0, zy - 24, W, 4);
    } else if (dunya === 'orman') {
      daire(g, W * 0.25, zy * 0.18, 30, '#fffbd8');
      katman(g, W, kamera, 0.1, 62, function (x, i) {
        var h = 150 + tohum(i + 3) * 130;
        cokgen(g, [x, zy, x + 40, zy - h, x + 80, zy], T.uzak);
      });
      katman(g, W, kamera, 0.3, 116, function (x, i) { agac(g, x, zy, 0.95 + tohum(i) * 0.5, T.orta, '#4a3524'); });
      katman(g, W, kamera, 0.6, 230, function (x, i) { agac(g, x + tohum(i) * 80, zy + 4, 0.55, '#5c9442', '#5d422b'); });
      g.save(); g.globalAlpha = 0.09; g.fillStyle = '#fff7c0';
      for (var k = 0; k < 4; k++) cokgen(g, [W * (0.1 + k * 0.27), 0, W * (0.19 + k * 0.27), 0, W * (k * 0.27 - 0.08), zy, W * (k * 0.27 - 0.22), zy], '#fff7c0');
      g.restore();
    } else {
      daire(g, W * 0.72, zy * 0.5, 70, '#ffcf6a');
      for (var y = 0; y < 40; y++) { g.fillStyle = 'rgba(255,255,255,' + (0.25 + tohum(y) * 0.5) + ')'; g.fillRect(tohum(y * 3) * W, tohum(y * 7) * zy * 0.35, 2, 2); }
      tepeler(g, W, zy, kamera, 0.1, 260, 175, T.uzak);
      tepeler(g, W, zy, kamera, 0.22, 150, 90, T.orta);
      katman(g, W, kamera, 0.42, 270, function (x, i) { akasya(g, x + tohum(i) * 90, zy, 0.85 + tohum(i + 9) * 0.35); });
    }
  }

  function bulutlar(g, W, zy, kamera, t, renk) {
    katman(g, W, kamera + t * 60, 0.05, 190, function (x, i) {
      var y = zy * (0.1 + tohum(i) * 0.25);
      daire(g, x, y, 17, renk); daire(g, x + 22, y - 9, 22, renk); daire(g, x + 46, y, 16, renk); kutu(g, x - 4, y, 54, 16, 8, renk);
    });
  }

  function tepeler(g, W, zy, kamera, oran, aralik, yuk, renk) {
    katman(g, W, kamera, oran, aralik, function (x, i) {
      var h = yuk * (0.6 + tohum(i) * 0.5);
      g.fillStyle = renk; g.beginPath(); g.moveTo(x - 90, zy);
      g.bezierCurveTo(x + 30, zy - h * 1.2, x + aralik * 0.6, zy - h * 1.2, x + aralik + 90, zy); g.fill();
    });
  }

  function agac(g, x, zy, o, yaprak, govde) {
    g.fillStyle = govde; g.fillRect(x - 8 * o, zy - 120 * o, 16 * o, 120 * o);
    daire(g, x, zy - 150 * o, 48 * o, yaprak); daire(g, x - 38 * o, zy - 118 * o, 36 * o, yaprak);
    daire(g, x + 38 * o, zy - 118 * o, 36 * o, yaprak);
    daire(g, x - 12 * o, zy - 168 * o, 24 * o, 'rgba(255,255,200,.1)');
  }

  function akasya(g, x, zy, o) {
    g.strokeStyle = '#2c1219'; g.lineWidth = 8 * o; g.lineCap = 'round';
    g.beginPath(); g.moveTo(x, zy); g.lineTo(x + 4 * o, zy - 80 * o); g.lineTo(x - 30 * o, zy - 130 * o);
    g.moveTo(x + 4 * o, zy - 80 * o); g.lineTo(x + 38 * o, zy - 132 * o); g.stroke();
    kutu(g, x - 80 * o, zy - 154 * o, 105 * o, 30 * o, 15 * o, '#2c1219');
    kutu(g, x - 5 * o, zy - 166 * o, 100 * o, 34 * o, 17 * o, '#2c1219');
  }

  var DUKKAN_ADI = ['BERBER', 'FIRIN', 'ÇAY EVİ', 'tarak', 'MANAV', 'KIRTASİYE'];
  var DUKKAN_ADI_K = ['KUAFÖR', 'GÜZELLİK', 'MANİKÜR', 'tarak', 'ÇİÇEKÇİ', 'BUTİK'];
  var DUKKAN_RENK = ['#e8845c', '#5aa7b8', '#d9a441', '#2b2e35', '#7fae62', '#b77fb0'];
  function dukkan(g, x, zy, i) {
    var n = ((i % 6) + 6) % 6, h = 128 + (n % 3) * 18;
    kutu(g, x, zy - h, 150, h, 6, DUKKAN_RENK[n]);
    kutu(g, x + 10, zy - h + 12, 130, 24, 6, '#1c2023');
    if (n === 3 && resim.logo) g.drawImage(resim.logo, x + 45, zy - h + 10, 60, 27);
    else { g.fillStyle = '#fff'; g.font = '700 15px system-ui, sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText((kadinMod ? DUKKAN_ADI_K : DUKKAN_ADI)[n], x + 75, zy - h + 25); }
    for (var s = 0; s < 7; s++) { g.fillStyle = s % 2 ? '#fff' : '#d9534f'; g.fillRect(x + 8 + s * 19, zy - 78, 19, 13); }
    kutu(g, x + 14, zy - 60, 74, 50, 3, '#cfeefa'); kutu(g, x + 102, zy - 62, 32, 62, 3, '#5a3b2e');
    g.fillStyle = 'rgba(255,255,255,.55)'; cokgen(g, [x + 22, zy - 56, x + 44, zy - 56, x + 26, zy - 14, x + 18, zy - 14], 'rgba(255,255,255,.55)');
    if (n === 0 || n === 3) berberDiregi(g, x + 90, zy - 62, 9, 46, performance.now() / 1000);
  }

  function berberDiregi(g, x, y, w, h, t) {
    g.save(); yuvarlak(g, x, y, w, h, 4); g.clip();
    g.fillStyle = '#fff'; g.fillRect(x, y, w, h);
    for (var k = -2; k < h / 10 + 2; k++) {
      var yy = y + k * 20 + (t * 22 % 20);
      cokgen(g, [x, yy, x + w, yy - 7, x + w, yy - 1, x, yy + 6], '#e03b3b');
      cokgen(g, [x, yy + 10, x + w, yy + 3, x + w, yy + 9, x, yy + 16], '#2f6fd6');
    }
    g.restore();
    kutu(g, x - 2, y - 4, w + 4, 6, 3, '#c9ccd4'); kutu(g, x - 2, y + h - 2, w + 4, 6, 3, '#c9ccd4');
  }

  // ---------- Zemin ----------
  function zemin(g, W, H, zy, kamera, dunya, cukurlar) {
    var T = TEMA[dunya];
    g.fillStyle = T.toprak; g.fillRect(0, zy, W, H - zy);
    g.fillStyle = T.zemin; g.fillRect(0, zy, W, 42);
    g.fillStyle = T.zeminUst; g.fillRect(0, zy, W, 9);
    if (dunya === 'otoyol') {
      katman(g, W, kamera, 1, 90, function (x) { g.fillStyle = T.cizgi; g.fillRect(x, zy + 23, 46, 5); });
    } else if (dunya === 'sehir') {
      katman(g, W, kamera, 1, 54, function (x) { g.strokeStyle = T.cizgi; g.lineWidth = 2; g.beginPath(); g.moveTo(x, zy + 9); g.lineTo(x - 12, zy + 42); g.stroke(); });
    } else {
      katman(g, W, kamera, 1, 37, function (x, i) {
        kutu(g, x + tohum(i) * 20, zy + 15 + tohum(i + 5) * 20, 8 + tohum(i + 2) * 9, 4, 2, T.cizgi);
        cokgen(g, [x, zy + 1, x + 4, zy - 7 - tohum(i) * 5, x + 8, zy + 1], T.zeminUst);
      });
    }
    katman(g, W, kamera, 1, 73, function (x, i) { daire(g, x + tohum(i) * 40, zy + 66 + tohum(i * 3) * 80, 3 + tohum(i + 1) * 5, 'rgba(255,255,255,.07)'); });

    for (var i = 0; i < cukurlar.length; i++) {
      var c = cukurlar[i], sx = c.x - kamera;
      if (sx > W || sx + c.w < 0) continue;
      var gr = g.createLinearGradient(0, zy, 0, zy + 170);
      if (dunya === 'orman') { gr.addColorStop(0, '#59c4dd'); gr.addColorStop(1, '#0d3b55'); }
      else { gr.addColorStop(0, '#22140f'); gr.addColorStop(1, '#050304'); }
      g.fillStyle = gr; g.fillRect(sx, zy - 1, c.w, H - zy + 1);
      for (var s = 0; s < 3; s++) {
        cokgen(g, [sx - 12 - s * 7, zy - 3, sx - 5 - s * 7, zy - 3, sx - 11 - s * 7, zy + 6, sx - 18 - s * 7, zy + 6], s % 2 ? '#1c2023' : '#ffc400');
      }
      g.fillStyle = '#ffc400'; g.fillRect(sx - 4, zy - 3, 4, 14); g.fillRect(sx + c.w, zy - 3, 4, 14);
    }
  }

  // ---------- Engeller ----------
  function engelCiz(g, e, sx, zy, dunya, t) {
    var w = e.w, h = e.y1;
    g.save();
    if (e.y0 === 0) { g.fillStyle = 'rgba(0,0,0,.22)'; g.beginPath(); g.ellipse(sx + w / 2, zy + 3, w * 0.62, 6, 0, 0, 6.2832); g.fill(); }
    if (e.tur === 'kutu') {
      if (dunya === 'sehir' || dunya === 'otoyol') {
        if (e.cesit === 0) { // trafik konisi
          cokgen(g, [sx + 5, zy, sx + w / 2 - 6, zy - h, sx + w / 2 + 6, zy - h, sx + w - 5, zy], '#ff7a1a');
          cokgen(g, [sx + 12, zy - h * 0.38, sx + 15, zy - h * 0.56, sx + w - 15, zy - h * 0.56, sx + w - 12, zy - h * 0.38], '#fff');
          kutu(g, sx, zy - 7, w, 7, 3, '#c2560c');
        } else if (e.cesit === 1) { // tıraş köpüğü tüpü
          kutu(g, sx + 6, zy - h + 10, w - 12, h - 10, 9, '#2f6fd6');
          kutu(g, sx + 12, zy - h + 1, w - 24, 12, 4, '#d7dbe3');
          kutu(g, sx + 6, zy - h * 0.55, w - 12, 16, 0, '#fff');
          g.fillStyle = '#2f6fd6'; g.font = '800 9px system-ui'; g.textAlign = 'center'; g.fillText('KÖPÜK', sx + w / 2, zy - h * 0.55 + 11);
          daire(g, sx + w / 2 - 6, zy - h, 6, '#fff'); daire(g, sx + w / 2 + 3, zy - h - 3, 8, '#fff');
        } else { // çöp kutusu
          kutu(g, sx + 4, zy - h + 8, w - 8, h - 8, 5, '#4f7d63');
          kutu(g, sx + 1, zy - h, w - 2, 11, 4, '#35594a');
          g.fillStyle = 'rgba(0,0,0,.2)'; for (var i = 0; i < 3; i++) g.fillRect(sx + 12 + i * 9, zy - h + 17, 4, h - 25);
        }
      } else if (e.cesit === 2) { // kütük
        kutu(g, sx, zy - h, w, h, 8, '#7a4a28'); g.fillStyle = '#5c361c'; for (var k = 0; k < 3; k++) g.fillRect(sx + 9 + k * 11, zy - h + 8, 3, h - 12);
        g.fillStyle = '#d8ab72'; g.beginPath(); g.ellipse(sx + w / 2, zy - h + 3, w / 2, 7, 0, 0, 6.2832); g.fill();
        g.strokeStyle = '#9c7044'; g.lineWidth = 1.5; g.beginPath(); g.ellipse(sx + w / 2, zy - h + 3, w / 4, 3.5, 0, 0, 6.2832); g.stroke();
      } else { // kaya
        cokgen(g, [sx, zy, sx + 4, zy - h * 0.6, sx + 15, zy - h, sx + 31, zy - h * 0.9, sx + w, zy - h * 0.45, sx + w - 2, zy], dunya === 'in' ? '#8a5a45' : '#82868a');
        cokgen(g, [sx + 15, zy - h, sx + 31, zy - h * 0.9, sx + 25, zy - h * 0.55, sx + 10, zy - h * 0.62], 'rgba(255,255,255,.22)');
      }
    } else if (e.tur === 'genis') { // berber bekleme bankı
      kutu(g, sx, zy - h, w, 15, 6, '#c0392b'); kutu(g, sx + 4, zy - h + 17, w - 8, 12, 4, '#8e2a20');
      g.fillStyle = '#2b2e35'; g.fillRect(sx + 7, zy - 18, 7, 18); g.fillRect(sx + w - 14, zy - 18, 7, 18);
      kutu(g, sx + 4, zy - h + 3, w - 8, 3, 2, 'rgba(255,255,255,.35)');
    } else if (e.tur === 'yuksek') {
      var bh = h / 3;
      for (var j = 0; j < 3; j++) {
        var by = zy - (j + 1) * bh;
        if (dunya === 'otoyol') { // lastik yığını
          kutu(g, sx, by + 1, w, bh - 2, 17, '#202126'); kutu(g, sx + 6, by + 8, w - 12, bh - 18, 8, '#3b3d45');
          g.fillStyle = '#ffc400'; g.fillRect(sx + w / 2 - 3, by + bh / 2 - 3, 6, 6);
        } else {
          kutu(g, sx, by + 1, w, bh - 2, 5, dunya === 'sehir' ? '#c98a4b' : '#80512d');
          g.strokeStyle = 'rgba(60,30,10,.55)'; g.lineWidth = 3.5;
          g.strokeRect(sx + 5, by + 6, w - 10, bh - 12);
          g.beginPath(); g.moveTo(sx + 6, by + bh - 7); g.lineTo(sx + w - 6, by + 7); g.stroke();
        }
      }
      g.fillStyle = '#fff'; g.font = '800 16px system-ui'; g.textAlign = 'center'; g.fillText('▲▲', sx + w / 2, zy - h - 7);
    } else if (e.tur === 'tabela') {
      var alt = zy - e.y0;
      if (dunya === 'sehir' || dunya === 'otoyol') {
        g.strokeStyle = '#4b4f59'; g.lineWidth = 3; g.beginPath(); g.moveTo(sx + 9, 0); g.lineTo(sx + 9, alt - 80); g.moveTo(sx + w - 9, 0); g.lineTo(sx + w - 9, alt - 80); g.stroke();
        kutu(g, sx - 8, alt - 84, w + 16, 84, 9, '#1c2023');
        kutu(g, sx - 4, alt - 80, w + 8, 76, 7, '#ffc400');
        g.fillStyle = '#1c2023'; g.textAlign = 'center'; g.font = '900 13px system-ui';
        g.fillText(dunya === 'sehir' ? (kadinMod ? 'KUAFÖR' : 'BERBER') : 'DİKKAT', sx + w / 2, alt - 52);
        g.font = '900 26px system-ui'; g.fillText('▼', sx + w / 2, alt - 18);
      } else {
        kutu(g, sx + 8, -20, w - 16, alt - 8, 9, '#4f321d');
        daire(g, sx + 4, alt - 34, 25, '#356b32'); daire(g, sx + w - 2, alt - 30, 24, '#3f7b39'); daire(g, sx + w / 2, alt - 24, 24, '#4b8c3f');
        daire(g, sx + w / 2, alt - 70, 28, '#356b32');
        g.fillStyle = '#ffe36e'; g.font = '900 20px system-ui'; g.textAlign = 'center'; g.fillText('▼', sx + w / 2, alt - 19);
      }
    } else if (e.tur === 'tunel') {
      var a = zy - e.y0;
      var gr = g.createLinearGradient(0, a - 150, 0, a);
      if (dunya === 'sehir' || dunya === 'otoyol') { gr.addColorStop(0, '#5b5f6b'); gr.addColorStop(1, '#8a8f9c'); }
      else { gr.addColorStop(0, '#33231a'); gr.addColorStop(1, '#6b4a33'); }
      g.fillStyle = gr; yuvarlak(g, sx, a - 170, w, 170, 14); g.fill();
      g.save(); g.beginPath(); g.rect(sx, a - 16, w, 16); g.clip();
      g.fillStyle = '#ffc400'; g.fillRect(sx, a - 16, w, 16);
      for (var s = -16; s < w + 16; s += 26) cokgen(g, [sx + s, a, sx + s + 13, a, sx + s + 29, a - 16, sx + s + 16, a - 16], '#1c2023');
      g.restore();
      kutu(g, sx + w / 2 - 62, a - 70, 124, 34, 9, '#1c2023');
      g.fillStyle = '#ffc400'; g.font = '900 14px system-ui'; g.textAlign = 'center'; g.fillText('⏩ TURBO x2', sx + w / 2, a - 48);
    } else if (e.tur === 'lastik') {
      var cx = sx + w / 2, cy = zy - h / 2;
      g.translate(cx, cy); g.rotate(-t * 7);
      daire(g, 0, 0, h / 2, '#1d1e22'); daire(g, 0, 0, h / 2 - 9, '#8d919c'); daire(g, 0, 0, 6, '#33353c');
      g.strokeStyle = '#33353c'; g.lineWidth = 4;
      for (var m = 0; m < 5; m++) { g.rotate(1.2566); g.beginPath(); g.moveTo(0, 0); g.lineTo(0, -h / 2 + 10); g.stroke(); }
    } else if (e.tur === 'koli') {
      kutu(g, sx, zy - h, w, h, 4, '#c99a5f');
      g.fillStyle = '#a77a43'; g.fillRect(sx, zy - h + 14, w, 3);
      g.fillStyle = '#ead2a6'; g.fillRect(sx + w / 2 - 7, zy - h, 14, h);
      g.fillStyle = '#6d4a22'; g.font = '900 10px system-ui'; g.textAlign = 'center'; g.fillText('KIRILIR', sx + w / 2, zy - 12);
    }
    g.restore();
  }

  // ---------- Toplanabilirler ----------
  function tarakSimge(g, x, y, o, aci) {
    g.save(); g.translate(x, y); g.rotate(aci); g.scale(o, o);
    g.fillStyle = '#ffc400'; g.strokeStyle = '#8a5a00'; g.lineWidth = 1.6;
    yuvarlak(g, -11, -7, 22, 6, 3); g.fill(); g.stroke();
    for (var i = 0; i < 6; i++) { yuvarlak(g, -10 + i * 3.8, -2, 2.4, 9, 1.2); g.fill(); }
    g.fillStyle = 'rgba(255,255,255,.7)'; g.fillRect(-8, -5.6, 12, 1.6);
    g.restore();
  }

  function nesneCiz(g, n, sx, sy, t) {
    var yuz = Math.sin(t * 5 + n.x * 0.03) * 2.5;
    if (n.tur === 'parca') {   // hediye parçası: parlayan pembe bilet
      var py = sy + yuz;
      daire(g, sx, py, 30 + Math.sin(t * 7) * 3, 'rgba(255,61,139,.28)');
      for (var pi = 0; pi < 6; pi++) { var pa = -t * 2 + pi * 1.047; daire(g, sx + Math.cos(pa) * 30, py + Math.sin(pa) * 30, 2.4, '#ffd1e4'); }
      g.save(); g.translate(sx, py); g.rotate(Math.sin(t * 3) * 0.2);
      kutu(g, -20, -13, 40, 26, 6, '#ff3d8b'); kutu(g, -16, -9, 32, 18, 4, '#ff7eb3');
      g.fillStyle = '#fff'; g.font = '900 12px system-ui, sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('🎁', 0, 1);
      g.restore();
      return;
    }
    if (n.tur === 'sandik') {
      var y = sy + yuz, a = 1 + Math.sin(t * 6) * 0.06;
      daire(g, sx, y, 27 * a, 'rgba(255,225,90,.32)');
      for (var i = 0; i < 8; i++) { var aci = t * 1.6 + i * 0.785; daire(g, sx + Math.cos(aci) * 29, y + Math.sin(aci) * 29, 2.2, '#fff6b0'); }
      kutu(g, sx - 15, y - 8, 30, 24, 4, '#d62a4a'); kutu(g, sx - 18, y - 14, 36, 9, 3, '#f0425f');
      g.fillStyle = '#ffd23f'; g.fillRect(sx - 4, y - 14, 8, 30);
      g.strokeStyle = '#ffd23f'; g.lineWidth = 3.5; g.beginPath(); g.ellipse(sx - 7, y - 19, 7, 4.5, 0.5, 0, 6.2832); g.stroke(); g.beginPath(); g.ellipse(sx + 7, y - 19, 7, 4.5, -0.5, 0, 6.2832); g.stroke();
      return;
    }
    if (n.tur === 'tarak') {
      daire(g, sx, sy + yuz, 13, 'rgba(255,230,120,.28)');
      tarakSimge(g, sx, sy + yuz, 0.92, Math.sin(t * 3 + n.x * 0.02) * 0.25 - 0.2);
      return;
    }
    daire(g, sx, sy + yuz, 22, 'rgba(255,255,255,.35)');
    daire(g, sx, sy + yuz, 17, n.tur === 'kalp' ? '#fff' : '#1c2023');
    g.textAlign = 'center'; g.textBaseline = 'middle'; g.font = '19px system-ui';
    if (n.tur === 'kalp') { g.fillStyle = '#e6395a'; g.font = '900 23px system-ui'; g.fillText('♥', sx, sy + yuz + 1); }
    else if (n.tur === 'kalkan') { // fön spreyi
      kutu(g, sx - 6, sy + yuz - 4, 12, 16, 3, '#7fd8ff'); kutu(g, sx - 3, sy + yuz - 11, 6, 8, 2, '#e8edf5'); g.fillStyle = '#e8edf5'; g.fillRect(sx + 3, sy + yuz - 11, 6, 3);
    } else { // tıraş makinesi
      kutu(g, sx - 6, sy + yuz - 6, 12, 18, 5, '#ffc400'); kutu(g, sx - 7, sy + yuz - 11, 14, 6, 1, '#d7dbe3');
      g.fillStyle = '#d7dbe3'; for (var i = 0; i < 5; i++) g.fillRect(sx - 7 + i * 3.1, sy + yuz - 14, 1.6, 4);
    }
  }

  // ---------- Maskot ----------
  var OLCEK = 0.119;            // kaynak sprite pikselinden oyun pikseline
  var BACAK = 27, AYAK = 22;    // bacak boyu ve bilekten tabana

  function uzuv(g, x1, y1, kx, ky, x2, y2, kalinlik) {
    g.lineCap = 'round'; g.lineJoin = 'round';
    g.strokeStyle = '#141416'; g.lineWidth = kalinlik;
    g.beginPath(); g.moveTo(x1, y1); g.quadraticCurveTo(kx, ky, x2, y2); g.stroke();
    g.strokeStyle = 'rgba(255,255,255,.17)'; g.lineWidth = kalinlik * 0.28;
    g.beginPath(); g.moveTo(x1 - 1.4, y1); g.quadraticCurveTo(kx - 1.4, ky, x2 - 1.4, y2); g.stroke();
  }

  function ayakkabiCiz(g, x, y, aci, golge) {
    var im = kadinMod ? ((golge && resim.ayakkabiKoyuK) || resim.ayakkabiK || resim.ayakkabi) : ((golge && resim.ayakkabiKoyu) || resim.ayakkabi);
    g.save(); g.translate(x, y); g.rotate(aci + 0.24);
    var s = OLCEK * 1.08;
    if (im) g.drawImage(im, -59 * s, -22 * s, im.width * s, im.height * s);
    else kutu(g, -7, -2, 22, 16, 7, '#fff');
    g.restore();
  }

  function eldivenCiz(g, x, y, aci, golge) {
    var im = (golge && resim.eldivenKoyu) || resim.eldiven;
    g.save(); g.translate(x, y); g.rotate(aci - 0.82);
    var s = OLCEK * 1.2;
    if (im) g.drawImage(im, -22 * s, -30 * s, im.width * s, im.height * s);
    else daire(g, 6, 5, 8, '#fff');
    g.restore();
  }

  var takili = {};
  function yol(g, n, renk) { cokgen(g, n, renk); }
  // Eski şapka çizimleri (160,28) taban noktasına göre çizilmişti; kafa kubbesine büyütülüp eğilerek oturtulur.
  var SAPKA_OLCEK = { yilbasi: 1.45, parti: 1.45, kovboy: 1.05, silindir: 1.3, sapka: 1.75, kasket: 1.7, tac: 1.5 };
  function basaOturt(g, ad, ciz) {
    g.save(); g.translate(150, ad === 'tac' ? 56 : 70); g.rotate(0.1);
    var k = SAPKA_OLCEK[ad] || 1; g.scale(k, k); g.translate(-160, -28);
    ciz(); g.restore();
  }
  function yeleCiz(g) {
    var nokta = [18,300, 12,230, 18,160, 36,98, 70,56, 118,28, 172,14, 224,28, 258,66, 276,112, 280,176, 274,232, 262,290];
    var tr = ['#c9781f', '#8a4a14', '#e29a35'];
    g.save(); g.translate(146, 170); g.scale(1.12, 1.12); g.translate(-146, -170);
    for (var i = 0; i < nokta.length; i += 2) { daire(g, nokta[i], nokta[i + 1], 44, tr[(i / 2) % 3]); daire(g, nokta[i] + 8, nokta[i + 1] + 34, 30, tr[(i / 2 + 1) % 3]); }
    g.restore();
  }
  // Sırt eşyaları gövdenin arkasına çizilir (sprite pikseli koordinatları)
  function arkaEsya(g) {
    var an = performance.now() / 1000, i;
    if (kadinMod) {
      var sw = Math.sin(an * 9) * 22;
      g.fillStyle = '#5a2f1c'; g.beginPath(); g.moveTo(70, 40); g.quadraticCurveTo(-40, 30, -70 + sw * 0.3, 150);
      g.quadraticCurveTo(-110 + sw, 280, -60 + sw, 400); g.quadraticCurveTo(-20 + sw * 0.6, 300, 10, 210); g.quadraticCurveTo(20, 120, 95, 90); g.closePath(); g.fill();
      g.strokeStyle = '#7a4528'; g.lineWidth = 10; g.lineCap = 'round'; g.beginPath(); g.moveTo(40, 70); g.quadraticCurveTo(-60 + sw * 0.4, 170, -70 + sw, 330); g.stroke();
    }
    if (takili.sirt === 'pelerin') {
      var d = Math.sin(an * 11) * 26;
      g.fillStyle = '#c81432'; g.beginPath(); g.moveTo(70, 150); g.lineTo(240, 160);
      g.quadraticCurveTo(210, 520, 60 + d, 700); g.quadraticCurveTo(-70, 650, -190 + d, 690); g.quadraticCurveTo(-110, 420, 70, 150); g.fill();
      g.fillStyle = '#8f0d24'; g.beginPath(); g.moveTo(40, 200); g.quadraticCurveTo(-70, 450, -150 + d, 670); g.lineTo(-120 + d, 676); g.quadraticCurveTo(-40, 450, 62, 205); g.fill();
    }
    if (takili.sirt === 'kanat') {
      var cirp = Math.sin(an * 9) * 40;
      g.fillStyle = '#ffffff'; g.strokeStyle = '#c9ced8'; g.lineWidth = 6;
      [[60, -1], [330, 1]].forEach(function (k) {
        var x = k[0], y = k[1];
        g.beginPath(); g.moveTo(x, 300); g.quadraticCurveTo(x + y * 90, 80 - cirp, x + y * 260, 130 - cirp);
        g.quadraticCurveTo(x + y * 190, 200, x + y * 235, 260 - cirp / 2); g.quadraticCurveTo(x + y * 140, 270, x + y * 165, 350);
        g.quadraticCurveTo(x + y * 80, 340, x, 390); g.closePath(); g.fill(); g.stroke();
      });
    }
    if (takili.sirt === 'balon') {
      var renk = ['#ff3b5c', '#2fb6ff', '#ffd23f'], yer = [[-110, 20], [-170, 190], [-20, -110]];
      for (i = 0; i < 3; i++) {
        var bx = yer[i][0] + Math.sin(an * 2 + i) * 14, by = yer[i][1] + Math.sin(an * 3 + i * 2) * 16;
        g.strokeStyle = '#ffffff'; g.lineWidth = 5; g.beginPath(); g.moveTo(70, 400); g.quadraticCurveTo(bx + 60, by + 190, bx, by + 78); g.stroke();
        g.fillStyle = renk[i]; g.beginPath(); g.ellipse(bx, by, 64, 78, 0, 0, 6.2832); g.fill();
        daire(g, bx - 22, by - 28, 14, 'rgba(255,255,255,.55)');
      }
    }
    if (takili.sirt === 'canta') { kutu(g, -112, 215, 200, 240, 44, '#17181c'); kutu(g, -112, 268, 200, 26, 4, '#ffc400'); kutu(g, -84, 350, 140, 70, 16, '#2a2c33'); kutu(g, -40, 372, 56, 14, 6, '#ffc400'); }
    if (takili.bas === 'yele') yeleCiz(g);
  }
  // Gövdenin üstüne çizilen yeni eşyalar
  function onEsya(g) {
    var i;
    if (kadinMod) {
      g.strokeStyle = '#111'; g.lineWidth = 7; g.lineCap = 'round';
      [[128, 298, 112, 282], [142, 290, 134, 272], [158, 288, 158, 270], [214, 284, 210, 266], [232, 282, 236, 264], [250, 288, 264, 272]].forEach(function (q) { g.beginPath(); g.moveTo(q[0], q[1]); g.lineTo(q[2], q[3]); g.stroke(); });
      g.fillStyle = 'rgba(255,110,160,.5)';
      [[118, 352], [262, 344]].forEach(function (p) { g.beginPath(); g.ellipse(p[0], p[1], 28, 16, 0, 0, 6.2832); g.fill(); });
      if (!takili.bas) fiyonkCiz(g, 70, 70, 0.9);
    }
    if (takili.bas === 'fiyonk') fiyonkCiz(g, 196, 30, 1.5);
    if (takili.bas === 'cicektac') {
      g.strokeStyle = '#4f9a3a'; g.lineWidth = 12; g.beginPath(); g.ellipse(150, 62, 128, 30, 0.1, Math.PI, 0); g.stroke();
      var rk = ['#ff6fa5', '#ffffff', '#ffd23f', '#b784ff', '#ff8a65', '#ffffff', '#ff6fa5'];
      for (i = 0; i < 7; i++) { var cx = 34 + i * 38, cy = 66 - Math.sin(i / 6 * Math.PI) * 30 + i * 3; for (var y = 0; y < 5; y++) daire(g, cx + Math.cos(y * 1.26) * 13, cy + Math.sin(y * 1.26) * 13, 11, rk[i]); daire(g, cx, cy, 8, '#ffc400'); }
    }
    if (takili.yuz === 'kedigoz') {
      g.strokeStyle = '#ff3d8b'; g.lineWidth = 9; g.beginPath(); g.moveTo(96, 300); g.lineTo(276, 290); g.stroke();
      [[148, 308, -1], [230, 302, 1]].forEach(function (p) {
        g.fillStyle = '#2a0b1c'; g.beginPath(); g.moveTo(p[0] - 46, p[1] - 14); g.quadraticCurveTo(p[0], p[1] - 30, p[0] + 46, p[1] - 22 + p[2] * 4); g.quadraticCurveTo(p[0] + 30, p[1] + 34, p[0], p[1] + 28); g.quadraticCurveTo(p[0] - 36, p[1] + 26, p[0] - 46, p[1] - 14); g.fill(); g.stroke();
        cokgen(g, [p[0] + p[2] * 40, p[1] - 20, p[0] + p[2] * 62, p[1] - 40, p[0] + p[2] * 46, p[1] - 8], '#ff3d8b');
      });
    }
    if (takili.boyun === 'inci') for (i = 0; i < 13; i++) { var a = i / 12; daire(g, 60 + a * 270, 448 + Math.sin(a * Math.PI) * 30, 13, '#fbf7f0'); daire(g, 56 + a * 270, 444 + Math.sin(a * Math.PI) * 30, 4, '#ffffff'); }
    if (takili.bas === 'yilbasi') basaOturt(g, 'yilbasi', function () {
      yol(g, [88, 34, 150, -80, 262, -112, 300, -30, 214, -34, 232, 34], '#d6202c');
      kutu(g, 78, 12, 168, 44, 22, '#ffffff'); daire(g, 302, -22, 32, '#ffffff');
    });
    if (takili.bas === 'parti') basaOturt(g, 'parti', function () {
      var rk = ['#ff3b8d', '#2fb6ff', '#ffd23f', '#7b5cff'];
      for (i = 0; i < 4; i++) { var a = 1 - i / 4, b = 1 - (i + 1) / 4; yol(g, [160 - 68 * a, 26 - i * 36, 160 - 68 * b, 26 - (i + 1) * 36, 160 + 68 * b, 26 - (i + 1) * 36, 160 + 68 * a, 26 - i * 36], rk[i]); }
      daire(g, 160, -126, 24, '#ffffff');
    });
    if (takili.bas === 'kulaklik') {
      g.strokeStyle = '#22242b'; g.lineWidth = 26; g.beginPath(); g.arc(139, 178, 146, Math.PI * 1.02, Math.PI * 1.98); g.stroke();
      [[0, 182], [278, 176]].forEach(function (p) { kutu(g, p[0] - 34, p[1] - 62, 68, 124, 30, '#22242b'); kutu(g, p[0] - 16, p[1] - 38, 32, 76, 16, '#2fb6ff'); });
    }
    if (takili.bas === 'kovboy') basaOturt(g, 'kovboy', function () { g.fillStyle = '#8a5427'; g.beginPath(); g.ellipse(160, 28, 160, 30, -0.04, 0, 6.2832); g.fill(); kutu(g, 96, -66, 128, 96, 34, '#8a5427'); kutu(g, 96, -4, 128, 22, 4, '#2a180c'); });
    if (takili.bas === 'silindir') basaOturt(g, 'silindir', function () { kutu(g, 100, -128, 122, 152, 12, '#15131c'); kutu(g, 100, -30, 122, 30, 2, '#7b35c9'); kutu(g, 62, 10, 198, 24, 12, '#15131c'); });
    if (takili.sirt === 'canta') { g.strokeStyle = '#17181c'; g.lineWidth = 18; g.lineCap = 'round'; g.beginPath(); g.moveTo(24, 228); g.lineTo(62, 470); g.stroke(); }
    if (takili.yuz === 'nsakal') {
      [[150,410,34], [182,428,42], [224,420,38], [252,396,27], [140,376,24], [196,458,34], [168,452,28], [230,448,26], [196,486,20]].forEach(function (p) { daire(g, p[0], p[1], p[2], '#ffffff'); });
      g.strokeStyle = '#ffffff'; g.lineWidth = 24; g.lineCap = 'round'; g.beginPath(); g.moveTo(140, 340); g.quadraticCurveTo(165, 352, 190, 334); g.quadraticCurveTo(222, 346, 242, 322); g.stroke();
    }
    if (takili.boyun === 'atki' || takili.boyun === 'ylatki') {
      var ana = takili.boyun === 'atki' ? '#ffc400' : '#d6202c', cizgi = takili.boyun === 'atki' ? '#1c2023' : '#ffffff';
      yol(g, [40, 430, 340, 424, 346, 486, 52, 498], ana); yol(g, [44, 454, 342, 448, 343, 464, 46, 472], cizgi);
      var s = Math.sin(performance.now() / 120) * 14;
      yol(g, [74, 480, 134, 478, 88 + s, 620, 24 + s, 604], ana); yol(g, [50 + s, 560, 112 + s, 566, 106 + s, 580, 45 + s, 574], cizgi);
    }
  }
  function govdeCiz(g, x, altY) {
    var im = (kadinMod && resim.govdeK) || resim.govde;
    g.save(); g.translate(x - 232 * OLCEK, altY - 590 * OLCEK); g.scale(OLCEK, OLCEK); arkaEsya(g); g.restore();
    if (im) g.drawImage(im, x - 232 * OLCEK, altY - 590 * OLCEK, im.width * OLCEK, im.height * OLCEK);
    else kutu(g, x - 24, altY - 68, 48, 68, 20, '#ffc400');
    g.save();
    // Aksesuarlar sprite pikseli koordinatlarında çizilir
    g.translate(x - 232 * OLCEK, altY - 590 * OLCEK); g.scale(OLCEK, OLCEK);
    if (takili.bas === 'sapka') basaOturt(g, 'sapka', function () { kutu(g, 98, -34, 128, 62, 18, '#f6f4ee'); kutu(g, 98, -6, 128, 10, 3, '#d6202c'); kutu(g, 90, 6, 144, 24, 10, '#e2ded4'); });
    if (takili.bas === 'kasket') basaOturt(g, 'kasket', function () { g.fillStyle = '#d23a32'; g.beginPath(); g.ellipse(160, 30, 76, 56, -0.08, Math.PI, 0); g.fill(); kutu(g, 48, 18, 74, 18, 9, '#a82a24'); daire(g, 160, -24, 7, '#a82a24'); });
    if (takili.bas === 'tac') basaOturt(g, 'tac', function () { g.fillStyle = '#ffd23f'; g.strokeStyle = '#8a5a00'; g.lineWidth = 6; g.beginPath(); g.moveTo(92, 26); g.lineTo(84, -52); g.lineTo(126, -16); g.lineTo(160, -66); g.lineTo(194, -16); g.lineTo(236, -52); g.lineTo(226, 26); g.closePath(); g.fill(); g.stroke(); daire(g, 160, 2, 11, '#e6395a'); daire(g, 116, 8, 8, '#2f9bff'); daire(g, 204, 8, 8, '#2f9bff'); });
    if (takili.yuz === 'gozluk') { g.strokeStyle = '#ffd23f'; g.lineWidth = 9; g.beginPath(); g.moveTo(96, 300); g.lineTo(276, 290); g.stroke(); [[148, 308], [230, 302]].forEach(function (p) { g.fillStyle = '#0d1016'; g.beginPath(); g.ellipse(p[0], p[1], 44, 32, -0.06, 0, 6.2832); g.fill(); g.stroke(); g.fillStyle = 'rgba(120,200,255,.45)'; g.beginPath(); g.ellipse(p[0] - 14, p[1] - 10, 12, 7, -0.5, 0, 6.2832); g.fill(); }); }
    if (takili.yuz === 'biyik') { g.strokeStyle = '#101012'; g.lineWidth = 17; g.lineCap = 'round'; g.beginPath(); g.moveTo(138, 338); g.quadraticCurveTo(158, 354, 190, 332); g.quadraticCurveTo(222, 350, 246, 312); g.stroke(); }
    onEsya(g);
    if (takili.boyun === 'papyon') { g.fillStyle = '#c4122e'; [[-1], [1]].forEach(function (y) { g.beginPath(); g.moveTo(190, 452); g.lineTo(190 + y[0] * 66, 414); g.lineTo(190 + y[0] * 66, 490); g.closePath(); g.fill(); }); daire(g, 190, 452, 19, '#8a0e22'); }
    g.restore();
  }
  function kusan(s) { takili = s || {}; }
  function fiyonkCiz(g, x, y, o) {
    g.save(); g.translate(x, y); g.rotate(0.25); g.scale(o, o);
    cokgen(g, [0, 0, -58, -34, -58, 34], '#ff3d8b'); cokgen(g, [0, 0, 58, -34, 58, 34], '#ff3d8b');
    cokgen(g, [0, 0, -40, -14, -40, 14], '#d81b60'); cokgen(g, [0, 0, 40, -14, 40, 14], '#d81b60');
    daire(g, 0, 0, 15, '#c2185b'); g.restore();
  }

  /* x = karakter merkezi, ay = ayak tabanının ekran y'si
   * poz: 'kos' | 'zipla' | 'kay' | 'dur' */
  function maskot(g, x, ay, poz, faz, ek) {
    ek = ek || {};
    var o = ek.olcek || 1;
    g.save(); g.translate(x, ay); g.scale(o, o);

    if (poz === 'kay') {
      // Geriye yatarak ayaklar önde kayış
      uzuv(g, -12, -22, 4, -30, 14, -14, 8);
      ayakkabiCiz(g, 15, -20, -0.95, true);
      g.save(); g.translate(-8, -30); g.rotate(-1.2); g.scale(0.84, 0.84); govdeCiz(g, 0, 33); g.restore();
      uzuv(g, -2, -17, 16, -22, 24, -12, 8.5);
      ayakkabiCiz(g, 25, -17, -0.88, false);
      uzuv(g, -22, -38, -40, -46, -44, -30, 6.5);
      eldivenCiz(g, -44, -30, 2.2, false);
      g.restore();
      return;
    }

    var ziplama = poz === 'zipla', dur = poz === 'dur';
    var sin = Math.sin(faz), cos = Math.cos(faz);
    var sek = dur ? Math.sin(faz * 0.35) * 1.2 : (ziplama ? 0 : -Math.abs(cos) * 4);
    var altY = -(BACAK + AYAK) + sek;      // gövdenin alt kenarı
    var egim = dur ? 0 : (ziplama ? (ek.vy > 0 ? 0.07 : -0.04) : 0.075);
    if (ek.takla) {
      g.translate(0, altY - 30); g.rotate(ek.takla); g.translate(0, -(altY - 30));
    }

    function bacak(yon, golge) {
      var kalcaX = -3 + yon * 3.5, kalcaY = altY - 4;
      var fx, fy, aci, kx, ky;
      if (ziplama) {
        fx = kalcaX + (yon < 0 ? -15 : 9); fy = altY + (yon < 0 ? 17 : 14);
        kx = kalcaX + (yon < 0 ? 3 : 18); ky = altY + (yon < 0 ? 18 : 6);
        aci = yon < 0 ? 0.55 : -0.2;
      } else if (dur) {
        fx = kalcaX + yon * 5; fy = -AYAK; kx = (kalcaX + fx) / 2; ky = (kalcaY + fy) / 2; aci = 0;
      } else {
        var s = sin * yon, c = cos * yon;
        fx = kalcaX + s * 19; fy = -AYAK - Math.max(0, c) * 15;
        kx = (kalcaX + fx) / 2 + 5 + Math.max(0, c) * 7; ky = (kalcaY + fy) / 2;
        aci = c > 0 ? 0.5 * c - s * 0.2 : -s * 0.12;
      }
      uzuv(g, kalcaX, kalcaY, kx, ky, fx, fy + 3, 8.2);
      ayakkabiCiz(g, fx, fy, aci, golge);
    }

    function elKonumu(yon) {
      var ox = yon < 0 ? -22 : 11, oy = altY - (yon < 0 ? 23 : 25);
      var hx, hy, aci;
      if (ziplama) { hx = ox + (yon < 0 ? -21 : 28); hy = oy - 15; aci = yon < 0 ? 3.7 : -0.5; }
      else if (dur) { hx = ox + (yon < 0 ? -13 : 27); hy = oy + 17 + Math.sin(faz * 0.35) * 1.5; aci = yon < 0 ? 1.9 : 0.8; }
      else { var s = -sin * yon; hx = ox + (yon < 0 ? -11 : 24) + s * 14; hy = oy + 12 - Math.abs(s) * 5; aci = (yon < 0 ? 1.9 : 0.6) - s * 0.6; }
      return { ox: ox, oy: oy, x: hx, y: hy, aci: aci };
    }

    bacak(-1, true);
    g.save(); g.translate(0, altY); g.rotate(egim); g.translate(0, -altY);
    var arka = elKonumu(1);
    uzuv(g, arka.ox, arka.oy, (arka.ox + arka.x) / 2 + 4, Math.max(arka.oy, arka.y) + 5, arka.x, arka.y, 6.6);
    eldivenCiz(g, arka.x, arka.y, arka.aci, true);
    g.restore();
    bacak(1, false);
    g.save(); g.translate(0, altY); g.rotate(egim); g.translate(0, -altY);
    govdeCiz(g, 0, altY);
    var on = elKonumu(-1);
    uzuv(g, on.ox, on.oy, (on.ox + on.x) / 2 - 8, (on.oy + on.y) / 2 + 3, on.x, on.y, 6.8);
    if (ek.canta) cantaCiz(g, on.x - 4, on.y + 13);
    eldivenCiz(g, on.x, on.y, on.aci, false);
    g.restore();
    g.restore();
  }

  function cantaCiz(g, x, y) {
    g.strokeStyle = '#141416'; g.lineWidth = 3; g.beginPath(); g.arc(x, y, 7, Math.PI, 0); g.stroke();
    kutu(g, x - 14, y, 28, 20, 5, '#ffc400'); kutu(g, x - 12, y + 2, 24, 16, 4, '#1a1b1f');
  }

  // Bölüm sonu: müşteri noktası (konum iğnesi + berber koltuğu)
  function bitisCiz(g, sx, zy, tanim, t) {
    g.fillStyle = '#fff'; g.fillRect(sx - 3, zy - 190, 6, 190);
    for (var r = 0; r < 3; r++) for (var c = 0; c < 6; c++) { g.fillStyle = (r + c) % 2 ? '#1c2023' : '#fff'; g.fillRect(sx + 3 + c * 11, zy - 190 + r * 11, 11, 11); }
    var py = zy - 150 + Math.sin(t * 4) * 6, px = sx + 95;
    g.fillStyle = '#ffc400'; g.beginPath(); g.arc(px, py, 22, Math.PI * 0.82, Math.PI * 0.18); g.lineTo(px, py + 40); g.closePath(); g.fill();
    daire(g, px, py, 10, '#1c2023');
    kutu(g, px - 22, zy - 58, 14, 46, 5, '#8e2a20'); kutu(g, px - 22, zy - 28, 44, 13, 5, '#c0392b');
    g.fillStyle = '#9ea3ad'; g.fillRect(px - 4, zy - 15, 8, 12); kutu(g, px - 20, zy - 5, 40, 5, 2, '#9ea3ad');
    var ad = tanim ? (kadinMod && tanim.musteriK ? tanim.musteriK : tanim.musteri) : 'Müşteri';
    g.font = '800 13px system-ui'; var gen = g.measureText(ad).width + 20;
    kutu(g, px - gen / 2, py - 56, gen, 24, 8, '#1c2023');
    g.fillStyle = '#fff'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(ad, px, py - 43);
  }

  // Akşam, gece ve sabah için gökyüzü + zemin katmanı (engeller ve maskot bunun üstüne çizilir)
  function saatKatmani(g, W, H, zy, saat, t) {
    if (!saat || saat === 'oglen') return;
    g.save();
    if (saat === 'gece') {
      var gr = g.createLinearGradient(0, 0, 0, H);
      gr.addColorStop(0, 'rgba(6,10,36,.82)'); gr.addColorStop(zy / H, 'rgba(12,18,48,.62)'); gr.addColorStop(1, 'rgba(8,10,24,.66)');
      g.fillStyle = gr; g.fillRect(0, 0, W, H);
      for (var i = 0; i < 55; i++) {
        var x = tohum(i * 3.1) * W, y = tohum(i * 7.7) * zy * 0.62, p = 0.45 + 0.55 * Math.abs(Math.sin(t * 1.4 + i));
        g.fillStyle = 'rgba(255,255,240,' + p.toFixed(2) + ')'; g.fillRect(x, y, 1.6, 1.6);
      }
      daire(g, W * 0.8, zy * 0.17, 17, '#f6f2d8'); daire(g, W * 0.8 + 5, zy * 0.17 - 3, 4, 'rgba(0,0,0,.08)'); daire(g, W * 0.8 - 6, zy * 0.17 + 5, 3, 'rgba(0,0,0,.08)');
      var hl = g.createRadialGradient(W * 0.8, zy * 0.17, 10, W * 0.8, zy * 0.17, 70); hl.addColorStop(0, 'rgba(246,242,216,.25)'); hl.addColorStop(1, 'rgba(246,242,216,0)');
      g.fillStyle = hl; g.fillRect(0, 0, W, zy);
    } else if (saat === 'aksam') {
      var ga = g.createLinearGradient(0, 0, 0, H);
      ga.addColorStop(0, 'rgba(90,40,120,.38)'); ga.addColorStop(zy / H * 0.8, 'rgba(255,120,60,.32)'); ga.addColorStop(1, 'rgba(80,30,20,.3)');
      g.fillStyle = ga; g.fillRect(0, 0, W, H);
      var gg = g.createRadialGradient(W * 0.25, zy * 0.9, 10, W * 0.25, zy * 0.9, 200); gg.addColorStop(0, 'rgba(255,190,90,.45)'); gg.addColorStop(1, 'rgba(255,190,90,0)');
      g.fillStyle = gg; g.fillRect(0, 0, W, zy);
    } else if (saat === 'sabah') {
      var gs = g.createLinearGradient(0, 0, 0, zy);
      gs.addColorStop(0, 'rgba(255,214,170,.18)'); gs.addColorStop(1, 'rgba(255,240,215,.38)');
      g.fillStyle = gs; g.fillRect(0, 0, W, zy);
      g.fillStyle = 'rgba(255,255,255,.12)'; g.fillRect(0, zy - 60, W, 60);
    }
    g.restore();
  }

  window.TarakCiz = { kadin: kadin,
    saatKatmani: saatKatmani,
    hazir: hazir, resim: resim, TEMA: TEMA, kusan: kusan,
    arkaPlan: arkaPlan, zemin: zemin, engelCiz: engelCiz, nesneCiz: nesneCiz,
    maskot: maskot, bitisCiz: bitisCiz, tarakSimge: tarakSimge, daire: daire, kutu: kutu
  };
})();
