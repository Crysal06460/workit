import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Ligne de statistiques résumées (en-tête des écrans principaux)
///
/// Usage :
/// ```dart
/// WiStatRow(stats: [
///   WiStat(value: '4', label: 'En attente', color: AppColors.warning),
///   WiStat(value: '5', label: 'En cours',   color: AppColors.primary),
///   WiStat(value: '3', label: 'Terminés',   color: AppColors.success),
/// ])
/// ```
class WiStat {
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const WiStat({required this.value, required this.label, required this.color, this.onTap});
}

class WiStatRow extends StatelessWidget {
  final List<WiStat> stats;

  /// Sur desktop (>=900px), bascule d'un `Row` étiré (qui devient
  /// disproportionné sur grand écran) vers un `Wrap` de cartes à largeur
  /// fixe alignées à gauche. Défaut `false` = comportement mobile inchangé.
  final bool compactOnDesktop;

  const WiStatRow({super.key, required this.stats, this.compactOnDesktop = false});

  @override
  Widget build(BuildContext context) {
    if (compactOnDesktop && MediaQuery.sizeOf(context).width >= 900) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: stats
            .map((s) => SizedBox(width: 180, child: _StatCard(stat: s)))
            .toList(),
      );
    }
    // Au-delà de 3 pastilles, un Row étiré (Expanded) devient trop étroit
    // sur mobile (6 catégories) — bascule sur une rangée défilante à largeur
    // de carte fixe plutôt que de compresser illisiblement chaque carte.
    if (stats.length > 3) {
      // `clipBehavior: none` + un peu de marge sous la Row : par défaut
      // SingleChildScrollView clippe pile à la hauteur de son contenu, ce qui
      // rognait l'ombre portée des cartes (boxShadow) tout en bas.
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: stats
                .map((s) => SizedBox(width: 104, child: _StatCard(stat: s)))
                .expand((w) => [w, const SizedBox(width: 8)])
                .toList()
              ..removeLast(),
          ),
        ),
      );
    }
    return Row(
      children: stats
          .map((s) => Expanded(child: _StatCard(stat: s)))
          .expand((w) => [w, const SizedBox(width: 8)])
          .toList()
        ..removeLast(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final WiStat stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: stat.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              stat.value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: stat.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              stat.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.grey400,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
