import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_layout_tokens.dart';

/// Une colonne du board (généralement un statut) avec ses cartes déjà
/// construites par l'écran appelant (ex: `WiDevisCard`).
class WiKanbanColumn {
  final String id;
  final String label;
  final Color color;
  final List<Widget> cards;

  const WiKanbanColumn({
    required this.id,
    required this.label,
    required this.color,
    required this.cards,
  });
}

/// Vue pipeline en colonnes (desktop) — regroupe visuellement des éléments
/// par statut, façon Krafteo. **Lecture seule** : pas de drag-and-drop entre
/// colonnes dans cette version, le changement de statut passe par les
/// actions métier existantes (Valider/Retourner/SAV...), pas par un
/// déplacement libre de carte qui contournerait les règles serveur.
///
/// Chaque colonne scrolle indépendamment verticalement : le board doit donc
/// recevoir une hauteur bornée de son parent (l'envelopper dans `Expanded`).
class WiKanbanBoard extends StatelessWidget {
  final List<WiKanbanColumn> columns;

  const WiKanbanBoard({super.key, required this.columns});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: columns.map((c) => _KanbanColumnView(column: c)).toList(),
      ),
    );
  }
}

class _KanbanColumnView extends StatelessWidget {
  final WiKanbanColumn column;
  const _KanbanColumnView({required this.column});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppLayout.kanbanColumnWidth,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: column.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  column.label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.grey900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '${column.cards.length}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.grey600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: column.cards.isEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.grey50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.grey100),
                    ),
                    child: const Text('Aucun dossier', style: TextStyle(fontSize: 12, color: AppColors.grey400)),
                  )
                : ListView.separated(
                    itemCount: column.cards.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => column.cards[i],
                  ),
          ),
        ],
      ),
    );
  }
}
