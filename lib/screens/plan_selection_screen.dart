import 'package:flutter/material.dart';

import '../models/onboarding_models.dart';
import 'final_save_screen.dart';

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
      MaterialPageRoute(builder: (_) => FinalSaveScreen(data: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF07090D);
    const accent = Color(0xFF00E676);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StepProgress(current: 3, total: 3),
              const SizedBox(height: 28),
              const Text(
                'Ma formule',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choisissez la configuration adaptée à votre équipe.',
                style: TextStyle(color: Colors.white60, fontSize: 15),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    final isSelected = plan.id == selectedPlan.id;
                    return InkWell(
                      onTap: () => setState(() => selectedPlan = plan),
                      borderRadius: BorderRadius.circular(18),
                      child: PlanCard(plan: plan, isSelected: isSelected),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _continue,
                  child: Text('Créer mon espace — ${selectedPlan.name}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Étape $current sur $total',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(total, (i) {
            final done = i < current;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: done
                      ? const Color(0xFF00E676)
                      : Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, required this.isSelected});

  final PlanOption plan;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? const Color(0xFF00E676) : Colors.white24;
    final seatBadges = plan.seatsByRole.entries.map((entry) {
      final seatLabel = plan.seatLabelForRole(entry.key);
      final pluralLabel = roleDisplayNamePlural(entry.key);
      final singularLabel = roleDisplayName(entry.key);
      final isUnlimited = plan.seatForRole(entry.key) == null;
      final value = plan.seatForRole(entry.key);
      final display = isUnlimited
          ? '$pluralLabel illimités'
          : value == 1
              ? '$seatLabel $singularLabel'
              : '$seatLabel $pluralLabel';
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          display,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }).toList();

    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: 1.4),
        borderRadius: BorderRadius.circular(16),
      ),
      color: const Color(0xFF0F1422),
      elevation: isSelected ? 6 : 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF00E676).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF00E676).withOpacity(0.6),
                      ),
                    ),
                    child: const Text(
                      'Sélectionné',
                      style: TextStyle(
                        color: Color(0xFF00E676),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final badge in seatBadges) ...[
                  badge,
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
