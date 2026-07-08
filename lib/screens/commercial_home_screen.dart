import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_home_screen.dart';
import 'entry_screen.dart';
import 'sign_in_screen.dart';
import 'settings_screen.dart';
import 'widgets/dynamic_dropdown_field.dart';
import '../core/theme/app_colors.dart';

const Map<String, String> _metierOptions = {
  'menuiserie_aluminium': 'Menuiserie Extérieure & Fermeture',
};

const Color _commercialBg     = AppColors.background;
const Color _commercialCard   = AppColors.surface;
const Color _commercialAccent = AppColors.primary;
const String _workspaceIdKey = 'workit_workspace_id';
const String _userFirstNameKey = 'workit_user_first_name';
const String _userLastNameKey = 'workit_user_last_name';
const String _isAdminKey = 'workit_is_admin';
const String _storageBucket = 'gs://workit-1daa1.firebasestorage.app';

class CommercialHomeScreen extends StatefulWidget {
  const CommercialHomeScreen({super.key});

  @override
  State<CommercialHomeScreen> createState() => _CommercialHomeScreenState();
}

class _CommercialHomeScreenState extends State<CommercialHomeScreen> {
  final _firestore = FirebaseFirestore.instance;
  String? _workspaceId;
  String? _userFirstName;
  String? _userLastName;
  bool _isAdmin = false;
  String _searchQuery = '';
  int _bottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadWorkspaceContext();
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
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        backgroundColor: _commercialBg,
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
              StreamBuilder<QuerySnapshot>(
                stream: _workspaceId == null
                    ? const Stream.empty()
                    : _firestore.collection('workspaces').doc(_workspaceId).collection('devis').snapshots(),
                builder: (_, snap) {
                  final total = (snap.data?.docs.length ?? 0) +
                      _kDemoDevis.where((d) => d.status != 'Terminé' && d.status != 'Clôturé').length;
                  return Text(
                    'Commercial · $total affaires actives',
                    style: const TextStyle(color: AppColors.grey400, fontSize: 13),
                  );
                },
              ),
            ],
          ),
          actions: [
            // Avatar initiales (affichage uniquement)
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primary,
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
                  MaterialPageRoute(builder: (_) => const EntryScreen()),
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
              child: SizedBox(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _workspaceId == null
                      ? const Stream.empty()
                      : _firestore
                          .collection('workspaces')
                          .doc(_workspaceId)
                          .collection('devis')
                          // Removed redundant where clause to avoid index requirement
                          .orderBy('createdAt', descending: true)
                          .limit(50)
                          .snapshots(),
                    builder: (context, snapshot) {
                    final allDocs = snapshot.data?.docs ?? [];
                    final docs = _searchQuery.isEmpty
                        ? allDocs
                        : allDocs.where((doc) {
                            return _matchesSearch(
                              doc.data() as Map<String, dynamic>,
                              _searchQuery,
                            );
                          }).toList();

                    final newItems = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = (data['status'] ?? data['metreurStatus']) as String?;
                      return status == null || status == 'Nouvelle demande' || status == 'Acceptée' || status == 'À classer';
                    }).toList();

                    final scheduledItems = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = (data['status'] ?? data['metreurStatus']) as String?;
                      return status == 'En cours';
                    }).toList();

                    final commandeItems = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = (data['status'] ?? data['metreurStatus']) as String?;
                      return status == 'À commander' || status == 'Commande en cours';
                    }).toList();

                    final planifierItems = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = (data['status'] ?? data['metreurStatus']) as String?;
                      return status == 'À planifier';
                    }).toList();

                    final poseItems = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = (data['status'] ?? data['metreurStatus']) as String?;
                      return status == 'En pose';
                    }).toList();

                    final terminesItems = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = (data['status'] ?? data['metreurStatus']) as String?;
                      return status == 'À clôturer' || status == 'Terminé' || status == 'Clôturé';
                    }).toList();

                    // compter demo + firestore
                    final demoNew = _kDemoDevis.where((d) => d.status == null || d.status == 'Nouvelle demande').length;
                    final demoSched = _kDemoDevis.where((d) => d.status == 'En cours').length;
                    final demoCmd = _kDemoDevis.where((d) => d.status == 'À commander' || d.status == 'Commande en cours').length;
                    final demoPlan = _kDemoDevis.where((d) => d.status == 'À planifier').length;
                    final demoPose = _kDemoDevis.where((d) => d.status == 'En pose').length;
                    final demoTerm = _kDemoDevis.where((d) => d.status == 'Terminé' || d.status == 'Clôturé').length;
                    final totalAll = newItems.length + demoNew + scheduledItems.length + demoSched
                        + commandeItems.length + demoCmd + planifierItems.length + demoPlan
                        + poseItems.length + demoPose + terminesItems.length + demoTerm;
                    final tabController = DefaultTabController.of(context);
                    return AnimatedBuilder(
                      animation: tabController,
                      builder: (ctx, _) {
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
                            _PillTab(label: 'Tous', count: totalAll, isSelected: sel == 0),
                            _PillTab(label: 'En attente', count: newItems.length + demoNew, isSelected: sel == 1),
                            _PillTab(label: 'Devis prog.', count: scheduledItems.length + demoSched, isSelected: sel == 2),
                            _PillTab(label: 'À commander', count: commandeItems.length + demoCmd, isSelected: sel == 3),
                            _PillTab(label: 'À planifier', count: planifierItems.length + demoPlan, isSelected: sel == 4),
                            _PillTab(label: 'En pose', count: poseItems.length + demoPose, isSelected: sel == 5),
                            _PillTab(label: 'Terminés', count: terminesItems.length + demoTerm, isSelected: sel == 6),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ── Stats row ────────────────────────────────────
              StreamBuilder<QuerySnapshot>(
                stream: _workspaceId == null
                    ? const Stream.empty()
                    : _firestore.collection('workspaces').doc(_workspaceId).collection('devis').snapshots(),
                builder: (context, snap) {
                  final docs = snap.data?.docs ?? [];
                  int fsNew = 0, fsActive = 0, fsDone = 0;
                  for (final doc in docs) {
                    final s = ((doc.data() as Map<String, dynamic>)['status'] ?? (doc.data() as Map<String, dynamic>)['metreurStatus'])?.toString();
                    if (s == null || s == 'Nouvelle demande' || s == 'Acceptée') fsNew++;
                    else if (s == 'Terminé' || s == 'Clôturé' || s == 'À clôturer') fsDone++;
                    else fsActive++;
                  }
                  final totalNew = fsNew + _kDemoDevis.where((d) => d.status == null || d.status == 'Nouvelle demande').length;
                  final totalActive = fsActive + _kDemoDevis.where((d) => d.status != null && d.status != 'Nouvelle demande' && d.status != 'Terminé' && d.status != 'Clôturé').length;
                  final totalDone = fsDone + _kDemoDevis.where((d) => d.status == 'Terminé' || d.status == 'Clôturé').length;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        _StatCard(value: totalNew, label: 'En attente', color: AppColors.warning),
                        const SizedBox(width: 10),
                        _StatCard(value: totalActive, label: 'En cours', color: AppColors.primary),
                        const SizedBox(width: 10),
                        _StatCard(value: totalDone, label: 'Terminés', color: AppColors.success),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: _SearchBar(
                  onChanged: (q) => setState(() => _searchQuery = q),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _AddQuoteButton(
                  onPressed: () async {
                    await Navigator.of(context).push<_QuoteItem>(
                      MaterialPageRoute(
                        builder: (_) => const _AddQuoteScreen(),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: const Text(
                  'Affaires récentes',
                  style: TextStyle(color: AppColors.grey900, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _workspaceId == null
                        ? const Stream.empty()
                        : _firestore
                            .collection('workspaces')
                            .doc(_workspaceId)
                            .collection('devis')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allDocs = snapshot.data?.docs ?? [];
                      final docs = _searchQuery.isEmpty
                          ? allDocs
                          : allDocs.where((doc) {
                              return _matchesSearch(
                                doc.data() as Map<String, dynamic>,
                                _searchQuery,
                              );
                            }).toList();

                      final newItems = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final status = (data['status'] ?? data['metreurStatus']) as String?;
                        return status == null || status == 'Nouvelle demande' || status == 'Acceptée' || status == 'À classer';
                      }).map((doc) {
                        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
                        data['id'] = doc.id;
                        return _QuoteItem.fromMap(data);
                      }).toList();

                      final scheduledItems = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final status = (data['status'] ?? data['metreurStatus']) as String?;
                        return status == 'En cours';
                      }).map((doc) {
                        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
                        data['id'] = doc.id;
                        return _QuoteItem.fromMap(data);
                      }).toList();

                      final commandeItems = [
                        ..._kDemoDevis.where((d) => d.status == 'À commander' || d.status == 'Commande en cours'),
                        ...docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final status = (data['status'] ?? data['metreurStatus']) as String?;
                          return status == 'À commander' || status == 'Commande en cours';
                        }).map((doc) {
                          final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
                          data['id'] = doc.id;
                          return _QuoteItem.fromMap(data);
                        }),
                      ];

                      final planifierItems = [
                        ..._kDemoDevis.where((d) => d.status == 'À planifier'),
                        ...docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final status = (data['status'] ?? data['metreurStatus']) as String?;
                          return status == 'À planifier';
                        }).map((doc) {
                          final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
                          data['id'] = doc.id;
                          return _QuoteItem.fromMap(data);
                        }),
                      ];

                      final poseItems = [
                        ..._kDemoDevis.where((d) => d.status == 'En pose'),
                        ...docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final status = (data['status'] ?? data['metreurStatus']) as String?;
                          return status == 'En pose';
                        }).map((doc) {
                          final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
                          data['id'] = doc.id;
                          return _QuoteItem.fromMap(data);
                        }),
                      ];

                      final terminesItems = [
                        ..._kDemoDevis.where((d) => d.status == 'Terminé' || d.status == 'Clôturé'),
                        ...docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final status = (data['status'] ?? data['metreurStatus']) as String?;
                          return status == 'À clôturer' || status == 'Terminé' || status == 'Clôturé';
                        }).map((doc) {
                          final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
                          data['id'] = doc.id;
                          return _QuoteItem.fromMap(data);
                        }),
                      ];

                      final allItems = [
                        ..._kDemoDevis,
                        ...docs.map((doc) {
                          final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
                          data['id'] = doc.id;
                          return _QuoteItem.fromMap(data);
                        }),
                      ];
                      return TabBarView(
                        children: [
                          _AllItemsList(items: allItems),
                          _NewQuotesList(
                            items: newItems,
                            onDelete: (item) {},
                            onEdit: (item) async {
                              await Navigator.of(context).push<_QuoteItem>(
                                MaterialPageRoute(
                                  builder: (_) => _AddQuoteScreen(existingItem: item),
                                ),
                              );
                            },
                          ),
                          _ScheduledList(items: scheduledItems),
                          _ValidatedList(items: commandeItems),
                          _ValidatedList(items: planifierItems),
                          _ValidatedList(items: poseItems),
                          _ValidatedList(items: terminesItems),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
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
              _NavItem(icon: Icons.home_rounded, activeIcon: Icons.home_rounded, label: 'Accueil', active: _bottomNavIndex == 0, onTap: () => setState(() => _bottomNavIndex = 0)),
              _NavItem(icon: Icons.description_outlined, activeIcon: Icons.description_rounded, label: 'Devis', active: _bottomNavIndex == 1, onTap: () => setState(() => _bottomNavIndex = 1)),
              _NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month_rounded, label: 'Agenda', active: _bottomNavIndex == 2, onTap: () => setState(() => _bottomNavIndex = 2)),
              _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Réglages', active: _bottomNavIndex == 3, onTap: () => setState(() => _bottomNavIndex = 3)),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesSearch(Map<String, dynamic> data, String query) {
    final q = query.toLowerCase();
    final fields = [
      data['clientName'],
      data['clientFirstName'],
      data['clientLastName'],
      data['client'],
      data['address'],
      data['adresse'],
    ];
    return fields.any((f) => f?.toString().toLowerCase().contains(q) == true);
  }

  Future<void> _loadWorkspaceContext() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _workspaceId = prefs.getString(_workspaceIdKey);
      _userFirstName = prefs.getString(_userFirstNameKey);
      _userLastName = prefs.getString(_userLastNameKey);
      _isAdmin = prefs.getBool(_isAdminKey) ?? false;
    });
    await _maybeFetchWorkspaceUserName();
  }

  Future<void> _maybeFetchWorkspaceUserName() async {
    if (_workspaceId == null) return;
    // Ne pas écraser le nom déjà stocké pour l'utilisateur courant.
    final hasLocalName = (_userFirstName?.isNotEmpty == true) || (_userLastName?.isNotEmpty == true);
    if (hasLocalName) return;
    try {
      final doc = await _firestore.collection('workspaces').doc(_workspaceId).get();
      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;
      final first = data['creatorFirstName']?.toString();
      final last = data['creatorLastName']?.toString();
      if (first?.isEmpty != false && last?.isEmpty != false) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userFirstNameKey, first ?? '');
      await prefs.setString(_userLastNameKey, last ?? '');
      if (mounted) {
        setState(() {
          _userFirstName = first;
          _userLastName = last;
        });
      }
    } catch (_) {
      // ignore fetch errors, fallback to defaults
    }
  }

  Future<void> _showCalendar() async {
    if (_workspaceId == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final snap = await _firestore
        .collection('workspaces')
        .doc(_workspaceId)
        .collection('devis')
        .where('userId', isEqualTo: uid)
        .get();

    final List<Map<String, dynamic>> events = [];

    for (final doc in snap.docs) {
      final d = doc.data();
      final client = d['client']?.toString() ?? d['clientName']?.toString() ?? 'Client';
      final meetingTs = d['meetingAt'];
      final poseTs = d['poseDate'];

      if (meetingTs is Timestamp) {
        final dt = meetingTs.toDate();
        if (dt.isAfter(now.subtract(const Duration(days: 1)))) {
          events.add({'date': dt, 'label': 'RDV Métré — $client', 'type': 'rdv'});
        }
      }
      if (poseTs is Timestamp) {
        final dt = poseTs.toDate();
        if (dt.isAfter(now.subtract(const Duration(days: 1)))) {
          events.add({'date': dt, 'label': 'Pose — $client', 'type': 'pose'});
        }
      }
    }

    events.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.grey200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Agenda',
              style: TextStyle(
                color: AppColors.grey900,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Aucun rendez-vous ou pose à venir',
                    style: TextStyle(color: AppColors.grey400),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: events.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: AppColors.grey100, height: 1),
                  itemBuilder: (_, i) {
                    final ev = events[i];
                    final dt = ev['date'] as DateTime;
                    final isRdv = ev['type'] == 'rdv';
                    final dayStr = _frDay(dt.weekday);
                    final dateStr =
                        '$dayStr ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isRdv
                                  ? _commercialAccent
                                  : AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ev['label'] as String,
                                  style: const TextStyle(
                                    color: AppColors.grey900,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    color: AppColors.grey500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
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

  String _frDay(int weekday) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[(weekday - 1).clamp(0, 6)];
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      style: const TextStyle(color: AppColors.grey900),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Rechercher un devis, un client…',
        hintStyle: const TextStyle(color: AppColors.grey400),
        filled: true,
        fillColor: AppColors.grey50,
        prefixIcon: const Icon(Icons.search, color: AppColors.grey400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.grey200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.grey200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _AddQuoteButton extends StatelessWidget {
  const _AddQuoteButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: Colors.white, size: 20),
              SizedBox(width: 8),
              const Text(
                'Ajouter un devis',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewQuotesList extends StatelessWidget {
  const _NewQuotesList({required this.items, required this.onDelete, required this.onEdit});
  final List<_QuoteItem> items;
  final ValueChanged<_QuoteItem> onDelete;
  final ValueChanged<_QuoteItem> onEdit;

  @override
  Widget build(BuildContext context) {
    final demoNew = _kDemoDevis.where((d) => d.status == null || d.status == 'Nouvelle demande').toList();
    final allItems = [...demoNew, ...items];
    if (allItems.isEmpty) {
      return const Center(child: Text("Aucun devis en attente", style: TextStyle(color: AppColors.grey400)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: allItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final item = allItems[index];
        return _QuoteCard(
          title: item.client,
          subtitle: item.address,
          meta: item.date,
          badgeLabel: 'En attente',
          badgeColor: AppColors.warning,
          statusValue: item.status,
          thumbnailUrl: item.uploadUrl,
          onEdit: () => onEdit(item),
          onDelete: () => onDelete(item),
          onTap: () => _showChantierDetail(context, item),
        );
      },
    );
  }
}

class _MeasuringList extends StatelessWidget {
  const _MeasuringList({required this.items});
  final List<_QuoteItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text("Aucun métré en cours", style: TextStyle(color: AppColors.grey400)),
      );
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final item = items[index];
        return _QuoteCard(
          title: item.client,
          subtitle: item.address,
          meta: item.status ?? 'En cours',
          badgeLabel: item.assignedMetreurName ?? 'Non attribué',
          badgeColor: Colors.lightBlueAccent,
          statusValue: item.status ?? 'En cours',
          trailing: const Icon(Icons.straighten, color: AppColors.grey500),
          onTap: () => _showChantierDetail(context, item),
        );
      },
    );
  }
}

class _ScheduledList extends StatelessWidget {
  const _ScheduledList({required this.items});
  final List<_QuoteItem> items;

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
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: allItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final item = allItems[index];
        final rdv = item.meetingAt != null ? _fmtDate(item.meetingAt!) : '';
        return _QuoteCard(
          title: item.client,
          subtitle: item.address,
          meta: rdv.isNotEmpty ? '📅 RDV le $rdv' : 'Métré programmé',
          badgeLabel: 'Devis prog.',
          badgeColor: AppColors.purple,
          statusValue: item.status ?? 'En cours',
          onTap: () => _showChantierDetail(context, item),
        );
      },
    );
  }
}

