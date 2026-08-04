import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service WorkIt — Gestion des devis avec logique cross-rôle
///
/// Quand le Commercial crée un devis :
///   1. Écrit dans  workspaces/{id}/devis/{devisId}
///   2. Crée une notification pour le Metteur dans workspaces/{id}/notifications
///   3. Le StreamBuilder du Metteur réagit automatiquement (temps réel Firestore)
///
/// Toute transition de statut passe par [updateStatus], qui appelle la Cloud
/// Function callable `transitionDevisStatus` — celle-ci vérifie les droits
/// (rôle, appartenance workspace, assignation poseur), valide les champs
/// additionnels autorisés, écrit le statut + l'historique immuable
/// (statusHistory) de façon atomique, puis envoie les notifications
/// (in-app + push). Plus aucune écriture directe du statut depuis le client.
class DevisService {
  static final _db   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ─────────────────────────────────────────────────────────────
  // Créer un devis (Commercial → Metteur notifié)
  // ─────────────────────────────────────────────────────────────
  static Future<String> createDevis({
    required String workspaceId,
    required Map<String, dynamic> data,
  }) async {
    final user = _auth.currentUser;
    final now  = FieldValue.serverTimestamp();

    final ref = await _db
        .collection('workspaces')
        .doc(workspaceId)
        .collection('devis')
        .add({
      ...data,
      'status': 'Nouvelle demande',
      'createdAt': now,
      'createdBy': user?.uid,
      'createdByRole': 'commercial',
    });

    return ref.id;
  }

  // ─────────────────────────────────────────────────────────────
  // Mettre à jour le statut (toute transition)
  // Appelle la Cloud Function transitionDevisStatus — voir
  // functions/devisWorkflow.js pour la table des transitions autorisées.
  // ─────────────────────────────────────────────────────────────
  static Future<void> updateStatus({
    required String workspaceId,
    required String devisId,
    required String newStatus,
    Map<String, dynamic> extraFields = const {},
    String? comment,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('transitionDevisStatus');
    await callable.call(<String, dynamic>{
      'workspaceId': workspaceId,
      'devisId': devisId,
      'newStatus': newStatus,
      'extraFields': extraFields,
      if (comment != null) 'comment': comment,
    });
  }

  // ─────────────────────────────────────────────────────────────
  // Stream notifications non lues pour un rôle (badge bottom nav)
  // ─────────────────────────────────────────────────────────────
  static Stream<int> unreadCount({
    required String workspaceId,
    required String role,
  }) {
    return _db
        .collection('workspaces')
        .doc(workspaceId)
        .collection('notifications')
        .where('targetRole', isEqualTo: role)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ─────────────────────────────────────────────────────────────
  // Marquer une notification comme lue
  // ─────────────────────────────────────────────────────────────
  static Future<void> markRead({
    required String workspaceId,
    required String notificationId,
  }) async {
    await _db
        .collection('workspaces')
        .doc(workspaceId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }
}
