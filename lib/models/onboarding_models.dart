const onboardingRoles = ['commercial', 'metreur', 'poseur'];

String roleDisplayName(String roleKey) {
  switch (roleKey) {
    case 'commercial':
      return 'Commercial';
    case 'metreur':
      return 'Métreur';
    case 'poseur':
      return 'Équipe de pose';
    default:
      return roleKey;
  }
}

String roleDisplayNamePlural(String roleKey) {
  switch (roleKey) {
    case 'commercial':
      return 'Commerciaux';
    case 'metreur':
      return 'Métreurs';
    case 'poseur':
      return 'Équipes de pose';
    default:
      return roleKey;
  }
}

String defaultInvitePlaceholder(String roleKey) {
  switch (roleKey) {
    case 'commercial':
      return 'ex: luc@menuiserie.fr\nmarie@menuiserie.fr';
    case 'metreur':
      return 'ex: julien@menuiserie.fr';
    case 'poseur':
      return 'ex: equipe1@menuiserie.fr';
    default:
      return 'email@example.com';
  }
}

class PlanOption {
  const PlanOption({
    required this.id,
    required this.name,
    required this.price,
    required this.seatsByRole,
    required this.features,
  });

  final String id;
  final String name;
  final String price;
  final Map<String, int?> seatsByRole;
  final List<String> features;

  bool get isUnlimited => seatsByRole.values.every((value) => value == null);

  int? seatForRole(String roleKey) => seatsByRole[roleKey];

  String seatLabelForRole(String roleKey) {
    final value = seatsByRole[roleKey];
    if (value == null) {
      return 'Illimité';
    }
    return value.toString();
  }
}

List<PlanOption> defaultPlans() => const [
      PlanOption(
        id: 'abonnement_1',
        name: 'Abonnement 1',
        price: 'Tarif à définir',
        seatsByRole: {
          'commercial': 3,
          'metreur': 1,
          'poseur': 3,
        },
        features: [
          '3 commerciaux inclus',
          '1 métreur inclus',
          '3 équipes de pose incluses',
          'Accès complet au workflow WorkIt',
        ],
      ),
      PlanOption(
        id: 'abonnement_2',
        name: 'Abonnement 2',
        price: 'Tarif à définir',
        seatsByRole: {
          'commercial': 5,
          'metreur': 2,
          'poseur': 5,
        },
        features: [
          '5 commerciaux inclus',
          '2 métreurs inclus',
          '5 équipes de pose incluses',
          'Support WorkIt prioritaire',
        ],
      ),
      PlanOption(
        id: 'abonnement_3',
        name: 'Abonnement 3',
        price: 'Tarif à définir',
        seatsByRole: {
          'commercial': null,
          'metreur': null,
          'poseur': null,
        },
        features: [
          'Utilisateurs illimités',
          'Équipes de pose illimitées',
          'Accès anticipé aux fonctionnalités IA',
          'Gestion avancée des permissions',
        ],
      ),
    ];

class OnboardingData {
  OnboardingData({
    required this.companyName,
    required this.siret,
    required this.address,
  }) : invites = {
          for (final role in onboardingRoles) role: <String>[],
        };

  final String companyName;
  final String siret;
  final String address;
  PlanOption? plan;
  final Map<String, List<String>> invites;

  final Map<String, String> generatedCodes = {
    'commercial': 'COMMERCIAL',
    'metreur': 'METREUR',
    'poseur': 'POSEURS',
  };

  int inviteCount(String roleKey) => invites[roleKey]?.length ?? 0;

  Map<String, int> get inviteCounts => invites.map(
        (key, value) => MapEntry(key, value.length),
      );

  int get totalInvites => inviteCounts.values.fold(0, (sum, value) => sum + value);

  int? seatLimit(String roleKey) => plan?.seatForRole(roleKey);

  int? remainingSeats(String roleKey) {
    final limit = seatLimit(roleKey);
    if (limit == null) return null;
    final remaining = limit - inviteCount(roleKey);
    return remaining < 0 ? 0 : remaining;
  }

  String seatUsageLabel(String roleKey) {
    final limit = seatLimit(roleKey);
    final count = inviteCount(roleKey);
    if (limit == null) {
      return '$count / ∞';
    }
    return '$count / $limit';
  }

  Map<String, dynamic> get seatUsageForFirestore => invites.map(
        (key, value) => MapEntry(key, value.length),
      );
}
