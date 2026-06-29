import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'create_workspace_screen.dart';

class AccountSetupScreen extends StatefulWidget {
  const AccountSetupScreen({super.key});

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim().toLowerCase();
      final password = _passwordCtrl.text;
      final firstName = _firstNameCtrl.text.trim();
      final lastName = _lastNameCtrl.text.trim();

      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CreateWorkspaceScreen(
          firstName: firstName,
          lastName: lastName,
          email: email,
          uid: cred.user?.uid ?? '',
        ),
      ));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_authError(e)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade800,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur inattendue. Réessayez.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade800,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return 'Connexion impossible. Vérifiez votre réseau.';
      case 'weak-password':
        return 'Mot de passe trop faible (6 caractères minimum).';
      case 'invalid-email':
        return 'Format d\'email invalide.';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé. Connectez-vous depuis l\'accueil.';
      case 'invalid-credential':
        return 'Cet email est déjà associé à un compte. Connectez-vous depuis l\'accueil.';
      case 'operation-not-allowed':
        return 'Inscription par email non activée. Contactez l\'administrateur.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez dans quelques minutes.';
      default:
        return 'Erreur (${e.code}) : ${e.message ?? 'inconnue'}';
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StepProgress(current: 1, total: 3),
              const SizedBox(height: 28),
              const Text(
                'Mon compte',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Vos identifiants pour accéder à WorkIt.',
                style: TextStyle(color: Colors.white60, fontSize: 15),
              ),
              const SizedBox(height: 28),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _DarkField(
                            controller: _firstNameCtrl,
                            label: 'Prénom',
                            textCapitalization: TextCapitalization.words,
                            validator: (v) =>
                                (v?.trim().isEmpty ?? true) ? 'Requis' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DarkField(
                            controller: _lastNameCtrl,
                            label: 'Nom',
                            textCapitalization: TextCapitalization.words,
                            validator: (v) =>
                                (v?.trim().isEmpty ?? true) ? 'Requis' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _DarkField(
                      controller: _emailCtrl,
                      label: 'Email professionnel',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return 'Email requis';
                        final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
                        if (!regex.hasMatch(s)) return 'Email invalide (ex: nom@domaine.fr)';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _DarkField(
                      controller: _passwordCtrl,
                      label: 'Mot de passe',
                      obscureText: !_showPassword,
                      suffix: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white38,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Mot de passe requis';
                        if (v.length < 6) return '6 caractères minimum';
                        if (!v.contains(RegExp('[A-Z]'))) {
                          return '1 majuscule requise';
                        }
                        if (!v.contains(RegExp('[0-9]'))) {
                          return '1 chiffre requis';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _DarkField(
                      controller: _confirmCtrl,
                      label: 'Confirmer le mot de passe',
                      obscureText: !_showConfirm,
                      suffix: IconButton(
                        icon: Icon(
                          _showConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white38,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _showConfirm = !_showConfirm),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Confirmation requise';
                        if (v != _passwordCtrl.text) {
                          return 'Les mots de passe ne correspondent pas';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.black,
                                ),
                              )
                            : const Text('Continuer'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Étape $current sur $total',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(total, (i) {
            final done = i < current;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: done
                      ? const Color(0xFF00E676)
                      : Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _DarkField extends StatelessWidget {
  const _DarkField({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF0F1422),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
