// ============================================================
// lib/screens/admin_kpis_tab.dart
// Phase 6 — Tableau de bord dirigeant (KPIs). Lit l'unique document
// d'agrégats workspaces/{id}/stats/kpis (mis à jour incrémentalement par
// transitionDevisStatus, functions/kpiStats.js) pour les délais moyens et
// les taux de qualité ; calcule en direct (comme AdminDashboardTab le fait
// déjà pour ses propres compteurs) les chantiers bloqués et la charge par
// équipe, qui dépendent du temps qui passe plutôt que d'une écriture.
// ============================================================

import '../core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const int _kBlockedThresholdDays = 7;
const Set<String> _kTerminalStatuses = {'Terminé', 'Clôturé', 'SAV'};

class AdminKpisTab extends StatefulWidget {
  const AdminKpisTab({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  State<AdminKpisTab> createState() => _AdminKpisTabState();
}

class _AdminKpisTabState extends State<AdminKpisTab> {
  final _firestore = FirebaseFirestore.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> get _kpiStream => _firestore
      .collection('workspaces')
      .doc(widget.workspaceId)
      .collection('stats')
      .doc('kpis')
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _devisStream => _firestore
      .collection('workspaces')
      .doc(widget.workspaceId)
      .collection('devis')
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _teamsStream => _firestore
      .collection('workspaces')
      .doc(widget.workspaceId)
      .collection('planningTeams')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _kpiStream,
      builder: (context, kpiSnap) {
        final kpi = kpiSnap.data?.data() ?? const <String, dynamic>{};
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _devisStream,
          builder: (context, devisSnap) {
            final devisDocs = devisSnap.data?.docs ?? [];
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _teamsStream,
              builder: (context, teamsSnap) {
                final teamDocs = teamsSnap.data?.docs ?? [];
                return _KpiBody(kpi: kpi, devisDocs: devisDocs, teamDocs: teamDocs);
              },
            );
          },
        );
      },
    );
  }
}

class _KpiBody extends StatelessWidget {
  const _KpiBody({required this.kpi, required this.devisDocs, required this.teamDocs});

  final Map<String, dynamic> kpi;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> devisDocs;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> teamDocs;

  int _asInt(dynamic v) => v is num ? v.toInt() : 0;

