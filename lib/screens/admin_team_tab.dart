import '../core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/onboarding_models.dart';

/// Écrit une entrée dans le journal d'audit immuable du workspace.
/// Best-effort : n'interrompt jamais l'action principale si l'écriture échoue.
Future<void> writeAuditLog(
  String workspaceId, {
  required String action,
  required String targetUid,
  String? targetEmail,
  required String performedByRole,
  Map<String, dynamic>? details,
}) async {
  final me = FirebaseAuth.instance.currentUser;
  if (me == null) return;
  try {
    await FirebaseFirestore.instance
        .collection('workspaces')
        .doc(workspaceId)
        .collection('auditLogs')
        .add({
      'action': action,
      'targetUid': targetUid,
      if (targetEmail != null) 'targetEmail': targetEmail,
      'performedBy': me.uid,
      'performedByRole': performedByRole,
      'details': details ?? {},
      'timestamp': FieldValue.serverTimestamp(),
    });
  } catch (_) {
    // Ignoré volontairement : un échec de log ne doit jamais bloquer l'action.
  }
}

class AdminTeamTab extends StatefulWidget {
  const AdminTeamTab({
    super.key,
    required this.workspaceId,
    this.restrictToRoles,
  });

  final String workspaceId;

  /// Si non-null, restreint l'écran à un sous-ensemble de rôles : c'est le
  /// cas d'un membre délégué (canManageTeam=true) qui ne gère qu'une partie
  /// de l'équipe. Null = vrai admin, accès complet + peut accorder des droits.
  final List<String>? restrictToRoles;

  @override
  State<AdminTeamTab> createState() => _AdminTeamTabState();
}

