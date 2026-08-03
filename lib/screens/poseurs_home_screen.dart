import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chantier_chat_screen.dart';
import 'settings_screen.dart';
import 'sign_in_screen.dart';
import '../core/theme/app_colors.dart';

// ─── Palette ────────────────────────────────────────────────────────────────
const Color _poseurBg = AppColors.background;
const Color _poseurCard = AppColors.surface;
const Color _poseurAccent = AppColors.primary;

// ─── SharedPreferences keys ─────────────────────────────────────────────────
const String _workspaceIdKey = 'workit_workspace_id';
const String _userFirstNameKey = 'workit_user_first_name';
const String _userLastNameKey = 'workit_user_last_name';

// ─── Storage bucket ──────────────────────────────────────────────────────────
const String _storageBucket = 'gs://workit-1daa1.firebasestorage.app';

// ════════════════════════════════════════════════════════════════════════════
// PoseursHomeScreen
// ════════════════════════════════════════════════════════════════════════════
class PoseursHomeScreen extends StatefulWidget {
  const PoseursHomeScreen({super.key});

  @override
  State<PoseursHomeScreen> createState() => _PoseursHomeScreenState();
}

class _PoseursHomeScreenState extends State<PoseursHomeScreen> {
  final _firestore = FirebaseFirestore.instance;

  String? _workspaceId;
  String? _userId;
  String? _firstName;
  String? _lastName;

  bool _loading = true;
  List<_ChantierData> _aFaire = [];
  List<_ChantierData> _historique = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  String _greetingName() {
    if (_firstName?.trim().isNotEmpty == true) return _firstName!.trim();
    if (_lastName?.trim().isNotEmpty == true) return _lastName!.trim();
    return '';
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _workspaceId = prefs.getString(_workspaceIdKey);
    _firstName = prefs.getString(_userFirstNameKey);
    _lastName = prefs.getString(_userLastNameKey);
    _userId = FirebaseAuth.instance.currentUser?.uid;
    await _loadChantiers();
  }

