import 'dart:collection';

/// Catalogue de mots-clés utilisés pour extraire des informations des devis.
///
/// Les termes sont organisés par catégories pour une lecture structurée.
const Map<String, dynamic> _keywordCatalog = {
  'type_produit': {
    'menuiseries': [
      'fenetre',
      'fenetre_oscillo_battante',
      'fenetre_fixe',
      'fenetre_coulissante',
      'fenetre_soufflet',
      'chassis',
      'chassis_fixe',
      'porte_fenetre',
      'porte_fenetre_coulissante',
      'coulissant',
      'coulissant_2_vantaux',
      'coulissant_3_vantaux',
      'galandage',
      'porte_entree',
      'porte_monobloc',
      'bloc_porte',
    ],
    'volets': [
      'volet_roulant',
      'volet_roulant_monobloc',
      'volet_roulant_traditionnel',
      'volet_battant',
      'volet_battant_plein',
      'volet_battant_persienne',
      'volet_mixte',
    ],
    'stores': [
      'store_toile',
      'store_banne',
      'store_coffre',
      'store_vertical',
      'store_interieur_venitien',
      'store_rouleau',
      'store_bandes_verticales',
    ],
    'protections_autres': [
      'moustiquaire',
      'porte_garage_enroulable',
      'porte_garage_sectionnelle',
      'porte_garage_basculante',
      'portail',
      'motorisation',
    ],
  },
  'materiaux': [
    'aluminium',
    'pvc',
    'bois',
    'mixte',
    'acier',
  ],
  'specifications': {
    'menuiseries': [
      'frappe',
      'oscillo_battant',
      'coulissant',
      'fixe',
      'galandage',
      'soufflet',
    ],
  },
  'couleurs': {
    'ral': [
      '7016',
      '9016',
      '9005',
      '7021',
      '7035',
      '8014',
    ],
    'finitions': [
      'texture_sable',
      'finition_satinee',
      'finition_brillante',
      'bi_color',
      'interieur',
      'exterieur',
      'akzonobel',
    ],
  },
  'dimensions_termes': [
    'largeur_hauteur',
    'hauteur_largeur',
    'lg_ht',
    'ht_lg',
    'hors_tout',
    'tableau',
    'dimensions_tableau',
    'dimensions_coffre',
    'profondeur',
    'epaisseur',
    'clair_de_jour',
    'entre_coulisses',
    'dos_coulisses',
    'sous_coffre',
    'coffre_compris',
    'bavette',
    'couvre_joints',
    'corniere',
    'appui_fenetre',
    'habillage_interieur',
    'habillage_exterieur',
  ],
  'performances': {
    'thermiques': [
      'uw',
      'ug',
      'uf',
      'rupture_pont_thermique',
      'double_vitrage',
      'triple_vitrage',
      'itr',
      'vir',
    ],
    'phoniques': [
      'rw',
      'db',
    ],
    'vitrages': [
      'depolie',
      'feuillete',
      'securit',
      'sable',
      'anti_effraction',
    ],
  },
  'accessoires_options': [
    'poignee',
    'cremone',
    'barillet',
    'serrure',
    'ferrures',
    'oscillo_battant',
    'aeration',
    'grille_ventilation',
    'motorisation',
    'somfy',
    'telecommande',
    'coffre',
    'coulisses',
    'lame_finale',
    'tablier',
  ],
  'travaux_prestations': [
    'depose_totale',
    'depose_partielle',
    'renovation',
    'fourniture',
    'fourniture_pose',
    'pose_renovation',
    'pose_neuf',
    'reglages',
    'etancheite',
    'silicone',
    'joint_compriband',
    'habillages',
    'reprise_enduit',
  ],
  'administratif': [
    'reference_produit',
    'gamme',
    'modele',
    'date_devis',
    'pu_ht',
    'total_ht',
    'total_ttc',
    'tva_10',
    'tva_20',
    'garantie',
    'certification_ce',
    'nf',
    'rt2012',
    're2020',
  ],
};

class QuoteKeywordResult {
  QuoteKeywordResult(this.matches);

  /// Map <chemin_categorie, mots-clés trouvés>.
  final Map<String, List<String>> matches;

  bool get isEmpty => matches.isEmpty;
}

class QuoteKeywordAnalyzer {
  static final List<_KeywordEntry> _entries = _flattenCatalog();

  /// Extrait les mots-clés présents dans [text] en s’appuyant sur le catalogue.
  static QuoteKeywordResult analyze(String text) {
    final normalized = _normalize(text);
    final Map<String, List<String>> hits = SplayTreeMap();

    for (final entry in _entries) {
      if (entry.pattern.hasMatch(normalized)) {
        hits.putIfAbsent(entry.path, () => []).add(entry.term);
      }
    }

    return QuoteKeywordResult(hits);
  }

  static String _normalize(String input) {
    final lower = input.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^\w\s]'), ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<_KeywordEntry> _flattenCatalog() {
    final List<_KeywordEntry> result = [];

    void walk(dynamic node, List<String> path) {
      if (node is List) {
        for (final term in node) {
          final fullPath = [...path];
          result.add(
            _KeywordEntry(
              term: term.toString(),
              path: fullPath.join('.'),
              pattern: _buildPattern(term.toString()),
            ),
          );
        }
      } else if (node is Map<String, dynamic>) {
        node.forEach((key, value) => walk(value, [...path, key]));
      }
    }

    walk(_keywordCatalog, []);
    return result;
  }

  static RegExp _buildPattern(String term) {
    final safe = term.replaceAll('_', '[ _-]?');
    return RegExp('\\b$safe\\b', caseSensitive: false);
  }
}

class _KeywordEntry {
  _KeywordEntry({
    required this.term,
    required this.path,
    required this.pattern,
  });

  final String term;
  final String path;
  final RegExp pattern;
}
