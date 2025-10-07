import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/workspace_repository.dart';
import 'firebase_options.dart';
import 'models/onboarding_models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🔥 Test Firestore avec logs
  try {
    await FirebaseFirestore.instance.collection('health').doc('ping').set({
      'ok': true,
      'at': DateTime.now().toIso8601String(),
    });
    // ignore: avoid_print
    print('[Firestore] write OK -> health/ping');
  } catch (e, st) {
    // ignore: avoid_print
    print('[Firestore] write ERROR: $e\n$st');
  }

  runApp(const WorkItApp());
}

class WorkItApp extends StatelessWidget {
  const WorkItApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0066FF)),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      textTheme: Typography.blackMountainView,
    );

    return MaterialApp(
      title: 'WorkIt',
      theme: theme,
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      const Text(
                        'WorkIt',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'La plateforme qui connecte commerciaux, métreurs et équipes de pose.',
                        style: TextStyle(fontSize: 18, color: Colors.black54),
                      ),
                      const SizedBox(height: 48),
                      AuthCard(
                        title: 'Je gère l’entreprise',
                        subtitle:
                            'Créer un espace, choisir l’abonnement et inviter l’équipe.',
                        icon: Icons.business_center,
                        primaryAction: AuthAction(
                          label: 'Créer mon espace',
                          onTap: (context) => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CreateWorkspaceScreen(),
                            ),
                          ),
                        ),
                        secondaryAction: AuthAction(
                          label: 'Me connecter',
                          onTap: (context) => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SignInScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      AuthCard(
                        title: 'On m’a invité',
                        subtitle:
                            'Renseigner le code reçu ou ouvrir le lien magique.',
                        icon: Icons.group,
                        primaryAction: AuthAction(
                          label: 'J’ai un code',
                          onTap: (context) => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const JoinWorkspaceScreen(),
                            ),
                          ),
                        ),
                        secondaryAction: AuthAction(
                          label: 'J’ai un lien',
                          onTap: (context) => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MagicLinkHelpScreen(),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Center(
                        child: TextButton(
                          onPressed: () {},
                          child: const Text(
                            'Besoin d’aide ? Contactez WorkIt Support',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryAction,
    this.secondaryAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final AuthAction primaryAction;
  final AuthAction? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => primaryAction.onTap(context),
                child: Text(primaryAction.label),
              ),
            ),
            if (secondaryAction != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => secondaryAction!.onTap(context),
                  child: Text(secondaryAction!.label),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AuthAction {
  AuthAction({required this.label, required this.onTap});

  final String label;
  final void Function(BuildContext context) onTap;
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connexion en cours... (mock)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Se connecter')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Accédez à votre espace WorkIt',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Utilisez votre e-mail professionnel ou un SSO activé.',
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email professionnel',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Email requis';
                  if (!value.contains('@')) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Mot de passe requis';
                  if (value.length < 8) return '8 caractères minimum';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Mot de passe oublié ?'),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Se connecter'),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.login),
                label: const Text(
                  'Continuer avec Apple / Google (placeholder)',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateWorkspaceScreen extends StatefulWidget {
  const CreateWorkspaceScreen({super.key});

  @override
  State<CreateWorkspaceScreen> createState() => _CreateWorkspaceScreenState();
}

class _CreateWorkspaceScreenState extends State<CreateWorkspaceScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final siretController = TextEditingController();
  final addressController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    siretController.dispose();
    addressController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!formKey.currentState!.validate()) return;
    final data = OnboardingData(
      companyName: nameController.text,
      siret: siretController.text,
      address: addressController.text,
    );
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PlanSelectionScreen(data: data)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer mon entreprise')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Qui gère WorkIt ?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ces informations apparaîtront sur les fiches chantiers.',
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de l’entreprise',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Nom requis';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: siretController,
                decoration: const InputDecoration(
                  labelText: 'SIRET (optionnel)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Adresse du siège',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Adresse requise';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _continue,
                  child: const Text('Continuer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  late PlanOption selectedPlan;
  late List<PlanOption> plans;

  @override
  void initState() {
    super.initState();
    plans = defaultPlans();
    selectedPlan = plans.first;
  }

  void _continue() {
    widget.data.plan = selectedPlan;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InviteTeamScreen(data: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choisir un abonnement')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenue ${widget.data.companyName}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sélectionnez votre forfait WorkIt. Vous pourrez modifier ou augmenter vos sièges plus tard.',
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: plans.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  final isSelected = plan.id == selectedPlan.id;
                  return InkWell(
                    onTap: () => setState(() => selectedPlan = plan),
                    child: PlanCard(plan: plan, isSelected: isSelected),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _continue,
                child: Text('Continuer avec ${selectedPlan.name}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, required this.isSelected});

  final PlanOption plan;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade300;
    final seatBadges = plan.seatsByRole.entries.map((entry) {
      final seatLabel = plan.seatLabelForRole(entry.key);
      final pluralLabel = roleDisplayNamePlural(entry.key);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$seatLabel $pluralLabel',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }).toList();
    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: 1.4),
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: isSelected ? 4 : 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.price,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: seatBadges),
            const SizedBox(height: 12),
            for (final feature in plan.features)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feature)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
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
                      Text(
                        '1. WorkIt envoie un email + SMS avec un lien magique (dynamic link).',
                      ),
                      Text(
                        '2. Si l’app est déjà installée, elle s’ouvre directement sur l’activation.',
                      ),
                      Text(
                        '3. Sinon, l’utilisateur installe l’app puis WorkIt rattache automatiquement le compte à l’entreprise.',
                      ),
                      Text(
                        '4. Les codes ci-dessus servent de secours si le lien est expiré.',
                      ),
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

class AdminSummaryScreen extends StatefulWidget {
  const AdminSummaryScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<AdminSummaryScreen> createState() => _AdminSummaryScreenState();
}

class _AdminSummaryScreenState extends State<AdminSummaryScreen> {
  late final WorkspaceRepository repository;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    repository = WorkspaceRepository(FirebaseFirestore.instance);
  }

  Future<void> _createWorkspace() async {
    setState(() => isSaving = true);
    try {
      final result = await repository.createWorkspace(widget.data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Espace créé (ID: ${result.workspaceId}) · Invitations: ${result.invitesCreated}',
          ),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Création impossible : $error')));
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final plan = data.plan;
    return Scaffold(
      appBar: AppBar(title: const Text('Espace prêt !')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tout est configuré',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Entreprise : ${data.companyName}\nPlan : ${plan?.name ?? '-'} (${plan?.price ?? ''})',
            ),
            const SizedBox(height: 4),
            Text('Invitations envoyées : ${data.totalInvites}'),
            const SizedBox(height: 12),
            if (plan != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final role in onboardingRoles)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${roleDisplayNamePlural(role)} : ${data.seatUsageLabel(role)}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            const Text('Invitations envoyées :'),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: data.invites.entries.map((entry) {
                  final emails = entry.value.isEmpty
                      ? ['Aucun email']
                      : entry.value;
                  final roleLabel = roleDisplayNamePlural(entry.key);
                  return Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            roleLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          for (final email in emails) Text(email),
                          const SizedBox(height: 8),
                          Text(
                            'Code secours : ${data.generatedCodes[entry.key]}',
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isSaving ? null : _createWorkspace,
                child: Text(
                  isSaving
                      ? 'Création en cours…'
                      : 'Créer l’espace et envoyer les invitations',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JoinWorkspaceScreen extends StatefulWidget {
  const JoinWorkspaceScreen({super.key});

  @override
  State<JoinWorkspaceScreen> createState() => _JoinWorkspaceScreenState();
}

class _JoinWorkspaceScreenState extends State<JoinWorkspaceScreen> {
  final formKey = GlobalKey<FormState>();
  final workspaceCodeController = TextEditingController();
  final roleCodeController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    workspaceCodeController.dispose();
    roleCodeController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _join() {
    if (!formKey.currentState!.validate()) return;
    final role = _mapRole(roleCodeController.text.trim());
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoleAssignedScreen(
          role: role,
          workspaceCode: workspaceCodeController.text.trim(),
        ),
      ),
    );
  }

  String _mapRole(String code) {
    if (code.toUpperCase().contains('COMM')) return 'Commercial';
    if (code.toUpperCase().contains('MET')) return 'Métreur';
    if (code.toUpperCase().contains('POS')) return 'Poseur';
    return 'Collaborateur';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rejoindre une entreprise')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Entrez les codes fournis par votre entreprise.',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: workspaceCodeController,
                decoration: const InputDecoration(labelText: 'Code entreprise'),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Code requis';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: roleCodeController,
                decoration: const InputDecoration(
                  labelText: 'Code rôle (ex: COMMERCIAL)',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Code rôle requis';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email professionnel',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Email requis';
                  if (!value.contains('@')) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Créer un mot de passe',
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Mot de passe requis';
                  if (value.length < 8) return '8 caractères minimum';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _join,
                  child: const Text('Rejoindre WorkIt'),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Pas de code ?'),
                      SizedBox(height: 4),
                      Text(
                        'Contactez votre administrateur pour recevoir une nouvelle invitation ou un lien magique.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleAssignedScreen extends StatelessWidget {
  const RoleAssignedScreen({
    super.key,
    required this.role,
    required this.workspaceCode,
  });

  final String role;
  final String workspaceCode;

  @override
  Widget build(BuildContext context) {
    final descriptions = {
      'Commercial':
          'Créez les chantiers, importez les devis et suivez l’avancement.',
      'Métreur':
          'Planifiez vos visites, saisissez les mesures et générez les fiches métré.',
      'Poseur': 'Recevez vos chantiers du jour et clôturez en quelques clics.',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Activation terminée')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenue dans WorkIt !',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text('Entreprise: $workspaceCode'),
            const SizedBox(height: 24),
            RoleBadge(role: role),
            const SizedBox(height: 16),
            Text(
              descriptions[role] ??
                  'Votre administrateur définira vos autorisations.',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {},
                child: Text('Aller sur mon espace $role'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final icons = {
      'Commercial': Icons.handshake,
      'Métreur': Icons.straighten,
      'Poseur': Icons.home_repair_service,
      'Collaborateur': Icons.person,
    };
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icons[role] ?? Icons.person),
          const SizedBox(width: 12),
          Text(
            role,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class MagicLinkHelpScreen extends StatelessWidget {
  const MagicLinkHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lien magique reçu')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Ouvrir le lien d’invitation',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('1. Cliquez sur le lien dans l’email ou le SMS WorkIt.'),
            Text(
              '2. Si l’application est installée, elle s’ouvrira automatiquement.',
            ),
            Text(
              '3. Sinon, installez WorkIt depuis l’App Store ou Google Play.',
            ),
            Text(
              '4. Au premier lancement, WorkIt détecte le lien différé et rattache votre rôle automatiquement.',
            ),
            SizedBox(height: 24),
            Text(
              'Besoin d’un plan B ? Utilisez les codes reçus pour rejoindre manuellement votre entreprise.',
            ),
          ],
        ),
      ),
    );
  }
}
