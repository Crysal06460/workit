// WorkIt — Génère les PDF "Conditions générales de vente" et "Politique de
// confidentialité" à partir du texte ci-dessous.
//
// ⚠️ DOCUMENTS PROVISOIRES : les champs entre crochets (ex. [SIRET À
// COMPLÉTER]) doivent être renseignés avec les vraies informations légales
// de l'éditeur, et le texte doit être relu par un professionnel du droit
// avant toute publication ou usage commercial réel.
//
// Usage : dart run scripts/generate_legal_pdfs.dart
// Sortie : scripts/output/cgv.pdf et scripts/output/politique_confidentialite.pdf

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _lastUpdate = '19 août 2026';

Future<void> main() async {
  final outDir = Directory('scripts/output');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  await _writePdf(
    path: '${outDir.path}/cgv.pdf',
    title: 'Conditions générales de vente et d\'utilisation',
    sections: _cgvSections,
  );
  await _writePdf(
    path: '${outDir.path}/politique_confidentialite.pdf',
    title: 'Politique de confidentialité',
    sections: _privacySections,
  );

  stdout.writeln('OK — PDF générés dans ${outDir.path}/');
}

Future<void> _writePdf({
  required String path,
  required String title,
  required List<_Section> sections,
}) async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 56),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'WorkIt',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 2),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.SizedBox(height: 8),
        ],
      ),
      footer: (context) => pw.Column(
        children: [
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
          pw.SizedBox(height: 4),
          pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ],
      ),
      build: (context) => [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Dernière mise à jour : $_lastUpdate',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.amber50,
            border: pw.Border.all(color: PdfColors.amber200),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            'DOCUMENT PROVISOIRE — projet WorkIt. Les informations entre crochets '
            '(ex. [SIRET À COMPLÉTER]) doivent être complétées avec les données '
            'légales réelles de l\'éditeur, et ce texte doit être validé par un '
            'professionnel du droit avant toute publication ou usage commercial.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
        ),
        pw.SizedBox(height: 18),
        for (final section in sections) ...[
          pw.Text(
            section.heading,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          for (final para in section.paragraphs) ...[
            if (para.bullet)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('•  ', style: const pw.TextStyle(fontSize: 10.5)),
                    pw.Expanded(
                      child: pw.Text(para.text, style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2)),
                    ),
                  ],
                ),
              )
            else
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(para.text, style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2)),
              ),
          ],
          pw.SizedBox(height: 10),
        ],
      ],
    ),
  );

  final file = File(path);
  await file.writeAsBytes(await doc.save());
}

class _Section {
  const _Section(this.heading, this.paragraphs);
  final String heading;
  final List<_Para> paragraphs;
}

class _Para {
  const _Para(this.text, {this.bullet = false});
  final String text;
  final bool bullet;
}

// ─────────────────────────────────────────────────────────────────────────
// CONDITIONS GÉNÉRALES DE VENTE ET D'UTILISATION
// ─────────────────────────────────────────────────────────────────────────

