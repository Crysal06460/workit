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

  @override
  void dispose() {
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
    for (final role in onboardingRoles) {
      final existing = widget.data.invites[role];
      if (existing != null && existing.isNotEmpty) {
        controllers[role]!.text = existing.join('\n');
      }
    }
  }

  void _continue() {
    for (final role in onboardingRoles) {
      widget.data.invites[role] = _splitEmails(controllers[role]!.text);
    }

    final validationError = _validateSeatLimits();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminSummaryScreen(data: widget.data)),
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
      final count = widget.data.inviteCount(role);
      if (count > limit) {
        overflows.add('${roleDisplayNamePlural(role)}: $count / $limit');
      }
    }
    if (overflows.isEmpty) return null;
    return 'Capacité dépassée pour : ${overflows.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final codes = widget.data.generatedCodes;
    final plan = widget.data.plan;
    return Scaffold(
      appBar: AppBar(title: const Text('Inviter mon équipe')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: Theme.of(context).colorScheme.surface,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan?.name ?? 'Forfait sélectionné',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Indiquez les emails de vos collaborateurs. WorkIt enverra un lien magique et rappellera le code de secours.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final role in onboardingRoles) ...[
                InviteRoleSection(
                  roleKey: role,
                  controller: controllers[role]!,
                  code: codes[role]!,
                  plan: plan,
                  currentUsageLabel: widget.data.seatUsageLabel(role),
                ),
                const SizedBox(height: 24),
              ],
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Comment ça marche ?',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('1. WorkIt envoie un email + SMS avec un lien magique (dynamic link).'),
                      Text('2. Si l’app est déjà installée, elle s’ouvre directement sur l’activation.'),
                      Text('3. Sinon, l’utilisateur installe l’app puis WorkIt rattache automatiquement le compte à l’entreprise.'),
                      Text('4. Les codes ci-dessus servent de secours si le lien est expiré.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _continue,
                  child: const Text('Envoyer les invitations'),
                ),
              ),
            ],
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
    required this.code,
    required this.plan,
    required this.currentUsageLabel,
  });

  final String roleKey;
  final TextEditingController controller;
  final String code;
  final PlanOption? plan;
  final String currentUsageLabel;

  @override
  Widget build(BuildContext context) {
    final roleLabel = roleDisplayNamePlural(roleKey);
    final placeholder = defaultInvitePlaceholder(roleKey);
    final seatLabel = plan?.seatLabelForRole(roleKey) ?? 'Illimité';
    final capacityText = plan == null
        ? 'Sélectionnez un plan pour voir la capacité incluant les ${roleLabel.toLowerCase()}.'
        : 'Capacité du plan : $seatLabel ${roleLabel.toLowerCase()}';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              roleLabel,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(capacityText, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Text(
              'Actuellement : $currentUsageLabel',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Emails ${roleLabel.toLowerCase()}',
                hintText: placeholder,
                alignLabelWithHint: true,
              ),
              keyboardType: TextInputType.multiline,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.key, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Code ${roleLabel} : $code',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Code copié: $code (mock)')),
                      );
                    },
                    icon: const Icon(Icons.copy),
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