class _ValidatedList extends StatelessWidget {
  const _ValidatedList({required this.items});
  final List<_QuoteItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text("Aucune donnée pour l'instant", style: TextStyle(color: AppColors.grey400)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final item = items[index];
        final badgeColor = item.status == 'Commande en cours' ? AppColors.amber
            : item.status == 'À commander' ? AppColors.warning
            : item.status == 'À planifier' ? AppColors.primary
            : item.status == 'En pose' ? AppColors.success
            : item.status == 'Terminé' || item.status == 'Clôturé' ? AppColors.grey500
            : _commercialAccent;
        return _QuoteCard(
          title: item.client,
          subtitle: item.address,
          meta: item.poseDate != null
              ? '📅 Pose le ${item.poseDate!.day}/${item.poseDate!.month}'
              : '${item.number} • ${item.date}',
          badgeLabel: item.status ?? item.tag,
          badgeColor: badgeColor,
          trailing: const Icon(Icons.chevron_right, color: AppColors.grey300),
          onTap: () => _showChantierDetail(context, item),
        );
      },
    );
  }
}

class _AddQuoteScreen extends StatefulWidget {
  const _AddQuoteScreen({this.existingItem});

  final _QuoteItem? existingItem;

  @override
  State<_AddQuoteScreen> createState() => _AddQuoteScreenState();
}

