import 'package:flutter/material.dart';
import '../../responsive/responsive_context.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout_tokens.dart';
import '../wi_bottom_nav.dart';
import 'wi_sidebar_nav.dart';

/// Shell responsive réutilisable par les écrans de rôle (Commercial, Métreur,
/// Poseur, Admin) : bascule automatiquement entre bottom nav mobile,
/// sidebar réduite (tablette paysage/petit laptop) et sidebar étendue
/// (desktop), sans que l'écran appelant ait à gérer cette logique.
///
/// Mobile/tablette (< 900px) : Scaffold classique avec `appBar` (fourni par
/// l'écran, inchangé) + bottom nav. Desktop (>= 900px) : sidebar à gauche +
/// top bar (`header`/`topBarActions`) + contenu centré sur `maxContentWidth`.
class WiAppShell extends StatelessWidget {
  final List<WiNavItem> navItems;
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final Widget body;

  /// AppBar de l'écran (titre, actions, éventuel `bottom` comme un TabBar) —
  /// rendu tel quel sur mobile (`Scaffold.appBar`, comportement inchangé) ET
  /// en haut de la zone de contenu sur desktop (hors sidebar), pour ne pas
  /// perdre de fonctionnalité (recherche, tabs...) en basculant de chrome.
  final PreferredSizeWidget? appBar;

  /// Contenu de la top bar desktop (titre, recherche...).
  final Widget? header;

  /// Actions de la top bar desktop (avatar, déconnexion...).
  final List<Widget>? topBarActions;

  final Color accentColor;
  final String? workspaceName;
  final String? userName;
  final VoidCallback? onLogout;

  const WiAppShell({
    super.key,
    required this.navItems,
    required this.currentIndex,
    required this.onNavTap,
    required this.body,
    this.appBar,
    this.header,
    this.topBarActions,
    this.accentColor = AppColors.primary,
    this.workspaceName,
    this.userName,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    if (!context.showSidebar) {
      return Scaffold(
        appBar: appBar,
        body: body,
        bottomNavigationBar: WiBottomNav(
          items: navItems,
          currentIndex: currentIndex,
          onTap: onNavTap,
          activeColor: accentColor,
        ),
      );
    }

    final sidebarExpanded = context.isSidebarExpanded;
    return Scaffold(
      body: Row(
        children: [
          WiSidebarNav(
            items: navItems,
            currentIndex: currentIndex,
            onTap: onNavTap,
            expanded: sidebarExpanded,
            accentColor: accentColor,
            workspaceName: workspaceName,
            userName: userName,
            onLogout: onLogout,
          ),
          Expanded(
            child: Column(
              children: [
                if (appBar != null) SizedBox(height: appBar!.preferredSize.height, child: appBar),
                if (header != null || (topBarActions?.isNotEmpty ?? false))
                  _DesktopTopBar(header: header, actions: topBarActions),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
                      child: body,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  final Widget? header;
  final List<Widget>? actions;

  const _DesktopTopBar({this.header, this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppLayout.desktopTopBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.grey200)),
      ),
      child: Row(
        children: [
          if (header != null) Expanded(child: header!),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}
