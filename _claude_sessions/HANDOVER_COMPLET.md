# WorkIt — Handover complet inter-session
**Dernière mise à jour : 2026-06-29 — REFONTE DESIGN EN COURS**
**Accessible depuis : chrisbeylet@gmail.com ET cbeylet06@gmail.com**
**Projet Flutter : `/Users/macbook/workit/`**

---

## 0. TL;DR — Lire en 2 minutes

- App Flutter B2B pour entreprises second-œuvre (menuiserie, métallerie, pose)
- 4 rôles : Admin/Patron · Commercial · Métreur · Poseur
- Stack : Flutter + Firebase (Auth, Firestore, Storage, Functions, FCM)
- **Aucun Riverpod** — StatefulWidget + SharedPreferences uniquement
- **Champ critique** : `status` (PAS `metreurStatus`) sur les documents `devis`
- **0 erreur Flutter analyze** au dernier check (2026-06-17)
- Ce qui reste à faire : Stripe/abonnements + APNs iOS (config manuelle)
- ⚠️ **REFONTE DESIGN EN COURS (2026-06-29)** — Christophe a démarré une refonte visuelle complète (thème clair, `AppColors` design system). Lire la section 17 avant toute modif des 3 écrans principaux.

### État actuel (2026-06-17) — ce qui MARCHE ✅

✅ Inscription admin (flow complet 3 étapes → FinalSaveScreen → AdminHomeScreen)
✅ Connexion admin → AdminHomeScreen
✅ Admin → Équipe : liste les membres (commerciaux, métreurs, poseurs) — sans l'admin lui-même
✅ Admin → Ajouter membre → provisionAccounts → mdp temporaire affiché
✅ Connexion commercial avec mdp temporaire → CommercialHomeScreen
✅ Admin → Entreprise : email pré-rempli depuis adminEmail, téléphone 10 chiffres max
✅ Firestore security rules déployées (pas en mode "test" — vraies règles)
✅ Cloud Functions déployées (provisionAccounts + onDevisStatusChange)
✅ Commercial → Ajout devis → apparaît dans "En attente" côté commercial ET admin
✅ Formulaire devis : couleur par défaut selon tradeKey (RAL alu, Couleur PVC, Essence bois)
✅ Admin détail devis : Catégorie : SousCategorie + qty + bouton PDF
✅ MACHINE À ÉTATS COMPLÈTE — flow validé bout en bout (2026-06-17)
✅ 4 comptes tests permanents créés (scripts/setup_test_accounts.js)
✅ Métreur "Pose à programmer" → status 'À planifier' (2026-06-17 soir)
✅ Commercial : tab "Chantier à planifier" pour 'À planifier' (6 onglets)
✅ Admin : badge "Pose à programmer" pour status 'À planifier'
✅ Formulaire métré : bouton "Scinder" si quantité > 1
✅ Real-time Firestore stream côté métreur (StreamSubscription)
✅ "Demander des infos" métreur → sauvegardé Firestore → visible commercial
✅ Prise de RDV métreur → status 'En cours' → visible immédiatement sur 3 écrans
✅ Métré terminé → status 'À commander' → visible immédiatement sur 3 écrans

❌ APNs iOS (config manuelle Apple Developer Portal — Claude ne peut pas)
❌ Stripe / abonnements (pas encore commencé)
⚠️ Flow poseur non encore testé bout en bout

---

## 1. Présentation du projet

**WorkIt** est une app SaaS B2B pour les entreprises du second-œuvre. Un patron crée son espace ("workspace"), invite ses commerciaux, métreurs et poseurs. Les chantiers circulent entre les rôles avec notifications FCM à chaque étape.

**Cas d'usage principal :**
1. Le commercial rencontre un client → crée un devis/chantier dans l'app
2. L'app notifie le métreur assigné
3. Le métreur se déplace, mesure, complète le formulaire de métré
4. Le métreur confirme la commande (impression PDF)
5. Le métreur programme la pose (date + équipe de poseurs)
6. Les poseurs voient leur planning, remplissent un rapport de fin
7. L'admin voit tout en temps réel dans son dashboard

---

## 2. Stack technique

| Composant | Technologie |
|-----------|-------------|
| Framework | Flutter (Dart) — StatefulWidget uniquement |
| Auth | Firebase Authentication |
| Base de données | Cloud Firestore |
| Stockage fichiers | Firebase Storage (`gs://workit-1daa1.firebasestorage.app`) |
| Notifications | Firebase Cloud Messaging (FCM) |
| Cloud Functions | Firebase Functions v2 (europe-west1) |
| Paiements | Stripe (NON IMPLÉMENTÉ — à faire) |
| State management | SharedPreferences + setState (PAS Riverpod) |
| PDF | `pdf: ^3.11.1` + `printing: ^5.13.1` |

**Firebase projet** : `workit-1daa1`
**Region Functions** : `europe-west1`

---

## 3. Machine à états — CRITIQUE

Le champ `status` sur `workspaces/{workspaceId}/devis/{devisId}` est la colonne vertébrale de l'app.

```
Nouvelle demande → Acceptée → À commander → À planifier → En pose → Terminé
                                                                    → À clôturer
```

### Mapping status → onglet commercial (5 onglets — VALIDÉ 2026-06-17)

