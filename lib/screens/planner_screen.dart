// ============================================================
// lib/screens/planner_screen.dart
// Planner de planification — colonnes équipes, lignes jour/semaine,
// drag-and-drop, capacité, surcharge. Partagé Admin + Métreur.
//
// Phase 4 (Planner v2) : lot-aware. Un devis sans lot produit une seule
// unité planifiable (_PlanUnit, comportement identique à avant la Phase 3).
// Un devis avec lots (workspaces/{id}/devis/{id}.lotsSummary, dénormalisé
// par transitionDevisStatus) produit une unité par lot — chaque lot se
// planifie/drag-and-drop indépendamment, avec son propre statut/équipe/
// dépendances, exactement comme l'écran métreur sait déjà le faire.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/responsive/responsive_context.dart';
import '../core/theme/app_colors.dart';
import '../services/devis_service.dart';

const List<String> _kBacklogStatuses = ['À commander', 'Commande en cours', 'À planifier'];
const double _kDayLabelWidth = 88;
const double _kTeamColumnWidth = 220;
const double _kBacklogWidth = 260;

// Miroir Dart de LOT_TERMINAL_STATUSES (functions/devisWorkflow.js) — un lot
// dont dépend un autre doit être dans un de ces statuts pour ne plus bloquer.
// Phase 5 : À clôturer n'est plus terminal (devenu le statut pivot "rapport
// soumis, en attente de validation"), SAV ajouté à sa place.
const Set<String> _kLotTerminalStatuses = {'Terminé', 'SAV'};

const List<String> _kAbsenceReasons = ['Congé', 'Maladie', 'Formation', 'Absence partielle'];

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
DateTime _startOfWeek(DateTime d) {
  final start = _startOfDay(d);
  return start.subtract(Duration(days: start.weekday - 1));
}
String _twoDigits(int n) => n.toString().padLeft(2, '0');
String _formatShortDate(DateTime d) => '${_twoDigits(d.day)}/${_twoDigits(d.month)}';
String _formatDateTime(DateTime d) =>
    '${_formatShortDate(d)}/${d.year} ${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';
const _kWeekdayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

DateTime? _tsOf(dynamic v) => v is Timestamp ? v.toDate() : null;

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({
    super.key,
    required this.workspaceId,
    required this.accentColor,
    this.readOnly = false,
    this.filterPoseurId,
  });
  final String workspaceId;
  final Color accentColor;

  /// Poseur (et, à terme, tout rôle sans droit d'écriture serveur sur la
  /// planification) : masque création d'équipe/congés et rend les cellules
  /// non draggables/déposables — les Cloud Functions de planification
  /// (updateLotPlanningFields, setLotDependencies, transitionDevisStatus)
  /// n'acceptent que metreur/admin/commercial côté serveur de toute façon.
  final bool readOnly;

  /// Si renseigné (Poseur), restreint la vue à ses propres poses : équipes
  /// dont il est membre, chantiers où il figure dans poseurIds. Backlog masqué
  /// (rien à planifier soi-même).
  final String? filterPoseurId;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final _firestore = FirebaseFirestore.instance;

  bool _weekMode = false;
  DateTime _anchor = _startOfWeek(DateTime.now());
  // Sur mobile, une seule équipe à la fois est affichée (sélecteur) plutôt
  // que toutes les colonnes côte à côte — trop étroit pour glisser-déposer
  // confortablement dès qu'il y a 2+ équipes. Bidon sur desktop (toutes les
  // équipes restent visibles ensemble comme avant).
  String? _mobileSelectedTeamId;

  void _shiftAnchor(int direction) {
    final step = _weekMode ? 28 : 7;
    setState(() => _anchor = _anchor.add(Duration(days: direction * step)));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _teamsStream => _firestore
      .collection('workspaces')
      .doc(widget.workspaceId)
      .collection('planningTeams')
      .orderBy('createdAt')
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
            .where((t) => widget.filterPoseurId == null || t.memberIds.contains(widget.filterPoseurId))
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
                    final units = <_PlanUnit>[];
                    for (final doc in (devisSnap.data?.docs ?? [])) {
                      units.addAll(_PlanUnit.fromDevisDoc(doc));
                    }
                    final backlog = widget.filterPoseurId != null
                        ? const <_PlanUnit>[]
                        : units.where((u) => _kBacklogStatuses.contains(u.status)).toList();
                    final scheduled = units
                        .where((u) => u.status == 'En pose')
                        .where((u) => widget.filterPoseurId == null || u.poseurIds.contains(widget.filterPoseurId))
                        .toList();

                    // Sélecteur d'équipe mobile : par défaut la première,
                    // recalé si l'équipe choisie a disparu (désactivée...).
                    final isMobileMultiTeam = context.isMobile && teams.length > 1;
                    if (isMobileMultiTeam &&
                        (_mobileSelectedTeamId == null ||
                            !teams.any((t) => t.id == _mobileSelectedTeamId))) {
                      _mobileSelectedTeamId = teams.first.id;
                    }
                    final visibleTeams = isMobileMultiTeam
                        ? teams.where((t) => t.id == _mobileSelectedTeamId).toList()
                        : teams;

                    // Semaine retirée sur mobile (colonnes bien trop
                    // étroites pour rester lisibles) — seule la vue Jour y
                    // est proposée, le champ `_weekMode` sous-jacent n'est
                    // pas remis à zéro (inoffensif, juste ignoré ici).
                    final effectiveWeekMode = context.isMobile ? false : _weekMode;
                    final visibleDates = effectiveWeekMode
                        ? List.generate(4, (i) => _anchor.add(Duration(days: i * 7)))
                        : List.generate(7, (i) => _anchor.add(Duration(days: i)));

                    return _PlannerBody(
                      workspaceId: widget.workspaceId,
                      accentColor: widget.accentColor,
                      readOnly: widget.readOnly,
                      teams: visibleTeams,
                      allTeams: isMobileMultiTeam ? teams : null,
                      selectedTeamId: isMobileMultiTeam ? _mobileSelectedTeamId : null,
                      onSelectTeam: isMobileMultiTeam
                          ? (id) => setState(() => _mobileSelectedTeamId = id)
                          : null,
                      poseurs: poseurs,
                      unavailabilities: unavailabilities,
                      backlog: backlog,
                      scheduled: scheduled,
                      weekMode: effectiveWeekMode,
                      visibleDates: visibleDates,
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
  const _Unavailability({
    required this.id,
    required this.poseurId,
    required this.start,
    required this.end,
    this.reason = '',
  });
  final String id;
  final String poseurId;
  final DateTime start;
  final DateTime end;
  final String reason;

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
      id: doc.id,
      poseurId: d['poseurId']?.toString() ?? '',
      start: start.toDate(),
      end: end.toDate(),
      reason: d['reason']?.toString() ?? '',
    );
  }
}

