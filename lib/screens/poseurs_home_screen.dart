import 'package:flutter/material.dart';

const Color _poseurBg = Color(0xFF07090D);
const Color _poseurCard = Color(0xFF0F1422);
const Color _poseurAccent = Color(0xFF00F795);

class PoseursHomeScreen extends StatelessWidget {
  const PoseursHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _poseurBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Vos poses du jour',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: _poseurAccent,
            tabs: const [
              Tab(text: 'Jour'),
              Tab(text: 'Semaine'),
              Tab(text: 'Liste'),
            ],
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: TabBarView(
              children: [
                _DayPlanning(),
                _Placeholder(text: 'Planning de la semaine (aperçu condensé).'),
                _Placeholder(text: 'Liste des poses à venir.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayPlanning extends StatelessWidget {
  final List<_Job> jobs = const [
    _Job(
      start: '08h00',
      address: '15 rue des Tuileries, Nantes',
      client: 'Claire Durant',
      products: '1 pergola bioclimatique',
      status: 'Préparé',
    ),
    _Job(
      start: '11h30',
      address: '3 chemin des Acacias, Rennes',
      client: 'SARL Vert',
      products: '2 fenêtres alu',
      status: 'En cours',
    ),
    _Job(
      start: '15h30',
      address: '22 av. du Parc, Angers',
      client: 'M. Bernard',
      products: '1 portail alu, 1 portillon',
      status: 'À terminer',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: jobs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final job = jobs[index];
        return _JobCard(job: job);
      },
    );
  }
}

class _JobCard extends StatefulWidget {
  const _JobCard({required this.job});

  final _Job job;

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final statusColor = job.status == 'En cours'
        ? Colors.blueAccent
        : job.status == 'À terminer'
            ? Colors.deepOrangeAccent
            : Colors.greenAccent;

    return Container(
      decoration: BoxDecoration(
        color: _poseurCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(job.start, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Tag(label: job.status, color: statusColor),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.navigation_outlined, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            job.address,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${job.client} • ${job.products}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _poseurAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {},
            child: const Text('Démarrer la pose'),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => expanded = !expanded),
            child: Row(
              children: [
                Text(
                  expanded ? 'Masquer la fiche chantier' : 'Voir la fiche chantier',
                  style: const TextStyle(color: Colors.white70),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            _JobDetails(job: job),
          ],
        ],
      ),
    );
  }
}

class _JobDetails extends StatelessWidget {
  const _JobDetails({required this.job});

  final _Job job;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations essentielles',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _DetailRow(
            icon: Icons.place_outlined,
            text: 'Adresse GPS (navigation)',
            action: Icons.navigation_outlined,
          ),
          _DetailRow(
            icon: Icons.phone_outlined,
            text: 'Contact client (appel / SMS)',
            action: Icons.call,
          ),
          _DetailRow(
            icon: Icons.checklist,
            text: 'Produits validés par métré',
            action: Icons.description_outlined,
          ),
          const SizedBox(height: 12),
          const Text(
            'Photos avant pose',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
            ),
            onPressed: () {},
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Prendre une photo'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Checklist pose',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ...[
            'Niveaux OK',
            'Fixations OK',
            'Étanchéité OK',
            'Nettoyage OK',
            'Tests ouverture / fermeture OK',
          ].map(
            (item) => CheckboxListTile(
              value: false,
              onChanged: (_) {},
              title: Text(
                item,
                style: const TextStyle(color: Colors.white),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: _poseurAccent,
              checkColor: Colors.black,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Photos après pose',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
            ),
            onPressed: () {},
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Ajouter photos après pose'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _poseurAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {},
              child: const Text('Terminer la pose'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text, required this.action});

  final IconData icon;
  final String text;
  final IconData action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70)),
          ),
          Icon(action, color: Colors.white54, size: 18),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(color: Colors.white54),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Job {
  const _Job({
    required this.start,
    required this.address,
    required this.client,
    required this.products,
    required this.status,
  });

  final String start;
  final String address;
  final String client;
  final String products;
  final String status;
}