class _AddQuoteScreenState extends State<_AddQuoteScreen> {
  final pageController = PageController();
  final clientNameController = TextEditingController();
  final clientFirstNameController = TextEditingController();
  final clientStreetController = TextEditingController();
  final clientPostalController = TextEditingController();
  final clientCityController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final commentaireController = TextEditingController();
  final chantierNotesController = TextEditingController();
  final quantiteController = TextEditingController(text: '1');
  final largeurController = TextEditingController();
  final hauteurController = TextEditingController();
  final List<_MetreurOption> _metreurs = [];
  bool loadingMetreurs = true;
  String? _selectedMetreurId;
  String? _selectedMetreurName;
  String? uploadedFileUrl;
  int currentStep = 0;
  Map<String, dynamic>? dictionary;
  bool loadingDictionary = true;
  bool loadingTrade = true;
  String? tradeKey;
  String? tradeLabel;
  String? _workspaceId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> selectedFiles = [];
  String? chantierType;
  String? typeHabitation;
  String? accessibilite;
  DateTime? selectedDate;
  List<_ProductFormData> products = [const _ProductFormData()];
  String? uploadLabel;
  List<String> citySuggestions = [];
  bool isFetchingCities = false;
  String? _lastPostalLookup;
  static const Map<String, List<String>> _postalFallback = {
    '06600': ['Antibes', 'Juan-les-Pins'],
    '06460': ['Caussols', 'Escragnolles', 'Saint-Vallier-de-Thiey'],
    '75001': ['Paris'],
    '13001': ['Marseille'],
    '69001': ['Lyon'],
    '33000': ['Bordeaux'],
    '31000': ['Toulouse'],
    '59000': ['Lille'],
  };

  @override
  void initState() {
    super.initState();
    _loadWorkspaceFromPrefs();
    _loadDictionary();
    _loadTradeFromPrefs();
    _loadMetreurs();
    _applyDraft(widget.existingItem?.draft);
    if (widget.existingItem != null && widget.existingItem!.draft == null) {
      _applyQuoteFallback(widget.existingItem!);
    }
  }

