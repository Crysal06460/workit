// ============================================================
// lib/screens/planner_screen.dart
// Planner de planification — colonnes équipes, lignes jour/semaine,
// drag-and-drop, capacité, surcharge. Partagé Admin + Métreur.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/devis_service.dart';

const List<String> _kBacklogStatuses = ['À commander', 'Commande en cours', 'À planifier'];
const double _kDayLabelWidth = 88;
const double _kTeamColumnWidth = 220;
const double _kBacklogWidth = 260;

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
DateTime _startOfWeek(DateTime d) {
  final start = _startOfDay(d);
  return start.subtract(Duration(days: start.weekday - 1));
}
String _twoDigits(int n) => n.toString().padLeft(2, '0');
String _formatShortDate(DateTime d) => '${_twoDigits(d.day)}/${_twoDigits(d.month)}';
const _kWeekdayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, required this.workspaceId, required this.accentColor});
  final String workspaceId;
  final Color accentColor;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final _firestore = FirebaseFirestore.instance;

  bool _weekMode = false;
  DateTime _anchor = _startOfWeek(DateTime.now());

  List<DateTime> get _visibleDates {
    if (_weekMode) {
      return List.generate(4, (i) => _anchor.add(Duration(days: i * 7)));
    }
    return List.generate(7, (i) => _anchor.add(Duration(days: i)));
  }

  void _shiftAnchor(int direction) {
    final step = _weekMode ? 28 : 7;
    setState(() => _anchor = _anchor.add(Duration(days: direction * step)));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _teamsStream => _firestore
      .collection('workspaces')
      .doc(widget.workspaceId)
      .collection('planningTeams')
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _usersStream => _firestore
      .collection('users')
      .where('workspaceId', isEqualTo: widget.workspaceId)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _devisStream => _firestore
      .collection('workspaces')
      .doc(widget.workspaceId)
      .collection('devis')
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _unavailStream => _firestore
      .collection('workspaces')
      .doc(widget.workspaceId)
      .collection('unavailabilities')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _teamsStream,
      builder: (context, teamsSnap) {
        final teams = (teamsSnap.data?.docs ?? [])
            .map(_PlanningTeam.fromDoc)
            .where((t) => t.active)
            .toList();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _usersStream,
          builder: (context, usersSnap) {
            final poseurs = (usersSnap.data?.docs ?? [])
                .map(_PoseurOption.fromDoc)
                .where((p) => p.role == 'poseur')
                .toList();
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _unavailStream,
              builder: (context, unavailSnap) {
                final unavailabilities = (unavailSnap.data?.docs ?? [])
                    .map(_Unavailability.fromDoc)
                    .whereType<_Unavailability>()
                    .toList();
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _devisStream,
                  builder: (context, devisSnap) {
                    if (!teamsSnap.hasData || !usersSnap.hasData || !devisSnap.hasData) {
                      return Center(
                        child: CircularProgressIndicator(color: widget.accentColor),
                      );
                    }
                    final all =
                        (devisSnap.data?.docs ?? []).map(_ChantierPlan.fromDoc).toList();
                    final backlog =
                        all.where((c) => _kBacklogStatuses.contains(c.status)).toList();
                    final scheduled = all.where((c) => c.status == 'En pose').toList();
                    return _PlannerBody(
                      workspaceId: widget.workspaceId,
                      accentColor: widget.accentColor,
                      teams: teams,
                      poseurs: poseurs,
                      unavailabilities: unavailabilities,
                      backlog: backlog,
                      scheduled: scheduled,
                      weekMode: _weekMode,
                      visibleDates: _visibleDates,
                      onToggleWeekMode: (v) => setState(() => _weekMode = v),
                      onShiftAnchor: _shiftAnchor,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ────────────────────────────────────────────────
// MODÈLES
// ────────────────────────────────────────────────

class _PlanningTeam {
  const _PlanningTeam({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.active,
  });
  final String id;
  final String name;
  final List<String> memberIds;
  final bool active;

  static _PlanningTeam fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return _PlanningTeam(
      id: doc.id,
      name: d['name']?.toString() ?? 'Équipe',
      memberIds: List<String>.from(d['memberIds'] as List? ?? const []),
      active: d['active'] != false,
    );
  }
}

class _PoseurOption {
  const _PoseurOption({
    required this.id,
    required this.name,
    required this.role,
    required this.active,
  });
  final String id;
  final String name;
  final String role;
  final bool active;

  static _PoseurOption fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final name = '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim();
    return _PoseurOption(
      id: doc.id,
      name: name.isEmpty ? (d['email']?.toString() ?? doc.id) : name,
      role: d['role']?.toString() ?? '',
      active: d['status']?.toString() != 'disabled',
    );
  }
}

class _Unavailability {
  const _Unavailability({required this.poseurId, required this.start, required this.end});
  final String poseurId;
  final DateTime start;
  final DateTime end;

  bool covers(DateTime day) {
    final d = _startOfDay(day);
    return !d.isBefore(_startOfDay(start)) && !d.isAfter(_startOfDay(end));
  }

  static _Unavailability? fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final start = d['startDate'];
    final end = d['endDate'];
    if (start is! Timestamp || end is! Timestamp) return null;
    return _Unavailability(
      poseurId: d['poseurId']?.toString() ?? '',
      start: start.toDate(),
      end: end.toDate(),
    );
  }
}

class _ChantierPlan {
  const _ChantierPlan({
    required this.id,
    required this.client,
    required this.address,
    required this.status,
    this.teamId,
    this.poseDate,
    this.estimatedDurationDays = 1,
    this.poseurCountRequired = 1,
    this.supplierDeliveryDate,
    this.clientDesiredDate,
  });

  final String id;
  final String client;
  final String address;
  final String status;
  final String? teamId;
  final DateTime? poseDate;
  final int estimatedDurationDays;
  final int poseurCountRequired;
  final DateTime? supplierDeliveryDate;
  final DateTime? clientDesiredDate;

  bool get isReady {
    if (status != 'À planifier') return false;
    if (supplierDeliveryDate == null) return true;
    return !supplierDeliveryDate!.isAfter(DateTime.now());
  }

  List<DateTime> get occupiedDays {
    if (poseDate == null) return const [];
    final start = _startOfDay(poseDate!);
    final days = estimatedDurationDays < 1 ? 1 : (estimatedDurationDays > 60 ? 60 : estimatedDurationDays);
    return List.generate(days, (i) => start.add(Duration(days: i)));
  }

  bool touchesWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return occupiedDays.any((d) => !d.isBefore(weekStart) && !d.isAfter(weekEnd));
  }

  static DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

  static _ChantierPlan fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return _ChantierPlan(
      id: doc.id,
      client: d['client']?.toString() ?? 'Client',
      address: d['address']?.toString() ?? '',
      status: (d['status'] ?? d['metreurStatus'])?.toString() ?? '',
      teamId: d['teamId']?.toString(),
      poseDate: _ts(d['poseDate']),
      estimatedDurationDays: (d['estimatedDurationDays'] as num?)?.toInt() ?? 1,
      poseurCountRequired: (d['poseurCountRequired'] as num?)?.toInt() ?? 1,
      supplierDeliveryDate: _ts(d['supplierDeliveryDate']),
      clientDesiredDate: _ts(d['clientDesiredDate']),
    );
  }
}

// ────────────────────────────────────────────────
// CORPS PRINCIPAL (une fois les données chargées)
// ────────────────────────────────────────────────

class _PlannerBody extends StatelessWidget {
  const _PlannerBody({
    required this.workspaceId,
    required this.accentColor,
    required this.teams,
    required this.poseurs,
    required this.unavailabilities,
    required this.backlog,
    required this.scheduled,
    required this.weekMode,
    required this.visibleDates,
    required this.onToggleWeekMode,
    required this.onShiftAnchor,
  });

  final String workspaceId;
  final Color accentColor;
  final List<_PlanningTeam> teams;
  final List<_PoseurOption> poseurs;
  final List<_Unavailability> unavailabilities;
  final List<_ChantierPlan> backlog;
  final List<_ChantierPlan> scheduled;
  final bool weekMode;
  final List<DateTime> visibleDates;
  final ValueChanged<bool> onToggleWeekMode;
  final void Function(int direction) onShiftAnchor;

  _PoseurOption? _findPoseur(String uid) {
    for (final p in poseurs) {
      if (p.id == uid) return p;
    }
    return null;
  }

  int _teamCapacity(_PlanningTeam team, DateTime day) {
    return team.memberIds.where((uid) {
      final p = _findPoseur(uid);
      if (p == null || !p.active) return false;
      final unavailable = unavailabilities.any((u) => u.poseurId == uid && u.covers(day));
      return !unavailable;
    }).length;
  }

  int _teamLoad(_PlanningTeam team, DateTime day) {
    return scheduled
        .where((c) => c.teamId == team.id && c.occupiedDays.any((d) => _isSameDay(d, day)))
        .fold(0, (total, c) => total + c.poseurCountRequired);
  }

  int _overloadedCellCount() {
    var count = 0;
    for (final team in teams) {
      for (final day in visibleDates) {
        if (weekMode) continue;
        if (_teamLoad(team, day) > _teamCapacity(team, day)) count++;
      }
    }
    return count;
  }

  Future<void> _assignToCell(BuildContext context, String devisId, _PlanningTeam team, DateTime day) async {
    final names = team.memberIds.map((uid) => _findPoseur(uid)?.name ?? uid).join(', ');
    try {
      await DevisService.updateStatus(
        workspaceId: workspaceId,
        devisId: devisId,
        newStatus: 'En pose',
        extraFields: {
          'teamId': team.id,
          'poseDate': Timestamp.fromDate(day),
          'poseurIds': team.memberIds,
          'poseurNames': names,
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de planification : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final overloadCount = _overloadedCellCount();
    return Column(
      children: [
        _TopBar(
          accentColor: accentColor,
          weekMode: weekMode,
          onToggleWeekMode: onToggleWeekMode,
          onPrev: () => onShiftAnchor(-1),
          onNext: () => onShiftAnchor(1),
          onCreateTeam: () => _openTeamSheet(context, null),
        ),
        if (overloadCount > 0)
          Container(
            width: double.infinity,
            color: AppColors.dangerLight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '⚠️ $overloadCount créneau${overloadCount > 1 ? 'x' : ''} en surcharge sur la période affichée.',
              style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _kBacklogWidth,
                child: _BacklogPanel(workspaceId: workspaceId, backlog: backlog),
              ),
              const VerticalDivider(width: 1, color: AppColors.cardBorder),
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: _kDayLabelWidth + teams.length * _kTeamColumnWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderRow(context),
                          ...visibleDates.map((day) => weekMode
                              ? _buildWeekRow(context, day)
                              : _buildDayRow(context, day)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: _kDayLabelWidth, height: 64),
        ...teams.map((team) => SizedBox(
              width: _kTeamColumnWidth,
              height: 64,
              child: InkWell(
                onTap: () => _openTeamSheet(context, team),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        team.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.grey900, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${team.memberIds.length} poseur${team.memberIds.length > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 11, color: AppColors.grey500),
                      ),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildDayRow(BuildContext context, DateTime day) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _kDayLabelWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_kWeekdayLabels[day.weekday - 1],
                    style: const TextStyle(fontSize: 11, color: AppColors.grey500, fontWeight: FontWeight.w600)),
                Text(_formatShortDate(day),
                    style: const TextStyle(fontSize: 13, color: AppColors.grey900, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        ...teams.map((team) {
          final capacity = _teamCapacity(team, day);
          final load = _teamLoad(team, day);
          final overloaded = load > capacity;
          final dayChantiers = scheduled
              .where((c) => c.teamId == team.id && c.occupiedDays.any((d) => _isSameDay(d, day)))
              .toList();
          return SizedBox(
            width: _kTeamColumnWidth,
            child: DragTarget<String>(
              onWillAcceptWithDetails: (details) => true,
              onAcceptWithDetails: (details) => _assignToCell(context, details.data, team, day),
              builder: (context, candidateData, rejectedData) {
                final highlighted = candidateData.isNotEmpty;
                return Container(
                  margin: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minHeight: 84),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: highlighted
                        ? accentColor.withOpacity(0.12)
                        : (overloaded ? AppColors.dangerLight : AppColors.surface),
                    border: Border.all(
                      color: overloaded ? AppColors.danger : AppColors.cardBorder,
                      width: overloaded ? 1.4 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (overloaded)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.danger),
                            ),
                          Text(
                            '$load/$capacity',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: overloaded ? AppColors.danger : AppColors.grey400,
                            ),
                          ),
                        ],
                      ),
                      ...dayChantiers.map((c) => _ScheduledCard(workspaceId: workspaceId, chantier: c, day: day)),
                    ],
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWeekRow(BuildContext context, DateTime weekStart) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _kDayLabelWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Sem. ${_formatShortDate(weekStart)}',
              style: const TextStyle(fontSize: 12, color: AppColors.grey900, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        ...teams.map((team) {
          final weekChantiers = scheduled
              .where((c) => c.teamId == team.id && c.touchesWeek(weekStart))
              .toList();
          return SizedBox(
            width: _kTeamColumnWidth,
            child: Container(
              margin: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.cardBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              child: weekChantiers.isEmpty
                  ? const Text('—', style: TextStyle(color: AppColors.grey300, fontSize: 12))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: weekChantiers
                          .map((c) => GestureDetector(
                                onTap: () => _openDetailSheet(context, c),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Text(
                                    '• ${c.client}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.grey700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
            ),
          );
        }),
      ],
    );
  }

  void _openTeamSheet(BuildContext context, _PlanningTeam? team) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _TeamEditSheet(
        workspaceId: workspaceId,
        accentColor: accentColor,
        team: team,
        poseurs: poseurs,
      ),
    );
  }

  void _openDetailSheet(BuildContext context, _ChantierPlan chantier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ChantierDetailSheet(workspaceId: workspaceId, chantier: chantier, accentColor: accentColor),
    );
  }
}

// ────────────────────────────────────────────────
// BARRE SUPÉRIEURE
// ────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.accentColor,
    required this.weekMode,
    required this.onToggleWeekMode,
    required this.onPrev,
    required this.onNext,
    required this.onCreateTeam,
  });

  final Color accentColor;
  final bool weekMode;
  final ValueChanged<bool> onToggleWeekMode;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onCreateTeam;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const Text('Planner', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.grey900)),
          const SizedBox(width: 16),
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left, color: AppColors.grey600)),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right, color: AppColors.grey600)),
          const Spacer(),
          _SegmentButton(label: 'Jour', selected: !weekMode, accentColor: accentColor, onTap: () => onToggleWeekMode(false)),
          const SizedBox(width: 4),
          _SegmentButton(label: 'Semaine', selected: weekMode, accentColor: accentColor, onTap: () => onToggleWeekMode(true)),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: onCreateTeam,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Équipe'),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({required this.label, required this.selected, required this.accentColor, required this.onTap});
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accentColor : AppColors.grey100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.grey600,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────
// PANNEAU BACKLOG (chantiers à planifier)
// ────────────────────────────────────────────────

class _BacklogPanel extends StatelessWidget {
  const _BacklogPanel({required this.workspaceId, required this.backlog});
  final String workspaceId;
  final List<_ChantierPlan> backlog;

  @override
  Widget build(BuildContext context) {
    final ready = backlog.where((c) => c.isReady).toList();
    final blocked = backlog.where((c) => !c.isReady).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Prêt à planifier', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.success)),
        const SizedBox(height: 8),
        if (ready.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Aucun chantier prêt.', style: TextStyle(color: AppColors.grey400, fontSize: 12)),
          ),
        ...ready.map((c) => _BacklogCard(workspaceId: workspaceId, chantier: c, ready: true)),
        const SizedBox(height: 20),
        const Text('Bloqué', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.warning)),
        const SizedBox(height: 8),
        if (blocked.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Aucun chantier bloqué.', style: TextStyle(color: AppColors.grey400, fontSize: 12)),
          ),
        ...blocked.map((c) => _BacklogCard(workspaceId: workspaceId, chantier: c, ready: false)),
      ],
    );
  }
}

