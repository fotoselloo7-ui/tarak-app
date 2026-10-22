#!/usr/bin/env python3
"""Tarak uygulama ikonu üretici: Android + iOS + uygulama içi seçenekler + mağaza görselleri.

Kaynak: `tools/icon-source/tarak-rating-512.png`, yani Tarak puanı için verilen resmi "k" taraklı ikon (yeniden çizilmez,
yalnız ölçeklenir). Simge hep aynıdır; **yalnız arka plan rengi** değişir. PALETTE içindeki 10 renk kullanıcıya
"Uygulama ikonu" ekranında sunulur; DEFAULT_ID (altın) varsayılan ve mağaza simgesidir.

    pip install Pillow
    python tools/generate_app_icons.py        # mobile/ klasöründen

Yazdıkları:
  android/app/src/main/res/mipmap-*/ic_launcher[_<id>].png             eski (API 21-25) simgeler, köşeleri yuvarlak
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher[_<id>].xml    uyarlanabilir simge tanımları
  android/app/src/main/res/drawable/ic_launcher_bg_<id>.xml            arka plan degradeleri
  android/app/src/main/res/drawable-*dpi/ic_launcher_foreground.png    ortak ön plan (şeffaf)
  android/app/src/main/res/drawable-nodpi/ic_launcher_monochrome.png   Android 13 "temalı simge"
  android/app/src/main/res/drawable-nodpi/ic_launcher_mark.png         açılış ekranı işareti
  android/app/src/main/res/values/brand_colors.xml                     açılış ekranı zemini (beyaz)
  android/app/src/main/AndroidManifest.xml                             <activity-alias> bloğu (ICON-ALIASES işaretleri arası)
  ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png                  varsayılan simge, tüm boyutlar (alfa kanalsız)
  ios/Runner/Assets.xcassets/AppIcon-<Id>.appiconset/*                 9 alternatif simge
  ios/Runner.xcodeproj/project.pbxproj                                 ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES
  ios/Runner/Assets.xcassets/LaunchImage.imageset/*.png                iOS açılış işareti
  lib/core/app_icon/app_icon_options.dart                              uygulama içi seçenek listesi (id, ad, renkler)
  store-assets/app-icons/                                              mağazaya elle yüklenecek görseller + 10 rengin önizlemesi
"""
import json
import re
import shutil
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

MOBILE = Path(__file__).resolve().parents[1]
SOURCE = MOBILE / "tools" / "icon-source" / "tarak-rating-512.png"

# id, Türkçe ad, (üst-sol, alt-sağ) degrade renkleri. id: küçük ASCII (Android kaynak adı + iOS simge adı için).
PALETTE = [
    ("altin", "Altın", (224, 166, 50), (176, 118, 24)),
    ("lacivert", "Lacivert", (36, 52, 90), (10, 16, 32)),
    ("krem", "Krem", (255, 255, 255), (240, 232, 218)),
    ("turuncu", "Turuncu", (255, 128, 72), (224, 68, 24)),
    ("bordo", "Bordo", (176, 48, 64), (112, 20, 40)),
    ("zumrut", "Zümrüt", (52, 168, 118), (16, 104, 76)),
    ("mavi", "Mavi", (66, 133, 244), (30, 78, 200)),
    ("mor", "Mor", (150, 98, 246), (88, 36, 180)),
    ("gul", "Gül", (244, 114, 170), (190, 52, 120)),
    ("grafit", "Grafit", (62, 68, 80), (20, 23, 28)),
]
DEFAULT_ID = "altin"
SPLASH_BG = (255, 255, 255)  # açılış ekranı zemini (Android + iOS)

MASTER = 1024
LEGACY_MARK = 0.62  # tam taşan (iOS / eski Android) simgede işaretin yüksekliği / kenar
ADAPTIVE_MARK = 0.46  # uyarlanabilir simgede işaretin yüksekliği / 108dp tuval (güvenli bölge: 66dp daire)
LAUNCH_MARK_PX = 480  # Android açılış ekranı işareti (yükseklik)

RES = MOBILE / "android" / "app" / "src" / "main" / "res"
MANIFEST = MOBILE / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
ASSETS = MOBILE / "ios" / "Runner" / "Assets.xcassets"
PBXPROJ = MOBILE / "ios" / "Runner.xcodeproj" / "project.pbxproj"


def pascal(icon_id: str) -> str:
    return icon_id[:1].upper() + icon_id[1:]


