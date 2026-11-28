/* WebAudio ile üretilen sesler ve müzik (ses dosyası gerektirmez). */
(function () {
  'use strict';
  var ctx = null, ana = null, muzikKazanc = null, muzikZaman = null, adimNo = 0, sonraki = 0;
  var acik = true;
  try { acik = localStorage.getItem('tm_ses') !== '0'; } catch (e) {}

  // iPhone'da sessiz moddayken Web Audio susturulur. Oynatma oturumunu "medya" yapmak için
  // kısa, sessiz bir <audio> çalınır ve destekleyen Safari'de audioSession türü ayarlanır.
  var sessiz = null;
  function sessizSes() {
    if (sessiz) return sessiz;
    var n = 800, b = new ArrayBuffer(44 + n * 2), v = new DataView(b);
    function yaz(o, s) { for (var i = 0; i < s.length; i++) v.setUint8(o + i, s.charCodeAt(i)); }
    yaz(0, 'RIFF'); v.setUint32(4, 36 + n * 2, true); yaz(8, 'WAVE'); yaz(12, 'fmt ');
    v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true); v.setUint32(24, 8000, true);
    v.setUint32(28, 16000, true); v.setUint16(32, 2, true); v.setUint16(34, 16, true); yaz(36, 'data'); v.setUint32(40, n * 2, true);
    try {
      sessiz = new Audio(URL.createObjectURL(new Blob([b], { type: 'audio/wav' })));
      sessiz.setAttribute('playsinline', ''); sessiz.loop = true; sessiz.volume = 0.01;
    } catch (e) { sessiz = null; }
    return sessiz;
  }
  function oturumAc() {
    try { if (navigator.audioSession) navigator.audioSession.type = 'playback'; } catch (e) {}
    var a = sessizSes();
    if (a && a.paused) { var p = a.play(); if (p && p.catch) p.catch(function () {}); }
  }

  function hazirla() {
    if (!ctx) {
      var AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return false;
      ctx = new AC();
      ana = ctx.createGain(); ana.gain.value = 0.85; ana.connect(ctx.destination);
      muzikKazanc = ctx.createGain(); muzikKazanc.gain.value = 0.32; muzikKazanc.connect(ana);
    }
    // 'interrupted': telefon görüşmesi ya da uygulama değişimi sonrası (iOS)
    if (ctx.state !== 'running' && ctx.state !== 'closed') { var r = ctx.resume(); if (r && r.catch) r.catch(function () {}); }
    return true;
  }

  // İlk dokunuşta ses kilidini aç (tarayıcılar sesi ancak kullanıcı dokununca başlatır)
  function kilitAc() {
    if (!acik) return;
    oturumAc();
    hazirla();
  }
  ['pointerup', 'touchend', 'click', 'keydown'].forEach(function (olay) {
    document.addEventListener(olay, kilitAc, { capture: true, passive: true });
  });
  document.addEventListener('visibilitychange', function () {
    if (document.hidden && sessiz && !sessiz.paused) sessiz.pause();
  });

  function nota(f, sure, tip, ses, kaydir, gecikme, hedef) {
    if (!acik || !hazirla()) return;
    var t = ctx.currentTime + (gecikme || 0);
    var o = ctx.createOscillator(), g = ctx.createGain();
    o.type = tip || 'square';
    o.frequency.setValueAtTime(f, t);
    if (kaydir) o.frequency.exponentialRampToValueAtTime(Math.max(30, f * kaydir), t + sure);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(ses || 0.2, t + 0.012);
    g.gain.exponentialRampToValueAtTime(0.0001, t + sure);
    o.connect(g); g.connect(hedef || ana);
    o.start(t); o.stop(t + sure + 0.03);
  }

  var taraktaSira = 0, taraktaZaman = 0;
  var EFEKT = {
    zipla: function () { nota(330, 0.16, 'square', 0.12, 2.1); },
    zipla2: function () { nota(500, 0.18, 'square', 0.12, 2); },
    kay: function () { nota(260, 0.22, 'sawtooth', 0.1, 0.4); },
    turbo: function () { nota(180, 0.45, 'sawtooth', 0.14, 4); nota(360, 0.4, 'square', 0.07, 3, 0.05); },
    tarak: function () {
      var simdi = Date.now();
      taraktaSira = simdi - taraktaZaman < 450 ? Math.min(taraktaSira + 1, 10) : 0;
      taraktaZaman = simdi;
      nota(880 * Math.pow(1.0595, taraktaSira), 0.09, 'triangle', 0.2);
    },
    carpti: function () { nota(150, 0.35, 'sawtooth', 0.3, 0.35); },
    kirdi: function () { nota(110, 0.2, 'square', 0.25, 0.5); nota(700, 0.1, 'triangle', 0.12, 0.5, 0.03); },
    kalkan: function () { nota(520, 0.3, 'sine', 0.25, 2); },
    kalkanKirildi: function () { nota(700, 0.3, 'sine', 0.25, 0.4); },
    miknatis: function () { nota(300, 0.4, 'triangle', 0.25, 3); },
    kalp: function () { [660, 880, 1100].forEach(function (f, i) { nota(f, 0.14, 'sine', 0.22, 0, i * 0.08); }); },
    kontrol: function () { [523, 784].forEach(function (f, i) { nota(f, 0.2, 'triangle', 0.22, 0, i * 0.12); }); },
    kazandi: function () { [523, 659, 784, 1047, 784, 1047].forEach(function (f, i) { nota(f, 0.24, 'triangle', 0.28, 0, i * 0.13); }); },
    kaybetti: function () { [392, 330, 262, 196].forEach(function (f, i) { nota(f, 0.3, 'triangle', 0.26, 0, i * 0.17); }); },
    kukreme: function () { nota(92, 1.1, 'sawtooth', 0.34, 0.6); nota(138, 0.9, 'square', 0.12, 0.5, 0.05); nota(68, 1.25, 'sawtooth', 0.24, 0.75, 0.12); },
    vin: function () { nota(330, 0.45, 'sawtooth', 0.05, 0.42); nota(180, 0.5, 'triangle', 0.06, 0.6, 0.05); },
    tik: function () { nota(600, 0.05, 'square', 0.07); },
    korna: function () { nota(392, 0.22, 'sawtooth', 0.16); nota(494, 0.22, 'sawtooth', 0.12); nota(392, 0.3, 'sawtooth', 0.16, 0, 0.28); },
    bildirim: function () { nota(988, 0.12, 'sine', 0.25); nota(1319, 0.22, 'sine', 0.22, 0, 0.12); }
  };

  var MELODI = [523, 0, 659, 784, 0, 659, 587, 0, 698, 880, 0, 698, 523, 659, 784, 0];
  var BAS = [131, 0, 131, 0, 175, 0, 175, 0, 147, 0, 147, 0, 196, 0, 196, 0];

  function muzikAdim() {
    if (!acik || !ctx || ctx.state !== 'running') return;
    while (sonraki < ctx.currentTime + 0.25) {
      var g = Math.max(0, sonraki - ctx.currentTime);
      var i = adimNo % 16;
      if (MELODI[i]) nota(MELODI[i], 0.13, 'square', 0.09, 0, g, muzikKazanc);
      if (BAS[i]) nota(BAS[i], 0.2, 'triangle', 0.3, 0, g, muzikKazanc);
      if (i % 4 === 2) nota(6000, 0.03, 'square', 0.03, 0.5, g, muzikKazanc);
      sonraki += 0.155; adimNo++;
    }
  }

  window.TarakSes = {
    cal: function (ad) { if (EFEKT[ad]) EFEKT[ad](); },
    muzikBaslat: function () {
      if (!hazirla() || muzikZaman) return;
      sonraki = ctx.currentTime + 0.1;
      muzikZaman = setInterval(muzikAdim, 60);
    },
    muzikDur: function () { clearInterval(muzikZaman); muzikZaman = null; },
    acikMi: function () { return acik; },
    degistir: function () {
      acik = !acik;
      try { localStorage.setItem('tm_ses', acik ? '1' : '0'); } catch (e) {}
      if (!acik) { this.muzikDur(); if (sessiz && !sessiz.paused) sessiz.pause(); }
      else kilitAc();
      return acik;
    },
    durum: function () { return ctx ? ctx.state : 'yok'; },
    hazirla: hazirla
  };
})();
