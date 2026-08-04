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
import '../core/theme/app_colors.dart';
import '../services/devis_service.dart';

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
  String? _workspaceId;
  String? _workspaceName;
  String? _userId;
  String? _userFirstName;
  String? _userLastName;
  int _bottomNavIndex = 0;

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
    super.dispose();
  }

  Future<void> _init() async {
    await _loadWorkspaceContext();
    _subscribeToDevis();
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
      if (status == 'En cours') {
        accepted.add(item);
      } else if (status == 'À commander' || status == 'Commande en cours') {
        toOrder.add(item);
      } else if (status == 'À planifier' || status == 'En pose') {
        toPlan.add(item);
      } else if (status == 'À clôturer' || status == 'Terminé' || status == 'Clôturé') {
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
              const Text(
                'Gestion chantiers',
                style: TextStyle(
                  color: AppColors.grey900,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Metteur en œuvre · ${_totalActions()} actions à traiter',
                style: const TextStyle(color: AppColors.grey400, fontSize: 13),
              ),
            ],
          ),
          actions: [
            GestureDetector(
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                  (_) => false,
                );
              },
              child: Container(
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
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
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
              // Stats row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _StatChip(
                      label: 'Urgent',
                      count: _newRequests.length,
                      color: AppColors.danger,
                      bg: AppColors.dangerLight,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'À commander',
                      count: _toOrder.length,
                      color: AppColors.warning,
                      bg: AppColors.warningLight,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'À planifier',
                      count: _toPlan.length,
                      color: AppColors.purple,
                      bg: AppColors.purpleLight,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _MetreurList(
                      items: allItems,
                      emptyLabel: 'Aucun chantier.',
                      onCardTap: (item) => _showRequestDetails(context, item),
                    ),
                    _MetreurList(
                      items: _newRequests,
                      emptyLabel: 'Aucune demande en attente.',
                      onCardTap: (item) => _showRequestDetails(context, item),
                    ),
                    _MetreurList(
                      items: _acceptedRequests,
                      emptyLabel: 'Aucun métré en cours.',
                      onCardTap: (item) => _showRequestDetails(context, item),
                    ),
                    _MetreurList(
                      items: _toOrder,
                      emptyLabel: 'Aucune commande en attente.',
                      onCardTap: (item) => _showRequestDetails(context, item),
                    ),
                    _MetreurList(
                      items: _toPlan,
                      emptyLabel: 'Aucune pose à planifier.',
                      onCardTap: (item) => _showRequestDetails(context, item),
                    ),
                    _MetreurList(
                      items: _toClose,
                      emptyLabel: 'Rien à clôturer.',
                      onCardTap: (item) => _showRequestDetails(context, item),
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
          title: const Text('Planner', style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800)),
          iconTheme: const IconThemeData(color: AppColors.grey600),
        ),
        body: PlannerScreen(workspaceId: _workspaceId!, accentColor: AppColors.roleMetteur),
      ),
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
              _MetNavItem(icon: Icons.home_rounded, label: 'Accueil', active: _bottomNavIndex == 0, onTap: () => setState(() => _bottomNavIndex = 0)),
              _MetNavItem(icon: Icons.straighten_rounded, label: 'Chantiers', active: _bottomNavIndex == 1, onTap: () => setState(() => _bottomNavIndex = 1)),
              _MetNavItem(icon: Icons.calendar_month_outlined, label: 'Agenda', active: false, onTap: _openPlanner),
              _MetNavItem(icon: Icons.settings_outlined, label: 'Réglages', active: _bottomNavIndex == 3, onTap: () => setState(() => _bottomNavIndex = 3)),
            ],
          ),
        ),
      ),
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
          onAccept: () => _acceptRequest(context, data),
          onAskInfo: () => _askForInfo(context, data),
          onSchedule: () => _scheduleMeeting(data),
          onConfirmOrder: () => _confirmOrder(context, data),
          onSchedulePose: () => _schedulePose(context, data),
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
          extraFields: {'meetingAt': Timestamp.fromDate(dt)},
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
                            'poseDate': Timestamp.fromDate(dt),
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

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
    required this.bg,
  });
  final String label;
  final int count;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count',
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 20),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
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
  });
  final List<_MeasureCardData> items;
  final String emptyLabel;
  final void Function(_MeasureCardData) onCardTap;

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
      ),
    );
  }
}

class _MetCard extends StatelessWidget {
  const _MetCard({required this.data, required this.onTap});
  final _MeasureCardData data;
  final VoidCallback onTap;