| Status Firestore | Onglet CommercialHome |
|-----------------|----------------------|
| `null` / `'Nouvelle demande'` / `'Acceptée'` | **"En attente"** |
| `'En cours'` | **"Métré programmé"** |
| `'À commander'` / `'Commande en cours'` | **"À commander"** |
| `'À planifier'` / `'En pose'` | "En pose" |
| `'À clôturer'` / `'Terminé'` / `'Clôturé'` | "Terminés" |

⚠️ Plus d'onglet "En cours de métré". 'Acceptée' reste dans "En attente". Seul 'En cours' (RDV pris) passe dans "Métré programmé".

### Mapping status → admin dashboard (stat cards — VALIDÉ 2026-06-17)

| Status Firestore | Stat card Admin |
|-----------------|----------------|
| `null` / `'Nouvelle demande'` / `'Acceptée'` | **"En attente"** (bleu) |
| `'En cours'` | **"Métré en cours"** (orange) |
| `'À commander'` / `'Commande en cours'` / `'À planifier'` / `'En pose'` | "Commande / Pose" |
| `'À clôturer'` / `'Terminé'` / `'Clôturé'` | "Terminés" |

### Mapping status → onglet métreur (4 onglets — VALIDÉ 2026-06-17)

| Status Firestore | Affichage MétreurHome |
|-----------------|----------------------|
| `null` / `'Nouvelle demande'` / `'Acceptée'` | **Home Tab 1** — section "Nouvelle demande" ou "Demandes acceptées" (pas dans un onglet distinct) |
| `'En cours'` | **Tab 1 "En cours"** — section "Demandes acceptées" (RDV pris, section visible) |
| `'À commander'` / `'Commande en cours'` | Tab 2 "À commander" |
| `'À planifier'` / `'En pose'` | Tab 3 "À planifier" |
| `'À clôturer'` / `'Terminé'` / `'Clôturé'` | Tab 4 "À clôturer" |

### Qui écrit quoi (VALIDÉ 2026-06-17)

| Acteur | Action dans l'app | Status écrit | Fichier |
|--------|------------------|-------------|---------|
| Commercial | Crée devis | `'Nouvelle demande'` | commercial_home_screen.dart |
| Métreur | "Accepter la demande" | `'Acceptée'` | metreur_home_screen.dart `_acceptRequest` |
| Métreur | "Prendre RDV" | `'En cours'` + `meetingAt` | metreur_home_screen.dart `_scheduleMeeting` |
| Métreur | "Terminer et Valider" métré | `'À commander'` | metreur_home_screen.dart `_openMeasurementForm` |
| Métreur | "Confirmer commande" | `'À planifier'` | metreur_home_screen.dart `_showConfirmOrderSheet` |
| Métreur | "Programmer pose" | `'En pose'` | metreur_home_screen.dart `_showSchedulePoseSheet` |
| Poseur | Rapport OK | `'Terminé'` | poseurs_home_screen.dart |
| Poseur | Rapport problème | `'À clôturer'` | poseurs_home_screen.dart |

---

## 4. Structure Firestore

```
workspaces/
  {workspaceId}/
    - companyName, siret, address, postalCode, city
    - adminEmail, adminUid
    - creatorFirstName, creatorLastName
    - tradeKey ('menuiserie_aluminium')
    - plan: { id, name, priceDisplay, seatsByRole, features, isUnlimited }
    - seatUsage
    - status: 'trial' | 'active' | 'expired'
    - trialStartAt, trialEndsAt (Timestamp)
    - subscriptionStatus: 'trial'
    - createdAt, updatedAt

    devis/
      {devisId}/
        - client (nom affiché)
        - clientFirstName, clientName (prénom/nom séparés)
        - address (adresse complète formatée)
        - phone, email
        - status (⚠️ CHAMP CRITIQUE — voir §3)
        - assignedMetreurId, assignedMetreurName
        - poseurIds (List<String>) — pour arrayContains query
        - poseurNames (String formaté)
        - poseDate (Timestamp)
        - uploadUrl (URL PDF devis commercial uploadé)
        - summary (List<Map> — résumé produits : label "Élément X", value "Catégorie • SousCategorie • Type • Qté: N")
        - attachments (List<Map> — [{label, thumbnailUrl}])
        - note, commentaire
        - infoRequest: { message, requestedAt, metreurId }
        - rapportFin: { reglementOk, photos (List<String>), createdAt }
        - rapportProbleme: { souci, manque, erreur, createdAt }
        - draft: { clientName, clientFirstName, street, postal, city, phone,
                   email, commentaire, chantierNotes, chantierType,
                   typeHabitation, accessibilite, date, products (List),
                   assignedMetreurId, assignedMetreurName }
        - userId (uid du créateur)
        - workspaceId
        - metreurId
        - category (label catégorie)
        - createdAt, updatedAt

    invites/
      {inviteId}/
        - email, role, tradeKey, status ('pending'|'used'), workspaceId, createdAt

users/
  {uid}/
    - uid, email, firstName, lastName
    - role: 'admin' | 'commercial' | 'metreur' | 'poseur'
    - companyId (= workspaceId) ← les deux champs existent toujours
    - workspaceId                ← champ canonique depuis 2026-06-11
    - tradeKey
    - status: 'active' | 'provisioned' | 'disabled'
    - fcmToken (sauvegardé au login par AuthNavigationService)
    - createdAt
```

