/**
 * WorkIt — Script de test flow complet
 * Simule : Commercial → Métreur → Poseur → Terminé
 * Usage : node test_flow.js
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const serviceAccount = require('./serviceAccountKey.json');

initializeApp({ credential: cert(serviceAccount) });

const db = getFirestore();

const DELAI = 4000; // 4 secondes entre chaque étape (regarder les simulateurs)

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const log = (etape, msg) => {
  console.log(`\n${'─'.repeat(50)}`);
  console.log(`  ÉTAPE ${etape} — ${msg}`);
  console.log(`${'─'.repeat(50)}`);
};

async function main() {
  // ── 0. Récupérer workspace + users ─────────────────────────────────────────
  console.log('\n🔍 Recherche du workspace et des utilisateurs...\n');

  const workspacesSnap = await db.collection('workspaces').limit(1).get();
  if (workspacesSnap.empty) {
    console.error('❌ Aucun workspace trouvé. Lance l\'app et inscris-toi d\'abord.');
    process.exit(1);
  }
  const workspaceId = workspacesSnap.docs[0].id;
  const workspaceData = workspacesSnap.docs[0].data();
  console.log(`✅ Workspace : ${workspaceData.companyName} (${workspaceId})`);

  const usersSnap = await db.collection('users')
    .where('workspaceId', '==', workspaceId)
    .get();

  let commercialId = null, commercialName = '';
  let metreurId = null, metreurName = '';
  let poseurId = null, poseurName = '';
  let adminId = null;

  for (const doc of usersSnap.docs) {
    const u = doc.data();
    if (u.role === 'commercial' && !commercialId) {
      commercialId = doc.id;
      commercialName = `${u.firstName} ${u.lastName}`;
    } else if (u.role === 'metreur' && !metreurId) {
      metreurId = doc.id;
      metreurName = `${u.firstName} ${u.lastName}`;
    } else if (u.role === 'poseur' && !poseurId) {
      poseurId = doc.id;
      poseurName = `${u.firstName} ${u.lastName}`;
    } else if (u.role === 'admin' && !adminId) {
      adminId = doc.id;
    }
  }

  console.log(`✅ Commercial : ${commercialName || '❌ non trouvé'} (${commercialId || '-'})`);
  console.log(`✅ Métreur    : ${metreurName || '❌ non trouvé'} (${metreurId || '-'})`);
  console.log(`✅ Poseur     : ${poseurName || '⚠️  non trouvé — étape pose ignorée'} (${poseurId || '-'})`);

  if (!commercialId || !metreurId) {
    console.error('\n❌ Il faut au moins un commercial et un métreur. Crée-les depuis l\'onglet Admin > Équipe.');
    process.exit(1);
  }

  // ── 1. Créer le devis (rôle commercial) ────────────────────────────────────
  await sleep(1000);
  log(1, 'Commercial crée un devis');

  const devisRef = db.collection('workspaces').doc(workspaceId).collection('devis').doc();
  const devisId = devisRef.id;
  const maintenant = Timestamp.now();

  const draft = {
    clientName: 'Dupont',
    clientFirstName: 'Marie',
    street: '12 avenue des Mimosas',
    postal: '06400',
    city: 'Cannes',
    phone: '0612345678',
    email: 'marie.dupont@test.fr',
    commentaire: 'Remplacement fenêtres et volets',
    chantierNotes: 'Accès par l\'arrière du bâtiment',
    chantierType: 'Rénovation',
    typeHabitation: 'Appartement',
    accessibilite: 'Facile',
    date: null,
    assignedMetreurId: metreurId,
    assignedMetreurName: metreurName,
    products: [
      {
        categoryKey: 'menuiseries_exterieures',
        sousCategorie: 'PVC',
        typeProduit: 'battant',
        variante: 'Standard',
        couleur: 'RAL Aluminium',
        couleurDetail: '7016',
        largeur: 900,
        hauteur: 1200,
        quantite: 3,
        unite: 'mm',
      },
      {
        categoryKey: 'volets_battants',
        sousCategorie: 'Aluminium',
        typeProduit: 'persienne',
        variante: null,
        couleur: 'RAL Aluminium',
        couleurDetail: '7016',
        largeur: 900,
        hauteur: 1200,
        quantite: 3,
        unite: 'mm',
      },
    ],
  };

  await devisRef.set({
    client: 'Marie Dupont',
    clientFirstName: 'Marie',
    clientName: 'Dupont',
    address: '12 avenue des Mimosas, 06400 Cannes',
    phone: '0612345678',
    email: 'marie.dupont@test.fr',
    status: 'Nouvelle demande',
    assignedMetreurId: metreurId,
    assignedMetreurName: metreurName,
    userId: commercialId,
    workspaceId: workspaceId,
    metreurId: metreurId,
    category: 'Menuiserie Extérieure',
    note: 'Remplacement fenêtres et volets — accès arrière',
    draft: draft,
    summary: [
      { label: 'Type de chantier', value: 'Rénovation' },
      { label: 'Type d\'habitation', value: 'Appartement' },
      { label: 'Accessibilité', value: 'Facile' },
      { label: 'Commentaires chantier', value: 'Accès par l\'arrière du bâtiment' },
      { label: 'Élément 1', value: 'Menuiseries extérieures • PVC • Battant • RAL Aluminium • Dim: 900 x 1200 mm • Qté: 3' },
      { label: 'Élément 2', value: 'Volets battants • Aluminium • Persienne • RAL Aluminium • Dim: 900 x 1200 mm • Qté: 3' },
    ],
    attachments: [],
    poseurIds: [],
    createdAt: maintenant,
    updatedAt: maintenant,
  });

  console.log(`   → Devis créé : ${devisId}`);
  console.log(`   → Client : Marie Dupont, 12 av des Mimosas, Cannes`);
  console.log(`   → 3 fenêtres PVC + 3 volets alu`);
  console.log(`   → Métreur assigné : ${metreurName}`);
  console.log(`\n   👀 Regarde les simulateurs : "En attente" +1 côté commercial et admin`);

  // ── 2. Métreur accepte ──────────────────────────────────────────────────────
  await sleep(DELAI);
  log(2, 'Métreur accepte la demande → status: Acceptée');

  await devisRef.set({
    status: 'Acceptée',
    metreurId: metreurId,
    metreurUpdatedAt: FieldValue.serverTimestamp(),
    updated: 'Acceptée à l\'instant',
  }, { merge: true });

  console.log(`   👀 Commercial : reste dans "En attente" (pas de changement visuel)`);
  console.log(`   👀 Admin : reste dans "En attente" (Acceptée = toujours en attente)`);

  // ── 3. Métreur prend RDV (meetingAt) ───────────────────────────────────────
  await sleep(DELAI);
  log(3, 'Métreur fixe un RDV de visite');

  const rdvDate = new Date();
  rdvDate.setDate(rdvDate.getDate() + 3); // dans 3 jours
  rdvDate.setHours(10, 0, 0, 0);

  await devisRef.set({
    status: 'En cours',
    meetingAt: Timestamp.fromDate(rdvDate),
    updated: `RDV le ${rdvDate.toLocaleDateString('fr-FR')} à 10h`,
    metreurUpdatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log(`   → RDV fixé : ${rdvDate.toLocaleDateString('fr-FR')} à 10h00 — status: En cours`);
  console.log(`   👀 Commercial : passe dans "Métré programmé"`);
  console.log(`   👀 Admin : passe dans "Métré en cours"`);
  console.log(`   👀 Métreur : passe dans onglet "En cours"`);

  // ── 4. Métreur termine le métré ─────────────────────────────────────────────
  await sleep(DELAI);
  log(4, 'Métreur termine le métré → status: À commander');

  await devisRef.set({
    status: 'À commander',
    metreurId: metreurId,
    metreurUpdatedAt: FieldValue.serverTimestamp(),
    updated: 'Métré terminé',
  }, { merge: true });

  console.log(`   👀 Commercial : passe en "En commande"`);
  console.log(`   👀 Métreur : passe en onglet "À commander"`);

  // ── 5. Métreur confirme la commande ─────────────────────────────────────────
  await sleep(DELAI);
  log(5, 'Métreur confirme la commande → status: À planifier');

  await devisRef.set({
    status: 'À planifier',
    metreurId: metreurId,
    metreurUpdatedAt: FieldValue.serverTimestamp(),
    updated: 'Commande confirmée',
  }, { merge: true });

  console.log(`   👀 Commercial : passe en "En pose"`);
  console.log(`   👀 Métreur : passe en onglet "Pose / Suivi"`);

  // ── 6. Métreur programme la pose ────────────────────────────────────────────
  await sleep(DELAI);
  log(6, 'Métreur programme la pose → status: En pose');

  const poseDate = new Date();
  poseDate.setDate(poseDate.getDate() + 14); // dans 2 semaines
  poseDate.setHours(8, 0, 0, 0);

  const poseurIds = poseurId ? [poseurId] : [];
  const poseurNames = poseurName || '';

  await devisRef.set({
    status: 'En pose',
    poseDate: Timestamp.fromDate(poseDate),
    poseurIds: poseurIds,
    poseurNames: poseurNames,
    metreurId: metreurId,
    metreurUpdatedAt: FieldValue.serverTimestamp(),
    updated: `Pose le ${poseDate.toLocaleDateString('fr-FR')}`,
  }, { merge: true });

  console.log(`   → Pose programmée : ${poseDate.toLocaleDateString('fr-FR')} à 08h00`);
  if (poseurId) {
    console.log(`   → Poseur assigné : ${poseurName}`);
    console.log(`   👀 Poseur : apparaît dans "À faire"`);
  } else {
    console.log(`   ⚠️  Aucun poseur — ajoute-en un depuis Admin > Équipe pour tester cette étape`);
  }

  // ── 7. Rapport de fin — chantier terminé ────────────────────────────────────
  await sleep(DELAI);
  log(7, 'Poseur soumet rapport OK → status: Terminé');

  await devisRef.set({
    status: 'Terminé',
    rapportFin: {
      reglementOk: true,
      photos: [],
      createdAt: FieldValue.serverTimestamp(),
    },
    updated: 'Chantier terminé',
    metreurUpdatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log(`   👀 Commercial : passe en "Terminés"`);
  console.log(`   👀 Admin : dashboard "Terminés" +1`);

  // ── Fin ─────────────────────────────────────────────────────────────────────
  console.log(`\n${'═'.repeat(50)}`);
  console.log(`  ✅ FLOW COMPLET — Devis ID : ${devisId}`);
  console.log(`  Tu peux retrouver ce devis dans Firestore pour vérifier.`);
  console.log(`${'═'.repeat(50)}\n`);

  process.exit(0);
}

main().catch((err) => {
  console.error('\n❌ Erreur :', err.message);
  process.exit(1);
});
