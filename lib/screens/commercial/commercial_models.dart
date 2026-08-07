part of 'commercial_home_screen.dart';

const Object _unset = Object();

class _ProductFormData {
  const _ProductFormData({
    this.metierKey,
    this.categoryKey,
    this.sousCategorie,
    this.typeProduit,
    this.variante,
    this.couleur,
    this.couleurDetail,
    this.largeur,
    this.hauteur,
    this.quantite,
    this.unite = 'mm',
  });

  /// Métier choisi pour CET élément du devis (ex: 'menuiserie_aluminium',
  /// 'plomberie_sanitaire') — un devis peut mélanger plusieurs métiers,
  /// un par élément.
  final String? metierKey;
  final String? categoryKey;
  final String? sousCategorie;
  final String? typeProduit;
  final String? variante;
  final String? couleur;
  final String? couleurDetail;
  final int? largeur;
  final int? hauteur;
  final int? quantite;
  final String unite;

  // Sentinel qui distingue "paramètre non fourni" (garder l'ancienne valeur)
  // de "null fourni explicitement" (réinitialiser le champ) — un simple `??`
  // ne peut pas faire cette distinction et ignorait silencieusement les
  // resets explicites (ex: categoryKey: null lors d'un changement de métier).
  _ProductFormData copyWith({
    Object? metierKey = _unset,
    Object? categoryKey = _unset,
    Object? sousCategorie = _unset,
    Object? typeProduit = _unset,
    Object? variante = _unset,
    Object? couleur = _unset,
    Object? couleurDetail = _unset,
    Object? largeur = _unset,
    Object? hauteur = _unset,
    Object? quantite = _unset,
    Object? unite = _unset,
  }) {
    return _ProductFormData(
      metierKey: identical(metierKey, _unset) ? this.metierKey : metierKey as String?,
      categoryKey: identical(categoryKey, _unset) ? this.categoryKey : categoryKey as String?,
      sousCategorie: identical(sousCategorie, _unset) ? this.sousCategorie : sousCategorie as String?,
      typeProduit: identical(typeProduit, _unset) ? this.typeProduit : typeProduit as String?,
      variante: identical(variante, _unset) ? this.variante : variante as String?,
      couleur: identical(couleur, _unset) ? this.couleur : couleur as String?,
      couleurDetail: identical(couleurDetail, _unset) ? this.couleurDetail : couleurDetail as String?,
      largeur: identical(largeur, _unset) ? this.largeur : largeur as int?,
      hauteur: identical(hauteur, _unset) ? this.hauteur : hauteur as int?,
      quantite: identical(quantite, _unset) ? this.quantite : quantite as int?,
      unite: identical(unite, _unset) ? this.unite : (unite as String?) ?? this.unite,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'metierKey': metierKey,
      'categoryKey': categoryKey,
      'sousCategorie': sousCategorie,
      'typeProduit': typeProduit,
      'variante': variante,
      'couleur': couleur,
      'couleurDetail': couleurDetail,
      'largeur': largeur,
      'hauteur': hauteur,
      'quantite': quantite,
      'unite': unite,
    };
  }

  factory _ProductFormData.fromMap(Map<String, dynamic> map) {
    return _ProductFormData(
      metierKey: map['metierKey']?.toString(),
      categoryKey: map['categoryKey']?.toString(),
      sousCategorie: map['sousCategorie']?.toString(),
      typeProduit: map['typeProduit']?.toString(),
      variante: map['variante']?.toString(),
      couleur: map['couleur']?.toString(),
      couleurDetail: map['couleurDetail']?.toString(),
      largeur: map['largeur'] is int ? map['largeur'] as int : int.tryParse(map['largeur']?.toString() ?? ''),
      hauteur: map['hauteur'] is int ? map['hauteur'] as int : int.tryParse(map['hauteur']?.toString() ?? ''),
      quantite: map['quantite'] is int ? map['quantite'] as int : int.tryParse(map['quantite']?.toString() ?? ''),
      unite: map['unite']?.toString() ?? 'mm',
    );
  }
}

class _QuoteDraft {
  const _QuoteDraft({
    this.clientName,
    this.clientFirstName,
    this.street,
    this.postal,
    this.city,
    this.phone,
    this.email,
    this.commentaire,
    this.chantierNotes,
    this.chantierType,
    this.typeHabitation,
    this.accessibilite,
    this.date,
    this.products = const [],
    this.assignedMetreurId,
    this.assignedMetreurName,
  });

  final String? clientName;
  final String? clientFirstName;
  final String? street;
  final String? postal;
  final String? city;
  final String? phone;
  final String? email;
  final String? commentaire;
  final String? chantierNotes;
  final String? chantierType;
  final String? typeHabitation;
  final String? accessibilite;
  final DateTime? date;
  final List<_ProductFormData> products;
  final String? assignedMetreurId;
  final String? assignedMetreurName;

