part of 'commercial_home_screen.dart';

// ─── Détail chantier ────────────────────────────────────────────────────────

void _showChantierDetail(BuildContext context, _QuoteItem item, String workspaceId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: _commercialCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ChantierDetailSheet(item: item, workspaceId: workspaceId),
  );
}

class _ChantierDetailSheet extends StatelessWidget {
  const _ChantierDetailSheet({required this.item, required this.workspaceId});
  final _QuoteItem item;
  final String workspaceId;

  @override
  Widget build(BuildContext context) {
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
          _ChantierDetailBody(item: item, workspaceId: workspaceId),
        ],
      ),
    );
  }
}

/// Panneau détail desktop — même contenu que `_ChantierDetailSheet`, sans la
/// poignée de drag ni le scrim de bottom sheet, avec un bouton de fermeture
/// explicite (pas de "glisser pour fermer" possible dans un panneau fixe).
class _ChantierDetailPanel extends StatelessWidget {
  const _ChantierDetailPanel({required this.item, required this.workspaceId, required this.onClose});
  final _QuoteItem item;
  final String workspaceId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Fermer',
              icon: const Icon(Icons.close, color: AppColors.grey400),
              onPressed: onClose,
            ),
          ),
          _ChantierDetailBody(item: item, workspaceId: workspaceId),
        ],
      ),
    );
  }
}

