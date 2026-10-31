import 'package:flutter/material.dart';

/// Icon + tint for one service. Mirrors the web `ServiceIcon`: the catalog (backend) names an
/// icon per service as a Font Awesome class ("fa-solid fa-crown"); those map to Material icons
/// here, with the service name as a fallback ("Sakal Tıraşı" ships the generic "fa-user").
class ServiceVisual {
  final IconData icon;
  final Color foreground;
  final Color from;
  final Color to;
  const ServiceVisual(this.icon, this.foreground, this.from, this.to);
}

const _orange = ServiceVisual(Icons.content_cut_rounded, Color(0xFFEA580C), Color(0xFFFFEDD5), Color(0xFFFFFBEB));
const _sky = ServiceVisual(Icons.air_rounded, Color(0xFF0284C7), Color(0xFFE0F2FE), Color(0xFFECFEFF));
const _amber = ServiceVisual(Icons.workspace_premium_rounded, Color(0xFFD97706), Color(0xFFFEF3C7), Color(0xFFFEFCE8));
const _emerald = ServiceVisual(Icons.child_care_rounded, Color(0xFF059669), Color(0xFFD1FAE5), Color(0xFFF0FDFA));
const _violet = ServiceVisual(Icons.colorize_rounded, Color(0xFF7C3AED), Color(0xFFEDE9FE), Color(0xFFFAF5FF));
const _pink = ServiceVisual(Icons.palette_rounded, Color(0xFFDB2777), Color(0xFFFCE7F3), Color(0xFFFFF1F2));
const _rose = ServiceVisual(Icons.auto_awesome_rounded, Color(0xFFE11D48), Color(0xFFFFE4E6), Color(0xFFFDF2F8));
const _teal = ServiceVisual(Icons.spa_rounded, Color(0xFF0D9488), Color(0xFFCCFBF1), Color(0xFFECFEFF));
const _fuchsia = ServiceVisual(Icons.diamond_rounded, Color(0xFFC026D3), Color(0xFFFAE8FF), Color(0xFFFDF2F8));
const _wand = ServiceVisual(Icons.auto_fix_high_rounded, Color(0xFFDB2777), Color(0xFFFCE7F3), Color(0xFFFFF1F2));
const _green = ServiceVisual(Icons.eco_rounded, Color(0xFF16A34A), Color(0xFFDCFCE7), Color(0xFFF7FEE7));
const _cyan = ServiceVisual(Icons.visibility_rounded, Color(0xFF0891B2), Color(0xFFCFFAFE), Color(0xFFF0F9FF));
const _beard = ServiceVisual(Icons.face_retouching_natural_rounded, Color(0xFF334155), Color(0xFFE2E8F0), Color(0xFFF1F5F9));

const _byIconClass = <String, ServiceVisual>{
  'scissors': _orange,
  'wind': _sky,
  'crown': _amber,
  'child': _emerald,
  'paintbrush': _violet,
  'palette': _pink,
  'hand-sparkles': _rose,
  'shoe-prints': _teal,
  'gem': _fuchsia,
  'wand-magic-sparkles': _wand,
  'leaf': _green,
  'eye': _cyan,
};

final _byName = <(RegExp, ServiceVisual)>[
  (RegExp('sakal'), _beard),
  (RegExp('çocuk'), _emerald),
  (RegExp('damat|gelin|vip'), _amber),
  (RegExp('boya|röfle|ombre|renk'), _violet),
  (RegExp('fön'), _sky),
  (RegExp('makyaj'), _wand),
  (RegExp('manik'), _rose),
  (RegExp('pedik'), _teal),
  (RegExp('ağda'), _green),
  (RegExp('kaş|bıyık'), _cyan),
  (RegExp('kes|tıraş|saç'), _orange),
];

String _lower(String value) => value.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

ServiceVisual resolveServiceVisual(String? iconClass, String? name) {
  final label = _lower(name ?? '');
  final fa = (iconClass ?? '')
      .split(RegExp(r'\s+'))
      .map((token) => token.replaceFirst(RegExp('^fa-'), ''))
      .where(_byIconClass.containsKey)
      .firstOrNull;
  // The generic user icon says nothing; "Saç Kesimi"-style scissors must not win over "Sakal …".
  if (fa != null && !(fa == 'scissors' && label.contains('sakal'))) return _byIconClass[fa]!;
  for (final (pattern, visual) in _byName) {
    if (pattern.hasMatch(label)) return visual;
  }
  return _orange;
}

/// Rounded gradient tile carrying the service's own icon.
class ServiceIconBox extends StatelessWidget {
  final String? iconClass;
  final String? name;
  final double size;
  final double iconSize;
  final double radius;

  const ServiceIconBox({
    super.key,
    this.iconClass,
    this.name,
    this.size = 40,
    this.iconSize = 20,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final v = resolveServiceVisual(iconClass, name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(colors: [v.from, v.to], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: v.foreground.withValues(alpha: 0.16)),
      ),
      child: Icon(v.icon, size: iconSize, color: v.foreground),
    );
  }
}
