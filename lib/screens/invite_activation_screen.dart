import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/onboarding_models.dart';
import '../services/auth_navigation_service.dart';

class InviteActivationScreen extends StatefulWidget {
  const InviteActivationScreen({super.key, required this.token});

  final String token;

  @override
  State<InviteActivationScreen> createState() => _InviteActivationScreenState();
}

class _InviteActivationScreenState extends State<InviteActivationScreen> {
  final _passwordController = TextEditingController();
  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _role;
  String? _companyName;
  String? _email;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefetch();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _firstController.dispose();
    _lastController.dispose();
    super.dispose();
  }

  Future<void> _prefetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('getInvitationByToken');
      final result = await callable.call({'token': widget.token});
      final data = Map<String, dynamic>.from(result.data as Map);
      setState(() {
        _role = data['role']?.toString();
        _companyName = data['companyName']?.toString();
        _email = data['email']?.toString();
      });
    } catch (e) {
      setState(() => _error = 'Invitation introuvable ou expirée.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _activate() async {
    final password = _passwordController.text;
    if (password.length < 6) {
      setState(() => _error = 'Mot de passe trop court (minimum 6 caractères).');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('consumeInvitation');
      await callable.call({
        'token': widget.token,
        'password': password,
        'firstName': _firstController.text.trim(),
        'lastName': _lastController.text.trim(),
      });

      if (_email != null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email!,
          password: password,
        );
      }

      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await AuthNavigationService().navigateUser(context, user);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Erreur lors de l\'activation. Veuillez réessayer.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Color(0xFF00E676), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Activation du compte',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white54),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Bienvenue sur WorkIt',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Créez votre accès pour rejoindre votre équipe.',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    if (_email != null || _role != null || _companyName != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1422),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_email != null) ...[
                              Text(
                                _email!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                            if (_role != null || _companyName != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (_role != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E676).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
                                      ),
                                      child: Text(
                                        roleDisplayName(_role!),
                                        style: const TextStyle(
                                          color: Color(0xFF00E676),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  if (_companyName != null) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.business_outlined, color: Colors.white38, size: 14),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _companyName!,
                                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _firstController,
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration('Prénom'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _lastController,
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration('Nom'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                        'Choisir un mot de passe',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.white38,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Minimum 6 caractères.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _loading ? null : _activate,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                              )
                            : const Text(
                                'Activer mon compte',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
