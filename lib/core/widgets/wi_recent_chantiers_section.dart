import 'package:flutter/material.dart';
import '../models/wi_devis_summary.dart';
import '../theme/app_colors.dart';

/// Section "chantiers récemment ajoutés" — les derniers créés + ceux dont le
/// statut vient de changer (voir `mergeRecentChantiers`). Distingue "Nouveau"
/// (inclus via la date de création) de "Mis à jour" (inclus via la date de
/// mise à jour) pour que la réapparition d'un vieux chantier soit
/// compréhensible plutôt que déroutante.
class WiRecentChantiersSection extends StatelessWidget {
  const WiRecentChantiersSection({super.key, required this.title, required this.items});

  final String title;
  final List<WiDevisSummary> items;

  bool _isNew(WiDevisSummary item) {
    if (item.createdAt == null) return false;
    return DateTime.now().difference(item.createdAt!) <= const Duration(days: 1);
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: AppColors.grey900, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.clientLabel,
                            style: const TextStyle(
                              color: AppColors.grey900,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if ((item.address?.isNotEmpty ?? false)) ...[
                            const SizedBox(height: 3),
                            Text(
                              item.address!,
                              style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: item.statusColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            item.statusLabel,
                            style: TextStyle(color: item.statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isNew(item) ? 'Nouveau' : 'Mis à jour',
                          style: const TextStyle(color: AppColors.grey300, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
