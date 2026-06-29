import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service WorkIt — Gestion des devis avec logique cross-rôle
///
/// Quand le Commercial crée un devis :
///   1. Écrit dans  workspaces/{id}/devis/{devisId}
///   2. Crée une notification pour le Metteur dans workspaces/{id}/notifications
///   3. Le StreamBuilder du Metteur réagit automatiquement (temps réel Firestore)
///
/// Toute transition de statut passe par [updateStatus] qui :
///   - Met à jour le document devis
///   - Crée la notification destinataire appropriée
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

    // 1. Écriture du devis
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

    // 2. Notification Metteur
    await _notify(
      workspaceId: workspaceId,
      devisId: ref.id,
      targetRole: 'metreur',
      type: 'new_devis',
      title: 'Nouveau devis',
      body: '${data['clientName'] ?? 'Client'} — action requise',
    );

    return ref.id;
  }

  // ─────────────────────────────────────────────────────────────
  // Mettre à jour le statut (toute transition)
  // ─────────────────────────────────────────────────────────────
  static Future<void> updateStatus({
    required String workspaceId,
    required String devisId,
    required String newStatus,
    Map<String, dynamic> extraFields = const {},
  }) async {
    final now = FieldValue.serverTimestamp();

    // 1. Mise à jour Firestore
    await _db
        .collection('workspaces')
        .doc(workspaceId)
        .collection('devis')
        .doc(devisId)
        .update({
      'status': newStatus,
      'updatedAt': now,
      ...extraFields,
    });

    // 2. Notification selon la transition
    final notif = _notifForTransition(newStatus);
    if (notif != null) {
      await _notify(
        workspaceId: workspaceId,
        devisId: devisId,
        targetRole: notif.targetRole,
        type: notif.type,
        title: notif.title,
        body: notif.body,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Transitions → notifications
  // ─────────────────────────────────────────────────────────────
  static _NotifSpec? _notifForTransition(String status) {
    switch (status) {
      case 'En cours':
        return const _NotifSpec(
          targetRole: 'commercial',
          type: 'devis_accepted',
          title: 'Devis accepté',
          body: 'Métré programmé par le metteur',
        );
      case 'Commande en cours':
        return const _NotifSpec(
          targetRole: 'admin',
          type: 'order_placed',
          title: 'Commande passée',
          body: 'Matériaux commandés — suivi en cours',
        );
      case 'À planifier':
        return const _NotifSpec(
          targetRole: 'poseur',
          type: 'site_scheduled',
          title: 'Chantier à venir',
          body: 'Votre intervention a été planifiée',
        );
      case 'En pose':
        return const _NotifSpec(
          targetRole: 'commercial',
          type: 'site_started',
          title: 'Pose démarrée',
          body: "L'équipe est sur place",
        );
      case 'À clôturer':
        return const _NotifSpec(
          targetRole: 'metreur',
          type: 'site_done',
          title: 'Chantier terminé',
          body: 'Validation de clôture requise',
        );
      case 'Problème chantier':
        return const _NotifSpec(
          targetRole: 'metreur',
          type: 'site_problem',
          title: '⚠️ Problème chantier',
          body: 'Intervention requise — voir photos',
        );
      default:
        return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Écriture notification dans Firestore
  // Les écrans écoutent workspaces/{id}/notifications
  // filtré par targetRole + read == false
  // ─────────────────────────────────────────────────────────────
  static Future<void> _notify({
    required String workspaceId,
    required String devisId,
    required String targetRole,
    required String type,
    required String title,
    required String body,
  }) async {
    await _db
        .collection('workspaces')
        .doc(workspaceId)
        .collection('notifications')
        .add({
      'devisId': devisId,
      'targetRole': targetRole,
      'type': type,
      'title': title,
      'body': body,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
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

class _NotifSpec {
  final String targetRole;
  final String type;
  final String title;
  final String body;
  const _NotifSpec({
    required this.targetRole,
    required this.type,
    required this.title,
    required this.body,
  });
}
