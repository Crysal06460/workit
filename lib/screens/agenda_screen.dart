import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';

/// Agenda temps réel des RDV de métré et des poses à venir pour le
/// commercial connecté. Se met à jour instantanément dès qu'un métreur
/// programme un RDV (`meetingAt`) ou qu'une pose est planifiée (`poseDate`).
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final _firestore = FirebaseFirestore.instance;
  String? _workspaceId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkspaceId();
  }

  Future<void> _loadWorkspaceId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _workspaceId = prefs.getString('workit_workspace_id');
      _loading = false;
    });
  }

  String _frDay(int weekday) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[(weekday - 1).clamp(0, 6)];
  }

  String _fmtDate(DateTime dt) {
    final day = _frDay(dt.weekday);
    return '$day ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _buildEvents(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final events = <Map<String, dynamic>>[];
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final client = d['client']?.toString() ?? d['clientName']?.toString() ?? 'Client';
      final meetingTs = d['meetingAt'];
      final poseTs = d['poseDate'];

      if (meetingTs is Timestamp) {
        final dt = meetingTs.toDate();
        if (dt.isAfter(now.subtract(const Duration(days: 1)))) {
          events.add({'date': dt, 'label': 'RDV Métré — $client', 'type': 'rdv'});
        }
      }
      if (poseTs is Timestamp) {
        final dt = poseTs.toDate();
        if (dt.isAfter(now.subtract(const Duration(days: 1)))) {
          events.add({'date': dt, 'label': 'Pose — $client', 'type': 'pose'});
        }
      }
    }
    events.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Agenda',
          style: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_workspaceId == null || uid == null)
              ? const Center(
                  child: Text('Contexte introuvable.', style: TextStyle(color: AppColors.grey400)),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('workspaces')
                      .doc(_workspaceId)
                      .collection('devis')
                      .where('userId', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final events = _buildEvents(snapshot.data?.docs ?? []);
                    if (events.isEmpty) {
                      return const Center(
                        child: Text(
                          'Aucun rendez-vous ou pose à venir',
                          style: TextStyle(color: AppColors.grey400),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const Divider(color: AppColors.grey100, height: 1),
                      itemBuilder: (_, i) {
                        final ev = events[i];
                        final dt = ev['date'] as DateTime;
                        final isRdv = ev['type'] == 'rdv';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isRdv ? AppColors.primary : AppColors.success,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ev['label'] as String,
                                      style: const TextStyle(
                                        color: AppColors.grey900,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _fmtDate(dt),
                                      style: const TextStyle(color: AppColors.grey500, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
