import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chantier_chat_screen.dart';
import 'measurement_form_screen.dart';
import 'planner_screen.dart';
import 'sign_in_screen.dart';
import 'settings_screen.dart';
import '../core/dictionary_service.dart';
import '../core/models/wi_devis_summary.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/recent_chantiers.dart';
import '../core/widgets/wi_devis_list_modal.dart';
import '../core/widgets/wi_recent_chantiers_section.dart';
import '../core/widgets/wi_swipe_back.dart';
import '../services/devis_service.dart';
import '../services/document_engine.dart';
import '../services/document_engine.dart';

const Color _metreurBg = AppColors.background;
const Color _metreurCard = AppColors.surface;
const Color _metreurAccent = AppColors.primary;
const String _workspaceIdKey = 'workit_workspace_id';
const String _workspaceNameKey = 'workit_workspace_name';
const String _userFirstNameKey = 'workit_user_first_name';
const String _userLastNameKey = 'workit_user_last_name';
const String _meteurPrefsKey = 'workit_metreur_requests';

class MetreurHomeScreen extends StatefulWidget {
  const MetreurHomeScreen({super.key});

  @override
  State<MetreurHomeScreen> createState() => _MetreurHomeScreenState();
}

class _MetreurHomeScreenState extends State<MetreurHomeScreen> {
  late List<_MeasureCardData> _newRequests;
  late List<_MeasureCardData> _acceptedRequests;
  late List<_PriorityItem> _todaysMeasures;
  late List<_MeasureCardData> _toOrder;
  late List<_MeasureCardData> _toPlan;
  late List<_MeasureCardData> _toClose;
  final _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _devisSubscription;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  String? _workspaceId;
  String? _workspaceName;
  String? _userId;
  String? _userFirstName;
  String? _userLastName;
  // Défaut = comportement historique (le métreur peut commander) tant que
  // users/{uid} n'a pas encore été lu ou n'a pas de restriction explicite.
  bool _canPlaceOrders = true;

  @override
  void initState() {
    super.initState();
    _newRequests = [];
    _acceptedRequests = [];
    _todaysMeasures = [];
    _toOrder = [];
    _toPlan = [];
    _toClose = [];
    _init();
  }

  String _greetingName() {
    if (_userFirstName?.trim().isNotEmpty == true) {
      return _userFirstName!.trim();
    }
    if (_userLastName?.trim().isNotEmpty == true) {
      return _userLastName!.trim();
    }
    return '';
  }

  String _initials() {
    final f = _userFirstName?.trim() ?? '';
    final l = _userLastName?.trim() ?? '';
    if (f.isNotEmpty && l.isNotEmpty) return '${f[0]}${l[0]}'.toUpperCase();
    if (f.isNotEmpty) return f[0].toUpperCase();
    if (l.isNotEmpty) return l[0].toUpperCase();
    return 'PL';
  }

  int _totalActions() =>
      _newRequests.length + _acceptedRequests.length + _toOrder.length + _toPlan.length;

  @override
  void dispose() {
    _devisSubscription?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadWorkspaceContext();
    _subscribeToDevis();
    _subscribeToPermissions();
  }

  void _subscribeToPermissions() {
    if (_userId == null) return;
    _userSubscription = _firestore.collection('users').doc(_userId).snapshots().listen((doc) {
      if (!mounted) return;
      setState(() => _canPlaceOrders = doc.data()?['canPlaceOrders'] != false);
    });
  }

  void _subscribeToDevis() {
    if (_workspaceId == null) {
      _loadFromPrefs();
      return;
    }
    _devisSubscription?.cancel();
    _devisSubscription = _firestore
        .collection('workspaces')
        .doc(_workspaceId)
        .collection('devis')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(_onDevisSnapshot, onError: (_) => _loadFromPrefs());
  }

  void _onDevisSnapshot(QuerySnapshot snap) {
    final newOnes = <_MeasureCardData>[];
    final accepted = <_MeasureCardData>[];
    final toOrder = <_MeasureCardData>[];
    final toPlan = <_MeasureCardData>[];
    final toClose = <_MeasureCardData>[];

    for (final doc in snap.docs) {
      final map = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
      map['id'] = doc.id;
      final assignedId = (map['metreurId'] ?? map['assignedMetreurId'])?.toString();
      if (assignedId != null &&
          assignedId.isNotEmpty &&
          assignedId != 'any' &&
          assignedId != _userId) {
        continue;
      }
      final item = _MeasureCardData.fromMap(map);
      final status = item.status;
      if (status == 'Acceptée' || status == 'En cours') {
        accepted.add(item);
      } else if (status == 'À commander' || status == 'Commande en cours') {
        toOrder.add(item);
      } else if (status == 'À planifier' || status == 'En pose') {
        toPlan.add(item);
      } else if (status == 'À clôturer' ||
          status == 'Terminé' ||
          status == 'Clôturé' ||
          status == 'SAV') {
        toClose.add(item);
      } else {
        newOnes.add(item);
      }
    }

    if (!mounted) return;
    setState(() {
      _newRequests = [..._kDemoNewRequests, ...newOnes];
      _acceptedRequests = [..._kDemoAccepted, ...accepted];
      _toOrder = [..._kDemoToOrder, ...toOrder];
      _toPlan = [..._kDemoPlan, ...toPlan];
      _toClose = [..._kDemoToClose, ...toClose];
    });
    _saveToPrefs();
  }

