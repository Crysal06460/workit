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
  //
  // [lotId] (Phase 3, multi-lots) : quand fourni, la transition porte sur
  // ce lot (workspaces/{id}/devis/{devisId}/lots/{lotId}) plutôt que sur le
  // devis entier. Une fois qu'un devis a des lots (après son métré), toute
  // transition ultérieure DOIT fournir lotId — voir le commentaire sur
  // transitionDevisStatus côté Cloud Function pour le détail.
  // ─────────────────────────────────────────────────────────────
  static Future<void> updateStatus({
    required String workspaceId,
    required String devisId,
    required String newStatus,
    Map<String, dynamic> extraFields = const {},
    String? comment,
    String? lotId,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('transitionDevisStatus');
    await callable.call(<String, dynamic>{
      'workspaceId': workspaceId,
      'devisId': devisId,
      'newStatus': newStatus,
      'extraFields': extraFields,
      if (comment != null) 'comment': comment,
      if (lotId != null) 'lotId': lotId,
    });
  }

  // ─────────────────────────────────────────────────────────────
  // Déclarer les dépendances d'un lot envers d'autres lots du même chantier
  // (Phase 3, multi-lots). Appelle la Cloud Function callable
  // setLotDependencies (valide que les IDs sont bien des lots de ce
  // chantier et détecte les cycles côté serveur).
  // ─────────────────────────────────────────────────────────────
  static Future<void> setLotDependencies({
    required String workspaceId,
    required String devisId,
    required String lotId,
    required List<String> dependsOn,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('setLotDependencies');
    await callable.call(<String, dynamic>{
      'workspaceId': workspaceId,
      'devisId': devisId,
      'lotId': lotId,
      'dependsOn': dependsOn,
    });
  }

  // ─────────────────────────────────────────────────────────────
  // Met à jour les champs de planification d'un lot (durée estimée,
  // poseurs requis, matériel requis) — Phase 4, Planner v2. Champs de
  // planification, pas une transition de statut, donc pas via updateStatus.
  // Appelle la Cloud Function callable updateLotPlanningFields (lots en
  // écriture serveur uniquement côté règles Firestore).
  // ─────────────────────────────────────────────────────────────
  static Future<void> updateLotPlanningFields({
    required String workspaceId,
    required String devisId,
    required String lotId,
    int? estimatedDurationDays,
    int? poseurCountRequired,
    String? materielRequis,
    // Tableau complet des jours déjà planifiés, un seul élément modifié —
    // utilisé pour déplacer un jour isolé d'un chantier étalé sur plusieurs
    // jours sans toucher aux autres. Chaque DateTime doit être en UTC (voir
    // planner_screen.dart pour le pourquoi du .toUtc() avant l'appel).
    List<DateTime>? scheduledDates,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('updateLotPlanningFields');
    await callable.call(<String, dynamic>{
      'workspaceId': workspaceId,
      'devisId': devisId,
      'lotId': lotId,
      if (estimatedDurationDays != null)
        'estimatedDurationDays': estimatedDurationDays,
      if (poseurCountRequired != null)
        'poseurCountRequired': poseurCountRequired,
      if (materielRequis != null) 'materielRequis': materielRequis,
      if (scheduledDates != null)
        'scheduledDates': scheduledDates.map((d) => d.toIso8601String()).toList(),
    });
  }

  // ─────────────────────────────────────────────────────────────
  // Enregistre un événement de pointage (Phase 5, temps passé) : départ
  // dépôt, arrivée chantier, début intervention, pause, reprise, fin.
  // Appelle la Cloud Function callable logTimeEntry (timeEntries en
  // écriture serveur uniquement côté règles Firestore).
  // ─────────────────────────────────────────────────────────────
  static Future<void> logTimeEntry({
    required String workspaceId,
    required String devisId,
    String? lotId,
    required String type,
    int? collaborateurs,
    String? commentaire,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('logTimeEntry');
    await callable.call(<String, dynamic>{
      'workspaceId': workspaceId,
      'devisId': devisId,
      if (lotId != null) 'lotId': lotId,
      'type': type,
      if (collaborateurs != null) 'collaborateurs': collaborateurs,
      if (commentaire != null) 'commentaire': commentaire,
    });
  }

  // ─────────────────────────────────────────────────────────────
  // Envoie une relance manuelle (clic utilisateur, pas une transition de
  // statut) — Commercial → Métreur (chantier pas accepté / commande en
  // attente) ou Métreur → Poseurs assignés (clôture pas faite dans l'appli).
  // Appelle la Cloud Function callable sendRelance, qui vérifie les droits,
  // le statut courant du chantier et un cooldown anti-spam par type — voir
  // functions/relanceConfig.js pour la table des types. L'exception (ex.
  // cooldown pas écoulé) remonte telle quelle pour affichage côté appelant.
  // ─────────────────────────────────────────────────────────────
  static Future<void> sendRelance({
    required String workspaceId,
    required String devisId,
    String? lotId,
    required String relanceType,
  }) async {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('sendRelance');
    await callable.call(<String, dynamic>{
      'workspaceId': workspaceId,
      'devisId': devisId,
      if (lotId != null) 'lotId': lotId,
      'relanceType': relanceType,
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
