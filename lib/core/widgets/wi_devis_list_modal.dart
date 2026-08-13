import 'package:flutter/material.dart';
import '../models/wi_devis_summary.dart';
import '../theme/app_colors.dart';
import 'wi_responsive_dialog.dart';

/// Popup listant des chantiers filtrés (ex. tous ceux comptés par une
/// pastille de statistique), chaque ligne rouvrant le détail complet déjà
/// existant de l'écran appelant via `item.onTap` — pas de nouvelle UI de
/// détail construite ici.
class WiDevisListModal extends StatelessWidget {
  const WiDevisListModal({super.key, required this.title, required this.items});

  final String title;
  final List<WiDevisSummary> items;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<WiDevisSummary> items,
  }) {
    return showWiAdaptiveModal(
      context,
      width: 480,
      builder: (_) => WiDevisListModal(title: title, items: items),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.grey900,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.grey400),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.cardBorder),
            Flexible(
              child: items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Aucun chantier',
                        style: TextStyle(color: AppColors.grey400),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.cardBorder),
                      itemBuilder: (_, i) {
                        final item = items[i];
                        return ListTile(
                          onTap: () {
                            Navigator.of(context).pop();
                            item.onTap();
                          },
                          title: Text(
                            item.clientLabel,
                            style: const TextStyle(
                              color: AppColors.grey900,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: (item.address?.isNotEmpty ?? false)
                              ? Text(
                                  item.address!,
                                  style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: item.statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: item.statusColor.withOpacity(0.4)),
                            ),
                            child: Text(
                              item.statusLabel,
                              style: TextStyle(
                                color: item.statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
