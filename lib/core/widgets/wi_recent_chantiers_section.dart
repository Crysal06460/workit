import 'package:flutter/material.dart';
import '../models/wi_devis_summary.dart';
import '../theme/app_colors.dart';

/// Section "chantiers récemment ajoutés" — bande horizontale défilante à
/// hauteur fixe (les items de démo + Firestore sont plafonnés à 6 par
/// `mergeRecentChantiers`, mais un empilement vertical complet ferait grimper
/// la hauteur jusqu'à ~600px et écraserait la liste principale en dessous,
/// qui elle n'a droit qu'à l'espace restant dans une Column non scrollable).
/// Distingue "Nouveau" (inclus via la date de création) de "Mis à jour"
/// (inclus via la date de mise à jour) pour que la réapparition d'un vieux
/// chantier soit compréhensible plutôt que déroutante.
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
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _RecentCard(item: items[i], isNew: _isNew(items[i])),
          ),
        ),
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.item, required this.isNew});

  final WiDevisSummary item;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 208,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: item.statusColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      item.statusLabel,
                      style: TextStyle(color: item.statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isNew ? 'Nouveau' : 'Mis à jour',
                  style: const TextStyle(color: AppColors.grey300, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.clientLabel,
                  style: const TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700, fontSize: 14),
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
          ],
        ),
      ),
    );
  }
}
