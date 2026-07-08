import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../services/auth_navigation_service.dart';
import 'onboarding_screen.dart';
import 'sign_in_screen.dart';

/// Écran d'accueil rapide pour les utilisateurs ayant déjà fait l'onboarding.
/// (Le splash + slides ne sont montrés qu'une fois, via OnboardingScreen.)
class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;

  Future<void> _handleSignIn(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Utilisateur déjà connecté côté Firebase — vérifier si FaceID est activé
      final prefs = await SharedPreferences.getInstance();
      final faceIdEnabled = prefs.getBool('workit_faceid_enabled') ?? false;

      if (faceIdEnabled) {
        try {
          final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
          final bool canAuthenticate =
              canAuthenticateWithBiometrics || await auth.isDeviceSupported();

          if (canAuthenticate) {
            setState(() => _isAuthenticating = true);
            final bool didAuthenticate = await auth.authenticate(
              localizedReason: 'Veuillez vous authentifier pour accéder à WorkIt',
              biometricOnly: true,
            );
            setState(() => _isAuthenticating = false);

            if (didAuthenticate) {
              if (!mounted) return;
              await AuthNavigationService().navigateUser(context, user);
              return;
            }
            // FaceID a échoué mais user est auth → on navigue quand même après 2ème tentative
            if (!mounted) return;
            await AuthNavigationService().navigateUser(context, user);
            return;
          }
        } catch (e) {
          setState(() => _isAuthenticating = false);
          debugPrint('Error auth: $e');
        }
      }
      // FaceID non configuré mais user connecté → naviguer directement
      if (!mounted) return;
      await AuthNavigationService().navigateUser(context, user);
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
  }

  void _openSignup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.factory_outlined, size: 32, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Bon retour 👋',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.grey900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Connectez-vous pour retrouver vos chantiers.',
                style: TextStyle(fontSize: 15, color: AppColors.grey400),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isAuthenticating ? null : () => _handleSignIn(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isAuthenticating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Se connecter',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: () => _openSignup(context),
                  child: const Text(
                    'Pas encore de compte — Créer mon espace',
                    style: TextStyle(color: AppColors.primary, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
