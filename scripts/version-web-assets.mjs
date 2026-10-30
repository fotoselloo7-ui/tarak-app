// A release archive keeps the original Vite filenames. Version the complete
// module graph consistently so old browser caches cannot mix API contracts or
// execute the main module twice (queried entry + unqueried chunk imports).
import fs from 'node:fs';
const root = new URL('../tarak.app/', import.meta.url);
const version = '20261030-address-rules1';
let count = 0;
for (const name of fs.readdirSync(new URL('assets/', root)).filter(name => name.endsWith('.js') && !name.includes('sync-conflict'))) {
  const file = new URL(`assets/${name}`, root);
  const before = fs.readFileSync(file, 'utf8');
  const after = before.replace(/(["'])(\.?\/?(?:assets\/)?[A-Za-z0-9_./-]+\.js)(?:\?v=[A-Za-z0-9_-]+)?\1/g,
    (match, quote, path) => /^(\.\/|\/assets\/|assets\/)/.test(path) ? `${quote}${path}?v=${version}${quote}` : match);
  if (after !== before) { fs.writeFileSync(file, after); count++; }
}
const entry = new URL('index.html', root);
fs.writeFileSync(entry, fs.readFileSync(entry, 'utf8').replace(/(\/assets\/[A-Za-z0-9_-]+\.js)(?:\?v=[A-Za-z0-9_-]+)?/g, `$1?v=${version}`));
console.log(`Versioned ${count} web modules consistently (${version}).`);
