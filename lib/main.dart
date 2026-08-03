import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/entry_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/auth_navigation_service.dart';

/// Clé de navigation globale : permet de naviguer depuis les callbacks FCM,
/// qui s'exécutent en dehors de l'arbre de widgets.
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // App Check — providers .debug pour l'instant (fonctionnent sans
  // configuration externe). Aucune Cloud Function n'impose encore
  // enforceAppCheck, donc rien n'est bloqué : cette activation sert juste
  // à préparer/observer, en attendant l'enregistrement des vrais providers
  // (reCAPTCHA v3 web, Play Integrity Android, DeviceCheck/App Attest iOS)
  // dans les consoles respectives — voir _claude_sessions/session_courante.md.
  // Best-effort : ne doit jamais empêcher l'app de démarrer.
  try {
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider('debug'),
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  } catch (_) {
    // Ignoré : App Check est une couche de sécurité additive, jamais
    // bloquante pour le démarrage de l'app.
  }

  await FirebaseMessaging.instance.requestPermission();

  // Notification reçue app au premier plan : pas de notif système par défaut,
  // on affiche donc un bandeau in-app, tapable comme une vraie notif.
  FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

  // Notification tapée depuis l'arrière-plan (app pas fermée).
  FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

  runApp(const WorkItApp());

  // Notification tapée alors que l'app était fermée (cold start).
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    // Laisser le premier frame se construire avant de naviguer.
    await Future.delayed(Duration.zero);
    _handleNotificationTap(initialMessage);
  }
}

void _handleForegroundMessage(RemoteMessage message) {
  final context = navigatorKey.currentContext;
  final notification = message.notification;
  if (context == null || notification == null) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.title ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
          if (notification.body != null) Text(notification.body!),
        ],
      ),
      action: SnackBarAction(
        label: 'Ouvrir',
        onPressed: () => _handleNotificationTap(message),
      ),
    ),
  );
}

Future<void> _handleNotificationTap(RemoteMessage message) async {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  final prefs = await SharedPreferences.getInstance();
  final role = prefs.getString('workit_user_role');
  if (role == null) return;

  final home = AuthNavigationService().homeForRole(role);
  if (home == null || !context.mounted) return;

  navigatorKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => home),
    (route) => false,
  );
}

class WorkItApp extends StatelessWidget {
  const WorkItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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
      // Premier lancement : afficher l'onboarding
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
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
