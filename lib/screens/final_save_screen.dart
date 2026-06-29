import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/workspace_repository.dart';
import '../models/onboarding_models.dart';
import 'admin_home_screen.dart';

class FinalSaveScreen extends StatefulWidget {
  const FinalSaveScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<FinalSaveScreen> createState() => _FinalSaveScreenState();
}

class _FinalSaveScreenState extends State<FinalSaveScreen> {
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _save());
  }

  Future<void> _save() async {
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
    try {
      widget.data
        ..creatorUsesWorkit = true
        ..creatorRoleKey = 'admin';

      final repo = WorkspaceRepository(FirebaseFirestore.instance);
      final result = await repo.createWorkspace(widget.data);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('workit_workspace_id', result.workspaceId);
      await prefs.setString('workit_workspace_name', widget.data.companyName);
      await prefs.setString(
        'workit_user_first_name',
        widget.data.creatorFirstName ?? '',
      );
      await prefs.setString(
        'workit_user_last_name',
        widget.data.creatorLastName ?? '',
      );
      await prefs.setBool('workit_is_admin', true);
      if (widget.data.tradeKey != null) {
        await prefs.setString('workit_trade_key', widget.data.tradeKey!);
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF07090D);
    const accent = Color(0xFF00E676);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: _hasError
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 56,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Erreur lors de la création',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.white60),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _save,
                        child: const Text(
                          'Réessayer',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.10),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: accent.withOpacity(0.3), width: 1.5),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          color: Color(0xFF00E676),
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Création de votre espace...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cela prend quelques secondes.',
                      style: TextStyle(color: Colors.white54, fontSize: 15),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
