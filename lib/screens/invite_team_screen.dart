import 'package:flutter/material.dart';

import '../models/onboarding_models.dart';
import 'admin_summary_screen.dart';

class InviteTeamScreen extends StatefulWidget {
  const InviteTeamScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<InviteTeamScreen> createState() => _InviteTeamScreenState();
}

class _InviteTeamScreenState extends State<InviteTeamScreen> {
  late final Map<String, TextEditingController> controllers;
  final formKey = GlobalKey<FormState>();
  bool creatorUsesWorkit = false;
  String? creatorRoleKey;
  final TextEditingController creatorFirstNameController = TextEditingController();
  final TextEditingController creatorLastNameController = TextEditingController();

  @override
  void dispose() {
    creatorFirstNameController.dispose();
    creatorLastNameController.dispose();
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    controllers = {
      for (final role in onboardingRoles) role: TextEditingController(),
    };
    creatorUsesWorkit = widget.data.creatorUsesWorkit;
    creatorRoleKey = widget.data.creatorRoleKey;
    creatorFirstNameController.text = widget.data.creatorFirstName ?? '';
    creatorLastNameController.text = widget.data.creatorLastName ?? '';
    for (final role in onboardingRoles) {
      final existing = widget.data.invites[role];
      if (existing != null && existing.isNotEmpty) {
        controllers[role]!.text = existing.join('\n');
      }
    }
  }

  void _continue() {
    if (!formKey.currentState!.validate()) return;
    widget.data
      ..creatorUsesWorkit = creatorUsesWorkit
      ..creatorRoleKey = creatorUsesWorkit ? creatorRoleKey : null
      ..creatorFirstName = creatorFirstNameController.text.trim()
      ..creatorLastName = creatorLastNameController.text.trim();

    for (final role in onboardingRoles) {
      widget.data.invites[role] = _splitEmails(controllers[role]!.text);
    }

    if (widget.data.creatorUsesWorkit && widget.data.creatorRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez votre rôle pour utiliser WorkIt.')),
      );
      return;
    }