  Map<String, dynamic> toMap() {
    return {
      'clientName': clientName,
      'clientFirstName': clientFirstName,
      'street': street,
      'postal': postal,
      'city': city,
      'phone': phone,
      'email': email,
      'commentaire': commentaire,
      'chantierNotes': chantierNotes,
      'chantierType': chantierType,
      'typeHabitation': typeHabitation,
      'accessibilite': accessibilite,
      'date': date?.toIso8601String(),
      'products': products.map((e) => e.toMap()).toList(),
      'assignedMetreurId': assignedMetreurId,
      'assignedMetreurName': assignedMetreurName,
    };
  }

  factory _QuoteDraft.fromMap(Map<String, dynamic> map) {
    return _QuoteDraft(
      clientName: map['clientName']?.toString(),
      clientFirstName: map['clientFirstName']?.toString(),
      street: map['street']?.toString(),
      postal: map['postal']?.toString(),
      city: map['city']?.toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      commentaire: map['commentaire']?.toString(),
      chantierNotes: map['chantierNotes']?.toString(),
      chantierType: map['chantierType']?.toString(),
      typeHabitation: map['typeHabitation']?.toString(),
      accessibilite: map['accessibilite']?.toString(),
      date: map['date'] != null ? DateTime.tryParse(map['date'].toString()) : null,
      products: map['products'] is List
          ? (map['products'] as List)
              .map((e) {
                if (e is Map<String, dynamic>) return _ProductFormData.fromMap(e);
                if (e is Map) return _ProductFormData.fromMap(Map<String, dynamic>.from(e));
                return null;
              })
              .whereType<_ProductFormData>()
              .toList()
          : const [],
      assignedMetreurId: map['assignedMetreurId']?.toString(),
      assignedMetreurName: map['assignedMetreurName']?.toString(),
    );
  }
}

class _Choice {
  const _Choice(this.key, this.label);
  final String key;
  final String label;
}

class _MetreurOption {
  const _MetreurOption({required this.id, required this.name, required this.email});
  final String id;
  final String name;
  final String? email;
}

class _QuoteItem {
  const _QuoteItem({
    required this.client,
    required this.address,
    required this.number,
    required this.date,
    required this.tag,
    this.assignedMetreurId,
    this.assignedMetreurName,
    this.draft,
    this.id,
    this.createdAt,
    this.updatedAt,
    this.uploadUrl,
    this.status,
    this.phone,
    this.email,
    this.clientFirstName,
    this.poseurNames,
    this.poseDate,
    this.rapportFin,
    this.rapportProbleme,
    this.infoRequest,
    this.meetingAt,
    this.metreurNote,
    this.metreurNoteName,
    this.lotsSummary = const [],
  });

  final String client;
  final String address;
  final String number;
  final String date;
  final String tag;
  final String? assignedMetreurId;
  final String? assignedMetreurName;
  final _QuoteDraft? draft;
  final String? id;
  final DateTime? createdAt;
  // Section "chantiers récemment ajoutés" (écran d'accueil) : dernière
  // transition de statut, déjà écrite côté serveur par transitionDevisStatus,
  // simplement lue ici (aucune écriture cliente).
  final DateTime? updatedAt;
  final String? uploadUrl;
  final String? status;
  final String? phone;
  final String? email;
  final String? clientFirstName;
  final String? poseurNames;
  final DateTime? poseDate;
  final Map<String, dynamic>? rapportFin;
  final Map<String, dynamic>? rapportProbleme;
  final Map<String, dynamic>? infoRequest;
  final DateTime? meetingAt;
  final String? metreurNote;
  final String? metreurNoteName;
  // Phase 3/5 : dénormalisation des lots d'un devis multi-métier (statut,
  // rapport... par lot) — vide pour un devis sans lot.
  final List<Map<String, dynamic>> lotsSummary;

  _QuoteItem copyWith({
    String? client,
    String? address,
    String? number,
    String? date,
    String? tag,
    String? assignedMetreurId,
    String? assignedMetreurName,
    _QuoteDraft? draft,
    String? id,
    DateTime? createdAt,
    String? uploadUrl,
    String? status,
    String? phone,
    String? email,
    String? clientFirstName,
    String? poseurNames,
    DateTime? poseDate,
    Map<String, dynamic>? rapportFin,
    Map<String, dynamic>? rapportProbleme,
    Map<String, dynamic>? infoRequest,
  }) {
    return _QuoteItem(
      client: client ?? this.client,
      address: address ?? this.address,
      number: number ?? this.number,
      date: date ?? this.date,
      tag: tag ?? this.tag,
      assignedMetreurId: assignedMetreurId ?? this.assignedMetreurId,
      assignedMetreurName: assignedMetreurName ?? this.assignedMetreurName,
      draft: draft ?? this.draft,
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      uploadUrl: uploadUrl ?? this.uploadUrl,
      status: status ?? this.status,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      clientFirstName: clientFirstName ?? this.clientFirstName,
      poseurNames: poseurNames ?? this.poseurNames,
      poseDate: poseDate ?? this.poseDate,
      rapportFin: rapportFin ?? this.rapportFin,
      rapportProbleme: rapportProbleme ?? this.rapportProbleme,
      infoRequest: infoRequest ?? this.infoRequest,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client': client,
      'address': address,
      'number': number,
      'date': date,
      'tag': tag,
      'assignedMetreurId': assignedMetreurId,
      'assignedMetreurName': assignedMetreurName,
      'draft': draft?.toMap(),
      'createdAt': createdAt?.toIso8601String(),
      'uploadUrl': uploadUrl,
      'status': status,
    };
  }

