---
name: "Agent Sécurité & Performance"
description: "Responsable sécurité des codes d'invitation, pagination Firestore, et optimisations scalabilité"
type: "security-performance"
skills: ["security", "firestore", "optimization", "backend"]
focusAreas:
  - "Sécuriser codes d'invitation (UUID rotatifs au lieu de hardcodés)"
  - "Pagination Firestore (problème scalabilité devis stream)"
  - "Support poseurs en batch 1 utilisateurs"
  - "Optimisations requêtes Firestore"
  - "Rate limiting et throttling"
priority: "P1"
estimatedEffort: "2-3 semaines"
dependencies: []
blockingFor:
  - "Agent 1 & 2 (avant go production)"
---

# Agent 3: Sécurité & Performance

## 🎯 Mission
Eliminer vulnérabilités de sécurité, résoudre problèmes de scalabilité Firestore, et préparer production.

## 📋 Tâches Prioritaires

### 1️⃣ **Codes d'Invitation Sécurisés** (Semaine 1)
**Problème actuel:** Hardcodés 'COMMERCIAL', 'METREUR', 'POSEURS' → Zéro sécurité, prévisible

**Solution:**
- Générer UUID v4 rotatifs par rôle + workspace
- Chaque code: utilisable 1x, expire après 30 jours
- Tracker l'utilisation (qui, quand)
- Invalider après utilisation

**Firestore Schema:**
```
workspaces/{id}/invitationCodes
├─ {codeId}
│  ├─ code: 'a1b2c3d4-e5f6-4g7h-8i9j-0k1l2m3n4o5p' (UUID v4)
│  ├─ role: 'commercial' | 'metreur' | 'poseur'
│  ├─ createdBy: uid de l'admin
│  ├─ createdAt: Timestamp
│  ├─ expiresAt: Timestamp (now + 30 days)
│  ├─ status: 'active' | 'used' | 'expired'
│  ├─ usedBy: uid | null
│  ├─ usedAt: Timestamp | null
│  └─ maxUses: 1 (toujours, pour sécurité)
```

**Backend Changes:**
- [ ] Supprimer `generatedCodes` hardcodés dans `OnboardingData`
- [ ] Cloud Function `generateInvitationCode()` → return UUID
- [ ] Cloud Function `validateInvitationCode(code, workspaceId)` → check status + expiry
- [ ] Cloud Function `consumeInvitationCode(code, uid)` → mark as used

**Frontend Changes:**
- [ ] `InviteTeamScreen`: bouton "Générer code" pour chaque rôle (à partager manuellement)
- [ ] `JoinWorkspaceScreen`: champ input pour saisir code d'invitation (validation réseau)
- [ ] Afficher erreur si code invalide/expiré/déjà utilisé

**Files to modify:**
- `lib/models/onboarding_models.dart` (supprimer `generatedCodes`)
- `lib/screens/invite_team_screen.dart` (nouveau flow)
- `lib/screens/join_workspace_screen.dart` (validation code)
- `functions/index.js` (3 nouvelles Cloud Functions)
- Create `lib/services/invitation_service.dart`

**Example Cloud Function:**
```javascript
exports.generateInvitationCode = onCall(
  async (request) => {
    const workspaceId = request.data.workspaceId;
    const role = request.data.role; // 'commercial', 'metreur', 'poseur'
    const adminUid = request.auth.uid;

    // Check: admin de ce workspace
    const ws = await db.collection('workspaces').doc(workspaceId).get();
    if (ws.data().adminUid !== adminUid) throw new Error('Unauthorized');

    const code = crypto.randomUUID();
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

    await db.collection('workspaces').doc(workspaceId).collection('invitationCodes').add({
      code,
      role,
      createdBy: adminUid,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromDate(expiresAt),
      status: 'active',
      usedBy: null,
      usedAt: null,
    });

    return { code, expiresAt };
  }
);
```

### 2️⃣ **Pagination Firestore (Problème Scalabilité)** (Semaine 1-2)
**Problème actuel:** 
```dart
_firestore.collection('workspaces').doc(_workspaceId)
  .collection('devis')
  .orderBy('createdAt', descending: true)
  .get() // ← CHARGE TOUT, pas de limite!
```
→ N documents lus = coût $ Firestore + lag UI

**Solution: Pagination avec cursor (keyset pagination)**

- [ ] Charger 20 devis par page par défaut
- [ ] Stocker `lastDocument` + `lastValue` pour next page
- [ ] Implémenter "Load More" button
- [ ] Indexer Firestore: `workspaces/{id}/devis` on `(createdAt desc, __name__ desc)`

**Code Pattern:**
```dart
Future<List<DevisDoc>> loadDevisPage({int pageSize = 20, DocumentSnapshot? cursor}) async {
  Query query = _firestore
      .collection('workspaces')
      .doc(_workspaceId)
      .collection('devis')
      .orderBy('createdAt', descending: true)
      .limit(pageSize);

  if (cursor != null) {
    query = query.startAfterDocument(cursor);
  }

  final snap = await query.get();
  if (snap.docs.isNotEmpty) {
    _nextCursor = snap.docs.last; // Pour next page
  }
  return snap.docs.map((d) => DevisDoc.fromFirestore(d)).toList();
}
```