    final validationError = _validateSeatLimits();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminSummaryScreen(data: widget.data)),
    );
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

  List<String> _splitEmails(String raw) {
    return raw
        .split(RegExp('[,\n]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  String? _validateSeatLimits() {
    final plan = widget.data.plan;
    if (plan == null) return 'Veuillez d’abord sélectionner un abonnement.';
    final overflows = <String>[];
    for (final role in onboardingRoles) {
      final limit = plan.seatForRole(role);
      if (limit == null) continue;
      final count = widget.data.roleUsageCount(role);
      if (count > limit) {
        overflows.add('${roleDisplayNamePlural(role)}: $count / $limit');
      }
    }
    if (overflows.isEmpty) return null;
    return 'Capacité dépassée pour : ${overflows.join(', ')}';
  }

  String? _validateEmailList(String? raw, String roleKey) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final emails = _splitEmails(value);
    final invalid = emails.firstWhere(
      (email) => !email.contains('@') || !email.contains('.'),
      orElse: () => '',
    );
    if (invalid.isEmpty) return null;
    final roleLabel = roleDisplayNamePlural(roleKey);
    return 'Email invalide pour $roleLabel';
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.data.plan;
    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Inviter mon équipe',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroCard(planName: plan?.name ?? 'Configuration sélectionnée'),
                const SizedBox(height: 16),
                _SelfUsageCard(
                  usesWorkit: creatorUsesWorkit,
                  onToggle: (value) {
                    setState(() {
                      creatorUsesWorkit = value;
                      if (!value) {
                        creatorRoleKey = null;
                        widget.data
                          ..creatorUsesWorkit = false
                          ..creatorRoleKey = null
                          ..creatorFirstName = creatorFirstNameController.text.trim()
                          ..creatorLastName = creatorLastNameController.text.trim();
                      } else {
                        widget.data.creatorUsesWorkit = true;
                      }
                    });
                  },
                  selectedRole: creatorRoleKey,
                  onRoleSelected: (role) {
                    setState(() {
                      creatorUsesWorkit = true;
                      creatorRoleKey = role;
                      widget.data
                        ..creatorUsesWorkit = true
                        ..creatorRoleKey = role;
                    });
                  },
                  showHybridRole: widget.data.plan?.id == 'abonnement_2',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: creatorFirstNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Prénom',
                          labelStyle: const TextStyle(color: Colors.white),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Prénom requis';
                          return null;
                        },
                        onChanged: (_) => _capitalizeFirstLetter(creatorFirstNameController),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: creatorLastNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Nom',
                          labelStyle: const TextStyle(color: Colors.white),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Nom requis';
                          return null;
                        },
                        onChanged: (_) => _capitalizeFirstLetter(creatorLastNameController),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final role in onboardingRoles) ...[
                  InviteRoleSection(
                    roleKey: role,
                    controller: controllers[role]!,
                    plan: plan,
                    currentUsageLabel: widget.data.seatUsageLabel(role),
                    validator: (value) => _validateEmailList(value, role),
                  ),
                  const SizedBox(height: 18),
                ],
                const SizedBox(height: 18),
                _HowItWorksCard(),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        inherit: true,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _continue,
                    child: const Text('Envoyer les invitations'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InviteRoleSection extends StatelessWidget {
  const InviteRoleSection({
    super.key,
    required this.roleKey,
    required this.controller,
    required this.plan,
    required this.currentUsageLabel,
    required this.validator,
  });

  final String roleKey;
  final TextEditingController controller;
  final PlanOption? plan;
  final String currentUsageLabel;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final roleLabel = roleDisplayNamePlural(roleKey);
    final placeholder = defaultInvitePlaceholder(roleKey);
    final seatLabel = plan?.seatLabelForRole(roleKey) ?? 'Illimité';
    final capacityText = plan == null
        ? 'Sélectionnez un plan pour voir la capacité incluant les ${roleLabel.toLowerCase()}.'
        : 'Capacité du plan : $seatLabel ${roleLabel.toLowerCase()}';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1422),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(Icons.group_add, color: Color(0xFF00E676)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roleLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      capacityText,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Actuellement : $currentUsageLabel',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            validator: validator,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Emails ${roleLabel.toLowerCase()}',
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: placeholder,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF11182A),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF00E676),
                  width: 1.5,
                ),
              ),
              alignLabelWithHint: true,
            ),
            keyboardType: TextInputType.multiline,
            maxLines: 4,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SelfUsageCard extends StatelessWidget {
  const _SelfUsageCard({
    required this.usesWorkit,
    required this.onToggle,
    required this.selectedRole,
    required this.onRoleSelected,
    required this.showHybridRole,
  });

  final bool usesWorkit;
  final ValueChanged<bool> onToggle;
  final String? selectedRole;
  final ValueChanged<String> onRoleSelected;
  final bool showHybridRole;

  @override
  Widget build(BuildContext context) {
    final options = <_SelfRoleOption>[
      const _SelfRoleOption(
        key: 'commercial',
        title: 'Commercial',
        subtitle: 'Prospection, devis et suivi client.',
      ),
      const _SelfRoleOption(
        key: 'metreur',
        title: 'Métreur',
        subtitle: 'Relevés terrain, plans et métrés.',
      ),
      if (showHybridRole)
        const _SelfRoleOption(
          key: 'commercial_metreur',
          title: 'Commercial / Métreur',
          subtitle: 'Vous faites les deux (configuration 2).',
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1422),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(Icons.person_pin_circle, color: Color(0xFF00E676)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Votre accès WorkIt',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Souhaitez-vous aussi utiliser WorkIt ? Sélectionnez votre rôle si oui.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: usesWorkit,
                onChanged: onToggle,
                activeColor: const Color(0xFF00E676),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!usesWorkit)
            const Text(
              'Vous aurez un tableau de bord global pour suivre les devis et métrés.',
              style: TextStyle(color: Colors.white70),
            ),
          if (usesWorkit) ...[
            const Text(
              'Choisissez le rôle qui vous correspond :',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Column(
              children: options
                  .map(
                    (option) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SelfRoleTile(
                        option: option,
                        isSelected: selectedRole == option.key,
                        onTap: () => onRoleSelected(option.key),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelfRoleOption {
  const _SelfRoleOption({
    required this.key,
    required this.title,
    required this.subtitle,
  });

  final String key;
  final String title;
  final String subtitle;
}

class _SelfRoleTile extends StatelessWidget {
  const _SelfRoleTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _SelfRoleOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? const Color(0xFF00E676) : Colors.white.withOpacity(0.18);
    final background = isSelected ? const Color(0xFF00E676).withOpacity(0.08) : const Color(0xFF11182A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFF00E676) : Colors.white70,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
                    style: const TextStyle(color: Colors.white70),
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.planName});

  final String planName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E1726), Color(0xFF0A1A2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.mail, color: Color(0xFF00E676)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Envoyez les invitations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$planName. \nAjoutez vos collaborateurs, WorkIt enverra un lien d’invitation.\nVous aurez la possibilité d\'envoyer les invitations par la suite.',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1422),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Comment ça marche ?',
            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
          ),
          SizedBox(height: 10),
          _StepRow('1. WorkIt envoie un email avec un lien Invitation.'),
          _StepRow(
            '2. Si l’app est installée, ouverture directe sur l’activation.',
          ),
          _StepRow(
            '3. Sinon, installation puis rattachement automatique au compte entreprise.',
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 18, color: Color(0xFF00E676)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
