import 'package:flutter/material.dart';

/// Représentation normalisée d'un chantier, indépendante du modèle Dart
/// propre à chaque écran (`_QuoteItem`, `_MeasureCardData`, `_ChantierData`,
/// `Map` brut côté admin). Sert de langage commun aux composants partagés
/// (popup de liste, section "chantiers récemment ajoutés") sans requête
/// Firestore supplémentaire : chaque écran mappe son modèle déjà chargé en
/// mémoire vers ce DTO.
class WiDevisSummary {
  const WiDevisSummary({
    required this.id,
    required this.clientLabel,
    this.address,
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    this.createdAt,
    this.updatedAt,
    required this.onTap,
  });

  final String id;
  final String clientLabel;
  final String? address;
  final String status;
  final String statusLabel;
  final Color statusColor;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final VoidCallback onTap;
}
