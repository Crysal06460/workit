import '../models/wi_devis_summary.dart';

/// Fusionne, pour la section "chantiers récemment ajoutés" de chaque écran
/// d'accueil : les [maxNew] plus récents par date de création, et ceux dont
/// le statut a changé dans la fenêtre [recentWindow] (par défaut 7 jours) —
/// un chantier ancien réapparaît donc dès que son statut bouge. Résultat
/// dédupliqué par id, trié par date la plus récente (création ou mise à
/// jour), plafonné à [maxTotal] éléments.
List<WiDevisSummary> mergeRecentChantiers(
  List<WiDevisSummary> items, {
  int maxNew = 3,
  int maxTotal = 6,
  Duration recentWindow = const Duration(days: 7),
}) {
  final now = DateTime.now();
  final byCreatedAt = [...items]
    ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  final recentlyCreated = byCreatedAt.take(maxNew);

  final recentlyUpdated = items.where((i) {
    if (i.updatedAt == null) return false;
    return now.difference(i.updatedAt!) <= recentWindow;
  });

  final merged = <String, WiDevisSummary>{};
  for (final item in [...recentlyCreated, ...recentlyUpdated]) {
    merged[item.id] = item;
  }

  final result = merged.values.toList()
    ..sort((a, b) {
      final aDate = _latest(a.createdAt, a.updatedAt);
      final bDate = _latest(b.createdAt, b.updatedAt);
      return bDate.compareTo(aDate);
    });

  return result.take(maxTotal).toList();
}

DateTime _latest(DateTime? a, DateTime? b) {
  if (a == null) return b ?? DateTime(0);
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}
