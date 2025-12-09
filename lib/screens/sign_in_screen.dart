import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

      // Cherche workspace par admin; sinon, par companyId depuis users/{uid}
      QuerySnapshot<Map<String, dynamic>> workspaceSnap = await FirebaseFirestore.instance
          .collection('workspaces')
          .where('adminUid', isEqualTo: uid)
          .limit(1)
          .get();

      String? workspaceId;
      Map<String, dynamic>? data;
      String? roleKey;
      bool isAdmin = false;
      Map<String, dynamic>? userData;

      if (workspaceSnap.docs.isEmpty) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        userData = userDoc.data();
        final companyId = userData?['companyId']?.toString();
        roleKey = userData?['role']?.toString();
        if (companyId != null && companyId.isNotEmpty) {
          // 1) Essai par docId
          final ws = await FirebaseFirestore.instance.collection('workspaces').doc(companyId).get();
          if (ws.exists) {
            workspaceId = ws.id;
            data = ws.data();
          } else {
            // 2) Essai par siret ou companyName
            final bySiret = await FirebaseFirestore.instance
                .collection('workspaces')
                .where('siret', isEqualTo: companyId)
                .limit(1)
                .get();
            if (bySiret.docs.isNotEmpty) {
              workspaceId = bySiret.docs.first.id;
              data = bySiret.docs.first.data();
            } else {
              final byName = await FirebaseFirestore.instance
                  .collection('workspaces')
                  .where('companyName', isEqualTo: companyId)
                  .limit(1)
                  .get();
              if (byName.docs.isNotEmpty) {
                workspaceId = byName.docs.first.id;
                data = byName.docs.first.data();
              }
            }
          }
        }
      } else {
        workspaceId = workspaceSnap.docs.first.id;
        data = workspaceSnap.docs.first.data();
        isAdmin = true;
        final roles = data?['creatorRoles'];
        if (roles is List && roles.isNotEmpty) {
          roleKey = roles.first?.toString();
        } else if (data?['creatorRole'] != null) {
          roleKey = data?['creatorRole'].toString();
        }
        if (userData == null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          userData = userDoc.data();
          roleKey ??= userData?['role']?.toString();
        }
      }

      if (workspaceId == null || data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Espace introuvable pour cet utilisateur.'),
          ),
        );
        return;
      }

      final usesApp = data['creatorUsesWorkit'] == true;
      isAdmin = isAdmin || (data['adminUid']?.toString() == uid);
      roleKey ??= data['role']?.toString();

      final mustChangePassword = userData?['mustChangePassword'] == true;

      if (mustChangePassword) {
        final completed = await Navigator.of(context).push<Map<String, dynamic>?>(
          MaterialPageRoute(
            builder: (_) => CompleteProfileScreen(
              email: email,
              currentRole: roleKey,
              userDoc: userData,
            ),
          ),
        );
        if (completed != null) {
          roleKey = completed['role']?.toString() ?? roleKey;
          userData = userData ?? {};
          userData.addAll(completed);
        } else {
          return;
        }
      }

      if (!usesApp && roleKey == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accès admin uniquement, aucun rôle défini.'),
          ),
        );
        return;
      }

      // Stocke le contexte d’entreprise pour isoler les données.
      final tradeKey = (userData?['tradeKey'] ?? data['tradeKey'])?.toString();
      await _persistWorkspaceContext(
        workspaceId,
        data['companyName']?.toString() ?? '',
        userData?['firstName']?.toString() ?? data['creatorFirstName']?.toString(),
        userData?['lastName']?.toString() ?? data['creatorLastName']?.toString(),
        isAdmin,
        tradeKey,
      );

      final home = _homeForRole(roleKey ?? 'commercial');
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

  Future<void> _persistWorkspaceContext(
    String workspaceId,
    String companyName,
    String? firstName,
    String? lastName,
    bool isAdmin,
    String? tradeKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('workit_workspace_id', workspaceId);
    await prefs.setString('workit_workspace_name', companyName);
    if (firstName != null) await prefs.setString('workit_user_first_name', firstName);
    if (lastName != null) await prefs.setString('workit_user_last_name', lastName);
    await prefs.setBool('workit_is_admin', isAdmin);
    if (tradeKey != null && tradeKey.isNotEmpty) {
      await prefs.setString('workit_trade_key', tradeKey);
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
        SnackBar(content: Text(e.message ?? 'Impossible d’envoyer le mail.')),
      );
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
                          onPressed: _sendReset,
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
    const accent = Color(0xFF00E676);
    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Sécuriser votre compte', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Merci de définir votre mot de passe et vos informations avant d’accéder à votre espace.',
                  style: TextStyle(color: Colors.white70, height: 1.3),
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
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _loading ? null : _save,
                    child: Text(_loading ? 'Enregistrement…' : 'Continuer'),
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
    const accent = Color(0xFF00E676);
    final roles = {
      'commercial': 'Commercial',
      'metreur': 'Métreur',
      'poseur': 'Poseur',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Rôle', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: roles.entries.map((entry) {
            final selected = _role == entry.key;
            return SizedBox(
              width: 130,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: selected ? accent : Colors.white24),
                  backgroundColor: selected ? accent.withOpacity(0.12) : const Color(0xFF0F1524),
                ),
                onPressed: () => setState(() => _role = entry.key),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: selected ? accent : Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
