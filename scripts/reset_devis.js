/**
 * WorkIt — Reset base de données
 * Supprime tous les devis de tous les workspaces
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

  let totalDeleted = 0;

  for (const wsDoc of workspacesSnap.docs) {
    const wsName = wsDoc.data().companyName ?? wsDoc.id;
    const devisSnap = await db
      .collection('workspaces')
      .doc(wsDoc.id)
      .collection('devis')
      .get();

    if (devisSnap.empty) {
      console.log(`  Workspace "${wsName}" — aucun devis.`);
      continue;
    }

    // Firestore batch delete (max 500 par batch)
    const chunks = [];
    for (let i = 0; i < devisSnap.docs.length; i += 400) {
      chunks.push(devisSnap.docs.slice(i, i + 400));
    }

    for (const chunk of chunks) {
      const batch = db.batch();
      for (const doc of chunk) {
        batch.delete(doc.ref);
      }
      await batch.commit();
      totalDeleted += chunk.length;
    }

    console.log(`  ✅ Workspace "${wsName}" — ${devisSnap.docs.length} devis supprimés`);
  }

  console.log(`\n✅ Done — ${totalDeleted} devis supprimés au total.`);
  console.log('   La base est vierge. Tu peux créer un nouveau devis côté commercial.\n');
  process.exit(0);
}

main().catch((err) => {
  console.error('\n❌ Erreur :', err.message);
  process.exit(1);
});
