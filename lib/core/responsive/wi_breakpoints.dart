/// WorkIt Design System — Breakpoints responsive
///
/// Basés sur la largeur d'écran (jamais `kIsWeb`) : le même code sert le web
/// et le mobile natif, donc un téléphone et une fenêtre Chrome étroite
/// doivent produire le même layout.
library;

enum WiScreenSize {
  /// Téléphone portrait — layout mobile (bottom nav, listes, bottom sheets).
  compact,

  /// Tablette portrait / petit écran — layout mobile élargi, bottom nav
  /// conservée (ergonomie tactile terrain, tablette tenue à la main).
  medium,

  /// Tablette paysage / petit laptop — bascule vers sidebar réduite.
  expanded,

  /// Desktop / grand écran — sidebar étendue + contenu centré.
  large,
}

abstract class WiBreakpoints {
  static const double medium = 600;
  static const double expanded = 900;
  static const double large = 1200;

  static WiScreenSize of(double width) {
    if (width >= large) return WiScreenSize.large;
    if (width >= expanded) return WiScreenSize.expanded;
    if (width >= medium) return WiScreenSize.medium;
    return WiScreenSize.compact;
  }
}
