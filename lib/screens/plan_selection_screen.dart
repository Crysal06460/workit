import 'package:flutter/material.dart';

import '../models/onboarding_models.dart';
import 'invite_team_screen.dart';

class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  late PlanOption selectedPlan;
  late List<PlanOption> plans;

  @override
  void initState() {
    super.initState();
    plans = defaultPlans();
    selectedPlan = plans.first;
  }

  void _continue() {
    widget.data.plan = selectedPlan;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InviteTeamScreen(data: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choisir un abonnement')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenue ${widget.data.companyName}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sélectionnez votre forfait WorkIt. Vous pourrez modifier ou augmenter vos sièges plus tard.',
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: plans.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  final isSelected = plan.id == selectedPlan.id;
                  return InkWell(
                    onTap: () => setState(() => selectedPlan = plan),
                    child: PlanCard(plan: plan, isSelected: isSelected),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _continue,
                child: Text('Continuer avec ${selectedPlan.name}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, required this.isSelected});

  final PlanOption plan;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300;
    final seatBadges = plan.seatsByRole.entries.map((entry) {
      final seatLabel = plan.seatLabelForRole(entry.key);
      final pluralLabel = roleDisplayNamePlural(entry.key);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$seatLabel $pluralLabel',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }).toList();
    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: 1.4),
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: isSelected ? 4 : 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.price,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: seatBadges),
            const SizedBox(height: 12),
            for (final feature in plan.features)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feature)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
