part of 'commercial_home_screen.dart';

// ─── Agenda Commercial (lecture seule) ──────────────────────────────────────
//
// Remplace l'ancien PlannerScreen complet (grille équipes × jours + sélecteur
// d'équipe + glisser-déposer) : un commercial n'a pas besoin de composer les
// équipes ni de choisir laquelle regarder, juste de voir SES chantiers déjà
// planifiés, triés par date, avec le détail (équipe, date) au tap. La
// planification elle-même reste réservée au métreur/admin (Planner complet).

class CommercialAgendaScreen extends StatelessWidget {
  const CommercialAgendaScreen({super.key, required this.workspaceId, required this.uid});

  final String workspaceId;
  final String uid;

  String _fmtDate(DateTime dt) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final day = days[(dt.weekday - 1).clamp(0, 6)];
    return '$day ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} à '
        '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
  }

  // Toutes les dates d'un chantier étalé sur plusieurs jours, pas seulement
  // la première — sinon un chantier 18→20/08 s'affichait comme "18/08"
  // uniquement, aucune trace du 20/08 nulle part côté Commercial.
  String _fmtDates(List<DateTime> dates) {
    if (dates.isEmpty) return 'Date à confirmer';
    final sorted = [...dates]..sort();
    if (sorted.length == 1) return _fmtDate(sorted.first);
    String short(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return '${sorted.map(short).join(', ')} (${sorted.length}j)';
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Agenda', style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: AppColors.grey600),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: firestore
              .collection('workspaces')
              .doc(workspaceId)
              .collection('planningTeams')
              .snapshots(),
          builder: (context, teamsSnap) {
            final teamNames = <String, String>{
              for (final d in teamsSnap.data?.docs ?? const <QueryDocumentSnapshot>[])
                d.id: ((d.data() as Map<String, dynamic>)['name']?.toString() ?? 'Équipe'),
            };
            return StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('workspaces')
                  .doc(workspaceId)
                  .collection('devis')
                  .where('userId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                final entries = <_CommercialAgendaEntry>[];
                for (final doc in snap.data?.docs ?? const <QueryDocumentSnapshot>[]) {
                  final raw = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
                  raw['id'] = doc.id;
                  final item = _QuoteItem.fromMap(raw);
                  entries.addAll(_CommercialAgendaEntry.fromQuoteItem(item, teamNames));
                }
                entries.sort((a, b) {
                  if (a.poseDate == null && b.poseDate == null) return 0;
                  if (a.poseDate == null) return 1;
                  if (b.poseDate == null) return -1;
                  return a.poseDate!.compareTo(b.poseDate!);
                });
                if (entries.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Aucune pose planifiée pour le moment.',
                        style: TextStyle(color: AppColors.grey400),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final entry = entries[i];
                    return WiDevisCard(
                      title: entry.item.client,
                      subtitle: entry.item.address,
                      status: statusFromFirestore(entry.item.status),
                      meta: _fmtDates(entry.dates),
                      trailingBadge: _quoteBadge(entry.teamLabel, AppColors.roleCommercial),
                      devisId: entry.item.id,
                      workspaceId: workspaceId,
                      onTap: () => _showChantierDetail(context, entry.item, workspaceId),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CommercialAgendaEntry {
  const _CommercialAgendaEntry({
    required this.item,
    required this.poseDate,
    required this.dates,
    required this.teamLabel,
  });

  final _QuoteItem item;
  final DateTime? poseDate;
  // Tous les jours planifiés (voir scheduledDates) — poseDate reste utilisé
  // seul pour le tri de la liste, mais l'affichage montre `dates` en entier.
  final List<DateTime> dates;
  final String teamLabel;

  static const _scheduledStatuses = {'En pose', 'À clôturer'};

  // Un devis multi-lots planifie chaque lot séparément (équipe/date propres à
  // chaque métier) — voir _PlanUnit.fromDevisDoc dans planner_screen.dart,
  // même logique de repli lots/top-level reproduite ici pour l'affichage.
  static List<_CommercialAgendaEntry> fromQuoteItem(_QuoteItem item, Map<String, String> teamNames) {
    if (item.lotsSummary.isEmpty) {
      if (!_scheduledStatuses.contains(item.status)) return const [];
      final dates = item.scheduledDates.isNotEmpty
          ? item.scheduledDates
          : (item.poseDate != null ? [item.poseDate!] : const <DateTime>[]);
      return [
        _CommercialAgendaEntry(
          item: item,
          poseDate: item.poseDate,
          dates: dates,
          teamLabel: item.poseurNames?.isNotEmpty == true ? item.poseurNames! : 'Équipe à confirmer',
        ),
      ];
    }
    return item.lotsSummary
        .where((l) => _scheduledStatuses.contains(l['status']?.toString()))
        .map((l) {
      final teamId = l['teamId']?.toString();
      final poseDate = l['poseDate'] is Timestamp ? (l['poseDate'] as Timestamp).toDate() : null;
      final lotDates = (l['scheduledDates'] as List<dynamic>? ?? [])
          .whereType<Timestamp>()
          .map((t) => t.toDate())
          .toList();
      final dates = lotDates.isNotEmpty ? lotDates : (poseDate != null ? [poseDate] : const <DateTime>[]);
      final poseurNames = l['poseurNames']?.toString();
      final teamLabel = (teamId != null && teamNames.containsKey(teamId))
          ? teamNames[teamId]!
          : (poseurNames?.isNotEmpty == true ? poseurNames! : 'Équipe à confirmer');
      return _CommercialAgendaEntry(item: item, poseDate: poseDate, dates: dates, teamLabel: teamLabel);
    }).toList();
  }
}
