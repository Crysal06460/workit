import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sign_in_screen.dart';

const Color _metreurBg = Color(0xFF07090D);
const Color _metreurCard = Color(0xFF0F1422);
const Color _metreurAccent = Color(0xFF00F795);
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
  String? _workspaceId;
  String? _workspaceName;
  String? _userId;
  String? _userFirstName;
  String? _userLastName;

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

  Future<void> _init() async {
    await _loadWorkspaceContext();
    await _loadRequests();
    if (_newRequests.isEmpty && _acceptedRequests.isEmpty) {
      _seedDemo();
    }
    setState(() {});
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
    final cachedMap = await _readPrefsMap();
    if (_workspaceId == null) {
      await _loadFromPrefs();
      return;
    }
    try {
      final snap = await _firestore
          .collection('workspaces')
          .doc(_workspaceId)
          .collection('devis')
          .orderBy('createdAt', descending: true)
          .get();
      final newOnes = <_MeasureCardData>[];
      final accepted = <_MeasureCardData>[];
      for (final doc in snap.docs) {
        final map = doc.data();
        map['id'] = doc.id;
        final assignedId = (map['metreurId'] ?? map['assignedMetreurId'])?.toString();
        if (assignedId != null &&
            assignedId.isNotEmpty &&
            assignedId != 'any' &&
            assignedId != _userId) {
          continue;
        }
        final item = _mergeCached(_MeasureCardData.fromMap(map), cachedMap[doc.id]);
        if (item.status == 'Acceptée') {
          accepted.add(item);
        } else {
          newOnes.add(item);
        }
      }
      setState(() {
        _newRequests
          ..clear()
          ..addAll(newOnes);
        _acceptedRequests
          ..clear()
          ..addAll(accepted);
      });
      await _saveToPrefs();
    } catch (_) {
      await _loadFromPrefs();
    }
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
    _newRequests = [];
    _todaysMeasures = [];
    _toOrder = [];
    _toPlan = [];
    _toClose = [];
  }

  @override
  Widget build(BuildContext context) {

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: _metreurBg,
        appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _greetingName().isNotEmpty ? 'Bonjour ${_greetingName()}' : 'Bonjour',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Métreur',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_month_outlined, color: Colors.white),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: _metreurAccent),
              tooltip: 'Actualiser',
              onPressed: _loadRequests,
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: _metreurAccent),
              tooltip: 'Se déconnecter',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                    (route) => false,
                  );
                }
              },
            ),
            const SizedBox(width: 6),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(92),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0E1424), Color(0xFF0B111D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: TabBar(
                  isScrollable: true,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _metreurAccent.withOpacity(0.5)),
                  ),
                  indicatorPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  tabs: [
                    Tab(
                      child: _TabPill(
                        label: 'En cours',
                        count: (_newRequests.length + _todaysMeasures.length + _acceptedRequests.length),
                        color: Colors.lightBlueAccent,
                        icon: Icons.straighten,
                      ),
                    ),
                    Tab(
                      child: _TabPill(
                        label: 'À commander',
                        count: _toOrder.length,
                        color: Colors.orangeAccent,
                        icon: Icons.shopping_bag_outlined,
                      ),
                    ),
                    Tab(
                      child: _TabPill(
                        label: 'À planifier',
                        count: _toPlan.length,
                        color: Colors.tealAccent,
                        icon: Icons.event_available_outlined,
                      ),
                    ),
                    Tab(
                      child: _TabPill(
                        label: 'À clôturer',
                        count: _toClose.length,
                        color: Colors.greenAccent,
                        icon: Icons.verified_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_newRequests.isNotEmpty)
                      _Section(
                        title: 'Nouvelle demande de métré',
                        children: _newRequests
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _MeasureCard(
                                  data: item,
                                  tag: 'Demande',
                                  tagColor: Colors.deepPurpleAccent,
                                  actions: [
                                    Text(
                                      item.updated ?? '',
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                    _PillButton(
                                      label: 'Ouvrir la demande',
                                      icon: Icons.open_in_new,
                                      onPressed: () => _showRequestDetails(context, item),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    if (_newRequests.isNotEmpty) const SizedBox(height: 16),
                    _PrioritiesSection(
                      title: 'Métrés du jour',
                      items: _todaysMeasures,
                    ),
                    if (_acceptedRequests.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _Section(
                        title: 'Demandes acceptées',
                        children: _acceptedRequests
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _MeasureCard(
                                      data: item,
                                      tag: 'Acceptée',
                                      tagColor: Colors.tealAccent,
                                      actions: [
                                        Text(
                                          item.updated ?? '',
                                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                                        ),
                                        _PillButton(
                                          label: 'Voir le résumé',
                                          icon: Icons.list_alt,
                                          onPressed: () => _showRequestDetails(context, item),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              _StatusList(
                tag: 'À commander',
                tagColor: Colors.orangeAccent,
                items: _toOrder,
                emptyLabel: 'Aucune commande en attente.',
                actionsBuilder: (item) => [
                  _Tag(label: item.status ?? '', color: Colors.orangeAccent),
                  const SizedBox(width: 6),
                  Text(
                    item.updated ?? '',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Commander',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              _StatusList(
                tag: 'À planifier',
                tagColor: Colors.tealAccent,
                items: _toPlan,
                emptyLabel: 'Aucune pose à planifier.',
                actionsBuilder: (item) => [
                  _Tag(label: item.status ?? '', color: Colors.tealAccent),
                  const SizedBox(width: 6),
                  Text(
                    item.updated ?? '',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  IconButton(
                    icon: const Icon(Icons.event, color: Colors.white70),
                    onPressed: () {},
                  ),
                ],
              ),
              _StatusList(
                tag: 'À clôturer',
                tagColor: Colors.greenAccent,
                items: _toClose,
                emptyLabel: 'Rien à clôturer pour le moment.',
                actionsBuilder: (item) => [
                  _Tag(label: item.status ?? '', color: Colors.greenAccent),
                  const SizedBox(width: 6),
                  Text(
                    item.updated ?? '',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  IconButton(
                    icon: const Icon(Icons.verified, color: Colors.white70),
                    onPressed: () {},
                  ),
                ],
              ),
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
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                data.title,
                style: const TextStyle(
                  color: Colors.white,
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
                style: const TextStyle(color: Colors.white70),
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
          onAccept: () => _acceptRequest(context, data),
          onAskInfo: () => _askForInfo(context, data),
          onSchedule: () => _scheduleMeeting(data),
        ),
      ),
    );
  });
}

  void _acceptRequest(BuildContext context, _MeasureCardData data) {
    final navigator = Navigator.of(context);
    setState(() {
      _newRequests.removeWhere((e) => e.id == data.id);
      if (!_acceptedRequests.contains(data)) {
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
    _persistRequestToCloud(
      data.copyWith(
        status: 'Acceptée',
        metreurId: _userId,
        updated: 'Acceptée à l’instant',
      ),
    );
    _saveToPrefs();
    navigator.pop();
    ScaffoldMessenger.of(this.context).showSnackBar(
      const SnackBar(
        content: Text('Demande acceptée et déplacée en En cours.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _askForInfo(BuildContext context, _MeasureCardData data) {
    final navigator = Navigator.of(context);
    navigator.pop();
    Future.microtask(() {
      showModalBottomSheet(
        context: this.context,
        backgroundColor: _metreurCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Row(
                children: const [
                  Icon(Icons.chat_bubble_outline, color: Colors.white70),
                  SizedBox(width: 8),
                  Text(
                    'Demander des informations',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'À ${data.title}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Expliquez ce dont vous avez besoin pour démarrer.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ex: Ajoutez les plans de façade ou les accès au chantier',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
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
                  onPressed: () => Navigator.of(this.context).pop(),
                ),
              ),
            ],
          ),
        );
      },
      );
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
      _acceptedRequests = _acceptedRequests
          .map((e) => e.id == data.id ? e.copyWith(meetingAt: dt) : e)
          .toList();
      _newRequests = _newRequests
          .map((e) => e.id == data.id ? e.copyWith(meetingAt: dt) : e)
          .toList();
    });
    _persistRequestToCloud(data.copyWith(meetingAt: dt));
    _saveToPrefs();
    return dt;
  }

  Future<void> _persistRequestToCloud(_MeasureCardData data) async {
    if (_workspaceId == null) return;
    try {
      final doc = _firestore.collection('workspaces').doc(_workspaceId).collection('devis').doc(data.id);
      await doc.set(
        {
          'metreurStatus': data.status ?? 'En cours',
          'meetingAt': data.meetingAt != null ? Timestamp.fromDate(data.meetingAt!) : null,
          'metreurId': data.metreurId ?? _userId,
          'workspaceId': _workspaceId,
          'updated': data.updated,
          'address': data.address,
          'title': data.title,
          'metreurUpdatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // ignore remote errors for now
    }
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
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
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
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
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
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(item.time, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _Tag(label: item.tag, color: tagColor),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.navigation_outlined, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.address,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.client} • ${item.quote}',
            style: const TextStyle(color: Colors.white70),
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
            color: Colors.white,
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
        border: Border.all(color: Colors.white12),
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
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70),
          ),
          if (data.meetingAt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.event_available_outlined, color: Colors.white54, size: 18),
                const SizedBox(width: 6),
                Text(
                  _formatMeeting(data.meetingAt!),
                  style: const TextStyle(color: Colors.white70),
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
          color: Colors.white,
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

void _callNumber(BuildContext context, String number) {
  // TODO: branch to url_launcher when available; temporary feedback only.
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Appel vers $number'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void _openAttachment(BuildContext context, _AttachmentData data) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Ouverture de ${data.label}'),
      behavior: SnackBarBehavior.floating,
    ),
  );
  // TODO: remplacer par l’ouverture réelle du PDF/JPG du devis.
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
            style: const TextStyle(color: Colors.white54),
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

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.18),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count', style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _MeasureRequestSummary extends StatefulWidget {
  const _MeasureRequestSummary({
    required this.data,
    required this.onAccept,
    required this.onAskInfo,
    required this.onSchedule,
  });

  final _MeasureCardData data;
  final VoidCallback onAccept;
  final VoidCallback onAskInfo;
  final Future<DateTime?> Function() onSchedule;

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

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Scaffold(
      backgroundColor: _metreurBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Demande de métré',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white70),
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
                              color: Colors.white,
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
                    if (data.summary.isNotEmpty)
                      _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Résumé',
                              style: TextStyle(
                                color: Colors.white,
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
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              data.note,
                              style: const TextStyle(color: Colors.white70, height: 1.4),
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
                                color: Colors.white,
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
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        backgroundColor: Colors.white.withOpacity(0.04),
                      ),
                      onPressed: widget.onAskInfo,
                      child: const Text('Demander des infos'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
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
                  ),
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
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
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, color: Colors.white70),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                data.label,
                style: const TextStyle(color: Colors.white70),
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
        backgroundColor: Colors.white.withOpacity(0.08),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.12)),
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