  factory _QuoteItem.fromMap(Map<String, dynamic> map) {
    DateTime? poseDate;
    if (map['poseDate'] is Timestamp) {
      poseDate = (map['poseDate'] as Timestamp).toDate();
    }
    return _QuoteItem(
      id: map['id']?.toString(),
      client: map['client']?.toString() ?? 'Client',
      address: map['address']?.toString() ?? '',
      number: map['number']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      tag: map['tag']?.toString() ?? '',
      assignedMetreurId: map['assignedMetreurId']?.toString(),
      assignedMetreurName: map['assignedMetreurName']?.toString(),
      draft: map['draft'] is Map<String, dynamic>
          ? _QuoteDraft.fromMap(map['draft'] as Map<String, dynamic>)
          : null,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : (map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'].toString())
              : null),
      updatedAt: map['updatedAt'] is Timestamp ? (map['updatedAt'] as Timestamp).toDate() : null,
      uploadUrl: map['uploadUrl']?.toString(),
      status: (map['status'] ?? map['metreurStatus'])?.toString(),
      phone: map['phone']?.toString() ?? map['clientPhone']?.toString(),
      email: map['email']?.toString() ?? map['clientEmail']?.toString(),
      clientFirstName: map['clientFirstName']?.toString(),
      poseurNames: map['poseurNames']?.toString(),
      poseDate: poseDate,
      rapportFin: map['rapportFin'] is Map
          ? Map<String, dynamic>.from(map['rapportFin'] as Map)
          : null,
      rapportProbleme: map['rapportProbleme'] is Map
          ? Map<String, dynamic>.from(map['rapportProbleme'] as Map)
          : null,
      infoRequest: map['infoRequest'] is Map
          ? Map<String, dynamic>.from(map['infoRequest'] as Map)
          : null,
      meetingAt: map['meetingAt'] is Timestamp
          ? (map['meetingAt'] as Timestamp).toDate()
          : null,
      metreurNote: map['metreurNote']?.toString(),
      metreurNoteName: map['metreurNoteName']?.toString(),
      lotsSummary: (map['lotsSummary'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }
}

// ─── Données de démonstration ─────────────────────────────────────────────────
final _kDemoDevis = <_QuoteItem>[
  _QuoteItem(
    client: 'Dupont Jean', address: '14 rue Ledru-Rollin, Paris 15e',
    number: '#5001', date: 'Il y a 2 jours', tag: 'Nouvelle demande', status: null,
    phone: '06 12 34 56 78', email: 'dupont@email.fr',
  ),
  _QuoteItem(
    client: 'Martin Sophie', address: '8 avenue des Arts, Lyon 3e',
    number: '#5002', date: 'Il y a 5 jours', tag: 'En cours', status: 'En cours',
    assignedMetreurName: 'Pascal M.',
    meetingAt: DateTime.now().add(const Duration(days: 2)),
  ),
  _QuoteItem(
    client: 'Bernard Marc', address: '22 quai de la Loire, Nantes',
    number: '#5003', date: 'Il y a 8 jours', tag: 'À planifier', status: 'À planifier',
    assignedMetreurName: 'Pascal M.',
  ),
  _QuoteItem(
    client: 'Laurent Céline', address: '5 impasse des Pins, Toulouse',
    number: '#5004', date: 'Il y a 10 jours', tag: 'Commande en cours', status: 'Commande en cours',
    assignedMetreurName: 'Pascal M.',
  ),
  _QuoteItem(
    client: 'Petit Thomas', address: '3 allée des Roses, Bordeaux',
    number: '#5005', date: 'Il y a 12 jours', tag: 'En pose', status: 'En pose',
    assignedMetreurName: 'Pascal M.',
    poseurNames: 'Équipe A',
    poseDate: DateTime.now(),
  ),
  _QuoteItem(
    client: 'Moreau Julie', address: '17 rue du Moulin, Strasbourg',
    number: '#5006', date: 'Il y a 20 jours', tag: 'Terminé', status: 'Terminé',
  ),
];