**UI Changes:**
- CommercialHomeScreen: afficher 20 devis + "Charger plus" button
- MetreurHomeScreen: afficher 20 demandes + "Charger plus" button
- Possibilité stream 20 premiers devis en realtime, rest on-demand

**Files to modify:**
- `lib/screens/commercial_home_screen.dart` (pagination logic)
- `lib/screens/metreur_home_screen.dart` (pagination logic)
- `lib/services/devis_service.dart` (créer si n'existe pas, centraliser queries)
- Create `lib/models/pagination_models.dart` (PageCursor, PageResult)

### 3️⃣ **Support Poseurs en Batch 1** (Semaine 2)
Si les poseurs sont dans premiers utilisateurs, risque qu'ils voient écran vide.

**Mitigation:**
- [ ] PoseursHomeScreen doit être **100% fonctionnel** avant go-live (Agent 1)
- [ ] Démonstration data: créer 2-3 poses de test dans Firestore
- [ ] Trigger par statut devis "À planifier" → créer Pose doc automatiquement
- [ ] Backend: Cloud Function `onDevisStatusChange` → crée Pose si `status === 'À planifier'`

**Cloud Function exemple:**
```javascript
exports.onDevisStatusChange = onDocumentUpdated(
  'workspaces/{workspaceId}/devis/{devisId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status !== 'À planifier' && after.status === 'À planifier') {
      // Créer Pose automatiquement
      const poseRef = db.collection('workspaces')
        .doc(event.params.workspaceId)
        .collection('poses')
        .add({
          devisId: event.params.devisId,
          status: 'À faire',
          createdAt: FieldValue.serverTimestamp(),
        });
    }
  }
);
```

### 4️⃣ **Optimisations Firestore Générales** (Semaine 2)
- [ ] Index composés selon usage patterns:
  - `(workspaceId, status, createdAt desc)`
  - `(workspaceId, metreurId, status)`
  - `(workspaceId, role, createdAt desc)`
- [ ] Cacher les reads inutiles:
  - Ajouter `.limit(1)` quand on cherche 1 seul doc
  - Utiliser `.count()` si on a juste besoin du nombre
  - Batch reads quand possible (vs N read séquentielles)
- [ ] DocumentReference pour relations (vs sous-collections partout)
- [ ] Monitorer Firestore Usage dans Firebase Console

**Firestore Index config (ajouter à firebase.json):**
```json
{
  "firestore": {
    "indexes": [
      {
        "collection": "workspaces",
        "fieldConfig": [
          { "fieldPath": "createdAt", "order": "DESCENDING" },
          { "fieldPath": "__name__", "order": "DESCENDING" }
        ]
      }
    ]
  }
}
```

### 5️⃣ **Rate Limiting & Throttling** (Semaine 2-3)
Prévenir abuse (brute force invites, spam queries, etc.)

- [ ] Cloud Functions: max 5 requests/min per user per function
- [ ] Frontend: debounce recherches (0.3s delay)
- [ ] Frontend: throttle Firestore queries (pas de double requests simultanées)
- [ ] Bloquer user si > 10 failed login attempts en 15 min

**Using `firebase-functions-rate-limiter`:**
```javascript
const rateLimiter = new RateLimiter({
  name: 'generateInvitationCode',
  maxCalls: 5,
  windowMs: 60000,
});

exports.generateInvitationCode = onCall(
  async (request) => {
    await rateLimiter.rejectOnQuotaExceededError(request.auth.uid);
    // ... rest of function
  }
);
```

## 🔐 Security Checklist

- [ ] Codes d'invitation: UUID v4 rotatifs + expiry 30j
- [ ] Firestore Rules: déployées et testées
- [ ] No credentials en code source (secrets dans Cloud Functions)
- [ ] HTTPS partout (enforcer redirect)
- [ ] CORS configured correctement
- [ ] Rate limits sur Cloud Functions
- [ ] Input validation côté backend (pas frontend only)
- [ ] Données sensibles (passwords, tokens) jamais en Firestore

## 📊 Performance Targets

| Métrique | Target | Actuel | Status |
|----------|--------|--------|--------|
| Devis list load time | < 2s | 5-10s | 🔴 |
| Invitation code gen | < 1s | N/A | 🟡 |
| Page size | 20 items | ∞ | 🔴 |
| Firestore read cost | < 100k/mo | Unknown | 🟡 |

## ✅ Définition "Fait"
- Codes d'invitation sécurisés + en production
- Pagination implémentée partout
- Firestore indexes optimisés
- Rate limiting actif
- Poseurs supportés en batch 1
- 0 vulnérabilités de sécurité identifiées