⚠️ **Les deux champs `companyId` et `workspaceId` ont toujours la même valeur.**
Ils coexistent pour rétro-compat. Toujours écrire les DEUX. Lire en priorité `workspaceId` avec fallback `companyId`.

**Index Firestore déployé** : `devis` — `poseurIds` (ARRAY_CONTAINS) + `poseDate` (ASCENDING)

---

## 5. SharedPreferences — clés

| Clé | Type | Contenu |
|-----|------|---------|
| `workit_workspace_id` | String | ID du workspace courant |
| `workit_workspace_name` | String | Nom de l'entreprise |
| `workit_user_first_name` | String | Prénom de l'utilisateur connecté |
| `workit_user_last_name` | String | Nom de l'utilisateur connecté |
| `workit_is_admin` | bool | true si l'utilisateur est admin |
| `workit_trade_key` | String | ex: 'menuiserie_aluminium' |
| `workit_faceid_enabled` | bool | FaceID activé pour l'accès |

---

## 6. Navigation / Routing

### Routing post-connexion (`auth_navigation_service.dart`)

```
FirebaseAuth.currentUser → lit users/{uid} (GET direct, pas de query) →
  regarde userData['workspaceId'] ?? userData['companyId'] →
  lit workspaces/{workspaceId} (GET direct) →
  regarde userData['role'] →
    'admin'      → AdminHomeScreen
    'commercial' → CommercialHomeScreen
    'metreur'    → MetreurHomeScreen
    'poseur'     → PoseursHomeScreen
    sinon        → SnackBar erreur
```

⚠️ **Uniquement des GET par ID direct — jamais de query dans navigateUser().**
Les queries Firestore exigent des règles différentes et causaient des permission-denied.

### Flow d'inscription (simplifié — 5 écrans)

```
EntryScreen
  → AccountSetupScreen (prénom, nom, email, mdp) — step 1/3
    → CreateWorkspaceScreen (nom entreprise, SIRET, adresse) — step 2/3
      → PlanSelectionScreen (choix forfait) — step 3/3
        → FinalSaveScreen (spinner auto-save)
          → AdminHomeScreen
```

**Ce qui est créé dans Firebase lors de l'inscription** :
- `workspaces/{id}` — document workspace complet
- `users/{adminUid}` — document utilisateur admin (rôle, companyId, workspaceId, tradeKey)
- SharedPreferences : workspace_id, workspace_name, firstName, lastName, is_admin=true, trade_key

### Flow d'invitation (membres provisionnés)

```
Admin → AdminTeamTab → "Ajouter" → _AddMemberSheet
  → appel Cloud Function 'provisionAccounts' (europe-west1)
  → retourne tempPassword
  → bottom sheet "Compte créé ✓" avec mdp à copier/partager

Membre → SignInScreen → saisit email + mdp temporaire
  → Firebase Auth signIn
  → AuthNavigationService.navigateUser() → bon HomeScreen selon rôle
  (si mustChangePassword == true → CompleteProfileScreen d'abord)
```

---

## 7. Cloud Functions déployées

**Fichier** : `/Users/macbook/workit/functions/index.js`
**Région** : europe-west1
**Dernier déploiement** : 2026-06-11

### `onDevisStatusChange` (trigger Firestore)

Déclenché à chaque écriture sur `workspaces/{workspaceId}/devis/{devisId}`.
Lit `before.status || before.metreurStatus` pour rétro-compat (ancien champ bugué).

| Nouveau status | Qui est notifié | Message |
|---------------|----------------|---------|
| `'Nouvelle demande'` | Métreur assigné + Admin | "Nouveau chantier à métrer" |
| `'Acceptée'` | Commercial + Admin | "va être métré par [Métreur]" |
| `'À commander'` | Commercial + Admin | "Métré terminé, commande à passer" |
| `'À planifier'` | Commercial + Admin | "Commande confirmée" |
| `'En pose'` | Poseurs + Commercial + Admin | date+heure + équipe |
| `'Terminé'` | Commercial + Admin | "Chantier terminé" |
| `'À clôturer'` | Commercial + Admin | "Problème signalé" |

### `provisionAccounts` (HTTP callable)

Crée un compte Firebase Auth avec mot de passe temporaire.

**CRITIQUE** : la fonction écrit DEUX champs dans `users/{uid}` :
```javascript
companyId: companyId,    // pour rétro-compat
workspaceId: companyId,  // champ canonique — AJOUTÉ EN 2026-06-11
```
Sans `workspaceId`, les règles Firestore refusaient la connexion du commercial.

**Appel depuis Flutter (admin_team_tab.dart) :**
```dart
final fn = FirebaseFunctions.instanceFor(region: 'europe-west1')
    .httpsCallable('provisionAccounts');
final result = await fn.call({
  'accounts': [{
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'role': role, // 'commercial' | 'metreur' | 'poseur'
    'companyId': workspaceId,
  }]
});
// Retourne : result.data['accounts'][0]['tempPassword']
```

---

## 8. Firestore — Règles de sécurité

**Fichier** : `/Users/macbook/workit/firestore.rules`
**Déployé** : 2026-06-12 ✅ (pas en mode test — vraies règles)

### Architecture des règles