  Future<void> _loadWorkspaceFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _workspaceId = prefs.getString(_workspaceIdKey);
    });
    await _loadMetreurs();
  }

  Future<void> _loadMetreurs() async {
    if (_workspaceId == null) {
      setState(() => loadingMetreurs = false);
      return;
    }
    try {
      final snap = await _firestore
          .collection('users')
          .where('companyId', isEqualTo: _workspaceId)
          .where('role', isEqualTo: 'metreur')
          .get();
      _metreurs
        ..clear()
        ..addAll(snap.docs.map((doc) {
          final data = doc.data();
          final first = data['firstName']?.toString().trim() ?? '';
          final last = data['lastName']?.toString().trim() ?? '';
          final name = [first, last].where((e) => e.isNotEmpty).join(' ');
          return _MetreurOption(
            id: doc.id,
            name: name.isNotEmpty ? name : (data['email']?.toString() ?? 'Métreur'),
            email: data['email']?.toString(),
          );
        }));
      if (_metreurs.length == 1 && _selectedMetreurId == null) {
        _selectedMetreurId = _metreurs.first.id;
        _selectedMetreurName = _metreurs.first.name;
      }
      if (_metreurs.isNotEmpty && _selectedMetreurId == null) {
        _selectedMetreurId = 'any';
        _selectedMetreurName = 'Peu importe';
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => loadingMetreurs = false);
    }
  }

  Future<void> _loadDictionary() async {
    try {
      final raw = await rootBundle.loadString('assets/dictionnaire_workit/workit_dictionary.json');
      setState(() {
        dictionary = json.decode(raw) as Map<String, dynamic>;
        loadingDictionary = false;
      });
      _ensureDefaultCategoryForProducts();
    } catch (_) {
      setState(() {
        dictionary = {};
        loadingDictionary = false;
      });
    }
  }

  Future<void> _loadTradeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _workspaceId = prefs.getString(_workspaceIdKey);
    final key = prefs.getString('workit_trade_key');
    if (key != null) {
      setState(() {
        tradeKey = key;
        tradeLabel = _metierOptions[key] ?? key;
        loadingTrade = false;
      });
      _ensureDefaultCategoryForProducts();
      return;
    }

    if (_workspaceId != null) {
      try {
        final doc = await _firestore.collection('workspaces').doc(_workspaceId).get();
        final data = doc.data();
        final workspaceTrade = data?['tradeKey']?.toString();
        if (workspaceTrade != null && workspaceTrade.isNotEmpty) {
          await prefs.setString('workit_trade_key', workspaceTrade);
          setState(() {
            tradeKey = workspaceTrade;
            tradeLabel = _metierOptions[workspaceTrade] ?? workspaceTrade;
            loadingTrade = false;
          });
          _ensureDefaultCategoryForProducts();
          return;
        }
      } catch (_) {
        // ignore
      }
    }

    setState(() {
      tradeKey = key;
      tradeLabel = _metierOptions[key] ?? key;
      loadingTrade = false;
    });
    _ensureDefaultCategoryForProducts();
  }

  void _applyDraft(_QuoteDraft? draft) {
    if (draft == null) return;
    clientNameController.text = draft.clientName ?? '';
    clientFirstNameController.text = draft.clientFirstName ?? '';
    clientStreetController.text = draft.street ?? '';
    clientPostalController.text = draft.postal ?? '';
    clientCityController.text = draft.city ?? '';
    phoneController.text = draft.phone ?? '';
    emailController.text = draft.email ?? '';
    chantierNotesController.text = draft.chantierNotes ?? '';
    commentaireController.text = draft.commentaire ?? '';
    chantierType = draft.chantierType;
    typeHabitation = draft.typeHabitation;
    accessibilite = draft.accessibilite;
    selectedDate = draft.date;
    _selectedMetreurId = draft.assignedMetreurId;
    _selectedMetreurName = draft.assignedMetreurName;
    products = draft.products.isNotEmpty ? draft.products : products;
    _ensureDefaultCategoryForProducts();
    setState(() {});
  }

  void _applyQuoteFallback(_QuoteItem item) {
    // Reconstitute fields from the minimal data we have for older quotes without draft.
    final clientParts = item.client.trim().split(RegExp(r'\\s+'));
    if (clientParts.length > 1) {
      clientNameController.text = clientParts.first;
      clientFirstNameController.text = clientParts.sublist(1).join(' ');
    } else {
      clientNameController.text = item.client;
    }

    final segments = item.address.split(',');
    if (segments.isNotEmpty) {
      clientStreetController.text = segments.first.trim();
    }
    if (segments.length > 1) {
      final tail = segments.sublist(1).join(',').trim();
      final postalMatch = RegExp(r'(\\d{5})').firstMatch(tail);
      if (postalMatch != null) {
        clientPostalController.text = postalMatch.group(1) ?? '';
        final city = tail.replaceFirst(postalMatch.group(0) ?? '', '').trim();
        if (city.isNotEmpty) clientCityController.text = city;
      } else {
        clientCityController.text = tail;
      }
    }

    chantierNotesController.clear();
    commentaireController.clear();
    phoneController.clear();
    emailController.clear();
    _selectedMetreurId = item.assignedMetreurId;
    _selectedMetreurName = item.assignedMetreurName;
    products = const [_ProductFormData(quantite: 1)];
    _ensureDefaultCategoryForProducts();
  }

  void _capitalizeFirstLetter(TextEditingController controller) {
    final text = controller.text;
    if (text.isEmpty) return;
    final capitalized = text[0].toUpperCase() + text.substring(1);
    if (capitalized == text) return;
    final selectionIndex = controller.selection.baseOffset;
    controller.value = controller.value.copyWith(
      text: capitalized,
      selection: TextSelection.collapsed(
        offset: selectionIndex.clamp(0, capitalized.length),
      ),
    );
  }

  String? _colorDetailLabel(String? choice) {
    switch (choice) {
      case 'RAL Aluminium':
        return 'RAL :';
      case 'Couleur PVC':
        return 'Couleur :';
      case 'Essence de Bois':
        return 'Essence :';
      default:
        return null;
    }
  }

  String _defaultCouleurForTrade() {
    switch (tradeKey) {
      case 'menuiserie_pvc':
        return 'Couleur PVC';
      case 'menuiserie_bois':
        return 'Essence de Bois';
      default:
        return 'RAL Aluminium';
    }
  }

  void _ensureDefaultCategoryForProducts() {
    final categories = _categoryChoices();
    if (categories.isEmpty) return;
    final defaultCategory = categories.first.key;
    final defaultCouleur = _defaultCouleurForTrade();
    var changed = false;
    final updated = <_ProductFormData>[];

    if (products.isEmpty) {
      updated.add(_ProductFormData(categoryKey: defaultCategory, couleur: defaultCouleur));
      changed = true;
    } else {
      for (final product in products) {
        if (product.categoryKey == null || product.couleur == null) {
          updated.add(product.copyWith(
            categoryKey: product.categoryKey ?? defaultCategory,
            couleur: product.couleur ?? defaultCouleur,
          ));
          changed = true;
        } else {
          updated.add(product);
        }
      }
    }

    if (changed) {
      setState(() {
        products = updated;
      });
    }
  }

  _ProductFormData _newProductWithDefaultCategory() {
    final categories = _categoryChoices();
    final defaultCategory = categories.isNotEmpty ? categories.first.key : null;
    return _ProductFormData(categoryKey: defaultCategory, couleur: _defaultCouleurForTrade());
  }

  _QuoteDraft _buildDraft() {
    return _QuoteDraft(
      clientName: clientNameController.text,
      clientFirstName: clientFirstNameController.text,
      street: clientStreetController.text,
      postal: clientPostalController.text,
      city: clientCityController.text,
      phone: phoneController.text,
      email: emailController.text,
      commentaire: commentaireController.text,
      chantierNotes: chantierNotesController.text,
      chantierType: chantierType,
      typeHabitation: typeHabitation,
      accessibilite: accessibilite,
      date: selectedDate,
      products: products,
      assignedMetreurId: _selectedMetreurId == 'any' ? null : _selectedMetreurId,
      assignedMetreurName: _selectedMetreurName,
    );
  }

  @override
  void dispose() {
    clientNameController.dispose();
    clientFirstNameController.dispose();
    clientStreetController.dispose();
    clientPostalController.dispose();
    clientCityController.dispose();
    phoneController.dispose();
    emailController.dispose();
    commentaireController.dispose();
    chantierNotesController.dispose();
    quantiteController.dispose();
    largeurController.dispose();
    hauteurController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _currentTradeNode() {
    final key = tradeKey;
    if (key == null) return null;
    final metiers = dictionary?['metiers'];
    if (metiers is Map && metiers[key] is Map<String, dynamic>) {
      return metiers[key] as Map<String, dynamic>;
    }
    return null;
  }

  List<_Choice> _categoryChoices() {
    final trade = _currentTradeNode();
    final cats = trade?['categories'];
    if (cats is Map<String, dynamic>) {
      return cats.entries
          .map((e) => _Choice(e.key, e.value['label']?.toString() ?? e.key))
          .toList();
    }
    return const [];
  }

  List<String> _sousCategories(String? categoryKey) {
    if (categoryKey == null) return const [];
    final trade = _currentTradeNode();
    final cat = trade?['categories']?[categoryKey];
    if (cat is Map && cat['sous_categories'] is List) {
      return (cat['sous_categories'] as List).map((e) => e.toString()).toList();
    }
    return const [];
  }

  List<_Choice> _typeChoices(String? categoryKey) {
    if (categoryKey == null) return const [];
    final trade = _currentTradeNode();
    final cat = trade?['categories']?[categoryKey];
    if (cat is Map && cat['types'] is Map) {
      return (cat['types'] as Map<String, dynamic>)
          .entries
          .map((e) => _Choice(e.key, e.value['label']?.toString() ?? e.key))
          .toList();
    }
    return const [];
  }

  List<String> _variantForType(String? categoryKey, String? typeKey) {
    if (categoryKey == null || typeKey == null) return const [];
    final trade = _currentTradeNode();
    final type = trade?['categories']?[categoryKey]?['types']?[typeKey];
    if (type is Map && type['variantes'] is List) {
      return (type['variantes'] as List).map((e) => e.toString()).toList();
    }
    return const [];
  }

  String _categoryLabelFromKey(String? categoryKey) {
    if (categoryKey == null) return '';
    final trade = _currentTradeNode();
    final cat = trade?['categories']?[categoryKey];
    if (cat is Map && cat['label'] != null) return cat['label'].toString();
    return categoryKey;
  }

  String _typeLabelFromKey(String? categoryKey, String? typeKey) {
    if (categoryKey == null || typeKey == null) return typeKey ?? '';
    final trade = _currentTradeNode();
    final typeData = trade?['categories']?[categoryKey]?['types']?[typeKey];
    if (typeData is Map) return typeData['label']?.toString() ?? typeKey;
    return typeKey;
  }

  List<Map<String, dynamic>> _buildSummaryFromDraft(_QuoteDraft draft) {
    final entries = <Map<String, dynamic>>[];
    void addEntry(String label, String? value) {
      final clean = value?.trim();
      if (clean != null && clean.isNotEmpty) {
        entries.add({'label': label, 'value': clean});
      }
    }

    addEntry('Type de chantier', draft.chantierType);
    addEntry('Type d’habitation', draft.typeHabitation);
    addEntry('Accessibilité', draft.accessibilite);
    addEntry('Commentaires chantier', draft.chantierNotes);

    for (var i = 0; i < draft.products.length; i++) {
      final p = draft.products[i];
      final catLabel = _categoryLabelFromKey(p.categoryKey);
      final buffer = StringBuffer();
      buffer.write(catLabel);
      if (p.sousCategorie?.isNotEmpty == true) buffer.write(' • ${p.sousCategorie}');
      if (p.typeProduit?.isNotEmpty == true) buffer.write(' • ${_typeLabelFromKey(p.categoryKey, p.typeProduit)}');
      if (p.variante?.isNotEmpty == true) buffer.write(' • ${p.variante}');
      if (p.couleur?.isNotEmpty == true) buffer.write(' • Couleur: ${p.couleur}');
      final dimParts = <String>[];
      if (p.largeur != null) dimParts.add('${p.largeur}');
      if (p.hauteur != null) dimParts.add('${p.hauteur}');
      if (dimParts.isNotEmpty) {
        buffer.write(' • Dim: ${dimParts.join(' x ')} ${p.unite}');
      }
      if (p.quantite != null) buffer.write(' • Qté: ${p.quantite}');
      addEntry('Élément ${i + 1}', buffer.toString());
    }

    if (draft.date != null) {
      final d = draft.date!;
      final formatted = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      addEntry('Chantier prévu', formatted);
    }

    return entries;
  }

  Future<void> _onPostalCodeChanged(String value) async {
    final postalCode = value.trim();
    // Utilise la même logique que create_workspace_screen.dart
    if (postalCode.length != 5 || !RegExp(r'^\d{5}$').hasMatch(postalCode)) {
      setState(() {
        clientCityController.clear();
        citySuggestions = [];
      });
      return;
    }

    if (postalCode == _lastPostalLookup) return;
    _lastPostalLookup = postalCode;

    // Pré-remplir avec un fallback immédiat (comme l'écran de création compte).
    final fallback = _postalFallback[postalCode];
    if (fallback != null && fallback.isNotEmpty) {
      setState(() {
        citySuggestions = fallback;
        clientCityController.text = fallback.first;
      });
      if (fallback.length > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showCitySelector(fallback);
        });
      }
    } else {
      setState(() {
        citySuggestions = [];
        clientCityController.clear();
      });
    }

    await _fetchCitiesForPostalCode(postalCode);
  }

  Future<void> _fetchCitiesForPostalCode(String postalCode) async {
    setState(() {
      isFetchingCities = true;
      citySuggestions = [];
      clientCityController.clear();
    });

    try {
      final url = Uri.parse('https://geo.api.gouv.fr/communes?codePostal=$postalCode&fields=nom');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        final List<String> cities = data.map((city) => city['nom'].toString()).toSet().toList()..sort();

        if (!mounted) return;
        if (cities.isEmpty) {
          _applyFallbackCity(postalCode);
        } else {
          setState(() {
            citySuggestions = cities;
            clientCityController.text = cities.first;
          });

          if (cities.length > 1 && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showCitySelector(cities);
            });
          }
        }
      } else {
        if (!mounted) return;
        _applyFallbackCity(postalCode);
      }
    } catch (_) {
      if (!mounted) return;
      _applyFallbackCity(postalCode);
    } finally {
      if (mounted) {
        setState(() => isFetchingCities = false);
      }
    }
  }

  void _applyFallbackCity(String postalCode) {
    final cities = _postalFallback[postalCode] ?? const [];
    setState(() {
      citySuggestions = cities;
      if (cities.isNotEmpty) clientCityController.text = cities.first;
    });

    if (cities.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCitySelector(cities);
      });
    }
  }

  void _showCitySelector(List<String> cities) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _commercialCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints.maxHeight * 0.75;
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.grey200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Sélectionnez la commune',
                        style: TextStyle(
                          color: AppColors.grey900,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (_, index) {
                          final city = cities[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(city, style: const TextStyle(color: AppColors.grey900)),
                            onTap: () {
                              setState(() => clientCityController.text = city);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                        separatorBuilder: (_, __, ) => const Divider(height: 1, color: AppColors.grey100),
                        itemCount: cities.length,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _uploadFile(String path) async {
    try {
      setState(() => uploadLabel = 'Envoi du devis…');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(path)}';
      final storage = FirebaseStorage.instanceFor(bucket: _storageBucket);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final prefs = await SharedPreferences.getInstance();
      final workspace = prefs.getString(_workspaceIdKey);
      if (uid == null || workspace == null) {
        throw Exception('Utilisateur ou workspace manquant pour sécuriser le fichier.');
      }
      final ref = storage.ref().child('devis_uploads/$workspace/$uid/$fileName');

      // Certaines sélections (bibliothèque photos) nécessitent une lecture en mémoire.
      final file = File(path);
      final bytes = await file.readAsBytes();
      final uploadTask = await ref.putData(bytes);
      final success = uploadTask.bytesTransferred > 0;
      if (!success) throw Exception('Téléversement incomplet.');

      // Tente d’obtenir l’URL sans bloquer l’utilisateur si le bucket refuse.
      try {
        final url = await ref.getDownloadURL();
        uploadedFileUrl = url;
      } catch (_) {
        uploadedFileUrl = null;
      }

      setState(() => uploadLabel = 'Devis stocké pour le reste de l’équipe.');
    } catch (e) {
      _showPickerError(context, 'Envoi impossible : $e');
      setState(() => uploadLabel = null);
    }
  }

  Future<void> _pickFiles() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (picked == null || picked.files.isEmpty) return;
      final firstPath = picked.files.first.path;
      if (firstPath == null) {
        _showPickerError(context, 'Impossible de lire ce fichier.');
        return;
      }
      setState(() => selectedFiles = picked.files.map((f) => f.name).toList());
      await _uploadFile(firstPath);
    } on PlatformException catch (e) {
      _showPickerError(context, 'Sélection de fichier impossible (${e.code}).');
    } catch (e) {
      _showPickerError(context, 'Sélection de fichier impossible.');
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final picker = ImagePicker();
      final photos = await picker.pickMultiImage();
      if (photos.isEmpty) return;
      final firstPath = photos.first.path;
      setState(() => selectedFiles = photos.map((f) => f.name).toList());
      await _uploadFile(firstPath);
    } on PlatformException catch (e) {
      _showPickerError(context, 'Accès appareil photo impossible (${e.code}).');
    } catch (e) {
      _showPickerError(context, 'Accès appareil photo impossible.');
    }
  }

  Widget _stepHeader() {
    const labels = ['Client', 'Chantier', 'Éléments', 'Date', 'Commentaires', 'Upload devis'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(labels.length, (index) {
            final active = index == currentStep;
            final done = index < currentStep;
            return Row(
              children: [
                _StepBadge(
                  index: index,
                  label: labels[index],
                  active: active,
                  done: done,
                ),
                if (index != labels.length - 1)
                  Container(
                    width: 32,
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: done ? _commercialAccent : AppColors.grey200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _clientForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Coordonnées client', style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _LabeledField(
          label: 'Nom',
          controller: clientNameController,
          keyboardType: TextInputType.name,
          required: true,
          onChanged: (_) => _capitalizeFirstLetter(clientNameController),
        ),
        _LabeledField(
          label: 'Prénom',
          controller: clientFirstNameController,
          keyboardType: TextInputType.name,
          onChanged: (_) => _capitalizeFirstLetter(clientFirstNameController),
        ),
        _LabeledField(
          label: 'Adresse (rue)',
          controller: clientStreetController,
          keyboardType: TextInputType.streetAddress,
          required: true,
        ),
        Row(
          children: [
            Expanded(
              child: _LabeledField(
                label: 'Code postal',
                controller: clientPostalController,
                keyboardType: TextInputType.number,
                required: true,
                maxLength: 5,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onPostalCodeChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LabeledField(
                label: 'Ville',
                controller: clientCityController,
                keyboardType: TextInputType.text,
                readOnly: true,
                onTap: () {
                  if (citySuggestions.length > 1) _showCitySelector(citySuggestions);
                },
                hintText: isFetchingCities ? 'Chargement…' : 'Selon code postal',
              ),
            ),
          ],
        ),
        _LabeledField(
          label: 'Téléphone',
          controller: phoneController,
          keyboardType: TextInputType.phone,
          required: true,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        _LabeledField(
          label: 'Email',
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return null;
            final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
            return isValid ? null : 'Email invalide';
          },
        ),
      ],
    );
  }

  Widget _chantierForm() {
    final fields = dictionary?['workit_commercial']?['part2_infos_generales']?['fields']
        as Map<String, dynamic>? ??
        {};
    String? typeChantier = chantierType;
    String? habitationVal = typeHabitation;
    String? accessVal = accessibilite;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            const Text('Infos générales chantier', style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800)),
            if (tradeLabel != null)
              Chip(
                label: Text(
                  tradeLabel!,
                  style: const TextStyle(color: Colors.black),
                  overflow: TextOverflow.ellipsis,
                ),
                backgroundColor: _commercialAccent.withOpacity(0.85),
              ),
          ],
        ),
        const SizedBox(height: 12),
        DynamicDropdownField(
          label: 'Type de chantier',
          value: typeChantier,
          required: true,
          choices: fields['type_chantier']?['choices']?.cast<String>() ?? const [],
          onChanged: (v) => setState(() => chantierType = v),
        ),
        DynamicDropdownField(
          label: "Type d'habitation",
          value: habitationVal,
          choices: fields['type_habitation']?['choices']?.cast<String>() ?? const [],
          onChanged: (v) => setState(() => typeHabitation = v),
        ),
        DynamicDropdownField(
          label: 'Accessibilité',
          value: accessVal,
          choices: fields['site_accessibilite']?['choices']?.cast<String>() ?? const [],
          onChanged: (v) => setState(() => accessibilite = v),
        ),
        _LabeledField(
          label: 'Commentaires',
          controller: chantierNotesController,
          keyboardType: TextInputType.multiline,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _productCard(int index) {
    final product = products[index];
    final categories = _categoryChoices();
    final sousCategories = _sousCategories(product.categoryKey);
    final types = _typeChoices(product.categoryKey);
    final variants = _variantForType(product.categoryKey, product.typeProduit);
    const couleurs = ['RAL Aluminium', 'Couleur PVC', 'Essence de Bois'];
    final colorDetailLabel = _colorDetailLabel(product.couleur);
    final bool showDecorOptions = tradeKey == 'menuiserie_aluminium';
    final bool showDimensions = tradeKey == 'menuiserie_aluminium';
    final bool showVariant = tradeKey == 'menuiserie_aluminium';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Élément ${index + 1}',
                style: const TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800),
              ),
              if (products.length > 1)
                IconButton(
                  onPressed: () => setState(() => products.removeAt(index)),
                  icon: const Icon(Icons.delete_outline, color: AppColors.grey400),
                ),
            ],
          ),
          _DropdownField(
            label: 'Catégorie',
            value: product.categoryKey,
            required: true,
            items: categories,
            onChanged: (v) => setState(() {
              products[index] = products[index].copyWith(
                categoryKey: v,
                sousCategorie: null,
                typeProduit: null,
                variante: null,
              );
            }),
          ),
          _DropdownField(
            label: 'Sous-catégorie',
            value: product.sousCategorie,
            items: sousCategories,
            onChanged: (v) => setState(() => products[index] = products[index].copyWith(sousCategorie: v)),
          ),
          _DropdownField(
            label: 'Type',
            value: product.typeProduit,
            items: types,
            onChanged: (v) => setState(() => products[index] = products[index].copyWith(typeProduit: v, variante: null)),
          ),
          if (showVariant)
            _DropdownField(
              label: 'Spécificité / variante',
              value: product.variante,
              items: variants.isEmpty ? const ['Standard'] : variants,
              onChanged: (v) => setState(() => products[index] = products[index].copyWith(variante: v)),
            ),
          if (showDecorOptions) ...[
            _DropdownField(
              label: 'Couleur',
              value: product.couleur,
              items: couleurs,
              onChanged: (v) => setState(() => products[index] = products[index].copyWith(couleur: v, couleurDetail: null)),
            ),
            if (colorDetailLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(colorDetailLabel, style: const TextStyle(color: AppColors.grey500)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(text: product.couleurDetail ?? '')
                        ..selection = TextSelection.collapsed(offset: (product.couleurDetail ?? '').length),
                      style: const TextStyle(color: AppColors.grey900),
                      onChanged: (text) => setState(() => products[index] = products[index].copyWith(couleurDetail: text)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.grey50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.grey200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.grey200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _commercialAccent, width: 1.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (showDimensions)
            Row(
              children: [
                Expanded(
                  child: _IntField(
                    label: 'Largeur',
                    value: product.largeur,
                    onChanged: (v) => setState(() => products[index] = products[index].copyWith(largeur: v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _IntField(
                    label: 'Hauteur',
                    value: product.hauteur,
                    onChanged: (v) => setState(() => products[index] = products[index].copyWith(hauteur: v)),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: _DropdownField(
                    label: 'Unité',
                    value: product.unite,
                    items: const ['mm', 'cm', 'm'],
                    onChanged: (v) => setState(() => products[index] = products[index].copyWith(unite: v ?? 'mm')),
                  ),
                ),
              ],
            ),
          _IntField(
            label: 'Quantité',
            value: product.quantite,
            onChanged: (v) => setState(() => products[index] = products[index].copyWith(quantite: v)),
          ),
        ],
      ),
    );
  }

  Widget _productForm() {
    if (_currentTradeNode() == null) {
      return const Text(
        'Aucun corps de métier sélectionné. Définissez-le lors de l’onboarding pour charger les choix produits.',
        style: TextStyle(color: AppColors.grey500),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Éléments du devis', style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...List.generate(products.length, _productCard),
        Align(
          alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => setState(() => products.add(_newProductWithDefaultCategory())),
        icon: const Icon(Icons.add, color: _commercialAccent),
        label: const Text(
          'Ajouter un élément',
          style: TextStyle(color: _commercialAccent, fontWeight: FontWeight.w700),
        ),
          ),
        ),
      ],
    );
  }

  Widget _dateForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Planification', style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.grey50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: Text(
                  selectedDate != null
                      ? 'Chantier prévu : ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                      : 'Choisir une date estimative',
                  style: const TextStyle(color: AppColors.grey500),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _commercialAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? now,
                  firstDate: now,
                  lastDate: DateTime(now.year + 2),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: _commercialAccent,
                          surface: _commercialCard,
                          onSurface: AppColors.grey900,
                        ),
                      ),
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                );
                if (picked != null) setState(() => selectedDate = picked);
              },
              child: const Text('Choisir'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _commentsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Commentaires', style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _LabeledField(
          label: 'Notes supplémentaires',
          controller: commentaireController,
          keyboardType: TextInputType.multiline,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _metreurStep() {
    if (loadingMetreurs) {
      return const Center(child: CircularProgressIndicator(color: _commercialAccent));
    }
    if (_metreurs.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: _commercialCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.grey200),
        ),
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Aucun métreur disponible dans l’entreprise.',
          style: TextStyle(color: AppColors.grey500),
        ),
      );
    }

    final options = [
      ..._metreurs,
      const _MetreurOption(id: 'any', name: 'Peu importe', email: null),
    ];
    final groupValue = _selectedMetreurId ?? 'any';

    return Container(
      decoration: BoxDecoration(
        color: _commercialCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attribuer à un métreur',
            style: const TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ...options.map((m) {
            final selected = groupValue == m.id;
            return RadioListTile<String>(
              value: m.id,
              groupValue: groupValue,
              onChanged: (value) {
                setState(() {
                  _selectedMetreurId = value;
                  _selectedMetreurName = value == 'any' ? 'Peu importe' : m.name;
                });
              },
              activeColor: _commercialAccent,
              title: Text(
                m.name,
                style: const TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700),
              ),
              subtitle: m.email != null ? Text(m.email!, style: const TextStyle(color: AppColors.grey500)) : null,
              tileColor: selected ? AppColors.primaryLight : Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _uploadStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Uploader le devis', style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text(
          'Ajoutez un PDF ou des photos. Le devis sera stocké et accessible aux métreurs/poseurs.',
          style: TextStyle(color: AppColors.grey500),
        ),
        const SizedBox(height: 14),
        if (selectedFiles.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedFiles
                .map(
                  (f) => Chip(
                    label: Text(f, style: const TextStyle(color: AppColors.grey900)),
                    backgroundColor: AppColors.grey100,
                    side: BorderSide(color: AppColors.grey200),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.folder_open,
          label: 'Uploader un PDF / JPEG',
          description: 'Depuis vos fichiers ou Drive',
          primary: true,
          onTap: _pickFiles,
        ),
        const SizedBox(height: 12),
        _ActionTile(
          icon: Icons.photo_camera_outlined,
          label: 'Prendre photo (plusieurs pages)',
          description: 'Ajoutez toutes les pages en une fois',
          primary: false,
          onTap: _pickPhotos,
        ),
        if (uploadLabel != null) ...[
          const SizedBox(height: 10),
          Text(uploadLabel!, style: const TextStyle(color: AppColors.grey500)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _clientForm(),
      _chantierForm(),
      _productForm(),
      _dateForm(),
      _metreurStep(),
      _commentsForm(),
      _uploadStep(),
    ]
        .map(
          (w) => SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: w,
          ),
        )
        .toList();

    return Scaffold(
      backgroundColor: _commercialBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.grey700),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Nouveau devis', style: TextStyle(color: AppColors.grey900)),
      ),
      body: SafeArea(
        child: loadingDictionary
            ? const Center(child: CircularProgressIndicator(color: _commercialAccent))
            : loadingTrade
                ? const Center(child: CircularProgressIndicator(color: _commercialAccent))
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _stepHeader(),
                        const SizedBox(height: 12),
                        Expanded(
                          child: PageView(
                            controller: pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: steps,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (currentStep > 0)
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.grey700,
                                  side: const BorderSide(color: AppColors.grey300),
                                ),
                                onPressed: () {
                                  currentStep = (currentStep - 1).clamp(0, steps.length - 1);
                                  pageController.animateToPage(
                                    currentStep,
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                  );
                                  setState(() {});
                                },
                                child: const Text('Précédent'),
                              ),
                            const Spacer(),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _commercialAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              ),
                              onPressed: () async {
                                if (currentStep < steps.length - 1) {
                                  currentStep++;
                                  pageController.animateToPage(
                                    currentStep,
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                  );
                                  setState(() {});
                                  return;
                                }
                                await _saveQuoteToCloud();
                                if (!mounted) return;
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Devis enregistré et partagé avec l’équipe.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: Text(currentStep == steps.length - 1 ? 'Soumettre' : 'Suivant'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Future<void> _saveQuoteToCloud() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    final workspaceId = prefs.getString('workit_workspace_id');

    if (uid == null || workspaceId == null) return;

    final draft = _buildDraft();
    final existing = widget.existingItem;
    
    // Construct the quote item
    final newItem = _QuoteItem(
      client: clientNameController.text.isNotEmpty
          ? '${clientNameController.text}${clientFirstNameController.text.isNotEmpty ? ' ${clientFirstNameController.text}' : ''}'
          : 'Nouveau client',
      address: '${clientStreetController.text}, ${clientPostalController.text} ${clientCityController.text}',
      number: existing?.number ?? '#${DateTime.now().millisecondsSinceEpoch % 10000}',
      date: existing?.date ?? 'Ajouté aujourd’hui',
      tag: '',
      assignedMetreurId: _selectedMetreurId == 'any' ? null : _selectedMetreurId,
      assignedMetreurName: _selectedMetreurName,
      draft: draft,
      id: existing?.id,
      createdAt: existing?.createdAt ?? DateTime.now(),
      uploadUrl: uploadedFileUrl ?? existing?.uploadUrl,
    );

    try {
        final col = FirebaseFirestore.instance.collection('workspaces').doc(workspaceId).collection('devis');
        final sanitizedNumber = newItem.number.replaceAll('#', '');
        final docId = (newItem.id?.isNotEmpty == true)
            ? newItem.id!
            : (sanitizedNumber.isNotEmpty
                ? sanitizedNumber
                : 'quote_${DateTime.now().millisecondsSinceEpoch}');
        final ref = col.doc(docId);

        String? categoryLabel;
        final firstProduct = newItem.draft?.products.isNotEmpty == true ? newItem.draft!.products.first : null;
        if (firstProduct != null) {
          categoryLabel = _categoryLabelFromKey(firstProduct.categoryKey);
        }

        final summary = newItem.draft != null ? _buildSummaryFromDraft(newItem.draft!) : <Map<String, dynamic>>[];
        final attachments = <Map<String, dynamic>>[];
        if (newItem.uploadUrl != null && newItem.uploadUrl!.isNotEmpty) {
          attachments.add({
            'label': 'Devis du commercial',
            'icon': Icons.picture_as_pdf.codePoint,
            'thumbnailUrl': newItem.uploadUrl,
          });
        }

        final combinedClientName = [
          newItem.draft?.clientFirstName?.trim() ?? '',
          newItem.draft?.clientName?.trim() ?? '',
        ].where((e) => e.isNotEmpty).join(' ').trim();

        await ref.set({
          ...newItem.toMap(),
          'userId': uid,
          'workspaceId': workspaceId,
          'metreurId': newItem.assignedMetreurId,
          // Only set status to 'Nouvelle demande' if it's a new quote or doesn't have a status yet.
          // If editing, we want to preserve the status ideally, but for now we might reset if not careful.
          // However, existing Metreur workflow relies on status. 
          // If existing item has status, keep it. 
          'status': existing?.status ?? 'Nouvelle demande',
          'category': categoryLabel,
          'phone': newItem.draft?.phone,
          'updated': 'À l’instant',
          'note': newItem.draft?.commentaire ?? newItem.draft?.chantierNotes ?? '',
          'summary': summary,
          'attachments': attachments,
          if (combinedClientName.isNotEmpty) 'client': combinedClientName,
          'createdAt': newItem.createdAt != null
              ? Timestamp.fromDate(newItem.createdAt!)
              : FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving quote: $e');
      if (mounted) _showPickerError(context, 'Erreur sauvegarde: $e');
    }
  }

}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.primary,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? AppColors.primary : AppColors.grey100;
    final fg = primary ? Colors.white : AppColors.grey700;
    final border = primary ? Colors.transparent : AppColors.grey200;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary ? Colors.white.withOpacity(0.15) : AppColors.grey200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: fg.withOpacity(0.78),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: fg.withOpacity(0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({
    required this.index,
    required this.label,
    required this.active,
    required this.done,
  });

  final int index;
  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final Color fill = done
        ? _commercialAccent
        : active
            ? _commercialAccent
            : AppColors.grey200;
    final Color textColor = done || active ? Colors.white : AppColors.grey500;
    final Color labelColor = done
        ? _commercialAccent
        : active
            ? AppColors.grey900
            : AppColors.grey400;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? _commercialAccent.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? _commercialAccent.withOpacity(0.5) : Colors.transparent),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: fill,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

void _showPickerError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.redAccent,
    ),
  );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.required = false,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.hintText,
    this.inputFormatters,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final int maxLines;
  final int? maxLength;
  final bool required;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? hintText;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required ? '$label *' : label,
            style: const TextStyle(color: AppColors.grey500),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            maxLength: maxLength,
            style: const TextStyle(color: AppColors.grey900),
            onChanged: onChanged,
            readOnly: readOnly,
            onTap: onTap,
            inputFormatters: inputFormatters,
            validator: validator,
            autovalidateMode: validator != null ? AutovalidateMode.onUserInteraction : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.grey50,
              hintText: hintText,
              hintStyle: const TextStyle(color: AppColors.grey400),
              counterText: maxLength != null ? '' : null,
              errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _commercialAccent, width: 1.3),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1.3),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.items,
    this.value,
    this.onChanged,
    this.required = false,
  });

  final String label;
  final List<dynamic> items;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final List<String> itemValues = items.map(_itemValue).toList();
    final String? currentValue =
        (value != null && itemValues.contains(value)) ? value : (itemValues.isNotEmpty ? itemValues.first : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required ? '$label *' : label,
            style: const TextStyle(color: AppColors.grey500),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey200),
            ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              isExpanded: true,
              dropdownColor: _commercialCard,
              style: const TextStyle(color: AppColors.grey900),
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.grey500),
              items: items
                    .map(
                      (e) => DropdownMenuItem(
                        value: _itemValue(e),
                        child: Text(_itemLabel(e)),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _itemValue(dynamic e) {
    if (e is _Choice) return e.key;
    return e.toString();
  }

  String _itemLabel(dynamic e) {
    if (e is _Choice) return e.label;
    return e.toString();
  }
}

class _IntField extends StatelessWidget {
  const _IntField({required this.label, this.value, this.onChanged});

  final String label;
  final int? value;
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final text = value?.toString() ?? '';
    final controller = TextEditingController(text: text)
      ..selection = TextSelection.collapsed(offset: text.length);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.grey500)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.grey900),
            onChanged: (text) {
              final parsed = int.tryParse(text);
              onChanged?.call(parsed);
            },
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.grey50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _commercialAccent, width: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductFormData {
  const _ProductFormData({
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
  });

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

  _ProductFormData copyWith({
    String? categoryKey,
    String? sousCategorie,
    String? typeProduit,
    String? variante,
    String? couleur,
    String? couleurDetail,
    int? largeur,
    int? hauteur,
    int? quantite,
    String? unite,
  }) {
    return _ProductFormData(
      categoryKey: categoryKey ?? this.categoryKey,
      sousCategorie: sousCategorie ?? this.sousCategorie,
      typeProduit: typeProduit ?? this.typeProduit,
      variante: variante ?? this.variante,
      couleur: couleur ?? this.couleur,
      couleurDetail: couleurDetail ?? this.couleurDetail,
      largeur: largeur ?? this.largeur,
      hauteur: hauteur ?? this.hauteur,
      quantite: quantite ?? this.quantite,
      unite: unite ?? this.unite,
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
    };
  }

  factory _ProductFormData.fromMap(Map<String, dynamic> map) {
    return _ProductFormData(
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

/// Pill de filtre style maquette.
/// isSelected gère fill bleu (actif) vs bordure grise (inactif).
class _PillTab extends StatelessWidget {
  const _PillTab({required this.label, required this.count, this.isSelected = false});
  final String label;
  final int count;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
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

/// Tab "Tous" — affiche toutes les affaires sans filtre
class _AllItemsList extends StatelessWidget {
  const _AllItemsList({required this.items});
  final List<_QuoteItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Aucune affaire', style: TextStyle(color: AppColors.grey400)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
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
          case 'À clôturer':
            badge = 'Terminé'; badgeColor = AppColors.grey500; break;
          default:
            badge = item.status ?? ''; badgeColor = AppColors.grey400;
        }
        return _QuoteCard(
          title: item.client,
          subtitle: item.address,
          meta: item.date,
          badgeLabel: badge,
          badgeColor: badgeColor,
          statusValue: item.status,
          onTap: () => _showChantierDetail(context, item),
        );
      },
    );
  }
}

