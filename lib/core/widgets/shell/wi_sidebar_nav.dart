import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout_tokens.dart';
import '../wi_bottom_nav.dart' show WiNavItem;

/// Sidebar/nav rail desktop de WorkIt — style inspiré des outils métier
/// (Revel'Home) : logo, items icône+label, footer workspace/utilisateur.
///
/// `expanded` bascule entre rail réduit (icônes + tooltip, 72px) et sidebar
/// étendue (icône + label, 240px) — piloté par le palier responsive appelant,
/// pas par un état interne.
class WiSidebarNav extends StatelessWidget {
  final List<WiNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool expanded;
  final Color accentColor;
  final String brandLabel;
  final String? workspaceName;
  final String? userName;
  final VoidCallback? onLogout;

  const WiSidebarNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.expanded,
    this.accentColor = AppColors.primary,
    this.brandLabel = 'WorkIt',
    this.workspaceName,
    this.userName,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final width = expanded ? AppLayout.sidebarWidthExpanded : AppLayout.sidebarWidthCollapsed;
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(right: BorderSide(color: AppColors.sidebarBorder)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: AppLayout.desktopTopBarHeight,
              child: Row(
                mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  if (expanded) const SizedBox(width: 20),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 10),
                    Text(
                      brandLabel,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.grey900, letterSpacing: -0.4),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: List.generate(items.length, (i) {
                  final item = items[i];
                  final isActive = i == currentIndex;
                  final row = Material(
                    color: isActive ? AppColors.sidebarActiveBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onTap(i),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 11, horizontal: expanded ? 12 : 0),
                        child: Row(
                          mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                          children: [
                            Icon(
                              isActive ? item.activeIcon : item.icon,
                              size: 22,
                              color: isActive ? AppColors.sidebarActiveText : AppColors.grey500,
                            ),
                            if (expanded) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                    color: isActive ? AppColors.sidebarActiveText : AppColors.grey700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: expanded ? row : Tooltip(message: item.label, child: row),
                  );
                }),
              ),
            ),
            if (workspaceName != null || userName != null || onLogout != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: expanded ? _expandedFooter() : _collapsedFooter(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _expandedFooter() {
    return Row(
      children: [
        CircleAvatar(radius: 16, backgroundColor: AppColors.grey100, child: Icon(Icons.person, size: 16, color: AppColors.grey500)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (userName != null)
                Text(userName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.grey900)),
              if (workspaceName != null)
                Text(workspaceName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
            ],
          ),
        ),
        if (onLogout != null)
          IconButton(
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout, size: 18, color: AppColors.grey400),
            onPressed: onLogout,
          ),
      ],
    );
  }

  Widget _collapsedFooter() {
    if (onLogout == null) {
      return const CircleAvatar(radius: 16, backgroundColor: AppColors.grey100, child: Icon(Icons.person, size: 16, color: AppColors.grey500));
    }
    return Tooltip(
      message: 'Déconnexion',
      child: IconButton(
        icon: const Icon(Icons.logout, size: 18, color: AppColors.grey400),
        onPressed: onLogout,
      ),
    );
  }
}