```
users/{userId}
  allow get  : soi-même OU même workspace (via myWorkspaceId())
  allow list : tout user authentifié dont le doc a un workspaceId non-vide
               → pas d'appel me() pour les queries streaming = pas de permission-denied
  allow create : soi-même uniquement
  allow update : soi-même OU admin du même workspace
  allow delete : jamais

workspaces/{workspaceId}
  allow get/list/update : adminUid == uid OU myWorkspaceId() == workspaceId
  allow create : adminUid == uid
  allow delete : jamais

workspaces/{workspaceId}/devis/{devisId}
  allow read/write : adminUid == uid OU myWorkspaceId() == workspaceId

workspaces/{workspaceId}/invites/{inviteId}
  allow read : tout authentifié
  allow create/update : admin OU membre du workspace

trial_sessions, provisioned_accounts : tout authentifié
```

### Helpers clés

```javascript
function myWorkspaceId() {
  let d = me(); // get(users/{uid})
  return d.get('workspaceId', d.get('companyId', ''));
}
```

### Règle critique pour list users (évite permission-denied sur stream)

```javascript
// LIST — pas d'appel me() pour éviter les erreurs sur queries streaming
allow list: if isAuth() &&
  resource.data.get('workspaceId', resource.data.get('companyId', '')) != '';
```

⚠️ Pourquoi pas `myWorkspaceId()` dans `allow list` ?
Les queries Firestore streaming évaluent la règle pour chaque document. L'appel `me()` dans une règle `list` peut causer des problèmes de quota. La solution : ne vérifier que le document lui-même (has workspaceId ≠ '') sans appel `get()`.

---

## 9. État de chaque écran/fichier

### ✅ TERMINÉ ET OPÉRATIONNEL

#### `lib/screens/entry_screen.dart`
- Écran d'accueil : "Se connecter" + "Créer mon espace"
- FaceID si déjà connecté

#### `lib/screens/account_setup_screen.dart`
- Prénom + Nom + Email + Mot de passe (avec œil toggle)
- Validation email : RegExp `r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}'`
- Email `.toLowerCase()` avant Firebase
- Gestion erreur `invalid-credential` + `email-already-in-use` (Firebase Auth v5)
- Step 1/3

#### `lib/screens/create_workspace_screen.dart`
- Champs : nom entreprise, SIRET, adresse, code postal, ville
- Step 2/3, tradeKey forcé à 'menuiserie_aluminium'

#### `lib/screens/plan_selection_screen.dart`
- 3 plans (Starter, Pro, Entreprise), step 3/3
- Navigate → FinalSaveScreen

#### `lib/screens/final_save_screen.dart`
- Auto-save au initState via addPostFrameCallback
- Appelle WorkspaceRepository.createWorkspace()
- Sauvegarde SharedPreferences
- Success → AdminHomeScreen (pushAndRemoveUntil)

#### `lib/data/workspace_repository.dart`
- Batch write : workspace + users/{adminUid}
- users/{adminUid} : uid, email, firstName, lastName, role='admin', companyId, workspaceId, tradeKey

#### `lib/screens/sign_in_screen.dart`
- Email + mot de passe → AuthNavigationService.navigateUser()

#### `lib/services/auth_navigation_service.dart`
- GET direct users/{uid} → workspaceId → GET workspaces/{workspaceId}
- Sauvegarde FCM token
- Route selon rôle : admin/commercial/metreur/poseur

#### `lib/screens/admin_home_screen.dart`
- 3 onglets : Dashboard · Équipe · Entreprise
- Charge workspaceId depuis SharedPreferences, passe aux 3 tabs

#### `lib/screens/admin_dashboard_tab.dart` (DERNIÈRE MODIF : 2026-06-17)
- Stat cards 2x2, liste 20 derniers chantiers
- Stream sur devis, filtre par status
- Détail devis (bottom sheet) :
  - Nom client + adresse + status chip
  - Éléments : "Catégorie : SousCategorie — N pcs" (ex: "Menuiserie Extérieure : PVC — 1 pcs")
  - Total pièces
  - Métreur assigné (ou '—' si pas encore assigné)
  - Poseurs + date de pose (si planifié)
  - Bouton "Ouvrir le devis commercial" → ouvre uploadUrl/attachments en browser externe
  - Alerte info client / problème / rapport de fin si présents
- ⚠️ PAS de phone/email du client dans la vue admin (inutile)
- `_InfoRow` utilise `Flexible` pour éviter overflow sur labels longs
- Import `url_launcher` requis (pour le bouton PDF)

#### `lib/screens/admin_team_tab.dart` (MODIF : 2026-06-12)
- Query : `users.where('workspaceId', isEqualTo: workspaceId)` ← champ canonique
- Filtre : `status != 'disabled' && role != 'admin'` ← admin exclu de sa propre liste
- Bouton Ajouter → provisionAccounts → bottom sheet avec mdp

#### `lib/screens/admin_company_tab.dart` (MODIF : 2026-06-11)
- Email pré-rempli : `data['email'] ?? data['adminEmail']`
- Téléphone : chiffres uniquement, max 10

#### `lib/screens/invite_activation_screen.dart`
- Routing après activation → AuthNavigationService().navigateUser()

