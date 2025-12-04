import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/onboarding_models.dart';
import 'plan_selection_screen.dart';

class AccountSetupScreen extends StatefulWidget {
  const AccountSetupScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) return;
    final email = emailController.text.trim();
    final password = passwordController.text;
    setState(() => isLoading = true);
    try {
      UserCredential credential;
      try {
        credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
      } on FirebaseAuthException catch (error) {
        if (error.code == 'email-already-in-use') {
          credential = await FirebaseAuth.instance
              .signInWithEmailAndPassword(email: email, password: password);
        } else {
          rethrow;
        }
      }

      widget.data
        ..adminEmail = email
        ..adminUid = credential.user?.uid ?? '';

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlanSelectionScreen(data: widget.data)),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = _humanReadableError(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _humanReadableError(FirebaseAuthException error) {
    switch (error.code) {
      case 'network-request-failed':
        return 'Connexion impossible (réseau). Réessayez en ligne.';
      case 'weak-password':
        return 'Mot de passe trop faible.';
      case 'invalid-email':
        return 'Email invalide.';
      case 'email-already-in-use':
        return 'Email déjà utilisé avec un autre mot de passe.';
      default:
        return 'Impossible de créer le compte : ${error.message ?? error.code}';
    }
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
          'Espace prêt',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0E1726), Color(0xFF0A1A2F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.12),
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
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
                        child: const Icon(Icons.verified_user, color: accent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Créez votre accès admin',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Cet accès servira à reconnecter et administrer l’entreprise sur le tableau de bord.',
                              style: TextStyle(color: Colors.white70, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _Field(
                  controller: emailController,
                  label: 'Email admin',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Email requis';
                    if (!trimmed.contains('@') || !trimmed.contains('.')) {
                      return 'Email invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: passwordController,
                  label: 'Mot de passe',
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Mot de passe requis';
                    final hasUpper = value.contains(RegExp('[A-Z]'));
                    final hasDigit = value.contains(RegExp('[0-9]'));
                    if (value.length < 6 || !hasUpper || !hasDigit) {
                      return '6 caractères, 1 majuscule, 1 chiffre requis';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _Field(
                  controller: confirmController,
                  label: 'Confirmez le mot de passe',
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Confirmation requise';
                    if (value != passwordController.text) return 'Les mots de passe diffèrent';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    onPressed: isLoading ? null : _submit,
                    child: Text(isLoading ? 'Création en cours…' : 'Continuer'),
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF0F1422),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
