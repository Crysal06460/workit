/**
 * WorkIt — Création des 4 comptes tests permanents
 * Crée commercial / métreur / poseur dans le premier workspace trouvé
 * L'admin existe déjà (compte Christophe)
 * Usage : node scripts/setup_test_accounts.js
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const serviceAccount = require('./serviceAccountKey.json');

initializeApp({ credential: cert(serviceAccount) });
const auth = getAuth();
const db = getFirestore();

const COMPTES = [
  { email: 'commercial@workit-test.fr', firstName: 'Marie',   lastName: 'Dupont',   role: 'commercial', password: 'Workit2026!' },
  { email: 'metreur@workit-test.fr',    firstName: 'Pascal',  lastName: 'Lemaire',  role: 'metreur',    password: 'Workit2026!' },
  { email: 'poseur@workit-test.fr',     firstName: 'Lucas',   lastName: 'Martin',   role: 'poseur',     password: 'Workit2026!' },
];

async function main() {
  console.log('\n🔧 Setup comptes tests WorkIt...\n');

  const workspacesSnap = await db.collection('workspaces').limit(1).get();
  if (workspacesSnap.empty) {
    console.error('❌ Aucun workspace trouvé. Lance l\'app et inscris-toi d\'abord.');
    process.exit(1);
  }
  const wsDoc = workspacesSnap.docs[0];
  const workspaceId = wsDoc.id;
  const wsName = wsDoc.data().companyName ?? workspaceId;
  console.log(`✅ Workspace : ${wsName} (${workspaceId})\n`);

  for (const compte of COMPTES) {
    try {
      // Crée ou récupère le compte Firebase Auth
      let userRecord;
      try {
        userRecord = await auth.getUserByEmail(compte.email);
        await auth.updateUser(userRecord.uid, { password: compte.password, displayName: `${compte.firstName} ${compte.lastName}` });
        console.log(`🔄 Compte existant mis à jour : ${compte.email}`);
      } catch {
        userRecord = await auth.createUser({
          email: compte.email,
          password: compte.password,
          displayName: `${compte.firstName} ${compte.lastName}`,
        });
        console.log(`✨ Compte créé : ${compte.email}`);
      }

      // Crée/met à jour le doc users/{uid}
      await db.collection('users').doc(userRecord.uid).set({
        uid: userRecord.uid,
        email: compte.email,
        firstName: compte.firstName,
        lastName: compte.lastName,
        role: compte.role,
        companyId: workspaceId,
        workspaceId: workspaceId,
        tradeKey: 'menuiserie_aluminium',
        status: 'active',
        createdAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      console.log(`   → Firestore users/${userRecord.uid} : ${compte.role}`);
      console.log(`   → Email : ${compte.email}`);
      console.log(`   → Mot de passe : ${compte.password}\n`);

    } catch (err) {
      console.error(`❌ Erreur pour ${compte.email} :`, err.message);
    }
  }

  console.log('═'.repeat(50));
  console.log('  ✅ COMPTES TESTS CRÉÉS');
  console.log('  Admin      → ton compte Christophe (déjà existant)');
  console.log('  Commercial → commercial@workit-test.fr / Workit2026!');
  console.log('  Métreur    → metreur@workit-test.fr   / Workit2026!');
  console.log('  Poseur     → poseur@workit-test.fr    / Workit2026!');
  console.log('═'.repeat(50) + '\n');
  process.exit(0);
}

main().catch((err) => {
  console.error('\n❌ Erreur :', err.message);
  process.exit(1);
});