#### `lib/screens/commercial_home_screen.dart` (DERNIÈRE MODIF : 2026-06-17)
- **5 onglets** (était 6 — suppression "En cours de métré") avec compteurs temps réel
- Onglets : "En attente" / "Métré programmé" / "À commander" / "En pose" / "Terminés"
- "En attente" = null / 'Nouvelle demande' / 'Acceptée'
- "Métré programmé" = 'En cours' uniquement (plus de logique meetingAt)
- "À commander" (était "En commande") = 'À commander' / 'Commande en cours'
- Deux StreamBuilder imbriqués : header TabBar + body TabBarView (même logique de filtrage)
- Tous les filtres : `status ?? metreurStatus` (rétro-compat)
- **Couleur par défaut** : `_defaultCouleurForTrade()` retourne 'RAL Aluminium' / 'Couleur PVC' / 'Essence de Bois'
- **Summary amélioré** : `_typeLabelFromKey()` convertit les clés type en libellés lisibles

#### `lib/screens/metreur_home_screen.dart` (DERNIÈRE MODIF : 2026-06-17)
- **4 onglets** : "En cours" / "À commander" / "À planifier" / "À clôturer"
- Stream Firestore temps réel (`StreamSubscription<QuerySnapshot>` + `_devisSubscription`)
- Bucketing `_onDevisSnapshot` :
  - null / 'Nouvelle demande' / 'Acceptée' → `_newRequests` (home Tab 1)
  - 'En cours' → `_acceptedRequests` (Tab 1, section "Demandes acceptées")
  - 'À commander' → `_toOrder` (Tab 2)
  - 'À planifier' / 'En pose' → `_toPlan` (Tab 3)
  - 'À clôturer' / 'Terminé' / 'Clôturé' → `_toClose` (Tab 4)
- `_scheduleMeeting` : écrit `status: 'En cours'` + `meetingAt` en Firestore, déplace item localement
- `_openMeasurementForm` : écrit `status: 'À commander'` en Firestore après "Terminer et Valider"
- `_MeasureRequestSummary` reçoit `workspaceId` en paramètre (fallback si `data.workspaceId` null)
- `_persistRequestToCloud` : écrit `status` (PAS `metreurStatus`)
- `_askForInfo` : écrit `metreurNote`, `metreurNoteName`, `metreurNoteAt` en Firestore

#### `lib/screens/measurement_form_screen.dart`
- Formulaire métré + génération PDF

#### `lib/screens/poseurs_home_screen.dart`
- 2 onglets : À faire + Historique
- Query : `poseurIds arrayContains uid` (index composite déployé)

#### `lib/screens/settings_screen.dart`
- Déconnexion, FaceID toggle

---

### ⏸️ FICHIERS ORPHELINS (compilent, ne servent plus)

- `welcome_screen.dart`, `journey_selection_screen.dart`, `select_metier_screen.dart`
- `invite_team_screen.dart`, `admin_summary_screen.dart`, `trial_activation_screen.dart`

Peuvent être supprimés proprement lors d'une session de nettoyage.

---

### ❌ NON IMPLÉMENTÉ

1. **Stripe / Abonnements** — aucun code, à faire entièrement
2. **APNs iOS** — config manuelle Apple Developer Portal (Claude ne peut pas)
3. **Recherche** dans les écrans métreur/admin
4. **Mode offline** / retry réseau automatique

---

## 10. Bugs corrigés (journal complet)

### Bug #1 — metreurStatus vs status (CORRIGÉ 2026-06-11)
**Symptôme** : Onglets commercial ne changeaient jamais.
**Fix** : Lectures `data['status'] ?? data['metreurStatus']`, écritures `'status'`.

### Bug #2 — Routing après invitation (CORRIGÉ)
**Fix** : `AuthNavigationService().navigateUser()` dans invite_activation_screen.dart.

### Bug #3 — Admin jamais routé (CORRIGÉ)
**Fix** : Ajout `case 'admin': return AdminHomeScreen()` dans auth_navigation_service.dart.

### Bug #4 — users/{adminUid} manquant (CORRIGÉ)
**Fix** : Batch write dans workspace_repository.dart.

### Bug #5 — "The supplied auth credential is malformed" (CORRIGÉ 2026-06-11)
**Cause** : Firebase Auth v5 retourne `invalid-credential` (pas `email-already-in-use`) avec email enumeration protection.
**Fix** : Ajout du case `invalid-credential` dans account_setup_screen.dart, suppression de l'auto-sign-in fallback.

### Bug #6 — permission-denied sur FinalSaveScreen (CORRIGÉ 2026-06-11)
**Cause** : Pas de fichier `firestore.rules` — Firestore en mode "deny all".
**Fix** : Création du fichier firestore.rules + ajout dans firebase.json + déploiement.

### Bug #7 — permission-denied dans AuthNavigationService (CORRIGÉ 2026-06-11)
**Cause** : navigateUser() utilisait des queries Firestore (.where). Les queries ont des règles d'évaluation différentes et causaient permission-denied.
**Fix** : Remplacement de toutes les queries par des GET directs par ID (`users/{uid}` puis `workspaces/{workspaceId}`).

### Bug #8 — permission-denied pour commercial (CORRIGÉ 2026-06-11)
**Cause** : provisionAccounts sauvegardait `companyId` mais PAS `workspaceId`. La règle `myWorkspaceId()` lisait `workspaceId` → null → permission denied.
**Fix** : Ajout `workspaceId: companyId` dans provisionAccounts + règle fallback `d.get('workspaceId', d.get('companyId', ''))`.

