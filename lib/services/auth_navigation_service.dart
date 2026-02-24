import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/commercial_home_screen.dart';
import '../screens/metreur_home_screen.dart';
import '../screens/poseurs_home_screen.dart';
import '../screens/sign_in_screen.dart'; // For CompleteProfileScreen if needed, or better to move it

class AuthNavigationService {
  static final AuthNavigationService _instance = AuthNavigationService._internal();

  factory AuthNavigationService() {
    return _instance;
  }

  AuthNavigationService._internal();

  Future<void> navigateUser(BuildContext context, User user) async {
    final uid = user.uid;

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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Espace introuvable pour cet utilisateur.'),
          ),
        );
      }
      return;
    }

    final usesApp = data['creatorUsesWorkit'] == true;
    isAdmin = isAdmin || (data['adminUid']?.toString() == uid);
    roleKey ??= data['role']?.toString();

    final mustChangePassword = userData?['mustChangePassword'] == true;

    if (mustChangePassword) {
      if (context.mounted) {
        final completed = await Navigator.of(context).push<Map<String, dynamic>?>(
          MaterialPageRoute(
            builder: (_) => CompleteProfileScreen(
              email: user.email ?? '',
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
    }

    if (!usesApp && roleKey == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accès admin uniquement, aucun rôle défini.'),
          ),
        );
      }
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rôle non supporté ($roleKey).')),
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
}
