import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Item de la bottom nav
class WiNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badgeCount;

  const WiNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount,
  });
}

/// Bottom navigation bar WorkIt (design système)
///
/// Usage :
/// ```dart
/// WiBottomNav(
///   items: [
///     WiNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Accueil'),
///     WiNavItem(icon: Icons.description_outlined, activeIcon: Icons.description, label: 'Devis', badgeCount: 4),
///     WiNavItem(icon: Icons.location_on_outlined, activeIcon: Icons.location_on, label: 'Chantiers'),
///     WiNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profil'),
///   ],
///   currentIndex: _tabIndex,
///   onTap: (i) => setState(() => _tabIndex = i),
/// )
/// ```
class WiBottomNav extends StatelessWidget {
  final List<WiNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color? activeColor;

  const WiBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.primary;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.grey200)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            isActive ? item.activeIcon : item.icon,
                            color: isActive ? color : AppColors.grey400,
                            size: 24,
                          ),
                          if (item.badgeCount != null && item.badgeCount! > 0)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.surface, width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    '${item.badgeCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isActive ? color : AppColors.grey400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
