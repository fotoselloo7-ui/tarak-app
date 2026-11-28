// API uçtan uca testi. Geçici bir veri klasörüyle ayrı bir PHP sunucusu açar; gerçek verilere dokunmaz.
//   node tests/api-test.js
'use strict';
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PHP = process.env.PHP_YOLU || 'C:\\xampp\\php\\php.exe';
const PORT = 8899;
const kok = path.join(__dirname, '..');
const veri = fs.mkdtempSync(path.join(os.tmpdir(), 'tarak-test-'));
const sunucu = spawn(PHP, ['-S', `127.0.0.1:${PORT}`, '-t', path.join(kok, '..', '..', 'tarak.app', 'oyun'), path.join(kok, 'dev-router.php')],
  { env: { ...process.env, TM_VERI_KLASORU: veri }, stdio: 'ignore' });

const url = i => `http://127.0.0.1:${PORT}/api/index.php?islem=${i}`;
async function cagir(islem, govde) {
  const r = await fetch(url(islem), govde ? { method: 'POST', headers: { 'Content-Type': 'text/plain' }, body: JSON.stringify(govde) } : undefined);
  return { kod: r.status, v: await r.json().catch(() => null) };
}
let hata = 0;
function bekle(ad, kosul, ek) { console.log((kosul ? 'GEÇTİ  ' : 'KALDI  ') + ad + (kosul ? '' : '  ' + JSON.stringify(ek))); if (!kosul) hata++; }
const uyu = ms => new Promise(r => setTimeout(r, ms));

