/**
 * WorkIt — Upload des PDF légaux (CGV, Politique de confidentialité) vers
 * Firebase Storage.
 *
 * Pas de serviceAccountKey.json sur ce poste Windows (voir _claude_sessions/
 * session_courante.md) : on réutilise le token OAuth déjà mis en cache par
 * `firebase login` via l'API interne de firebase-tools (pas un secret
 * utilisateur, même technique que celle documentée dans le journal de
 * session pour interroger Firestore en direct).
 *
 * Prérequis : avoir généré les PDF via `dart run scripts/generate_legal_pdfs.dart`.
 * Usage : node scripts/upload_legal_pdfs.js
 */

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

// firebase-tools est installé globalement (npm install -g), pas comme
// dépendance locale de scripts/ — require via son chemin absolu.
const FIREBASE_TOOLS_AUTH = path.join(
  process.env.APPDATA || '',
  '..', 'Local', 'Programs', 'nodejs', 'node_modules', 'firebase-tools', 'lib', 'auth.js',
);

const { getGlobalDefaultAccount, getAccessToken } = require(FIREBASE_TOOLS_AUTH);

const BUCKET = 'workit-1daa1.firebasestorage.app';
const FILES = [
  { local: path.join(__dirname, 'output', 'cgv.pdf'), remote: 'legal/cgv.pdf' },
  { local: path.join(__dirname, 'output', 'politique_confidentialite.pdf'), remote: 'legal/politique_confidentialite.pdf' },
];

async function main() {
  const account = getGlobalDefaultAccount();
  if (!account) {
    throw new Error('Aucun compte Firebase CLI connecté — lancez `firebase login` d\'abord.');
  }
  const token = await getAccessToken(account.tokens.refresh_token, [
    'https://www.googleapis.com/auth/cloud-platform',
  ]);
  const accessToken = token.access_token;

  const urls = {};
  for (const f of FILES) {
    if (!fs.existsSync(f.local)) {
      throw new Error(`Fichier introuvable : ${f.local} — lancez d'abord generate_legal_pdfs.dart`);
    }
    const bytes = fs.readFileSync(f.local);
    const downloadToken = crypto.randomUUID();
    const encodedName = encodeURIComponent(f.remote);

    const uploadUrl = `https://storage.googleapis.com/upload/storage/v1/b/${BUCKET}/o?uploadType=media&name=${encodedName}`;
    const uploadResp = await fetch(uploadUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/pdf',
      },
      body: bytes,
    });
    if (!uploadResp.ok) {
      throw new Error(`Upload échoué pour ${f.remote} : HTTP ${uploadResp.status} — ${await uploadResp.text()}`);
    }

    // Jeton de téléchargement (même mécanisme que ref.getDownloadURL() côté
    // client Flutter) — produit une URL stable et publique sans avoir à
    // ouvrir les règles de sécurité Storage à la lecture anonyme.
    const metaUrl = `https://storage.googleapis.com/storage/v1/b/${BUCKET}/o/${encodedName}`;
    const metaResp = await fetch(metaUrl, {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ metadata: { firebaseStorageDownloadTokens: downloadToken } }),
    });
    if (!metaResp.ok) {
      throw new Error(`Mise à jour metadata échouée pour ${f.remote} : HTTP ${metaResp.status} — ${await metaResp.text()}`);
    }

    const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodedName}?alt=media&token=${downloadToken}`;
    urls[f.remote] = downloadUrl;
    console.log(`OK ${f.remote} -> ${downloadUrl}`);
  }

  fs.writeFileSync(path.join(__dirname, 'output', 'legal_urls.json'), JSON.stringify(urls, null, 2));
  console.log('\nURLs écrites dans scripts/output/legal_urls.json');
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
