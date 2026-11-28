#!/bin/bash
# Randevuya Koş oyununu ve Tarak entegrasyonunu cPanel'de kurar / günceller (tekrar tekrar çalıştırılabilir).
#   curl -fsSL https://raw.githubusercontent.com/fotoselloo7-ui/tarak-app/main/tarak-backend/oyun/tools/cpanel-kur.sh -o ~/tarak-kur.sh && bash ~/tarak-kur.sh 2>&1 | tee ~/tarak-yedek/son-kur.log
# Yaptıkları:
#  1. Değişecek dosyaların ve veritabanının yedeği (~/tarak-yedek/oyun-<tarih>/)
#  2. GitHub main'den oyun dosyaları (tarak.app/oyun) ve backend'in oyun dosyaları
#  3. Canlı routes/api.php, config/services.php, tarak.app/index.html dosyalarına yalnızca eksikse ekleme (üzerine yazmaz)
#  4. .env'e GAME_SERVER_KEY / GAME_RETURN_URLS (yoksa), yalnız oyun tablolarının migration'ı, önbellek yenileme
#  5. Oyun sunucusunu Tarak'a bağlama (tarak_api + anahtar), kontrol istekleri
# Sırlar ekrana ve kayda yazılmaz.
set -euo pipefail
H="$HOME"
B="$H/tarak-backend"
W="$H/tarak.app"
REPO="https://github.com/fotoselloo7-ui/tarak-app.git"
DAL="${TARAK_DAL:-main}"
Y="$H/tarak-yedek/oyun-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$Y"
LOG="$Y/kur.log"
echo "== Kurulum başladı: $(date)  dal: $DAL"

# ---- 1. yedek
cp -a "$B/routes/api.php" "$Y/api.php"
cp -a "$B/config/services.php" "$Y/services.php"
cp -a "$B/.env" "$Y/backend.env"; chmod 600 "$Y/backend.env"
cp -a "$W/index.html" "$Y/index.html"
[ -d "$W/oyun" ] && tar -czf "$Y/oyun-eski.tgz" -C "$W" --exclude='oyun/data' oyun || true
cd "$B"
CNF="$Y/.my.cnf"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP" "$CNF"' EXIT
# Yardımcı betik GitHub'dan (yerel kopya yoksa)
curl -fsSL "https://raw.githubusercontent.com/fotoselloo7-ui/tarak-app/$DAL/tarak-backend/oyun/tools/cpanel-yardimci.php?t=$(date +%s)" -o "$TMP/yardimci.php"
DBADI=$(php "$TMP/yardimci.php" dbcnf "$B" "$CNF" | tail -1)
if [ -f "$CNF" ] && [ "$DBADI" != "-" ]; then
  mysqldump --defaults-extra-file="$CNF" --single-transaction --no-tablespaces --routines "$DBADI" | gzip > "$Y/veritabani.sql.gz"
  rm -f "$CNF"
  echo "Veritabanı yedeği: $(du -h "$Y/veritabani.sql.gz" | cut -f1)"
else
  echo "UYARI: veritabanı yedeği alınamadı (sürücü: $DBADI); kurulum durduruldu"; exit 1
fi

# ---- 2. GitHub'dan dosyalar
if git clone -q --depth 1 --branch "$DAL" --filter=blob:none --sparse "$REPO" "$TMP/r" 2>/dev/null; then
  git -C "$TMP/r" sparse-checkout set tarak.app/oyun tarak-backend/app/Http/Controllers/Api tarak-backend/database/migrations tarak-backend/resources/views/game tarak-backend/routes tarak-backend/config
else
  rm -rf "$TMP/r"; git clone -q --depth 1 --branch "$DAL" "$REPO" "$TMP/r"
