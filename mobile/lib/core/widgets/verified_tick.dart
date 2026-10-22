import 'package:flutter/material.dart';

/// The blue "onaylı hizmet veren" tick. It belongs next to a provider's name wherever that name appears (cards,
/// lists, profiles, chat, offers, appointments) as soon as the provider is verified (`is_verified` in the API).
/// One look everywhere: do not draw another check icon for this.
class VerifiedTick extends StatelessWidget {
  static const Color color = Color(0xFF2563EB);

  final double size;
  const VerifiedTick({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Onaylı hizmet veren',
      child: Icon(Icons.verified_rounded, size: size, color: color),
    );
  }
}

/// `is_verified` of an API map (older shapes only carry `is_approved`).
bool isVerifiedMap(Map<dynamic, dynamic>? provider) => provider != null && (provider['is_verified'] ?? provider['is_approved']) == true;

/// A provider name with its tick: the name shortens first (ellipsis), the tick always stays.
class ProviderNameRow extends StatelessWidget {
  final String name;
  final bool verified;
  final TextStyle? style;
  final int maxLines;
  final double tickSize;
  final MainAxisAlignment alignment;

  const ProviderNameRow({
    super.key,
    required this.name,
    required this.verified,
    this.style,
    this.maxLines = 1,
    this.tickSize = 15,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: [
        Flexible(child: Text(name, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style)),
        if (verified) ...[
          const SizedBox(width: 4),
          VerifiedTick(size: tickSize),
        ],
      ],
    );
  }
}
