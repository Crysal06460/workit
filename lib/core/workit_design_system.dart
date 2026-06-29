/// WorkIt Design System — import unique
///
/// Ajoutez ceci en haut de vos écrans :
/// ```dart
/// import 'package:workit/core/workit_design_system.dart';
/// ```
///
/// Vous aurez accès à :
///   - AppColors        → toutes les couleurs
///   - AppTheme         → thème Material 3
///   - WiDevisCard      → carte devis avec statut, montant, actions
///   - WiStatusBadge    → badge coloré (En attente, En pose, etc.)
///   - WiStatRow        → ligne de 2-3 stats résumées
///   - WiFilterPills    → filtres scrollables en pills
///   - WiCtaButton      → bouton CTA pleine largeur
///   - WiBottomNav      → barre de navigation bas d'écran
///   - DevisStatus      → enum des statuts
///   - statusFromFirestore() → convertit string Firestore → DevisStatus
///   - WiCardAction     → action d'une carte (label + callback)
///   - WiNavItem        → item de la bottom nav
///   - WiStat           → item de stat

export 'theme/app_colors.dart';
export 'theme/app_theme.dart';
export 'widgets/wi_status_badge.dart';
export 'widgets/wi_devis_card.dart';
export 'widgets/wi_stat_row.dart';
export 'widgets/wi_filter_pills.dart';
export 'widgets/wi_cta_button.dart';
export 'widgets/wi_bottom_nav.dart';
