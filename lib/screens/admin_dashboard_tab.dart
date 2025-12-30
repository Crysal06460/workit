import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminDashboardTab extends StatelessWidget {
  const AdminDashboardTab({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('workspaces')
          .doc(workspaceId)
          .collection('devis')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Erreur de chargement', style: TextStyle(color: Colors.white)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        
        // Counters logic
        final pendingQuotes = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Assuming 'metreurStatus' is 'Nouvelle demande' for pending
          return (data['metreurStatus'] == 'Nouvelle demande' || data['metreurStatus'] == null);
        }).length;

        final meaasuringInProgress = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['metreurStatus'] == 'En cours' || data['metreurStatus'] == 'Acceptée';
        }).length;
        
        // Assuming we have a status for orders, let's use 'to_order' based on previous context or 'À commander' tag
        final toOrder = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['metreurStatus'] == 'À commander';
        }).length;

         final worksitesInProgress = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Placeholder status for worksites
          return data['poseurStatus'] == 'En cours'; 
        }).length;


        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               const Text(
                'Vue d’ensemble',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StatCard(
                    title: 'Devis en attente',
                    count: pendingQuotes,
                    icon: Icons.description_outlined,
                    color: Colors.blueAccent,
                  ),
                   _StatCard(
                    title: 'Métrés en cours',
                    count: meaasuringInProgress,
                    icon: Icons.straighten,
                    color: Colors.orangeAccent,
                  ),
                  _StatCard(
                    title: 'Commandes à faire',
                    count: toOrder,
                    icon: Icons.shopping_cart_outlined,
                    color: Colors.purpleAccent,
                  ),
                   _StatCard(
                    title: 'Chantiers en cours',
                    count: worksitesInProgress,
                    icon: Icons.construction,
                    color: Colors.greenAccent,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1422),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