/// Statut/label d'un lot frère, utilisé uniquement pour résoudre l'affichage
/// des dépendances (`dependsOn`) d'une autre unité du même devis.
class _SiblingLotInfo {
  const _SiblingLotInfo({required this.label, required this.status});
  final String label;
  final String status;
}

/// Unité planifiable dans le Planner : soit un devis entier (pas de lots,
/// comportement identique à avant la Phase 4), soit un lot d'un devis
/// multi-lots (Phase 3). Toutes les unités d'un même devis partagent
/// `client`/`address`/`supplierDeliveryDate`/`clientDesiredDate` — ces
/// champs restent devis-level (décision Phase 3 : pas de livraison/date
/// souhaitée par lot).
class _PlanUnit {
  const _PlanUnit({
    required this.devisId,
    required this.lotId,
    required this.client,
    required this.address,
    required this.label,
    required this.status,
    this.teamId,
    this.poseDate,
    this.estimatedDurationDays = 1,
    this.poseurCountRequired = 1,
    this.poseurIds = const [],
    this.poseurNames = '',
    this.dependsOn = const [],
    this.materielRequis = '',
    this.supplierDeliveryDate,
    this.clientDesiredDate,
    this.siblings = const {},
  });

  final String devisId;
  final String? lotId;
  final String client;
  final String address;
  final String label;
  final String status;
  final String? teamId;
  final DateTime? poseDate;
  final int estimatedDurationDays;
  final int poseurCountRequired;
  final List<String> poseurIds;
  final String poseurNames;
  final List<String> dependsOn;
  final String materielRequis;
  final DateTime? supplierDeliveryDate;
  final DateTime? clientDesiredDate;
  final Map<String, _SiblingLotInfo> siblings;

  bool get dependenciesSatisfied {
    if (dependsOn.isEmpty) return true;
    return dependsOn.every((id) {
      final info = siblings[id];
      return info != null && _kLotTerminalStatuses.contains(info.status);
    });
  }

  List<String> get blockingDependencyLabels => dependsOn
      .where((id) {
        final info = siblings[id];
        return info == null || !_kLotTerminalStatuses.contains(info.status);
      })
      .map((id) => siblings[id]?.label ?? id)
      .toList();

