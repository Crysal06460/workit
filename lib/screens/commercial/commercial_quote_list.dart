part of 'commercial_home_screen.dart';

/// 0=Nouvelle demande  1=En cours  2=À commander  3=À planifier/En pose  4=Terminé
int _quoteStepIndex(String? s) {
  if (s == null || s == 'Nouvelle demande' || s == 'Acceptée' || s == 'À classer'
      || s == 'En attente') return 0;
  if (s == 'En cours' || s == 'Devis prog.' || s == 'Métré programmé') return 1;
  if (s == 'À commander' || s == 'Commande en cours') return 2;
  if (s == 'À planifier' || s == 'En pose' || s == 'Chantier à planifier') return 3;
  return 4;
}

String _quoteDefaultAction(String? s) {
  if (s == null || s == 'Nouvelle demande') return 'Relancer';
  if (s == 'En cours') return 'Rappel';
  if (s == 'À commander' || s == 'Commande en cours') return 'Commander';
  if (s == 'À planifier') return 'Planifier';
  if (s == 'En pose') return 'Suivi';
  return 'Voir';
}

/// Badge avec libellé/couleur personnalisés (préserve les libellés métier
/// existants, différents des libellés génériques de `WiStatusBadge`).
Widget _quoteBadge(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

/// Passer réellement la commande (transition À commander/Commande en cours
/// → À planifier) — réservé au métreur/admin côté serveur, sauf délégation
/// explicite `canPlaceOrders` accordée par un admin à ce commercial.
Future<void> _placeOrder(BuildContext context, String workspaceId, _QuoteItem item) async {
  if (item.id == null) return; // item de démo, rien de réel à commander
  try {
    await DevisService.updateStatus(
      workspaceId: workspaceId,
      devisId: item.id!,
      newStatus: 'À planifier',
      extraFields: const {'updated': 'Pose à programmer'},
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Commande confirmée pour ${item.client}.'), behavior: SnackBarBehavior.floating),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red),
      );
    }
  }
}

/// Relance manuelle (notification, pas une transition de statut) — voir
/// DevisService.sendRelance / functions/relanceConfig.js. L'erreur serveur
/// (ex. cooldown anti-spam pas écoulé) est affichée telle quelle.
Future<void> _sendRelance(
  BuildContext context,
  String workspaceId,
  _QuoteItem item,
  String relanceType,
) async {
  if (item.id == null) return; // item de démo, rien de réel à relancer
  try {
    await DevisService.sendRelance(
      workspaceId: workspaceId,
      devisId: item.id!,
      relanceType: relanceType,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Relance envoyée pour ${item.client}.'), behavior: SnackBarBehavior.floating),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red),
      );
    }
  }
}