fi
R="$TMP/r"
echo "Sürüm: $(git -C "$R" log -1 --format='%h %s')"
mkdir -p "$W/oyun"
# oyun verisi (data/) ve yüklenen sponsor logoları korunur
( cd "$R/tarak.app/oyun" && find . -type f ! -path './data/*' ! -path './uploads/sponsor/*' -print0 | while IFS= read -r -d '' f; do mkdir -p "$W/oyun/$(dirname "$f")"; cp "$f" "$W/oyun/$f"; done )
mkdir -p "$W/oyun/data" "$W/oyun/uploads/sponsor"
cp "$R/tarak.app/oyun/data/.htaccess" "$W/oyun/data/.htaccess"
chmod 750 "$W/oyun/data"
cp "$R/tarak-backend/app/Http/Controllers/Api/GameController.php" "$B/app/Http/Controllers/Api/GameController.php"
cp "$R/tarak-backend/database/migrations/2026_11_28_100000_create_game_tables.php" "$B/database/migrations/"
mkdir -p "$B/resources/views/game" && cp "$R/tarak-backend/resources/views/game/giris.blade.php" "$B/resources/views/game/"

# ---- 3. canlı dosyalara ekleme (yalnız eksikse)
cp -a "$B/routes/api.php" "$TMP/api-onceki.php"
echo "routes/api.php: oyun rotaları $(php "$TMP/yardimci.php" rota-guncelle "$B/routes/api.php" "$R/tarak-backend/routes/api.php")"
if ! php -l "$B/routes/api.php" >/dev/null; then cp -a "$TMP/api-onceki.php" "$B/routes/api.php"; echo "HATA: routes/api.php geri alındı"; exit 1; fi
echo "config/services.php: $(php "$TMP/yardimci.php" servis-ekle "$B/config/services.php")"
php -l "$B/config/services.php" >/dev/null
php -l "$B/routes/api.php" >/dev/null
if ! grep -q "oyun/site-baglanti.js" "$W/index.html"; then
  sed -i 's#</head>#  <script defer src="/oyun/site-baglanti.js?v=20261128-1"></script>\n</head>#' "$W/index.html"
  echo "index.html: oyun bağlantısı eklendi"
else echo "index.html: oyun bağlantısı zaten var"; fi

# ---- 4. .env, migration, önbellek
if ! grep -q '^GAME_SERVER_KEY=' "$B/.env"; then
  printf '\n# Randevuya Koş oyunu\nGAME_SERVER_KEY=%s\nGAME_RETURN_URLS=https://tarak.app/oyun\n' "$(openssl rand -hex 32)" >> "$B/.env"
  echo ".env: GAME_SERVER_KEY ve GAME_RETURN_URLS eklendi"
else echo ".env: oyun anahtarı zaten var"; fi
php artisan migrate --force --path=database/migrations/2026_11_28_100000_create_game_tables.php
[ -f bootstrap/cache/config.php ] && php artisan config:cache >/dev/null && echo "config önbelleği yenilendi" || php artisan config:clear >/dev/null
[ -f bootstrap/cache/routes-v7.php ] && php artisan route:cache >/dev/null && echo "rota önbelleği yenilendi" || true
php artisan view:clear >/dev/null || true

# ---- 5. oyun sunucusunu Tarak'a bağla
ANAHTAR=$(grep '^GAME_SERVER_KEY=' .env | tail -1 | cut -d= -f2-)
TM_ANAHTAR="$ANAHTAR" php -r 'require $argv[1]; tm_ayar_yaz("tarak_api", "https://tarak.app/api"); tm_ayar_yaz("tarak_oyun_anahtari", getenv("TM_ANAHTAR")); echo "Oyun ayarları: Tarak bağlantısı yazıldı\n";' "$W/oyun/inc/baslat.php"
unset ANAHTAR
[ -f "$W/oyun/data/gizli.php" ] && chmod 640 "$W/oyun/data/gizli.php"

echo "== Kontroller"
k() { printf '%-55s %s\n' "$1" "$(curl -s -o /dev/null -w '%{http_code}' "$1")"; }
k https://tarak.app/oyun/
k https://tarak.app/oyun/api/index.php?islem=ayar
k https://tarak.app/oyun/data/gizli.php
k https://tarak.app/oyun/inc/baslat.php
k https://tarak.app/api/game/linkler
k "https://tarak.app/api/game/sponsorlar?il=Antalya&ilce=Alanya"
k "https://tarak.app/api/game/giris?donus=https://tarak.app/oyun/"
k https://tarak.app/oyun/hesap/
echo "== Bitti: $(date)  kayıt: $LOG"
