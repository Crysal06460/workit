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
  });

  /// Clé de stockage de la valeur saisie (ex: 'largeur', 'cjHaut').
  final String key;
  final String label;

  /// 'number' | 'text' | 'dropdown' | 'boolean'.
  final String type;
  final String? unit;
  final List<String> choices;

  factory MetreFieldDef.fromMap(Map<String, dynamic> map) {
    return MetreFieldDef(
      key: map['key']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      type: map['type']?.toString() ?? 'text',
      unit: map['unit']?.toString(),
      choices: (map['choices'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
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
}