class _Choice {
  const _Choice(this.key, this.label);
  final String key;
  final String label;
}

class _MetreurOption {
  const _MetreurOption({required this.id, required this.name, required this.email});
  final String id;
  final String name;
  final String? email;
}

class _QuoteItem {
  const _QuoteItem({
    required this.client,
    required this.address,
    required this.number,
    required this.date,
    required this.tag,
    this.assignedMetreurId,
    this.assignedMetreurName,
    this.draft,
    this.id,
    this.createdAt,
    this.uploadUrl,
    this.status,
    this.phone,
    this.email,
    this.clientFirstName,
    this.poseurNames,
    this.poseDate,
    this.rapportFin,
    this.rapportProbleme,
    this.infoRequest,
    this.meetingAt,
    this.metreurNote,
    this.metreurNoteName,
  });

  final String client;
  final String address;
  final String number;
  final String date;
  final String tag;
  final String? assignedMetreurId;
  final String? assignedMetreurName;
  final _QuoteDraft? draft;
  final String? id;
  final DateTime? createdAt;
  final String? uploadUrl;
  final String? status;
  final String? phone;
  final String? email;
  final String? clientFirstName;
  final String? poseurNames;
  final DateTime? poseDate;
  final Map<String, dynamic>? rapportFin;
  final Map<String, dynamic>? rapportProbleme;
  final Map<String, dynamic>? infoRequest;
  final DateTime? meetingAt;
  final String? metreurNote;
  final String? metreurNoteName;

