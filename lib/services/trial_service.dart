import 'package:cloud_firestore/cloud_firestore.dart';

class TrialService {
  TrialService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<String> startTrial() async {
    final now = DateTime.now().toUtc();
    final endsAt = now.add(const Duration(days: 7));

    final ref = _firestore.collection('trial_sessions').doc();
    final payload = {
      'status': 'trial', // trial | expired | active
      'startedAt': Timestamp.fromDate(now),
      'endsAt': Timestamp.fromDate(endsAt),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await ref.set(payload);
    return ref.id;
  }
}