/// Construit une `WiDevisCard` à partir d'un `_QuoteItem`, en reproduisant le
/// comportement de l'ancienne `_QuoteCard` (badge/étapes/actions par statut).
///
/// `canPlaceOrders` : par défaut (false), un commercial n'a pas de CTA
/// "Commander" sur les statuts À commander/Commande en cours — action
/// réservée au métreur/admin — seul "Voir détails" reste. Si un admin a
/// délégué ce droit, le CTA réapparaît et déclenche la vraie transition.
WiDevisCard _quoteCardFor(
  BuildContext context,
  _QuoteItem item, {
  required String meta,
  required Widget badge,
  required VoidCallback onTap,
  required String workspaceId,
  bool canPlaceOrders = false,
  List<Widget>? headerActions,
}) {
  final step = _quoteStepIndex(item.status);
  final isDone = step == 4;
  final isOrderStatus = item.status == 'À commander' || item.status == 'Commande en cours';
  // Statuts où le chantier attend une action du métreur (acceptation ou
  // rendez-vous de métré) — c'est là que "Relancer"/"Rappel" a du sens.
  final isAwaitingMetreur = item.status == null || item.status == 'Nouvelle demande' || item.status == 'En cours';

  WiCardAction? primaryAction;
  if (!isDone) {
    if (isOrderStatus && canPlaceOrders) {
      primaryAction = WiCardAction(
        label: 'Commander →',
        isPrimary: true,
        onTap: () => _placeOrder(context, workspaceId, item),
      );
    } else if (isOrderStatus) {
      // !canPlaceOrders : pas de CTA de commande (le commercial n'a pas le
      // droit), mais il peut relancer le métreur/admin qui doit la passer.
      if (item.id != null) {
        primaryAction = WiCardAction(
          label: 'Relancer →',
          onTap: () => _sendRelance(context, workspaceId, item, 'metreur_commande_attente'),
        );
      }
    } else if (isAwaitingMetreur && item.id != null) {
      // Le bouton portait déjà le libellé "Relancer"/"Rappel" mais ouvrait
      // seulement le détail (bug) — il déclenche maintenant la vraie relance.
      primaryAction = WiCardAction(
        label: '${_quoteDefaultAction(item.status)} →',
        isPrimary: true,
        onTap: () => _sendRelance(context, workspaceId, item, 'metreur_non_accepte'),
      );
    } else {
      primaryAction = WiCardAction(label: '${_quoteDefaultAction(item.status)} →', onTap: onTap, isPrimary: true);
    }
  }

  return WiDevisCard(
    title: item.client,
    subtitle: item.address,
    status: statusFromFirestore(item.status),
    meta: meta,
    trailingBadge: badge,
    headerActions: headerActions,
    stepCount: isDone ? null : 5,
    currentStep: isDone ? null : step,
    onTap: onTap,
    secondaryAction: isDone ? null : WiCardAction(label: 'Voir détails', onTap: onTap),
    primaryAction: primaryAction,
  );
}

class _NewQuotesList extends StatelessWidget {
  const _NewQuotesList({
    required this.items,
    required this.workspaceId,
    required this.onDelete,
    required this.onEdit,
  });
  final List<_QuoteItem> items;
  final String workspaceId;
  final ValueChanged<_QuoteItem> onDelete;
  final ValueChanged<_QuoteItem> onEdit;

  @override
  Widget build(BuildContext context) {
    final demoNew = _kDemoDevis.where((d) => d.status == null || d.status == 'Nouvelle demande').toList();
    final allItems = [...demoNew, ...items];
    if (allItems.isEmpty) {
      return const Center(child: Text("Aucun devis en attente", style: TextStyle(color: AppColors.grey400)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allItems.length,
      itemBuilder: (_, index) {
        final item = allItems[index];
        return _quoteCardFor(
          context,
          item,
          workspaceId: workspaceId,
          meta: item.date,
          badge: _quoteBadge('En attente', AppColors.warning),
          onTap: () => _showChantierDetail(context, item, workspaceId),
          headerActions: [
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.grey400), onPressed: () => onEdit(item), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
            IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.grey400), onPressed: () => onDelete(item), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
          ],
        );
      },
    );
  }
}

class _MeasuringList extends StatelessWidget {
  const _MeasuringList({required this.items, required this.workspaceId});
  final List<_QuoteItem> items;
  final String workspaceId;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text("Aucun métré en cours", style: TextStyle(color: AppColors.grey400)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, index) {
        final item = items[index];
        return _quoteCardFor(
          context,
          item,
          workspaceId: workspaceId,
          meta: item.status ?? 'En cours',
          badge: _quoteBadge(item.assignedMetreurName ?? 'Non attribué', Colors.lightBlueAccent),
          onTap: () => _showChantierDetail(context, item, workspaceId),
        );
      },
    );
  }
}

class _ScheduledList extends StatelessWidget {
  const _ScheduledList({required this.items, required this.workspaceId});
  final List<_QuoteItem> items;
  final String workspaceId;

