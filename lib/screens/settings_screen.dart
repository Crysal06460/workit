import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    const bg = Color(0xFF07090D);
    const accent = Color(0xFF00E676);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Paramètres',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_canManageTeam && _workspaceId != null && _manageableRoles.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(Icons.groups_outlined, color: accent),
                  title: const Text(
                    'Gérer l\'équipe',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Ajouter des membres à l\'équipe',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white38),
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
            if (_canCheckBiometrics)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: SwitchListTile(
                  activeColor: accent,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: const Text(
                    'Déverrouillage FaceID / Biométrique',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Utiliser la biométrie pour la connexion rapide',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  value: _faceIdEnabled,
                  onChanged: _toggleFaceId,
                  secondary: const Icon(Icons.face, color: Colors.white70),
                ),
              ),
              if (!_canCheckBiometrics)
                 Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Text(
                     "La biométrie n'est pas disponible sur cet appareil.",
                     style: TextStyle(color: Colors.white54),
                     textAlign: TextAlign.center,
                   ),
                 )
          ],
        ),
      ),
    );
  }
}