class _AdminTeamTabState extends State<AdminTeamTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool get _isFullAdmin => widget.restrictToRoles == null;

  Color _roleColor(String role) => _teamRoleColor(role);

  void _addMember() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _AddMemberSheet(
        workspaceId: widget.workspaceId,
        allowedRoles: widget.restrictToRoles,
        canGrantPermissions: _isFullAdmin,
      ),
    );
  }

  void _editPermissions(
    String uid,
    String displayName,
    String role,
    bool enabled,
    Set<String> roles,
    bool canPlaceOrders,
    bool orderRestricted,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditPermissionsSheet(
        workspaceId: widget.workspaceId,
        uid: uid,
        displayName: displayName,
        memberRole: role,
        initialEnabled: enabled,
        initialRoles: roles,
        initialCanPlaceOrders: canPlaceOrders,
        initialOrderRestricted: orderRestricted,
      ),
    );
  }

  Future<void> _removeUser(String uid, String displayName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Retirer ce membre ?',
          style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Voulez-vous retirer l\'accès de $displayName ?\nIl ne pourra plus se connecter.',
          style: const TextStyle(color: AppColors.grey600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: AppColors.grey400)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('users').doc(uid).set(
        {'status': 'disabled'},
        SetOptions(merge: true),
      );
      await writeAuditLog(
        widget.workspaceId,
        action: 'member_disabled',
        targetUid: uid,
        performedByRole: _isFullAdmin ? 'admin' : 'delegate',
        details: {'displayName': displayName},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membre retiré de l\'équipe.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mon équipe',
                style: TextStyle(
                  color: AppColors.grey900,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: _addMember,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .where('workspaceId', isEqualTo: widget.workspaceId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              if (snapshot.hasError) {
                final err = snapshot.error.toString();
                debugPrint('[AdminTeamTab] StreamBuilder error: $err');
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'Erreur de chargement',
                        style: TextStyle(color: AppColors.grey600, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          err,
                          style: const TextStyle(color: AppColors.grey300, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              final docs = snapshot.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                if (data['status'] == 'disabled' || data['role'] == 'admin') {
                  return false;
                }
                if (widget.restrictToRoles != null &&
                    !widget.restrictToRoles!.contains(data['role'])) {
                  return false;
                }
                return true;
              }).toList();

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.group_add_outlined, size: 52, color: AppColors.grey200),
                      const SizedBox(height: 12),
                      const Text(
                        'Aucun membre dans l\'équipe',
                        style: TextStyle(color: AppColors.grey300, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Appuyez sur "Ajouter" pour inviter quelqu\'un.',
                        style: TextStyle(color: AppColors.grey200, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final uid = docs[i].id;
                  final role = (data['role'] ?? '').toString();
                  final email = (data['email'] ?? '').toString();
                  final firstName = (data['firstName'] ?? '').toString();
                  final lastName = (data['lastName'] ?? '').toString();
                  final name = '$firstName $lastName'.trim();
                  final displayName = name.isNotEmpty ? name : email;
                  final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
                  final roleColor = _roleColor(role);
                  final canManageTeam = data['canManageTeam'] == true;
                  final manageableRoles = Set<String>.from(
                    (data['manageableRoles'] as List<dynamic>? ?? [])
                        .map((e) => e.toString()),
                  );
                  final canPlaceOrders = data['canPlaceOrders'] == true;
                  final orderRestricted =
                      role == 'metreur' && data['canPlaceOrders'] == false;

                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: roleColor.withOpacity(0.18),
                          radius: 22,
                          child: Text(
                            initial,
                            style: TextStyle(
                              color: roleColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  color: AppColors.grey900,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: roleColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: roleColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  roleDisplayName(role),
                                  style: TextStyle(
                                    color: roleColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (canManageTeam) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.shield_outlined,
                                        size: 12, color: AppColors.grey400),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        manageableRoles.isEmpty
                                            ? 'Peut ajouter des membres'
                                            : 'Peut ajouter : ${manageableRoles.map(roleDisplayNamePlural).join(', ')}',
                                        style: const TextStyle(
                                            color: AppColors.grey400,
                                            fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (canPlaceOrders) ...[
                                const SizedBox(height: 6),
                                const Row(
                                  children: [
                                    Icon(Icons.local_shipping_outlined,
                                        size: 12, color: AppColors.grey400),
                                    SizedBox(width: 4),
                                    Text(
                                      'Peut passer commande',
                                      style: TextStyle(
                                          color: AppColors.grey400,
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                              if (orderRestricted) ...[
                                const SizedBox(height: 6),
                                const Row(
                                  children: [
                                    Icon(Icons.block,
                                        size: 12, color: AppColors.danger),
                                    SizedBox(width: 4),
                                    Text(
                                      'Commande restreinte',
                                      style: TextStyle(
                                          color: AppColors.danger,
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_isFullAdmin)
                          IconButton(
                            icon: Icon(
                              canManageTeam || canPlaceOrders || orderRestricted
                                  ? Icons.shield
                                  : Icons.shield_outlined,
                              color: canManageTeam || canPlaceOrders || orderRestricted
                                  ? AppColors.primary
                                  : AppColors.grey300,
                            ),
                            tooltip: 'Droits du membre',
                            onPressed: () => _editPermissions(uid, displayName, role,
                                canManageTeam, manageableRoles, canPlaceOrders,
                                orderRestricted),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                          tooltip: 'Retirer de l\'équipe',
                          onPressed: () => _removeUser(uid, displayName),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet({
    required this.workspaceId,
    this.allowedRoles,
    this.canGrantPermissions = false,
  });

  final String workspaceId;

  /// Rôles proposables. Null = tous (vrai admin) ; sinon restreint aux
  /// rôles délégués au membre qui ajoute (ex : un métreur "chef
  /// d'orchestre" ne peut ajouter que commerciaux + poseurs).
  final List<String>? allowedRoles;

  /// Seul un vrai admin peut, en créant le compte, lui accorder à son tour
  /// le droit d'ajouter des membres.
  final bool canGrantPermissions;

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  late String _selectedRole =
      widget.allowedRoles?.isNotEmpty == true ? widget.allowedRoles!.first : 'commercial';
  bool _canManageTeam = false;
  Set<String> _manageableRoles = {};
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _provision() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable = functions.httpsCallable('provisionAccounts');

      final result = await callable.call({
        'accounts': [
          {
            'email': _emailController.text.trim(),
            'firstName': _firstNameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'role': _selectedRole,
            'companyId': widget.workspaceId,
            if (widget.canGrantPermissions) 'canManageTeam': _canManageTeam,
            if (widget.canGrantPermissions)
              'manageableRoles': _manageableRoles.toList(),
          }
        ],
      });

      final data = result.data as Map;
      final accounts = (data['accounts'] as List<dynamic>? ?? []);

      if (!mounted) return;

      if (accounts.isEmpty) {
        Navigator.pop(context);
        return;
      }

      final acc = Map<String, dynamic>.from(accounts.first as Map);
      final activationLink = (acc['activationLink'] ?? '').toString();
      final email = _emailController.text.trim();

      Navigator.pop(context);

      if (!mounted) return;
      _showSuccessSheet(email, activationLink);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessSheet(String email, String activationLink) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.grey200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 52),
                ),
                const SizedBox(height: 16),
                Text(
                  'Compte créé pour\n$email',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.grey900,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lien d\'activation',
                        style: TextStyle(color: AppColors.grey400, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        activationLink,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Copier le lien', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: activationLink));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Lien copié dans le presse-papier !')),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.amber.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Partagez ce lien par WhatsApp ou SMS. Il permettra au membre de définir son mot de passe, puis de se connecter normalement depuis l\'app.',
                    style: TextStyle(color: AppColors.amber, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'OK, j\'ai copié',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(24, 16, 24, 32 + bottomInset),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.grey200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Nouveau membre',
                  style: TextStyle(
                    color: AppColors.grey900,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                _DarkField(
                  controller: _firstNameController,
                  label: 'Prénom',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                _DarkField(
                  controller: _lastNameController,
                  label: 'Nom',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                _DarkField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'L\'email est requis';
                    if (!val.contains('@')) return 'Email invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Rôle',
                  style: TextStyle(color: AppColors.grey600, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _RoleSelector(
                  selected: _selectedRole,
                  onChanged: (role) => setState(() => _selectedRole = role),
                  roles: widget.allowedRoles ?? onboardingRoles,
                ),
                if (widget.canGrantPermissions) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Droits de gestion d\'équipe',
                    style: TextStyle(color: AppColors.grey600, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  _PermissionsFields(
                    enabled: _canManageTeam,
                    selectedRoles: _manageableRoles,
                    onEnabledChanged: (v) => setState(() => _canManageTeam = v),
                    onRolesChanged: (r) => setState(() => _manageableRoles = r),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: (_isLoading || (_canManageTeam && _manageableRoles.isEmpty))
                        ? null
                        : _provision,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Créer le compte',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DarkField extends StatelessWidget {
  const _DarkField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: AppColors.grey900),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.grey400),
        filled: true,
        fillColor: AppColors.grey100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.grey200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.grey200),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.selected,
    required this.onChanged,
    this.roles = onboardingRoles,
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    final allRoles = [
      (key: 'commercial', label: 'Commercial', icon: Icons.handshake_outlined),
      (key: 'metreur', label: 'Métreur', icon: Icons.architecture_outlined),
      (key: 'poseur', label: 'Poseur / Pose', icon: Icons.home_repair_service_outlined),
    ];
    final visibleRoles = allRoles.where((r) => roles.contains(r.key)).toList();

    return Row(
      children: visibleRoles.map((r) {
        final isSelected = selected == r.key;
        Color color;
        switch (r.key) {
          case 'commercial':
            color = AppColors.primary;
            break;
          case 'metreur':
            color = AppColors.warning;
            break;
          default:
            color = AppColors.purple;
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onChanged(r.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.18) : AppColors.grey50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color.withOpacity(0.7) : AppColors.grey100,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(r.icon, color: isSelected ? color : AppColors.grey300, size: 22),
                    const SizedBox(height: 6),
                    Text(
                      r.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? color : AppColors.grey400,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Droits de gestion d'équipe — délégation type "chef d'orchestre"
// ════════════════════════════════════════════════════════════════════════════

Color _teamRoleColor(String role) {
  switch (role) {
    case 'commercial':
      return AppColors.primary;
    case 'metreur':
      return AppColors.warning;
    case 'poseur':
      return AppColors.purple;
    default:
      return AppColors.grey300;
  }
}

class _PermissionsFields extends StatelessWidget {
  const _PermissionsFields({
    required this.enabled,
    required this.selectedRoles,
    required this.onEnabledChanged,
    required this.onRolesChanged,
  });

  final bool enabled;
  final Set<String> selectedRoles;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<Set<String>> onRolesChanged;

  @override
  Widget build(BuildContext context) {
    final allSelected = onboardingRoles.every(selectedRoles.contains);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.grey50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.grey100),
          ),
          child: SwitchListTile(
            value: enabled,
            onChanged: onEnabledChanged,
            activeColor: AppColors.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            title: const Text(
              'Peut ajouter des membres à l\'équipe',
              style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: const Text(
              'Ex : le métreur référent recrute lui-même poseurs et commerciaux, sans passer par vous.',
              style: TextStyle(color: AppColors.grey400, fontSize: 12),
            ),
          ),
        ),
        if (enabled) ...[
          const SizedBox(height: 14),
          const Text(
            'Rôles qu\'il peut ajouter',
            style: TextStyle(color: AppColors.grey600, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RoleChip(
                label: 'Tous les rôles',
                selected: allSelected,
                color: AppColors.grey500,
                onTap: () => onRolesChanged(
                  allSelected ? {} : onboardingRoles.toSet(),
                ),
              ),
              for (final r in onboardingRoles)
                _RoleChip(
                  label: roleDisplayNamePlural(r),
                  selected: selectedRoles.contains(r),
                  color: _teamRoleColor(r),
                  onTap: () {
                    final next = Set<String>.from(selectedRoles);
                    if (next.contains(r)) {
                      next.remove(r);
                    } else {
                      next.add(r);
                    }
                    onRolesChanged(next);
                  },
                ),
            ],
          ),
          if (selectedRoles.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Sélectionnez au moins un rôle.',
                style: TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ),
        ],
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.18) : AppColors.grey50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color.withOpacity(0.7) : AppColors.grey100,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? color : AppColors.grey400,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditPermissionsSheet extends StatefulWidget {
  const _EditPermissionsSheet({
    required this.workspaceId,
    required this.uid,
    required this.displayName,
    required this.memberRole,
    required this.initialEnabled,
    required this.initialRoles,
    required this.initialCanPlaceOrders,
    required this.initialOrderRestricted,
  });

  final String workspaceId;
  final String uid;
  final String displayName;
  final String memberRole;
  final bool initialEnabled;
  final Set<String> initialRoles;
  final bool initialCanPlaceOrders;
  final bool initialOrderRestricted;

  @override
  State<_EditPermissionsSheet> createState() => _EditPermissionsSheetState();
}

class _EditPermissionsSheetState extends State<_EditPermissionsSheet> {
  late bool _enabled = widget.initialEnabled;
  late Set<String> _roles = Set<String>.from(widget.initialRoles);
  late bool _canPlaceOrders = widget.initialCanPlaceOrders;
  late bool _orderRestricted = widget.initialOrderRestricted;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // canPlaceOrders est un override tri-état côté serveur (voir
      // devisWorkflow.js) : pour un commercial il ACCORDE le droit, pour un
      // métreur il le RETIRE. On ne l'écrit que pour le rôle concerné, pour
      // ne jamais écraser silencieusement l'autre sémantique en éditant
      // d'autres droits (canManageTeam) sur un membre d'un rôle tiers.
      final payload = <String, dynamic>{
        'canManageTeam': _enabled,
        'manageableRoles': _enabled ? _roles.toList() : [],
      };
      if (widget.memberRole == 'commercial') {
        payload['canPlaceOrders'] = _canPlaceOrders;
      }
      if (widget.memberRole == 'metreur') {
        payload['canPlaceOrders'] = !_orderRestricted;
      }
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update(payload);
      await writeAuditLog(
        widget.workspaceId,
        action: 'rights_changed',
        targetUid: widget.uid,
        performedByRole: 'admin', // cette feuille n'est ouvrable que par un admin
        details: payload,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Droits mis à jour.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.grey200,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Text(
            'Droits de ${widget.displayName}',
            style: const TextStyle(
              color: AppColors.grey900,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 16),
          _PermissionsFields(
            enabled: _enabled,
            selectedRoles: _roles,
            onEnabledChanged: (v) => setState(() => _enabled = v),
            onRolesChanged: (r) => setState(() => _roles = r),
          ),
          if (widget.memberRole == 'commercial') ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _canPlaceOrders,
              onChanged: (v) => setState(() => _canPlaceOrders = v),
              activeThumbColor: AppColors.primary,
              title: const Text(
                'Autoriser à passer commande',
                style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: const Text(
                'Ce commercial pourra confirmer la commande sur ses propres chantiers (normalement réservé au métreur).',
                style: TextStyle(color: AppColors.grey500, fontSize: 12),
              ),
            ),
          ],
          if (widget.memberRole == 'metreur') ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _orderRestricted,
              onChanged: (v) => setState(() => _orderRestricted = v),
              activeThumbColor: AppColors.danger,
              title: const Text(
                'Restreindre le droit de passer commande',
                style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: const Text(
                'Ce métreur ne pourra plus confirmer de commande — réservé au commercial/admin sur ses chantiers.',
                style: TextStyle(color: AppColors.grey500, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: (_saving || (_enabled && _roles.isEmpty)) ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
