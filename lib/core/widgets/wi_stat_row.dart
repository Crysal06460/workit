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
  const WiStat({required this.value, required this.label, required this.color});
}

class WiStatRow extends StatelessWidget {
  final List<WiStat> stats;
  const WiStatRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
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
    return Container(
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
    );
  }
}