  Future<void> _loadChantiers() async {
    if (!mounted) return;
    setState(() => _loading = true);

    if (_workspaceId == null || _userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final snap = await _firestore
          .collection('workspaces')
          .doc(_workspaceId)
          .collection('devis')
          .where('poseurIds', arrayContains: _userId)
          .orderBy('poseDate', descending: false)
          .get();

      final aFaire = <_ChantierData>[];
      final historique = <_ChantierData>[];

      for (final doc in snap.docs) {
        final data = _ChantierData.fromMap(doc.id, doc.data());
        final status = data.metreurStatus ?? '';
        if (status == 'En pose') {
          aFaire.add(data);
        } else if (status == 'À clôturer' ||
            status == 'Terminé' ||
            status == 'Clôturé') {
          historique.add(data);
        }
      }

      if (mounted) {
        setState(() {
          _aFaire = aFaire;
          _historique = historique;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('_loadChantiers error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _poseurBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _greetingName().isNotEmpty
                    ? 'Bonjour ${_greetingName()}'
                    : 'Bonjour',
                style: const TextStyle(
                  color: AppColors.grey900,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Poseur',
                style: TextStyle(color: AppColors.grey500, fontSize: 14),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: _poseurAccent),
              tooltip: 'Actualiser',
              onPressed: _loadChantiers,
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppColors.grey600),
              tooltip: 'Paramètres',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: _poseurAccent),
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
            preferredSize: const Size.fromHeight(72),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.surface, AppColors.surface],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.grey50),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.white70,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppColors.grey50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _poseurAccent.withOpacity(0.5)),
                  ),
                  indicatorPadding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  tabs: [
                    Tab(
                      child: _TabPill(
                        label: 'À faire',
                        count: _aFaire.length,
                        color: _poseurAccent,
                        icon: Icons.construction_outlined,
                      ),
                    ),
                    Tab(
                      child: _TabPill(
                        label: 'Historique',
                        count: _historique.length,
                        color: AppColors.grey400,
                        icon: Icons.history_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _poseurAccent),
              )
            : SafeArea(
                child: TabBarView(
                  children: [
                    _ChantierList(
                      items: _aFaire,
                      emptyMessage: 'Aucun chantier assigné.',
                      workspaceId: _workspaceId ?? '',
                      onRefresh: _loadChantiers,
                    ),
                    _ChantierList(
                      items: _historique,
                      emptyMessage: 'Aucun chantier dans l\'historique.',
                      workspaceId: _workspaceId ?? '',
                      onRefresh: _loadChantiers,
                      isHistorique: true,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _ChantierList
// ════════════════════════════════════════════════════════════════════════════
class _ChantierList extends StatelessWidget {
  const _ChantierList({
    required this.items,
    required this.emptyMessage,
    required this.workspaceId,
    required this.onRefresh,
    this.isHistorique = false,
  });

  final List<_ChantierData> items;
  final String emptyMessage;
  final String workspaceId;
  final VoidCallback onRefresh;
  final bool isHistorique;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isHistorique
                    ? Icons.history_outlined
                    : Icons.construction_outlined,
                color: AppColors.grey200,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: const TextStyle(color: AppColors.grey400, fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return _ChantierCard(
          data: item,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _PoseurChantierDetail(
                  data: item,
                  workspaceId: workspaceId,
                  onRefresh: onRefresh,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _ChantierCard
// ════════════════════════════════════════════════════════════════════════════
class _ChantierCard extends StatelessWidget {
  const _ChantierCard({required this.data, required this.onTap});

  final _ChantierData data;
  final VoidCallback onTap;

  Color _statusColor(String? status) {
    switch (status) {
      case 'Terminé':
        return Colors.greenAccent;
      case 'Clôturé':
        return Colors.tealAccent;
      case 'À clôturer':
        return Colors.orangeAccent;
      case 'En pose':
      default:
        return _poseurAccent;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'Terminé':
        return 'Terminé';
      case 'Clôturé':
        return 'Clôturé';
      case 'À clôturer':
        return 'À clôturer';
      case 'En pose':
      default:
        return 'En pose';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(data.metreurStatus);
    final statusLabel = _statusLabel(data.metreurStatus);
    final poseDate = data.poseDate;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: _poseurCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.grey100),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status badge + date
              Row(
                children: [
                  _StatusBadge(label: statusLabel, color: statusColor),
                  const Spacer(),
                  if (poseDate != null) ...[
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: AppColors.grey400),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(poseDate),
                      style: const TextStyle(
                          color: AppColors.grey400, fontSize: 12),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Client name
              Text(
                data.clientDisplay,
                style: const TextStyle(
                  color: AppColors.grey900,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              // Address
              if (data.address?.isNotEmpty == true) ...[
                Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 14, color: AppColors.grey400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        data.address!,
                        style: const TextStyle(
                            color: AppColors.grey500, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              // Category + poseur names
              Row(
                children: [
                  if (data.category?.isNotEmpty == true) ...[
                    const Icon(Icons.category_outlined,
                        size: 14, color: AppColors.grey400),
                    const SizedBox(width: 4),
                    Text(
                      data.category!,
                      style: const TextStyle(
                          color: AppColors.grey400, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (poseDate != null) ...[
                    const Icon(Icons.access_time,
                        size: 14, color: AppColors.grey400),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(poseDate),
                      style: const TextStyle(
                          color: AppColors.grey400, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _PoseurChantierDetail
// ════════════════════════════════════════════════════════════════════════════
class _PoseurChantierDetail extends StatefulWidget {
  const _PoseurChantierDetail({
    required this.data,
    required this.workspaceId,
    required this.onRefresh,
  });

  final _ChantierData data;
  final String workspaceId;
  final VoidCallback onRefresh;

  @override
  State<_PoseurChantierDetail> createState() => _PoseurChantierDetailState();
}

class _PoseurChantierDetailState extends State<_PoseurChantierDetail> {
  bool get _isReadOnly {
    final s = widget.data.metreurStatus;
    return s == 'Terminé' || s == 'Clôturé';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final draft = data.draft;

    return Scaffold(
      backgroundColor: _poseurBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.grey900, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          data.clientDisplay,
          style: const TextStyle(
            color: AppColors.grey900,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        actions: [
          ChatEntryButton(
            devisId: data.id,
            clientLabel: data.clientDisplay,
            color: AppColors.rolePoseur,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Scrollable body ──────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Section 1 : Coordonnées client ───────────────────
                    _SectionTitle(
                      icon: Icons.person_outline,
                      label: 'Coordonnées client',
                    ),
                    const SizedBox(height: 10),
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nom complet depuis draft ou champs racine
                          _InfoLine(
                            icon: Icons.badge_outlined,
                            label: 'Client',
                            value: data.clientDisplay,
                          ),
                          if (data.address?.isNotEmpty == true)
                            _InfoLine(
                              icon: Icons.place_outlined,
                              label: 'Adresse',
                              value: data.address!,
                            ),
                          if (draft?.street?.isNotEmpty == true &&
                              draft!.street != data.address)
                            _InfoLine(
                              icon: Icons.location_on_outlined,
                              label: 'Rue',
                              value: [
                                draft.street,
                                draft.postal,
                                draft.city,
                              ]
                                  .where((e) => e?.isNotEmpty == true)
                                  .join(' '),
                            ),
                          if (data.phone?.isNotEmpty == true)
                            _InfoLine(
                              icon: Icons.phone_outlined,
                              label: 'Téléphone',
                              value: data.phone!,
                              trailing: TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: _poseurAccent,
                                ),
                                onPressed: () =>
                                    _callNumber(context, data.phone!),
                                child: const Text('Appeler'),
                              ),
                            ),
                          if (draft?.email?.isNotEmpty == true)
                            _InfoLine(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: draft!.email!,
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Section 2 : Devis commercial ─────────────────────
                    _SectionTitle(
                      icon: Icons.description_outlined,
                      label: 'Devis commercial',
                    ),
                    const SizedBox(height: 10),
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Bouton "Voir le devis" si pièce jointe disponible
                          if (data.attachments.isNotEmpty) ...[
                            _DevisButton(
                              attachments: data.attachments,
                            ),
                            const SizedBox(height: 12),
                          ],
                          // Résumé commercial
                          if (data.summary.isNotEmpty) ...[
                            ...data.summary.map(
                              (e) => _InfoLine(
                                icon: Icons.check_circle_outline,
                                label: e.label,
                                value: e.value,
                              ),
                            ),
                          ] else if (data.attachments.isEmpty)
                            const Text(
                              'Aucun résumé commercial disponible.',
                              style: TextStyle(color: AppColors.grey400),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Section 3 : Détails métreur ──────────────────────
                    _SectionTitle(
                      icon: Icons.straighten_outlined,
                      label: 'Détails métreur',
                    ),
                    const SizedBox(height: 10),

                    if (draft != null && draft.products.isNotEmpty) ...[
                      // Chantier infos générales
                      if (draft.chantierType?.isNotEmpty == true ||
                          draft.typeHabitation?.isNotEmpty == true ||
                          draft.accessibilite?.isNotEmpty == true)
                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (draft.chantierType?.isNotEmpty == true)
                                _InfoLine(
                                  icon: Icons.construction_outlined,
                                  label: 'Type de chantier',
                                  value: draft.chantierType!,
                                ),
                              if (draft.typeHabitation?.isNotEmpty == true)
                                _InfoLine(
                                  icon: Icons.home_outlined,
                                  label: 'Type d\'habitation',
                                  value: draft.typeHabitation!,
                                ),
                              if (draft.accessibilite?.isNotEmpty == true)
                                _InfoLine(
                                  icon: Icons.accessible_outlined,
                                  label: 'Accessibilité',
                                  value: draft.accessibilite!,
                                ),
                            ],
                          ),
                        ),
                      if (draft.chantierNotes?.isNotEmpty == true ||
                          draft.commentaire?.isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (draft.chantierNotes?.isNotEmpty == true)
                                _InfoLine(
                                  icon: Icons.note_outlined,
                                  label: 'Notes chantier',
                                  value: draft.chantierNotes!,
                                ),
                              if (draft.commentaire?.isNotEmpty == true)
                                _InfoLine(
                                  icon: Icons.comment_outlined,
                                  label: 'Commentaire',
                                  value: draft.commentaire!,
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // Liste des produits
                      ...draft.products.asMap().entries.map((entry) {
                        final i = entry.key;
                        final p = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ProductCard(index: i, product: p),
                        );
                      }),
                    ] else
                      _GlassCard(
                        child: const Text(
                          'Aucun détail métreur disponible.',
                          style: TextStyle(color: AppColors.grey400),
                        ),
                      ),

                    const SizedBox(height: 80), // espace pour les boutons
                  ],
                ),
              ),
            ),

            // ── Section 4 : Actions sticky ──────────────────────────────
            if (!_isReadOnly)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                decoration: BoxDecoration(
                  color: _poseurBg,
                  border: Border(
                    top: BorderSide(
                        color: AppColors.grey50),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orangeAccent,
                          side: const BorderSide(
                              color: Colors.orangeAccent, width: 1.5),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => _openRapportProbleme(context),
                        icon: const Icon(Icons.warning_amber_outlined,
                            size: 18),
                        label: const Text(
                          'Chantier pas terminé',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _poseurAccent,
                          foregroundColor: Colors.black,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () => _openRapportFin(context),
                        icon: const Icon(Icons.check_circle_outline,
                            size: 18),
                        label: const Text(
                          'Chantier terminé',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 20),
                decoration: BoxDecoration(
                  color: _poseurBg,
                  border: Border(
                    top: BorderSide(
                        color: AppColors.grey50),
                  ),
                ),
                child: Center(
                  child: Text(
                    widget.data.metreurStatus == 'Clôturé'
                        ? 'Chantier clôturé'
                        : 'Chantier terminé — en attente de clôture',
                    style: const TextStyle(
                        color: AppColors.grey400, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openRapportFin(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _poseurCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RapportFinChantier(
        workspaceId: widget.workspaceId,
        devisId: widget.data.id,
        onDone: () {
          Navigator.of(context).pop(); // close bottom sheet
          Navigator.of(context).pop(); // back to list
          widget.onRefresh();
        },
      ),
    );
  }

  void _openRapportProbleme(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _poseurCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RapportProbleme(
        workspaceId: widget.workspaceId,
        devisId: widget.data.id,
        onDone: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
          widget.onRefresh();
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _ProductCard
// ════════════════════════════════════════════════════════════════════════════
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.index, required this.product});

  final int index;
  final _ProductData product;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey100),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _poseurAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Élément ${index + 1}',
                  style: const TextStyle(
                    color: _poseurAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (product.quantite?.isNotEmpty == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.grey100),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Qté : ${product.quantite}',
                    style: const TextStyle(
                        color: AppColors.grey500, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Détails produit
          if (product.categoryKey?.isNotEmpty == true)
            _ProductRow('Catégorie', product.categoryKey!),
          if (product.sousCategorie?.isNotEmpty == true)
            _ProductRow('Type', product.sousCategorie!),
          if (product.typeProduit?.isNotEmpty == true &&
              product.typeProduit != product.sousCategorie)
            _ProductRow('Produit', product.typeProduit!),
          if (product.variante?.isNotEmpty == true)
            _ProductRow('Variante', product.variante!),
          // Dimensions prévues
          if (product.largeur?.isNotEmpty == true ||
              product.hauteur?.isNotEmpty == true)
            _ProductRow(
              'Dimensions prévues',
              '${product.largeur ?? '-'} × ${product.hauteur ?? '-'} ${product.unite ?? 'mm'}',
            ),
          // Dimensions réelles
          if (product.largeurReelle?.isNotEmpty == true ||
              product.hauteurReelle?.isNotEmpty == true)
            _ProductRow(
              'Dimensions réelles',
              '${product.largeurReelle ?? '-'} × ${product.hauteurReelle ?? '-'}',
              highlight: true,
            ),
          // CJ
          if (_hasCJ(product)) ...[
            _ProductRow(
              'CJ (H/B/G/D)',
              [
                product.cjHaut,
                product.cjBas,
                product.cjGauche,
                product.cjDroite,
              ].map((e) => e?.isNotEmpty == true ? e! : '—').join(' / '),
            ),
          ],
          // Couleur
          if (product.couleur?.isNotEmpty == true)
            _ProductRow(
              'Couleur',
              [product.couleur, product.couleurDetail]
                  .where((e) => e?.isNotEmpty == true)
                  .join(' — '),
            ),
          // Référence / emplacement
          if (product.ref?.isNotEmpty == true)
            _ProductRow('Référence / Emplacement', product.ref!),
          // Note
          if (product.note?.isNotEmpty == true)
            _ProductRow('Note', product.note!),
        ],
      ),
    );
  }

  bool _hasCJ(_ProductData p) =>
      p.cjHaut?.isNotEmpty == true ||
      p.cjBas?.isNotEmpty == true ||
      p.cjGauche?.isNotEmpty == true ||
      p.cjDroite?.isNotEmpty == true;
}

class _ProductRow extends StatelessWidget {
  const _ProductRow(this.label, this.value, {this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label : ',
            style: const TextStyle(color: AppColors.grey400, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: highlight ? AppColors.primary : AppColors.grey900,
                fontSize: 13,
                fontWeight:
                    highlight ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _DevisButton
// ════════════════════════════════════════════════════════════════════════════
class _DevisButton extends StatelessWidget {
  const _DevisButton({required this.attachments});

  final List<_AttachmentEntry> attachments;

  @override
  Widget build(BuildContext context) {
    final att = attachments.first;
    final url = att.url;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: _poseurAccent,
        foregroundColor: Colors.black,
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      onPressed: url?.isNotEmpty == true
          ? () async {
              final uri = Uri.parse(url!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri,
                    mode: LaunchMode.inAppWebView);
              }
            }
          : null,
      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
      label: Text(
        att.label.isNotEmpty ? att.label : 'Voir le devis',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _RapportFinChantier (bottom sheet)
// ════════════════════════════════════════════════════════════════════════════
class _RapportFinChantier extends StatefulWidget {
  const _RapportFinChantier({
    required this.workspaceId,
    required this.devisId,
    required this.onDone,
  });

  final String workspaceId;
  final String devisId;
  final VoidCallback onDone;

  @override
  State<_RapportFinChantier> createState() => _RapportFinChantierState();
}

class _RapportFinChantierState extends State<_RapportFinChantier> {
  DateTime _dateFin = DateTime.now();
  bool _reglementEffectue = false;
  final List<File> _photos = [];
  File? _attestation;
  bool _loading = false;
  bool _showAttestationError = false;

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty && mounted) {
      setState(() {
        _photos.addAll(picked.map((e) => File(e.path)));
      });
    }
  }

  Future<void> _pickAttestation() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() {
        _attestation = File(picked.path);
        _showAttestationError = false;
      });
    }
  }

  Future<String?> _uploadFile(File file, String folder) async {
    try {
      final ref = FirebaseStorage.instanceFor(bucket: _storageBucket)
          .ref()
          .child(
              '$folder/${widget.workspaceId}/${widget.devisId}/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload file error: $e');
      return null;
    }
  }

  Future<List<String>> _uploadPhotos() async {
    final urls = <String>[];
    for (final file in _photos) {
      final url = await _uploadFile(file, 'chantier_photos');
      if (url != null) urls.add(url);
    }
    return urls;
  }

  Future<void> _valider() async {
    if (_loading) return;
    if (_attestation == null) {
      setState(() => _showAttestationError = true);
      return;
    }
    setState(() => _loading = true);

    final photoUrls = await _uploadPhotos();
    final attestationUrl = await _uploadFile(_attestation!, 'attestations_fin_travaux');

    try {
      await FirebaseFirestore.instance
          .collection('workspaces')
          .doc(widget.workspaceId)
          .collection('devis')
          .doc(widget.devisId)
          .set(
            {
              'status': 'Terminé',
              'rapportFin': {
                'date': _dateFin.toIso8601String(),
                'photoUrls': photoUrls,
                'attestationUrl': attestationUrl,
              },
              'paiementEffectue': _reglementEffectue,
              'paiementSetAt': FieldValue.serverTimestamp(),
              'clotureAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('_valider error: $e');
    }

    if (mounted) {
      setState(() => _loading = false);
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
            // Title
            Row(
              children: const [
                Icon(Icons.check_circle_outline,
                    color: _poseurAccent, size: 22),
                SizedBox(width: 8),
                Text(
                  'Rapport de fin de chantier',
                  style: TextStyle(
                    color: AppColors.grey900,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Date de fin
            const Text(
              'Date de fin',
              style:
                  TextStyle(color: AppColors.grey500, fontSize: 13),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateFin,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now()
                      .add(const Duration(days: 1)),
                  builder: (context, child) => Theme(
                    data: ThemeData.dark(),
                    child: child!,
                  ),
                );
                if (picked != null && mounted) {
                  setState(() => _dateFin = picked);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.grey50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.grey100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: AppColors.grey400, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      _formatDateFull(_dateFin),
                      style: const TextStyle(
                          color: AppColors.grey900,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Attestation de fin de travaux signée (obligatoire)
            const Text(
              'Attestation de fin de travaux signée',
              style: TextStyle(color: AppColors.grey500, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (_attestation != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _attestation!,
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => setState(() => _attestation = null),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: AppColors.grey900, size: 18),
                      ),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _poseurAccent,
                  side: BorderSide(
                    color: _showAttestationError
                        ? Colors.redAccent
                        : _poseurAccent,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _pickAttestation,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Photographier l\'attestation signée'),
              ),
            if (_showAttestationError)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'L\'attestation signée est obligatoire pour clôturer.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),

            const SizedBox(height: 16),

            // Toggle règlement
            Container(
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.grey100),
              ),
              child: SwitchListTile(
                value: _reglementEffectue,
                onChanged: (v) =>
                    setState(() => _reglementEffectue = v),
                activeColor: _poseurAccent,
                title: const Text(
                  'Chantier payé par le client',
                  style: TextStyle(
                      color: AppColors.grey900, fontSize: 14),
                ),
                subtitle: Text(
                  _reglementEffectue ? 'Payé' : 'Pas payé',
                  style: TextStyle(
                    color: _reglementEffectue
                        ? _poseurAccent
                        : Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Photos
            const Text(
              'Photos du chantier',
              style:
                  TextStyle(color: AppColors.grey500, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (_photos.isNotEmpty) ...[
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _photos[i],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _photos.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: AppColors.grey900, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: AppColors.grey200),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _pickPhotos,
              icon: const Icon(Icons.add_a_photo_outlined,
                  size: 18),
              label: Text(_photos.isEmpty
                  ? 'Ajouter des photos'
                  : 'Ajouter d\'autres photos'),
            ),

            const SizedBox(height: 24),

            // Valider
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _poseurAccent,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _loading ? null : _valider,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Valider la clôture',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _RapportProbleme (bottom sheet)
// ════════════════════════════════════════════════════════════════════════════
class _RapportProbleme extends StatefulWidget {
  const _RapportProbleme({
    required this.workspaceId,
    required this.devisId,
    required this.onDone,
  });

  final String workspaceId;
  final String devisId;
  final VoidCallback onDone;

  @override
  State<_RapportProbleme> createState() => _RapportProblemeState();
}

class _RapportProblemeState extends State<_RapportProbleme> {
  final _raisonCtrl = TextEditingController();
  bool _reglementEffectue = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _raisonCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _raisonCtrl.dispose();
    super.dispose();
  }

  Future<void> _signaler() async {
    if (_loading) return;
    final raison = _raisonCtrl.text.trim();
    if (raison.isEmpty) return;
    setState(() => _loading = true);

    try {
      await FirebaseFirestore.instance
          .collection('workspaces')
          .doc(widget.workspaceId)
          .collection('devis')
          .doc(widget.devisId)
          .set(
            {
              'status': 'À clôturer',
              'rapportProbleme': {
                'raison': raison,
                'signaledAt': FieldValue.serverTimestamp(),
              },
              'paiementEffectue': _reglementEffectue,
              'paiementSetAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('_signaler error: $e');
    }

    if (mounted) {
      setState(() => _loading = false);
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
            // Title
            Row(
              children: const [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orangeAccent, size: 22),
                SizedBox(width: 8),
                Text(
                  'Chantier pas terminé',
                  style: TextStyle(
                    color: AppColors.grey900,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _ProblemeField(
              controller: _raisonCtrl,
              label: 'Raison',
              hint:
                  'Pourquoi le chantier n\'est pas terminé ? (manque de matériel, problème sur place, dimensions non conformes...)',
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: AppColors.grey50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.grey100),
              ),
              child: SwitchListTile(
                value: _reglementEffectue,
                onChanged: (v) => setState(() => _reglementEffectue = v),
                activeColor: Colors.orangeAccent,
                title: const Text(
                  'Chantier payé par le client',
                  style: TextStyle(color: AppColors.grey900, fontSize: 14),
                ),
                subtitle: Text(
                  _reglementEffectue ? 'Payé' : 'Pas payé',
                  style: TextStyle(
                    color: _reglementEffectue
                        ? Colors.orangeAccent
                        : Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: (_loading || _raisonCtrl.text.trim().isEmpty)
                    ? null
                    : _signaler,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_outlined, size: 18),
                label: const Text(
                  'Confirmer — chantier pas terminé',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProblemeField extends StatelessWidget {
  const _ProblemeField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: AppColors.grey500, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: AppColors.grey900),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: AppColors.grey50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.grey100),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.grey100),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Colors.orangeAccent),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Shared small widgets
// ════════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.grey400, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.grey900,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ],
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({
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
                  style: const TextStyle(
                      color: AppColors.grey400, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                      color: AppColors.grey900,
                      fontWeight: FontWeight.w700),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
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
          radius: 14,
          backgroundColor: color.withOpacity(0.18),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 6),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style:
                  const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Data models
// ════════════════════════════════════════════════════════════════════════════

class _ChantierData {
  const _ChantierData({
    required this.id,
    this.metreurStatus,
    this.client,
    this.address,
    this.phone,
    this.category,
    this.poseDate,
    this.poseurNames,
    this.summary = const [],
    this.attachments = const [],
    this.draft,
  });

  final String id;
  final String? metreurStatus;
  final String? client;
  final String? address;
  final String? phone;
  final String? category;
  final DateTime? poseDate;
  final String? poseurNames;
  final List<_SummaryEntry> summary;
  final List<_AttachmentEntry> attachments;
  final _DraftData? draft;

  String get clientDisplay {
    final parts = <String>[];
    if (draft?.clientFirstName?.trim().isNotEmpty == true) {
      parts.add(draft!.clientFirstName!.trim());
    }
    if (draft?.clientName?.trim().isNotEmpty == true) {
      parts.add(draft!.clientName!.trim());
    }
    if (parts.isNotEmpty) return parts.join(' ');
    if (client?.trim().isNotEmpty == true) return client!.trim();
    return 'Client inconnu';
  }

  factory _ChantierData.fromMap(String id, Map<String, dynamic> map) {
    // Parse attachments — accepte List<Map> ou List<String>
    final rawAtt = map['attachments'];
    final attachments = <_AttachmentEntry>[];
    if (rawAtt is List) {
      for (final item in rawAtt) {
        if (item is Map<String, dynamic>) {
          attachments.add(_AttachmentEntry.fromMap(item));
        } else if (item is String && item.isNotEmpty) {
          attachments.add(_AttachmentEntry(label: 'Devis', url: item));
        }
      }
    }

    // Parse summary
    final rawSum = map['summary'];
    final summary = <_SummaryEntry>[];
    if (rawSum is List) {
      for (final item in rawSum) {
        if (item is Map<String, dynamic>) {
          summary.add(_SummaryEntry.fromMap(item));
        }
      }
    }

    // Parse poseDate
    DateTime? poseDate;
    final pd = map['poseDate'];
    if (pd is Timestamp) {
      poseDate = pd.toDate();
    } else if (pd is String) {
      poseDate = DateTime.tryParse(pd);
    }

    // Parse draft
    _DraftData? draft;
    if (map['draft'] is Map<String, dynamic>) {
      draft = _DraftData.fromMap(map['draft'] as Map<String, dynamic>);
    }

    return _ChantierData(
      id: id,
      metreurStatus: (map['status'] ?? map['metreurStatus'])?.toString(),
      client: map['client']?.toString(),
      address: map['address']?.toString(),
      phone: map['phone']?.toString(),
      category: map['category']?.toString(),
      poseDate: poseDate,
      poseurNames: map['poseurNames']?.toString(),
      summary: summary,
      attachments: attachments,
      draft: draft,
    );
  }
}

class _SummaryEntry {
  const _SummaryEntry({required this.label, required this.value});

  final String label;
  final String value;

  factory _SummaryEntry.fromMap(Map<String, dynamic> map) => _SummaryEntry(
        label: map['label']?.toString() ?? '',
        value: map['value']?.toString() ?? '',
      );
}

class _AttachmentEntry {
  const _AttachmentEntry({required this.label, this.url});

  final String label;
  final String? url;

  factory _AttachmentEntry.fromMap(Map<String, dynamic> map) =>
      _AttachmentEntry(
        label: map['label']?.toString() ??
            map['name']?.toString() ??
            'Document',
        url: map['url']?.toString() ??
            map['thumbnailUrl']?.toString() ??
            map['downloadUrl']?.toString(),
      );
}

class _DraftData {
  const _DraftData({
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
    this.products = const [],
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
  final List<_ProductData> products;

  factory _DraftData.fromMap(Map<String, dynamic> map) {
    final rawProducts = map['products'];
    final products = <_ProductData>[];
    if (rawProducts is List) {
      for (final item in rawProducts) {
        if (item is Map<String, dynamic>) {
          products.add(_ProductData.fromMap(item));
        } else if (item is Map) {
          products
              .add(_ProductData.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }
    return _DraftData(
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
      products: products,
    );
  }
}

class _ProductData {
  const _ProductData({
    this.categoryKey,
    this.sousCategorie,
    this.typeProduit,
    this.variante,
    this.couleur,
    this.couleurDetail,
    this.largeur,
    this.hauteur,
    this.largeurReelle,
    this.hauteurReelle,
    this.cjHaut,
    this.cjBas,
    this.cjGauche,
    this.cjDroite,
    this.quantite,
    this.unite,
    this.note,
    this.ref,
  });

  final String? categoryKey;
  final String? sousCategorie;
  final String? typeProduit;
  final String? variante;
  final String? couleur;
  final String? couleurDetail;
  final String? largeur;
  final String? hauteur;
  final String? largeurReelle;
  final String? hauteurReelle;
  final String? cjHaut;
  final String? cjBas;
  final String? cjGauche;
  final String? cjDroite;
  final String? quantite;
  final String? unite;
  final String? note;
  final String? ref;

  factory _ProductData.fromMap(Map<String, dynamic> map) => _ProductData(
        categoryKey: map['categoryKey']?.toString(),
        sousCategorie: map['sousCategorie']?.toString(),
        typeProduit: map['typeProduit']?.toString(),
        variante: map['variante']?.toString(),
        couleur: map['couleur']?.toString(),
        couleurDetail: map['couleurDetail']?.toString(),
        largeur: map['largeur']?.toString(),
        hauteur: map['hauteur']?.toString(),
        largeurReelle: map['largeurReelle']?.toString(),
        hauteurReelle: map['hauteurReelle']?.toString(),
        cjHaut: map['cjHaut']?.toString(),
        cjBas: map['cjBas']?.toString(),
        cjGauche: map['cjGauche']?.toString(),
        cjDroite: map['cjDroite']?.toString(),
        quantite: map['quantite']?.toString(),
        unite: map['unite']?.toString(),
        note: map['note']?.toString(),
        ref: map['ref']?.toString(),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// Helpers
// ════════════════════════════════════════════════════════════════════════════

String _formatDate(DateTime dt) {
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  return '$d/$m/${dt.year}';
}

String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$h:$min';
}

String _formatDateFull(DateTime dt) {
  const months = [
    '',
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return '${dt.day} ${months[dt.month]} ${dt.year}';
}

Future<void> _callNumber(BuildContext context, String number) async {
  final uri = Uri.parse('tel:$number');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Impossible d\'appeler $number'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
      ),
    );
  }
}
