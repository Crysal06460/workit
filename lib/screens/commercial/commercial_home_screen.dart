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

import '../admin_home_screen.dart';
import '../chantier_chat_screen.dart';
import '../entry_screen.dart';
import '../planner_screen.dart';
import '../sign_in_screen.dart';
import '../settings_screen.dart';
import '../widgets/dynamic_dropdown_field.dart';
import '../../core/models/wi_devis_summary.dart';
import '../../core/responsive/responsive_context.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/recent_chantiers.dart';
import '../../core/widgets/shell/wi_app_shell.dart';
import '../../core/widgets/wi_bottom_nav.dart';
import '../../core/widgets/wi_devis_card.dart';
import '../../core/widgets/wi_devis_list_modal.dart';
import '../../core/widgets/wi_kanban_board.dart';
import '../../core/widgets/wi_recent_chantiers_section.dart';
import '../../core/widgets/wi_responsive_dialog.dart';
import '../../core/widgets/wi_stat_row.dart';
import '../../core/widgets/wi_status_badge.dart';
import '../../services/devis_service.dart';

part 'commercial_models.dart';
part 'commercial_quote_list.dart';
part 'commercial_quote_wizard.dart';
part 'commercial_chantier_detail.dart';

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
  bool _canPlaceOrders = false;
  String _searchQuery = '';
  int _bottomNavIndex = 0;
  String? _selectedQuoteId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadWorkspaceContext();
    await _loadCanPlaceOrders();
  }

  /// Droit délégué (par un admin, par utilisateur) de passer commande —
  /// normalement réservé au métreur. Lu en direct depuis Firestore, pas mis
  /// en cache (même pattern que canManageTeam dans settings_screen.dart).
  Future<void> _loadCanPlaceOrders() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final canPlaceOrders = doc.data()?['canPlaceOrders'] == true;
      if (mounted) setState(() => _canPlaceOrders = canPlaceOrders);
    } catch (_) {
      // Reste à false par défaut en cas d'erreur réseau.
    }
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return DefaultTabController(
      length: 7,
      child: WiAppShell(
        navItems: const [
          WiNavItem(icon: Icons.description_outlined, activeIcon: Icons.description_rounded, label: 'Devis'),
          WiNavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month_rounded, label: 'Agenda'),
          WiNavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Réglages'),
        ],
        currentIndex: _bottomNavIndex,
        onNavTap: _onNavTap,
        accentColor: AppColors.roleCommercial,
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
                stream: (_workspaceId == null || uid == null)
                    ? const Stream.empty()
                    : _firestore
                        .collection('workspaces')
                        .doc(_workspaceId)
                        .collection('devis')
                        .where('userId', isEqualTo: uid)
                        .snapshots(),
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
          // Sur desktop, le Kanban ci-dessous regroupe déjà tous les statuts
          // visuellement — la barre de pills devient redondante.
          bottom: context.isDesktop ? null : PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
              child: SizedBox(
                child: StreamBuilder<QuerySnapshot>(
                  stream: (_workspaceId == null || uid == null)
                      ? const Stream.empty()
                      : _firestore
                          .collection('workspaces')
                          .doc(_workspaceId)
                          .collection('devis')
                          .where('userId', isEqualTo: uid)
                          .orderBy('createdAt', descending: true)
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
                      return status == 'À clôturer' ||
                          status == 'Terminé' ||
                          status == 'Clôturé' ||
                          status == 'SAV';
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
                stream: (_workspaceId == null || uid == null)
                    ? const Stream.empty()
                    : _firestore
                        .collection('workspaces')
                        .doc(_workspaceId)
                        .collection('devis')
                        .where('userId', isEqualTo: uid)
                        .snapshots(),
                builder: (context, snap) {
                  final docs = snap.data?.docs ?? [];
                  // 6 catégories distinctes (décidées avec Christophe) — voir
                  // admin_dashboard_tab.dart pour le même découpage.
                  final attenteDocs = <_QuoteItem>[], commanderDocs = <_QuoteItem>[],
                      planifierDocs = <_QuoteItem>[], poseDocs = <_QuoteItem>[],
                      termineDocs = <_QuoteItem>[], savDocs = <_QuoteItem>[];
                  for (final doc in docs) {
                    final raw = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
                    raw['id'] = doc.id;
                    final s = (raw['status'] ?? raw['metreurStatus'])?.toString();
                    final item = _QuoteItem.fromMap(raw);
                    if (s == null || s == 'Nouvelle demande' || s == 'Acceptée' || s == 'En cours') {
                      attenteDocs.add(item);
                    } else if (s == 'À commander' || s == 'Commande en cours') {
                      commanderDocs.add(item);
                    } else if (s == 'À planifier') {
                      planifierDocs.add(item);
                    } else if (s == 'En pose' || s == 'À clôturer') {
                      poseDocs.add(item);
                    } else if (s == 'SAV') {
                      savDocs.add(item);
                    } else {
                      termineDocs.add(item);
                    }
                  }
                  final demoAttente = _kDemoDevis.where((d) => d.status == null || d.status == 'Nouvelle demande' || d.status == 'Acceptée' || d.status == 'En cours').toList();
                  final demoCommander = _kDemoDevis.where((d) => d.status == 'À commander' || d.status == 'Commande en cours').toList();
                  final demoPlanifier = _kDemoDevis.where((d) => d.status == 'À planifier').toList();
                  final demoPose = _kDemoDevis.where((d) => d.status == 'En pose' || d.status == 'À clôturer').toList();
                  final demoSav = _kDemoDevis.where((d) => d.status == 'SAV').toList();
                  final demoTermine = _kDemoDevis.where((d) => d.status == 'Terminé' || d.status == 'Clôturé').toList();
                  final allAttente = [...attenteDocs, ...demoAttente];
                  final allCommander = [...commanderDocs, ...demoCommander];
                  final allPlanifier = [...planifierDocs, ...demoPlanifier];
                  final allPose = [...poseDocs, ...demoPose];
                  final allTermine = [...termineDocs, ...demoTermine];
                  final allSav = [...savDocs, ...demoSav];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: WiStatRow(
                      compactOnDesktop: true,
                      stats: [
                        WiStat(
                          value: '${allAttente.length}', label: 'En attente', color: AppColors.warning,
                          onTap: () => WiDevisListModal.show(context,
                              title: 'En attente', items: allAttente.map((e) => _toSummary(context, e)).toList()),
                        ),
                        WiStat(
                          value: '${allCommander.length}', label: 'À commander', color: AppColors.amber,
                          onTap: () => WiDevisListModal.show(context,
                              title: 'À commander', items: allCommander.map((e) => _toSummary(context, e)).toList()),
                        ),
                        WiStat(
                          value: '${allPlanifier.length}', label: 'À planifier', color: AppColors.primary,
                          onTap: () => WiDevisListModal.show(context,
                              title: 'À planifier', items: allPlanifier.map((e) => _toSummary(context, e)).toList()),
                        ),
                        WiStat(
                          value: '${allPose.length}', label: 'En pose', color: AppColors.purple,
                          onTap: () => WiDevisListModal.show(context,
                              title: 'En pose', items: allPose.map((e) => _toSummary(context, e)).toList()),
                        ),
                        WiStat(
                          value: '${allTermine.length}', label: 'Terminé', color: AppColors.success,
                          onTap: () => WiDevisListModal.show(context,
                              title: 'Terminé', items: allTermine.map((e) => _toSummary(context, e)).toList()),
                        ),
                        WiStat(
                          value: '${allSav.length}', label: 'SAV', color: AppColors.danger,
                          onTap: () => WiDevisListModal.show(context,
                              title: 'SAV', items: allSav.map((e) => _toSummary(context, e)).toList()),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: (_workspaceId == null || uid == null)
                    ? const Stream.empty()
                    : _firestore
                        .collection('workspaces')
                        .doc(_workspaceId)
                        .collection('devis')
                        .where('userId', isEqualTo: uid)
                        .snapshots(),
                builder: (context, snap) {
                  final docs = snap.data?.docs ?? [];
                  final items = [
                    ..._kDemoDevis,
                    ...docs.map((doc) {
                      final raw = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
                      raw['id'] = doc.id;
                      return _QuoteItem.fromMap(raw);
                    }),
                  ];
                  final recent = mergeRecentChantiers(items.map((e) => _toSummary(context, e)).toList());
                  if (recent.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: WiRecentChantiersSection(
                      title: 'Chantiers récemment ajoutés',
                      items: recent,
                    ),
                  );
                },
              ),
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
                    await showWiAdaptiveModal<_QuoteItem>(
                      context,
                      builder: (_) => const _AddQuoteScreen(),
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
                    stream: (_workspaceId == null || uid == null)
                        ? const Stream.empty()
                        : _firestore
                            .collection('workspaces')
                            .doc(_workspaceId)
                            .collection('devis')
                            .where('userId', isEqualTo: uid)
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
                          return status == 'À clôturer' ||
                              status == 'Terminé' ||
                              status == 'Clôturé' ||
                              status == 'SAV';
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

                      // ── Desktop : vue pipeline en colonnes (Kanban) + panneau détail ──
                      if (context.isDesktop) {
                        // Les items de démo n'ont pas d'`id` Firestore — `number` est
                        // toujours renseigné et unique, on l'utilise comme clé de repli.
                        String keyOf(_QuoteItem it) => it.id ?? it.number;

                        _QuoteItem? selected;
                        if (_selectedQuoteId != null) {
                          for (final it in allItems) {
                            if (keyOf(it) == _selectedQuoteId) { selected = it; break; }
                          }
                        }
                        Widget kanbanCard(_QuoteItem item, String badgeLabel, Color badgeColor) {
                          return _quoteCardFor(
                            context,
                            item,
                            workspaceId: _workspaceId!,
                            canPlaceOrders: _canPlaceOrders,
                            meta: item.date,
                            badge: _quoteBadge(badgeLabel, badgeColor),
                            onTap: () => setState(() => _selectedQuoteId = keyOf(item)),
                          );
                        }
                        // _NewQuotesList/_ScheduledList fusionnent les items de démo en
                        // interne (mobile) — reproduit ici pour que le Kanban desktop
                        // affiche les mêmes dossiers.
                        final demoAttente = _kDemoDevis.where((d) => d.status == null || d.status == 'Nouvelle demande');
                        final demoProg = _kDemoDevis.where((d) => d.status == 'En cours');
                        final board = WiKanbanBoard(columns: [
                          WiKanbanColumn(
                            id: 'attente', label: 'En attente', color: AppColors.warning,
                            cards: [...demoAttente, ...newItems].map((i) => kanbanCard(i, 'En attente', AppColors.warning)).toList(),
                          ),
                          WiKanbanColumn(
                            id: 'prog', label: 'Devis prog.', color: AppColors.purple,
                            cards: [...demoProg, ...scheduledItems].map((i) => kanbanCard(i, 'Devis prog.', AppColors.purple)).toList(),
                          ),
                          WiKanbanColumn(
                            id: 'commander', label: 'À commander', color: AppColors.amber,
                            cards: commandeItems.map((i) => kanbanCard(i, i.status ?? 'À commander', AppColors.amber)).toList(),
                          ),
                          WiKanbanColumn(
                            id: 'planifier', label: 'À planifier', color: AppColors.primary,
                            cards: planifierItems.map((i) => kanbanCard(i, 'À planifier', AppColors.primary)).toList(),
                          ),
                          WiKanbanColumn(
                            id: 'pose', label: 'En pose', color: AppColors.success,
                            cards: poseItems.map((i) => kanbanCard(i, 'En pose', AppColors.success)).toList(),
                          ),
                          WiKanbanColumn(
                            id: 'termines', label: 'Terminés', color: AppColors.grey500,
                            cards: terminesItems.map((i) => kanbanCard(
                              i,
                              i.status == 'À clôturer' ? 'À valider' : i.status == 'SAV' ? 'SAV' : 'Terminé',
                              i.status == 'À clôturer' ? Colors.orangeAccent : i.status == 'SAV' ? Colors.deepOrangeAccent : AppColors.grey500,
                            )).toList(),
                          ),
                        ]);
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: board),
                            if (selected != null) ...[
                              const VerticalDivider(width: 1, color: AppColors.grey200),
                              SizedBox(
                                width: 420,
                                child: _ChantierDetailPanel(
                                  item: selected,
                                  workspaceId: _workspaceId!,
                                  onClose: () => setState(() => _selectedQuoteId = null),
                                ),
                              ),
                            ],
                          ],
                        );
                      }

                      return TabBarView(
                        children: [
                          _AllItemsList(items: allItems, workspaceId: _workspaceId!, canPlaceOrders: _canPlaceOrders),
                          _NewQuotesList(
                            items: newItems,
                            workspaceId: _workspaceId!,
                            onDelete: (item) {},
                            onEdit: (item) async {
                              await showWiAdaptiveModal<_QuoteItem>(
                                context,
                                builder: (_) => _AddQuoteScreen(existingItem: item),
                              );
                            },
                          ),
                          _ScheduledList(items: scheduledItems, workspaceId: _workspaceId!),
                          _ValidatedList(items: commandeItems, workspaceId: _workspaceId!, canPlaceOrders: _canPlaceOrders),
                          _ValidatedList(items: planifierItems, workspaceId: _workspaceId!),
                          _ValidatedList(items: poseItems, workspaceId: _workspaceId!),
                          _ValidatedList(items: terminesItems, workspaceId: _workspaceId!),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onNavTap(int index) {
    setState(() => _bottomNavIndex = index);
    if (index == 1) {
      if (_workspaceId == null) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: const Text('Agenda', style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800)),
            iconTheme: const IconThemeData(color: AppColors.grey600),
          ),
          body: PlannerScreen(workspaceId: _workspaceId!, accentColor: AppColors.roleCommercial),
        ),
      ));
    } else if (index == 2) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    }
  }

  // Même mapping statut → couleur que `_AllItemsList` (commercial_quote_list.dart) —
  // dupliqué volontairement (chaque écran a déjà sa propre logique de badge par
  // statut, pas de composant partagé pour ça, voir stratégie DRY du popup/récents).
  Color _summaryStatusColor(String? status) {
    switch (status) {
      case null:
      case 'Nouvelle demande':
      case 'Acceptée':
        return AppColors.warning;
      case 'En cours':
        return AppColors.purple;
      case 'À commander':
      case 'Commande en cours':
        return AppColors.amber;
      case 'À planifier':
        return AppColors.primary;
      case 'En pose':
        return AppColors.success;
      case 'À clôturer':
        return Colors.orangeAccent;
      case 'SAV':
        return Colors.deepOrangeAccent;
      case 'Terminé':
      case 'Clôturé':
        return AppColors.grey500;
      default:
        return AppColors.grey400;
    }
  }

  WiDevisSummary _toSummary(BuildContext context, _QuoteItem item) {
    final status = item.status;
    return WiDevisSummary(
      id: item.id ?? item.number,
      clientLabel: item.client,
      address: item.address,
      status: status ?? '',
      statusLabel: status == null || status.isEmpty ? 'Nouvelle demande' : status,
      statusColor: _summaryStatusColor(status),
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      onTap: () => _showChantierDetail(context, item, _workspaceId!),
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

