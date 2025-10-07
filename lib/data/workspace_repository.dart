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

    final workspaceRef = _firestore.collection('workspaces').doc();
    final serverTimestamp = FieldValue.serverTimestamp();

    final planMap = {
      'id': plan.id,
      'name': plan.name,
      'priceDisplay': plan.price,
      'seatsByRole': plan.seatsByRole,
      'features': plan.features,
      'isUnlimited': plan.isUnlimited,
    };

    final workspaceData = {
      'companyName': data.companyName,
      'siret': data.siret,
      'address': data.address,
      'plan': planMap,
      'seatUsage': data.seatUsageForFirestore,
      'joinCodes': data.generatedCodes,
      'totalInvites': data.totalInvites,
      'status': 'pending_activation',
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
          'status': 'pending',
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