class _BacklogCard extends StatelessWidget {
  const _BacklogCard({required this.workspaceId, required this.chantier, required this.ready});
  final String workspaceId;
  final _ChantierPlan chantier;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: ready ? AppColors.success.withOpacity(0.4) : AppColors.warning.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(chantier.client, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.grey900)),
          Text(chantier.address, style: const TextStyle(fontSize: 11, color: AppColors.grey500), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.schedule, size: 12, color: AppColors.grey400),
              const SizedBox(width: 3),
              Text('${chantier.estimatedDurationDays}j · ${chantier.poseurCountRequired} poseur(s)',
                  style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
            ],
          ),
          if (!ready && chantier.supplierDeliveryDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'Livraison le ${_formatShortDate(chantier.supplierDeliveryDate!)}',
                style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _ChantierDetailSheet(
          workspaceId: workspaceId,
          chantier: chantier,
          accentColor: AppColors.primary,
        ),
      ),
      child: Draggable<String>(
        data: chantier.id,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: _kTeamColumnWidth - 12, child: Opacity(opacity: 0.9, child: card)),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: card),
        child: card,
      ),
    );
  }
}

class _ScheduledCard extends StatelessWidget {
  const _ScheduledCard({required this.workspaceId, required this.chantier, required this.day});
  final String workspaceId;
  final _ChantierPlan chantier;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final dayIndex = chantier.poseDate == null
        ? 1
        : day.difference(_startOfDay(chantier.poseDate!)).inDays + 1;
    final card = Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(chantier.client,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.grey900),
              overflow: TextOverflow.ellipsis),
          if (chantier.estimatedDurationDays > 1)
            Text('Jour $dayIndex/${chantier.estimatedDurationDays}',
                style: const TextStyle(fontSize: 10, color: AppColors.grey500)),
        ],
      ),
    );
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _ChantierDetailSheet(
          workspaceId: workspaceId,
          chantier: chantier,
          accentColor: AppColors.primary,
        ),
      ),
      child: Draggable<String>(
        data: chantier.id,
        feedback: Material(color: Colors.transparent, child: SizedBox(width: _kTeamColumnWidth - 16, child: card)),
        childWhenDragging: Opacity(opacity: 0.3, child: card),
        child: card,
      ),
    );
  }
}