### Bug #9 — Admin Équipe "Erreur de chargement" (CORRIGÉ 2026-06-12)
**Cause 1** : Query utilisait `where('companyId', ...)` alors que le champ canonique est maintenant `workspaceId`.
**Cause 2** : La règle `allow list` utilisait `myWorkspaceId()` → appel `me()` → problèmes de quota/permission sur queries streaming.
**Fix** :
- Query changée vers `where('workspaceId', isEqualTo: workspaceId)`
- Règle `allow list` simplifiée : vérifie uniquement que le doc a un `workspaceId` non vide (sans appel `me()`)
- Ajout affichage de l'erreur réelle dans le StreamBuilder (exit du message générique)
- Déploiement rules : `firebase deploy --only firestore:rules` ✅

### Bug #10 — Admin s'affichait dans la liste de son équipe (CORRIGÉ 2026-06-12)
**Fix** : Filtre `role != 'admin'` dans le StreamBuilder de admin_team_tab.dart.

### Bug #11 — Couleur RAL non visible par défaut dans le formulaire devis (CORRIGÉ 2026-06-15)
**Cause** : `product.couleur` était null → `_colorDetailLabel(null)` retournait null → champ RAL caché. Le dropdown affichait "RAL Aluminium" visuellement (premier item) mais la valeur réelle était null.
**Fix** :
- Méthode `_defaultCouleurForTrade()` : retourne le bon défaut selon tradeKey
- `_ensureDefaultCategoryForProducts()` : initialise aussi `couleur` quand null
- `_newProductWithDefaultCategory()` : inclut `couleur` par défaut

### Bug #12 — Bouton "Se déconnecter" dans le step 2 du formulaire devis (CORRIGÉ 2026-06-15)
**Cause** : Un `IconButton` logout était dans le `Wrap` du titre "Infos générales chantier" dans `_chantierForm()`.
**Fix** : Suppression de l'IconButton.

### Bug #14 — Métreur écrivait `metreurStatus` au lieu de `status` (CORRIGÉ 2026-06-15)
**Symptôme** : Après acceptation par le métreur, le devis restait dans "En attente" côté commercial au lieu de passer en "En cours de métré".
**Cause** : `_persistRequestToCloud()` et toutes les autres écritures Firestore du métreur utilisaient le champ `metreurStatus` (ancien champ bugué) au lieu de `status`.
**Fixes dans `metreur_home_screen.dart`** :
- `_persistRequestToCloud` : `'metreurStatus': data.status` → `'status': data.status ?? 'Acceptée'`
- `_showConfirmOrderSheet` : `'metreurStatus': 'À planifier'` → `'status': 'À planifier'`
- `_showSchedulePoseSheet` : `'metreurStatus': 'En pose'` → `'status': 'En pose'`
- `MeasurementFormScreen` save : `'metreurStatus': 'À commander'` → `'status': 'À commander'`
- Lecture `_MeasureCardData.fromMap` : ordre inversé → `status ?? metreurStatus` (canonique en premier)

### Bug #15 — Machine à états incohérente entre les 3 écrans (CORRIGÉ 2026-06-17)
**Symptôme** : Après acceptation, commercial passait en "En cours de métré" (mauvais). Après RDV, rien ne changeait. Après métré terminé, tout revenait à "En attente".
**Causes multiples** :
- Commercial : 'Acceptée' était dans "En cours de métré" au lieu de rester "En attente"
- `_scheduleMeeting` n'écrivait que `meetingAt` mais pas `status: 'En cours'`
- `_openMeasurementForm` n'écrivait jamais `status: 'À commander'`
- Admin : 'Acceptée' comptait dans "Métré en cours" au lieu de "En attente"
**Fixes** :
- `_scheduleMeeting` : ajoute `'status': 'En cours'` dans l'écriture Firestore
- `_openMeasurementForm` : ajoute `'status': 'À commander'` dans l'écriture Firestore
- Commercial : 5 onglets (suppression "En cours de métré") — 'Acceptée' reste "En attente", 'En cours' → "Métré programmé"
- Admin : 'Acceptée' → "En attente" (bleu), 'En cours' uniquement → "Métré en cours" (orange)
- Métreur bucketing : 'Acceptée' → `_newRequests` (home), 'En cours' → `_acceptedRequests` (onglet)

### Bug #16 — workspaceId null dans _openMeasurementForm (CORRIGÉ 2026-06-17)
**Symptôme** : Exception silencieuse dans le catch → rien ne se passait après "Terminer et Valider"
**Cause** : `data.workspaceId` pouvait être null, `throw 'Workspace ID missing'` capturé par catch → aucun feedback
**Fix** :
- `_MeasureRequestSummary` reçoit `workspaceId: _workspaceId` en paramètre
- Fallback : `final wsId = data.workspaceId ?? widget.workspaceId`
- `data.draft` nullable : `updatedDraft` n'est calculé que si `data.draft != null`