(async () => {
  for (let i = 0; i < 40; i++) { try { await fetch(url('ayar')); break; } catch { await uyu(150); } }

  const a = await cagir('ayar');
  bekle('ayar döner', a.kod === 200 && a.v.oyunAktif === true, a);
  const o = await cagir('oturum', { cihaz: 'test-cihaz-0001', platform: 'android', ekran: '1080x2400', isim: '<b>Test</b>' });
  bekle('oturum jetonu', o.kod === 200 && /^[a-f0-9]{48}$/.test(o.v.jeton), o);
  const jeton = o.v.jeton;

  const k1 = await cagir('basla', { jeton, bolum: 0 });
  bekle('koşu başlar', k1.v && k1.v.kosuId > 0, k1);
  await uyu(2100);
  const b1 = await cagir('bitir', { jeton, kosuId: k1.v.kosuId, sonuc: 'kaybetti', skor: 90, tarak: 5, can: 0, sure: 2, mesafe: 520, yildiz: 0, neden: 'kutu' });
  bekle('makul sonsuz skor kabul edilir', b1.v && b1.v.tamam, b1);
  const tekrar = await cagir('bitir', { jeton, kosuId: k1.v.kosuId, sonuc: 'kaybetti', skor: 999999 });
  bekle('aynı koşu ikinci kez bitirilemez', tekrar.kod === 404, tekrar);

  const k2 = await cagir('basla', { jeton, bolum: 1 });
  await cagir('bitir', { jeton, kosuId: k2.v.kosuId, sonuc: 'kazandi', skor: 999999, tarak: 9999, can: 3, sure: 1, mesafe: 99999, yildiz: 3 });
  const s1 = await cagir('siralama&tur=toplam');
  bekle('hileli skor sıralamaya girmez', s1.v.liste.length === 0, s1);
  const s2 = await cagir('siralama&tur=sonsuz&jeton=' + jeton);
  bekle('geçerli skor sıralamada, ad temizlenmiş', s2.v.liste.length === 1 && s2.v.liste[0].skor === 90 && !/[<>/]/.test(s2.v.liste[0].ad) && s2.v.liste[0].ben, s2);

  bekle('tıklama kaydı', (await cagir('tiklama', { jeton, tur: 'randevu' })).v.tamam);
  bekle('nabız', (await cagir('nabiz', { jeton })).v.tamam);
  bekle('sahte jeton reddedilir', (await cagir('basla', { jeton: 'a'.repeat(48), bolum: 1 })).kod === 401);
  bekle('olmayan bölüm reddedilir', (await cagir('basla', { jeton, bolum: 99 })).kod === 400);

  // Zorluk modları
  const km = await cagir('basla', { jeton, bolum: 0, zorluk: 'kolay' });
  await uyu(2100);
  await cagir('bitir', { jeton, kosuId: km.v.kosuId, sonuc: 'kaybetti', skor: 500, tarak: 50, can: 5, sure: 2, mesafe: 2000 });
  const s3 = await cagir('siralama&tur=sonsuz');
  bekle('kolay modda 5 can geçerli', s3.v.liste[0] && s3.v.liste[0].skor === 500, s3);
  const zm = await cagir('basla', { jeton, bolum: 0, zorluk: 'zor' });
  await uyu(2100);
  await cagir('bitir', { jeton, kosuId: zm.v.kosuId, sonuc: 'kaybetti', skor: 700, tarak: 50, can: 5, sure: 2, mesafe: 2000 });
  const s4 = await cagir('siralama&tur=sonsuz');
  bekle('zor modda 5 can şüpheli sayılır', s4.v.liste[0].skor === 500, s4);

  // 3D koşu
  const u1 = await cagir('basla', { jeton, bolum: 108, zorluk: 'orta' });
  await uyu(2100);
  await cagir('bitir', { jeton, kosuId: u1.v.kosuId, sonuc: 'kaybetti', skor: 260, tarak: 12, can: 0, sure: 2, mesafe: 40 });
  const su = await cagir('siralama&tur=uc');
  bekle('3D skor kabul edilir', su.kod === 200 && su.v.liste[0] && su.v.liste[0].skor === 260, su);
  const u2 = await cagir('basla', { jeton, bolum: 101, zorluk: 'zor' });
  bekle('olmayan rota reddedilir', (await cagir('basla', { jeton, bolum: 1074 })).kod === 400);
  await uyu(1100);
  await cagir('bitir', { jeton, kosuId: u2.v.kosuId, sonuc: 'kaybetti', skor: 9999999, tarak: 99999, can: 0, sure: 1, mesafe: 999999 });
  const su2 = await cagir('siralama&tur=uc');
  bekle('3D hileli skor reddedilir', su2.v.liste[0].skor === 260, su2);
  bekle('2D sıralaması 3D skoru içermez', (await cagir('siralama&tur=toplam')).v.liste.length === 0);

  // Gerçek hizmet hediyesi: parçalar sunucuda sayılır, yılda bir kod, Tarak Mobil anahtarla doğrular
  const phpCalistir = kod => require('child_process').execFileSync(PHP, ['-r', "require '" + path.join(kok, '..', '..', 'tarak.app', 'oyun', 'inc', 'baslat.php').split(path.sep).join('/') + "'; " + kod], { env: { ...process.env, TM_VERI_KLASORU: veri } }).toString().trim();
  phpCalistir("tm_ayar_yaz('hediye_parca', '5');");
  const h1 = await cagir('basla', { jeton, bolum: 0 }), h2 = await cagir('basla', { jeton, bolum: 0 }), h3 = await cagir('basla', { jeton, bolum: 0 });
  await uyu(21000);
  for (const h of [h1, h2]) await cagir('bitir', { jeton, kosuId: h.v.kosuId, sonuc: 'kaybetti', skor: 90, tarak: 5, can: 0, sure: 20, mesafe: 520, parca: 9 });
  await cagir('bitir', { jeton, kosuId: h3.v.kosuId, sonuc: 'kaybetti', skor: 9999999, tarak: 99999, can: 0, sure: 20, mesafe: 9999999, parca: 3 });
  const hd = await cagir('hediye', { jeton });
  bekle('hediye parçası koşu başına en fazla 3, hileli koşu sayılmaz', hd.v && hd.v.parca === 6 && hd.v.gerekli === 5, hd);
  const ha = await cagir('hediyeAl', { jeton, kadin: true });
  bekle('yeterli parçada hediye kodu verilir', ha.v && /^TRK-[A-Z0-9]{4}-[A-Z0-9]{4}$/.test(ha.v.kod) && /Manikür/.test(ha.v.ad), ha);
  const ha2 = await cagir('hediyeAl', { jeton });
  bekle('yılda yalnızca bir hediye', ha2.v && ha2.v.kod === ha.v.kod, ha2);
  const yetkisiz = await fetch(url('hediyeDogrula&kod=' + ha.v.kod), { headers: { 'X-Tarak-Anahtar': 'yanlis' } });
  bekle('anahtarsız doğrulama reddedilir', yetkisiz.status === 401, yetkisiz.status);
  const anahtar = phpCalistir('echo tm_entegrasyon_anahtari();');
  const dg = await (await fetch(url('hediyeDogrula&kod=' + ha.v.kod), { headers: { 'X-Tarak-Anahtar': anahtar } })).json();
  bekle('Tarak Mobil kodu doğrular', dg.gecerli === true && dg.hediye.tur === 'kuafor', dg);
  const ku = await fetch(url('hediyeKullan&kod=' + ha.v.kod), { method: 'POST', headers: { 'X-Tarak-Anahtar': anahtar } });
  const ku2 = await fetch(url('hediyeKullan&kod=' + ha.v.kod), { method: 'POST', headers: { 'X-Tarak-Anahtar': anahtar } });
  bekle('kod bir kez kullanılır', ku.status === 200 && ku2.status === 409, [ku.status, ku2.status]);
  phpCalistir("tm_sorgu(\"INSERT INTO hediyeler (oyuncu_id, kod, tur, ad, yil, olusturma, son_tarih) VALUES (1, 'TRK-ESKI-KUPN', 'berber', 'Sakal', " + new Date().getFullYear() + ", 1, 2)\");");
  const eski = await (await fetch(url('hediyeDogrula&kod=TRK-ESKI-KUPN'), { headers: { 'X-Tarak-Anahtar': anahtar } })).json();
  bekle('30 günü geçen kupon geçersiz', eski.gecerli === false && eski.hediye.durum === 'suresi_doldu', eski);
  bekle('yeni kuponun son kullanma tarihi 30 gün', ha.v.sonTarih && Math.abs(ha.v.sonTarih - Date.now() / 1000 - 30 * 86400) < 600, ha.v);

  // Bölgesel sponsor: oyuncunun seçtiği ilçedeki işletmenin reklamı sayılır, berber paneli istatistiği alır
  phpCalistir("tm_sorgu(\"INSERT INTO sponsorlar (ad, hizmet, il, ilce, logo, renk, aktif, bitis, tarak_id, olusturma) VALUES ('Test Barber', 'Sakal Tıraşı', 'Ankara', 'Çankaya', '', '#1c2023', 1, 0, 'T-42', 1)\");");
  bekle('geçersiz ilçe reddedilir', (await cagir('bolge', { jeton, il: 'Ankara', ilce: 'Kadıköy' })).kod === 400);
  const bg = await cagir('bolge', { jeton, il: 'Ankara', ilce: 'Çankaya' });
  bekle('bölgedeki sponsor döner', bg.v && bg.v.sponsorlar.length === 1 && bg.v.sponsorlar[0].ad === 'Test Barber', bg);
  const sk = await cagir('basla', { jeton, bolum: 101 });
  await uyu(11000);
  await cagir('bitir', { jeton, kosuId: sk.v.kosuId, sonuc: 'kaybetti', skor: 50, tarak: 3, can: 0, sure: 10, mesafe: 120, sponsor: [bg.v.sponsorlar[0].id, 9999] });
  const ist = await (await fetch(url('sponsorIstatistik&isletme=T-42'), { headers: { 'X-Tarak-Anahtar': anahtar } })).json();
  bekle('sponsor gösterimi sayılır (başka bölgenin/olmayan sponsor sayılmaz)', ist.toplam === 1 && ist.tekilOyuncu === 1 && ist.rotalar[0].rota === 1, ist);
  bekle('sponsor istatistiği anahtarsız verilmez', (await fetch(url('sponsorIstatistik&isletme=T-42'))).status === 401);

  for (const yol of ['/inc/bolumler.json', '/data/gizli.php', '/data/.htaccess']) {
    const r = await fetch(`http://127.0.0.1:${PORT}${yol}`);
    bekle('korumalı yol kapalı: ' + yol, r.status === 403, r.status);
  }
  const admin = await (await fetch(`http://127.0.0.1:${PORT}/admin/`)).text();
  bekle('yönetici yokken kurulum anahtarı istenir', admin.includes('name="anahtar"'), admin.slice(0, 200));

  console.log(hata ? `\nBAŞARISIZ: ${hata}` : '\nTÜM API TESTLERİ GEÇTİ');
})().catch(e => { console.error(e); hata++; }).finally(async () => {
  sunucu.kill();
  await uyu(500);
  try { fs.rmSync(veri, { recursive: true, force: true }); } catch {}
  process.exit(hata ? 1 : 0);
});
