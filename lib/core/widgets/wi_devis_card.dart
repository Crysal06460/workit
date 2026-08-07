import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'wi_status_badge.dart';

/// Carte devis WorkIt — design system
///
/// Usage :
/// ```dart
/// WiDevisCard(
///   title: 'Rénovation cuisine',
///   subtitle: 'M. Dupont · Paris 15e',
///   status: DevisStatus.enAttente,
///   amount: '4 200 €',
///   meta: 'Il y a 2 jours',
///   stepCount: 5,
///   currentStep: 1,
///   primaryAction: WiCardAction(label: 'Relancer', onTap: () {}),
///   secondaryAction: WiCardAction(label: 'Voir détails', onTap: () {}),
/// )
/// ```
class WiCardAction {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isDanger;
  final IconData? icon;

  const WiCardAction({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.isDanger = false,
    this.icon,
  });
}

class WiDevisCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final DevisStatus status;
  final String? amount;
  final String? meta;
  final int? stepCount;
  final int? currentStep;
  final WiCardAction? primaryAction;
  final WiCardAction? secondaryAction;
  /// Couleur d'accentuation de la bordure gauche (rôle metteur/poseur)
  final Color? accentColor;
  /// Si true, affiche une bordure complète bleue (chantier actif poseur)
  final bool isActive;
  /// Rend toute la carte tapable (ouverture du détail) — en plus des
  /// éventuelles actions du footer.
  final VoidCallback? onTap;
  /// Remplace le badge de statut par défaut (`WiStatusBadge`) — utile quand
  /// le libellé affiché diverge du libellé générique de l'enum (ex: nom de
  /// la personne assignée, libellé métier spécifique à un écran).
  final Widget? trailingBadge;
  /// Petites actions icône additionnelles dans l'en-tête (ex: éditer/supprimer).
  final List<Widget>? headerActions;

  const WiDevisCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    this.amount,
    this.meta,
    this.stepCount,
    this.currentStep,
    this.primaryAction,
    this.secondaryAction,
    this.accentColor,
    this.isActive = false,
    this.onTap,
    this.trailingBadge,
    this.headerActions,
  });

  @override
  Widget build(BuildContext context) {
    final BorderSide leftBorder = accentColor != null
        ? BorderSide(color: accentColor!, width: 3)
        : BorderSide.none;

    final content = Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ───────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.grey900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.grey400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailingBadge ?? WiStatusBadge(status: status),
                if (headerActions != null) ...headerActions!,
              ],
            ),

            // ── Montant + méta ────────────────────────────
            if (amount != null || meta != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (amount != null)
                    Text(
                      amount!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.grey900,
                      ),
                    ),
                  const Spacer(),
                  if (meta != null)
                    Text(
                      meta!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.grey400,
                      ),
                    ),
                ],
              ),
            ],

            // ── Indicateur d'étapes ───────────────────────
            if (stepCount != null && currentStep != null) ...[
              const SizedBox(height: 10),
              _StepDots(total: stepCount!, current: currentStep!),
            ],

            // ── Boutons d'action ──────────────────────────
            if (primaryAction != null || secondaryAction != null) ...[
              const SizedBox(height: 11),
              const Divider(height: 1),
              const SizedBox(height: 11),
              Row(
                children: [
                  if (secondaryAction != null)
                    Expanded(child: _ActionBtn(action: secondaryAction!)),
                  if (secondaryAction != null && primaryAction != null)
                    const SizedBox(width: 8),
                  if (primaryAction != null)
                    Expanded(child: _ActionBtn(action: primaryAction!)),
                ],
              ),
            ],
          ],
        ),
      );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: AppColors.primary, width: 2)
            : accentColor != null
                ? Border(
                    left: leftBorder,
                    top: const BorderSide(color: AppColors.cardBorder),
                    right: const BorderSide(color: AppColors.cardBorder),
                    bottom: const BorderSide(color: AppColors.cardBorder),
                  )
                : Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: content,
              ),
            ),
    );
  }
}

// ── Step dots ─────────────────────────────────────────────
class _StepDots extends StatelessWidget {
  final int total;
  final int current;
  const _StepDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        Color color;
        if (i < current) {
          color = AppColors.success;
        } else if (i == current) {
          color = AppColors.primary;
        } else {
          color = AppColors.grey200;
        }
        return Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
      }),
    );
  }
}

// ── Bouton d'action ───────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final WiCardAction action;
  const _ActionBtn({required this.action});

  @override
  Widget build(BuildContext context) {
    if (action.isPrimary) {
      return ElevatedButton(
        onPressed: action.onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (action.icon != null) ...[
              Icon(action.icon, size: 14),
              const SizedBox(width: 4),
            ],
            Text(action.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    if (action.isDanger) {
      return TextButton(
        onPressed: action.onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.danger,
          backgroundColor: AppColors.dangerLight,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(action.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );
    }

    return OutlinedButton(
      onPressed: action.onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: AppColors.grey200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (action.icon != null) ...[
            Icon(action.icon, size: 14, color: AppColors.grey700),
            const SizedBox(width: 4),
          ],
          Text(action.label),
        ],
      ),
    );
  }
}
