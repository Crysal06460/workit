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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Choisir votre configuration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0E1726), Color(0xFF0A1A2F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Icon(
                        Icons.verified,
                        color: Color(0xFF00E676),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choisir la taille de votre équipe',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Sélectionnez la configuration adaptée à votre structure.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
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
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _continue,
                  child: Text('Continuer avec ${selectedPlan.name}'),
                ),
              ),
            ],
          ),
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
    final theme = Theme.of(context);
    final borderColor = isSelected ? const Color(0xFF00E676) : Colors.white24;
    final titleColor = Colors.white;
    final subtitleColor = Colors.white70;
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Price hidden for trial flow
                      // Text(
                      //   plan.price,
                      //   style: const TextStyle(color: Colors.white70),
                      // ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF00E676).withOpacity(0.6),
                      ),
                    ),
                    child: const Text(
                      'Choisi',
                      style: TextStyle(
                        color: Color(0xFF00E676),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final badge in seatBadges) ...[
                  badge,
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