def res_name(icon_id: str) -> str:
    """Android simge kaynağı adı: varsayılan `ic_launcher`, diğerleri `ic_launcher_<id>`."""
    return "ic_launcher" if icon_id == DEFAULT_ID else f"ic_launcher_{icon_id}"


def hex_color(c) -> str:
    return "#%02X%02X%02X" % c


def load_mark() -> Image.Image:
    mark = Image.open(SOURCE).convert("RGBA")
    return mark.crop(mark.getbbox())


def gradient(size: int, top, bottom) -> Image.Image:
    """Sol üstten sağ alta çapraz degrade."""
    ramp = Image.linear_gradient("L").resize((size, size), Image.BICUBIC)
    across = ramp.transpose(Image.ROTATE_90)  # soldan sağa
    t = ImageChops.add(ramp, across, scale=2)
    return Image.composite(Image.new("RGB", (size, size), bottom), Image.new("RGB", (size, size), top), t)


def put_mark(canvas: Image.Image, mark: Image.Image, height_fraction: float) -> Image.Image:
    size = canvas.size[0]
    h = round(size * height_fraction)
    w = round(mark.size[0] * h / mark.size[1])
    out = canvas.convert("RGBA")
    out.alpha_composite(mark.resize((w, h), Image.LANCZOS), ((size - w) // 2, (size - h) // 2))
    return out


def rounded(image: Image.Image, radius_fraction: float) -> Image.Image:
    size = image.size[0]
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size * 4 - 1, size * 4 - 1), radius=int(size * 4 * radius_fraction), fill=255)
    out = image.convert("RGBA")
    out.putalpha(mask.resize((size, size), Image.LANCZOS))
    return out


def monochrome(mark: Image.Image) -> Image.Image:
    """Tek renkli (temalı simge) siluet: k'nın gövdesi dolu, taraktaki altın çizgiler boş."""
    w, h = mark.size
    alpha = mark.split()[-1].point(lambda v: 255 if v > 128 else 0)
    r, g, b, _ = mark.split()
    gold = ImageChops.multiply(
        r.point(lambda v: 255 if v > 170 else 0),
        ImageChops.multiply(g.point(lambda v: 255 if v > 110 else 0), b.point(lambda v: 255 if v < 140 else 0)),
    )
    # Yalnız taraktaki dişler (sağ alt bölge) ve kenar çizgisinden uzak olanlar boşaltılır.
    interior = alpha.filter(ImageFilter.MinFilter(45))
    region = Image.new("L", mark.size, 0)
    ImageDraw.Draw(region).rectangle((int(w * 0.5), int(h * 0.62), w, h), fill=255)
    teeth = ImageChops.multiply(ImageChops.multiply(gold, interior), region).filter(ImageFilter.MaxFilter(5))
    out = Image.new("RGBA", mark.size, (255, 255, 255, 0))
    out.putalpha(ImageChops.subtract(alpha, teeth))
    return out


def contain(mark: Image.Image, canvas: int, height_fraction: float) -> Image.Image:
    """Şeffaf kare tuval üzerinde ortalanmış işaret."""
    layer = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    return put_mark(layer, mark, height_fraction)


