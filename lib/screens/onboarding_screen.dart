// ============================================================
// lib/screens/onboarding_screen.dart
// Onboarding WorkIt — tous corps de métier du second œuvre
// ============================================================
// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../services/auth_navigation_service.dart';
import 'sign_in_screen.dart';

// ────────────────────────────────────────────────
// DONNÉES STATIQUES
// ────────────────────────────────────────────────

class _Trade {
  const _Trade({
    required this.key,
    required this.label,
    required this.sublabel,
    required this.icon,
  });
  final String key;
  final String label;
  final String sublabel;
  final IconData icon;
}

const _kTrades = [
  _Trade(key: 'menuiserie_ext',  label: 'Menuiserie ext.',  sublabel: 'Fermeture',      icon: Icons.window_outlined),
  _Trade(key: 'menuiserie_int',  label: 'Menuiserie int.',  sublabel: 'Intérieure',      icon: Icons.door_front_door_outlined),
  _Trade(key: 'plomberie',       label: 'Plomberie',        sublabel: 'Sanitaire',       icon: Icons.water_drop_outlined),
  _Trade(key: 'electricite',     label: 'Électricité',      sublabel: '',                icon: Icons.bolt_outlined),
  _Trade(key: 'peinture',        label: 'Peinture',         sublabel: 'Enduits',         icon: Icons.format_paint_outlined),
  _Trade(key: 'carrelage',       label: 'Carrelage',        sublabel: 'Sols souples',    icon: Icons.grid_on),
  _Trade(key: 'isolation',       label: 'Isolation',        sublabel: 'ITI / ITE',       icon: Icons.layers_outlined),
  _Trade(key: 'serrurerie',      label: 'Serrurerie',       sublabel: 'Métallerie',      icon: Icons.lock_outline),
  _Trade(key: 'cvc',             label: 'Climatisation',    sublabel: 'CVC / VMC',       icon: Icons.ac_unit_outlined),
  _Trade(key: 'charpente',       label: 'Charpente',        sublabel: 'Couverture',      icon: Icons.roofing_outlined),
  _Trade(key: 'vitrerie',        label: 'Vitrerie',         sublabel: 'Miroiterie',      icon: Icons.crop_square_outlined),
  _Trade(key: 'autre',           label: 'Autre',            sublabel: 'Corps de métier', icon: Icons.add),
];

class _Role {
  const _Role({
    required this.key,
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
  });
  final String key;
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
}

const _kRoles = [
  _Role(
    key: 'admin',
    label: 'Gérant / Admin',
    sublabel: 'Équipe, accès et statistiques',
    icon: Icons.admin_panel_settings_outlined,
    color: Color(0xFF6366F1),
  ),
  _Role(
    key: 'commercial',
    label: 'Commercial',
    sublabel: 'Devis, prospects et affaires',
    icon: Icons.work_outline,
    color: AppColors.primary,
  ),
  _Role(
    key: 'metreur',
    label: 'Métreur / Chargé d\'études',
    sublabel: 'Métrés, chiffrage et commandes',
    icon: Icons.straighten,
    color: AppColors.purple,
  ),
  _Role(
    key: 'poseur',
    label: 'Poseur / Technicien',
    sublabel: 'Interventions et avancement',
    icon: Icons.construction_outlined,
    color: AppColors.success,
  ),
];

class _CompanySize {
  const _CompanySize({
    required this.key,
    required this.label,
    required this.sublabel,
  });
  final String key;
  final String label;
  final String sublabel;
}

const _kSizes = [
  _CompanySize(key: 'solo', label: '1',    sublabel: 'Artisan solo'),
  _CompanySize(key: '2-5',  label: '2–5',  sublabel: 'Petite équipe'),
  _CompanySize(key: '6-20', label: '6–20', sublabel: 'Équipe moyenne'),
  _CompanySize(key: '20+',  label: '20+',  sublabel: 'Grande entreprise'),
];

class _Slide {
  const _Slide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bg,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color bg;
}

