import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/onboarding_models.dart';

class WorkspaceCreationResult {
  WorkspaceCreationResult({required this.workspaceId, required this.invitesCreated});

  final String workspaceId;
  final int invitesCreated;
}

class WorkspaceRepository {
  WorkspaceRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Future<WorkspaceCreationResult> createWorkspace(OnboardingData data) async {
    final plan = data.plan;
    if (plan == null) {
      throw StateError('Aucun forfait sélectionné.');
    }
    if (data.adminUid.isEmpty) {
      throw StateError('Admin non authentifié, création impossible.');
    }

    final workspaceRef = data.workspaceId == null
        ? _firestore.collection('workspaces').doc()
        : _firestore.collection('workspaces').doc(data.workspaceId);
    data.workspaceId = workspaceRef.id;
    final serverTimestamp = FieldValue.serverTimestamp();

    final planMap = {
      'id': plan.id,
      'name': plan.name,
      'priceDisplay': plan.price,
      'seatsByRole': plan.seatsByRole,
      'features': plan.features,
      'isUnlimited': plan.isUnlimited,
    };

    final trialStart = DateTime.now().toUtc();
    final trialEnd = trialStart.add(const Duration(days: 7));

    final workspaceData = {
      'companyName': data.companyName,
      'siret': data.siret,
      'address': data.address,
      'postalCode': data.postalCode,
      'city': data.city,
      'adminEmail': data.adminEmail.toLowerCase(),
      'adminUid': data.adminUid,
      'createdByEmail': data.adminEmail.toLowerCase(),
      'createdByUid': data.adminUid,
      'journeyType': data.journeyType,
      'trialSessionId': data.trialSessionId,
      'plan': planMap,
      'seatUsage': data.seatUsageForFirestore,
      'creatorUsesWorkit': data.creatorUsesWorkit,
      'creatorRole': data.creatorRoleKey,
      'creatorRoles': data.creatorRoles,
      'creatorFirstName': data.creatorFirstName,
      'creatorLastName': data.creatorLastName,
      'tradeKey': data.tradeKey,
      'joinCodes': data.generatedCodes,
      'totalInvites': data.totalInvites,
      'status': 'trial', // trial | expired | active
      'trialStartAt': Timestamp.fromDate(trialStart),
      'trialEndsAt': Timestamp.fromDate(trialEnd),
      'subscriptionStatus': 'trial',
      'createdAt': serverTimestamp,
      'updatedAt': serverTimestamp,
    };

    final batch = _firestore.batch();
    batch.set(workspaceRef, workspaceData);

    int invitesCreated = 0;
    data.invites.forEach((role, emails) {
      for (final email in emails) {
        final trimmedEmail = email.trim();
        if (trimmedEmail.isEmpty) continue;
        final inviteRef = workspaceRef.collection('invites').doc();
        batch.set(inviteRef, {
          'email': trimmedEmail.toLowerCase(),
          'role': role,
          'tradeKey': data.tradeKey,
          'status': 'pending',
          'workspaceId': workspaceRef.id,
          'createdAt': serverTimestamp,
          'updatedAt': serverTimestamp,
        });
        invitesCreated++;
      }
    });

    await batch.commit();

    return WorkspaceCreationResult(
      workspaceId: workspaceRef.id,
      invitesCreated: invitesCreated,
    );
  }
}