### Bug #13 — Admin dashboard détail : phone visible, libellés bruts, pas de PDF (CORRIGÉ 2026-06-15)
**Cause** :
- Phone/email du client affiché (inutile pour admin)
- `categoryKey` et `typeProduit` affichés comme clés brutes (ex: `menuiseries_exterieures`, `a_la_francaise`)
- Pas de lien vers le PDF/devis uploadé par le commercial
**Fix** :
- Suppression section phone/email du détail admin
- Méthode `_typeLabelFromKey()` pour convertir les clés type en libellés lisibles dans le summary
- Affichage "Catégorie : SousCategorie — N pcs" en utilisant `summary` (déjà formaté) + `draft.products` pour les quantités
- Bouton "Ouvrir le devis commercial" → `launchUrl(uploadUrl)` en browser externe
- `_InfoRow` : `Text(label)` → `Flexible(child: Text(label, overflow: ellipsis))` pour éviter overflow
- `_ContactRow` class supprimée (devenue orpheline)

---

## 11. Thème et couleurs

| Constante | Valeur hex | Usage |
|-----------|-----------|-------|
| Background global | `#07090D` | Toutes les pages |
| Card global | `#0F1422` | Cartes, conteneurs |
| Accent global | `#00E676` | Admin, global |
| Accent commercial | `#00F795` | Commercial uniquement |
| Commercial role | `Colors.blueAccent` | Avatars team |
| Métreur role | `Colors.orange` | Avatars team |
| Poseur role | `Colors.purple` | Avatars team |

---

## 12. pubspec.yaml — dépendances clés

```yaml
dependencies:
  firebase_core: ^3.x
  firebase_auth: ^5.x
  cloud_firestore: ^5.x
  firebase_storage: ^12.x
  firebase_messaging: ^15.0.0
  cloud_functions: ^5.x
  shared_preferences: ^2.x
  file_picker: ^8.x
  image_picker: ^1.x
  url_launcher: ^6.x
  http: ^1.x
  path: ^1.x
  local_auth: ^2.x
  pdf: ^3.11.1
  printing: ^5.13.1
```

---

## 13. Commandes utiles

```bash
# Analyser le code (objectif : 0 errors)
flutter analyze

# Lancer l'app simulateur
flutter run

# Déployer uniquement les règles Firestore
cd /Users/macbook/workit && firebase deploy --only firestore:rules

# Déployer les Cloud Functions
firebase deploy --only functions

# Déployer les index Firestore
firebase deploy --only firestore:indexes

# Voir les logs Cloud Functions
firebase functions:log

# Déployer tout Firebase
firebase deploy
```

---

## 14. Ce qu'il faut faire à la prochaine session

### Priorité haute — À TESTER EN PREMIER
1. **Tester le flow poseur bout en bout** (jamais testé)
   - Métreur programme pose (date + poseurs) → status 'En pose'
   - Poseur voit dans onglet "À faire" de PoseursHomeScreen
   - Poseur soumet rapport → 'Terminé' ou 'À clôturer'
   - Commercial/Admin voient dans "Terminés"

2. **Vérifier les notifications FCM** (Android — iOS attend APNs)

### Priorité moyenne
3. **Stripe** — intégration paiement fin essai 7 jours
4. **APNs iOS** (Apple Developer Portal — config manuelle par Christophe)

### Priorité basse
5. **Nettoyage** des écrans orphelins
6. **Recherche** dans écrans métreur/admin

---

## 15. Contexte personnel (Christophe)

- **Fondateur** de WorkIt ET Poppins (deux projets séparés sur le même Mac)
- WorkIt : `/Users/macbook/workit/`
- Email principal : chrisbeylet@gmail.com
- Email secondaire : cbeylet06@gmail.com
- Les deux sessions Claude ont accès au même filesystem

---

## 16. Note pour Claude en début de session

**Si tu es Claude et que tu lis ce fichier** :

1. Lire ce fichier EN ENTIER avant de faire quoi que ce soit
2. Ne pas réinitialiser l'architecture — tout est déjà implémenté
3. Le champ critique est `status` (PAS `metreurStatus` — ancien champ bugué)
4. Ne pas utiliser Riverpod — StatefulWidget + SharedPreferences uniquement
5. Toujours écrire dans Firestore avec `SetOptions(merge: true)` sauf création initiale
6. La région Cloud Functions est TOUJOURS `europe-west1`
7. Firebase Storage bucket : `gs://workit-1daa1.firebasestorage.app`
8. Avant toute modification d'un fichier : le lire d'abord (Write tool refuse sinon)
9. Objectif : 0 erreur `flutter analyze` à chaque fin de session
10. Les queries Firestore sur `users` filtrent par `workspaceId` (pas `companyId`)
11. Ne JAMAIS utiliser de query dans AuthNavigationService — GET directs uniquement
12. Pour redéployer les règles : `firebase deploy --only firestore:rules`
13. `_InfoRow` dans admin_dashboard_tab utilise `Flexible` pour le label (pas `Text` simple)
14. Le `summary` des devis contient "Catégorie • SousCategorie • Type • Qté: N" — utiliser les 2 premiers segments pour l'affichage admin
15. Le bouton PDF admin utilise `data['uploadUrl']` en priorité, fallback sur `data['attachments'][0]['thumbnailUrl']`

---

## 17. ⚠️ REFONTE DESIGN EN COURS (depuis 2026-06-29)

