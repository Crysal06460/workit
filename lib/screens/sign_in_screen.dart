import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../models/onboarding_models.dart';
import '../services/auth_navigation_service.dart';

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
  bool rememberEmail = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('workit_saved_email');
    if (savedEmail != null) {
      emailController.text = savedEmail;
      setState(() {
        rememberEmail = true;
      });
    }
  }

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
      final user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'Utilisateur introuvable',
        );
      }

      // Save or clear email based on checkbox
      final prefs = await SharedPreferences.getInstance();
      if (rememberEmail) {
        await prefs.setString('workit_saved_email', email);
      } else {
        await prefs.remove('workit_saved_email');
      }

      if (!mounted) return;
      
      // Use the centralized navigation service
      await AuthNavigationService().navigateUser(context, user);

    } on FirebaseAuthException catch (error) {
      final message = _humanError(error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
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
      case 'invalid-credential':
        return 'Identifiants invalides ou expirés.';
      case 'network-request-failed':
        return 'Connexion réseau impossible.';
      default:
        return 'Connexion impossible : ${error.message ?? error.code}';
    }
  }

  Future<void> _sendReset() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez un email valide avant de réinitialiser.')),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email de réinitialisation envoyé.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Impossible d'envoyer le mail.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                // ── Logo ──────────────────────────────────────
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.construction_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                const Text('WorkIt', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.grey900, letterSpacing: -1)),
                const SizedBox(height: 6),
                const Text('Accédez à votre espace professionnel', style: TextStyle(color: AppColors.grey500, fontSize: 14)),
                const SizedBox(height: 40),
                // ── Carte formulaire ──────────────────────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Connexion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.grey900)),
                      const SizedBox(height: 4),
                      const Text('Utilisez votre e-mail professionnel', style: TextStyle(color: AppColors.grey500, fontSize: 13)),
                      const SizedBox(height: 22),
                      _Input(
                        controller: emailController,
                        label: 'Email professionnel',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Email requis';
                          if (!v.contains('@') || !v.contains('.')) return 'Email invalide';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _Input(
                        controller: passwordController,
                        label: 'Mot de passe',
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Mot de passe requis';
                          if (v.length < 6) return '6 caractères minimum';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: rememberEmail,
                              activeColor: AppColors.primary,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              side: const BorderSide(color: AppColors.grey300),
                              onChanged: (v) => setState(() => rememberEmail = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(child: Text("Se souvenir de l'email", style: TextStyle(color: AppColors.grey600, fontSize: 13))),
                          TextButton(
                            onPressed: _sendReset,
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            child: const Text('Mot de passe oublié ?', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          onPressed: isLoading ? null : _submit,
                          child: isLoading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : const Text('Se connecter'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: const [
                      Icon(Icons.shield_outlined, color: AppColors.primary, size: 18),
                      SizedBox(width: 8),
                      Expanded(child: Text('Connexion sécurisée · Données chiffrées', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key, required this.email, this.currentRole, this.userDoc});

  final String email;
  final String? currentRole;
  final Map<String, dynamic>? userDoc;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _phoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _role;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _role = widget.currentRole;
    final data = widget.userDoc;
    _firstController.text = data?['firstName']?.toString() ?? '';
    _lastController.text = data?['lastName']?.toString() ?? '';
    _phoneController.text = data?['phone']?.toString() ?? '';
  }

  @override
  void dispose() {
    _firstController.dispose();
    _lastController.dispose();
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == null && widget.currentRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez un rôle.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw FirebaseAuthException(code: 'user-null', message: 'Utilisateur non connecté');

      if (_newPasswordController.text != _confirmPasswordController.text) {
        throw FirebaseAuthException(code: 'password-mismatch', message: 'Les mots de passe ne correspondent pas');
      }

      await user.updatePassword(_newPasswordController.text);

      final uid = user.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'firstName': _firstController.text.trim(),
          'lastName': _lastController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': _role ?? widget.currentRole,
          'tradeKey': widget.userDoc?['tradeKey'],
          'mustChangePassword': false,
          'tempPassword': FieldValue.delete(),
          'status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Nettoie les accès provisoires côté admin
      final provSnap = await FirebaseFirestore.instance
          .collection('provisioned_accounts')
          .where('uid', isEqualTo: uid)
          .get();
      for (final doc in provSnap.docs) {
        await doc.reference.set(
          {
            'status': 'activated',
            'tempPassword': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop<Map<String, dynamic>>({
        'firstName': _firstController.text.trim(),
        'lastName': _lastController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _role ?? widget.currentRole,
        'mustChangePassword': false,
      });
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? e.code)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de mettre à jour : $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.grey700),
        title: const Text('Sécuriser votre compte', style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    'Merci de définir votre mot de passe et vos informations avant d\'accéder à votre espace.',
                    style: TextStyle(color: AppColors.primary, height: 1.4, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 18),
                _input(
                  controller: _firstController,
                  label: 'Prénom',
                  validator: (v) => v == null || v.trim().isEmpty ? 'Prénom requis' : null,
                ),
                const SizedBox(height: 12),
                _input(
                  controller: _lastController,
                  label: 'Nom',
                  validator: (v) => v == null || v.trim().isEmpty ? 'Nom requis' : null,
                ),
                const SizedBox(height: 12),
                _input(
                  controller: _phoneController,
                  label: 'Téléphone',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Téléphone requis';
                    if (v.trim().length != 10) return '10 chiffres requis';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                if (widget.currentRole != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rôle assigné', style: TextStyle(color: AppColors.grey500, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(roleDisplayName(widget.currentRole!), style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  )
                else
                  _roleSelector(),
                const SizedBox(height: 12),
                _input(
                  controller: _newPasswordController,
                  label: 'Nouveau mot de passe',
                  obscure: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Mot de passe requis';
                    final hasUpper = v.contains(RegExp('[A-Z]'));
                    final hasDigit = v.contains(RegExp('[0-9]'));
                    if (v.length < 6 || !hasUpper || !hasDigit) {
                      return '6 caractères, 1 majuscule et 1 chiffre requis';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _input(
                  controller: _confirmPasswordController,
                  label: 'Confirmer le mot de passe',
                  obscure: true,
                  validator: (v) => v != _newPasswordController.text ? 'Les mots de passe diffèrent' : null,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Continuer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleSelector() {
    final roles = {'commercial': 'Commercial', 'metreur': 'Métreur', 'poseur': 'Poseur'};
    final roleColors = {'commercial': AppColors.primary, 'metreur': AppColors.purple, 'poseur': AppColors.success};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Rôle', style: TextStyle(color: AppColors.grey700, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: roles.entries.map((entry) {
            final selected = _role == entry.key;
            final color = roleColors[entry.key] ?? AppColors.primary;
            return SizedBox(
              width: 130,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: selected ? color : AppColors.grey200, width: selected ? 2 : 1),
                  backgroundColor: selected ? color.withOpacity(0.1) : AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => setState(() => _role = entry.key),
                child: Text(entry.value, style: TextStyle(color: selected ? color : AppColors.grey600, fontWeight: FontWeight.w700)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: AppColors.grey900),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.grey500),
        filled: true,
        fillColor: AppColors.grey50,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      style: const TextStyle(color: AppColors.grey900),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.grey500),
        filled: true,
        fillColor: AppColors.grey50,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
