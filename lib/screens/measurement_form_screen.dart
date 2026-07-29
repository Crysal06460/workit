import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/dictionary_service.dart';

const Color _bg = Color(0xFF07090D);
const Color _accent = Color(0xFF00E676); // Metreur Green
const Color _cardBg = Color(0xFF13161C);

// PDF accent color matching WorkIt branding
final _pdfAccent = PdfColor.fromHex('#00F795');
const _pdfGrey = PdfColors.grey200;
const _pdfDarkGrey = PdfColors.grey600;
const _pdfBlack = PdfColors.black;

class MeasurementFormScreen extends StatefulWidget {
  const MeasurementFormScreen({super.key, required this.draftData, this.initialIndex = 0});

  final Map<String, dynamic> draftData;
  final int initialIndex;

  @override
  State<MeasurementFormScreen> createState() => _MeasurementFormScreenState();
}

class _MeasurementFormScreenState extends State<MeasurementFormScreen> {
  PageController? _pageControllerCached;
  PageController get _pageController => _pageControllerCached ??= PageController(initialPage: _currentIndex);

  List<Map<String, dynamic>>? _productsCached;
  List<Map<String, dynamic>> get _products => _productsCached ??=
      (widget.draftData['products'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();

  late int _currentIndex;
  bool _generating = false;
  bool _loadingFields = true;

  /// Champs de métré résolus (dictionnaire) par index de produit — `null`
  /// tant que non chargés, ou si le produit n'a pas de métier/catégorie
  /// reconnue (repli sur le footer générique uniquement).
  final Map<int, MetreCategoryFields?> _fieldDefs = {};

  // Valeurs saisies par produit, indexées par clé de champ (celles du
  // dictionnaire + les clés universelles 'couleur'/'quantite'/'ref'/'note').
  final Map<int, Map<String, String>> _measurements = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // Initialise les valeurs déjà saisies à partir des données existantes du
    // produit — générique : reprend telle quelle toute valeur déjà stockée.
    final products = (widget.draftData['products'] as List<dynamic>? ?? []);
    const nonMeasurementKeys = {
      'metierKey', 'categoryKey', 'sousCategorie', 'typeProduit', 'variante',
      'couleurDetail', 'largeur', 'hauteur', 'unite', '_splitRef',
    };
    for (int i = 0; i < products.length; i++) {
      final p = products[i] as Map<String, dynamic>;
      final values = <String, String>{
        'couleur': p['couleur']?.toString() ?? '',
        'quantite': p['quantite']?.toString() ?? '1',
        'ref': p['ref']?.toString() ?? '',
        'note': p['note']?.toString() ?? '',
      };
      for (final entry in p.entries) {
        if (nonMeasurementKeys.contains(entry.key) || values.containsKey(entry.key)) continue;
        if (entry.value == null) continue;
        values[entry.key] = entry.value.toString();
      }
      _measurements[i] = values;
    }
    _loadFieldDefs(products);
  }

  Future<void> _loadFieldDefs(List<dynamic> products) async {
    for (int i = 0; i < products.length; i++) {
      final p = products[i] as Map<String, dynamic>;
      final metierKey = p['metierKey']?.toString();
      final categoryKey = p['categoryKey']?.toString();
      if (metierKey == null || categoryKey == null) {
        _fieldDefs[i] = null;
        continue;
      }
      _fieldDefs[i] = await DictionaryService.instance.metreFieldsFor(metierKey, categoryKey);
    }
    if (mounted) setState(() => _loadingFields = false);
  }

  @override
  void dispose() {
    _pageControllerCached?.dispose();
    super.dispose();
  }

  void _splitProduct(int index) {
    final product = _products[index];
    final qty = (product['quantite'] is int)
        ? product['quantite'] as int
        : int.tryParse(product['quantite']?.toString() ?? '1') ?? 1;
    if (qty <= 1) return;

    final baseName = product['typeProduit']?.toString() ?? 'Élément';
    final copies = List.generate(qty, (i) => {
      ...product,
      'quantite': 1,
      '_splitRef': '$baseName ${i + 1}/$qty',
    });

    // Shift measurements after index to make room for new pages
    final shifted = <int, Map<String, String>>{};
    _measurements.forEach((key, value) {
      if (key < index) {
        shifted[key] = value;
      } else if (key == index) {
        shifted[index] = value; // first copy keeps original measurements
      } else {
        shifted[key + qty - 1] = value;
      }
    });
    _measurements.clear();
    _measurements.addAll(shifted);

    _productsCached!.removeAt(index);
    _productsCached!.insertAll(index, copies);

    _pageControllerCached?.dispose();
    _pageControllerCached = null;

    setState(() {
      _currentIndex = index;
    });
  }

  void _updateMeasurement(int index, String key, String value) {
    setState(() {
      if (!_measurements.containsKey(index)) {
        _measurements[index] = {};
      }
      _measurements[index]![key] = value;
    });
  }

  // ---------------------------------------------------------------------------
  // PDF helpers
  // ---------------------------------------------------------------------------

  /// Fusionne les données de _products avec _measurements pour avoir le plus
  /// à jour possible. Générique : chaque clé de mesure (dictionnaire ou
  /// universelle) s'écrit directement sous son propre nom sur le produit.
  List<Map<String, dynamic>> _buildProductsWithMeasurements() {
    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < _products.length; i++) {
      final base = Map<String, dynamic>.from(_products[i]);
      final m = _measurements[i];
      if (m != null) {
        m.forEach((key, value) {
          if (value.isEmpty) return;
          if (key == 'quantite') {
            base['quantite'] = int.tryParse(value) ?? base['quantite'];
          } else {
            base[key] = value;
          }
        });
      }
      result.add(base);
    }
    return result;
  }