  bool get isReady {
    if (status != 'À planifier') return false;
    if (!dependenciesSatisfied) return false;
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

  static List<_PlanUnit> fromDevisDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final client = d['client']?.toString() ?? 'Client';
    final address = d['address']?.toString() ?? '';
    final supplierDeliveryDate = _tsOf(d['supplierDeliveryDate']);
    final clientDesiredDate = _tsOf(d['clientDesiredDate']);
    final lotsSummary = (d['lotsSummary'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    if (lotsSummary.isEmpty) {
      return [
        _PlanUnit(
          devisId: doc.id,
          lotId: null,
          client: client,
          address: address,
          label: client,
          status: (d['status'] ?? d['metreurStatus'])?.toString() ?? '',
          teamId: d['teamId']?.toString(),
          poseDate: _tsOf(d['poseDate']),
          estimatedDurationDays: (d['estimatedDurationDays'] as num?)?.toInt() ?? 1,
          poseurCountRequired: (d['poseurCountRequired'] as num?)?.toInt() ?? 1,
          poseurIds: (d['poseurIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
          poseurNames: d['poseurNames']?.toString() ?? '',
          materielRequis: d['materielRequis']?.toString() ?? '',
          supplierDeliveryDate: supplierDeliveryDate,
          clientDesiredDate: clientDesiredDate,
        ),
      ];
    }

    final siblings = <String, _SiblingLotInfo>{
      for (final l in lotsSummary)
        (l['lotId']?.toString() ?? ''): _SiblingLotInfo(
          label: l['label']?.toString().isNotEmpty == true ? l['label'].toString() : (l['lotId']?.toString() ?? ''),
          status: l['status']?.toString() ?? '',
        ),
    };

    return lotsSummary.map((l) {
      final lotId = l['lotId']?.toString();
      return _PlanUnit(
        devisId: doc.id,
        lotId: lotId,
        client: client,
        address: address,
        label: l['label']?.toString().isNotEmpty == true ? l['label'].toString() : (lotId ?? client),
        status: l['status']?.toString() ?? '',
        teamId: l['teamId']?.toString(),
        poseDate: _tsOf(l['poseDate']),
        estimatedDurationDays: (l['estimatedDurationDays'] as num?)?.toInt() ?? 1,
        poseurCountRequired: (l['poseurCountRequired'] as num?)?.toInt() ?? 1,
        poseurIds: (l['poseurIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        poseurNames: l['poseurNames']?.toString() ?? '',
        dependsOn: (l['dependsOn'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        materielRequis: l['materielRequis']?.toString() ?? '',
        supplierDeliveryDate: supplierDeliveryDate,
        clientDesiredDate: clientDesiredDate,
        siblings: siblings,
      );
    }).toList();
  }
}

// ────────────────────────────────────────────────
// CORPS PRINCIPAL (une fois les données chargées)
// ────────────────────────────────────────────────

class _PlannerBody extends StatelessWidget {
  const _PlannerBody({
    required this.workspaceId,
    required this.accentColor,
    required this.readOnly,
    required this.teams,
    required this.poseurs,
    required this.unavailabilities,
    required this.backlog,
    required this.scheduled,
    required this.weekMode,
    required this.visibleDates,
    required this.onToggleWeekMode,
    required this.onShiftAnchor,
    this.allTeams,
    this.selectedTeamId,
    this.onSelectTeam,
  });

  final String workspaceId;
  final Color accentColor;
  final bool readOnly;
  final List<_PlanningTeam> teams;
  final List<_PoseurOption> poseurs;
  final List<_Unavailability> unavailabilities;
  final List<_PlanUnit> backlog;
  final List<_PlanUnit> scheduled;
  final bool weekMode;
  final List<DateTime> visibleDates;
  final ValueChanged<bool> onToggleWeekMode;
  final void Function(int direction) onShiftAnchor;
  // Sélecteur d'équipe mobile (non-null seulement sur mobile avec 2+
  // équipes) : `allTeams` liste tout le monde pour le menu, `teams`
  // ci-dessus ne contient déjà que l'équipe sélectionnée pour la grille.
  final List<_PlanningTeam>? allTeams;
  final String? selectedTeamId;
  final ValueChanged<String>? onSelectTeam;

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

  // Le dépôt (glisser-déposer depuis le backlog, ou re-glisser une pose déjà
  // planifiée) fixe un jour + une équipe par défaut, mais n'écrit rien tout
  // de suite : `_PoseAssignmentSheet` s'ouvre pour ajuster l'heure et
  // confirmer/changer l'équipe avant l'écriture Firestore.
  void _assignToCell(BuildContext context, _PlanUnit unit, _PlanningTeam team, DateTime day) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PoseAssignmentSheet(
        workspaceId: workspaceId,
        unit: unit,
        teams: allTeams ?? teams,
        poseurs: poseurs,
        initialDay: day,
        initialTeamId: team.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overloadCount = _overloadedCellCount();
    final grid = SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // Petit gutter à gauche — sans lui, les libellés de jour ("Lun
        // 10/08"...) collaient pile au bord de l'écran sur mobile.
        padding: const EdgeInsets.only(left: 8),
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
    );
    return Column(
      children: [
        _TopBar(
          accentColor: accentColor,
          weekMode: weekMode,
          onToggleWeekMode: onToggleWeekMode,
          onPrev: () => onShiftAnchor(-1),
          onNext: () => onShiftAnchor(1),
          onCreateTeam: readOnly ? null : () => _openTeamSheet(context, null),
          onOpenConges: readOnly ? null : () => _openUnavailabilitiesSheet(context),
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
        // Sur mobile, le backlog (260pt) à côté de la grille (day-label 88pt
        // + 220pt par équipe) ne laisse presque plus de place pour la
        // grille. Un tiroir superposé casse le glisser-déposer (il faut
        // voir la grille ET le backlog en même temps pour glisser de l'un
        // vers l'autre) — le backlog devient donc une bande horizontale
        // défilante au-dessus de la grille, plutôt qu'un panneau qui lui
        // vole la largeur ou un tiroir qui la masque.
        if (!readOnly && context.isMobile) ...[
          _MobileBacklogStrip(workspaceId: workspaceId, backlog: backlog),
          const Divider(height: 1, color: AppColors.cardBorder),
        ],
        // Sélecteur d'équipe mobile : avec 2+ équipes, les colonnes
        // côte à côte deviennent trop étroites pour glisser-déposer
        // confortablement — une seule équipe s'affiche à la fois,
        // choisie ici (la grille ci-dessous ne contient déjà que
        // l'équipe sélectionnée, voir `_PlannerScreenState`).
        if (allTeams != null && allTeams!.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                _MobileTeamPicker(
                  teams: allTeams!,
                  selectedTeamId: selectedTeamId,
                  accentColor: accentColor,
                  onChanged: onSelectTeam!,
                ),
                if (!readOnly) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Renommer l\'équipe',
                    icon: Icon(Icons.edit_outlined, size: 18, color: accentColor),
                    onPressed: () {
                      final selected = allTeams!.firstWhere(
                        (t) => t.id == selectedTeamId,
                        orElse: () => allTeams!.first,
                      );
                      _openTeamSheet(context, selected);
                    },
                  ),
                ],
              ],
            ),
          ),
        Expanded(
          child: readOnly || context.isMobile
              ? grid
              : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: _kBacklogWidth,
                          child: _BacklogPanel(workspaceId: workspaceId, backlog: backlog),
                        ),
                        const VerticalDivider(width: 1, color: AppColors.cardBorder),
                        Expanded(child: grid),
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
                onTap: readOnly ? null : () => _openTeamSheet(context, team),
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
            child: DragTarget<_PlanUnit>(
              // `isReady` reflète exactement la règle serveur (statut
              // "À planifier" + dépendances satisfaites) — refuser ici les
              // chantiers "Bloqué" évite un aller-retour serveur voué à
              // échouer ("Transition non autorisée : À commander → En
              // pose") qui remontait comme une erreur générique illisible
              // côté client (Cloud Functions ne propage pas le message des
              // `Error` non-`HttpsError`, seulement un code "internal").
              onWillAcceptWithDetails: (details) => !readOnly && details.data.isReady,
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
                      ...dayChantiers.map((c) => _ScheduledCard(
                            workspaceId: workspaceId,
                            unit: c,
                            day: day,
                            readOnly: readOnly,
                            teams: allTeams ?? teams,
                            poseurs: poseurs,
                          )),
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
                                    '• ${c.label}',
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

  void _openUnavailabilitiesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _UnavailabilitiesSheet(
        workspaceId: workspaceId,
        accentColor: accentColor,
        poseurs: poseurs,
        unavailabilities: unavailabilities,
      ),
    );
  }

  void _openDetailSheet(BuildContext context, _PlanUnit unit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ChantierDetailSheet(
        workspaceId: workspaceId,
        unit: unit,
        accentColor: accentColor,
        readOnly: readOnly,
        teams: allTeams ?? teams,
        poseurs: poseurs,
      ),
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
    required this.onOpenConges,
  });

  final Color accentColor;
  final bool weekMode;
  final ValueChanged<bool> onToggleWeekMode;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onCreateTeam;
  final VoidCallback? onOpenConges;

  @override
  Widget build(BuildContext context) {
    // Capturées en local pour que Dart promeuve leur type en non-nullable
    // dans les blocs `if` ci-dessous (ce sont des champs, pas des variables).
    final conges = onOpenConges;
    final createTeam = onCreateTeam;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const Text('Planner', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.grey900)),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left, color: AppColors.grey600),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, color: AppColors.grey600),
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const Spacer(),
          // Choix Jour/Semaine retiré sur mobile : les colonnes de la vue
          // Semaine sont bien trop étroites pour rester lisibles sur un
          // écran de téléphone — seule la vue Jour y est proposée
          // (`_PlannerScreenState` force déjà `weekMode` à false).
          if (!context.isMobile) ...[
            _SegmentButton(label: 'Jour', selected: !weekMode, accentColor: accentColor, onTap: () => onToggleWeekMode(false)),
            const SizedBox(width: 4),
            _SegmentButton(label: 'Semaine', selected: weekMode, accentColor: accentColor, onTap: () => onToggleWeekMode(true)),
          ],
          // Congés/Créer équipe : actions secondaires regroupées dans un menu
          // "plus" plutôt qu'en boutons texte côte à côte — avec le titre, la
          // navigation et le switch Jour/Semaine déjà présents, les afficher
          // en clair faisait déborder la barre de 186px sur un écran de
          // téléphone (RenderFlex overflow constaté en test réel).
          if (conges != null || createTeam != null) ...[
            const SizedBox(width: 4),
            PopupMenuButton<VoidCallback>(
              tooltip: 'Plus d\'actions',
              icon: const Icon(Icons.more_vert, color: AppColors.grey600),
              padding: EdgeInsets.zero,
              onSelected: (action) => action(),
              itemBuilder: (context) => [
                if (conges != null)
                  PopupMenuItem<VoidCallback>(
                    value: conges,
                    child: const Row(
                      children: [
                        Icon(Icons.beach_access_outlined, size: 18, color: AppColors.grey700),
                        SizedBox(width: 10),
                        Text('Congés'),
                      ],
                    ),
                  ),
                if (createTeam != null)
                  PopupMenuItem<VoidCallback>(
                    value: createTeam,
                    child: Row(
                      children: [
                        Icon(Icons.add, size: 18, color: accentColor),
                        const SizedBox(width: 10),
                        const Text('Créer une équipe'),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Sélecteur "Afficher Équipe X" — mobile uniquement, 2+ équipes. Remplace
/// les colonnes équipes côte à côte (illisibles/trop étroites en dessous de
/// 2 équipes sur un écran de téléphone) par un choix explicite d'une seule
/// équipe à la fois, sans rien perdre du glisser-déposer sur la grille.
class _MobileTeamPicker extends StatelessWidget {
  const _MobileTeamPicker({
    required this.teams,
    required this.selectedTeamId,
    required this.accentColor,
    required this.onChanged,
  });
  final List<_PlanningTeam> teams;
  final String? selectedTeamId;
  final Color accentColor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = teams.firstWhere(
      (t) => t.id == selectedTeamId,
      orElse: () => teams.first,
    );
    return PopupMenuButton<String>(
      tooltip: 'Changer d\'équipe',
      onSelected: onChanged,
      itemBuilder: (context) => teams
          .map((t) => PopupMenuItem<String>(
                value: t.id,
                child: Row(
                  children: [
                    Icon(
                      t.id == selectedTeamId ? Icons.check_circle : Icons.circle_outlined,
                      size: 16,
                      color: t.id == selectedTeamId ? accentColor : AppColors.grey300,
                    ),
                    const SizedBox(width: 10),
                    Text('Afficher ${t.name}'),
                  ],
                ),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined, size: 16, color: accentColor),
            const SizedBox(width: 8),
            Text(
              'Afficher ${selected.name}',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: accentColor),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 18, color: accentColor),
          ],
        ),
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
// CHIP DE DÉPENDANCE (badge partagé backlog/grille/détail)
// ────────────────────────────────────────────────

class _DependencyChip extends StatelessWidget {
  const _DependencyChip({required this.unit});
  final _PlanUnit unit;

  @override
  Widget build(BuildContext context) {
    if (unit.dependsOn.isEmpty) return const SizedBox.shrink();
    final satisfied = unit.dependenciesSatisfied;
    final labels = satisfied
        ? unit.dependsOn.map((id) => unit.siblings[id]?.label ?? id).toList()
        : unit.blockingDependencyLabels;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            satisfied ? Icons.check_circle_outline : Icons.lock_clock,
            size: 12,
            color: satisfied ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              satisfied ? 'Dépend de : ${labels.join(', ')}' : 'Bloqué par : ${labels.join(', ')}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: satisfied ? AppColors.success : AppColors.warning,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
// LAYOUT MOBILE — backlog en bande horizontale
// ────────────────────────────────────────────────

/// Sur mobile, le backlog et la grille ne peuvent pas se partager la largeur
/// comme sur desktop (voir commentaire dans `_PlannerBody.build`), et un
/// tiroir qui masque la grille casse le glisser-déposer (il faut voir les
/// deux en même temps pour glisser l'un vers l'autre). Le backlog devient
/// donc une bande horizontale défilante fixée au-dessus de la grille — même
/// principe que "Chantiers récemment ajoutés" sur les dashboards.
class _MobileBacklogStrip extends StatelessWidget {
  const _MobileBacklogStrip({required this.workspaceId, required this.backlog});
  final String workspaceId;
  final List<_PlanUnit> backlog;

  @override
  Widget build(BuildContext context) {
    if (backlog.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Text('Backlog vide — aucun chantier en attente de planification.',
            style: TextStyle(color: AppColors.grey400, fontSize: 12)),
      );
    }
    // Prêts d'abord (actionnables tout de suite), bloqués ensuite.
    final ordered = [
      ...backlog.where((c) => c.isReady),
      ...backlog.where((c) => !c.isReady),
    ];
    return SizedBox(
      height: 158,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        scrollDirection: Axis.horizontal,
        itemCount: ordered.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _MobileBacklogCard(workspaceId: workspaceId, unit: ordered[i]),
      ),
    );
  }
}

class _MobileBacklogCard extends StatelessWidget {
  const _MobileBacklogCard({required this.workspaceId, required this.unit});
  final String workspaceId;
  final _PlanUnit unit;

  @override
  Widget build(BuildContext context) {
    final ready = unit.isReady;
    final statusColor = ready ? AppColors.success : AppColors.warning;
    final card = Container(
      width: 192,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: statusColor.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(ready ? 'Prêt' : 'Bloqué',
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Text(unit.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.grey900)),
          const SizedBox(height: 2),
          Text(unit.address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule, size: 12, color: AppColors.grey400),
              const SizedBox(width: 3),
              Text('${unit.estimatedDurationDays}j · ${unit.poseurCountRequired} poseur(s)',
                  style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
            ],
          ),
          _DependencyChip(unit: unit),
        ],
      ),
    );

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _ChantierDetailSheet(workspaceId: workspaceId, unit: unit, accentColor: AppColors.primary),
      ),
      child: Draggable<_PlanUnit>(
        data: unit,
        feedback: Material(color: Colors.transparent, child: Opacity(opacity: 0.9, child: card)),
        childWhenDragging: Opacity(opacity: 0.3, child: card),
        child: card,
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
  final List<_PlanUnit> backlog;

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
        ...ready.map((c) => _BacklogCard(workspaceId: workspaceId, unit: c, ready: true)),
        const SizedBox(height: 20),
        const Text('Bloqué', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.warning)),
        const SizedBox(height: 8),
        if (blocked.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Aucun chantier bloqué.', style: TextStyle(color: AppColors.grey400, fontSize: 12)),
          ),
        ...blocked.map((c) => _BacklogCard(workspaceId: workspaceId, unit: c, ready: false)),
      ],
    );
  }
}

class _BacklogCard extends StatelessWidget {
  const _BacklogCard({required this.workspaceId, required this.unit, required this.ready});
  final String workspaceId;
  final _PlanUnit unit;
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
          Text(unit.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.grey900)),
          if (unit.lotId != null)
            Text(unit.client, style: const TextStyle(fontSize: 11, color: AppColors.grey500), overflow: TextOverflow.ellipsis),
          Text(unit.address, style: const TextStyle(fontSize: 11, color: AppColors.grey500), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.schedule, size: 12, color: AppColors.grey400),
              const SizedBox(width: 3),
              Text('${unit.estimatedDurationDays}j · ${unit.poseurCountRequired} poseur(s)',
                  style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
            ],
          ),
          if (!ready && unit.dependenciesSatisfied && unit.supplierDeliveryDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'Livraison le ${_formatShortDate(unit.supplierDeliveryDate!)}',
                style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
              ),
            ),
          _DependencyChip(unit: unit),
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
          unit: unit,
          accentColor: AppColors.primary,
        ),
      ),
      child: Draggable<_PlanUnit>(
        data: unit,
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
  const _ScheduledCard({
    required this.workspaceId,
    required this.unit,
    required this.day,
    this.readOnly = false,
    this.teams = const [],
    this.poseurs = const [],
  });
  final String workspaceId;
  final _PlanUnit unit;
  final DateTime day;
  final bool readOnly;
  final List<_PlanningTeam> teams;
  final List<_PoseurOption> poseurs;

  @override
  Widget build(BuildContext context) {
    final dayIndex = unit.poseDate == null
        ? 1
        : day.difference(_startOfDay(unit.poseDate!)).inDays + 1;
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
          Text(unit.label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.grey900),
              overflow: TextOverflow.ellipsis),
          if (unit.lotId != null)
            Text(unit.client,
                style: const TextStyle(fontSize: 10, color: AppColors.grey500), overflow: TextOverflow.ellipsis),
          if (unit.estimatedDurationDays > 1)
            Text('Jour $dayIndex/${unit.estimatedDurationDays}',
                style: const TextStyle(fontSize: 10, color: AppColors.grey500)),
          _DependencyChip(unit: unit),
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
          unit: unit,
          accentColor: AppColors.primary,
          readOnly: readOnly,
          teams: teams,
          poseurs: poseurs,
        ),
      ),
      child: readOnly
          ? card
          : Draggable<_PlanUnit>(
              data: unit,
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
// FEUILLE : CONGÉS & ABSENCES (Phase 4)
// ────────────────────────────────────────────────

class _UnavailabilitiesSheet extends StatelessWidget {
  const _UnavailabilitiesSheet({
    required this.workspaceId,
    required this.accentColor,
    required this.poseurs,
    required this.unavailabilities,
  });
  final String workspaceId;
  final Color accentColor;
  final List<_PoseurOption> poseurs;
  final List<_Unavailability> unavailabilities;

  Future<void> _delete(_Unavailability u) async {
    await FirebaseFirestore.instance
        .collection('workspaces')
        .doc(workspaceId)
        .collection('unavailabilities')
        .doc(u.id)
        .delete();
  }

  void _openForm(BuildContext context, _Unavailability? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _UnavailabilityFormSheet(
        workspaceId: workspaceId,
        accentColor: accentColor,
        poseurs: poseurs,
        existing: existing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...unavailabilities]..sort((a, b) => b.start.compareTo(a.start));
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Congés & absences',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.grey900)),
                ),
                TextButton.icon(
                  onPressed: () => _openForm(context, null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: sorted.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Aucune absence enregistrée.', style: TextStyle(color: AppColors.grey400)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) => const Divider(height: 12, color: AppColors.cardBorder),
                      itemBuilder: (context, i) {
                        final u = sorted[i];
                        final poseur = poseurs.where((p) => p.id == u.poseurId).toList();
                        final poseurName = poseur.isNotEmpty ? poseur.first.name : u.poseurId;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(poseurName,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.grey900, fontSize: 13)),
                          subtitle: Text(
                            '${u.reason.isNotEmpty ? '${u.reason} · ' : ''}${_formatShortDate(u.start)} → ${_formatShortDate(u.end)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.grey500),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.grey500),
                                onPressed: () => _openForm(context, u),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                onPressed: () => _delete(u),
                              ),
                            ],
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

class _UnavailabilityFormSheet extends StatefulWidget {
  const _UnavailabilityFormSheet({
    required this.workspaceId,
    required this.accentColor,
    required this.poseurs,
    this.existing,
  });
  final String workspaceId;
  final Color accentColor;
  final List<_PoseurOption> poseurs;
  final _Unavailability? existing;

  @override
  State<_UnavailabilityFormSheet> createState() => _UnavailabilityFormSheetState();
}

class _UnavailabilityFormSheetState extends State<_UnavailabilityFormSheet> {
  String? _poseurId;
  DateTime? _start;
  DateTime? _end;
  String _reason = _kAbsenceReasons.first;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _poseurId = widget.existing?.poseurId ?? (widget.poseurs.isNotEmpty ? widget.poseurs.first.id : null);
    _start = widget.existing?.start;
    _end = widget.existing?.end;
    _reason = (widget.existing?.reason.isNotEmpty ?? false) ? widget.existing!.reason : _kAbsenceReasons.first;
  }

  bool get _canSave => _poseurId != null && _start != null && _end != null && !_end!.isBefore(_start!) && !_saving;

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final data = {
      'poseurId': _poseurId,
      'startDate': Timestamp.fromDate(_start!),
      'endDate': Timestamp.fromDate(_end!),
      'reason': _reason,
    };
    final col = FirebaseFirestore.instance
        .collection('workspaces')
        .doc(widget.workspaceId)
        .collection('unavailabilities');
    try {
      if (widget.existing == null) {
        await col.add({...data, 'createdAt': FieldValue.serverTimestamp()});
      } else {
        await col.doc(widget.existing!.id).set(data, SetOptions(merge: true));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Widget _dropdownField<T>(String label, T? value, List<T> items, String Function(T) text, ValueChanged<T?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(label, style: const TextStyle(color: AppColors.grey500)),
          items: items.map((v) => DropdownMenuItem(value: v, child: Text(text(v)))).toList(),
          onChanged: onChanged,
        ),
      ),
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
          Text(widget.existing == null ? 'Nouvelle absence' : 'Modifier l\'absence',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.grey900)),
          const SizedBox(height: 16),
          _dropdownField<String>(
            'Poseur',
            _poseurId,
            widget.poseurs.map((p) => p.id).toList(),
            (id) => widget.poseurs.firstWhere((p) => p.id == id).name,
            (v) => setState(() => _poseurId = v),
          ),
          const SizedBox(height: 12),
          _dropdownField<String>(
            'Motif',
            _reason,
            _kAbsenceReasons,
            (r) => r,
            (v) => setState(() => _reason = v ?? _reason),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(true),
                  child: Text(_start == null ? 'Début' : _formatShortDate(_start!)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(false),
                  child: Text(_end == null ? 'Fin' : _formatShortDate(_end!)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSave ? _save : null,
              style: ElevatedButton.styleFrom(backgroundColor: widget.accentColor, foregroundColor: Colors.white),
              child: Text(widget.existing == null ? 'Ajouter' : 'Enregistrer'),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
// FEUILLE : HISTORIQUE DES TRANSITIONS (Phase 4)
// ────────────────────────────────────────────────

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.workspaceId, required this.unit});
  final String workspaceId;
  final _PlanUnit unit;

  Future<List<Map<String, dynamic>>> _load() async {
    final devisRef = FirebaseFirestore.instance
        .collection('workspaces')
        .doc(workspaceId)
        .collection('devis')
        .doc(unit.devisId);
    final historyRef = unit.lotId != null
        ? devisRef.collection('lots').doc(unit.lotId).collection('statusHistory')
        : devisRef.collection('statusHistory');
    final snap = await historyRef.orderBy('at', descending: true).limit(30).get();
    return snap.docs.map((d) => d.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _load(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return SizedBox(
              height: 80,
              child: Center(child: Text('Erreur : ${snap.error}', style: const TextStyle(color: AppColors.danger))),
            );
          }
          final entries = snap.data!;
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Historique — ${unit.label}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.grey900)),
                const SizedBox(height: 12),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Aucun historique.', style: TextStyle(color: AppColors.grey400)),
                  ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 16, color: AppColors.cardBorder),
                    itemBuilder: (context, i) {
                      final e = entries[i];
                      final from = e['fromStatus']?.toString() ?? '(aucun)';
                      final to = e['toStatus']?.toString() ?? '';
                      final role = e['role']?.toString() ?? '';
                      final at = e['at'];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$from → $to',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.grey900)),
                          Text(
                            '${at is Timestamp ? _formatDateTime(at.toDate()) : ''} · $role',
                            style: const TextStyle(fontSize: 11, color: AppColors.grey500),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────
// FEUILLE : CONFIRMER DATE + HEURE + ÉQUIPE D'UNE POSE
// ────────────────────────────────────────────────

/// Popup de confirmation ouverte à chaque fois qu'une pose est assignée à
/// une case (glisser-déposer depuis le backlog ou re-glissée à une autre
/// date/équipe) — la case déposée ne fixe qu'un jour + une équipe par
/// défaut, cette feuille laisse ajuster l'heure et changer l'équipe avant
/// d'écrire. Réutilisée aussi comme feuille "Modifier" quand on tape une
/// pose déjà planifiée dans la grille (voir `_ChantierDetailSheet`).
class _PoseAssignmentSheet extends StatefulWidget {
  const _PoseAssignmentSheet({
    required this.workspaceId,
    required this.unit,
    required this.teams,
    required this.poseurs,
    required this.initialDay,
    this.initialTeamId,
  });
  final String workspaceId;
  final _PlanUnit unit;
  final List<_PlanningTeam> teams;
  final List<_PoseurOption> poseurs;
  final DateTime initialDay;
  final String? initialTeamId;

  @override
  State<_PoseAssignmentSheet> createState() => _PoseAssignmentSheetState();
}

class _PoseAssignmentSheetState extends State<_PoseAssignmentSheet> {
  late DateTime _date;
  late TimeOfDay _time;
  String? _teamId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = _startOfDay(widget.initialDay);
    _time = widget.unit.poseDate != null
        ? TimeOfDay.fromDateTime(widget.unit.poseDate!)
        : const TimeOfDay(hour: 8, minute: 0);
    _teamId = widget.initialTeamId ??
        widget.unit.teamId ??
        (widget.teams.isNotEmpty ? widget.teams.first.id : null);
  }

  String _poseurName(String uid) {
    for (final p in widget.poseurs) {
      if (p.id == uid) return p.name;
    }
    return uid;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _confirm() async {
    if (_teamId == null) return;
    final team = widget.teams.firstWhere((t) => t.id == _teamId, orElse: () => widget.teams.first);
    final names = team.memberIds.map(_poseurName).join(', ');
    final poseDateTime = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    setState(() => _saving = true);
    try {
      await DevisService.updateStatus(
        workspaceId: widget.workspaceId,
        devisId: widget.unit.devisId,
        newStatus: 'En pose',
        lotId: widget.unit.lotId,
        extraFields: {
          'teamId': team.id,
          'poseDate': poseDateTime.toIso8601String(),
          'poseurIds': team.memberIds,
          'poseurNames': names,
        },
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de planification : $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.unit.label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.grey900)),
          Text(widget.unit.client, style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text('Date', style: const TextStyle(color: AppColors.grey700, fontSize: 13))),
              TextButton(onPressed: _pickDate, child: Text(_formatShortDate(_date))),
            ],
          ),
          Row(
            children: [
              Expanded(child: Text('Heure', style: const TextStyle(color: AppColors.grey700, fontSize: 13))),
              TextButton(onPressed: _pickTime, child: Text(_time.format(context))),
            ],
          ),
          Row(
            children: [
              Expanded(child: Text('Équipe', style: const TextStyle(color: AppColors.grey700, fontSize: 13))),
              DropdownButton<String>(
                value: _teamId,
                items: widget.teams
                    .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                    .toList(),
                onChanged: (v) => setState(() => _teamId = v),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving || _teamId == null ? null : _confirm,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Confirmer'),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
// FEUILLE : DÉTAILS DE PLANIFICATION D'UN CHANTIER / LOT
// ────────────────────────────────────────────────

class _ChantierDetailSheet extends StatefulWidget {
  const _ChantierDetailSheet({
    required this.workspaceId,
    required this.unit,
    required this.accentColor,
    this.readOnly = false,
    this.teams = const [],
    this.poseurs = const [],
  });
  final String workspaceId;
  final _PlanUnit unit;
  final Color accentColor;
  final bool readOnly;
  final List<_PlanningTeam> teams;
  final List<_PoseurOption> poseurs;

  @override
  State<_ChantierDetailSheet> createState() => _ChantierDetailSheetState();
}

class _ChantierDetailSheetState extends State<_ChantierDetailSheet> {
  late int _duration = widget.unit.estimatedDurationDays;
  late int _poseurCount = widget.unit.poseurCountRequired;
  late final _materielCtrl = TextEditingController(text: widget.unit.materielRequis);
  DateTime? _deliveryDate;
  DateTime? _desiredDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _deliveryDate = widget.unit.supplierDeliveryDate;
    _desiredDate = widget.unit.clientDesiredDate;
  }

  @override
  void dispose() {
    _materielCtrl.dispose();
    super.dispose();
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
    try {
      await FirebaseFirestore.instance
          .collection('workspaces')
          .doc(widget.workspaceId)
          .collection('devis')
          .doc(widget.unit.devisId)
          .set({
        'supplierDeliveryDate': _deliveryDate != null ? Timestamp.fromDate(_deliveryDate!) : null,
        'clientDesiredDate': _desiredDate != null ? Timestamp.fromDate(_desiredDate!) : null,
        if (widget.unit.lotId == null) ...{
          'estimatedDurationDays': _duration,
          'poseurCountRequired': _poseurCount,
          'materielRequis': _materielCtrl.text.trim(),
        },
      }, SetOptions(merge: true));

      if (widget.unit.lotId != null) {
        await DevisService.updateLotPlanningFields(
          workspaceId: widget.workspaceId,
          devisId: widget.unit.devisId,
          lotId: widget.unit.lotId!,
          estimatedDurationDays: _duration,
          poseurCountRequired: _poseurCount,
          materielRequis: _materielCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.danger),
        );
      }
    }
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

  void _openHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _HistorySheet(workspaceId: widget.workspaceId, unit: widget.unit),
    );
  }

  void _openModifyPose() {
    Navigator.of(context).pop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PoseAssignmentSheet(
        workspaceId: widget.workspaceId,
        unit: widget.unit,
        teams: widget.teams,
        poseurs: widget.poseurs,
        initialDay: widget.unit.poseDate ?? DateTime.now(),
        initialTeamId: widget.unit.teamId,
      ),
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.unit.label,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.grey900)),
                    if (widget.unit.lotId != null)
                      Text(widget.unit.client, style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
                    Text(widget.unit.address, style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _openHistory,
                icon: const Icon(Icons.history, size: 16),
                label: const Text('Historique'),
              ),
            ],
          ),
          if (widget.unit.poseDate != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Prévu le ${_formatDateTime(widget.unit.poseDate!)}'
                      '${widget.unit.poseurNames.isNotEmpty ? ' par ${widget.unit.poseurNames}' : ''}',
                      style: const TextStyle(color: AppColors.grey900, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (!widget.readOnly && widget.teams.isNotEmpty)
                    TextButton(onPressed: _openModifyPose, child: const Text('Modifier')),
                ],
              ),
            ),
          ],
          if (widget.unit.dependsOn.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.unit.dependsOn.map((depId) {
                final info = widget.unit.siblings[depId];
                final satisfied = info != null && _kLotTerminalStatuses.contains(info.status);
                return Chip(
                  label: Text(info?.label ?? depId, style: const TextStyle(fontSize: 11)),
                  avatar: Icon(
                    satisfied ? Icons.check_circle : Icons.lock_clock,
                    size: 14,
                    color: satisfied ? AppColors.success : AppColors.warning,
                  ),
                  backgroundColor: satisfied ? AppColors.success.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
                  side: BorderSide.none,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          if (widget.readOnly) ...[
            Text('Durée estimée : $_duration jour${_duration > 1 ? 's' : ''}',
                style: const TextStyle(color: AppColors.grey700, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Poseurs requis : $_poseurCount',
                style: const TextStyle(color: AppColors.grey700, fontSize: 13)),
            if (_deliveryDate != null) ...[
              const SizedBox(height: 4),
              Text('Livraison fournisseur : ${_formatShortDate(_deliveryDate!)}',
                  style: const TextStyle(color: AppColors.grey700, fontSize: 13)),
            ],
            if (_desiredDate != null) ...[
              const SizedBox(height: 4),
              Text('Date souhaitée client : ${_formatShortDate(_desiredDate!)}',
                  style: const TextStyle(color: AppColors.grey700, fontSize: 13)),
            ],
            if (widget.unit.materielRequis.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Matériel requis : ${widget.unit.materielRequis}',
                  style: const TextStyle(color: AppColors.grey700, fontSize: 13)),
            ],
          ] else ...[
            _stepper('Durée estimée (jours)', _duration, (v) => setState(() => _duration = v)),
            _stepper('Poseurs requis', _poseurCount, (v) => setState(() => _poseurCount = v), max: 10),
            _dateRow('Livraison fournisseur', _deliveryDate, true),
            _dateRow('Date souhaitée client', _desiredDate, false),
            const SizedBox(height: 8),
            TextField(
              controller: _materielCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Matériel requis',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
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
        ],
      ),
    );
  }
}