final _cgvSections = <_Section>[
  const _Section('Article 1 — Objet', [
    _Para(
      'Les présentes conditions générales de vente et d\'utilisation (les « CGV ») ont pour objet de '
      'définir les modalités et conditions dans lesquelles [RAISON SOCIALE À COMPLÉTER] (« WorkIt », « nous ») '
      'met à disposition de ses clients professionnels (« le Client ») l\'application logicielle WorkIt, '
      'plateforme de gestion de devis, de métrés, de planification et de suivi de chantiers destinée aux '
      'entreprises du bâtiment.',
    ),
  ]),
  const _Section('Article 2 — Éditeur', [
    _Para(
      '[RAISON SOCIALE À COMPLÉTER], [FORME JURIDIQUE À COMPLÉTER], au capital de [MONTANT À COMPLÉTER], '
      'immatriculée au RCS de [VILLE À COMPLÉTER] sous le numéro [SIRET À COMPLÉTER], dont le siège social '
      'est situé [ADRESSE À COMPLÉTER], numéro de TVA intracommunautaire [À COMPLÉTER].',
    ),
  ]),
  const _Section('Article 3 — Acceptation', [
    _Para(
      'L\'accès et l\'utilisation de l\'application WorkIt impliquent l\'acceptation sans réserve des '
      'présentes CGV par le Client. Le Client déclare avoir la capacité juridique de s\'engager au nom de '
      'son entreprise.',
    ),
  ]),
  const _Section('Article 4 — Description du service', [
    _Para('WorkIt est une application permettant notamment :'),
    _Para('la création et le suivi de devis clients ;', bullet: true),
    _Para('la planification et l\'attribution des métrés et des poses ;', bullet: true),
    _Para('la gestion d\'équipes et de plannings ;', bullet: true),
    _Para(
      'l\'échange de messages liés à un chantier entre les membres autorisés d\'un même espace de travail ;',
      bullet: true,
    ),
    _Para('la génération de documents (bons de commande, bons de préparation, rapports) ;', bullet: true),
    _Para(
      'une fonctionnalité optionnelle d\'analyse automatisée par intelligence artificielle des devis déposés, '
      'destinée à faciliter la préparation des métrés (fonctionnalité soumise à un quota d\'usage et pouvant '
      'faire appel à des prestataires tiers, voir la Politique de confidentialité).',
      bullet: true,
    ),
    _Para(
      'WorkIt se réserve le droit de faire évoluer les fonctionnalités du service, sous réserve d\'en informer '
      'le Client pour toute modification substantielle.',
    ),
  ]),
  const _Section('Article 5 — Accès au service, comptes utilisateurs', [
    _Para(
      'L\'accès au service est réservé aux entreprises clientes ayant créé un espace de travail ("workspace") '
      'et à leurs collaborateurs dûment autorisés (rôles Administrateur, Commercial, Métreur, Poseur).',
    ),
    _Para(
      'Le Client, par l\'intermédiaire de son compte Administrateur, est seul responsable de la gestion des '
      'accès de ses collaborateurs, de l\'exactitude des informations renseignées et de la confidentialité '
      'des identifiants de connexion.',
    ),
    _Para(
      'WorkIt se réserve le droit de suspendre un compte en cas d\'usage non conforme aux présentes CGV ou de '
      'tentative d\'atteinte à la sécurité du service.',
    ),
  ]),
  const _Section('Article 6 — Tarifs et modalités de paiement', [
    _Para(
      'Les conditions tarifaires applicables (abonnement, période d\'essai le cas échéant) sont celles '
      'convenues séparément entre WorkIt et le Client [À COMPLÉTER — grille tarifaire, modalités de '
      'facturation et de paiement à préciser une fois le modèle commercial arrêté].',
    ),
  ]),
  const _Section('Article 7 — Durée, résiliation', [
    _Para(
      '[À COMPLÉTER — durée de l\'engagement, modalités de résiliation, préavis, effets de la résiliation '
      'sur l\'accès aux données].',
    ),
  ]),
  const _Section('Article 8 — Obligations du Client', [
    _Para('Le Client s\'engage à :'),
    _Para('utiliser le service conformément à sa destination et à la réglementation applicable ;', bullet: true),
    _Para(
      'ne saisir dans l\'application que des données dont il a le droit de disposer, notamment les données '
      'personnelles de ses propres clients, dans le respect du RGPD (le Client agissant en qualité de '
      'responsable de traitement pour ces données, WorkIt en qualité de sous-traitant — voir la Politique '
      'de confidentialité) ;',
      bullet: true,
    ),
    _Para(
      'ne pas détourner le service à des fins illicites ou porter atteinte à la sécurité de la plateforme.',
      bullet: true,
    ),
  ]),
  const _Section('Article 9 — Propriété intellectuelle', [
    _Para(
      'L\'application WorkIt, son code, sa structure, ses éléments graphiques et sa documentation sont la '
      'propriété exclusive de [RAISON SOCIALE À COMPLÉTER]. Aucune disposition des présentes CGV n\'emporte '
      'cession d\'un quelconque droit de propriété intellectuelle au profit du Client, qui bénéficie d\'un '
      'simple droit d\'usage, non exclusif et non cessible, pour la durée du contrat.',
    ),
    _Para(
      'Les données saisies par le Client (devis, informations clients, photos de chantier, etc.) restent la '
      'propriété du Client.',
    ),
  ]),
  const _Section('Article 10 — Disponibilité et maintenance', [
    _Para(
      'WorkIt met en œuvre les moyens raisonnables pour assurer la disponibilité du service, sans garantie '
      'de disponibilité continue. Des opérations de maintenance planifiées ou des interruptions liées aux '
      'prestataires techniques tiers (hébergement, infrastructure cloud) peuvent survenir.',
    ),
  ]),
  const _Section('Article 11 — Responsabilité', [
    _Para(
      'WorkIt met en œuvre les moyens raisonnables pour assurer le bon fonctionnement du service mais n\'est '
      'tenu que d\'une obligation de moyens. WorkIt ne saurait être tenu responsable des dommages indirects, '
      'ni des conséquences résultant d\'une utilisation non conforme du service par le Client, d\'une saisie '
      'erronée de données, ou d\'une indisponibilité imputable à un prestataire tiers. La fonctionnalité '
      'd\'analyse automatisée par intelligence artificielle est fournie à titre d\'aide et ne dispense pas le '
      'Client d\'un contrôle humain des éléments proposés avant toute utilisation (métré, commande).',
    ),
  ]),
  const _Section('Article 12 — Données personnelles', [
    _Para(
      'Le traitement des données à caractère personnel dans le cadre du service est décrit dans la Politique '
      'de confidentialité de WorkIt, qui fait partie intégrante des présentes CGV.',
    ),
  ]),
  const _Section('Article 13 — Force majeure', [
    _Para(
      'WorkIt ne pourra être tenu responsable de tout retard ou inexécution consécutif à la survenance d\'un '
      'cas de force majeure habituellement reconnu par la jurisprudence et les tribunaux français.',
    ),
  ]),
  const _Section('Article 14 — Modification des CGV', [
    _Para(
      'WorkIt se réserve le droit de modifier les présentes CGV à tout moment. Les CGV applicables sont '
      'celles en vigueur à la date d\'utilisation du service. Le Client sera informé de toute modification '
      'substantielle.',
    ),
  ]),
  const _Section('Article 15 — Droit applicable et juridiction compétente', [
    _Para(
      'Les présentes CGV sont soumises au droit français. Tout litige relatif à leur interprétation ou à '
      'leur exécution relève de la compétence exclusive des tribunaux de [VILLE À COMPLÉTER], sauf '
      'disposition légale impérative contraire.',
    ),
  ]),
  const _Section('Article 16 — Contact', [
    _Para('Pour toute question relative aux présentes CGV : [EMAIL DE CONTACT À COMPLÉTER].'),
  ]),
];

