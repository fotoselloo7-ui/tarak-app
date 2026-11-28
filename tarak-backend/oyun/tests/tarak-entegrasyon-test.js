// Oyun ↔ Tarak uçtan uca testi: "Tarak ile giriş", Tarak'ta üretilen kupon, Tarak sponsorları.
// Yerelde çalışan bir Tarak backend'i ister (gerçek sunucuya bağlanmaz):
//   TARAK_API=http://127.0.0.1:18810/api TARAK_ANAHTAR=... TARAK_GIRIS=oyuncu@example.test TARAK_SIFRE=... node tests/tarak-entegrasyon-test.js
// Oyun sunucusu geçici bir veri klasörüyle ayrı açılır; gerçek oyun verisine dokunmaz.
'use strict';
const { spawn, execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { TARAK_API, TARAK_ANAHTAR, TARAK_GIRIS, TARAK_SIFRE } = process.env;
if (!TARAK_API || !TARAK_ANAHTAR || !TARAK_GIRIS || !TARAK_SIFRE) { console.log('ATLANDI: TARAK_API, TARAK_ANAHTAR, TARAK_GIRIS, TARAK_SIFRE gerekli'); process.exit(0); }

const PHP = process.env.PHP_YOLU || 'C:\\xampp\\php\\php.exe';
const PORT = 8898;
const kok = path.join(__dirname, '..');
const veri = fs.mkdtempSync(path.join(os.tmpdir(), 'tarak-ent-'));
const env = { ...process.env, TM_VERI_KLASORU: veri };
const php = kod => execFileSync(PHP, ['-r', `require '${path.join(kok, '..', '..', 'tarak.app', 'oyun', 'inc', 'baslat.php').replace(/\\/g, '/')}'; ${kod}`], { env }).toString();
const sunucu = spawn(PHP, ['-S', `127.0.0.1:${PORT}`, '-t', path.join(kok, '..', '..', 'tarak.app', 'oyun'), path.join(kok, 'dev-router.php')], { env, stdio: 'ignore' });

const url = i => `http://127.0.0.1:${PORT}/api/index.php?islem=${i}`;
async function cagir(islem, govde) {
  const r = await fetch(url(islem), govde ? { method: 'POST', headers: { 'Content-Type': 'text/plain' }, body: JSON.stringify(govde) } : undefined);
  return { kod: r.status, v: await r.json().catch(() => null) };
}
let hata = 0;
function bekle(ad, kosul, ek) { console.log((kosul ? 'GEÇTİ  ' : 'KALDI  ') + ad + (kosul ? '' : '  ' + JSON.stringify(ek))); if (!kosul) hata++; }
const uyu = ms => new Promise(r => setTimeout(r, ms));

(async () => {
  try {
    for (let i = 0; i < 40; i++) { try { await fetch(url('ayar')); break; } catch { await uyu(150); } }
    php(`tm_ayar_yaz('tarak_api', '${TARAK_API}'); tm_ayar_yaz('tarak_oyun_anahtari', '${TARAK_ANAHTAR}');`);

    const o = await cagir('oturum', { cihaz: 'tarak-ent-cihaz-01', platform: 'web', ekran: '1080x2400', isim: 'Deniz' });
    const jeton = o.v.jeton;
    // Bu yılın hediye parçaları toplanmış olsun
    php(`tm_sorgu("INSERT INTO kosular (oturum_id, oyuncu_id, bolum, baslangic, bitis, sonuc, parca, supheli, gun) SELECT id, oyuncu_id, 0, 0, 1, 'cikti', 25, 0, '${new Date().getFullYear()}-06-01' FROM oturumlar WHERE jeton = '${jeton}'");`);

    const h0 = await cagir('hediyeAl', { jeton, kadin: false });
    bekle('Tarak bağlıyken hediye için önce Tarak ile giriş istenir', h0.v && h0.v.tarakGerekli === true, h0);

    const g = await cagir('tarakGiris', { jeton, donus: 'http://localhost:8812/' });
    bekle('Tarak giriş sayfası adresi döner', g.v && /\/game\/giris\?/.test(g.v.url), g);
    const sayfa = await fetch(g.v.url);
    bekle('Tarak giriş sayfası açılır', sayfa.status === 200 && (await sayfa.text()).includes('Tarak ile giriş'), sayfa.status);

    const q = new URL(g.v.url).searchParams;
    const yanlis = await fetch(TARAK_API + '/game/giris', { method: 'POST', redirect: 'manual', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ donus: q.get('donus'), durum: q.get('durum'), login: TARAK_GIRIS, password: 'yanlis-sifre' }) });
    bekle('yanlış şifre reddedilir', yanlis.status === 422, yanlis.status);
    const giris = await fetch(TARAK_API + '/game/giris', { method: 'POST', redirect: 'manual', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ donus: q.get('donus'), durum: q.get('durum'), login: TARAK_GIRIS, password: TARAK_SIFRE }) });
    const donus = new URL(giris.headers.get('location') || 'http://x/');
    bekle('doğru giriş tek kullanımlık kodla oyuna döner', giris.status === 302 && donus.searchParams.get('tarak_kod'), giris.status);

    const baskaOturum = (await cagir('oturum', { cihaz: 'tarak-ent-cihaz-02', platform: 'web', ekran: '1x1', isim: 'Baska' })).v.jeton;
    const calinti = await cagir('tarakBagla', { jeton: baskaOturum, kod: donus.searchParams.get('tarak_kod'), durum: donus.searchParams.get('durum') });
    bekle('kod başka oturuma bağlanamaz', calinti.kod === 400, calinti);

    const b = await cagir('tarakBagla', { jeton, kod: donus.searchParams.get('tarak_kod'), durum: donus.searchParams.get('durum') });
    bekle('Tarak hesabı bağlanır ve bölgesi gelir', b.v && b.v.tamam && b.v.ilce === 'Beyoğlu', b);
    bekle('bölgedeki Tarak sponsoru gelir', b.v && b.v.sponsorlar.some(s => s.id > 100000 && s.ad === 'Galata Makas'), b.v && b.v.sponsorlar);

    const h1 = await cagir('hediyeAl', { jeton, kadin: false });
    bekle('kupon Tarak’ta üretilir (sponsor berberin hizmeti)', h1.v && /^TRK-/.test(h1.v.kod) && /Galata Makas/.test(h1.v.ad), h1);
    bekle('sponsor kartı oyuna gelir', h1.v && h1.v.sponsor && h1.v.sponsor.ad === 'Galata Makas', h1.v && h1.v.sponsor);
    const h2 = await cagir('hediye', { jeton, kadin: false });
    bekle('aynı kupon tekrar sorulunca değişmez', h2.v && h2.v.kod === h1.v.kod, h2);

    // Kupon Tarak tarafında da var: sunucudan sunucuya aynı oyun kaydı aynı kodu döndürür
    const ayni = await fetch(TARAK_API + '/game/hediye', { method: 'POST', headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-Oyun-Anahtar': TARAK_ANAHTAR },
      body: JSON.stringify({ kullanici_id: b.v && 1, oyun_ref: 'oyun-' + php(`echo tm_deger("SELECT oyuncu_id FROM oturumlar WHERE jeton = '${jeton}'");`) + '-' + new Date().getFullYear() }) }).then(r => r.json());
    bekle('Tarak’taki kayıt aynı kod', ayni.data && ayni.data.kod === h1.v.kod, ayni);
  } catch (e) { hata++; console.log('HATA', e); }
  sunucu.kill();
  fs.rmSync(veri, { recursive: true, force: true });
  console.log(hata ? `\n${hata} TEST KALDI` : '\nTÜM TARAK ENTEGRASYON TESTLERİ GEÇTİ');
  process.exit(hata ? 1 : 0);
})();