const _kSlides = [
  _Slide(
    icon: Icons.description_outlined,
    title: 'Devis pros en quelques clics',
    subtitle: 'Chiffrage adapté à votre corps de métier,\nmodèles prêts à l\'emploi.',
    bg: AppColors.primaryLight,
  ),
  _Slide(
    icon: Icons.groups_outlined,
    title: 'Coordonnez vos équipes terrain',
    subtitle: 'Commercial, métreur, poseur —\nchacun voit exactement ce qu\'il lui faut.',
    bg: AppColors.purpleLight,
  ),
  _Slide(
    icon: Icons.place_outlined,
    title: 'Chaque chantier suivi en temps réel',
    subtitle: 'Du premier contact à la pose terminée,\ntout en un seul endroit.',
    bg: AppColors.successLight,
  ),
];

// Pages internes
const int _kPageSplash    = 0;
const int _kPageSlides    = 1;
const int _kPageEntry     = 2;
const int _kPageTrades    = 3;
const int _kPageCompany   = 4;
const int _kPageRole      = 5;
const int _kPageAccount   = 6;
const int _kPageSuccess   = 7;
const int _kPageJoin      = 8;
const int _kPageJoinOk    = 9;

// ────────────────────────────────────────────────
// WIDGET PRINCIPAL
// ────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Navigation
  int _page = _kPageSplash;
  bool _forward = true; // direction de l'animation

  // Slides
  int _slideIndex = 0;
  final PageController _slideCtrl = PageController();

  // Trades
  final Set<int> _selectedTrades = {};

  // Company
  final _companyNameCtrl = TextEditingController();
  String? _selectedSize;

  // Role
  String? _selectedRole;

  // Account
  final _firstNameCtrl  = TextEditingController();
  final _lastNameCtrl   = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  bool _cguAccepted   = false;
  bool _showPassword  = false;

  // Join
  final List<TextEditingController> _codeCtrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _codeFocus =
      List.generate(6, (_) => FocusNode());

  // État
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Avancer automatiquement depuis le splash
    Future.delayed(const Duration(milliseconds: 4500), () {
      if (mounted) _goTo(_kPageSlides);
    });
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _companyNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    for (final c in _codeCtrl) c.dispose();
    for (final f in _codeFocus) f.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────

  void _goTo(int page) {
    setState(() {
      _forward = page > _page;
      _page = page;
      _errorMessage = null;
    });
  }

  // ── Validations ───────────────────────────────

  bool get _canTrades  => _selectedTrades.isNotEmpty;
  bool get _canCompany => _companyNameCtrl.text.trim().length >= 2;
  bool get _canRole    => _selectedRole != null;
  bool get _canAccount =>
      _firstNameCtrl.text.trim().isNotEmpty &&
      _lastNameCtrl.text.trim().isNotEmpty &&
      _emailCtrl.text.trim().contains('@') &&
      _passwordCtrl.text.length >= 8 &&
      _cguAccepted;

  // ── Firebase : créer compte + workspace ──────

  Future<void> _createAccount() async {
    if (!_canAccount) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      // 1. Firebase Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      final uid = cred.user!.uid;

      // 2. Workspace Firestore
      final wsRef = FirebaseFirestore.instance.collection('workspaces').doc();
      final workspaceId = wsRef.id;
      await wsRef.set({
        'companyName': _companyNameCtrl.text.trim(),
        'companySize': _selectedSize ?? 'solo',
        'trades': _selectedTrades.map((i) => _kTrades[i].key).toList(),
        'adminUid': uid,
        // 'pending' : pas encore de contrôle actif (site web + Stripe pas
        // en place) — voir AuthNavigationService._isSubscriptionAllowed.
        'subscriptionStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'members': {
          uid: {
            'role': _selectedRole,
            'firstName': _firstNameCtrl.text.trim(),
            'lastName': _lastNameCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
          },
        },
      });

      // 3. Document user
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'firstName': _firstNameCtrl.text.trim(),
        'lastName':  _lastNameCtrl.text.trim(),
        'email':     _emailCtrl.text.trim(),
        'role':      _selectedRole,
        'companyId': workspaceId,
        'workspaceId': workspaceId,
        'isAdmin': _selectedRole == 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('workit_onboarding_done', true);

      setState(() { _isLoading = false; });
      _goTo(_kPageSuccess);
    } on FirebaseAuthException catch (e) {
      String msg = 'Une erreur est survenue.';
      if (e.code == 'email-already-in-use') msg = 'Cette adresse email est déjà utilisée.';
      if (e.code == 'weak-password')        msg = 'Mot de passe trop faible (8 car. min).';
      if (e.code == 'invalid-email')        msg = 'Adresse email invalide.';
      setState(() { _isLoading = false; _errorMessage = msg; });
    } catch (e) {
      setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  // ── Navigation vers home ──────────────────────

  Future<void> _goToHome() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await AuthNavigationService().navigateUser(context, user);
  }

  // ── Build ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) {
          final offset = _forward
              ? const Offset(1, 0)
              : const Offset(-1, 0);
          return SlideTransition(
            position: Tween<Offset>(begin: offset, end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: FadeTransition(opacity: anim, child: child),
          );
        },
        child: _buildPage(),
      ),
    );
  }

  Widget _buildPage() {
    switch (_page) {
      case _kPageSplash:   return _buildSplash();
      case _kPageSlides:   return _buildSlides();
      case _kPageEntry:    return _buildEntry();
      case _kPageTrades:   return _buildTrades();
      case _kPageCompany:  return _buildCompany();
      case _kPageRole:     return _buildRole();
      case _kPageAccount:  return _buildAccount();
      case _kPageSuccess:  return _buildSuccess();
      case _kPageJoin:     return _buildJoin();
      case _kPageJoinOk:   return _buildJoinSuccess();
      default:             return _buildSplash();
    }
  }

  // ═══════════════════════════════════════════════
  // PAGE 0 — SPLASH
  // ═══════════════════════════════════════════════
  Widget _buildSplash() {
    return Scaffold(
      key: const ValueKey(_kPageSplash),
      backgroundColor: AppColors.primary,
      body: SizedBox.expand(
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white30),
                ),
                child: const Icon(Icons.factory_outlined, size: 42, color: Colors.white),
              ),
              const SizedBox(height: 22),
              const Text(
                'WorkIt',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Gérez vos chantiers\ndu devis à la pose',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
              ),
              const Spacer(),
              const _PulsingDots(),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // PAGE 1 — SLIDES VALEUR
  // ═══════════════════════════════════════════════
  Widget _buildSlides() {
    return Scaffold(
      key: const ValueKey(_kPageSlides),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 16, 0),
                child: TextButton(
                  onPressed: () => _goTo(_kPageEntry),
                  child: const Text('Passer', style: TextStyle(color: AppColors.grey400)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _slideCtrl,
                itemCount: _kSlides.length,
                onPageChanged: (i) => setState(() => _slideIndex = i),
                itemBuilder: (_, i) {
                  final s = _kSlides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: s.bg,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Icon(s.icon, size: 56, color: AppColors.primary),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.grey900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.grey400,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_kSlides.length, (i) {
                      final active = i == _slideIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 22 : 8,
                        height: 4,
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : AppColors.grey200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  _PrimaryButton(
                    label: _slideIndex == _kSlides.length - 1
                        ? 'Commencer'
                        : 'Suivant',
                    onTap: () {
                      if (_slideIndex < _kSlides.length - 1) {
                        _slideCtrl.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _goTo(_kPageEntry);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // PAGE 2 — CHOIX D'ENTRÉE
  // ═══════════════════════════════════════════════
  Widget _buildEntry() {
    return Scaffold(
      key: const ValueKey(_kPageEntry),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 32, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenue 👋',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.grey900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Comment souhaitez-vous démarrer ?',
                    style: TextStyle(fontSize: 15, color: AppColors.grey400),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _EntryCard(
                    icon: Icons.business_center_outlined,
                    iconBg: AppColors.primaryLight,
                    iconColor: AppColors.primary,
                    title: 'Créer mon espace entreprise',
                    subtitle: 'Je configure WorkIt pour mon équipe\net mes chantiers.',
                    onTap: () => _goTo(_kPageTrades),
                  ),
                  const SizedBox(height: 12),
                  _EntryCard(
                    icon: Icons.group_add_outlined,
                    iconBg: AppColors.purpleLight,
                    iconColor: AppColors.purple,
                    title: 'Rejoindre une équipe',
                    subtitle: 'Mon responsable m\'a invité avec\nun code ou un lien.',
                    onTap: () => _goTo(_kPageJoin),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                  );
                },
                child: const Text(
                  'J\'ai déjà un compte — Se connecter',
                  style: TextStyle(color: AppColors.primary, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // PAGE 3 — CORPS DE MÉTIER
  // ═══════════════════════════════════════════════
  Widget _buildTrades() {
    return Scaffold(
      key: const ValueKey(_kPageTrades),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: () => _goTo(_kPageEntry), step: 0, totalSteps: 4),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ScreenHeading(
                      title: 'Votre activité ⚙️',
                      subtitle: 'Sélectionnez votre ou vos corps de métier.\nModifiable à tout moment dans les réglages.',
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _kTrades.length,
                      itemBuilder: (_, i) {
                        final selected = _selectedTrades.contains(i);
                        return GestureDetector(
                          onTap: () => setState(() {
                            selected
                                ? _selectedTrades.remove(i)
                                : _selectedTrades.add(i);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primaryLight
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.grey200,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _kTrades[i].icon,
                                          size: 26,
                                          color: selected
                                              ? AppColors.primary
                                              : AppColors.grey400,
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          _kTrades[i].label,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: selected
                                                ? AppColors.primary
                                                : AppColors.grey600,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        if (_kTrades[i].sublabel.isNotEmpty)
                                          Text(
                                            _kTrades[i].sublabel,
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: selected
                                                  ? AppColors.primary
                                                      .withOpacity(0.7)
                                                  : AppColors.grey400,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (selected)
                                  Positioned(
                                    top: 5,
                                    right: 5,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        size: 9,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            _BottomBar(
              tags: _selectedTrades.map((i) => _kTrades[i].label).toList(),
              child: _PrimaryButton(
                label: 'Continuer',
                onTap: _canTrades ? () => _goTo(_kPageCompany) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // PAGE 4 — INFOS ENTREPRISE
  // ═══════════════════════════════════════════════
  Widget _buildCompany() {
    return Scaffold(
      key: const ValueKey(_kPageCompany),
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: () => _goTo(_kPageTrades), step: 1, totalSteps: 4),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ScreenHeading(
                      title: 'Votre entreprise 🏢',
                      subtitle: 'Ces informations apparaîtront\nsur vos devis et documents.',
                    ),
                    _OnbField(
                      label: 'Nom de l\'entreprise *',
                      controller: _companyNameCtrl,
                      hint: 'Ex : Plomberie Dupont & Fils',
                      onChanged: (_) => setState(() {}),
                    ),
                    _OnbField(
                      label: 'SIRET (optionnel)',
                      hint: '000 000 000 00000',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Taille de l\'équipe',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.2,
                      children: _kSizes.map((sz) {
                        final sel = _selectedSize == sz.key;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedSize = sz.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.primaryLight
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: sel
                                    ? AppColors.primary
                                    : AppColors.grey200,
                                width: sel ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  sz.label,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: sel
                                        ? AppColors.primary
                                        : AppColors.grey900,
                                  ),
                                ),
                                Text(
                                  sz.sublabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: sel
                                        ? AppColors.primary.withOpacity(0.7)
                                        : AppColors.grey400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Modifiable dans les réglages.',
                      style: TextStyle(fontSize: 11, color: AppColors.grey300),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _PrimaryButton(
                label: 'Continuer',
                onTap: _canCompany ? () => _goTo(_kPageRole) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // PAGE 5 — RÔLE
  // ═══════════════════════════════════════════════
  Widget _buildRole() {
    return Scaffold(
      key: const ValueKey(_kPageRole),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: () => _goTo(_kPageCompany), step: 2, totalSteps: 4),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ScreenHeading(
                      title: 'Votre rôle 🎯',
                      subtitle: 'L\'interface WorkIt s\'adapte\nentièrement à votre rôle.',
                    ),
                    ..._kRoles.map((role) {
                      final sel = _selectedRole == role.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedRole = role.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: sel
                                  ? role.color.withOpacity(0.08)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: sel ? role.color : AppColors.grey200,
                                width: sel ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: role.color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(role.icon,
                                      color: role.color, size: 22),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        role.label,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.grey900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        role.sublabel,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.grey400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: sel ? role.color : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: sel
                                          ? role.color
                                          : AppColors.grey200,
                                    ),
                                  ),
                                  child: sel
                                      ? const Icon(Icons.check,
                                          size: 12, color: Colors.white)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _PrimaryButton(
                label: 'Continuer',
                onTap: _canRole ? () => _goTo(_kPageAccount) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // PAGE 6 — CRÉATION DE COMPTE
  // ═══════════════════════════════════════════════
  Widget _buildAccount() {
    return Scaffold(
      key: const ValueKey(_kPageAccount),
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: () => _goTo(_kPageRole), step: 3, totalSteps: 4),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ScreenHeading(
                      title: 'Créer mon compte 🔐',
                      subtitle: 'Dernière étape — vous y êtes presque.',
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _OnbField(
                            label: 'Prénom',
                            controller: _firstNameCtrl,
                            hint: 'Yann',
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OnbField(
                            label: 'Nom',
                            controller: _lastNameCtrl,
                            hint: 'Martin',
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    _OnbField(
                      label: 'Email professionnel',
                      controller: _emailCtrl,
                      hint: 'yann@monentreprise.fr',
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                    ),
                    _OnbField(
                      label: 'Mot de passe',
                      controller: _passwordCtrl,
                      hint: '8 caractères minimum',
                      obscure: !_showPassword,
                      onChanged: (_) => setState(() {}),
                      suffix: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: AppColors.grey400,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _cguAccepted = !_cguAccepted),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(
                              color: _cguAccepted
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: _cguAccepted
                                    ? AppColors.primary
                                    : AppColors.grey300,
                              ),
                            ),
                            child: _cguAccepted
                                ? const Icon(Icons.check,
                                    size: 11, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.grey400,
                                  height: 1.5,
                                ),
                                children: [
                                  TextSpan(text: 'J\'accepte les '),
                                  TextSpan(
                                    text: 'Conditions d\'utilisation',
                                    style:
                                        TextStyle(color: AppColors.primary),
                                  ),
                                  TextSpan(text: ' et la '),
                                  TextSpan(
                                    text: 'Politique de confidentialité',
                                    style:
                                        TextStyle(color: AppColors.primary),
                                  ),
                                  TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _PrimaryButton(
                      label: 'Créer mon espace WorkIt',
                      onTap: _canAccount ? _createAccount : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // PAGE 7 — SUCCÈS
  // ═══════════════════════════════════════════════
  Widget _buildSuccess() {
    final tradeKeys = _selectedTrades.toList();
    final tradeLabel = tradeKeys.isEmpty
        ? '—'
        : tradeKeys.length <= 2
            ? tradeKeys.map((i) => _kTrades[i].label).join(', ')
            : '${_kTrades[tradeKeys[0]].label}, ${_kTrades[tradeKeys[1]].label} +${tradeKeys.length - 2}';
    final roleLabel = _kRoles
        .firstWhere(
          (r) => r.key == _selectedRole,
          orElse: () => _kRoles[0],
        )
        .label;

    return Scaffold(
      key: const ValueKey(_kPageSuccess),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: AppColors.success, size: 42),
            ),
            const SizedBox(height: 22),
            const Text(
              'Votre espace est prêt !',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.grey900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'WorkIt est configuré.\nBienvenue dans l\'équipe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.grey400,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 26),
            // Récap
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.grey100),
              ),
              child: Column(
                children: [
                  _RecapRow(
                    label: 'Entreprise',
                    value: _companyNameCtrl.text.trim(),
                  ),
                  _RecapRow(
                    label: 'Corps de métier',
                    value: tradeLabel,
                  ),
                  _RecapRow(
                    label: 'Votre rôle',
                    value: roleLabel,
                    isLast: true,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: ouvrir partage d'invitation
                },
                icon: const Icon(Icons.email_outlined, size: 18),
                label: const Text('Inviter mon équipe'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: AppColors.grey200),
                  foregroundColor: AppColors.grey700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _PrimaryButton(
                label: 'Commencer',
                onTap: _goToHome,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // PAGE 8 — REJOINDRE UNE ÉQUIPE
  // ═══════════════════════════════════════════════
  Widget _buildJoin() {
    return Scaffold(
      key: const ValueKey(_kPageJoin),
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: () => _goTo(_kPageEntry), step: -1, totalSteps: 0),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ScreenHeading(
                      title: 'Code d\'invitation 🔗',
                      subtitle: 'Saisissez le code reçu de votre responsable\nou dans l\'email d\'invitation.',
                    ),
                    // 6 champs code
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (i) {
                        return Container(
                          width: 46,
                          height: 56,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          child: TextField(
                            controller: _codeCtrl[i],
                            focusNode: _codeFocus[i],
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.grey900,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: AppColors.grey200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            onChanged: (v) {
                              if (v.isNotEmpty && i < 5) {
                                _codeFocus[i + 1].requestFocus();
                              }
                              if (v.isEmpty && i > 0) {
                                _codeFocus[i - 1].requestFocus();
                              }
                            },
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 22),
                    Row(children: [
                      Expanded(child: Divider(color: AppColors.grey200)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'ou',
                          style: TextStyle(color: AppColors.grey300, fontSize: 12),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.grey200)),
                    ]),
                    const SizedBox(height: 18),
                    _OnbField(
                      label: 'Email avec lequel vous avez été invité',
                      hint: 'votre@email.fr',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.grey50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.grey100),
                      ),
                      child: const Text(
                        '💡 Pas encore invité ? Demandez à votre responsable de vous envoyer une invitation depuis son espace Admin WorkIt.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.grey400,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _PrimaryButton(
                label: 'Rejoindre l\'équipe',
                onTap: () => _goTo(_kPageJoinOk),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // PAGE 9 — JOIN SUCCESS
  // ═══════════════════════════════════════════════
  Widget _buildJoinSuccess() {
    return Scaffold(
      key: const ValueKey(_kPageJoinOk),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppColors.purpleLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group_outlined,
                  color: AppColors.purple, size: 42),
            ),
            const SizedBox(height: 22),
            const Text(
              'Bienvenue dans l\'équipe !',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.grey900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Votre compte est lié à l\'espace\nde votre entreprise.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.grey400),
            ),
            const SizedBox(height: 26),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.grey100),
              ),
              child: const Column(
                children: [
                  _RecapRow(label: 'Espace', value: '—'),
                  _RecapRow(label: 'Rôle assigné', value: '—'),
                  _RecapRow(
                    label: 'Accès',
                    value: 'En attente',
                    isLast: true,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _PrimaryButton(
                label: 'Accéder à mon espace',
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────
// WIDGETS PARTAGÉS
// ────────────────────────────────────────────────

/// Points animés sur le splash
class _PulsingDots extends StatefulWidget {
  const _PulsingDots();
  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_ctrl.value - i * 0.18).remainder(1.0);
            final t = (phase < 0 ? phase + 1 : phase);
            final opacity = 0.3 + 0.7 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
            return Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

/// Barre de navigation en haut (retour + steps)
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onBack,
    required this.step,
    required this.totalSteps,
  });
  final VoidCallback onBack;
  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 18, color: AppColors.grey600),
            ),
          ),
          const Spacer(),
          if (totalSteps > 0)
            Row(
              children: List.generate(totalSteps, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: i == step ? 20 : 6,
                  height: 3,
                  decoration: BoxDecoration(
                    color: i <= step ? AppColors.primary : AppColors.grey200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          const Spacer(),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

/// Titre + sous-titre de chaque écran
class _ScreenHeading extends StatelessWidget {
  const _ScreenHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.grey900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.grey400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Champ de formulaire générique
class _OnbField extends StatelessWidget {
  const _OnbField({
    required this.label,
    this.controller,
    required this.hint,
    this.keyboardType,
    this.obscure = false,
    this.onChanged,
    this.suffix,
  });
  final String label;
  final TextEditingController? controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final void Function(String)? onChanged;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.grey600,
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscure,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 14, color: AppColors.grey900),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.grey300),
              filled: true,
              fillColor: AppColors.surface,
              suffixIcon: suffix,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.grey200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton principal bleu
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.grey200,
          disabledForegroundColor: AppColors.grey400,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Carte de choix d'entrée (créer / rejoindre)
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.grey200),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.grey900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.grey400,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.grey300, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Barre du bas avec tags sélectionnés + bouton
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child, this.tags = const []});
  final Widget child;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.grey100)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tags.isNotEmpty) ...[
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

/// Ligne de récap (success screen)
class _RecapRow extends StatelessWidget {
  const _RecapRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.grey400),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.grey900,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 0, color: AppColors.grey100),
      ],
    );
  }
}
