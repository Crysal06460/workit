import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  String? _role;
  String? _companyId;
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
      final callable = FirebaseFunctions.instance.httpsCallable('getInvitationByToken');
      final result = await callable.call({'token': widget.token});
      final data = Map<String, dynamic>.from(result.data as Map);
      setState(() {
        _role = data['role']?.toString();
        _companyId = data['companyId']?.toString();
        _email = data['email']?.toString();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _activate() async {
    if (_passwordController.text.length < 6) {
      setState(() => _error = 'Mot de passe trop court (min 6 caractères)');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('consumeInvitation');
      final result = await callable.call({
        'token': widget.token,
        'password': _passwordController.text,
        'firstName': _firstController.text.trim(),
        'lastName': _lastController.text.trim(),
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      // Connecter l'utilisateur avec l'email et mdp choisis
      if (_email != null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email!,
          password: _passwordController.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/'); // TODO: route home selon rôle
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Invitation WorkIt'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          border: Border.all(color: Colors.redAccent),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error ?? '',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (_email != null)
                      Text(
                        _email!,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                    if (_role != null || _companyId != null)
                      Text(
                        'Entreprise: ${_companyId ?? '–'} • Rôle: ${_role ?? '–'}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _firstController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Prénom'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _lastController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Nom'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Créer un mot de passe'),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00F795),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _loading ? null : _activate,
                        child: const Text('Activer mon compte', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
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
        borderSide: BorderSide(color: Color(0xFF00F795), width: 1.4),
      ),
    );
  }
}