  _QuoteItem copyWith({
    String? client,
    String? address,
    String? number,
    String? date,
    String? tag,
    String? assignedMetreurId,
    String? assignedMetreurName,
    _QuoteDraft? draft,
    String? id,
    DateTime? createdAt,
    String? uploadUrl,
    String? status,
    String? phone,
    String? email,
    String? clientFirstName,
    String? poseurNames,
    DateTime? poseDate,
    Map<String, dynamic>? rapportFin,
    Map<String, dynamic>? rapportProbleme,
    Map<String, dynamic>? infoRequest,
  }) {
    return _QuoteItem(
      client: client ?? this.client,
      address: address ?? this.address,
      number: number ?? this.number,
      date: date ?? this.date,
      tag: tag ?? this.tag,
      assignedMetreurId: assignedMetreurId ?? this.assignedMetreurId,
      assignedMetreurName: assignedMetreurName ?? this.assignedMetreurName,
      draft: draft ?? this.draft,
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      uploadUrl: uploadUrl ?? this.uploadUrl,
      status: status ?? this.status,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      clientFirstName: clientFirstName ?? this.clientFirstName,
      poseurNames: poseurNames ?? this.poseurNames,
      poseDate: poseDate ?? this.poseDate,
      rapportFin: rapportFin ?? this.rapportFin,
      rapportProbleme: rapportProbleme ?? this.rapportProbleme,
      infoRequest: infoRequest ?? this.infoRequest,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client': client,
      'address': address,
      'number': number,
      'date': date,
      'tag': tag,
      'assignedMetreurId': assignedMetreurId,
      'assignedMetreurName': assignedMetreurName,
      'draft': draft?.toMap(),
      'createdAt': createdAt?.toIso8601String(),
      'uploadUrl': uploadUrl,
      'status': status,
    };
  }

