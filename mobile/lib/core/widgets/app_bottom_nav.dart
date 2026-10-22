import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One tab of [AppBottomNav].
class AppNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Unread counter shown as a badge on the icon (0 hides it).
  final int badge;

  const AppNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge = 0,
  });
}

/// The bottom tab bar shared by the customer and provider shells: a white sheet with softly
/// rounded top corners, a lifted shadow and a pill-shaped highlight behind the active icon.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppNavItem> items;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  Widget _icon(AppNavItem item, bool active) {
    final icon = Icon(active ? item.activeIcon : item.icon);
    if (item.badge <= 0) return icon;
    return Badge(
      backgroundColor: AppTheme.primary,
      label: Text(
        item.badge > 99 ? '99+' : '${item.badge}',
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(top: Radius.circular(24));
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 68,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            indicatorColor: AppTheme.primaryLight,
            indicatorShape: const StadiumBorder(),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                size: 24,
                color: selected ? AppTheme.primary : AppTheme.slate500,
              );
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppTheme.primary : AppTheme.slate500,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: onTap,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (var i = 0; i < items.length; i++)
                NavigationDestination(
                  icon: _icon(items[i], false),
                  selectedIcon: _icon(items[i], true),
                  label: items[i].label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