  Future<void> _loadWorkspaceContext() async {
    final prefs = await SharedPreferences.getInstance();
    _workspaceId = prefs.getString(_workspaceIdKey);
    _workspaceName = prefs.getString(_workspaceNameKey);
    _userFirstName = prefs.getString(_userFirstNameKey);
    _userLastName = prefs.getString(_userLastNameKey);
    _userId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _loadRequests() async {
    await _loadWorkspaceContext();
    _subscribeToDevis();
  }

  Future<Map<String, _MeasureCardData>> _readPrefsMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_meteurPrefsKey);
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final all = <_MeasureCardData>[
        ...(decoded['new'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().map(_MeasureCardData.fromMap),
        ...(decoded['accepted'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().map(_MeasureCardData.fromMap),
      ];
      return {for (final e in all) e.id: e};
    } catch (_) {
      return {};
    }
  }

  _MeasureCardData _mergeCached(_MeasureCardData live, _MeasureCardData? cached) {
    if (cached == null) return live;
    return live.copyWith(
      status: live.status ?? cached.status,
      meetingAt: live.meetingAt ?? cached.meetingAt,
      metreurId: live.metreurId ?? cached.metreurId,
      commercialId: live.commercialId ?? cached.commercialId,
      workspaceId: live.workspaceId ?? cached.workspaceId,
    );
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'new': _newRequests.map((e) => e.toMap()).toList(),
      'accepted': _acceptedRequests.map((e) => e.toMap()).toList(),
    };
    await prefs.setString(_meteurPrefsKey, json.encode(payload));
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_meteurPrefsKey);
    if (raw == null) return;
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final newOnes = (decoded['new'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(_MeasureCardData.fromMap)
          .toList();
      final accepted = (decoded['accepted'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(_MeasureCardData.fromMap)
          .toList();
      setState(() {
        _newRequests
          ..clear()
          ..addAll(newOnes);
        _acceptedRequests
          ..clear()
          ..addAll(accepted);
      });
    } catch (_) {
      // ignore parse errors
    }
  }

  void _seedDemo() {
    _newRequests = [..._kDemoNewRequests];
    _acceptedRequests = [..._kDemoAccepted];
    _todaysMeasures = [];
    _toOrder = [..._kDemoToOrder];
    _toPlan = [..._kDemoPlan];
    _toClose = [..._kDemoToClose];
  }

  @override
  Widget build(BuildContext context) {

    final allItems = [
      ..._newRequests,
      ..._acceptedRequests,
      ..._toOrder,
      ..._toPlan,
      ..._toClose,
    ];
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: 20,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greetingName().isNotEmpty ? 'Bonjour ${_greetingName()} 👋' : 'Bonjour 👋',
                style: const TextStyle(
                  color: AppColors.grey900,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Métreur · ${_totalActions()} actions à traiter',
                style: const TextStyle(color: AppColors.grey400, fontSize: 13),
              ),
            ],
          ),
          actions: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.purple,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppColors.grey400, size: 22),
              tooltip: 'Déconnexion',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                  (_) => false,
                );
              },
            ),
            const SizedBox(width: 10),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
              child: Builder(
                builder: (ctx) {
                  final tabController = DefaultTabController.of(ctx);
                  return AnimatedBuilder(
                    animation: tabController,
                    builder: (ctx2, _) {
                      final sel = tabController.index;
                      return TabBar(
                        isScrollable: true,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                        tabAlignment: TabAlignment.start,
                        dividerColor: Colors.transparent,
                        indicator: const BoxDecoration(),
                        indicatorSize: TabBarIndicatorSize.tab,
                        splashBorderRadius: BorderRadius.circular(100),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        tabs: [
                          _MetPillTab(label: 'Tous', isSelected: sel == 0),
                          _MetPillTab(label: 'En attente', isSelected: sel == 1),
                          _MetPillTab(label: 'En cours', isSelected: sel == 2),
                          _MetPillTab(label: 'À commander', isSelected: sel == 3),
                          _MetPillTab(label: 'À planifier', isSelected: sel == 4),
                          _MetPillTab(label: 'À clôturer', isSelected: sel == 5),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Stats row — 6 catégories distinctes (décidées avec Christophe,
              // voir admin_dashboard_tab.dart pour le même découpage). Calculées
              // sur allItems (fusion des 5 listes de statut déjà chargées) sans
              // toucher aux tabs/listes existantes, qui gardent leur propre
              // regroupement pour la navigation.
              Builder(builder: (context) {
                bool isEnAttente(_MeasureCardData d) {
                  final s = d.status;
                  return s == null || s == 'Nouvelle demande' || s == 'Acceptée' || s == 'En cours';
                }
                bool isACommander(_MeasureCardData d) =>
                    d.status == 'À commander' || d.status == 'Commande en cours';
                bool isAPlanifier(_MeasureCardData d) => d.status == 'À planifier';
                bool isEnPose(_MeasureCardData d) => d.status == 'En pose' || d.status == 'À clôturer';
                bool isTermine(_MeasureCardData d) => d.status == 'Terminé' || d.status == 'Clôturé';
                bool isSav(_MeasureCardData d) => d.status == 'SAV';

                final attente = allItems.where(isEnAttente).toList();
                final commander = allItems.where(isACommander).toList();
                final planifier = allItems.where(isAPlanifier).toList();
                final pose = allItems.where(isEnPose).toList();
                final termine = allItems.where(isTermine).toList();
                final sav = allItems.where(isSav).toList();

                Widget chipRow(List<Widget> chips) => Row(
                      children: chips
                          .expand((c) => [c, const SizedBox(width: 8)])
                          .toList()
                        ..removeLast(),
                    );

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    children: [
                      chipRow([
                        _StatChip(
                          label: 'En attente', count: attente.length,
                          color: AppColors.warning,
                          onTap: () => WiDevisListModal.show(context,
                              title: 'En attente', items: attente.map((e) => _toSummary(context, e)).toList()),
                        ),
                        _StatChip(
                          label: 'À commander', count: commander.length,
                          color: AppColors.amber,
                          onTap: () => WiDevisListModal.show(context,
                              title: 'À commander', items: commander.map((e) => _toSummary(context, e)).toList()),
                        ),
                        _StatChip(
                          label: 'À planifier', count: planifier.length,
                          color: AppColors.primary,
                          onTap: () => WiDevisListModal.show(context,
                              title: 'À planifier', items: planifier.map((e) => _toSummary(context, e)).toList()),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      chipRow([
                        _StatChip(
                          label: 'Programmé', count: pose.length,
                          color: AppColors.purple,
                          onTap: () => WiDevisListModal.show(context,
                              title: 'Programmé', items: pose.map((e) => _toSummary(context, e)).toList()),
                        ),
                        _StatChip(
                          label: 'Terminé', count: termine.length,
                          color: AppColors.success,
                          onTap: () => WiDevisListModal.show(context,
                              title: 'Terminé', items: termine.map((e) => _toSummary(context, e)).toList()),
                        ),
                        _StatChip(
                          label: 'SAV', count: sav.length,
                          color: AppColors.danger,
                          onTap: () => WiDevisListModal.show(context,
                              title: 'SAV', items: sav.map((e) => _toSummary(context, e)).toList()),
                        ),
                      ]),
                    ],
                  ),
                );
              }),
              Builder(builder: (context) {
                final recent = mergeRecentChantiers(allItems.map((e) => _toSummary(context, e)).toList());
                if (recent.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: WiRecentChantiersSection(title: 'Chantiers récemment ajoutés', items: recent),
                );
              }),
              Expanded(
                child: TabBarView(
                  children: [
                    _MetreurList(
                      items: allItems,
                      emptyLabel: 'Aucun chantier.',
                      onCardTap: (item) => _showRequestDetails(context, item),
                      onPlanifierPose: (item) => _openPlanner(),
                    ),
                    _MetreurList(
                      items: _newRequests,
                      emptyLabel: 'Aucune demande en attente.',
                      onCardTap: (item) => _showRequestDetails(context, item),
                      onPlanifierPose: (item) => _openPlanner(),
                    ),
                    _MetreurList(
                      items: _acceptedRequests,
                      emptyLabel: 'Aucun métré en cours.',
                      onCardTap: (item) => _showRequestDetails(context, item),
                      onPlanifierPose: (item) => _openPlanner(),
                    ),
                    _MetreurList(
                      items: _toOrder,
                      emptyLabel: 'Aucune commande en attente.',
                      onCardTap: (item) => _showRequestDetails(context, item),
                      onPlanifierPose: (item) => _openPlanner(),
                    ),
                    _MetreurList(
                      items: _toPlan,
                      emptyLabel: 'Aucune pose à planifier.',
                      onCardTap: (item) => _showRequestDetails(context, item),
                      onPlanifierPose: (item) => _openPlanner(),
                    ),
                    _MetreurList(
                      items: _toClose,
                      emptyLabel: 'Rien à clôturer.',
                      onCardTap: (item) => _showRequestDetails(context, item),
                      onPlanifierPose: (item) => _openPlanner(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  void _openPlanner() {
    if (_workspaceId == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: const Text('Planning', style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800)),
          iconTheme: const IconThemeData(color: AppColors.grey600),
        ),
        body: WiSwipeBack(child: PlannerScreen(workspaceId: _workspaceId!, accentColor: AppColors.roleMetteur)),
      ),
    ));
  }

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const SettingsScreen(),
    ));
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.cardBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _MetNavItem(icon: Icons.home_rounded, label: 'Accueil', active: true, onTap: () {}),
              _MetNavItem(icon: Icons.calendar_month_outlined, label: 'Agenda', active: false, onTap: _openPlanner),
              _MetNavItem(icon: Icons.settings_outlined, label: 'Réglages', active: false, onTap: _openSettings),
            ],
          ),
        ),
      ),
    );
  }

  WiDevisSummary _toSummary(BuildContext context, _MeasureCardData data) {
    return WiDevisSummary(
      id: data.id,
      clientLabel: data.title,
      address: data.address,
      status: data.status ?? '',
      statusLabel: (data.status?.isEmpty ?? true)
          ? 'Nouvelle demande'
          : (data.status == 'En pose' ? 'Programmé' : data.status!),
      statusColor: _MetCard._accentColor(data.status),
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      onTap: () => _showRequestDetails(context, data),
    );
  }

  void _showRequestDetails(BuildContext context, _MeasureCardData data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _metreurCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.grey200,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                data.title,
                style: const TextStyle(
                  color: AppColors.grey900,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              _SummaryLine(
                icon: Icons.place_outlined,
                label: 'Adresse',
                value: data.address,
              ),
              _SummaryLine(
                icon: Icons.dashboard_customize_outlined,
                label: 'Métré de',
                value: data.category ?? 'Catégorie transmise par le commercial',
              ),
              _SummaryLine(
                icon: Icons.schedule,
                label: 'Reçue',
                value: data.updated ?? 'À l’instant',
              ),
              if (data.phone != null)
                _SummaryLine(
                  icon: Icons.phone_outlined,
                  label: 'Contact',
                  value: data.phone!,
                ),
              const SizedBox(height: 8),
              Text(
                data.note,
                style: const TextStyle(color: AppColors.grey500),
              ),
              const SizedBox(height: 18),
              _PrimaryAction(
                label: 'Ouvrir',
                icon: Icons.open_in_new,
                onPressed: () => _openRequestSummary(context, data),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openRequestSummary(BuildContext context, _MeasureCardData data) {
    Navigator.of(context).pop();
    Future.microtask(() {
      Navigator.of(context).push(
        MaterialPageRoute(
        builder: (_) => _MeasureRequestSummary(
          data: data,
          workspaceId: _workspaceId,
          canConfirmOrder: _canPlaceOrders,
          onAccept: () => _acceptRequest(context, data),
          onAskInfo: () => _askForInfo(context, data),
          onSchedule: () => _scheduleMeeting(data),
          onConfirmOrder: () => _confirmOrder(context, data),
          onSchedulePose: () {
            // Planifier la pose se fait maintenant depuis l'agenda (glisser-
            // déposer le chantier — encore en backlog "À planifier" — sur la
            // bonne date), plutôt que via l'ancien sélecteur date/heure/
            // poseurs autonome (`_schedulePose`, conservé mais plus appelé).
            Navigator.of(context).pop();
            _openPlanner();
          },
          onRefresh: _loadRequests,
        ),
      ),
    );
  });
}

  Future<void> _acceptRequest(BuildContext context, _MeasureCardData data) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(this.context);
    setState(() {
      _newRequests.removeWhere((e) => e.id == data.id);
      final alreadyAccepted = _acceptedRequests.any((e) => e.id == data.id);
      if (!alreadyAccepted) {
        _acceptedRequests.add(
          data.copyWith(
            status: 'Acceptée',
            updated: 'Acceptée à l’instant',
            metreurId: _userId,
            workspaceId: _workspaceId,
          ),
        );
      }
    });
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Demande acceptée — commercial et admin mis à jour.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (_workspaceId != null) {
      try {
        await DevisService.updateStatus(
          workspaceId: _workspaceId!,
          devisId: data.id,
          newStatus: 'Acceptée',
          extraFields: const {'updated': 'Acceptée à l’instant'},
        );
      } catch (_) {}
    }
    await _saveToPrefs();
  }

  void _askForInfo(BuildContext context, _MeasureCardData data) {
    final navigator = Navigator.of(context);
    navigator.pop();
    Future.microtask(() {
      final ctrl = TextEditingController();
      showModalBottomSheet(
        context: this.context,
        backgroundColor: _metreurCard,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => Padding(
          padding: EdgeInsets.fromLTRB(
            16, 12, 16,
            MediaQuery.of(this.context).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSt) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.grey200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, color: AppColors.grey500),
                      SizedBox(width: 8),
                      Text(
                        'Demander des informations',
                        style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    autofocus: true,
                    style: const TextStyle(color: AppColors.grey900),
                    decoration: InputDecoration(
                      hintText: 'Ex: ajoutez les plans de façade ou les accès au chantier…',
                      hintStyle: const TextStyle(color: AppColors.grey400),
                      filled: true,
                      fillColor: AppColors.grey50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.grey50),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _metreurAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _PrimaryAction(
                      label: 'Envoyer au commercial',
                      icon: Icons.send,
                      onPressed: () async {
                        final msg = ctrl.text.trim();
                        if (msg.isEmpty) return;
                        Navigator.of(this.context).pop();
                        if (_workspaceId != null) {
                          await _firestore
                              .collection('workspaces')
                              .doc(_workspaceId)
                              .collection('devis')
                              .doc(data.id)
                              .set({
                            'metreurNote': msg,
                            'metreurNoteName': '${_userFirstName ?? ''} ${_userLastName ?? ''}'.trim(),
                            'metreurNoteAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Message envoyé au commercial.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ).whenComplete(() => ctrl.dispose());
    });
  }

  Future<DateTime?> _scheduleMeeting(_MeasureCardData data) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return null;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!mounted) return dt;
    setState(() {
      final updated = data.copyWith(meetingAt: dt, status: 'En cours');
      _newRequests = _newRequests.where((e) => e.id != data.id).toList();
      _acceptedRequests = [
        ..._acceptedRequests.where((e) => e.id != data.id),
        updated,
      ];
    });
    if (_workspaceId != null) {
      try {
        await DevisService.updateStatus(
          workspaceId: _workspaceId!,
          devisId: data.id,
          newStatus: 'En cours',
          // .toUtc() : voir planner_screen.dart _confirm() pour le pourquoi
          // (sans ça, le serveur lit l'heure locale comme si elle était UTC).
          extraFields: {'meetingAt': dt.toUtc().toIso8601String()},
        );
      } catch (_) {}
    }
    await _saveToPrefs();
    return dt;
  }

  Future<void> _markPoseAProgrammer(_MeasureCardData item) async {
    final wsId = item.workspaceId ?? _workspaceId;
    if (wsId == null) return;
    setState(() {
      _toOrder = _toOrder.where((e) => e.id != item.id).toList();
      _toPlan = [..._toPlan, item.copyWith(status: 'À planifier', updated: 'Pose à programmer')];
    });
    try {
      await DevisService.updateStatus(
        workspaceId: wsId,
        devisId: item.id,
        newStatus: 'À planifier',
        extraFields: const {'updated': 'Pose à programmer'},
      );
    } catch (_) {}
  }

  void _confirmOrder(BuildContext context, _MeasureCardData data) {
    Navigator.of(context).pop();
    Future.microtask(() async {
      await _markPoseAProgrammer(data);
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(
            content: Text('Commande confirmée — passage en planification de pose.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Future<void> _schedulePose(BuildContext context, _MeasureCardData data) async {
    final navigator = Navigator.of(context);
    navigator.pop();
    if (_workspaceId == null) return;

    var poseurs = <Map<String, String>>[];
    try {
      final snap = await _firestore
          .collection('users')
          .where('workspaceId', isEqualTo: _workspaceId)
          .get();
      poseurs = snap.docs
          .where((d) => d.data()['role'] == 'poseur' && d.data()['status'] != 'disabled')
          .map((d) => {
                'id': d.id,
                'name': '${d.data()['firstName'] ?? ''} ${d.data()['lastName'] ?? ''}'.trim(),
              })
          .toList();
    } catch (_) {}

    if (!mounted) return;
    final date = await showDatePicker(
      context: this.context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: this.context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    final selectedIds = <String>{};

    if (!mounted) return;
    await showModalBottomSheet(
      context: this.context,
      backgroundColor: _metreurCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          16, 12, 16,
          MediaQuery.of(this.context).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSt) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.grey200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const Row(
                  children: [
                    Icon(Icons.groups_outlined, color: AppColors.grey500),
                    SizedBox(width: 8),
                    Text(
                      'Programmer la pose',
                      style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Pose le ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
                  'à ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppColors.grey500),
                ),
                const SizedBox(height: 12),
                if (poseurs.isEmpty)
                  const Text(
                    'Aucun poseur dans l\'équipe — ajoutez-en depuis Admin > Équipe.',
                    style: TextStyle(color: AppColors.grey500),
                  )
                else
                  ...poseurs.map((p) => CheckboxListTile(
                        value: selectedIds.contains(p['id']),
                        onChanged: (v) => setSt(() {
                          if (v == true) {
                            selectedIds.add(p['id']!);
                          } else {
                            selectedIds.remove(p['id']!);
                          }
                        }),
                        title: Text(
                          p['name']!.isEmpty ? p['id']! : p['name']!,
                          style: const TextStyle(color: AppColors.grey900),
                        ),
                        activeColor: _metreurAccent,
                        contentPadding: EdgeInsets.zero,
                      )),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _PrimaryAction(
                    label: 'Confirmer la pose',
                    icon: Icons.check,
                    onPressed: () async {
                      final poseurIds = selectedIds.toList();
                      final poseurNames = poseurs
                          .where((p) => selectedIds.contains(p['id']))
                          .map((p) => p['name']!.isEmpty ? p['id']! : p['name']!)
                          .join(', ');
                      Navigator.of(ctx).pop();
                      try {
                        await DevisService.updateStatus(
                          workspaceId: _workspaceId!,
                          devisId: data.id,
                          newStatus: 'En pose',
                          extraFields: {
                            'poseDate': dt.toUtc().toIso8601String(),
                            'poseurIds': poseurIds,
                            'poseurNames': poseurNames,
                            'updated': 'Pose programmée',
                          },
                        );
                      } catch (_) {}
                      if (mounted) {
                        setState(() {
                          _toPlan = _toPlan
                              .map((e) => e.id == data.id
                                  ? e.copyWith(status: 'En pose', updated: 'Pose programmée')
                                  : e)
                              .toList();
                        });
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('Pose programmée — poseur(s) notifié(s).'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

}

class _PrioritiesSection extends StatelessWidget {
  const _PrioritiesSection({required this.title, required this.items});

  final String title;
  final List<_PriorityItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _metreurCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey100),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, color: AppColors.grey500, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.grey900,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PriorityCard(item: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.item});

  final _PriorityItem item;

  @override
  Widget build(BuildContext context) {
    final tagColor = item.tag == 'Terrain' ? Colors.orangeAccent : Colors.blueGrey;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey100),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.grey50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: AppColors.grey500, size: 16),
                    const SizedBox(width: 6),
                    Text(item.time, style: const TextStyle(color: AppColors.grey900)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _Tag(label: item.tag, color: tagColor),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.navigation_outlined, color: AppColors.grey500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.address,
            style: const TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.client} • ${item.quote}',
            style: const TextStyle(color: AppColors.grey500),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.grey900,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

class _MeasureCard extends StatelessWidget {
  const _MeasureCard({
    required this.data,
    required this.tag,
    required this.tagColor,
    required this.actions,
  });

  final _MeasureCardData data;
  final String tag;
  final Color tagColor;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _metreurCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey100),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Tag(label: tag, color: tagColor),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.title,
            style: const TextStyle(
              color: AppColors.grey900,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.grey500),
          ),
          if (data.meetingAt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.event_available_outlined, color: AppColors.grey400, size: 18),
                const SizedBox(width: 6),
                Text(
                  _formatMeeting(data.meetingAt!),
                  style: const TextStyle(color: AppColors.grey500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.grey900,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PriorityItem {
  _PriorityItem({
    required this.time,
    required this.address,
    required this.client,
    required this.quote,
    required this.tag,
  });

  final String time;
  final String address;
  final String client;
  final String quote;
  final String tag;
}

/// Résumé d'un lot (Phase 3, multi-lots) — `workspaces/{id}/devis/{devisId}/
/// lots/{lotId}`. Les instances construites depuis le champ dénormalisé
/// `lotsSummary` du devis (liste des chantiers, chips de statut) n'ont pas
/// `dependsOn`/`teamId`/`estimatedDurationDays` renseignés (non dénormalisés,
/// pour ne pas alourdir chaque carte) ; l'écran de détail (
/// `_MeasureRequestSummary`) lit le document lot complet via une
/// souscription dédiée à l'ouverture pour les avoir.
class _LotSummary {
  const _LotSummary({
    required this.lotId,
    required this.metierKey,
    required this.label,
    required this.status,
    this.poseurIds = const [],
    this.poseurNames = '',
    this.poseDate,
    this.teamId,
    this.dependsOn = const [],
  });

  final String lotId;
  final String metierKey;
  final String label;
  final String status;
  final List<String> poseurIds;
  final String poseurNames;
  final DateTime? poseDate;
  final String? teamId;
  final List<String> dependsOn;

  factory _LotSummary.fromMap(String lotId, Map<String, dynamic> map) {
    return _LotSummary(
      lotId: lotId,
      metierKey: map['metierKey']?.toString() ?? lotId,
      label: map['label']?.toString().isNotEmpty == true ? map['label'].toString() : lotId,
      status: map['status']?.toString() ?? 'À commander',
      poseurIds: (map['poseurIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      poseurNames: map['poseurNames']?.toString() ?? '',
      poseDate: map['poseDate'] is Timestamp ? (map['poseDate'] as Timestamp).toDate() : null,
      teamId: map['teamId']?.toString(),
      dependsOn: (map['dependsOn'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class _MeasureCardData {
  _MeasureCardData({
    required this.id,
    required this.title,
    required this.address,
    required this.note,
    this.status,
    this.updated,
    this.phone,
    this.category,
    this.summary = const [],
    this.attachments = const [],
    this.meetingAt,
    this.commercialId,
    this.metreurId,
    this.workspaceId,
    this.draft,
    this.lotIds = const [],
    this.lotsSummary = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String address;
  final String note;
  final String? status;
  final String? updated;
  final String? phone;
  final String? category;
  final List<_SummaryEntry> summary;
  final List<_AttachmentData> attachments;
  final DateTime? meetingAt;
  final String? commercialId;
  final String? metreurId;
  final String? workspaceId;
  final _QuoteDraft? draft;
  // Phase 3 (multi-lots) : présent (non vide) uniquement une fois le métré
  // terminé — voir le commentaire sur transitionDevisStatus côté Cloud
  // Function pour le moment exact de naissance des lots.
  final List<String> lotIds;
  final List<_LotSummary> lotsSummary;
  // Section "chantiers récemment ajoutés" (écran d'accueil) : lus depuis les
  // champs déjà écrits côté serveur, aucune écriture cliente supplémentaire.
  final DateTime? createdAt;
  final DateTime? updatedAt;

  _MeasureCardData copyWith({
    String? id,
    String? title,
    String? address,
    String? note,
    String? status,
    String? updated,
    String? phone,
    String? category,
    List<_SummaryEntry>? summary,
    List<_AttachmentData>? attachments,
    DateTime? meetingAt,
    String? commercialId,
    String? metreurId,
    String? workspaceId,
    _QuoteDraft? draft,
    List<String>? lotIds,
    List<_LotSummary>? lotsSummary,
  }) {
    return _MeasureCardData(
      id: id ?? this.id,
      title: title ?? this.title,
      address: address ?? this.address,
      note: note ?? this.note,
      status: status ?? this.status,
      updated: updated ?? this.updated,
      phone: phone ?? this.phone,
      category: category ?? this.category,
      summary: summary ?? this.summary,
      attachments: attachments ?? this.attachments,
      meetingAt: meetingAt ?? this.meetingAt,
      commercialId: commercialId ?? this.commercialId,
      metreurId: metreurId ?? this.metreurId,
      workspaceId: workspaceId ?? this.workspaceId,
      draft: draft ?? this.draft,
      lotIds: lotIds ?? this.lotIds,
      lotsSummary: lotsSummary ?? this.lotsSummary,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'address': address,
      'note': note,
      'status': status,
      'updated': updated,
      'phone': phone,
      'category': category,
      'summary': summary.map((e) => e.toMap()).toList(),
      'attachments': attachments.map((e) => e.toMap()).toList(),
      'meetingAt': meetingAt?.toIso8601String(),
      'commercialId': commercialId,
      'metreurId': metreurId,
      'workspaceId': workspaceId,
      'draft': draft?.toMap(),
      'lotIds': lotIds,
    };
  }

  factory _MeasureCardData.fromMap(Map<String, dynamic> map) {
    final id = map['id']?.toString() ?? '';
    final address = map['address']?.toString() ?? '';
    final number = map['number']?.toString() ?? '';
    final client = map['client']?.toString() ?? '';
    final baseTitle = [number.isNotEmpty ? '#$number' : '', client].where((e) => e.isNotEmpty).join(' - ');
    final title =
        map['title']?.toString().isNotEmpty == true ? map['title'].toString() : baseTitle.isNotEmpty ? baseTitle : address;
    return _MeasureCardData(
      id: id.isNotEmpty ? id : (number.isNotEmpty ? number : address),
      title: title.isNotEmpty ? title : 'Demande $id',
      address: address,
      note: map['note']?.toString() ?? map['chantierNotes']?.toString() ?? '',
      status: map['metreurStatus']?.toString() ?? map['status']?.toString(),
      updated: map['updated']?.toString(),
      phone: map['phone']?.toString(),
      category: map['category']?.toString(),
      summary: (map['summary'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(_SummaryEntry.fromMap)
          .toList(),
      attachments: (map['attachments'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(_AttachmentData.fromMap)
          .toList(),
      meetingAt: map['meetingAt'] is Timestamp
          ? (map['meetingAt'] as Timestamp).toDate()
          : (map['meetingAt'] != null ? DateTime.tryParse(map['meetingAt'].toString()) : null),
      commercialId: map['userId']?.toString(),
      metreurId: (map['metreurId'] ?? map['assignedMetreurId'])?.toString(),
      workspaceId: map['workspaceId']?.toString(),
      draft: map['draft'] is Map<String, dynamic> ? _QuoteDraft.fromMap(map['draft'] as Map<String, dynamic>) : null,
      lotIds: (map['lotIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      lotsSummary: (map['lotsSummary'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((m) => _LotSummary.fromMap(m['lotId']?.toString() ?? '', m))
          .toList(),
      createdAt: map['createdAt'] is Timestamp ? (map['createdAt'] as Timestamp).toDate() : null,
      updatedAt: map['updatedAt'] is Timestamp ? (map['updatedAt'] as Timestamp).toDate() : null,
    );
  }
}

class _MetPillTab extends StatelessWidget {
  const _MetPillTab({required this.label, this.isSelected = false});
  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.purple : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: isSelected ? null : Border.all(color: AppColors.grey200, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.grey600,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// Même design que `WiStat`/`WiStatRow` côté commercial (carte blanche,
// ombre légère, chiffre centré coloré + libellé gris) — la grille 2x3
// existante est conservée pour garder les 6 vignettes visibles sans
// scroll horizontal (contrairement à `WiStatRow` au-delà de 3 stats).
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
  });
  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.grey400),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vue lecture seule du métré déjà réalisé — remplace l'ancien accès direct
/// au formulaire d'édition une fois le statut passé en "À commander" (voir
/// `_openMetreDetail`). Le bouton "Imprimer le métré" réutilise le même
/// moteur de documents (`bon_commande`, mesures incluses) que le bouton
/// imprimante du formulaire de prise de mesure.
class _MetreDetailScreen extends StatefulWidget {
  const _MetreDetailScreen({required this.data, required this.workspaceId});
  final _MeasureCardData data;
  final String? workspaceId;

  @override
  State<_MetreDetailScreen> createState() => _MetreDetailScreenState();
}

class _MetreDetailScreenState extends State<_MetreDetailScreen> {
  bool _printing = false;

  Future<void> _printMetre() async {
    final workspaceId = widget.workspaceId;
    if (workspaceId == null) return;
    setState(() => _printing = true);
    try {
      await DocumentEngine.generateAndShare(
        templateId: 'bon_commande',
        workspaceId: workspaceId,
        devisId: widget.data.id,
        devisData: (widget.data.draft ?? const _QuoteDraft()).toMap(),
        generatedByRole: 'metreur',
        products: (widget.data.draft?.products ?? const <_ProductFormData>[]).map((e) => e.toMap()).toList(),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de générer le métré.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label : ', style: const TextStyle(color: AppColors.grey400, fontSize: 13)),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppColors.grey900, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.data.draft?.products ?? const <_ProductFormData>[];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.grey600),
        title: Text(
          'Métré — ${widget.data.title}',
          style: const TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.data.address, style: const TextStyle(color: AppColors.grey400, fontSize: 13)),
            const SizedBox(height: 16),
            ...products.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              final hasMeasurements = (p.largeurReelle?.isNotEmpty == true) ||
                  (p.hauteurReelle?.isNotEmpty == true) ||
                  (p.note?.isNotEmpty == true) ||
                  (p.cjHaut?.isNotEmpty == true);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.grey50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.grey100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _metreurAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Élément ${i + 1}',
                        style: const TextStyle(color: _metreurAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (p.categoryKey != null) _row('Catégorie', p.categoryKey!),
                    if (p.sousCategorie != null) _row('Type', p.sousCategorie!),
                    if (p.couleur != null) _row('Couleur', p.couleur!),
                    if (p.largeur != null || p.hauteur != null)
                      _row('Dim. prévue', '${p.largeur ?? '-'} x ${p.hauteur ?? '-'} ${p.unite}'),
                    if (hasMeasurements) ...[
                      const Divider(height: 20, color: AppColors.grey100),
                      if (p.largeurReelle?.isNotEmpty == true || p.hauteurReelle?.isNotEmpty == true)
                        _row('Dim. réelle', '${p.largeurReelle ?? '-'} x ${p.hauteurReelle ?? '-'} ${p.unite}'),
                      if (p.cjHaut?.isNotEmpty == true) _row('Cote jour haut', p.cjHaut!),
                      if (p.note?.isNotEmpty == true) _row('Note métreur', p.note!),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _metreurAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _printing ? null : _printMetre,
              icon: _printing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.print_outlined),
              label: const Text('Imprimer le métré'),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetreurList extends StatelessWidget {
  const _MetreurList({
    required this.items,
    required this.emptyLabel,
    required this.onCardTap,
    this.onPlanifierPose,
  });
  final List<_MeasureCardData> items;
  final String emptyLabel;
  final void Function(_MeasureCardData) onCardTap;
  final void Function(_MeasureCardData)? onPlanifierPose;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(emptyLabel, style: const TextStyle(color: AppColors.grey400)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _MetCard(
        data: items[i],
        onTap: () => onCardTap(items[i]),
        onPlanifierPose: onPlanifierPose == null ? null : () => onPlanifierPose!(items[i]),
      ),
    );
  }
}

class _MetCard extends StatelessWidget {
  const _MetCard({required this.data, required this.onTap, this.onPlanifierPose});
  final _MeasureCardData data;
  final VoidCallback onTap;
  // Statuts 'À planifier'/'En pose' : la pose se planifie depuis l'agenda
  // (glisser-déposer), pas depuis la fiche — voir _MeasureRequestSummary.
  // Si non fourni, la carte retombe sur onTap comme les autres statuts.
  final VoidCallback? onPlanifierPose;

  static Color _accentColor(String? s) {
    if (s == 'En cours' || s == 'Acceptée' || s == 'RDV métré' || s == 'Métré programmé') {
      return AppColors.purple;
    }
    if (s == 'À commander' || s == 'Commande en cours') return AppColors.warning;
    if (s == 'À planifier' || s == 'En pose' || s == 'Chantier à planifier') return AppColors.primary;
    // Phase 5 : À clôturer = rapport soumis, en attente de validation par le
    // responsable — plus un état terminal (Terminé/Clôturé/SAV le sont).
    if (s == 'À clôturer') return AppColors.warning;
    if (s == 'Terminé' || s == 'Clôturé' || s == 'SAV') return AppColors.success;
    return AppColors.warning;
  }

  static int _step(String? s) {
    if (s == null || s == 'Nouvelle demande' || s == 'En attente') return 0;
    if (s == 'Acceptée' || s == 'RDV métré' || s == 'Métré programmé') return 1;
    if (s == 'En cours') return 2;
    if (s == 'À commander') return 3;
    if (s == 'Commande en cours') return 4;
    if (s == 'À planifier' || s == 'En pose' || s == 'Chantier à planifier') return 5;
    return 6;
  }

  static String _ctaLabel(String? s) {
    if (s == 'Acceptée' || s == 'Métré programmé' || s == 'RDV métré') return 'Saisir métré';
    if (s == 'En cours') return 'Saisir métré';
    if (s == 'À commander') return 'Commander';
    if (s == 'Commande en cours') return 'Confirmer';
    // 'En pose' veut dire qu'une équipe/date sont déjà posées (voir
    // scheduledDates) — seul 'À planifier' correspond à un chantier pas
    // encore glissé dans l'agenda, distinction perdue avant ce correctif.
    if (s == 'À planifier') return 'Planifier pose';
    if (s == 'En pose') return 'Voir le planning';
    if (s == 'À clôturer') return 'En attente de validation';
    if (s == 'Terminé' || s == 'Clôturé' || s == 'SAV') return 'Clôturer';
    return 'Accepter';
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(data.status);
    final step = _step(data.status);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.grey900,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        WiUnreadMessageBadge(devisId: data.id, workspaceId: data.workspaceId),
                        const SizedBox(width: 6),
                        _MetStatusBadge(status: data.status, accent: accent),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                    ),
                    if (data.updated != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        data.updated!,
                        style: const TextStyle(color: AppColors.grey300, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Step dots (même style que l'écran commercial)
                    Row(
                      children: List.generate(7, (i) {
                        final done = i <= step;
                        final active = i == step;
                        return Container(
                          width: active ? 18 : 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: done ? accent : AppColors.grey200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              side: const BorderSide(color: AppColors.grey200),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: onTap,
                            child: const Text(
                              'Voir détails',
                              style: TextStyle(
                                color: AppColors.grey700,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed:
                                (data.status == 'À planifier' || data.status == 'En pose') &&
                                        onPlanifierPose != null
                                    ? onPlanifierPose
                                    : onTap,
                            child: Text(
                              _ctaLabel(data.status),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetStatusBadge extends StatelessWidget {
  const _MetStatusBadge({required this.status, required this.accent});
  final String? status;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // "Programmé" plutôt que le statut serveur brut "En pose" : ce dernier
    // est atteint dès qu'une équipe/date sont posées dans l'agenda, pas
    // forcément au moment réel de la pose — libellé jugé trompeur.
    final label = status == 'En pose' ? 'Programmé' : (status ?? 'En attente');
    final bg = accent.withOpacity(0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
class _SummaryEntry {
  const _SummaryEntry({required this.label, required this.value});
  final String label;
  final String value;

  Map<String, dynamic> toMap() => {'label': label, 'value': value};
  factory _SummaryEntry.fromMap(Map<String, dynamic> map) =>
      _SummaryEntry(label: map['label']?.toString() ?? '', value: map['value']?.toString() ?? '');
}

class _AttachmentData {
  const _AttachmentData({
    required this.label,
    required this.icon,
    this.thumbnailUrl,
    this.thumbnailAsset,
  });
  final String label;
  final IconData icon;
  final String? thumbnailUrl;
  final String? thumbnailAsset;

  Map<String, dynamic> toMap() => {
        'label': label,
        'icon': icon.codePoint,
        'thumbnailUrl': thumbnailUrl,
        'thumbnailAsset': thumbnailAsset,
      };

  factory _AttachmentData.fromMap(Map<String, dynamic> map) => _AttachmentData(
        label: map['label']?.toString() ?? '',
        icon: Icons.picture_as_pdf,
        thumbnailUrl: map['thumbnailUrl']?.toString(),
        thumbnailAsset: map['thumbnailAsset']?.toString(),
      );
}

void _callNumber(BuildContext context, String number) async {
  final uri = Uri.parse('tel:$number');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Impossible d’appeler $number'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

void _openAttachment(BuildContext context, _AttachmentData data) async {
  if (data.thumbnailUrl != null && await canLaunchUrl(Uri.parse(data.thumbnailUrl!))) {
    await launchUrl(Uri.parse(data.thumbnailUrl!), mode: LaunchMode.inAppWebView);
  } else {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Impossible d’ouvrir ${data.label}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}

String _formatMeeting(DateTime dt) {
  final twoDigits = (int n) => n.toString().padLeft(2, '0');
  return 'Rendez-vous le ${twoDigits(dt.day)}/${twoDigits(dt.month)}/${dt.year} à ${twoDigits(dt.hour)}:${twoDigits(dt.minute)}';
}

class _StatusList extends StatelessWidget {
  const _StatusList({
    required this.tag,
    required this.tagColor,
    required this.items,
    required this.emptyLabel,
    required this.actionsBuilder,
  });

  final String tag;
  final Color tagColor;
  final List<_MeasureCardData> items;
  final String emptyLabel;
  final List<Widget> Function(_MeasureCardData) actionsBuilder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyLabel,
            style: const TextStyle(color: AppColors.grey400),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final item = items[index];
        return _MeasureCard(
          data: item,
          tag: tag,
          tagColor: tagColor,
          actions: actionsBuilder(item),
        );
      },
    );
  }
}

class _ProductFormData {
  const _ProductFormData({
    this.metierKey,
    this.categoryKey,
    this.sousCategorie,
    this.typeProduit,
    this.variante,
    this.couleur,
    this.couleurDetail,
    this.largeur,
    this.hauteur,
    this.quantite,
    this.unite = 'mm',
    // Measurement fields
    this.largeurReelle,
    this.hauteurReelle,
    this.cjHaut,
    this.cjBas,
    this.cjGauche,
    this.cjDroite,
    this.note,
    this.ref,
    this.aiHint,
  });

  /// Métier choisi pour cet élément (voir _ProductFormData équivalent dans
  /// commercial_home_screen.dart — un devis peut mélanger plusieurs métiers).
  final String? metierKey;
  final String? categoryKey;
  final String? sousCategorie;
  final String? typeProduit;
  final String? variante;
  final String? couleur;
  final String? couleurDetail;
  final int? largeur;
  final int? hauteur;
  final int? quantite;
  final String unite;
  // Measurement fields
  final String? largeurReelle;
  final String? hauteurReelle;
  final String? cjHaut;
  final String? cjBas;
  final String? cjGauche;
  final String? cjDroite;
  final String? note;
  final String? ref;
  // Suggestion textuelle libre (extraction IA du devis, ou vide si compté à
  // la main) — voir _ProductFormData équivalent dans commercial_models.dart.
  final String? aiHint;

  Map<String, dynamic> toMap() {
    return {
      'metierKey': metierKey,
      'categoryKey': categoryKey,
      'sousCategorie': sousCategorie,
      'typeProduit': typeProduit,
      'variante': variante,
      'couleur': couleur,
      'couleurDetail': couleurDetail,
      'largeur': largeur,
      'hauteur': hauteur,
      'quantite': quantite,
      'unite': unite,
      // Measurement fields
      'largeurReelle': largeurReelle,
      'hauteurReelle': hauteurReelle,
      'cjHaut': cjHaut,
      'cjBas': cjBas,
      'cjGauche': cjGauche,
      'cjDroite': cjDroite,
      'note': note,
      'ref': ref,
      'aiHint': aiHint,
    };
  }

  factory _ProductFormData.fromMap(Map<String, dynamic> map) {
    return _ProductFormData(
      metierKey: map['metierKey']?.toString(),
      categoryKey: map['categoryKey']?.toString(),
      sousCategorie: map['sousCategorie']?.toString(),
      typeProduit: map['typeProduit']?.toString(),
      variante: map['variante']?.toString(),
      couleur: map['couleur']?.toString(),
      couleurDetail: map['couleurDetail']?.toString(),
      largeur: map['largeur'] is int ? map['largeur'] as int : int.tryParse(map['largeur']?.toString() ?? ''),
      hauteur: map['hauteur'] is int ? map['hauteur'] as int : int.tryParse(map['hauteur']?.toString() ?? ''),
      quantite: map['quantite'] is int ? map['quantite'] as int : int.tryParse(map['quantite']?.toString() ?? ''),
      unite: map['unite']?.toString() ?? 'mm',
      // Measurement fields
      largeurReelle: map['largeurReelle']?.toString(),
      hauteurReelle: map['hauteurReelle']?.toString(),
      cjHaut: map['cjHaut']?.toString(),
      cjBas: map['cjBas']?.toString(),
      cjGauche: map['cjGauche']?.toString(),
      cjDroite: map['cjDroite']?.toString(),
      note: map['note']?.toString(),
      ref: map['ref']?.toString(),
      aiHint: map['aiHint']?.toString(),
    );
  }
}

class _QuoteDraft {
  const _QuoteDraft({
    this.clientName,
    this.clientFirstName,
    this.street,
    this.postal,
    this.city,
    this.phone,
    this.email,
    this.commentaire,
    this.chantierNotes,
    this.chantierType,
    this.typeHabitation,
    this.accessibilite,
    this.date,
    this.products = const [],
    this.assignedMetreurId,
    this.assignedMetreurName,
    this.soldEstimatedDurationDays,
    this.soldPoseurCountRequired,
    this.elementsCount,
    this.montantHT,
  });

  final String? clientName;
  final String? clientFirstName;
  final String? street;
  final String? postal;
  final String? city;
  final String? phone;
  final String? email;
  final String? commentaire;
  final String? chantierNotes;
  final String? chantierType;
  final String? typeHabitation;
  final String? accessibilite;
  final DateTime? date;
  final List<_ProductFormData> products;
  final String? assignedMetreurId;
  final String? assignedMetreurName;
  // Temps/poseurs vendus au client par le commercial — voir même champ côté
  // commercial_models.dart, lu ici en lecture seule pour pré-remplir la
  // confirmation obligatoire du métreur à la validation du métré.
  final int? soldEstimatedDurationDays;
  final int? soldPoseurCountRequired;
  final int? elementsCount;
  final double? montantHT;

  Map<String, dynamic> toMap() {
    return {
      'clientName': clientName,
      'clientFirstName': clientFirstName,
      'street': street,
      'postal': postal,
      'city': city,
      'phone': phone,
      'email': email,
      'commentaire': commentaire,
      'chantierNotes': chantierNotes,
      'chantierType': chantierType,
      'typeHabitation': typeHabitation,
      'accessibilite': accessibilite,
      'date': date?.toIso8601String(),
      'products': products.map((e) => e.toMap()).toList(),
      'assignedMetreurId': assignedMetreurId,
      'assignedMetreurName': assignedMetreurName,
      'soldEstimatedDurationDays': soldEstimatedDurationDays,
      'soldPoseurCountRequired': soldPoseurCountRequired,
      'elementsCount': elementsCount,
      'montantHT': montantHT,
    };
  }

  factory _QuoteDraft.fromMap(Map<String, dynamic> map) {
    return _QuoteDraft(
      clientName: map['clientName']?.toString(),
      clientFirstName: map['clientFirstName']?.toString(),
      street: map['street']?.toString(),
      postal: map['postal']?.toString(),
      city: map['city']?.toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      commentaire: map['commentaire']?.toString(),
      chantierNotes: map['chantierNotes']?.toString(),
      chantierType: map['chantierType']?.toString(),
      typeHabitation: map['typeHabitation']?.toString(),
      accessibilite: map['accessibilite']?.toString(),
      date: map['date'] != null ? DateTime.tryParse(map['date'].toString()) : null,
      products: map['products'] is List
          ? (map['products'] as List)
              .map((e) {
                if (e is Map<String, dynamic>) return _ProductFormData.fromMap(e);
                if (e is Map) return _ProductFormData.fromMap(Map<String, dynamic>.from(e));
                return null;
              })
              .whereType<_ProductFormData>()
              .toList()
          : const [],
      assignedMetreurId: map['assignedMetreurId']?.toString(),
      assignedMetreurName: map['assignedMetreurName']?.toString(),
      soldEstimatedDurationDays: (map['soldEstimatedDurationDays'] as num?)?.toInt(),
      soldPoseurCountRequired: (map['soldPoseurCountRequired'] as num?)?.toInt(),
      elementsCount: (map['elementsCount'] as num?)?.toInt(),
      montantHT: (map['montantHT'] as num?)?.toDouble(),
    );
  }
}

class _MeasureRequestSummary extends StatefulWidget {
  const _MeasureRequestSummary({
    required this.data,
    required this.onAccept,
    required this.onAskInfo,
    required this.onSchedule,
    required this.onConfirmOrder,
    required this.onSchedulePose,
    this.onRefresh,
    this.workspaceId,
    this.canConfirmOrder = true,
  });

  final _MeasureCardData data;
  final VoidCallback onAccept;
  final VoidCallback onAskInfo;
  final Future<DateTime?> Function() onSchedule;
  final VoidCallback onConfirmOrder;
  final VoidCallback onSchedulePose;
  final VoidCallback? onRefresh;
  final String? workspaceId;
  final bool canConfirmOrder;

  @override
  State<_MeasureRequestSummary> createState() => _MeasureRequestSummaryState();
}

class _MeasureRequestSummaryState extends State<_MeasureRequestSummary> {
  DateTime? meetingAt;
  bool _generatingDoc = false;

  // Copie locale mutable de widget.data — widget.data lui-même ne change
  // jamais (capturé une fois à l'ouverture de l'écran), donc sans cette
  // copie, rouvrir "Modifier le métré" après une sauvegarde réaffichait un
  // formulaire vide au lieu des valeurs qu'on venait d'enregistrer.
  late _MeasureCardData _data;

  // Phase 3 (multi-lots) : les lots eux-mêmes (dependsOn compris) sont lus
  // en direct depuis la sous-collection à l'ouverture de cet écran de
  // détail plutôt que depuis le champ dénormalisé `lotsSummary` du devis
  // (qui ne porte pas `dependsOn`, pour ne pas alourdir chaque carte de la
  // liste). Vide tant que le métré n'est pas terminé (aucun lot créé).
  List<_LotSummary> _lots = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _lotsSub;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    meetingAt = widget.data.meetingAt;
    _subscribeLots();
  }

  void _subscribeLots() {
    final wsId = _data.workspaceId ?? widget.workspaceId;
    if (wsId == null) return;
    _lotsSub?.cancel();
    _lotsSub = FirebaseFirestore.instance
        .collection('workspaces')
        .doc(wsId)
        .collection('devis')
        .doc(_data.id)
        .collection('lots')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _lots = snap.docs.map((d) => _LotSummary.fromMap(d.id, d.data())).toList();
      });
    });
  }

  @override
  void dispose() {
    _lotsSub?.cancel();
    super.dispose();
  }

  Future<void> _generateBonPreparation() async {
    final data = _data;
    final workspaceId = data.workspaceId ?? widget.workspaceId ?? '';
    setState(() => _generatingDoc = true);
    try {
      await DocumentEngine.generateAndShare(
        templateId: 'bon_preparation',
        workspaceId: workspaceId,
        devisId: data.id,
        devisData: (data.draft ?? const _QuoteDraft()).toMap(),
        generatedByRole: 'metreur',
        products: (data.draft?.products ?? const <_ProductFormData>[]).map((e) => e.toMap()).toList(),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de générer le bon de préparation.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingDoc = false);
    }
  }

  void _openMetreDetail(_MeasureCardData data) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _MetreDetailScreen(
        data: data,
        workspaceId: data.workspaceId ?? widget.workspaceId,
      ),
    ));
  }

  Future<void> _openMeasurementForm(int initialIndex) async {
    final data = _data;
    // Navigate to Measurement Form and await result
    final updatedProducts = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeasurementFormScreen(
          draftData: (data.draft ?? const _QuoteDraft()).toMap(),
          initialIndex: initialIndex,
          workspaceId: data.workspaceId ?? widget.workspaceId ?? '',
          devisId: data.id,
        ),
      ),
    );

    if (updatedProducts != null && updatedProducts is List) {
      // Update local state and Firestore
      final updatedDraft = data.draft != null
          ? _QuoteDraft.fromMap({
              ...data.draft!.toMap(),
              'products': updatedProducts,
            })
          : null;

      // Sauvegarde immédiate des mesures saisies, indépendamment de la
      // transition de statut ci-dessous — les règles Firestore autorisent
      // l'écriture directe de tout champ sauf le statut. Si le métreur
      // annule ensuite la confirmation obligatoire durée/poseurs, ses
      // mesures restent acquises (sinon il faudrait tout ressaisir).
      final wsIdForDraft = data.workspaceId ?? widget.workspaceId;
      if (updatedDraft != null && wsIdForDraft != null) {
        try {
          await FirebaseFirestore.instance
              .collection('workspaces')
              .doc(wsIdForDraft)
              .collection('devis')
              .doc(data.id)
              .set({'draft': updatedDraft.toMap()}, SetOptions(merge: true));
        } catch (_) {}
        if (mounted) {
          setState(() => _data = _data.copyWith(draft: updatedDraft));
        }
      }

      // Phase 3 (multi-lots) : si ce passage en "À commander" est le premier
      // pour ce devis, la Cloud Function crée un lot par metierKey distinct
      // parmi les produits — elle a besoin des libellés métier (le
      // dictionnaire n'est pas accessible côté serveur) pour nommer les lots
      // créés, et calculées ici pour être aussi affichées dans la
      // confirmation obligatoire durée/poseurs ci-dessous.
      final isFirstValidation = updatedDraft != null && data.lotIds.isEmpty;
      final metierKeys = isFirstValidation
          ? updatedDraft.products
              .map((p) => p.metierKey)
              .whereType<String>()
              .where((k) => k.isNotEmpty)
              .toSet()
          : const <String>{};
      final metierLabels = <String, String>{};
      for (final key in metierKeys) {
        metierLabels[key] = await DictionaryService.instance.metierLabel(key);
      }

      // Obligatoire avant de pouvoir valider le métré : le métreur confirme
      // ou ajuste le temps/l'équipe vendus par le commercial (ou saisit une
      // valeur si le commercial n'en a transmis aucune) — ces valeurs
      // deviennent celles du/des lots créés par la transition ci-dessous.
      // Annuler ici laisse les mesures déjà sauvegardées ci-dessus intactes
      // et le statut inchangé — "Terminer et Valider" reste retentable.
      Map<String, Map<String, int>>? lotEstimates;
      if (metierKeys.isNotEmpty) {
        if (!mounted) return;
        lotEstimates = await _confirmScheduleEstimates(
          context,
          metierKeys: metierKeys,
          metierLabels: metierLabels,
          defaultDuration: data.draft?.soldEstimatedDurationDays,
          defaultPoseurCount: data.draft?.soldPoseurCountRequired,
        );
        if (lotEstimates == null) return; // annulé — métré pas encore validé
      }

      try {
        final wsId = data.workspaceId ?? widget.workspaceId;
        if (wsId == null) throw 'Workspace ID manquant';

        final extraFields = <String, dynamic>{'updated': 'Métré terminé'};
        if (updatedDraft != null) {
          extraFields['draft'] = updatedDraft.toMap();
          if (metierLabels.isNotEmpty) {
            extraFields['metierLabels'] = metierLabels;
          }
        }
        if (lotEstimates != null) {
          extraFields['lotEstimates'] = lotEstimates;
        }

        await DevisService.updateStatus(
          workspaceId: wsId,
          devisId: data.id,
          newStatus: 'À commander',
          extraFields: extraFields,
        );

        if (mounted) {
          setState(() {
            _data = _data.copyWith(
              draft: updatedDraft,
              status: 'À commander',
              updated: 'Métré terminé',
            );
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Métré enregistré avec succès'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: _metreurAccent,
            ),
          );
          // Refresh the parent list to show updated status/button
          if (widget.onRefresh != null) {
            widget.onRefresh!();
          }
        }
      } catch (e) {
        debugPrint('Error saving measurements: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'enregistrement: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Confirmation obligatoire du temps/de l'équipe avant de pouvoir valider
  /// le métré — un pair durée/poseurs par métier distinct du devis, pré-
  /// rempli avec l'estimation vendue par le commercial si transmise. Retourne
  /// `null` si le métreur annule (le métré reste non validé, réessayable).
  Future<Map<String, Map<String, int>>?> _confirmScheduleEstimates(
    BuildContext context, {
    required Set<String> metierKeys,
    required Map<String, String> metierLabels,
    int? defaultDuration,
    int? defaultPoseurCount,
  }) {
    return showModalBottomSheet<Map<String, Map<String, int>>>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: _metreurCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ScheduleEstimateSheet(
        metierKeys: metierKeys,
        metierLabels: metierLabels,
        defaultDuration: defaultDuration,
        defaultPoseurCount: defaultPoseurCount,
      ),
    );
  }

  // ─── Phase 3 (multi-lots) : actions par lot ────────────────────────────

  /// Libellé du premier lot bloquant parmi les dépendances de [lot] (pas
  /// encore Terminé/SAV — Phase 5 : À clôturer n'est plus terminal, c'est le
  /// statut pivot "rapport soumis, en attente de validation"), ou null si
  /// aucune dépendance ne bloque.
  String? _blockingDependencyLabel(_LotSummary lot) {
    for (final depId in lot.dependsOn) {
      final dep = _lots.where((l) => l.lotId == depId).toList();
      final depStatus = dep.isNotEmpty ? dep.first.status : null;
      if (depStatus != 'Terminé' && depStatus != 'SAV') {
        return dep.isNotEmpty ? dep.first.label : depId;
      }
    }
    return null;
  }

  Future<void> _confirmOrderLot(_LotSummary lot) async {
    final wsId = _data.workspaceId ?? widget.workspaceId;
    if (wsId == null) return;
    try {
      await DevisService.updateStatus(
        workspaceId: wsId,
        devisId: _data.id,
        newStatus: 'À planifier',
        lotId: lot.lotId,
        extraFields: const {'updated': 'Pose à programmer'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lot "${lot.label}" — commande confirmée.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Relance manuelle (notification, pas une transition de statut) : le
  /// métreur/admin relance les poseurs assignés quand le chantier semble
  /// terminé sur le terrain mais n'a jamais été clôturé dans l'appli.
  /// [lotId] absent pour un devis sans lot.
  Future<void> _sendRelanceCloture({String? lotId}) async {
    final wsId = _data.workspaceId ?? widget.workspaceId;
    if (wsId == null) return;
    try {
      await DevisService.sendRelance(
        workspaceId: wsId,
        devisId: _data.id,
        lotId: lotId,
        relanceType: 'cloture_manquante',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Relance envoyée aux poseurs assignés.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _schedulePoseLot(_LotSummary lot) async {
    final wsId = _data.workspaceId ?? widget.workspaceId;
    if (wsId == null) return;

    var poseurs = <Map<String, String>>[];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('workspaceId', isEqualTo: wsId)
          .get();
      poseurs = snap.docs
          .where((d) => d.data()['role'] == 'poseur' && d.data()['status'] != 'disabled')
          .map((d) => {
                'id': d.id,
                'name': '${d.data()['firstName'] ?? ''} ${d.data()['lastName'] ?? ''}'.trim(),
              })
          .toList();
    } catch (_) {}

    if (!mounted) return;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    final selectedIds = <String>{};
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: _metreurCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 24),
        child: StatefulBuilder(
          builder: (ctx, setSt) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.groups_outlined, color: AppColors.grey500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Programmer la pose — lot ${lot.label}',
                        style: const TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Pose le ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
                  'à ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppColors.grey500),
                ),
                const SizedBox(height: 12),
                if (poseurs.isEmpty)
                  const Text(
                    'Aucun poseur dans l\'équipe — ajoutez-en depuis Admin > Équipe.',
                    style: TextStyle(color: AppColors.grey500),
                  )
                else
                  ...poseurs.map((p) => CheckboxListTile(
                        value: selectedIds.contains(p['id']),
                        onChanged: (v) => setSt(() {
                          if (v == true) {
                            selectedIds.add(p['id']!);
                          } else {
                            selectedIds.remove(p['id']!);
                          }
                        }),
                        title: Text(
                          p['name']!.isEmpty ? p['id']! : p['name']!,
                          style: const TextStyle(color: AppColors.grey900),
                        ),
                        activeColor: _metreurAccent,
                        contentPadding: EdgeInsets.zero,
                      )),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _PrimaryAction(
                    label: 'Confirmer la pose',
                    icon: Icons.check,
                    onPressed: () async {
                      final poseurIds = selectedIds.toList();
                      final poseurNames = poseurs
                          .where((p) => selectedIds.contains(p['id']))
                          .map((p) => p['name']!.isEmpty ? p['id']! : p['name']!)
                          .join(', ');
                      Navigator.of(ctx).pop();
                      try {
                        await DevisService.updateStatus(
                          workspaceId: wsId,
                          devisId: _data.id,
                          newStatus: 'En pose',
                          lotId: lot.lotId,
                          extraFields: {
                            'poseDate': dt.toUtc().toIso8601String(),
                            'poseurIds': poseurIds,
                            'poseurNames': poseurNames,
                            'updated': 'Pose programmée',
                          },
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur : $e'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        return;
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('Lot "${lot.label}" — pose programmée.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _editLotDependencies(_LotSummary lot) async {
    final wsId = _data.workspaceId ?? widget.workspaceId;
    if (wsId == null) return;
    final others = _lots.where((l) => l.lotId != lot.lotId).toList();
    final selected = Set<String>.from(lot.dependsOn);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: _metreurCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 24),
        child: StatefulBuilder(
          builder: (ctx, setSt) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: AppColors.grey200, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.account_tree_outlined, color: AppColors.grey500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dépendances du lot ${lot.label}',
                        style: const TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'La pose de ce lot ne pourra démarrer qu\'une fois les lots cochés terminés.',
                  style: TextStyle(color: AppColors.grey500, fontSize: 12),
                ),
                const SizedBox(height: 8),
                if (others.isEmpty)
                  const Text('Aucun autre lot sur ce chantier.', style: TextStyle(color: AppColors.grey500))
                else
                  ...others.map((o) => CheckboxListTile(
                        value: selected.contains(o.lotId),
                        onChanged: (v) => setSt(() {
                          if (v == true) {
                            selected.add(o.lotId);
                          } else {
                            selected.remove(o.lotId);
                          }
                        }),
                        title: Text(o.label, style: const TextStyle(color: AppColors.grey900)),
                        activeColor: _metreurAccent,
                        contentPadding: EdgeInsets.zero,
                      )),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _PrimaryAction(
                    label: 'Enregistrer',
                    icon: Icons.check,
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      try {
                        await DevisService.setLotDependencies(
                          workspaceId: wsId,
                          devisId: _data.id,
                          lotId: lot.lotId,
                          dependsOn: selected.toList(),
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur : $e'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _lotActionRow(_LotSummary lot) {
    final blockedBy = _blockingDependencyLabel(lot);
    Widget action;
    switch (lot.status) {
      case 'À commander':
      case 'Commande en cours':
        action = widget.canConfirmOrder
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _confirmOrderLot(lot),
                child: const Text(
                  'Confirmer la commande',
                  style: TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              )
            : OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Commande réservée au commercial/admin',
                  style: TextStyle(fontSize: 11),
                ),
              );
        break;
      case 'À planifier':
        action = blockedBy != null
            ? OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Bloqué par : $blockedBy', style: const TextStyle(fontSize: 11)),
              )
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _schedulePoseLot(lot),
                child: const Text('Programmer la pose', style: TextStyle(fontSize: 12)),
              );
        break;
      case 'En pose':
        action = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'Pose programmée',
                style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            TextButton(
              onPressed: () => _sendRelanceCloture(lotId: lot.lotId),
              child: const Text('Relancer la clôture', style: TextStyle(fontSize: 12)),
            ),
          ],
        );
        break;
      default:
        action = Text(lot.status, style: const TextStyle(color: AppColors.grey500, fontSize: 12));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey100),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lot.label, style: const TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(lot.status, style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.account_tree_outlined, color: AppColors.grey400, size: 20),
              tooltip: 'Dépendances',
              onPressed: () => _editLotDependencies(lot),
            ),
            action,
          ],
        ),
      ),
    );
  }

  // Titre d'en-tête reflétant l'étape réelle du chantier — figé sur
  // "Demande de métré" jusque-là même une fois la commande passée (bug
  // constaté en test réel : le métré et la commande étaient faits, l'en-tête
  // n'avait pas bougé).
  String _titleForStatus(String? status) {
    switch (status) {
      case 'Acceptée':
      case 'En cours':
        return 'En attente de métré';
      case 'À commander':
      case 'Commande en cours':
        return 'En attente de commande';
      case 'À planifier':
        return 'En attente de plannification';
      case 'En pose':
        return 'En attente de pose';
      case 'À clôturer':
        return 'En attente de clôture';
      case 'Terminé':
      case 'Clôturé':
        return 'Chantier terminé';
      case 'SAV':
        return 'SAV';
      default:
        return 'Demande de métré';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    // Une fois le métré fait (statut au-delà de Acceptée/En cours), le
    // rendez-vous concernait la prise de mesures — sans rapport avec la
    // suite (commande/planification), donc plus affiché ni modifiable ici.
    final metreDone = data.status != null &&
        data.status != 'Nouvelle demande' &&
        data.status != 'Acceptée' &&
        data.status != 'En cours';
    return Scaffold(
      backgroundColor: _metreurBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.grey900, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _titleForStatus(data.status),
          style: const TextStyle(
            color: AppColors.grey900,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          ChatEntryButton(
            devisId: data.id,
            clientLabel: data.title,
            color: _metreurAccent,
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: AppColors.grey500),
            onPressed: () {},
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.title,
                            style: const TextStyle(
                              color: AppColors.grey900,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _SummaryLine(
                            icon: Icons.place_outlined,
                            label: 'Adresse',
                            value: data.address,
                          ),
                          const SizedBox(height: 8),
                          _SummaryLine(
                            icon: Icons.dashboard_customize_outlined,
                            label: 'Métré de',
                            value: data.category ?? 'Catégorie transmise par le commercial',
                          ),
                          _SummaryLine(
                            icon: Icons.schedule,
                            label: 'Reçue',
                            value: data.updated ?? 'À l’instant',
                          ),
                          if (meetingAt != null && !metreDone)
                            _SummaryLine(
                              icon: Icons.event_available_outlined,
                              label: 'Rendez-vous',
                              value: _formatMeeting(meetingAt!),
                            ),
                          if (data.phone != null)
                            _SummaryLine(
                              icon: Icons.phone_outlined,
                              label: 'Contact',
                              value: data.phone!,
                              trailing: TextButton(
                                onPressed: () => _callNumber(context, data.phone!),
                                child: const Text('Appeler', style: TextStyle(color: _metreurAccent)),
                              ),
                            ),
                          if (!metreDone) ...[
                            const SizedBox(height: 8),
                            _PrimaryAction(
                              label: meetingAt == null
                                  ? 'Prendre rendez-vous client'
                                  : 'Modifier rendez-vous client',
                              icon: Icons.calendar_month_outlined,
                              onPressed: () async {
                                final picked = await widget.onSchedule();
                                if (picked != null && mounted) {
                                  setState(() => meetingAt = picked);
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 12),
                    if (data.draft != null && data.draft!.products.isNotEmpty)
                      Builder(builder: (context) {
                        return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metreDone ? 'Éléments à commander' : 'Éléments à métrer',
                            style: const TextStyle(
                              color: AppColors.grey900,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          if (metreDone) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: _metreurAccent),
                                  foregroundColor: _metreurAccent,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () => _openMetreDetail(data),
                                icon: const Icon(Icons.straighten_outlined),
                                label: const Text('Voir le métré'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          ...data.draft!.products.asMap().entries.map((entry) {
                            final i = entry.key;
                            final p = entry.value;

                            // Helper to build rows
                            Widget _buildRow(String label, String value) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$label : ',
                                      style: const TextStyle(
                                          color: AppColors.grey400, fontSize: 13),
                                    ),
                                    Expanded(
                                      child: Text(
                                        value,
                                        style: const TextStyle(
                                            color: AppColors.grey900, fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: metreDone ? () => _openMetreDetail(data) : () => _openMeasurementForm(i),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.grey50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.grey100),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _metreurAccent.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Élément ${i + 1}',
                                              style: const TextStyle(
                                                color: _metreurAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          if (p.quantite != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: AppColors.grey100),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                'Qté: ${p.quantite}',
                                                style: const TextStyle(color: AppColors.grey500, fontSize: 12),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (p.categoryKey != null) _buildRow('Catégorie', p.categoryKey!),
                                      if (p.sousCategorie != null) _buildRow('Type', p.sousCategorie!),
                                      if (p.typeProduit != null && p.typeProduit != p.sousCategorie) _buildRow('Produit', p.typeProduit!),
                                      if (p.couleur != null) _buildRow('Couleur', p.couleur!),
                                      if (p.largeur != null || p.hauteur != null)
                                        _buildRow('Dim', '${p.largeur ?? '-'} x ${p.hauteur ?? '-'} ${p.unite}'),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                      })
                    else if (data.summary.isNotEmpty)
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Résumé',
                              style: TextStyle(
                                color: AppColors.grey900,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...data.summary
                                .map(
                                  (entry) => _SummaryLine(
                                    icon: Icons.check_circle_outline,
                                    label: entry.label,
                                    value: entry.value,
                                  ),
                                )
                                .toList(),
                          ],
                        ),
                      ),
                    if (data.summary.isNotEmpty) const SizedBox(height: 12),
                    if (data.note.trim().isNotEmpty)
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notes commerciales',
                              style: TextStyle(
                                color: AppColors.grey900,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              data.note,
                              style: const TextStyle(color: AppColors.grey500, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    if (data.note.trim().isNotEmpty) const SizedBox(height: 12),
                    if (data.attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pièces jointes',
                              style: TextStyle(
                                color: AppColors.grey900,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...data.attachments
                                .map(
                                  (att) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _AttachmentRow(
                                      data: att,
                                      onOpen: () => _openAttachment(context, att),
                                    ),
                                  ),
                                )
                                .toList(),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Section "Lots" (Phase 3 multi-lots) retirée de cet écran —
            // sa carte ne rendait rien d'exploitable ici (cas confirmé en
            // test réel sur un devis mono-lot passé en "En pose" : ligne
            // vide) et faisait doublon avec le suivi lot par lot déjà
            // disponible depuis l'agenda. `_lots`/`_lotActionRow` restent
            // en place, simplement plus affichés depuis cette fiche.
            if (data.status == 'À planifier' || data.status == 'En pose')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _metreurAccent),
                      foregroundColor: _metreurAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _generatingDoc ? null : _generateBonPreparation,
                    icon: _generatingDoc
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _metreurAccent),
                          )
                        : const Icon(Icons.description_outlined),
                    label: const Text('Bon de préparation'),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.grey50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        backgroundColor: AppColors.grey50,
                      ),
                      onPressed: widget.onAskInfo,
                      child: const Text('Demander des infos'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Builder(builder: (context) {
                    // Phase 3 (multi-lots) : au-delà de l'acceptation, ces
                    // statuts sont pilotés lot par lot (bloc "Lots"
                    // ci-dessus) dès qu'un devis a des lots.
                    if (data.lotIds.isNotEmpty &&
                        (data.status == 'À commander' ||
                            data.status == 'Commande en cours' ||
                            data.status == 'À planifier' ||
                            data.status == 'En pose')) {
                      return const SizedBox.shrink();
                    }
                    switch (data.status) {
                      case 'Acceptée':
                      case 'En cours':
                        return Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _metreurAccent, // Green for action
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                              shadowColor: _metreurAccent.withOpacity(0.4),
                            ),
                            onPressed: () => _openMeasurementForm(0),
                            child: Builder(
                              builder: (context) {
                                // Check if any product has measurements
                                final hasMeasurements = data.draft?.products.any((p) =>
                                    (p.largeurReelle?.isNotEmpty == true) ||
                                    (p.hauteurReelle?.isNotEmpty == true) ||
                                    (p.note?.isNotEmpty == true) ||
                                    (p.cjHaut?.isNotEmpty == true)) ?? false;

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(hasMeasurements ? Icons.edit : Icons.play_arrow_rounded, color: Colors.black),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        hasMeasurements ? 'Modifier le métré' : 'Démarrer le métré',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        );
                      case 'À commander':
                      case 'Commande en cours':
                        return Expanded(
                          child: widget.canConfirmOrder
                              ? ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.warning,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  onPressed: widget.onConfirmOrder,
                                  child: const Text(
                                    'Confirmer la commande',
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: AppColors.grey50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.grey100),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Commande réservée au commercial/admin',
                                    style: TextStyle(color: AppColors.grey500, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                        );
                      case 'À planifier':
                        return Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            onPressed: widget.onSchedulePose,
                            child: const Text('Programmer la pose'),
                          ),
                        );
                      case 'En pose':
                        return Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.successLight,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Pose programmée',
                                    style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _sendRelanceCloture(),
                                child: const Text('Relancer la clôture'),
                              ),
                            ],
                          ),
                        );
                      default:
                        return Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _metreurAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            onPressed: widget.onAccept,
                            child: const Text('Accepter la demande'),
                          ),
                        );
                    }
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey100),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.grey400, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.data, required this.onOpen});

  final _AttachmentData data;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey100),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, color: AppColors.grey500),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                data.label,
                style: const TextStyle(color: AppColors.grey500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.open_in_new, color: _metreurAccent),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        backgroundColor: AppColors.grey50,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.grey50),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: _metreurAccent,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        shadowColor: Colors.black45,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Feuille bloquante affichée à la fin de la saisie du métré (avant que la
/// transition vers "À commander" ne parte) : un pair durée/poseurs par
/// métier distinct du devis. Pas de bouton retour/croix — seul "Confirmer"
/// (retourne les valeurs) ou "Revenir au métré" (retourne null, annule la
/// validation) referment la feuille, pour qu'il soit impossible de valider
/// un métré sans ces deux informations.
class _ScheduleEstimateSheet extends StatefulWidget {
  const _ScheduleEstimateSheet({
    required this.metierKeys,
    required this.metierLabels,
    this.defaultDuration,
    this.defaultPoseurCount,
  });

  final Set<String> metierKeys;
  final Map<String, String> metierLabels;
  final int? defaultDuration;
  final int? defaultPoseurCount;

  @override
  State<_ScheduleEstimateSheet> createState() => _ScheduleEstimateSheetState();
}

class _ScheduleEstimateSheetState extends State<_ScheduleEstimateSheet> {
  late final Map<String, int> _durations = {
    for (final key in widget.metierKeys) key: widget.defaultDuration ?? 1,
  };
  late final Map<String, int> _poseurCounts = {
    for (final key in widget.metierKeys) key: widget.defaultPoseurCount ?? 1,
  };

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

  @override
  Widget build(BuildContext context) {
    final hadSoldEstimate = widget.defaultDuration != null || widget.defaultPoseurCount != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Temps prévu pour la pose',
            style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            hadSoldEstimate
                ? 'Confirmez ou ajustez l\'estimation transmise par le commercial — nécessaire pour planifier la pose.'
                : 'Le commercial n\'a transmis aucune estimation — indiquez le temps et le nombre de poseurs nécessaires.',
            style: const TextStyle(color: AppColors.grey400, fontSize: 12),
          ),
          const SizedBox(height: 16),
          for (final key in widget.metierKeys) ...[
            if (widget.metierKeys.length > 1) ...[
              Text(widget.metierLabels[key] ?? key,
                  style: const TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
            ],
            _stepper('Durée estimée (jours)', _durations[key]!, (v) => setState(() => _durations[key] = v)),
            _stepper('Poseurs requis', _poseurCounts[key]!, (v) => setState(() => _poseurCounts[key] = v), max: 10),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          _PrimaryAction(
            label: 'Confirmer et valider le métré',
            icon: Icons.check_circle_outline,
            onPressed: () => Navigator.of(context).pop({
              for (final key in widget.metierKeys)
                key: {
                  'estimatedDurationDays': _durations[key]!,
                  'poseurCountRequired': _poseurCounts[key]!,
                },
            }),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Revenir au métré', style: TextStyle(color: AppColors.grey500)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom nav item ──────────────────────────────────────────────────────────
class _MetNavItem extends StatelessWidget {
  const _MetNavItem({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: active ? AppColors.primary : AppColors.grey400),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.primary : AppColors.grey400)),
          ],
        ),
      ),
    );
  }
}

// Données de démonstration retirées (2026-08-14) — l'app n'affiche plus que
// les vrais chantiers Firestore, plus aucune vignette codée en dur.
final _kDemoNewRequests = <_MeasureCardData>[];
final _kDemoAccepted = <_MeasureCardData>[];
final _kDemoToOrder = <_MeasureCardData>[];
final _kDemoPlan = <_MeasureCardData>[];
final _kDemoToClose = <_MeasureCardData>[];