  factory _QuoteItem.fromMap(Map<String, dynamic> map) {
    DateTime? poseDate;
    if (map['poseDate'] is Timestamp) {
      poseDate = (map['poseDate'] as Timestamp).toDate();
    }
    return _QuoteItem(
      id: map['id']?.toString(),
      client: map['client']?.toString() ?? 'Client',
      address: map['address']?.toString() ?? '',
      number: map['number']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      tag: map['tag']?.toString() ?? '',
      assignedMetreurId: map['assignedMetreurId']?.toString(),
      assignedMetreurName: map['assignedMetreurName']?.toString(),
      draft: map['draft'] is Map<String, dynamic>
          ? _QuoteDraft.fromMap(map['draft'] as Map<String, dynamic>)
          : null,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : (map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'].toString())
              : null),
      uploadUrl: map['uploadUrl']?.toString(),
      status: (map['status'] ?? map['metreurStatus'])?.toString(),
      phone: map['phone']?.toString() ?? map['clientPhone']?.toString(),
      email: map['email']?.toString() ?? map['clientEmail']?.toString(),
      clientFirstName: map['clientFirstName']?.toString(),
      poseurNames: map['poseurNames']?.toString(),
      poseDate: poseDate,
      rapportFin: map['rapportFin'] is Map
          ? Map<String, dynamic>.from(map['rapportFin'] as Map)
          : null,
      rapportProbleme: map['rapportProbleme'] is Map
          ? Map<String, dynamic>.from(map['rapportProbleme'] as Map)
          : null,
      infoRequest: map['infoRequest'] is Map
          ? Map<String, dynamic>.from(map['infoRequest'] as Map)
          : null,
      meetingAt: map['meetingAt'] is Timestamp
          ? (map['meetingAt'] as Timestamp).toDate()
          : null,
      metreurNote: map['metreurNote']?.toString(),
      metreurNoteName: map['metreurNoteName']?.toString(),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.title,
    required this.subtitle,
    required this.meta,
    this.badgeLabel,
    required this.badgeColor,
    this.trailing,
    this.thumbnailUrl,
    this.onEdit,
    this.onDelete,
    this.onTap,
    this.statusValue,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String meta;
  final String? badgeLabel;
  final Color badgeColor;
  final Widget? trailing;
  final String? thumbnailUrl;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final String? statusValue;   // status brut pour les dots
  final String? actionLabel;   // label bouton CTA
  final VoidCallback? onAction;

  /// 0=Nouvelle demande  1=En cours  2=À commander  3=À planifier/En pose  4=Terminé
  static int _stepIndex(String? s) {
    if (s == null || s == 'Nouvelle demande' || s == 'Acceptée' || s == 'À classer'
        || s == 'En attente') return 0;
    if (s == 'En cours' || s == 'Devis prog.' || s == 'Métré programmé') return 1;
    if (s == 'À commander' || s == 'Commande en cours') return 2;
    if (s == 'À planifier' || s == 'En pose' || s == 'Chantier à planifier') return 3;
    return 4;
  }

  static String _defaultAction(String? s) {
    if (s == null || s == 'Nouvelle demande') return 'Relancer →';
    if (s == 'En cours') return 'Rappel →';
    if (s == 'À commander' || s == 'Commande en cours') return 'Commander →';
    if (s == 'À planifier') return 'Planifier →';
    if (s == 'En pose') return 'Suivi →';
    return 'Voir →';
  }

  @override
  Widget build(BuildContext context) {
    final step = _stepIndex(statusValue ?? badgeLabel);
    final ctaLabel = actionLabel ?? _defaultAction(statusValue ?? badgeLabel);
    final isDone = step == 4;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDone ? AppColors.grey100 : AppColors.cardBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(color: isDone ? AppColors.grey500 : AppColors.grey900, fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(subtitle, style: const TextStyle(color: AppColors.grey500, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (badgeLabel != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: badgeColor.withOpacity(0.13), borderRadius: BorderRadius.circular(20)),
                        child: Text(badgeLabel!, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                    if (onEdit != null || onDelete != null) ...[
                      const SizedBox(width: 4),
                      Column(children: [
                        if (onEdit != null) IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.grey400), onPressed: onEdit, visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                        if (onDelete != null) IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.grey400), onPressed: onDelete, visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                      ]),
                    ],
                  ],
                ),
                // ── Meta ──
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(meta, style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
                ),
                // ── Step dots ──
                if (!isDone) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(5, (i) {
                      final done = i <= step;
                      final active = i == step;
                      return Container(
                        width: active ? 18 : 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: done ? badgeColor : AppColors.grey200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ],
                // ── Boutons ──
                if (!isDone) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            side: const BorderSide(color: AppColors.grey200),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Voir détails', style: TextStyle(fontSize: 13, color: AppColors.grey700, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onAction ?? onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: badgeColor,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(ctaLabel, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPreview(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: InteractiveViewer(
            child: Image.network(
              url,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 200,
                child: Center(
                  child: Icon(Icons.picture_as_pdf, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Détail chantier ────────────────────────────────────────────────────────

void _showChantierDetail(BuildContext context, _QuoteItem item) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: _commercialCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ChantierDetailSheet(item: item),
  );
}

class _ChantierDetailSheet extends StatelessWidget {
  const _ChantierDetailSheet({required this.item});
  final _QuoteItem item;

  @override
  Widget build(BuildContext context) {
    final status = item.status ?? '';
    final isTermine = status == 'Terminé' || status == 'Clôturé';
    final isProbleme = status == 'À clôturer';
    final rapport = isTermine ? item.rapportFin : null;
    final probleme = isProbleme ? item.rapportProbleme : null;
    final photoUrls = (rapport?['photoUrls'] as List?)
        ?.whereType<String>()
        .toList() ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.grey200,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          Text(
            item.client,
            style: const TextStyle(
              color: AppColors.grey900,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (item.clientFirstName?.isNotEmpty == true)
            Text(item.clientFirstName!, style: const TextStyle(color: AppColors.grey500)),
          const SizedBox(height: 4),
          Text(item.address, style: const TextStyle(color: AppColors.grey500)),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor(status).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _statusColor(status).withOpacity(0.4)),
            ),
            child: Text(
              status.isEmpty ? 'En attente' : status,
              style: TextStyle(
                color: _statusColor(status),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (item.phone?.isNotEmpty == true)
            _DetailRow(
              icon: Icons.phone_outlined,
              label: item.phone!,
              onTap: () async {
                await launchUrl(Uri.parse('tel:${item.phone}'));
              },
            ),
          if (item.email?.isNotEmpty == true)
            _DetailRow(
              icon: Icons.email_outlined,
              label: item.email!,
              onTap: () async {
                await launchUrl(Uri.parse('mailto:${item.email}'));
              },
            ),
          if (item.phone?.isNotEmpty == true || item.email?.isNotEmpty == true)
            const SizedBox(height: 12),

          if (item.assignedMetreurName?.isNotEmpty == true)
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Métreur : ${item.assignedMetreurName}',
            ),

          if (item.uploadUrl?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                await launchUrl(
                  Uri.parse(item.uploadUrl!),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.grey50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: _commercialAccent),
                    SizedBox(width: 10),
                    Text(
                      'Voir le devis',
                      style: TextStyle(color: _commercialAccent, fontWeight: FontWeight.w600),
                    ),
                    Spacer(),
                    Icon(Icons.open_in_new, color: AppColors.grey400, size: 18),
                  ],
                ),
              ),
            ),
          ],

          if (item.poseDate != null) ...[
            const SizedBox(height: 16),
            const _SectionHeader(label: 'Pose programmée'),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: _formatDateTime(item.poseDate!),
            ),
            if (item.poseurNames?.isNotEmpty == true)
              _DetailRow(
                icon: Icons.group_outlined,
                label: 'Équipe : ${item.poseurNames}',
              ),
          ],

          if (item.metreurNote?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _SectionHeader(
              label: 'Message du métreur${item.metreurNoteName?.isNotEmpty == true ? " (${item.metreurNoteName})" : ""}',
              color: Colors.amberAccent,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Text(
                item.metreurNote!,
                style: const TextStyle(color: AppColors.grey900),
              ),
            ),
          ] else if (item.infoRequest != null) ...[
            const SizedBox(height: 16),
            const _SectionHeader(label: 'Message du métreur'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Text(
                item.infoRequest!['message']?.toString() ?? '',
                style: const TextStyle(color: AppColors.grey900),
              ),
            ),
          ],

          if (probleme != null) ...[
            const SizedBox(height: 16),
            const _SectionHeader(label: 'Problème signalé', color: Colors.orangeAccent),
            const SizedBox(height: 8),
            if ((probleme['soucis'] as String?)?.isNotEmpty == true)
              _RapportField(label: 'Soucis', value: probleme['soucis'] as String),
            if ((probleme['manque'] as String?)?.isNotEmpty == true)
              _RapportField(label: 'Manque', value: probleme['manque'] as String),
            if ((probleme['erreur'] as String?)?.isNotEmpty == true)
              _RapportField(label: 'Erreur', value: probleme['erreur'] as String),
          ],

          if (rapport != null) ...[
            const SizedBox(height: 16),
            const _SectionHeader(label: 'Réception chantier', color: _commercialAccent),
            const SizedBox(height: 8),
            _DetailRow(
              icon: rapport['reglementEffectue'] == true
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
              label: rapport['reglementEffectue'] == true
                  ? 'Règlement effectué'
                  : 'Règlement non effectué',
              iconColor: rapport['reglementEffectue'] == true
                  ? _commercialAccent
                  : Colors.redAccent,
            ),
            if (photoUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Photos (${photoUrls.length})',
                style: const TextStyle(color: AppColors.grey500, fontSize: 13),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) => GestureDetector(
                    onTap: () => showDialog(
                      context: ctx,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.black87,
                        child: InteractiveViewer(
                          child: Image.network(photoUrls[i]),
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        photoUrls[i],
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100,
                          height: 100,
                          color: AppColors.grey100,
                          child: const Icon(Icons.broken_image, color: AppColors.grey400),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Nouvelle demande':
        return Colors.deepPurpleAccent;
      case 'Acceptée':
      case 'En cours':
        return Colors.lightBlueAccent;
      case 'À commander':
      case 'Commande en cours':
        return Colors.orangeAccent;
      case 'À planifier':
      case 'En pose':
        return _commercialAccent;
      case 'Terminé':
      case 'Clôturé':
        return _commercialAccent;
      case 'À clôturer':
        return Colors.orangeAccent;
      default:
        return AppColors.grey400;
    }
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} à ${h}h$m';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: color ?? AppColors.grey900,
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.grey400, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: onTap != null ? _commercialAccent : AppColors.grey700,
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RapportField extends StatelessWidget {
  const _RapportField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppColors.grey900)),
        ],
      ),
    );
  }
}

// ─── Bottom nav item ──────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.activeIcon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final IconData activeIcon;
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
            Icon(active ? activeIcon : icon, size: 24, color: active ? AppColors.primary : AppColors.grey400),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.primary : AppColors.grey400)),
          ],
        ),
      ),
    );
  }
}

