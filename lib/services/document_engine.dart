import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/dictionary_service.dart';

const String _storageBucket = 'gs://workit-1daa1.firebasestorage.app';

final _pdfAccent = PdfColor.fromHex('#00F795');
const _pdfGrey = PdfColors.grey200;
const _pdfDarkGrey = PdfColors.grey600;

/// Moteur de documents générique : un modèle (`assets/dictionnaire_workit/
/// document_templates.json`) déclare une liste de sections ; ce moteur ne
/// connaît qu'un builder par *type* de section (réutilisé par tous les
/// modèles), jamais un builder par document — c'est la config qui décrit
/// chaque document, pas du code Dart dédié à chacun.
class DocumentEngine {
  DocumentEngine._();

  static Map<String, dynamic>? _templatesCache;

  static Future<Map<String, dynamic>> _loadTemplates() async {
    final cached = _templatesCache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/dictionnaire_workit/document_templates.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    _templatesCache = decoded;
    return decoded;
  }

  /// Génère le document [templateId] à partir des données du devis, l'envoie
  /// vers Firebase Storage, trace sa génération dans Firestore
  /// (`workspaces/{workspaceId}/devis/{devisId}/documents`), puis ouvre la
  /// boîte de dialogue d'impression/partage native (comportement identique à
  /// l'ancien `_generateAndPrintPdf` pour l'utilisateur).
  ///
  /// [devisData] porte les champs plats du devis (client/chantier). Les
  /// éléments à afficher viennent de [products] — laisser `null` pour
  /// utiliser `devisData['products']` tel quel (cas des documents générés
  /// après le métré, où les mesures sont déjà fusionnées sur chaque produit).
  static Future<void> generateAndShare({
    required String templateId,
    required String workspaceId,
    required String devisId,
    required Map<String, dynamic> devisData,
    required String generatedByRole,
    List<Map<String, dynamic>>? products,
  }) async {
    final templates = await _loadTemplates();
    final template = templates[templateId] as Map<String, dynamic>?;
    if (template == null) {
      throw Exception('Modèle de document inconnu : $templateId');
    }
    final version = template['version'] is int ? template['version'] as int : 1;
    final title = template['title']?.toString() ?? templateId;
    final sections = (template['sections'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final resolvedProducts = products ??
        ((devisData['products'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ??
            const <Map<String, dynamic>>[]);
    final metierKey = resolvedProducts.isNotEmpty ? resolvedProducts.first['metierKey']?.toString() : null;

    final widgets = <pw.Widget>[];
    for (final section in sections) {
      switch (section['type']?.toString()) {
        case 'header':
          widgets.add(_buildHeaderSection(title));
        case 'client':
          widgets.add(_buildClientSection(devisData));
        case 'chantier':
          widgets.add(_buildChantierSection(devisData));
        case 'elements':
          widgets.add(await _buildElementsSection(
            resolvedProducts,
            showMeasurements: section['showMeasurements'] == true,
          ));
        case 'checklist':
          widgets.add(await _buildChecklistSection(
            metierKey,
            source: section['source']?.toString() ?? '',
            title: section['title']?.toString() ?? '',
          ));
        case 'signature':
          widgets.add(_buildSignatureSection(section['label']?.toString() ?? 'Signature :'));
      }
      widgets.add(pw.SizedBox(height: 16));
    }

    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => widgets,
    ));
    final bytes = await pdf.save();

    final fileName = '${templateId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    try {
      final ref = FirebaseStorage.instanceFor(bucket: _storageBucket)
          .ref()
          .child('documents/$workspaceId/$devisId/$fileName');
      await ref.putData(bytes, SettableMetadata(contentType: 'application/pdf'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('workspaces')
          .doc(workspaceId)
          .collection('devis')
          .doc(devisId)
          .collection('documents')
          .add({
        'templateId': templateId,
        'templateVersion': version,
        'fileName': fileName,
        'storageUrl': url,
        'generatedAt': FieldValue.serverTimestamp(),
        'generatedByUid': FirebaseAuth.instance.currentUser?.uid,
        'generatedByRole': generatedByRole,
      });
    } catch (_) {
      // La traçabilité est best-effort : un échec d'upload/écriture ne doit
      // jamais empêcher l'utilisateur d'imprimer/partager son document.
    }

    await Printing.layoutPdf(onLayout: (format) async => bytes, name: fileName);
  }

  // ─── Builders par type de section (partagés entre tous les modèles) ─────

  static String _fmt(dynamic value, {String fallback = '—'}) {
    if (value == null) return fallback;
    final s = value.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static String _today() {
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final mo = now.month.toString().padLeft(2, '0');
    return '$d/$mo/${now.year}';
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _pdfAccent,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(label,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdfDarkGrey)),
          ),
          pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 9, color: PdfColors.black))),
        ],
      ),
    );
  }

  static pw.Widget _buildHeaderSection(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: _pdfAccent,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('WorkIt', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
              pw.SizedBox(height: 4),
              pw.Text('Date : ${_today()}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildClientSection(Map<String, dynamic> d) {
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
      decoration: pw.BoxDecoration(color: _pdfGrey, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
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

  static pw.Widget _buildChantierSection(Map<String, dynamic> d) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: _pdfGrey, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Chantier'),
          _buildInfoRow('Type de chantier', _fmt(d['chantierType'])),
          _buildInfoRow('Type d\'habitation', _fmt(d['typeHabitation'])),
          _buildInfoRow('Accessibilité', _fmt(d['accessibilite'])),
          if (_fmt(d['chantierNotes']) != '—') _buildInfoRow('Notes commerciales', _fmt(d['chantierNotes'])),
          if (_fmt(d['commentaire']) != '—') _buildInfoRow('Commentaire', _fmt(d['commentaire'])),
        ],
      ),
    );
  }

  static Future<pw.Widget> _buildElementsSection(
    List<Map<String, dynamic>> products, {
    required bool showMeasurements,
  }) async {
    final elements = <pw.Widget>[
      _buildSectionTitle('Éléments — ${products.length} article(s)'),
    ];

    for (int i = 0; i < products.length; i++) {
      final p = products[i];
      final isEven = i % 2 == 0;
      final bgColor = isEven ? PdfColors.white : _pdfGrey;

      final typeParts = [
        _fmt(p['categoryKey']),
        _fmt(p['typeProduit']),
        _fmt(p['sousCategorie']),
        _fmt(p['variante']),
      ].where((s) => s != '—').toList();
      final typeStr = typeParts.isEmpty ? '—' : typeParts.join(' > ');

      final couleur = _fmt(p['couleur']);
      final couleurDetail = _fmt(p['couleurDetail']);
      final couleurStr = couleur == '—' ? '—' : (couleurDetail != '—' ? '$couleur ($couleurDetail)' : couleur);

      final lPrev = _fmt(p['largeur']);
      final hPrev = _fmt(p['hauteur']);
      final unite = _fmt(p['unite'], fallback: 'mm');
      final prevStr =
          (lPrev == '—' && hPrev == '—') ? '—' : '${lPrev == '—' ? '?' : lPrev} x ${hPrev == '—' ? '?' : hPrev} $unite';

      final metreRows = <pw.Widget>[];
      if (showMeasurements) {
        final metierKey = p['metierKey']?.toString();
        final categoryKey = p['categoryKey']?.toString();
        final fieldDef = (metierKey != null && categoryKey != null)
            ? await DictionaryService.instance.metreFieldsFor(metierKey, categoryKey)
            : null;
        if (fieldDef != null) {
          for (final field in fieldDef.fields) {
            final value = p[field.key];
            if (value == null || value.toString().trim().isEmpty) continue;
            final unitSuffix = field.unit != null ? ' ${field.unit}' : '';
            metreRows.add(_buildInfoRow(field.label, '$value$unitSuffix'));
          }
        }
      }

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
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Élément ${i + 1}',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _pdfAccent)),
                  if (ref != '—')
                    pw.Text(ref, style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: _pdfDarkGrey)),
                ],
              ),
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              _buildInfoRow('Type', typeStr),
              _buildInfoRow('Couleur', couleurStr),
              _buildInfoRow('Dim. prévues', prevStr),
              ...metreRows,
              _buildInfoRow('Quantité', qty),
              if (note != '—') _buildInfoRow('Note métreur', note),
            ],
          ),
        ),
      );
    }

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: elements);
  }

  static Future<pw.Widget> _buildChecklistSection(
    String? metierKey, {
    required String source,
    required String title,
  }) async {
    List<({String key, String label})> items = const [];
    if (metierKey != null) {
      switch (source) {
        case 'preparation_steps':
          items = (await DictionaryService.instance.preparationStepsFor(metierKey))
              .map((e) => (key: e.key, label: e.label))
              .toList();
        case 'execution_checklist':
          items = (await DictionaryService.instance.executionChecklistFor(metierKey))
              .map((e) => (key: e.key, label: e.label))
              .toList();
      }
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: _pdfGrey, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(title),
          if (items.isEmpty)
            pw.Text('Aucun point de contrôle défini pour ce métier.',
                style: const pw.TextStyle(fontSize: 9, color: _pdfDarkGrey))
          else
            for (final item in items)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 3),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 10,
                      height: 10,
                      margin: const pw.EdgeInsets.only(right: 8, top: 1),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.8)),
                    ),
                    pw.Expanded(
                      child: pw.Text(item.label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatureSection(String label) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: _pdfGrey, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Document généré par WorkIt le ${_today()}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 120),
              pw.Container(width: 150, height: 1, color: PdfColors.black),
            ],
          ),
        ],
      ),
    );
  }
}
