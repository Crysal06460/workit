import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Définition d'un champ de métré (relevé terrain), lu depuis
/// `metiers.<metier>.categories.<categorie>.metre_fields.fields[]` du
/// dictionnaire.
class MetreFieldDef {
  const MetreFieldDef({
    required this.key,
    required this.label,
    required this.type,
    this.unit,
    this.choices = const [],
    this.required = false,
    this.min,
    this.max,
  });

  /// Clé de stockage de la valeur saisie (ex: 'largeur', 'cjHaut').
  final String key;
  final String label;

  /// 'number' | 'text' | 'dropdown' | 'boolean'.
  final String type;
  final String? unit;
  final List<String> choices;

  /// Contraintes de validation optionnelles (absentes pour la plupart des
  /// champs existants — pas de régression tant qu'un métier ne les déclare
  /// pas explicitement dans le dictionnaire).
  final bool required;
  final num? min;
  final num? max;

  factory MetreFieldDef.fromMap(Map<String, dynamic> map) {
    return MetreFieldDef(
      key: map['key']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      type: map['type']?.toString() ?? 'text',
      unit: map['unit']?.toString(),
      choices: (map['choices'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      required: map['required'] == true,
      min: map['min'] as num?,
      max: map['max'] as num?,
    );
  }
}

/// Étape de préparation avant intervention terrain (bon de préparation),
/// déclarée au niveau du métier : `metiers.<metier>.preparation_steps[]`.
class PreparationStep {
  const PreparationStep({required this.key, required this.label});
  final String key;
  final String label;

  factory PreparationStep.fromMap(Map<String, dynamic> map) => PreparationStep(
        key: map['key']?.toString() ?? '',
        label: map['label']?.toString() ?? '',
      );
}

/// Point de contrôle d'une checklist d'exécution/autocontrôle terrain,
/// déclaré au niveau du métier : `metiers.<metier>.execution_checklist[]`.
class ChecklistItem {
  const ChecklistItem({required this.key, required this.label});
  final String key;
  final String label;

  factory ChecklistItem.fromMap(Map<String, dynamic> map) => ChecklistItem(
        key: map['key']?.toString() ?? '',
        label: map['label']?.toString() ?? '',
      );
}

/// Cause de non-conformité structurée propre au métier :
/// `metiers.<metier>.non_conformite_causes[]`.
class NonConformiteCause {
  const NonConformiteCause({required this.key, required this.label});
  final String key;
  final String label;

  factory NonConformiteCause.fromMap(Map<String, dynamic> map) => NonConformiteCause(
        key: map['key']?.toString() ?? '',
        label: map['label']?.toString() ?? '',
      );
}

/// Indicateur métier (tableau de bord) : `metiers.<metier>.indicateurs[]`.
class MetierIndicateur {
  const MetierIndicateur({required this.key, required this.label, this.unit});
  final String key;
  final String label;
  final String? unit;

  factory MetierIndicateur.fromMap(Map<String, dynamic> map) => MetierIndicateur(
        key: map['key']?.toString() ?? '',
        label: map['label']?.toString() ?? '',
        unit: map['unit']?.toString(),
      );
}

/// Champs de métré d'une catégorie de produit, avec le mode de rendu à
/// utiliser côté écran de métré.
class MetreCategoryFields {
  const MetreCategoryFields({required this.render, required this.fields});

  /// 'schematic_ouverture' (schéma visuel type fenêtre) ou 'list' (défaut).
  final String render;
  final List<MetreFieldDef> fields;

  factory MetreCategoryFields.fromMap(Map<String, dynamic> map) {
    final rawFields = map['fields'] as List? ?? const [];
    return MetreCategoryFields(
      render: map['render']?.toString() ?? 'list',
      fields: rawFields
          .whereType<Map>()
          .map((e) => MetreFieldDef.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// Charge une seule fois le dictionnaire des métiers
/// (`assets/dictionnaire_workit/workit_dictionary.json`) et expose des accès
/// pratiques aux métiers, catégories et champs de métré — évite que chaque
/// écran reparse le même fichier avec sa propre logique.
class DictionaryService {
  DictionaryService._();
  static final DictionaryService instance = DictionaryService._();

  Future<Map<String, dynamic>>? _loading;

  Future<Map<String, dynamic>> _load() {
    return _loading ??= rootBundle
        .loadString('assets/dictionnaire_workit/workit_dictionary.json')
        .then((raw) => json.decode(raw) as Map<String, dynamic>)
        .catchError((_) => <String, dynamic>{});
  }

  Future<Map<String, dynamic>?> _metierNode(String metierKey) async {
    final dict = await _load();
    final metiers = dict['metiers'];
    if (metiers is Map && metiers[metierKey] is Map) {
      return Map<String, dynamic>.from(metiers[metierKey] as Map);
    }
    return null;
  }

  Future<Map<String, dynamic>?> _categoryNode(String metierKey, String categoryKey) async {
    final metier = await _metierNode(metierKey);
    final cats = metier?['categories'];
    if (cats is Map && cats[categoryKey] is Map) {
      return Map<String, dynamic>.from(cats[categoryKey] as Map);
    }
    return null;
  }

  /// Liste des métiers disponibles : clé → libellé affichable.
  Future<Map<String, String>> metiers() async {
    final dict = await _load();
    final metiers = dict['metiers'];
    if (metiers is! Map) return {};
    return {
      for (final entry in metiers.entries)
        entry.key.toString():
            (entry.value is Map ? (entry.value as Map)['label']?.toString() : null) ?? entry.key.toString(),
    };
  }

  /// Catégories d'un métier donné : clé → libellé affichable.
  Future<List<MapEntry<String, String>>> categoriesFor(String metierKey) async {
    final node = await _metierNode(metierKey);
    final cats = node?['categories'];
    if (cats is! Map) return const [];
    return cats.entries
        .map((e) => MapEntry(
              e.key.toString(),
              (e.value is Map ? (e.value as Map)['label']?.toString() : null) ?? e.key.toString(),
            ))
        .toList();
  }

  /// Types disponibles pour une catégorie d'un métier : clé → libellé.
  Future<List<MapEntry<String, String>>> typesFor(String metierKey, String categoryKey) async {
    final cat = await _categoryNode(metierKey, categoryKey);
    final types = cat?['types'];
    if (types is! Map) return const [];
    return types.entries
        .map((e) => MapEntry(
              e.key.toString(),
              (e.value is Map ? (e.value as Map)['label']?.toString() : null) ?? e.key.toString(),
            ))
        .toList();
  }

  /// Variantes disponibles pour un type donné.
  Future<List<String>> variantesFor(String metierKey, String categoryKey, String typeKey) async {
    final cat = await _categoryNode(metierKey, categoryKey);
    final type = (cat?['types'] as Map?)?[typeKey];
    final variantes = type is Map ? type['variantes'] : null;
    if (variantes is! List) return const [];
    return variantes.map((e) => e.toString()).toList();
  }

  /// Sous-catégories déclarées pour une catégorie (ex: matériaux).
  Future<List<String>> sousCategoriesFor(String metierKey, String categoryKey) async {
    final cat = await _categoryNode(metierKey, categoryKey);
    final sous = cat?['sous_categories'];
    if (sous is! List) return const [];
    return sous.map((e) => e.toString()).toList();
  }

  /// Libellé d'un métier.
  Future<String> metierLabel(String metierKey) async {
    final node = await _metierNode(metierKey);
    return node?['label']?.toString() ?? metierKey;
  }

  /// Libellé d'une catégorie.
  Future<String> categoryLabel(String metierKey, String categoryKey) async {
    final cat = await _categoryNode(metierKey, categoryKey);
    return cat?['label']?.toString() ?? categoryKey;
  }

  /// Champs de métré à afficher sur le terrain pour une catégorie donnée.
  /// Stockés au niveau du métier (`metiers.<metier>.metre_fields.<categorie>`),
  /// pas imbriqués dans chaque catégorie — un seul bloc à maintenir par métier.
  /// Retourne `null` si le métier/catégorie n'a pas encore de champs de
  /// métré définis (l'écran de métré doit alors utiliser un repli générique
  /// minimal : quantité, couleur, référence).
  Future<MetreCategoryFields?> metreFieldsFor(String metierKey, String categoryKey) async {
    final metier = await _metierNode(metierKey);
    final allMetre = metier?['metre_fields'];
    if (allMetre is! Map) return null;
    final metre = allMetre[categoryKey];
    if (metre is! Map) return null;
    return MetreCategoryFields.fromMap(Map<String, dynamic>.from(metre));
  }

  /// Version du schéma du métier (`metiers.<metier>.metierVersion`), pour
  /// traçabilité (stampée sur le devis au moment du métré). `1` par défaut
  /// pour un métier qui ne déclare pas encore cet attribut.
  Future<int> metierVersion(String metierKey) async {
    final node = await _metierNode(metierKey);
    final v = node?['metierVersion'];
    return v is int ? v : (int.tryParse(v?.toString() ?? '') ?? 1);
  }

  Future<List<T>> _listFor<T>(
    String metierKey,
    String jsonKey,
    T Function(Map<String, dynamic>) fromMap,
  ) async {
    final node = await _metierNode(metierKey);
    final raw = node?[jsonKey];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Étapes de préparation à prévoir avant l'intervention, pour le bon de
  /// préparation. Liste vide si le métier n'en déclare pas encore.
  Future<List<PreparationStep>> preparationStepsFor(String metierKey) =>
      _listFor(metierKey, 'preparation_steps', PreparationStep.fromMap);

  /// Points de contrôle de la checklist d'exécution/autocontrôle terrain.
  /// Liste vide si le métier n'en déclare pas encore.
  Future<List<ChecklistItem>> executionChecklistFor(String metierKey) =>
      _listFor(metierKey, 'execution_checklist', ChecklistItem.fromMap);

  /// Causes de non-conformité structurées propres au métier.
  /// Liste vide si le métier n'en déclare pas encore.
  Future<List<NonConformiteCause>> nonConformiteCausesFor(String metierKey) =>
      _listFor(metierKey, 'non_conformite_causes', NonConformiteCause.fromMap);

  /// Indicateurs métier pour le futur tableau de bord (Phase 6).
  /// Liste vide si le métier n'en déclare pas encore.
  Future<List<MetierIndicateur>> indicateursFor(String metierKey) =>
      _listFor(metierKey, 'indicateurs', MetierIndicateur.fromMap);
}
