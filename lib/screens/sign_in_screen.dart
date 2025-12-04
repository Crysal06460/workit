import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'commercial_home_screen.dart';
import 'metreur_home_screen.dart';
import 'poseurs_home_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) return;
    final email = emailController.text.trim();
    final password = passwordController.text;
    setState(() => isLoading = true);
    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final uid = credential.user?.uid;
      if (uid == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'Utilisateur introuvable',
        );
      }

      final workspaceSnap = await FirebaseFirestore.instance
          .collection('workspaces')
          .where('adminUid', isEqualTo: uid)
          .limit(1)
          .get();

      if (workspaceSnap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Espace introuvable pour cet utilisateur.'),
          ),
        );
        return;
      }

      final data = workspaceSnap.docs.first.data();
      final usesApp = data['creatorUsesWorkit'] == true;
      String? roleKey;
      final roles = data['creatorRoles'];
      if (roles is List && roles.isNotEmpty) {
        roleKey = roles.first?.toString();
      } else if (data['creatorRole'] != null) {
        roleKey = data['creatorRole'].toString();
      }

      if (!usesApp || roleKey == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accès admin uniquement, aucun rôle terrain défini.'),
          ),
        );
        return;
      }

      final home = _homeForRole(roleKey);
      if (home == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rôle non supporté ($roleKey).')),
        );
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => home),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      final message = _humanError(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _humanError(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
        return 'Mot de passe incorrect.';
      case 'user-not-found':
        return 'Utilisateur introuvable.';
      case 'invalid-email':
        return 'Email invalide.';
      case 'network-request-failed':
        return 'Connexion réseau impossible.';
      default:
        return 'Connexion impossible : ${error.message ?? error.code}';
    }
  }

  Widget? _homeForRole(String roleKey) {
    switch (roleKey) {
      case 'commercial':
        return const CommercialHomeScreen();
      case 'metreur':
        return const MetreurHomeScreen();
      case 'poseur':
        return const PoseursHomeScreen();
      case 'commercial_metreur':
        return const CommercialHomeScreen();
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const bg = Color(0xFF07090D);
    const cardGradient = LinearGradient(
      colors: [Color(0xFF0F172A), Color(0xFF0A1A2F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    const accent = Color(0xFF00E676);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Se connecter',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 32),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: cardGradient,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: accent.withOpacity(0.45),
                              ),
                            ),
                            child: const Text(
                              'Espace sécurisé',
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.shield_moon,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Accédez à votre espace WorkIt',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Utilisez votre e-mail professionnel.',
                        style: TextStyle(color: Colors.white70, height: 1.35),
                      ),
                      const SizedBox(height: 22),
                      _Input(
                        controller: emailController,
                        label: 'Email professionnel',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Email requis';
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Email invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _Input(
                        controller: passwordController,
                        label: 'Mot de passe',
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Mot de passe requis';
                          final hasUpper = value.contains(RegExp('[A-Z]'));
                          final hasDigit = value.contains(RegExp('[0-9]'));
                          if (value.length < 6 || !hasUpper || !hasDigit) {
                            return '6 caractères, 1 majuscule, 1 chiffre requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Min. 6 caractères, dont 1 majuscule et 1 chiffre.',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text(
                            'Mot de passe oublié ?',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
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
                          child: Text(isLoading ? 'Connexion…' : 'Se connecter'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
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
        fillColor: const Color(0xFF0F1524),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}
