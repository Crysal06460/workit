import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/workspace_repository.dart';
import '../models/onboarding_models.dart';
import 'commercial_home_screen.dart';
import 'metreur_home_screen.dart';
import 'poseurs_home_screen.dart';

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
      _goToHome();
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

  void _goToHome() {
    final roleKey = widget.data.creatorRoleKey;
    final usesApp = widget.data.creatorUsesWorkit;
    final home = (!usesApp || roleKey == null) ? const CommercialHomeScreen() : _homeForRole(roleKey);
    if (home == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => home),
      (route) => false,
    );
  }

  Widget? _homeForRole(String roleKey) {
    switch (roleKey) {
      case 'commercial':
        return const CommercialHomeScreen();
      case 'metreur':
        return const MetreurHomeScreen();
      case 'poseur':
        return const PoseursHomeScreen();
      case 'commercial_metreur':
        return const CommercialHomeScreen();
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final plan = data.plan;
    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Espace prêt !',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E676).withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
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
                          const Text(
                            'Espace prêt pour déploiement',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Entreprise : ${data.companyName}',
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Invitations prêtes : ${data.totalInvites}',
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'Configuration',
                      value: plan?.name ?? 'Non définie',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      label: 'Métier',
                      value: data.tradeKey != null ? roleDisplayName(data.tradeKey!) : 'Non défini',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'Email de l’admin',
                      value: data.adminEmail.isEmpty
                          ? 'Non défini'
                          : data.adminEmail,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      label: 'Invitations',
                      value: '${data.totalInvites}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _CreatorAccessCard(data: data),
              const SizedBox(height: 14),
              Text(
                'Synthèse par rôle',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Column(
                children: onboardingRoles.map((role) {
                  final roleLabel = roleDisplayNamePlural(role);
                  final usage = data.seatUsageLabel(role);
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1422),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.group_outlined,
                          color: Color(0xFF00E676),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                roleLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                usage,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                'Invitations',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Column(
                children: data.invites.entries.map((entry) {
                  final emails = entry.value.isEmpty
                      ? ['Aucun email']
                      : entry.value;
                  final roleLabel = roleDisplayNamePlural(entry.key);
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1422),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          roleLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: emails
                              .map(
                                (email) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Text(
                                    email,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: isSaving ? null : _createWorkspace,
                  child: Text(
                    isSaving
                        ? 'Création en cours…'
                        : 'Créer l’espace et envoyer les invitations',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatorAccessCard extends StatelessWidget {
  const _CreatorAccessCard({required this.data});

  final OnboardingData data;

  @override
  Widget build(BuildContext context) {
    final usesApp = data.creatorUsesWorkit;
    final selectedRoles = data.creatorRoles.map(roleDisplayName).toList();
    final roleLabel = data.creatorRoleLabel ?? 'Tableau de bord global';
    final fullName = [
      data.creatorFirstName?.trim() ?? '',
      data.creatorLastName?.trim() ?? '',
    ].where((e) => e.isNotEmpty).join(' ');
    final description = usesApp
        ? 'Vous serez assigné en tant que $roleLabel. Vous gardez aussi le tableau de bord global.'
        : 'Vous suivrez les devis et métrés depuis le tableau de bord global.';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1422),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(
              Icons.dashboard_customize,
              color: Color(0xFF00E676),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usesApp ? 'Accès terrain activé' : 'Accès admin uniquement',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                if (fullName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(fullName, style: const TextStyle(color: Colors.white70)),
                ],
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, height: 1.3),
                ),
                if (usesApp) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: selectedRoles
                        .map(
                          (label) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1422),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
