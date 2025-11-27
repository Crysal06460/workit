import 'package:flutter/material.dart';

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
                  if (value == null || value.isEmpty) return 'Mot de passe requis';
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
      'Commercial': 'Créez les chantiers, importez les devis et suivez l’avancement.',
      'Métreur': 'Planifiez vos visites, saisissez les mesures et générez les fiches métré.',
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
              descriptions[role] ?? 'Votre administrateur définira vos autorisations.',
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
            Text('2. Si l’application est installée, elle s’ouvrira automatiquement.'),
            Text('3. Sinon, installez WorkIt depuis l’App Store ou Google Play.'),
            Text('4. Au premier lancement, WorkIt détecte le lien différé et rattache votre rôle automatiquement.'),
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