  @override
  Widget build(BuildContext context) {
    final transitions = (kpi['transitions'] as Map<String, dynamic>? ?? {});
    final causes = (kpi['nonConformiteCauses'] as Map<String, dynamic>? ?? {});

    final premierPassage = _asInt(kpi['cloturesPremierPassage']);
    final apresRetour = _asInt(kpi['cloturesApresRetour']);
    final savCount = _asInt(kpi['savCount']);
    final paiementOk = _asInt(kpi['paiementEffectueCount']);
    final paiementKo = _asInt(kpi['paiementNonEffectueCount']);

    final blocked = _blockedChantiers(devisDocs);
    final teamLoads = _teamLoadsToday(devisDocs, teamDocs);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const Text(
          'Tableau de bord',
          style: TextStyle(color: AppColors.grey900, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'KPIs',
          style: TextStyle(color: AppColors.grey400, fontSize: 14),
        ),
        const SizedBox(height: 20),

        const _KpiSectionTitle(label: 'Délais moyens par transition'),
        const SizedBox(height: 10),
        if (transitions.isEmpty)
          const _EmptyNote(text: 'Pas encore assez de données.')
        else
          _DelaysCard(transitions: transitions),

        const SizedBox(height: 24),
        const _KpiSectionTitle(label: 'Qualité'),
        const SizedBox(height: 10),
        _RateCard(
          label: 'Clôture au premier passage',
          ok: premierPassage,
          total: premierPassage + apresRetour,
        ),
        const SizedBox(height: 10),
        _RateCard(
          label: 'Taux de SAV',
          ok: savCount,
          total: savCount + premierPassage + apresRetour,
          inverted: true,
        ),
        const SizedBox(height: 10),
        _RateCard(
          label: 'Paiement effectué à la clôture',
          ok: paiementOk,
          total: paiementOk + paiementKo,
        ),

        const SizedBox(height: 24),
        const _KpiSectionTitle(label: 'Causes de non-conformité'),
        const SizedBox(height: 10),
        if (causes.isEmpty)
          const _EmptyNote(text: 'Aucun problème signalé pour l\'instant.')
        else
          _CausesCard(causes: causes),

        const SizedBox(height: 24),
        _KpiSectionTitle(label: 'Chantiers bloqués (> $_kBlockedThresholdDays j)'),
        const SizedBox(height: 10),
        if (blocked.isEmpty)
          const _EmptyNote(text: 'Aucun chantier bloqué.')
        else
          _BlockedCard(items: blocked),

        const SizedBox(height: 24),
        const _KpiSectionTitle(label: 'Charge par équipe (aujourd\'hui)'),
        const SizedBox(height: 10),
        if (teamLoads.isEmpty)
          const _EmptyNote(text: 'Aucune équipe active.')
        else
          _TeamLoadCard(loads: teamLoads),
      ],
    );
  }

  List<_BlockedItem> _blockedChantiers(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final threshold = DateTime.now().subtract(const Duration(days: _kBlockedThresholdDays));
    final items = <_BlockedItem>[];
    for (final doc in docs) {
      final d = doc.data();
      final status = (d['status'] ?? d['metreurStatus'])?.toString() ?? '';
      if (status.isEmpty || _kTerminalStatuses.contains(status)) continue;
      final updatedAt = d['updatedAt'];
      if (updatedAt is! Timestamp) continue;
      final dt = updatedAt.toDate();
      if (dt.isAfter(threshold)) continue;
      items.add(_BlockedItem(
        client: d['client']?.toString() ?? 'Client',
        status: status,
        days: DateTime.now().difference(dt).inDays,
      ));
    }
    items.sort((a, b) => b.days.compareTo(a.days));
    return items;
  }

  List<_TeamLoad> _teamLoadsToday(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> devisDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> teamDocs,
  ) {
    final today = DateTime.now();
    bool isToday(DateTime? d) =>
        d != null && d.year == today.year && d.month == today.month && d.day == today.day;

    // Charge : parcourt chaque devis, et chacun de ses lots s'il en a
    // (dénormalisés dans lotsSummary, Phase 3/4) — sinon le devis lui-même.
    // Une unité programmée aujourd'hui compte pour poseurCountRequired sur
    // sa teamId, exactement comme _teamLoad dans planner_screen.dart.
    final loadByTeam = <String, int>{};
    for (final doc in devisDocs) {
      final d = doc.data();
      final lotsSummary =
          (d['lotsSummary'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
      final units = lotsSummary.isEmpty ? [d] : lotsSummary;
      for (final u in units) {
        final status = u['status']?.toString() ?? (d['status'] ?? d['metreurStatus'])?.toString();
        if (status != 'En pose') continue;
        final teamId = u['teamId']?.toString();
        if (teamId == null || teamId.isEmpty) continue;
        final poseDate = u['poseDate'];
        final dt = poseDate is Timestamp ? poseDate.toDate() : null;
        if (!isToday(dt)) continue;
        final count = (u['poseurCountRequired'] as num?)?.toInt() ?? 1;
        loadByTeam[teamId] = (loadByTeam[teamId] ?? 0) + count;
      }
    }

    final loads = <_TeamLoad>[];
    for (final team in teamDocs) {
      final t = team.data();
      if (t['active'] == false) continue;
      final memberIds = List<String>.from(t['memberIds'] as List? ?? const []);
      loads.add(_TeamLoad(
        name: t['name']?.toString() ?? 'Équipe',
        load: loadByTeam[team.id] ?? 0,
        capacity: memberIds.length,
      ));
    }
    return loads;
  }
}

// ────────────────────────────────────────────────
// Widgets de présentation
// ────────────────────────────────────────────────

class _KpiSectionTitle extends StatelessWidget {
  const _KpiSectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(color: AppColors.grey900, fontSize: 15, fontWeight: FontWeight.w800),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.grey400, fontSize: 13)),
    );
  }
}