  String _fmt(dynamic value, {String fallback = '—'}) {
    if (value == null) return fallback;
    final s = value.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  String _today() {
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final mo = now.month.toString().padLeft(2, '0');
    return '$d/${mo}/${now.year}';
  }

  // -- Section builders --

  pw.Widget _buildPdfHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: _pdfAccent,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'WorkIt',
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'BON DE COMMANDE — MÉTRÉ',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Date : ${_today()}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _pdfAccent,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _pdfDarkGrey,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfClientSection() {
    final d = widget.draftData;
    final firstName = _fmt(d['clientFirstName']);
    final lastName = _fmt(d['clientName']);
    final fullName = (firstName == '—' && lastName == '—')
        ? '—'
        : [if (firstName != '—') firstName, if (lastName != '—') lastName].join(' ');

    final street = _fmt(d['street']);
    final postal = _fmt(d['postal']);
    final city = _fmt(d['city']);
    final addressParts = [
      if (street != '—') street,
      if (postal != '—' || city != '—') '${postal != '—' ? postal : ''} ${city != '—' ? city : ''}'.trim(),
    ];
    final address = addressParts.isEmpty ? '—' : addressParts.join(', ');

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _pdfGrey,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Client'),
          _buildInfoRow('Nom', fullName),
          _buildInfoRow('Adresse', address),
          _buildInfoRow('Téléphone', _fmt(d['phone'])),
          _buildInfoRow('Email', _fmt(d['email'])),
        ],
      ),
    );
  }

  pw.Widget _buildPdfChantierSection() {
    final d = widget.draftData;
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _pdfGrey,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Chantier'),
          _buildInfoRow('Type de chantier', _fmt(d['chantierType'])),
          _buildInfoRow('Type d\'habitation', _fmt(d['typeHabitation'])),
          _buildInfoRow('Accessibilité', _fmt(d['accessibilite'])),
          if (_fmt(d['chantierNotes']) != '—')
            _buildInfoRow('Notes commerciales', _fmt(d['chantierNotes'])),
          if (_fmt(d['commentaire']) != '—')
            _buildInfoRow('Commentaire', _fmt(d['commentaire'])),
        ],
      ),
    );
  }

  pw.Widget _buildPdfElementsSection(List<Map<String, dynamic>> products) {
    final elements = <pw.Widget>[
      _buildSectionTitle('Éléments — ${products.length} article(s)'),
    ];

    for (int i = 0; i < products.length; i++) {
      final p = products[i];
      final isEven = i % 2 == 0;
      final bgColor = isEven ? PdfColors.white : _pdfGrey;

      // Build type string
      final typeParts = [
        _fmt(p['categoryKey']),
        _fmt(p['typeProduit']),
        _fmt(p['sousCategorie']),
        _fmt(p['variante']),
      ].where((s) => s != '—').toList();
      final typeStr = typeParts.isEmpty ? '—' : typeParts.join(' > ');

      // Couleur
      final couleur = _fmt(p['couleur']);
      final couleurDetail = _fmt(p['couleurDetail']);
      final couleurStr = couleur == '—'
          ? '—'
          : (couleurDetail != '—' ? '$couleur ($couleurDetail)' : couleur);

      // Dimensions prévues
      final lPrev = _fmt(p['largeur']);
      final hPrev = _fmt(p['hauteur']);
      final unite = _fmt(p['unite'], fallback: 'mm');
      final prevStr = (lPrev == '—' && hPrev == '—')
          ? '—'
          : '${lPrev == '—' ? '?' : lPrev} x ${hPrev == '—' ? '?' : hPrev} $unite';

      // Champs de métré spécifiques au métier/catégorie (dictionnaire),
      // affichés génériquement avec leur libellé ; repli sur la clé brute
      // si la catégorie n'a pas (ou plus) de définition connue.
      final fieldDef = _fieldDefs[i];
      final metreRows = <pw.Widget>[];
      if (fieldDef != null) {
        for (final field in fieldDef.fields) {
          final value = p[field.key];
          if (value == null || value.toString().trim().isEmpty) continue;
          final unitSuffix = field.unit != null ? ' ${field.unit}' : '';
          metreRows.add(_buildInfoRow(field.label, '$value$unitSuffix'));
        }
      }

      // Note & ref
      final note = _fmt(p['note']);
      final ref = _fmt(p['ref']);
      final qty = _fmt(p['quantite']);

      elements.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: bgColor,
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Element header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Élément ${i + 1}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _pdfAccent,
                    ),
                  ),
                  if (ref != '—')
                    pw.Text(
                      ref,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontStyle: pw.FontStyle.italic,
                        color: _pdfDarkGrey,
                      ),
                    ),
                ],
              ),
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              // Type
              _buildInfoRow('Type', typeStr),
              _buildInfoRow('Couleur', couleurStr),
              _buildInfoRow('Dim. prévues', prevStr),
              // Champs de métré spécifiques (dimensions réelles, couvre-joints,
              // ou tout autre champ propre au métier/catégorie)
              ...metreRows,
              _buildInfoRow('Quantité', qty),
              if (note != '—') _buildInfoRow('Note métreur', note),
            ],
          ),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: elements,
    );
  }

  pw.Widget _buildPdfFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _pdfGrey,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Document généré par WorkIt le ${_today()}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Text(
                'Visa métreur :',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(width: 120),
              pw.Container(
                width: 150,
                height: 1,
                color: PdfColors.black,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndPrintPdf() async {
    setState(() => _generating = true);
    try {
      final pdf = pw.Document();
      final allProducts = _buildProductsWithMeasurements();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            _buildPdfHeader(),
            pw.SizedBox(height: 20),
            _buildPdfClientSection(),
            pw.SizedBox(height: 16),
            _buildPdfChantierSection(),
            pw.SizedBox(height: 16),
            _buildPdfElementsSection(allProducts),
            pw.SizedBox(height: 24),
            _buildPdfFooter(),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'bon_commande_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Prise de mesure (${_currentIndex + 1}/${_products.length})',
          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          if (_generating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.print_outlined, color: Colors.white70),
              onPressed: _generateAndPrintPdf,
            ),
        ],
      ),
      body: SafeArea(
        child: _loadingFields
            ? const Center(child: CircularProgressIndicator(color: _accent))
            : Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _products.length,
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                itemBuilder: (context, index) {
                  final product = _products[index];
                  final qty = (product['quantite'] is int)
                      ? product['quantite'] as int
                      : int.tryParse(product['quantite']?.toString() ?? '1') ?? 1;
                  final isSplit = product['_splitRef'] != null;
                  return _MeasurementEditor(
                    product: product,
                    index: index,
                    fields: _fieldDefs[index],
                    measurements: _measurements[index] ?? {},
                    onUpdate: (key, val) => _updateMeasurement(index, key, val),
                    onSplit: (qty > 1 && !isSplit) ? () => _splitProduct(index) : null,
                  );
                },
              ),
            ),
            _BottomNav(
              total: _products.length,
              current: _currentIndex,
              onNext: () {
                if (_currentIndex < _products.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else {
                  // Retourne les produits avec toutes les mesures fusionnées
                  // (générique : voir _buildProductsWithMeasurements).
                  Navigator.of(context).pop(_buildProductsWithMeasurements());
                }
              },
              onPrev: () {
                if (_currentIndex > 0) {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

MetreFieldDef? _findField(List<MetreFieldDef> fields, String key) {
  for (final f in fields) {
    if (f.key == key) return f;
  }
  return null;
}

/// Éditeur de métré générique : rend soit le schéma visuel (ouvertures
/// menuiserie avec couvre-joints), soit une liste de champs adaptée au
/// métier/catégorie du produit — piloté par [fields] (dictionnaire).
class _MeasurementEditor extends StatelessWidget {
  const _MeasurementEditor({
    required this.product,
    required this.index,
    required this.fields,
    required this.measurements,
    required this.onUpdate,
    this.onSplit,
  });

  final Map<String, dynamic> product;
  final int index;
  final MetreCategoryFields? fields;
  final Map<String, String> measurements;
  final Function(String, String) onUpdate;
  final VoidCallback? onSplit;

  Widget _buildGenericField(MetreFieldDef field) {
    final value = measurements[field.key];
    switch (field.type) {
      case 'dropdown':
        return _GenericDropdownField(
          label: field.label,
          value: value,
          choices: field.choices,
          onChanged: (v) => onUpdate(field.key, v ?? ''),
        );
      case 'boolean':
        return _GenericSwitchField(
          label: field.label,
          value: value == 'true',
          onChanged: (v) => onUpdate(field.key, v.toString()),
        );
      case 'number':
        return _FooterInput(
          label: field.unit != null ? '${field.label} (${field.unit})' : field.label,
          hint: field.unit ?? 'Ex: 0',
          value: value,
          keyboardType: TextInputType.number,
          onChanged: (v) => onUpdate(field.key, v),
        );
      default:
        return _FooterInput(
          label: field.label,
          hint: '',
          value: value,
          onChanged: (v) => onUpdate(field.key, v),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = product['typeProduit']?.toString() ?? 'Produit ${index + 1}';
    final wPrev = product['largeur']?.toString() ?? '-';
    final hPrev = product['hauteur']?.toString() ?? '-';

    final allFields = fields?.fields ?? const <MetreFieldDef>[];
    final largeurField = _findField(allFields, 'largeurReelle');
    final hauteurField = _findField(allFields, 'hauteurReelle');
    final cjHaut = _findField(allFields, 'cjHaut');
    final cjBas = _findField(allFields, 'cjBas');
    final cjGauche = _findField(allFields, 'cjGauche');
    final cjDroite = _findField(allFields, 'cjDroite');
    final hasCj = cjHaut != null || cjBas != null || cjGauche != null || cjDroite != null;
    final isSchematic = fields?.render == 'schematic_ouverture' &&
        largeurField != null &&
        hauteurField != null &&
        hasCj;

    final schematicKeys = {'largeurReelle', 'hauteurReelle', 'cjHaut', 'cjBas', 'cjGauche', 'cjDroite'};
    final otherFields = isSchematic
        ? allFields.where((f) => !schematicKeys.contains(f.key)).toList()
        : allFields;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final double frameSize = w < 400 ? 180 : 240;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(isSchematic ? Icons.window : Icons.build_outlined, color: _accent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Prévu: $wPrev x $hPrev mm',
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                            if ((product['_splitRef'] as String?) != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                product['_splitRef'] as String,
                                style: const TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (onSplit != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onSplit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.call_split, color: Colors.orangeAccent, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Scinder ×${product['quantite']}',
                                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (isSchematic) ...[
                  // Schematic View Container (Frame + CJs)
                  SizedBox(
                    height: 360,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Central Frame Visual with Note
                        Container(
                          width: frameSize,
                          height: frameSize,
                          decoration: BoxDecoration(
                            color: _cardBg,
                            border: Border.all(color: Colors.white24, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('NOTE',
                                    style: TextStyle(
                                        color: Colors.white30,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10)),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: TextField(
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      hintText: 'Ajouter une note...',
                                      hintStyle: TextStyle(color: Colors.white12),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                    onChanged: (v) => onUpdate('note', v),
                                    controller: TextEditingController(text: measurements['note'])
                                      ..selection = TextSelection.collapsed(
                                          offset: measurements['note']?.length ?? 0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (cjHaut != null)
                          Positioned(
                            top: 0,
                            child: _SchematicInput(
                              label: 'CJ Haut',
                              value: measurements['cjHaut'],
                              onChanged: (v) => onUpdate('cjHaut', v),
                            ),
                          ),
                        if (cjBas != null)
                          Positioned(
                            bottom: 0,
                            child: _SchematicInput(
                              label: 'CJ Bas',
                              value: measurements['cjBas'],
                              onChanged: (v) => onUpdate('cjBas', v),
                            ),
                          ),
                        if (cjGauche != null)
                          Positioned(
                            left: 0,
                            child: _SchematicInput(
                              label: 'CJ Gauche',
                              value: measurements['cjGauche'],
                              onChanged: (v) => onUpdate('cjGauche', v),
                            ),
                          ),
                        if (cjDroite != null)
                          Positioned(
                            right: 0,
                            child: _SchematicInput(
                              label: 'CJ Droite',
                              value: measurements['cjDroite'],
                              onChanged: (v) => onUpdate('cjDroite', v),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Main Dimensions Row (Width & Height below the frame)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _MainDimensionInput(
                          label: 'Largeur',
                          value: measurements['largeurReelle'],
                          onChanged: (v) => onUpdate('largeurReelle', v),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _MainDimensionInput(
                          label: 'Hauteur',
                          value: measurements['hauteurReelle'],
                          onChanged: (v) => onUpdate('hauteurReelle', v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ] else if (allFields.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Aucun champ de métré spécifique pour cet élément — utilisez la note ci-dessous.',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),

                // Champs spécifiques au métier/catégorie (liste générique),
                // ou champs restants après le schéma visuel.
                for (final field in otherFields) ...[
                  _buildGenericField(field),
                  const SizedBox(height: 14),
                ],

                const SizedBox(height: 6),
                // Footer universel (toutes catégories)
                Row(
                  children: [
                    Expanded(child: _FooterInput(label: 'Couleur', hint: 'Ex: RAL 9010', value: measurements['couleur'], onChanged: (v) => onUpdate('couleur', v))),
                    const SizedBox(width: 12),
                    Expanded(child: _FooterInput(label: 'Quantité', hint: 'Ex: 1', value: measurements['quantite'], keyboardType: TextInputType.number, onChanged: (v) => onUpdate('quantite', v))),
                  ],
                ),
                const SizedBox(height: 12),
                _FooterInput(label: 'Référence / Emplacement', hint: 'Ex: Salon fenêtre gauche', value: measurements['ref'], onChanged: (v) => onUpdate('ref', v)),
                if (!isSchematic) ...[
                  const SizedBox(height: 12),
                  _FooterInput(label: 'Note', hint: 'Remarque libre pour ce chantier', value: measurements['note'], onChanged: (v) => onUpdate('note', v)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SchematicInput extends StatelessWidget {
  const _SchematicInput({required this.label, required this.onChanged, this.value});
  final String label;
  final ValueChanged<String> onChanged;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: value)
      ..selection = TextSelection.collapsed(offset: value?.length ?? 0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Container(
          width: 60,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextField(
            controller: controller,
             onChanged: onChanged,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 13),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(bottom: 14), // Center vertically roughly
            ),
          ),
        ),
      ],
    );
  }
}

class _MainDimensionInput extends StatelessWidget {
   const _MainDimensionInput({required this.label, required this.onChanged, this.value});
  final String label;
  final ValueChanged<String> onChanged;
  final String? value;

  @override
  Widget build(BuildContext context) {
     final controller = TextEditingController(text: value)
      ..selection = TextSelection.collapsed(offset: value?.length ?? 0);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 2)),
        ]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(label.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
           const SizedBox(height: 4),
           SizedBox(
             width: 80,
             height: 24,
             child: TextField(
                controller: controller,
                onChanged: onChanged,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '0',
                  hintStyle: TextStyle(color: Colors.white12),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
             ),
           ),
        ],
      ),
    );
  }
}

class _FooterInput extends StatelessWidget {
  const _FooterInput({
    required this.label,
    required this.hint,
    required this.onChanged,
    this.value,
    this.keyboardType = TextInputType.text,
  });
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
  final String? value;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
       final controller = TextEditingController(text: value)
      ..selection = TextSelection.collapsed(offset: value?.length ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
             border: Border.all(color: Colors.white12),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white24),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _GenericDropdownField extends StatelessWidget {
  const _GenericDropdownField({
    required this.label,
    required this.choices,
    required this.onChanged,
    this.value,
  });

  final String label;
  final List<String> choices;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveValue = (value != null && choices.contains(value)) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effectiveValue,
              isExpanded: true,
              dropdownColor: _cardBg,
              hint: const Text('Choisir…', style: TextStyle(color: Colors.white24)),
              style: const TextStyle(color: Colors.white),
              items: choices
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _GenericSwitchField extends StatelessWidget {
  const _GenericSwitchField({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          Switch(
            value: value,
            activeColor: _accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.total,
    required this.current,
    required this.onNext,
    required this.onPrev,
  });

  final int total;
  final int current;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  @override
  Widget build(BuildContext context) {
    final isLast = current == total - 1;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bg,
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          if (current > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast ? _accent : Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: onNext,
              child: Text(
                isLast ? 'Terminer et Valider' : 'Suivant',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
