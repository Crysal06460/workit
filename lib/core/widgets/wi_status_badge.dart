import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Statuts possibles d'un devis WorkIt
enum DevisStatus {
  enAttente,       // null / 'Nouvelle demande' / 'Acceptée' / 'À classer'
  metreProgramme,  // 'En cours'
  aCommander,      // 'À commander' / 'Commande en cours'
  aplanifier,      // 'À planifier'
  enPose,          // 'En pose'
  termine,         // 'À clôturer' / 'Terminé' / 'Clôturé'
  probleme,        // 'Problème chantier'
}

/// Convertit le status Firestore en [DevisStatus]
DevisStatus statusFromFirestore(String? s) {
  switch (s) {
    case 'En cours':           return DevisStatus.metreProgramme;
    case 'À commander':
    case 'Commande en cours':  return DevisStatus.aCommander;
    case 'À planifier':        return DevisStatus.aplanifier;
    case 'En pose':            return DevisStatus.enPose;
    case 'À clôturer':
    case 'Terminé':
    case 'Clôturé':            return DevisStatus.termine;
    case 'Problème chantier':  return DevisStatus.probleme;
    default:                   return DevisStatus.enAttente;
  }
}

class _BadgeStyle {
  final Color bg;
  final Color text;
  final String label;
  const _BadgeStyle(this.bg, this.text, this.label);
}

_BadgeStyle _styleFor(DevisStatus status) {
  switch (status) {
    case DevisStatus.enAttente:
      return const _BadgeStyle(AppColors.statusAttenteBg, AppColors.statusAttenteText, 'En attente');
    case DevisStatus.metreProgramme:
      return const _BadgeStyle(AppColors.statusProgBg, AppColors.statusProgText, 'Métré prog.');
    case DevisStatus.aCommander:
      return const _BadgeStyle(AppColors.statusOrderBg, AppColors.statusOrderText, 'À commander');
    case DevisStatus.aplanifier:
      return const _BadgeStyle(AppColors.statusPlanBg, AppColors.statusPlanText, 'À planifier');
    case DevisStatus.enPose:
      // Libellé "Programmé" plutôt que "En pose" : le statut serveur passe à
      // 'En pose' dès qu'une équipe/date sont posées dans l'agenda, pas
      // seulement au moment réel de la pose — "En pose" prêtait à confusion.
      return const _BadgeStyle(AppColors.statusPoseBg, AppColors.statusPoseText, 'Programmé');
    case DevisStatus.termine:
      return const _BadgeStyle(AppColors.statusDoneBg, AppColors.statusDoneText, 'Terminé');
    case DevisStatus.probleme:
      return const _BadgeStyle(AppColors.statusProblemBg, AppColors.statusProblemText, 'Problème');
  }
}

/// Badge de statut coloré — ex : [WiStatusBadge(status: DevisStatus.enAttente)]
class WiStatusBadge extends StatelessWidget {
  final DevisStatus status;

  /// Affiche directement depuis la chaîne Firestore
  factory WiStatusBadge.fromString(String? firestoreStatus) =>
      WiStatusBadge(status: statusFromFirestore(firestoreStatus));

  const WiStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = _styleFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        s.label,
        style: TextStyle(
          color: s.text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Retourne la couleur de la bordure gauche d'urgence selon le statut
Color urgencyBorderColor(DevisStatus status) {
  switch (status) {
    case DevisStatus.enAttente:      return AppColors.warning;
    case DevisStatus.metreProgramme: return AppColors.purple;
    case DevisStatus.aCommander:     return AppColors.amber;
    case DevisStatus.aplanifier:     return AppColors.primary;
    case DevisStatus.enPose:         return AppColors.success;
    case DevisStatus.termine:        return AppColors.grey300;
    case DevisStatus.probleme:       return AppColors.danger;
  }
}
