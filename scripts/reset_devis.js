/**
 * WorkIt — Reset base de données
 * Supprime tous les devis (chantiers) de tous les workspaces, avec leurs
 * sous-collections (lots, statusHistory, messages), ainsi que les
 * notifications et stats qui en découlent. Ne touche ni aux workspaces,
 * ni aux users, ni aux équipes de planning, ni aux audit logs.
 * Usage : node scripts/reset_devis.js
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./serviceAccountKey.json');

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

async function main() {
  console.log('\n🗑️  Nettoyage de la base de données WorkIt...\n');

  const workspacesSnap = await db.collection('workspaces').get();
  if (workspacesSnap.empty) {
    console.log('Aucun workspace trouvé.');
    process.exit(0);
  }

  let totalDevis = 0;
  let totalOther = 0;

  for (const wsDoc of workspacesSnap.docs) {
    const wsName = wsDoc.data().companyName ?? wsDoc.id;
    const devisSnap = await db
      .collection('workspaces')
      .doc(wsDoc.id)
      .collection('devis')
      .get();

    for (const doc of devisSnap.docs) {
      await db.recursiveDelete(doc.ref);
      totalDevis += 1;
    }

    let wsOther = 0;
    for (const sub of ['notifications', 'stats']) {
      const subSnap = await db
        .collection('workspaces')
        .doc(wsDoc.id)
        .collection(sub)
        .get();
      for (const doc of subSnap.docs) {
        await db.recursiveDelete(doc.ref);
        wsOther += 1;
      }
    }
    totalOther += wsOther;

    console.log(`  ✅ Workspace "${wsName}" — ${devisSnap.size} devis + ${wsOther} notifications/stats supprimés`);
  }

  console.log(`\n✅ Done — ${totalDevis} devis et ${totalOther} notifications/stats supprimés au total.`);
  console.log('   La base est vierge. Tu peux créer un nouveau devis côté commercial.\n');
  process.exit(0);
}

main().catch((err) => {
  console.error('\n❌ Erreur :', err.message);
  process.exit(1);
});