Christophe a démarré seul une refonte visuelle complète : passage du thème sombre (`#07090D`) à un **thème clair** avec un vrai design system. Il a dit explicitement : *"je me suis occupé de la refonte design, prochaines sessions je remets toutes les fonctionnalités en place juste avant"* — autrement dit, **certaines fonctionnalités ont été sacrifiées visuellement pendant la refonte et doivent être rebranchées**.

### Maquettes de référence : `/Users/macbook/workit/Ref/`

4 fichiers (captures d'écran + palette Adobe Color) :
- `AdobeColor-Mon thème de couleurs (1).jpeg` — palette officielle
- `Capture d'écran ... 16.07.09.png` — maquette **Commercial**
- `Capture d'écran ... 16.07.16.png` — maquette **Métreur** ("Gestion chantiers")
- `Capture d'écran ... 16.07.24.png` — maquette **Poseur** ("Mes chantiers")

### Palette officielle (Adobe Color)

| Couleur | Hex | Usage prévu |
|---|---|---|
| Violet | `#763DF2` | Métreur (rôle), statut "Programmé" |
| Bleu | `#296CF2` | Commercial (rôle), statut "À planifier" |
| Vert | `#078C5B` | Poseur (rôle), statut "En pose / Terminé" |
| Orange | `#D96B0B` | Statut "À commander" |
| Gris clair | `#F2F2F2` | Fond / surfaces |

⚠️ **Écart actuel** : `lib/core/theme/app_colors.dart` utilise des couleurs différentes (`primary: #2563EB`, `purple: #7C3AED`, `success: #059669`, `warning: #D97706`) — proches mais pas identiques à la palette Adobe Color officielle. À harmoniser si Christophe veut un match exact.

### Légende statuts commune aux 3 maquettes (en bas de chaque écran)
`En attente` (orange) · `Programmé` (violet) · `À commander` (marron/orange foncé) · `À planifier` (bleu) · `En pose / Terminé` (vert) · `Problème` (rouge)

### Ce que montrent les maquettes (cible à atteindre)

**Commercial** (`Bonjour, Marc 👋` + avatar "MC") :
- Pills : Tous / En attente / Devis prog. / À commander (scrollable, pills non sélectionnées ont une bordure visible — actuellement implémenté SANS bordure, à vérifier)
- Stats 3 cards : En attente / En cours / Terminés
- Cartes "Affaires récentes" avec **prix affiché** (`4 200 €`) — **absent du code actuel**, à ajouter
- Dots de progression **5 étapes** sous chaque carte (cohérent avec le code actuel)
- Bottom nav maquette : **Accueil / Devis (badge rouge "4") / Chantiers / Profil** — le code actuel a *Accueil/Devis/Agenda/Réglages* sans badge ni navigation fonctionnelle → à corriger

**Métreur** ("Gestion chantiers", `Metteur en œuvre · 7 actions à traiter`, avatar violet "PL") :
- Pills : Tous / En attente / En cours / À commander
- Stats 3 cards : Urgent / À commander / À planifier
- Section "⚠️ ACTIONS URGENTES" — **n'existe pas dans le code actuel**, à créer
- Cartes avec **barre colorée verticale à gauche** (orange/bleu/marron selon statut) — absent du code actuel
- Dots de progression **7 étapes** (pas 5 comme commercial !)
- Boutons spécifiques par statut : "Voir devis"+"Accepter →", "Prendre RDV"+"Faire le métré", etc. — pas génériques comme "Voir détails"+CTA actuel
- Bottom nav maquette : **Tableau de bord / Planning (badge "2") / Équipes / Profil**

**Poseur** ("Mes chantiers", `Poseur · 2 chantiers assignés`, avatar vert "JD") :
- Pills : Tous / À venir / Terminés
- Stats 2 cards seulement : Chantiers à venir / Chantiers terminés
- Section "📅 CHANTIER À VENIR" avec carte encadrée (bordure bleue complète, pas juste latérale)
- Carte affiche : date+heure, nb personnes, durée estimée, boutons "Itinéraire"+"Détails", puis bloc "ACTIONS SUR CHANTIER" (Déclarer fin / Photos-Doc / Signaler un problème)
- Bottom nav maquette : **Mes chantiers / Planning / Photos / Profil**
- ⚠️ Le screen actuel (`poseurs_home_screen.dart`) n'a probablement pas encore ce design (à vérifier en priorité à la prochaine session, pas encore audité comme Commercial)

### À faire à la prochaine session (ordre conseillé)
1. Auditer `poseurs_home_screen.dart` (pas encore fait, contrairement à Commercial)
2. Rebrancher les 4 points identifiés côté Commercial (cf. section 9) : bottom nav fonctionnel, calendrier, accès admin, confirmation logout
3. Ajouter le prix sur les cartes commercial (absent vs maquette)
4. Vérifier/adapter le nombre de dots de progression par écran (5 pour commercial, 7 pour métreur d'après la maquette)
5. Décider si on harmonise `app_colors.dart` avec la palette Adobe Color exacte ou si on garde les couleurs actuelles (proches mais différentes)
6. Section "Actions urgentes" + barres colorées latérales côté métreur (présent en maquette, absent du code)

---

*Ce fichier est le point d'entrée unique pour reprendre le travail sans perdre de temps.*
*Mis à jour à chaque fin de session significative.*
