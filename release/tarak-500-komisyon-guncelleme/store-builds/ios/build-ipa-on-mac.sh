#!/usr/bin/env bash
# Tarak - App Store IPA, Mac uzerinde TEK KOMUT.
#
#   TEAM_ID=ABCDE12345 bash build-ipa-on-mac.sh
#
# Windows'ta IPA uretilemez; bu betik Mac + Xcode icindir. Mevcut iOS projesine DOKUNMAZ (proje dosyasi degistirilmez):
# Bundle ID app.tarak.mobile, "Automatically manage signing" ve mevcut Info.plist/ikonlar oldugu gibi kullanilir.
# Takim (Team ID) komut satirindan verilir; sertifika / private key / sifre BU PAKETTE YOKTUR:
# Apple Distribution kimliginiz Mac'inizin Anahtar Zinciri'nde ya da Xcode'a giris yaptiginiz Apple hesabinizda olmalidir.
#
# Ortam degiskenleri (hepsi istege bagli, TEAM_ID haric):
#   TEAM_ID                  (ZORUNLU) Apple Developer Team ID
#   MOBILE_DIR               Flutter projesi (varsayilan: bu betigin 4 ust klasorundeki mobile/)
#   BUILD_NAME / BUILD_NUMBER  varsayilan pubspec.yaml "version: 1.1.0+2" -> 1.1.0 / 2
#                            App Store Connect'te bu surum+build zaten varsa BUILD_NUMBER'i yukseltin (ornek BUILD_NUMBER=7)
#   API_BASE_URL / REVERB_HOST / REVERB_APP_KEY   varsayilan: https://tarak.app/api, tarak.app, hhyfpgfv2dgv95yd78kz
#   EXPORT_METHOD            app-store-connect (Xcode 15.3+, varsayilan) | app-store (eski Xcode)
#   ASC_KEY_PATH / ASC_KEY_ID / ASC_ISSUER_ID   App Store Connect API anahtari (.p8 yolu); verilirse Xcode hesabina gerek kalmaz
# Cikti: bu klasore  tarak-<surum>+<build>.ipa   (App Store Connect'e YUKLENMEZ; yukleme size birakildi)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="${MOBILE_DIR:-$HERE/../../../../mobile}"
MOBILE_DIR="$(cd "$MOBILE_DIR" && pwd)"

[ "$(uname)" = "Darwin" ] || { echo "HATA: bu betik macOS'ta calisir (Xcode gerekir)."; exit 1; }
: "${TEAM_ID:?HATA: TEAM_ID verin, ornek:  TEAM_ID=ABCDE12345 bash build-ipa-on-mac.sh}"
command -v flutter >/dev/null || { echo "HATA: flutter bulunamadi (Flutter 3.47.x kurulu olmali)."; exit 1; }
command -v xcodebuild >/dev/null || { echo "HATA: Xcode / xcodebuild bulunamadi."; exit 1; }

API_BASE_URL="${API_BASE_URL:-https://tarak.app/api}"
REVERB_HOST="${REVERB_HOST:-tarak.app}"
REVERB_APP_KEY="${REVERB_APP_KEY:-hhyfpgfv2dgv95yd78kz}"
EXPORT_METHOD="${EXPORT_METHOD:-app-store-connect}"

cd "$MOBILE_DIR"
BUILD_NAME="${BUILD_NAME:-$(sed -n 's/^version:[[:space:]]*\([0-9][0-9.]*\)+.*/\1/p' pubspec.yaml | head -1)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(sed -n 's/^version:[[:space:]]*[0-9][0-9.]*+\([0-9][0-9]*\).*/\1/p' pubspec.yaml | head -1)}"
[ -n "$BUILD_NAME" ] && [ -n "$BUILD_NUMBER" ] || { echo "HATA: pubspec.yaml surumu okunamadi."; exit 1; }
echo ">> Tarak iOS ${BUILD_NAME} (${BUILD_NUMBER})  bundle: app.tarak.mobile  team: ${TEAM_ID}"

# Uyarilar (hata degil): bunlar yoksa uygulama derlenir ama push calismaz.
[ -f ios/Runner/GoogleService-Info.plist ] || echo "UYARI: ios/Runner/GoogleService-Info.plist yok -> iOS push (FCM) kapali derlenir."
ls ios/Runner/*.entitlements >/dev/null 2>&1 || echo "UYARI: Runner.entitlements yok (Push Notifications capability Xcode'da eklenmemis) -> iOS push calismaz."

# Windows'tan tasinan yollar Mac'te gecersizdir: yeniden uret.
rm -rf build ios/Flutter/ephemeral ios/Flutter/Generated.xcconfig ios/Flutter/flutter_export_environment.sh
flutter pub get
flutter build ios --release --config-only \
  --build-name "$BUILD_NAME" --build-number "$BUILD_NUMBER" \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=REVERB_HOST="$REVERB_HOST" \
  --dart-define=REVERB_APP_KEY="$REVERB_APP_KEY"

if [ -f ios/Podfile ]; then (cd ios && pod install); fi

AUTH=()
if [ -n "${ASC_KEY_PATH:-}" ] && [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ]; then
  AUTH=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

ARCHIVE="$MOBILE_DIR/build/ios/archive/Runner.xcarchive"
IPA_DIR="$MOBILE_DIR/build/ios/ipa"
rm -rf "$ARCHIVE" "$IPA_DIR"

xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"} archive

PLIST="$(mktemp -t tarak-export).plist"
sed -e "s/__TEAM_ID__/$TEAM_ID/" -e "s/__METHOD__/$EXPORT_METHOD/" "$HERE/ExportOptions.plist" > "$PLIST"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$IPA_DIR" \
  -exportOptionsPlist "$PLIST" -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"}
rm -f "$PLIST"

IPA="$(ls "$IPA_DIR"/*.ipa | head -1)"
DEST="$HERE/tarak-${BUILD_NAME}+${BUILD_NUMBER}.ipa"
cp "$IPA" "$DEST"
echo
echo "IPA hazir: $DEST"
echo "SHA256   : $(shasum -a 256 "$DEST" | awk '{print $1}')"
echo "Yukleme  : Transporter uygulamasina surukleyin (otomatik yukleme yapilmadi)."