  static Color _accentColor(String? s) {
    if (s == 'En cours' || s == 'Acceptée' || s == 'RDV métré' || s == 'Métré programmé') {
      return AppColors.purple;
    }
    if (s == 'À commander' || s == 'Commande en cours') return AppColors.warning;
    if (s == 'À planifier' || s == 'En pose' || s == 'Chantier à planifier') return AppColors.primary;
    if (s == 'Terminé' || s == 'À clôturer' || s == 'Clôturé') return AppColors.success;
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
    if (s == 'À planifier' || s == 'En pose') return 'Planifier pose';
    if (s == 'Terminé' || s == 'À clôturer' || s == 'Clôturé') return 'Clôturer';
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
                              'Voir devis',
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
                            onPressed: onTap,
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
    final label = status ?? 'En attente';
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
  });

  final _MeasureCardData data;
  final VoidCallback onAccept;
  final VoidCallback onAskInfo;
  final Future<DateTime?> Function() onSchedule;
  final VoidCallback onConfirmOrder;
  final VoidCallback onSchedulePose;
  final VoidCallback? onRefresh;
  final String? workspaceId;

  @override
  State<_MeasureRequestSummary> createState() => _MeasureRequestSummaryState();
}

class _MeasureRequestSummaryState extends State<_MeasureRequestSummary> {
  DateTime? meetingAt;

  @override
  void initState() {
    super.initState();
    meetingAt = widget.data.meetingAt;
  }

  Future<void> _openMeasurementForm(int initialIndex) async {
    final data = widget.data;
    // Navigate to Measurement Form and await result
    final updatedProducts = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeasurementFormScreen(
          draftData: (data.draft ?? const _QuoteDraft()).toMap(),
          initialIndex: initialIndex,
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

      try {
        final wsId = data.workspaceId ?? widget.workspaceId;
        if (wsId == null) throw 'Workspace ID manquant';

        final extraFields = <String, dynamic>{'updated': 'Métré terminé'};
        if (updatedDraft != null) {
          extraFields['draft'] = updatedDraft.toMap();
        }

        await DevisService.updateStatus(
          workspaceId: wsId,
          devisId: data.id,
          newStatus: 'À commander',
          extraFields: extraFields,
        );

        if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Scaffold(
      backgroundColor: _metreurBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.grey900, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Demande de métré',
          style: TextStyle(
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
                          if (meetingAt != null)
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
                          const SizedBox(height: 8),
                          _PrimaryAction(
                            label: meetingAt == null ? 'Prendre rendez-vous client' : 'Modifier rendez-vous client',
                            icon: Icons.calendar_month_outlined,
                            onPressed: () async {
                              final picked = await widget.onSchedule();
                              if (picked != null && mounted) {
                                setState(() => meetingAt = picked);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 12),
                    if (data.draft != null && data.draft!.products.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const // Section Title
                          Text(
                            'Éléments à métrer',
                            style: TextStyle(
                              color: AppColors.grey900,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
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
                                onTap: () => _openMeasurementForm(i),
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
                                      
                                      // Add a subtle hint that it's clickable
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: const [
                                          Text('Modifier', style: TextStyle(color: _metreurAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                          SizedBox(width: 4),
                                          Icon(Icons.edit, size: 14, color: _metreurAccent),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      )
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
                    switch (data.status) {
                      case 'Acceptée':
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
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            onPressed: widget.onConfirmOrder,
                            child: const Text('Confirmer la commande'),
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
                          child: Container(
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

// ─── Données de démonstration ─────────────────────────────────────────────────
final _kDemoNewRequests = <_MeasureCardData>[
  _MeasureCardData(id: 'demo1', title: 'Dupont Jean', address: '14 rue Ledru-Rollin, Paris 15e', note: 'Nouvelle demande', status: 'Nouvelle demande', updated: 'Il y a 2 jours', phone: '06 12 34 56 78'),
  _MeasureCardData(id: 'demo2', title: 'Rousseau Claire', address: '7 bd Victor Hugo, Nice', note: 'Nouveau', status: 'Nouvelle demande', updated: 'Il y a 3 jours', phone: '06 98 76 54 32'),
];

final _kDemoAccepted = <_MeasureCardData>[
  _MeasureCardData(id: 'demo3', title: 'Martin Sophie', address: '8 avenue des Arts, Lyon 3e', note: 'RDV Mer 02/07 à 09h00', status: 'En cours', updated: 'RDV programmé', phone: '06 55 44 33 22', meetingAt: DateTime.now().add(const Duration(days: 3))),
];

final _kDemoToOrder = <_MeasureCardData>[
  _MeasureCardData(id: 'demo4', title: 'Laurent Céline', address: '5 impasse des Pins, Toulouse', note: 'Métré validé — à commander', status: 'À commander', updated: 'Devis accepté'),
];

final _kDemoPlan = <_MeasureCardData>[
  _MeasureCardData(id: 'demo5', title: 'Bernard Marc', address: '22 quai de la Loire, Nantes', note: 'Pose à programmer', status: 'À planifier', updated: 'Commande reçue'),
  _MeasureCardData(id: 'demo6', title: 'Petit Thomas', address: '3 allée des Roses, Bordeaux', note: 'En cours de pose', status: 'En pose', updated: 'Équipe sur place'),
];

final _kDemoToClose = <_MeasureCardData>[
  _MeasureCardData(id: 'demo7', title: 'Moreau Julie', address: '17 rue du Moulin, Strasbourg', note: 'Travaux terminés', status: 'Terminé', updated: 'Terminé le 26/06'),
];
