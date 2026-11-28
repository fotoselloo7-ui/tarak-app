// Sunucusuz BETA sayfası üretir (tek HTML + görseller). API, admin ve veri klasörü pakete girmez.
//   node tools/beta-hazirla.js   ->   dist/beta/
'use strict';
const fs = require('fs');
const path = require('path');
const kok = path.join(__dirname, '..');
const web = path.join(kok, '..', '..', 'tarak.app', 'oyun');
const cikti = path.join(kok, 'dist', 'beta');
const oku = f => fs.readFileSync(path.join(web, f), 'utf8');

fs.rmSync(cikti, { recursive: true, force: true });
fs.mkdirSync(path.join(cikti, 'assets', 'img'), { recursive: true });

const govde = oku('index.html').split('<body>')[1].split('<script src=')[0];
const ayar = "window.TARAK_AYAR = { api: '', platform: 'web', beta: true };";
// index.html ile aynı sıra
const betikler = [ayar, ...['core', 'render', 'audio', 'odul', 'vendor/three.bundle', 'iller', 'uc-core', 'uc-maskot', 'uc-modeller', 'uc-yerler', 'uc-cadde', 'uc-sahne', 'uc-oyun', 'main'].map(a => oku(`assets/js/${a}.js`))];
for (const b of betikler) {
  if (/<\/script/i.test(b)) throw new Error('Betik içinde </script> var');
  new Function(b); // sözdizimi kontrolü
}

const sayfa = [
  '<title>Tarak Randevuya Koş</title>',
  '<style>', ':root{color-scheme:dark}', oku('assets/css/game.css'), '</style>',
  govde.trim(),
  ...betikler.map(b => `<script>\n${b}\n</script>`)
].join('\n');
fs.writeFileSync(path.join(cikti, 'oyun.html'), sayfa);

// Sayfanın ve betiklerin gerçekten kullandığı görseller
const gorseller = fs.readdirSync(path.join(web, 'assets', 'img'))
  .filter(f => /^(k-.*\.png|foto-.*\.jpg|logo-acik\.svg)$/.test(f))
  .filter(f => sayfa.includes(f));
for (const f of gorseller) fs.copyFileSync(path.join(web, 'assets', 'img', f), path.join(cikti, 'assets', 'img', f));
fs.mkdirSync(path.join(cikti, 'assets', 'tex'), { recursive: true });
const dokular = fs.readdirSync(path.join(web, 'assets', 'tex')).filter(f => f.endsWith('.jpg'));
for (const f of dokular) fs.copyFileSync(path.join(web, 'assets', 'tex', f), path.join(cikti, 'assets', 'tex', f));
gorseller.push(...dokular.map(f => '../tex/' + f));
// Gerçek cadde verisi (OpenStreetMap, il başına bir dosya)
const veriK = path.join(web, 'assets', 'veri', 'ilce');
fs.mkdirSync(path.join(cikti, 'assets', 'veri', 'ilce'), { recursive: true });
const veriler = fs.existsSync(veriK) ? fs.readdirSync(veriK).filter(f => f.endsWith('.json')) : [];
for (const f of veriler) fs.copyFileSync(path.join(veriK, f), path.join(cikti, 'assets', 'veri', 'ilce', f));
gorseller.push(...veriler.map(f => '../veri/ilce/' + f));
console.log(`oyun.html ${(sayfa.length / 1024).toFixed(0)} KB, ${gorseller.length} görsel:`);
console.log(gorseller.map(f => 'assets/img/' + f).join('\n'));
