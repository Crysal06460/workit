import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/entry_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_navigation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseMessaging.instance.requestPermission();

  // Activer le cache Firestore hors ligne
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  runApp(const WorkItApp());
}

class WorkItApp extends StatelessWidget {
  const WorkItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkIt',
      theme: AppTheme.light,
      home: const _StartupRouter(),
    );
  }
}

/// Détermine l'écran de démarrage :
///   • Utilisateur déjà connecté → redirige vers home (AuthNavigationService)
///   • Onboarding pas encore fait → OnboardingScreen
///   • Onboarding déjà fait → EntryScreen (écran de connexion classique)
class _StartupRouter extends StatefulWidget {
  const _StartupRouter();
  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    // Laisser le premier frame se construire avant de naviguer
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    // 1. Utilisateur Firebase déjà authentifié
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await AuthNavigationService().navigateUser(context, user);
      return;
    }

    // 2. Pas connecté → vérifier si l'onboarding a déjà été fait
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('workit_onboarding_done') ?? false;

    if (!mounted) return;
    if (!onboardingDone) {
      // Premier lancement : afficher l'accueil
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
    // Onboarding déjà fait → rester sur EntryScreen (Se connecter)
  }

  @override
  Widget build(BuildContext context) {
    // Affiché brièvement pendant la vérification async
    return const EntryScreen();
  }
}
