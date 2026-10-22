import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// "Panel | Müşteri" switch of a provider account. The account does not change: the customer view is a read-only
/// look at the platform the way a customer sees it (home page, services, provider lists with the recommended
/// ads); the panel holds the provider's own modules.
class ProviderViewModeSwitch extends StatelessWidget {
  /// True while the customer view is the one on screen.
  final bool customer;

  /// Called with the view that was tapped (true = customer view); not called for the one already showing.
  final ValueChanged<bool> onChanged;

  const ProviderViewModeSwitch({super.key, required this.customer, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppTheme.slate100, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.slate200)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(key: const Key('view_mode_panel'), label: 'Panel', icon: Icons.work_outline_rounded, selected: !customer, onTap: () { if (customer) onChanged(false); }),
          _Segment(key: const Key('view_mode_customer'), label: 'Müşteri', icon: Icons.visibility_outlined, selected: customer, onTap: () { if (!customer) onChanged(true); }),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Segment({super.key, required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected ? const [BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1))] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: selected ? AppTheme.slate900 : AppTheme.slate500),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w700, color: selected ? AppTheme.slate900 : AppTheme.slate500)),
            ],
          ),
        ),
      ),
    );
  }
}
