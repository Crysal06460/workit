import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/workspace_repository.dart';
import '../models/onboarding_models.dart';

class AdminSummaryScreen extends StatefulWidget {
  const AdminSummaryScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<AdminSummaryScreen> createState() => _AdminSummaryScreenState();
}

class _AdminSummaryScreenState extends State<AdminSummaryScreen> {
  late final WorkspaceRepository repository;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    repository = WorkspaceRepository(FirebaseFirestore.instance);
  }

  Future<void> _createWorkspace() async {
    setState(() => isSaving = true);
    try {
      final result = await repository.createWorkspace(widget.data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Espace créé (ID: ${result.workspaceId}) · Invitations: ${result.invitesCreated}',
          ),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Création impossible : $error')));
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final plan = data.plan;
    return Scaffold(
      appBar: AppBar(title: const Text('Espace prêt !')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tout est configuré',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Entreprise : ${data.companyName}\nPlan : ${plan?.name ?? '-'} (${plan?.price ?? ''})',
            ),
            const SizedBox(height: 4),
            Text('Invitations envoyées : ${data.totalInvites}'),
            const SizedBox(height: 12),
            if (plan != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final role in onboardingRoles)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${roleDisplayNamePlural(role)} : ${data.seatUsageLabel(role)}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            const Text('Invitations envoyées :'),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: data.invites.entries.map((entry) {
                  final emails = entry.value.isEmpty ? ['Aucun email'] : entry.value;
                  final roleLabel = roleDisplayNamePlural(entry.key);
                  return Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            roleLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          for (final email in emails) Text(email),
                          const SizedBox(height: 8),
                          Text('Code secours : ${data.generatedCodes[entry.key]}'),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isSaving ? null : _createWorkspace,
                child: Text(
                  isSaving ? 'Création en cours…' : 'Créer l’espace et envoyer les invitations',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