// ────────────────────────────────────────────────
// FEUILLE : CRÉER / MODIFIER UNE ÉQUIPE
// ────────────────────────────────────────────────

class _TeamEditSheet extends StatefulWidget {
  const _TeamEditSheet({
    required this.workspaceId,
    required this.accentColor,
    required this.team,
    required this.poseurs,
  });
  final String workspaceId;
  final Color accentColor;
  final _PlanningTeam? team;
  final List<_PoseurOption> poseurs;

  @override
  State<_TeamEditSheet> createState() => _TeamEditSheetState();
}

class _TeamEditSheetState extends State<_TeamEditSheet> {
  late final _nameCtrl = TextEditingController(text: widget.team?.name ?? '');
  late final Set<String> _selected = {...(widget.team?.memberIds ?? const [])};
  bool _saving = false;

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _selected.isEmpty) return;
    setState(() => _saving = true);
    final data = {
      'name': _nameCtrl.text.trim(),
      'memberIds': _selected.toList(),
      'active': true,
    };
    final teams = FirebaseFirestore.instance
        .collection('workspaces')
        .doc(widget.workspaceId)
        .collection('planningTeams');
    if (widget.team == null) {
      await teams.add({...data, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await teams.doc(widget.team!.id).set(data, SetOptions(merge: true));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.team == null) return;
    await FirebaseFirestore.instance
        .collection('workspaces')
        .doc(widget.workspaceId)
        .collection('planningTeams')
        .doc(widget.team!.id)
        .set({'active': false}, SetOptions(merge: true));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.team == null ? 'Nouvelle équipe' : 'Modifier l\'équipe',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.grey900)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Nom de l\'équipe',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Membres', style: TextStyle(fontSize: 13, color: AppColors.grey500, fontWeight: FontWeight.w600)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView(
              shrinkWrap: true,
              children: widget.poseurs
                  .map((p) => CheckboxListTile(
                        value: _selected.contains(p.id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(p.id);
                          } else {
                            _selected.remove(p.id);
                          }
                        }),
                        activeColor: widget.accentColor,
                        title: Text(p.name, style: const TextStyle(color: AppColors.grey900)),
                        contentPadding: EdgeInsets.zero,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.team != null)
                TextButton(
                  onPressed: _delete,
                  child: const Text('Supprimer', style: TextStyle(color: AppColors.danger)),
                ),
              const Spacer(),
              ElevatedButton(
                onPressed: (_nameCtrl.text.trim().isEmpty || _selected.isEmpty || _saving) ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, foregroundColor: Colors.white),
                child: Text(widget.team == null ? 'Créer' : 'Enregistrer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
// FEUILLE : DÉTAILS DE PLANIFICATION D'UN CHANTIER
// ────────────────────────────────────────────────

class _ChantierDetailSheet extends StatefulWidget {
  const _ChantierDetailSheet({required this.workspaceId, required this.chantier, required this.accentColor});
  final String workspaceId;
  final _ChantierPlan chantier;
  final Color accentColor;

  @override
  State<_ChantierDetailSheet> createState() => _ChantierDetailSheetState();
}

class _ChantierDetailSheetState extends State<_ChantierDetailSheet> {
  late int _duration = widget.chantier.estimatedDurationDays;
  late int _poseurCount = widget.chantier.poseurCountRequired;
  DateTime? _deliveryDate;
  DateTime? _desiredDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _deliveryDate = widget.chantier.supplierDeliveryDate;
    _desiredDate = widget.chantier.clientDesiredDate;
  }

  Future<void> _pickDate(bool delivery) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (delivery ? _deliveryDate : _desiredDate) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (delivery) {
        _deliveryDate = picked;
      } else {
        _desiredDate = picked;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await FirebaseFirestore.instance
        .collection('workspaces')
        .doc(widget.workspaceId)
        .collection('devis')
        .doc(widget.chantier.id)
        .set({
      'estimatedDurationDays': _duration,
      'poseurCountRequired': _poseurCount,
      'supplierDeliveryDate': _deliveryDate != null ? Timestamp.fromDate(_deliveryDate!) : null,
      'clientDesiredDate': _desiredDate != null ? Timestamp.fromDate(_desiredDate!) : null,
    }, SetOptions(merge: true));
    if (mounted) Navigator.of(context).pop();
  }

  Widget _stepper(String label, int value, ValueChanged<int> onChanged, {int min = 1, int max = 30}) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.grey700, fontSize: 13))),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  Widget _dateRow(String label, DateTime? value, bool delivery) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.grey700, fontSize: 13))),
        TextButton(
          onPressed: () => _pickDate(delivery),
          child: Text(value == null ? 'Choisir' : _formatShortDate(value)),
        ),
        if (value != null)
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppColors.grey400),
            onPressed: () => setState(() {
              if (delivery) {
                _deliveryDate = null;
              } else {
                _desiredDate = null;
              }
            }),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.chantier.client, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.grey900)),
          Text(widget.chantier.address, style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
          const SizedBox(height: 16),
          _stepper('Durée estimée (jours)', _duration, (v) => setState(() => _duration = v)),
          _stepper('Poseurs requis', _poseurCount, (v) => setState(() => _poseurCount = v), max: 10),
          _dateRow('Livraison fournisseur', _deliveryDate, true),
          _dateRow('Date souhaitée client', _desiredDate, false),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, foregroundColor: Colors.white),
              child: const Text('Enregistrer'),
            ),
          ),
        ],
      ),
    );
  }
}
