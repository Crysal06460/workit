/// WorkIt Design System — Tokens de layout desktop
///
/// Additif au design system mobile existant : ces valeurs ne sont
/// consommées que par les composants desktop (shell, master-detail,
/// Kanban, dialogs adaptatifs) et n'ont aucun effet sur le layout mobile.
abstract class AppLayout {
  static const double maxContentWidth = 1280;
  static const double sidebarWidthExpanded = 240;
  static const double sidebarWidthCollapsed = 72;
  static const double masterPaneWidth = 400;
  static const double dialogWidthForm = 640;
  static const double kanbanColumnWidth = 300;
  static const double desktopTopBarHeight = 64;
}
