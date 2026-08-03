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