  String _fmtDate(DateTime dt) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final day = days[(dt.weekday - 1).clamp(0, 6)];
    return '$day ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} à ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final demoScheduled = _kDemoDevis.where((d) => d.status == 'En cours').toList();
    final allItems = [...demoScheduled, ...items];
    if (allItems.isEmpty) {
      return const Center(
        child: Text('Aucun métré programmé', style: TextStyle(color: AppColors.grey400)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allItems.length,
      itemBuilder: (_, index) {
        final item = allItems[index];
        final rdv = item.meetingAt != null ? _fmtDate(item.meetingAt!) : '';
        return _quoteCardFor(
          context,
          item,
          workspaceId: workspaceId,
          meta: rdv.isNotEmpty ? '📅 RDV le $rdv' : 'Métré programmé',
          badge: _quoteBadge('Devis prog.', AppColors.purple),
          onTap: () => _showChantierDetail(context, item, workspaceId),
        );
      },
    );
  }
}

class _ValidatedList extends StatelessWidget {
  const _ValidatedList({required this.items, required this.workspaceId, this.canPlaceOrders = false});
  final List<_QuoteItem> items;
  final String workspaceId;
  final bool canPlaceOrders;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text("Aucune donnée pour l'instant", style: TextStyle(color: AppColors.grey400)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, index) {
        final item = items[index];
        final badgeColor = item.status == 'Commande en cours' ? AppColors.amber
            : item.status == 'À commander' ? AppColors.warning
            : item.status == 'À planifier' ? AppColors.primary
            : item.status == 'En pose' ? AppColors.success
            // Phase 5 : rapport soumis, en attente de validation.
            : item.status == 'À clôturer' ? Colors.orangeAccent
            : item.status == 'SAV' ? Colors.deepOrangeAccent
            : item.status == 'Terminé' || item.status == 'Clôturé' ? AppColors.grey500
            : _commercialAccent;
        return _quoteCardFor(
          context,
          item,
          workspaceId: workspaceId,
          canPlaceOrders: canPlaceOrders,
          meta: item.poseDate != null
              ? '📅 Pose le ${item.poseDate!.day}/${item.poseDate!.month}'
              : '${item.number} • ${item.date}',
          badge: _quoteBadge(
            item.status == 'À clôturer' ? 'À valider' : (item.status ?? item.tag),
            badgeColor,
          ),
          onTap: () => _showChantierDetail(context, item, workspaceId),
        );
      },
    );
  }
}

/// Tab "Tous" — affiche toutes les affaires sans filtre
class _AllItemsList extends StatelessWidget {
  const _AllItemsList({required this.items, required this.workspaceId, this.canPlaceOrders = false});
  final List<_QuoteItem> items;
  final String workspaceId;
  final bool canPlaceOrders;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Aucune affaire', style: TextStyle(color: AppColors.grey400)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        Color badgeColor;
        String badge;
        switch (item.status) {
          case null:
          case 'Nouvelle demande':
          case 'Acceptée':
            badge = 'En attente'; badgeColor = AppColors.warning; break;
          case 'En cours':
            badge = 'Devis prog.'; badgeColor = AppColors.purple; break;
          case 'À commander':
          case 'Commande en cours':
            badge = item.status!; badgeColor = AppColors.amber; break;
          case 'À planifier':
            badge = 'À planifier'; badgeColor = AppColors.primary; break;
          case 'En pose':
            badge = 'En pose'; badgeColor = AppColors.success; break;
          case 'Terminé':
          case 'Clôturé':
            badge = 'Terminé'; badgeColor = AppColors.grey500; break;
          // Phase 5 : rapport soumis, en attente de validation.
          case 'À clôturer':
            badge = 'À valider'; badgeColor = Colors.orangeAccent; break;
          case 'SAV':
            badge = 'SAV'; badgeColor = Colors.deepOrangeAccent; break;
          default:
            badge = item.status ?? ''; badgeColor = AppColors.grey400;
        }
        return _quoteCardFor(
          context,
          item,
          workspaceId: workspaceId,
          canPlaceOrders: canPlaceOrders,
          meta: item.date,
          badge: _quoteBadge(badge, badgeColor),
          onTap: () => _showChantierDetail(context, item, workspaceId),
        );
      },
    );
  }
}