// ─────────────────────────────────────────────────────────────────────────
// POLITIQUE DE CONFIDENTIALITÉ
// ─────────────────────────────────────────────────────────────────────────

final _privacySections = <_Section>[
  const _Section('1. Éditeur et responsable de traitement', [
    _Para(
      '[RAISON SOCIALE À COMPLÉTER], [FORME JURIDIQUE À COMPLÉTER], immatriculée au RCS de [VILLE À '
      'COMPLÉTER] sous le numéro [SIRET/RCS À COMPLÉTER], dont le siège social est situé [ADRESSE À '
      'COMPLÉTER] (ci-après « WorkIt », « nous »), édite l\'application WorkIt destinée aux entreprises '
      'du bâtiment.',
    ),
    _Para('Contact : [EMAIL DE CONTACT À COMPLÉTER]'),
    _Para('Délégué à la protection des données (le cas échéant) : [CONTACT DPO À COMPLÉTER]'),
  ]),
  const _Section('2. Champ d\'application', [
    _Para(
      'La présente politique décrit comment WorkIt collecte, utilise, conserve et protège les données à '
      'caractère personnel traitées dans le cadre de l\'utilisation de l\'application WorkIt (web, iOS, '
      'Android) par les utilisateurs des entreprises clientes ("Espaces de travail") ainsi que, le cas '
      'échéant, par les clients finaux de ces entreprises dont les coordonnées sont saisies dans '
      'l\'application (gestion de devis et de chantiers).',
    ),
  ]),
  const _Section('3. Données collectées', [
    _Para('3.1 Données des utilisateurs de l\'application (membres d\'un espace de travail)'),
    _Para('Identité : nom, prénom, adresse e-mail, rôle (Administrateur, Commercial, Métreur, Poseur)', bullet: true),
    _Para('Données de connexion : identifiants Firebase Authentication, jetons de session', bullet: true),
    _Para(
      'Données d\'usage : actions réalisées dans l\'application (création de devis, changements de statut, '
      'messages échangés dans le chat de chantier), horodatages de pointage (départ dépôt, arrivée chantier, '
      'début/fin d\'intervention)',
      bullet: true,
    ),
    _Para(
      'Photos prises dans le cadre de l\'activité (photos de chantier, attestations de fin de travaux) '
      'stockées via Firebase Storage',
      bullet: true,
    ),
    _Para(
      'Jeton de notification push (Firebase Cloud Messaging) pour l\'envoi d\'alertes liées aux chantiers',
      bullet: true,
    ),
    _Para('3.2 Données des clients finaux des entreprises utilisatrices'),
    _Para(
      'Saisies par les utilisateurs (rôle Commercial/Métreur) dans le cadre de la gestion des devis et '
      'chantiers :',
    ),
    _Para('Nom, prénom, adresse postale, téléphone, adresse e-mail', bullet: true),
    _Para('Documents de devis (PDF ou photos) déposés dans l\'application', bullet: true),
    _Para('Notes, commentaires et échanges relatifs au chantier', bullet: true),
    _Para(
      'Pour ces données, l\'entreprise cliente (l\'espace de travail) est responsable de traitement au sens '
      'du RGPD ; WorkIt agit en tant que sous-traitant au sens de l\'article 28 du RGPD.',
    ),
  ]),
  const _Section('4. Finalités du traitement', [
    _Para('Fourniture du service (gestion de devis, planification, suivi de chantier, messagerie interne)', bullet: true),
    _Para('Authentification et sécurité des comptes', bullet: true),
    _Para('Notifications liées à l\'avancement des chantiers (push, e-mail)', bullet: true),
    _Para('Génération de documents (bons de commande, bons de préparation, rapports)', bullet: true),
    _Para(
      'Analyse automatisée des devis déposés par le Commercial, à l\'aide de services d\'intelligence '
      'artificielle tiers, afin d\'en extraire une liste d\'éléments à mesurer (voir section 6)',
      bullet: true,
    ),
    _Para('Statistiques d\'usage agrégées pour l\'amélioration du service', bullet: true),
    _Para('Respect des obligations légales et sécurité (journalisation, audit)', bullet: true),
  ]),
  const _Section('5. Base légale', [
    _Para('Exécution du contrat conclu avec l\'entreprise cliente (abonnement au service WorkIt)', bullet: true),
    _Para('Intérêt légitime (sécurité, amélioration du service, prévention de la fraude)', bullet: true),
    _Para('Consentement, lorsque requis (ex. notifications push, biométrie locale à l\'appareil)', bullet: true),
  ]),
  const _Section('6. Destinataires et sous-traitants', [
    _Para(
      'Les données peuvent être transmises aux prestataires techniques suivants, dans la stricte mesure '
      'nécessaire à la fourniture du service :',
    ),
    _Para(
      'Google Firebase / Google Cloud Platform (hébergement, base de données, authentification, stockage '
      'de fichiers, fonctions serveur, notifications push) — région d\'hébergement europe-west1',
      bullet: true,
    ),
    _Para(
      'OpenAI (lecture visuelle des devis déposés par le Commercial, dans le cadre de la fonctionnalité '
      'd\'extraction automatique des éléments à métrer) — les fichiers analysés sont transmis à ce '
      'prestataire pour traitement',
      bullet: true,
    ),
    _Para('DeepSeek (structuration du résultat de cette analyse)', bullet: true),
    _Para(
      'Mailjet ou un service SMTP équivalent (envoi d\'e-mails transactionnels : activation de compte, '
      'notifications)',
      bullet: true,
    ),
    _Para(
      'WorkIt s\'assure que ces sous-traitants présentent des garanties suffisantes au regard du RGPD.',
    ),
  ]),
  const _Section('7. Transferts hors Union européenne', [
    _Para(
      'Certains sous-traitants mentionnés à la section 6 (notamment les fournisseurs d\'intelligence '
      'artificielle) peuvent être établis ou traiter des données en dehors de l\'Union européenne. Ces '
      'transferts sont encadrés par les garanties appropriées prévues par le RGPD (clauses contractuelles '
      'types ou équivalent) [À COMPLÉTER selon les engagements contractuels effectifs de chaque prestataire].',
    ),
  ]),
  const _Section('8. Durée de conservation', [
    _Para(
      'Données de compte utilisateur : pendant toute la durée de la relation contractuelle avec l\'entreprise '
      'cliente, puis archivage limité conformément aux obligations légales',
      bullet: true,
    ),
    _Para(
      'Données de chantier et de devis : durée définie par l\'entreprise cliente (responsable de traitement), '
      'sous réserve des durées légales de conservation applicables (garantie décennale, obligations '
      'comptables, etc.)',
      bullet: true,
    ),
    _Para('Journaux d\'audit (auditLogs) : conservés à des fins de sécurité et de preuve', bullet: true),
    _Para(
      'Photos et documents : jusqu\'à suppression par l\'entreprise cliente ou clôture du chantier concerné, '
      'selon la politique de conservation propre à chaque espace de travail',
      bullet: true,
    ),
  ]),
  const _Section('9. Sécurité', [
    _Para(
      'WorkIt met en œuvre des mesures techniques et organisationnelles pour protéger les données : '
      'authentification sécurisée, cloisonnement strict des données entre entreprises clientes (règles de '
      'sécurité Firestore par espace de travail), chiffrement en transit, contrôle des fonctions serveur '
      '(Firebase App Check).',
    ),
  ]),
  const _Section('10. Droits des personnes concernées', [
    _Para(
      'Conformément au RGPD, toute personne concernée dispose d\'un droit d\'accès, de rectification, '
      'd\'effacement, de limitation, d\'opposition et de portabilité de ses données. Pour les données '
      'saisies par une entreprise cliente (client final d\'un devis), la demande doit être adressée en '
      'priorité à cette entreprise, responsable de traitement. Pour les données de compte utilisateur '
      'WorkIt, toute demande peut être adressée à [EMAIL DE CONTACT À COMPLÉTER].',
    ),
    _Para('Chaque personne dispose également du droit d\'introduire une réclamation auprès de la CNIL (www.cnil.fr).'),
  ]),
  const _Section('11. Cookies et traceurs', [
    _Para(
      'La version web de l\'application peut utiliser des mécanismes techniques nécessaires à son '
      'fonctionnement (ex. reCAPTCHA pour la protection anti-abus) [À COMPLÉTER si des cookies de mesure '
      'd\'audience ou publicitaires sont ajoutés ultérieurement].',
    ),
  ]),
  const _Section('12. Modifications', [
    _Para(
      'La présente politique peut être mise à jour. La date de dernière mise à jour figure en en-tête. En '
      'cas de modification substantielle, les utilisateurs en seront informés via l\'application.',
    ),
  ]),
  const _Section('13. Contact', [
    _Para('Pour toute question relative à la présente politique : [EMAIL DE CONTACT À COMPLÉTER].'),
  ]),
];