def save(image: Image.Image, path: Path, rgb: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    (image.convert("RGB") if rgb else image).save(path, optimize=True)


def build_master(mark: Image.Image, top, bottom) -> Image.Image:
    return put_mark(gradient(MASTER, top, bottom), mark, LEGACY_MARK).convert("RGB")


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


# ───────────────────────────────────────────────────────────── Android

def android(mark: Image.Image, masters: dict) -> None:
    for density, px in {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}.items():
        save(contain(mark, px, ADAPTIVE_MARK), RES / f"drawable-{density}" / "ic_launcher_foreground.png")
    save(contain(monochrome(mark), 432, ADAPTIVE_MARK), RES / "drawable-nodpi" / "ic_launcher_monochrome.png")
    launch = mark.resize((round(mark.size[0] * LAUNCH_MARK_PX / mark.size[1]), LAUNCH_MARK_PX), Image.LANCZOS)
    save(launch, RES / "drawable-nodpi" / "ic_launcher_mark.png")
    for stale in (RES / "drawable" / "ic_launcher_mark.png", RES / "drawable" / "ic_launcher_foreground.xml", RES / "drawable" / "ic_launcher_background.xml"):
        if stale.exists():
            stale.unlink()

    for icon_id, name, top, bottom in PALETTE:
        master = masters[icon_id]
        for density, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
            save(rounded(master.resize((px, px), Image.LANCZOS), 0.2), RES / f"mipmap-{density}" / f"{res_name(icon_id)}.png")
        write(
            RES / "drawable" / f"ic_launcher_bg_{icon_id}.xml",
            '<?xml version="1.0" encoding="utf-8"?>\n'
            f'<!-- Tarak simgesi arka planı: {name} (tools/generate_app_icons.py üretir). -->\n'
            '<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">\n'
            f'    <gradient android:type="linear" android:angle="315" android:startColor="{hex_color(top)}" android:endColor="{hex_color(bottom)}" />\n'
            '</shape>\n',
        )
        write(
            RES / "mipmap-anydpi-v26" / f"{res_name(icon_id)}.xml",
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            f'    <background android:drawable="@drawable/ic_launcher_bg_{icon_id}" />\n'
            '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
            '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n'
            '</adaptive-icon>\n',
        )

    write(
        RES / "values" / "brand_colors.xml",
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        '    <!-- Açılış ekranı zemini beyaz: seçilebilir simge renginden bağımsız, Flutter yükleme ekranıyla kesintisiz. -->\n'
        f'    <color name="tarak_brand_background">{hex_color(SPLASH_BG)}</color>\n'
        '</resources>\n',
    )
    launch_xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- Tarak açılış ekranı: marka rengi + ortada işaret. -->\n'
        '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <item android:drawable="@color/tarak_brand_background" />\n'
        '    <item android:width="150dp" android:height="150dp" android:gravity="center">\n'
        '        <bitmap android:gravity="center" android:src="@drawable/ic_launcher_mark" />\n'
        '    </item>\n'
        '</layer-list>\n'
    )
    for folder in ("drawable", "drawable-v21"):
        write(RES / folder / "launch_background.xml", launch_xml)

    # Her renk için bir <activity-alias>: yalnız biri etkindir, MainActivity'nin kendisi başlatıcıda görünmez.
    aliases = ["        <!-- ICON-ALIASES:BEGIN (tools/generate_app_icons.py üretir; elle düzenleme) -->"]
    for icon_id, name, _, _ in PALETTE:
        aliases += [
            "        <activity-alias",
            f'            android:name=".Icon{pascal(icon_id)}"',
            '            android:targetActivity=".MainActivity"',
            f'            android:enabled="{"true" if icon_id == DEFAULT_ID else "false"}"',
            '            android:exported="true"',
            f'            android:icon="@mipmap/{res_name(icon_id)}"',
            '            android:label="@string/app_name">',
            "            <intent-filter>",
            '                <action android:name="android.intent.action.MAIN"/>',
            '                <category android:name="android.intent.category.LAUNCHER"/>',
            "            </intent-filter>",
            "        </activity-alias>",
        ]
    aliases.append("        <!-- ICON-ALIASES:END -->")
    block = "\n".join(aliases)
    text = MANIFEST.read_text(encoding="utf-8").replace("\r\n", "\n")
    if "ICON-ALIASES:BEGIN" in text:
        text = re.sub(r"[ \t]*<!-- ICON-ALIASES:BEGIN.*?<!-- ICON-ALIASES:END -->", lambda _: block, text, flags=re.S)
    else:
        text = text.replace("        <!-- Don't delete the meta-data below.", block + "\n        <!-- Don't delete the meta-data below.", 1)
    write(MANIFEST, text)


# ───────────────────────────────────────────────────────────── iOS

