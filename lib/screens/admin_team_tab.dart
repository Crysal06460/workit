import '../core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/onboarding_models.dart';  // roleDisplayName, roleDisplayNamePlural, onboardingRoles

class AdminTeamTab extends StatefulWidget {
  const AdminTeamTab({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  State<AdminTeamTab> createState() => _AdminTeamTabState();
}

class _AdminTeamTabState extends State<AdminTeamTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Color _roleColor(String role) {
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

  void _addMember() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _AddMemberSheet(workspaceId: widget.workspaceId),
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

  void _showTempPassword(BuildContext context, String email, String tempPassword) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Mot de passe provisoire',
          style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email, style: const TextStyle(color: AppColors.grey400, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
              ),
              child: SelectableText(
                tempPassword,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ce mot de passe est provisoire. Le membre devra le changer à la première connexion.',
              style: TextStyle(color: AppColors.grey300, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'Email: $email\nMot de passe: $tempPassword'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Identifiants copiés !')),
              );
            },
            child: const Text('Copier', style: TextStyle(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer', style: TextStyle(color: AppColors.grey400)),
          ),
        ],
      ),
    );
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
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
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
                return data['status'] != 'disabled' && data['role'] != 'admin';
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
                  final tempPassword = data['tempPassword']?.toString();
                  final isProvisioned = data['status'] == 'provisioned';

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
                            ],
                          ),
                        ),
                        if (isProvisioned && tempPassword != null)
                          IconButton(
                            icon: const Icon(Icons.key_outlined, color: AppColors.primary),
                            tooltip: 'Voir le mot de passe provisoire',
                            onPressed: () => _showTempPassword(context, email, tempPassword),
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
  const _AddMemberSheet({required this.workspaceId});

  final String workspaceId;

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedRole = 'commercial';
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
      final tempPassword = (acc['tempPassword'] ?? '').toString();
      final email = _emailController.text.trim();

      Navigator.pop(context);

      if (!mounted) return;
      _showSuccessSheet(email, tempPassword);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessSheet(String email, String tempPassword) {
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
                        'Mot de passe temporaire',
                        style: TextStyle(color: AppColors.grey400, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        tempPassword,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          letterSpacing: 2,
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
                    label: const Text('Copier', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: 'Email: $email\nMot de passe: $tempPassword',
                      ));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Identifiants copiés dans le presse-papier !')),
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
                    'Partagez ces identifiants par WhatsApp ou SMS. Le membre devra changer son mot de passe à la première connexion.',
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
                ),
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
                    onPressed: _isLoading ? null : _provision,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
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
  const _RoleSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final roles = [
      (key: 'commercial', label: 'Commercial', icon: Icons.handshake_outlined),
      (key: 'metreur', label: 'Métreur', icon: Icons.architecture_outlined),
      (key: 'poseur', label: 'Poseur / Pose', icon: Icons.home_repair_service_outlined),
    ];

    return Row(
      children: roles.map((r) {
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
