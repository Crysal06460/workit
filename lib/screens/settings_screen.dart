import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/wi_swipe_back.dart';
import 'team_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _faceIdEnabled = false;
  bool _canCheckBiometrics = false;
  bool _canManageTeam = false;
  List<String> _manageableRoles = [];
  String? _workspaceId;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _loadSettings();
    _loadTeamPermissions();
  }

  Future<void> _loadTeamPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final workspaceId = prefs.getString('workit_workspace_id');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (workspaceId == null || uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null || !mounted) return;
      setState(() {
        _workspaceId = workspaceId;
        _canManageTeam = data['canManageTeam'] == true;
        _manageableRoles = (data['manageableRoles'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _checkBiometrics() async {
    final LocalAuthentication auth = LocalAuthentication();
    final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
    final bool canAuthenticate =
        canAuthenticateWithBiometrics || await auth.isDeviceSupported();
    setState(() {
      _canCheckBiometrics = canAuthenticate;
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _faceIdEnabled = prefs.getBool('workit_faceid_enabled') ?? false;
    });
  }

  Future<void> _toggleFaceId(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('workit_faceid_enabled', value);
    setState(() {
      _faceIdEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.grey600),
        title: const Text(
          'Paramètres',
          style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: WiSwipeBack(child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_canManageTeam && _workspaceId != null && _manageableRoles.isNotEmpty) ...[
              _SettingsCard(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(Icons.groups_outlined, color: AppColors.primary),
                  title: const Text(
                    'Gérer l\'équipe',
                    style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Ajouter des membres à l\'équipe',
                    style: TextStyle(color: AppColors.grey400, fontSize: 13),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.grey300),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TeamManagementScreen(
                          workspaceId: _workspaceId!,
                          manageableRoles: _manageableRoles,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_canCheckBiometrics) ...[
              _SettingsCard(
                child: SwitchListTile(
                  activeThumbColor: AppColors.primary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: const Text(
                    'Déverrouillage FaceID / Biométrique',
                    style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Utiliser la biométrie pour la connexion rapide',
                    style: TextStyle(color: AppColors.grey400, fontSize: 13),
                  ),
                  value: _faceIdEnabled,
                  onChanged: _toggleFaceId,
                  secondary: const Icon(Icons.face_outlined, color: AppColors.grey600),
                ),
              ),
              const SizedBox(height: 16),
            ] else
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "La biométrie n'est pas disponible sur cet appareil.",
                  style: TextStyle(color: AppColors.grey400),
                  textAlign: TextAlign.center,
                ),
              ),
            const _SectionLabel('Légal'),
            const SizedBox(height: 8),
            _SettingsCard(
              child: Column(
                children: [
                  _LegalTile(
                    icon: Icons.description_outlined,
                    label: 'Conditions générales de vente',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _LegalPlaceholderScreen(
                          title: 'Conditions générales de vente',
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.cardBorder, indent: 16, endIndent: 16),
                  _LegalTile(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Politique de confidentialité',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _LegalPlaceholderScreen(
                          title: 'Politique de confidentialité',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      )),
    );
  }
}

/// Carte conteneur commune à toutes les sections de Réglages — même style
/// (fond blanc, bordure fine, coins arrondis) que le reste de l'app
/// (`AppColors.surface`/`cardBorder`), à la place de l'ancien thème sombre
/// autonome (`Color(0xFF07090D)`/vert néon) resté isolé du design system.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // `Material` (pas un `Container` décoré) : un ListTile a besoin d'un
    // ancêtre Material pour peindre son fond/ink splash correctement — un
    // Container avec juste une couleur de fond les rend invisibles.
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.grey400,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _LegalTile extends StatelessWidget {
  const _LegalTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: AppColors.grey600),
      title: Text(
        label,
        style: const TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.grey300),
      onTap: onTap,
    );
  }
}

/// Écran temporaire pour CGV/Politique de confidentialité — le lien est
/// fictif pour l'instant (pas de vrai texte juridique fourni), mais
/// l'entrée de menu et la navigation sont fonctionnelles dès maintenant.
class _LegalPlaceholderScreen extends StatelessWidget {
  const _LegalPlaceholderScreen({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.grey600),
        title: Text(title, style: const TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700)),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.article_outlined, size: 40, color: AppColors.grey300),
              SizedBox(height: 16),
              Text(
                'Contenu à venir.',
                style: TextStyle(color: AppColors.grey400, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
