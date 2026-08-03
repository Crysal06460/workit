import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/admin_home_screen.dart';
import '../screens/commercial_home_screen.dart';
import '../screens/metreur_home_screen.dart';
import '../screens/poseurs_home_screen.dart';
import '../screens/sign_in_screen.dart';

class AuthNavigationService {
  static final AuthNavigationService _instance = AuthNavigationService._internal();

  factory AuthNavigationService() {
    return _instance;
  }

  AuthNavigationService._internal();

  Future<void> navigateUser(BuildContext context, User user) async {
    final uid = user.uid;
    final firestore = FirebaseFirestore.instance;

    // 1. Lire le document user par ID direct (pas de query — règles Firestore)
    final userDoc = await firestore.collection('users').doc(uid).get();
    final userData = userDoc.data();

    if (userData == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte introuvable. Contactez votre administrateur.')),
        );
      }
      return;
    }

    // 2. Récupérer le workspaceId depuis le document user
    final workspaceId = (userData['workspaceId'] ?? userData['companyId'])?.toString();
    if (workspaceId == null || workspaceId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Espace de travail introuvable pour ce compte.')),
        );
      }
      return;
    }

    // 3. Lire le workspace par ID direct
    final workspaceDoc = await firestore.collection('workspaces').doc(workspaceId).get();
    final workspaceData = workspaceDoc.data();

    if (workspaceData == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Espace de travail supprimé ou inaccessible.')),
        );
      }
      return;
    }

    // 4. Déterminer le rôle
    final roleKey = userData['role']?.toString() ?? 'commercial';
    final isAdmin = roleKey == 'admin';

    // 4bis. Point d'accroche pour le futur blocage "abonnement requis"
    // (site web + Stripe pas encore en place). Toujours permissif pour
    // l'instant — aucun workspace n'est bloqué tant que ce n'est pas
    // branché à un vrai contrôle Stripe côté site.
    final subscriptionStatus = workspaceData['subscriptionStatus']?.toString();
    if (!_isSubscriptionAllowed(subscriptionStatus)) {
      return;
    }

    // 5. Changement de mot de passe obligatoire (comptes provisionnés)
    final mustChangePassword = userData['mustChangePassword'] == true;
    String effectiveRole = roleKey;

    if (mustChangePassword && context.mounted) {
      final completed = await Navigator.of(context).push<Map<String, dynamic>?>(
        MaterialPageRoute(
          builder: (_) => CompleteProfileScreen(
            email: user.email ?? '',
            currentRole: roleKey,
            userDoc: userData,
          ),
        ),
      );
      if (completed == null) return;
      effectiveRole = completed['role']?.toString() ?? roleKey;
    }

    // 6. Persister le contexte workspace dans SharedPreferences
    final tradeKey = (userData['tradeKey'] ?? workspaceData['tradeKey'])?.toString();
    await _persistWorkspaceContext(
      workspaceId,
      workspaceData['companyName']?.toString() ?? '',
      userData['firstName']?.toString() ?? workspaceData['creatorFirstName']?.toString(),
      userData['lastName']?.toString() ?? workspaceData['creatorLastName']?.toString(),
      isAdmin,
      tradeKey,
      effectiveRole,
    );

    // 7. Sauvegarder le token FCM
    await _saveFcmToken(uid, workspaceId);

    // 8. Naviguer vers le bon écran
    final home = homeForRole(effectiveRole);
    if (home == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rôle non supporté ($effectiveRole).')),
        );
      }
      return;
    }

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => home),
        (route) => false,
      );
    }
  }

  /// Toujours `true` pour l'instant : le site web + Stripe n'existent pas
  /// encore, donc aucun workspace n'est bloqué quel que soit son
  /// `subscriptionStatus`. À brancher sur un vrai contrôle le jour où
  /// l'abonnement se fait sur le site (rediriger vers un écran dédié au
  /// lieu de retourner `false` silencieusement).
  bool _isSubscriptionAllowed(String? subscriptionStatus) => true;

  Future<void> _saveFcmToken(String uid, String workspaceId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'fcmToken': token,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Silently ignore FCM token save errors
    }
  }

  Future<void> _persistWorkspaceContext(
    String workspaceId,
    String companyName,
    String? firstName,
    String? lastName,
    bool isAdmin,
    String? tradeKey,
    String roleKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('workit_workspace_id', workspaceId);
    await prefs.setString('workit_workspace_name', companyName);
    if (firstName != null) await prefs.setString('workit_user_first_name', firstName);
    if (lastName != null) await prefs.setString('workit_user_last_name', lastName);
    await prefs.setBool('workit_is_admin', isAdmin);
    await prefs.setString('workit_user_role', roleKey);
    if (tradeKey != null && tradeKey.isNotEmpty) {
      await prefs.setString('workit_trade_key', tradeKey);
    }
  }

  /// Retourne l'écran d'accueil correspondant à un rôle (`workit_user_role`).
  /// Utilisé aussi pour router depuis une notification (voir `main.dart`).
  Widget? homeForRole(String roleKey) {
    switch (roleKey) {
      case 'commercial':
        return const CommercialHomeScreen();
      case 'metreur':
        return const MetreurHomeScreen();
      case 'poseur':
        return const PoseursHomeScreen();
      case 'commercial_metreur':
        return const CommercialHomeScreen();
      case 'admin':
        return const AdminHomeScreen();
      default:
        return null;
    }
  }
}
