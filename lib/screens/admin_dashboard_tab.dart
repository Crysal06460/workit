import '../core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chantier_chat_screen.dart';

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  String _firstName = '';

  @override
  void initState() {
    super.initState();
    _loadFirstName();
  }

  Future<void> _loadFirstName() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _firstName = prefs.getString('workit_user_first_name') ?? '';
    });
  }

  Color _statusColor(String s) {
    if (s == 'Nouvelle demande' || s == 'Acceptée' || s.isEmpty) return AppColors.primary;
    if (s == 'En cours') return AppColors.warning;
    if (s == 'À commander' || s == 'Commande en cours') return AppColors.purple;
    if (s == 'À planifier' || s == 'En pose') return AppColors.primary;
    if (s == 'À clôturer') return AppColors.amber;
    if (s == 'Terminé' || s == 'Clôturé') return AppColors.success;
    return AppColors.grey300;
  }

  void _openDetail(BuildContext context, String devisId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          final status = (data['status'] ?? data['metreurStatus'] ?? '').toString();
          final client = (data['client'] ?? '—').toString();
          final address = (data['address'] ?? '').toString();
          final metreurName = (data['assignedMetreurName'] ?? '').toString();
          final poseurNames = data['poseurNames'];
          final poseurList = poseurNames is List
              ? poseurNames.map((e) => e.toString()).join(', ')
              : poseurNames?.toString() ?? '';
          final poseDate = data['poseDate'];
          String poseDateStr = '';
          if (poseDate is Timestamp) {
            final d = poseDate.toDate();
            poseDateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
          }
          // 'metreurNote' est le champ actif (bouton "Demander des informations"
          // du métreur) ; 'infoRequest' est un ancien nom conservé en fallback.
          final metreurNote = data['metreurNote']?.toString() ?? '';
          final infoRequest = data['infoRequest'];
          final infoMsg = metreurNote.isNotEmpty
              ? metreurNote
              : (infoRequest is Map
                  ? (infoRequest['message'] ?? infoRequest['content'] ?? '').toString()
                  : '');
          final rapportProbleme = data['rapportProbleme'];
          final soucis = rapportProbleme is Map
              ? (rapportProbleme['soucis'] ?? '').toString()
              : '';
          final rapportFin = data['rapportFin'];
          String reglement = '';
          int nbPhotos = 0;
          if (rapportFin is Map) {
            final reg = rapportFin['reglement'];
            reglement = reg == true || reg == 'oui' ? 'Oui' : 'Non';
            final photos = rapportFin['photos'];
            if (photos is List) {
              nbPhotos = photos.length;
            } else if (photos is int) {
              nbPhotos = photos;
            }
          }
          // Éléments : "Catégorie : SousCategorie — qty pcs"
          int totalQte = 0;
          final List<Map<String, dynamic>> productRows = [];
          final summaryRaw = data['summary'];
          final Map<int, String> summaryLabels = {};
          if (summaryRaw is List) {
            for (final entry in summaryRaw) {
              if (entry is! Map) continue;
              final lbl = entry['label']?.toString() ?? '';
              final val = entry['value']?.toString() ?? '';
              final match = RegExp(r'^Élément (\d+)$').firstMatch(lbl);
              if (match != null) {
                final idx = int.tryParse(match.group(1) ?? '') ?? 0;
                // On ne garde que les 2 premiers segments (catégorie + sous-catégorie)
                final cutQte = val.indexOf(' • Qté:');
                final base = cutQte > 0 ? val.substring(0, cutQte) : val;
                final parts = base.split(' • ');
                summaryLabels[idx - 1] = parts.length >= 2
                    ? '${parts[0]} : ${parts[1]}'
                    : parts[0];
              }
            }
          }
          final draft = data['draft'];
          if (draft is Map) {
            final draftProducts = draft['products'];
            if (draftProducts is List) {
              for (var i = 0; i < draftProducts.length; i++) {
                final p = draftProducts[i];
                if (p is! Map) continue;
                final q = p['quantite'];
                final qty = q is int ? q : (q is num ? q.toInt() : 1);
                totalQte += qty;
                final label = summaryLabels[i] ?? 'Élément ${i + 1}';
                productRows.add({'label': label, 'qty': qty});
              }
            }
          }
          // URL du devis PDF uploadé par le commercial
          final devisUrl = data['uploadUrl']?.toString() ?? (() {
            final att = data['attachments'];
            if (att is List && att.isNotEmpty && att.first is Map) {
              return att.first['thumbnailUrl']?.toString() ?? '';
            }
            return '';
          })();

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  client,
                                  style: const TextStyle(
                                    color: AppColors.grey900,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (address.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    address,
                                    style: const TextStyle(color: AppColors.grey500, fontSize: 14),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ChatEntryButton(
                            devisId: devisId,
                            clientLabel: client,
                            color: AppColors.roleAdmin,
                          ),
                          const SizedBox(width: 4),
                          _StatusChip(status: status, color: _statusColor(status)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Éléments et quantité totale
                      if (productRows.isNotEmpty) ...[
                        _SectionCard(children: [
                          _InfoRow(
                            label: 'Total éléments',
                            value: '$totalQte pièce${totalQte > 1 ? 's' : ''}',
                          ),
                          for (final r in productRows) ...[
                            const Divider(color: AppColors.grey100, height: 1),
                            _InfoRow(
                              label: r['label']?.toString() ?? '',
                              value: '${r['qty']} pcs',
                            ),
                          ],
                        ]),
                      ],
                      const SizedBox(height: 12),
                      _SectionCard(children: [
                        _InfoRow(
                          label: 'Métreur',
                          value: metreurName.isNotEmpty ? metreurName : '—',
                        ),
                        if (poseurList.isNotEmpty || poseDateStr.isNotEmpty) ...[
                          const Divider(color: AppColors.grey100, height: 1),
                          _InfoRow(
                            label: 'Poseurs',
                            value: poseurList.isNotEmpty ? poseurList : '—',
                          ),
                          if (poseDateStr.isNotEmpty) ...[
                            const Divider(color: AppColors.grey100, height: 1),
                            _InfoRow(label: 'Date de pose', value: poseDateStr),
                          ],
                        ],
                      ]),
                      // Bouton devis PDF
                      if (devisUrl.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => launchUrl(Uri.parse(devisUrl), mode: LaunchMode.externalApplication),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Ouvrir le devis commercial',
                                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                Spacer(),
                                Icon(Icons.open_in_new, color: AppColors.primary, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (infoMsg.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            border: Border.all(color: AppColors.amber.withOpacity(0.4)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.info_outline, color: AppColors.amber, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Demande client',
                                    style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(infoMsg, style: const TextStyle(color: AppColors.grey600, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                      if (soucis.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.warning_amber_outlined, color: AppColors.danger, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Problème signalé',
                                    style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(soucis, style: const TextStyle(color: AppColors.grey600, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                      if (rapportFin is Map) ...[
                        const SizedBox(height: 12),
                        _SectionCard(children: [
                          _InfoRow(label: 'Rapport de fin', value: ''),
                          const Divider(color: AppColors.grey100, height: 1),
                          _InfoRow(label: 'Règlement reçu', value: reglement),
                          const Divider(color: AppColors.grey100, height: 1),
                          _InfoRow(label: 'Photos', value: '$nbPhotos photo(s)'),
                        ]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('workspaces')
          .doc(widget.workspaceId)
          .collection('devis')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Erreur de chargement', style: TextStyle(color: AppColors.grey400)),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final docs = snapshot.data!.docs;

        final enAttente = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final s = (data['status'] ?? data['metreurStatus'] ?? '').toString();
          return s == 'Nouvelle demande' || s == 'Acceptée' || s.isEmpty;
        }).length;

        final metreEnCours = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final s = (data['status'] ?? data['metreurStatus'] ?? '').toString();
          return s == 'En cours';
        }).length;

        final commandePose = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final s = (data['status'] ?? data['metreurStatus'] ?? '').toString();
          return s == 'À commander' || s == 'Commande en cours' || s == 'À planifier' || s == 'En pose';
        }).length;

        final termines = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final s = (data['status'] ?? data['metreurStatus'] ?? '').toString();
          return s == 'Terminé' || s == 'À clôturer' || s == 'Clôturé';
        }).length;

        final recent = docs.take(20).toList();

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_firstName.isNotEmpty)
                      Text(
                        'Bonjour, $_firstName',
                        style: const TextStyle(color: AppColors.grey400, fontSize: 14),
                      ),
                    const Text(
                      'Tableau de bord',
                      style: TextStyle(
                        color: AppColors.grey900,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.1,
                      children: [
                        _StatCard(
                          title: 'En attente',
                          count: enAttente,
                          icon: Icons.hourglass_empty_rounded,
                          color: AppColors.primary,
                        ),
                        _StatCard(
                          title: 'Métré en cours',
                          count: metreEnCours,
                          icon: Icons.architecture_outlined,
                          color: AppColors.warning,
                        ),
                        _StatCard(
                          title: 'Commande / Pose',
                          count: commandePose,
                          icon: Icons.home_repair_service_outlined,
                          color: AppColors.purple,
                        ),
                        _StatCard(
                          title: 'Terminés',
                          count: termines,
                          icon: Icons.check_circle_outline,
                          color: AppColors.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Derniers chantiers',
                      style: TextStyle(
                        color: AppColors.grey900,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (recent.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 52, color: AppColors.grey200),
                      const SizedBox(height: 12),
                      const Text(
                        'Aucun chantier pour l\'instant',
                        style: TextStyle(color: AppColors.grey300, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final data = recent[i].data() as Map<String, dynamic>;
                      final status = (data['status'] ?? data['metreurStatus'] ?? '').toString();
                      final client = (data['client'] ?? '—').toString();
                      final address = (data['address'] ?? '').toString();
                      final createdAt = data['createdAt'];
                      String dateStr = '';
                      if (createdAt is Timestamp) {
                        final d = createdAt.toDate();
                        dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}';
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => _openDetail(context, recent[i].id, data),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        client,
                                        style: const TextStyle(
                                          color: AppColors.grey900,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (address.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          address,
                                          style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _StatusChip(status: status, color: _statusColor(status)),
                                    if (dateStr.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        dateStr,
                                        style: const TextStyle(color: AppColors.grey300, fontSize: 11),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: recent.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 10),
          Text(
            '$count',
            style: const TextStyle(
              color: AppColors.grey900,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grey500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = status.isEmpty ? 'Nouvelle demande'
        : status == 'À planifier' ? 'Pose à programmer'
        : status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.grey400, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(color: AppColors.grey900, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

