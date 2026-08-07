import 'package:flutter/widgets.dart';
import 'wi_breakpoints.dart';

/// Extension `BuildContext` pour les décisions de **chrome d'écran global**
/// (nav mobile vs sidebar, Kanban vs liste...).
///
/// Pour un composant imbriqué dont la largeur disponible dépend d'un parent
/// (ex. nombre de colonnes dans un panneau détail), utiliser `LayoutBuilder`
/// localement plutôt que cette extension.
extension WiResponsiveContext on BuildContext {
  WiScreenSize get screenSize => WiBreakpoints.of(MediaQuery.sizeOf(this).width);

  bool get isMobile =>
      screenSize == WiScreenSize.compact || screenSize == WiScreenSize.medium;

  bool get isDesktop =>
      screenSize == WiScreenSize.expanded || screenSize == WiScreenSize.large;

  bool get showSidebar => isDesktop;

  bool get isSidebarExpanded => screenSize == WiScreenSize.large;
}