// ─── Données de démonstration ─────────────────────────────────────────────────
final _kDemoDevis = <_QuoteItem>[
  _QuoteItem(
    client: 'Dupont Jean', address: '14 rue Ledru-Rollin, Paris 15e',
    number: '#5001', date: 'Il y a 2 jours', tag: 'Nouvelle demande', status: null,
    phone: '06 12 34 56 78', email: 'dupont@email.fr',
  ),
  _QuoteItem(
    client: 'Martin Sophie', address: '8 avenue des Arts, Lyon 3e',
    number: '#5002', date: 'Il y a 5 jours', tag: 'En cours', status: 'En cours',
    assignedMetreurName: 'Pascal M.',
    meetingAt: DateTime.now().add(const Duration(days: 2)),
  ),
  _QuoteItem(
    client: 'Bernard Marc', address: '22 quai de la Loire, Nantes',
    number: '#5003', date: 'Il y a 8 jours', tag: 'À planifier', status: 'À planifier',
    assignedMetreurName: 'Pascal M.',
  ),
  _QuoteItem(
    client: 'Laurent Céline', address: '5 impasse des Pins, Toulouse',
    number: '#5004', date: 'Il y a 10 jours', tag: 'Commande en cours', status: 'Commande en cours',
    assignedMetreurName: 'Pascal M.',
  ),
  _QuoteItem(
    client: 'Petit Thomas', address: '3 allée des Roses, Bordeaux',
    number: '#5005', date: 'Il y a 12 jours', tag: 'En pose', status: 'En pose',
    assignedMetreurName: 'Pascal M.',
    poseurNames: 'Équipe A',
    poseDate: DateTime.now(),
  ),
  _QuoteItem(
    client: 'Moreau Julie', address: '17 rue du Moulin, Strasbourg',
    number: '#5006', date: 'Il y a 20 jours', tag: 'Terminé', status: 'Terminé',
  ),
];

// ─── Stat card ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.color});
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color, letterSpacing: -1)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.grey500, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