String _fmtDuration(num totalMs, num count) {
  if (count <= 0) return '—';
  final avgMs = totalMs / count;
  final totalMinutes = (avgMs / 60000).round();
  final days = totalMinutes ~/ (60 * 24);
  final hours = (totalMinutes % (60 * 24)) ~/ 60;
  if (days > 0) return '${days}j ${hours}h';
  final minutes = totalMinutes % 60;
  if (hours > 0) return '${hours}h${minutes.toString().padLeft(2, '0')}';
  return '${minutes}min';
}

class _DelaysCard extends StatelessWidget {
  const _DelaysCard({required this.transitions});
  final Map<String, dynamic> transitions;

  @override
  Widget build(BuildContext context) {
    final entries = transitions.entries.where((e) => e.value is Map).toList()
      ..sort((a, b) {
        final ca = (a.value as Map)['count'] as num? ?? 0;
        final cb = (b.value as Map)['count'] as num? ?? 0;
        return cb.compareTo(ca);
      });
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.map((e) {
          final v = e.value as Map;
          final count = v['count'] as num? ?? 0;
          final totalMs = v['totalMs'] as num? ?? 0;
          final label = e.key.replaceAll('__', ' → ');
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: const TextStyle(color: AppColors.grey700, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(
                  '${_fmtDuration(totalMs, count)} · $count',
                  style: const TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.label,
    required this.ok,
    required this.total,
    this.inverted = false,
  });

  final String label;
  final int ok;
  final int total;
  // inverted : "ok" représente ici la part indésirable (ex. taux de SAV) —
  // la couleur s'inverse (rouge si élevé, plutôt que vert).
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : ok / total;
    final good = inverted ? ratio < 0.15 : ratio >= 0.8;
    final color = total == 0 ? AppColors.grey300 : (good ? AppColors.success : AppColors.warning);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(color: AppColors.grey700, fontSize: 13)),
              ),
              Text(
                total == 0 ? '—' : '${(ratio * 100).round()}% ($ok/$total)',
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : ratio,
              minHeight: 6,
              backgroundColor: AppColors.grey100,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _CausesCard extends StatelessWidget {
  const _CausesCard({required this.causes});
  final Map<String, dynamic> causes;

  @override
  Widget build(BuildContext context) {
    final entries = causes.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    final max = entries.isEmpty ? 1 : (entries.first.value as num);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.map((e) {
          final count = e.value as num;
          final ratio = max == 0 ? 0.0 : count / max;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(e.key,
                          style: const TextStyle(color: AppColors.grey700, fontSize: 13)),
                    ),
                    Text('$count',
                        style: const TextStyle(
                            color: AppColors.grey900, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                LayoutBuilder(
                  builder: (context, constraints) => Container(
                    height: 6,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: AppColors.grey100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: ratio.clamp(0.02, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BlockedItem {
  const _BlockedItem({required this.client, required this.status, required this.days});
  final String client;
  final String status;
  final int days;
}

class _BlockedCard extends StatelessWidget {
  const _BlockedCard({required this.items});
  final List<_BlockedItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((it) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Text('${it.client} — ${it.status}',
                      style: const TextStyle(color: AppColors.grey700, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
                Text('${it.days} j',
                    style: const TextStyle(
                        color: AppColors.danger, fontWeight: FontWeight.w800, fontSize: 13)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TeamLoad {
  const _TeamLoad({required this.name, required this.load, required this.capacity});
  final String name;
  final int load;
  final int capacity;
}

class _TeamLoadCard extends StatelessWidget {
  const _TeamLoadCard({required this.loads});
  final List<_TeamLoad> loads;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: loads.map((t) {
          final overloaded = t.load > t.capacity;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Text(t.name, style: const TextStyle(color: AppColors.grey700, fontSize: 13)),
                ),
                if (overloaded)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.danger),
                  ),
                Text(
                  '${t.load}/${t.capacity}',
                  style: TextStyle(
                    color: overloaded ? AppColors.danger : AppColors.grey900,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
