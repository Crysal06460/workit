const onboardingRoles = ['commercial', 'metreur', 'poseur'];

String roleDisplayName(String roleKey) {
  switch (roleKey) {
    case 'commercial':
      return 'Commercial';
    case 'metreur':
      return 'Métreur';
    case 'poseur':
      return 'Équipe de pose';
    case 'menuiserie_aluminium':
      return 'Menuiserie Aluminium';
    case 'plomberie_sanitaire':
      return 'Plomberie – Sanitaire';
    case 'electricite_courants_faibles':
      return 'Électricité – Courants faibles';
    case 'chauffage_climatisation_ventilation':
      return 'Chauffage – Clim – Ventilation';
    case 'peinture_revetements':
      return 'Peinture – Revêtements';
    case 'carrelage_maconnerie_fine':
      return 'Carrelage – Maçonnerie fine';
    case 'cuisine_amenagement_interieur':
      return 'Cuisine – Aménagement intérieur';
    case 'salle_de_bain_etancheite':
      return 'Salle de bain – Étanchéité';
    case 'sols_exterieurs_amenagements':
      return 'Sols extérieurs – Aménagements';
    case 'vitrerie_miroiterie':
      return 'Vitrerie – Miroiterie';
    case 'automatismes_portails':
      return 'Automatismes – Portails';
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
    name: 'Configuration 1',
    price: 'Tarif à définir',
    seatsByRole: {'commercial': 3, 'metreur': 1, 'poseur': 3},
    features: [
      '3 commerciaux inclus',
      '1 métreur inclus',
      '3 équipes de pose incluses',
    ],
  ),
  PlanOption(
    id: 'abonnement_2',
    name: 'Configuration 2',
    price: 'Tarif à définir',
    seatsByRole: {'commercial': 5, 'metreur': 2, 'poseur': 5},
    features: [
      '5 commerciaux inclus',
      '2 métreurs inclus',
      '5 équipes de pose incluses',
    ],
  ),
  PlanOption(
    id: 'abonnement_3',
    name: 'Configuration 3',
    price: 'Tarif à définir',
    seatsByRole: {'commercial': null, 'metreur': null, 'poseur': null},
    features: [
      'Commerciaux illimités',
      'Mètreurs illimités',
      'Équipes de pose illimitées',
    ],
  ),
];

class OnboardingData {
  OnboardingData({
    required this.companyName,
    required this.siret,
    required this.address,
    required this.postalCode,
    required this.city,
    this.journeyType,
    this.trialSessionId,
    this.tradeKey,
  }) : invites = {for (final role in onboardingRoles) role: <String>[]};

  final String companyName;
  final String siret;
  final String address;
  final String postalCode;
  final String city;
  final String? journeyType; // structured | artisan
  final String? trialSessionId;
  String? tradeKey; // corps de métier choisi
  PlanOption? plan;
  String adminEmail = '';
  String adminUid = '';
  String? workspaceId;
  bool creatorUsesWorkit = false;
  String? creatorRoleKey; // commercial | metreur | commercial_metreur
  String? creatorFirstName;
  String? creatorLastName;
  final Map<String, List<String>> invites;

  final Map<String, String> generatedCodes = {
    'commercial': 'COMMERCIAL',
    'metreur': 'METREUR',
    'poseur': 'POSEURS',
  };

  int inviteCount(String roleKey) => invites[roleKey]?.length ?? 0;

  List<String> get creatorRoles {
    if (!creatorUsesWorkit || creatorRoleKey == null) return [];
    if (creatorRoleKey == 'commercial_metreur') {
      return ['commercial', 'metreur'];
    }
    return [creatorRoleKey!];
  }

  String? get creatorRoleLabel {
    if (!creatorUsesWorkit || creatorRoleKey == null) return null;
    if (creatorRoleKey == 'commercial_metreur') {
      return 'Commercial + Métreur';
    }
    return roleDisplayName(creatorRoleKey!);
  }

  int roleUsageCount(String roleKey) {
    final base = inviteCount(roleKey);
    final selfUsage = creatorRoles.contains(roleKey) ? 1 : 0;
    return base + selfUsage;
  }

  Map<String, int> get inviteCounts =>
      invites.map((key, value) => MapEntry(key, value.length));

  int get totalInvites =>
      inviteCounts.values.fold(0, (sum, value) => sum + value);

  int? seatLimit(String roleKey) => plan?.seatForRole(roleKey);

  int? remainingSeats(String roleKey) {
    final limit = seatLimit(roleKey);
    if (limit == null) return null;
    final remaining = limit - roleUsageCount(roleKey);
    return remaining < 0 ? 0 : remaining;
  }

  String seatUsageLabel(String roleKey) {
    final limit = seatLimit(roleKey);
    final count = roleUsageCount(roleKey);
    if (limit == null) {
      return '$count / ∞';
    }
    return '$count / $limit';
  }

  Map<String, dynamic> get seatUsageForFirestore =>
      {for (final key in onboardingRoles) key: roleUsageCount(key)};
}
