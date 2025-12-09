import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sign_in_screen.dart';

const Color _poseurBg = Color(0xFF07090D);
const Color _poseurCard = Color(0xFF0F1422);
const Color _poseurAccent = Color(0xFF00F795);

class PoseursHomeScreen extends StatefulWidget {
  const PoseursHomeScreen({super.key});

  @override
  State<PoseursHomeScreen> createState() => _PoseursHomeScreenState();
}

class _PoseursHomeScreenState extends State<PoseursHomeScreen> {
  String? _firstName;
  String? _lastName;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _firstName = prefs.getString('workit_user_first_name');
      _lastName = prefs.getString('workit_user_last_name');
    });
  }

  String _greetingName() {
    if (_firstName?.trim().isNotEmpty == true) {
      return _firstName!.trim();
    }
    if (_lastName?.trim().isNotEmpty == true) {
      return _lastName!.trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _poseurBg,
        appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _greetingName().isNotEmpty ? 'Bonjour ${_greetingName()}' : 'Bonjour',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Poseur',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: _poseurAccent),
              tooltip: 'Se déconnecter',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: _poseurAccent,
            tabs: const [
              Tab(text: 'Jour'),
              Tab(text: 'Semaine'),
              Tab(text: 'Liste'),
            ],
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: TabBarView(
              children: const [
                _PlaceholderList(label: 'Jour'),
                _PlaceholderList(label: 'Semaine'),
                _PlaceholderList(label: 'Liste'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderList extends StatelessWidget {
  const _PlaceholderList({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _poseurCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          'Aucune donnée ($label)',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