def ios(mark: Image.Image, masters: dict) -> None:
    primary = ASSETS / "AppIcon.appiconset"
    contents = json.loads((primary / "Contents.json").read_text(encoding="utf-8"))

    def write_set(folder: Path, master: Image.Image, with_marketing: bool) -> None:
        images = []
        for entry in contents["images"]:
            name = entry.get("filename")
            if not name:
                continue
            if not with_marketing and entry.get("idiom") == "ios-marketing":
                continue
            points = float(entry["size"].split("x")[0])
            px = round(points * int(entry["scale"].rstrip("x")))
            # iOS kendi köşe maskesini uygular ve alfa kanalı olan simgeyi App Store reddeder: düz kare, alfasız.
            save(master.resize((px, px), Image.LANCZOS), folder / name, rgb=True)
            images.append(entry)
        write(folder / "Contents.json", json.dumps({"images": images, "info": contents["info"]}, indent=2, ensure_ascii=False) + "\n")

    write_set(primary, masters[DEFAULT_ID], with_marketing=True)
    alternates = []
    for icon_id, _, _, _ in PALETTE:
        if icon_id == DEFAULT_ID:
            continue
        folder = ASSETS / f"AppIcon-{pascal(icon_id)}.appiconset"
        write_set(folder, masters[icon_id], with_marketing=False)
        alternates.append(f"AppIcon-{pascal(icon_id)}")

    # Alternatif simge kümelerini uygulamaya kat (Xcode: "Alternate App Icon Sets").
    text = PBXPROJ.read_text(encoding="utf-8")
    text = re.sub(r"\n\t+ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = [^\n]*;", "", text)
    text = re.sub(
        r"(\n(\t+)ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;)",
        lambda m: f'{m.group(1)}\n{m.group(2)}ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "{" ".join(alternates)}";',
        text,
    )
    PBXPROJ.write_text(text, encoding="utf-8", newline="\n")

    launch_dir = ASSETS / "LaunchImage.imageset"
    for name, side in {"LaunchImage.png": 128, "LaunchImage@2x.png": 256, "LaunchImage@3x.png": 384}.items():
        h = round(side * 0.82)
        w = round(mark.size[0] * h / mark.size[1])
        layer = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        layer.alpha_composite(mark.resize((w, h), Image.LANCZOS), ((side - w) // 2, (side - h) // 2))
        save(layer, launch_dir / name)
    storyboard = MOBILE / "ios" / "Runner" / "Base.lproj" / "LaunchScreen.storyboard"
    text = storyboard.read_text(encoding="utf-8")
    new_color = '<color key="backgroundColor" red="%.6f" green="%.6f" blue="%.6f" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>' % tuple(c / 255 for c in SPLASH_BG)
    text = re.sub(r'<color key="backgroundColor" red="[^"]*" green="[^"]*" blue="[^"]*" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>', new_color, text, count=1)
    storyboard.write_text(text, encoding="utf-8", newline="\n")


# ───────────────────────────────────────────────────────────── Dart + mağaza

def dart_options() -> None:
    lines = [
        "// GENERATED by tools/generate_app_icons.py. Do not edit; change PALETTE in the script and run it again.",
        "import 'dart:ui' show Color;",
        "",
        "/// One of the selectable app icons: the same Tarak mark on a different background colour.",
        "class AppIconOption {",
        "  /// Stable id: Android `<activity-alias>` name suffix and iOS alternate icon name (`AppIcon-<Id>`).",
        "  final String id;",
        "  final String name;",
        "  final Color top;",
        "  final Color bottom;",
        "  const AppIconOption(this.id, this.name, this.top, this.bottom);",
        "}",
        "",
        f"const String kDefaultAppIconId = '{DEFAULT_ID}';",
        "",
        "const List<AppIconOption> kAppIconOptions = [",
    ]
    for icon_id, name, top, bottom in PALETTE:
        lines.append(f"  AppIconOption('{icon_id}', '{name}', Color(0xFF{top[0]:02X}{top[1]:02X}{top[2]:02X}), Color(0xFF{bottom[0]:02X}{bottom[1]:02X}{bottom[2]:02X})),")
    lines += ["];", ""]
    write(MOBILE / "lib" / "core" / "app_icon" / "app_icon_options.dart", "\n".join(lines))


def store_assets(masters: dict) -> None:
    out = MOBILE / "store-assets" / "app-icons"
    shutil.rmtree(out / "alternatif-renkler", ignore_errors=True)
    save(masters[DEFAULT_ID], out / "ios-app-store" / "app-icon-1024.png", rgb=True)
    save(masters[DEFAULT_ID].resize((512, 512), Image.LANCZOS), out / "google-play" / "app-icon-512.png", rgb=True)
    for icon_id, _, _, _ in PALETTE:
        save(masters[icon_id], out / "renkler" / f"app-icon-1024-{icon_id}.png", rgb=True)
    tile = 256
    sheet = Image.new("RGB", (5 * (tile + 16) + 16, 2 * (tile + 16) + 16), (236, 238, 242))
    for i, (icon_id, _, _, _) in enumerate(PALETTE):
        icon = rounded(masters[icon_id].resize((tile, tile), Image.LANCZOS), 0.225)
        sheet.paste(icon, (16 + (i % 5) * (tile + 16), 16 + (i // 5) * (tile + 16)), icon)
    save(sheet, out / "renkler" / "_onizleme.png", rgb=True)


def main() -> None:
    mark = load_mark()
    masters = {icon_id: build_master(mark, top, bottom) for icon_id, _, top, bottom in PALETTE}
    android(mark, masters)
    ios(mark, masters)
    dart_options()
    store_assets(masters)
    print(f"Tamam: {len(PALETTE)} renk, varsayılan {DEFAULT_ID}")


if __name__ == "__main__":
    main()