class _ChantierDetailBody extends StatelessWidget {
  const _ChantierDetailBody({required this.item, required this.workspaceId});
  final _QuoteItem item;
  final String workspaceId;

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
    // Distincte des photos de chantier ci-dessous : uploadée séparément par
    // le poseur (`attestations_fin_travaux`), c'est le vrai justificatif
    // de fin de travaux, pas une simple photo de rendu.
    final attestationUrl = rapport?['attestationUrl'] as String?;

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
              ),
              if (item.id != null)
                ChatEntryButton(
                  devisId: item.id!,
                  clientLabel: item.client,
                  color: _commercialAccent,
                ),
            ],
          ),
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
              // "Programmé" plutôt que le statut serveur brut "En pose" :
              // atteint dès qu'une équipe/date sont posées dans l'agenda,
              // pas forcément au moment réel de la pose.
              status.isEmpty ? 'En attente' : (status == 'En pose' ? 'Programmé' : status),
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

          // Même champ `assignedMetreurName` tout du long, mais un libellé
          // différent selon l'étape : la question qui intéresse le
          // commercial change ("à qui c'est envoyé" → "qui l'a fait"), pas
          // besoin d'un nouveau champ. Rien avant qu'un métreur ait
          // effectivement accepté la demande (nom pas encore renseigné).
          if (item.assignedMetreurName?.isNotEmpty == true &&
              (status.isEmpty ||
                  status == 'Nouvelle demande' ||
                  status == 'Acceptée' ||
                  status == 'À classer'))
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Demande de métré envoyée à : ${item.assignedMetreurName}',
            )
          else if (item.assignedMetreurName?.isNotEmpty == true &&
              (status == 'À commander' || status == 'Commande en cours'))
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Métré réalisé par : ${item.assignedMetreurName}',
            ),

          // La date de RDV ne concerne que l'étape "Métré prog." (En
          // cours) — une fois le métré fait, c'est "Métré réalisé par"
          // ci-dessus qui prend le relais, pas la date du rendez-vous.
          if (status == 'En cours' && item.meetingAt != null) ...[
            const SizedBox(height: 12),
            const _SectionHeader(label: 'Métré programmé'),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: _formatDateTime(item.meetingAt!),
            ),
          ],

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

          ..._buildPoseSections(item),

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
            if (attestationUrl?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                'Déclaration de fin de travaux',
                style: const TextStyle(color: AppColors.grey500, fontSize: 13),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: Colors.black87,
                    child: InteractiveViewer(
                      child: Image.network(attestationUrl),
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    attestationUrl!,
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 140,
                      height: 140,
                      color: AppColors.grey100,
                      child: const Icon(Icons.broken_image, color: AppColors.grey400),
                    ),
                  ),
                ),
              ),
            ],
            if (photoUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Photos du chantier (${photoUrls.length})',
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

          // ── Phase 5 : circuit de validation — un bloc par lot en attente
          // (ou un bloc devis-level unique pour un chantier sans lot).
          if (item.id != null) ...[
            if (item.lotsSummary.isEmpty && status == 'À clôturer') ...[
              const SizedBox(height: 16),
              _ValidationBlock(
                workspaceId: workspaceId,
                devisId: item.id!,
                lotId: null,
                label: item.client,
              ),
            ],
            for (final lot in item.lotsSummary)
              if (lot['status'] == 'À clôturer') ...[
                const SizedBox(height: 16),
                _ValidationBlock(
                  workspaceId: workspaceId,
                  devisId: item.id!,
                  lotId: lot['lotId']?.toString(),
                  label: lot['label']?.toString().isNotEmpty == true
                      ? lot['label'].toString()
                      : (lot['lotId']?.toString() ?? ''),
                ),
              ],
          ],
        ],
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
      case 'SAV':
        return Colors.deepOrangeAccent;
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

  // Une section "Pose programmée" par lot planifié — un chantier étalé sur
  // plusieurs jours (voir scheduledDates, planner_screen.dart) doit montrer
  // TOUTES ses dates ici, pas seulement la première (poseDate).
  List<Widget> _buildPoseSections(_QuoteItem item) {
    if (item.lotsSummary.isEmpty) {
      final dates = item.scheduledDates.isNotEmpty
          ? item.scheduledDates
          : (item.poseDate != null ? [item.poseDate!] : const <DateTime>[]);
      if (dates.isEmpty) return const [];
      return [
        const SizedBox(height: 16),
        const _SectionHeader(label: 'Pose programmée'),
        const SizedBox(height: 8),
        ..._poseDateRows(dates, item.poseurNames),
      ];
    }

    final widgets = <Widget>[];
    final multiLot = item.lotsSummary.length > 1;
    for (final lot in item.lotsSummary) {
      final lotDates = (lot['scheduledDates'] as List<dynamic>? ?? [])
          .whereType<Timestamp>()
          .map((t) => t.toDate())
          .toList();
      final lotPoseDate = lot['poseDate'] is Timestamp ? (lot['poseDate'] as Timestamp).toDate() : null;
      final dates = lotDates.isNotEmpty ? lotDates : (lotPoseDate != null ? [lotPoseDate] : const <DateTime>[]);
      if (dates.isEmpty) continue;
      final label = lot['label']?.toString().isNotEmpty == true
          ? lot['label'].toString()
          : (lot['lotId']?.toString() ?? '');
      widgets.addAll([
        const SizedBox(height: 16),
        _SectionHeader(label: multiLot ? 'Pose programmée — $label' : 'Pose programmée'),
        const SizedBox(height: 8),
        ..._poseDateRows(dates, lot['poseurNames']?.toString()),
      ]);
    }
    return widgets;
  }

  List<Widget> _poseDateRows(List<DateTime> dates, String? poseurNames) {
    final sorted = [...dates]..sort();
    return [
      for (var i = 0; i < sorted.length; i++)
        _DetailRow(
          icon: Icons.calendar_today_outlined,
          label: sorted.length > 1
              ? 'Jour ${i + 1}/${sorted.length} — ${_formatDateTime(sorted[i])}'
              : _formatDateTime(sorted[i]),
        ),
      if (poseurNames?.isNotEmpty == true)
        _DetailRow(icon: Icons.group_outlined, label: 'Équipe : $poseurNames'),
    ];
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _ValidationBlock (Phase 5) — circuit de validation : le responsable
// (commercial/admin) examine le rapport soumis par le poseur (fin propre ou
// problème signalé, lu directement sur le lot ou le devis, pas dénormalisé
// dans lotsSummary) et choisit une issue : Valider (clôture), Retourner au
// poseur (avec commentaire), ou Créer un SAV (avec motif).
// ════════════════════════════════════════════════════════════════════════════
class _ValidationBlock extends StatefulWidget {
  const _ValidationBlock({
    required this.workspaceId,
    required this.devisId,
    required this.lotId,
    required this.label,
  });

  final String workspaceId;
  final String devisId;
  final String? lotId;
  final String label;

  @override
  State<_ValidationBlock> createState() => _ValidationBlockState();
}

class _ValidationBlockState extends State<_ValidationBlock> {
  bool _loading = false;

  DocumentReference<Map<String, dynamic>> get _targetRef {
    final devisRef = FirebaseFirestore.instance
        .collection('workspaces')
        .doc(widget.workspaceId)
        .collection('devis')
        .doc(widget.devisId);
    return widget.lotId != null
        ? devisRef.collection('lots').doc(widget.lotId!)
        : devisRef;
  }

  Future<void> _act(String newStatus, Map<String, dynamic> extraFields) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await DevisService.updateStatus(
        workspaceId: widget.workspaceId,
        devisId: widget.devisId,
        lotId: widget.lotId,
        newStatus: newStatus,
        extraFields: extraFields,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _promptAndAct({
    required BuildContext context,
    required String title,
    required String hint,
    required String newStatus,
    required String extraFieldKey,
  }) async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _commercialCard,
        title: Text(title, style: const TextStyle(color: AppColors.grey900)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          style: const TextStyle(color: AppColors.grey900),
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    await _act(newStatus, {extraFieldKey: value});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _targetRef.get(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final rapportType = data?['rapportType']?.toString();
        final rapportProbleme = data?['rapportProbleme'] is Map
            ? Map<String, dynamic>.from(data!['rapportProbleme'] as Map)
            : null;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.pending_actions, color: Colors.orangeAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.label} — à valider',
                      style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (snap.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (rapportType == 'probleme' && rapportProbleme != null) ...[
                Text(
                  'Cause : ${rapportProbleme['cause'] ?? '—'}',
                  style: const TextStyle(
                      color: AppColors.grey900,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                if ((rapportProbleme['commentaire'] as String?)?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      rapportProbleme['commentaire'] as String,
                      style: const TextStyle(color: AppColors.grey700, fontSize: 13),
                    ),
                  ),
              ] else
                const Text(
                  'Rapport de fin propre, aucun problème signalé.',
                  style: TextStyle(color: AppColors.grey700, fontSize: 13),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loading ? null : () => _act('Terminé', const {}),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _commercialAccent, foregroundColor: Colors.black),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Valider'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () => _promptAndAct(
                              context: context,
                              title: 'Retourner au poseur',
                              hint: 'Pourquoi renvoyer ce chantier ?',
                              newStatus: 'En pose',
                              extraFieldKey: 'retourCommentaire',
                            ),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orangeAccent,
                        side: const BorderSide(color: Colors.orangeAccent)),
                    icon: const Icon(Icons.reply, size: 16),
                    label: const Text('Retourner'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () => _promptAndAct(
                              context: context,
                              title: 'Créer un SAV',
                              hint: 'Motif du SAV',
                              newStatus: 'SAV',
                              extraFieldKey: 'savReason',
                            ),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepOrangeAccent,
                        side: const BorderSide(color: Colors.deepOrangeAccent)),
                    icon: const Icon(Icons.build_circle_outlined, size: 16),
                    label: const Text('Créer un SAV'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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
