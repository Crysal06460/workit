import 'package:flutter/material.dart';

const Color _metreurBg = Color(0xFF07090D);
const Color _metreurCard = Color(0xFF0F1422);
const Color _metreurAccent = Color(0xFF00F795);

class MetreurHomeScreen extends StatelessWidget {
  const MetreurHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _metreurBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Bonjour, Léa',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Métreur',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined, color: Colors.white),
            onPressed: () {},
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _PrioritiesSection(),
              SizedBox(height: 18),
              _QuickActions(),
              SizedBox(height: 18),
              _MeasureSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrioritiesSection extends StatelessWidget {
  const _PrioritiesSection();

  @override
  Widget build(BuildContext context) {
    final items = [
      _PriorityItem(
        time: '10h30',
        address: '8 rue des Peupliers, Lille',
        client: 'Sophie Martin',
        quote: '#8424',
        tag: 'Terrain',
      ),
      _PriorityItem(
        time: '14h00',
        address: '12 av. Pasteur, Dunkerque',
        client: 'Menuiserie Nord',
        quote: '#8420',
        tag: 'Bureau',
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: _metreurCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.flag, color: Colors.white70, size: 18),
              SizedBox(width: 8),
              Text(
                'Vos priorités aujourd’hui',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PriorityCard(item: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.item});

  final _PriorityItem item;

  @override
  Widget build(BuildContext context) {
    final tagColor = item.tag == 'Terrain' ? Colors.orangeAccent : Colors.blueGrey;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(12),
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
                    Text(item.time, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _Tag(label: item.tag, color: tagColor),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.navigation_outlined, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.address,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.client} • ${item.quote}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem(icon: Icons.photo_camera_outlined, label: 'Prendre photo terrain'),
      _ActionItem(icon: Icons.edit_outlined, label: 'Annoter une photo'),
      _ActionItem(icon: Icons.add, label: 'Ajouter mesure'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions
          .map(
            (action) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.06),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {},
                  child: Column(
                    children: [
                      Icon(action.icon, color: Colors.white),
                      const SizedBox(height: 6),
                      Text(
                        action.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MeasureSection extends StatelessWidget {
  const _MeasureSection();

  @override
  Widget build(BuildContext context) {
    final toMeasure = [
      _MeasureCardData(
        title: '16 rue des Platanes, Rennes',
        note: 'Prévoir prise de cotes volets roulants.',
        hasPhotos: true,
        phone: '06 22 33 44 55',
      ),
    ];
    final inProgress = [
      _MeasureCardData(
        title: '21 av. des Pins, Toulouse',
        note: 'Vérifier menuiseries alu',
        status: 'Dimensions',
        updated: 'Mis à jour il y a 1h',
      ),
      _MeasureCardData(
        title: '4 impasse des Roses, Lyon',
        note: 'Photos ajoutées',
        status: 'Photos',
        updated: 'Mis à jour il y a 3h',
      ),
    ];
    final toValidate = [
      _MeasureCardData(
        title: '9 rue Victor Hugo, Paris',
        note: 'Dossier complet',
        status: 'Prêt à valider',
        updated: 'Revu ce matin',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(title: 'À mesurer (terrain)', children: [
          ...toMeasure.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MeasureCard(
                data: item,
                tag: 'À mesurer',
                tagColor: Colors.orangeAccent,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.navigation_outlined, color: Colors.white70),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone_outlined, color: Colors.white70),
                    onPressed: () {},
                  ),
                  if (item.hasPhotos)
                    const Icon(Icons.photo_outlined, color: Colors.white70),
                ],
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _Section(title: 'En cours de métré (bureau)', children: [
          ...inProgress.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MeasureCard(
                data: item,
                tag: 'En cours',
                tagColor: Colors.lightBlueAccent,
                actions: [
                  _Tag(label: item.status ?? '', color: Colors.lightBlueAccent),
                  const SizedBox(width: 6),
                  Text(
                    item.updated ?? '',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_square, color: Colors.white70),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _Section(title: 'À valider / transmettre', children: [
          ...toValidate.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MeasureCard(
                data: item,
                tag: 'Prêt à valider',
                tagColor: Colors.greenAccent,
                actions: [
                  Icon(Icons.folder_open, color: Colors.greenAccent.shade200),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _metreurAccent,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {},
                    child: const Text('Valider & transmettre au commercial'),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

class _MeasureCard extends StatelessWidget {
  const _MeasureCard({
    required this.data,
    required this.tag,
    required this.tagColor,
    required this.actions,
  });

  final _MeasureCardData data;
  final String tag;
  final Color tagColor;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _metreurCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Tag(label: tag, color: tagColor),
              const Spacer(),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
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

class _ActionItem {
  _ActionItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _PriorityItem {
  _PriorityItem({
    required this.time,
    required this.address,
    required this.client,
    required this.quote,
    required this.tag,
  });

  final String time;
  final String address;
  final String client;
  final String quote;
  final String tag;
}

class _MeasureCardData {
  _MeasureCardData({
    required this.title,
    required this.note,
    this.status,
    this.updated,
    this.hasPhotos = false,
    this.phone,
  });

  final String title;
  final String note;
  final String? status;
  final String? updated;
  final bool hasPhotos;
  final String? phone;
}
