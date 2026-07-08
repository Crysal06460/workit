# 📋 RAPPORT D'ANALYSE COMPLÈTE — Application WorkIt

**Projet :** WorkIt — Gestion de chantiers B2B (second œuvre)
**Branche :** `team-work/equipe-1-analyse`
**Firebase Project ID :** `workit-1daa1`
**Stack :** Flutter (Dart) · Firebase Auth · Cloud Firestore · Firebase Storage · Firebase Cloud Messaging · Firebase Functions · Stripe (prévu)
**État :** 🟢 Initialisé — En développement actif (4 agents parallèles, plan 5 semaines vers production)

---

## 1. ARCHITECTURE GÉNÉRALE

### 1.1 Structure des dossiers (`lib/`)

```
lib/
├── main.dart                          # Point d'entrée : Firebase init, FCM, router startup
├── firebase_options.dart              # Config Firebase multi-platforme
│
├── core/
│   ├── workit_design_system.dart      # Barrel export — import unique du DS
│   ├── theme/
│   │   ├── app_colors.dart            # Palette complète (primaires, rôles, statuts)
│   │   └── app_theme.dart             # Thème Material 3 complet
│   └── widgets/
│       ├── wi_bottom_nav.dart         # Barre de navigation générique
│       ├── wi_cta_button.dart         # CTA pleine largeur
│       ├── wi_devis_card.dart         # Carte devis avec statut/montant/actions
│       ├── wi_filter_pills.dart       # Pills de filtrage scrollables
│       ├── wi_stat_row.dart           # Ligne de 2-3 stats
│       └── wi_status_badge.dart       # Badge coloré par statut
│
├── models/
│   └── onboarding_models.dart         # OnboardingData, PlanOption, helpers
│
├── data/
│   └── workspace_repository.dart      # Création Firestore workspace + batch invites
│
├── services/
│   ├── auth_navigation_service.dart   # Singleton : routing post-auth par rôle
│   ├── devis_service.dart             # CRUD devis + notifications Firestore
│   ├── trial_service.dart             # Gestion trial 7 jours
│   └── quote_keyword_analyzer.dart    # Analyse sémantique des devis
│
└── screens/
    ├── entry_screen.dart              # Écran d'accueil (Bon retour 👋)
    ├── sign_in_screen.dart            # Connexion + CompleteProfileScreen
    ├── onboarding_screen.dart         # Parcours complet : splash → slides → trades → company → role → account → success
    ├── welcome_screen.dart            # Écran d'accueil onboarding
    ├── select_metier_screen.dart      # Choix corps de métier
    ├── journey_selection_screen.dart  # Parcours A (structuré) / B (artisan)
    ├── account_setup_screen.dart      # Création compte Firebase Auth
    ├── create_workspace_screen.dart   # Création workspace + infos entreprise
    ├── plan_selection_screen.dart     # Choix formule (abonnement_1/2/3)
    ├── invite_team_screen.dart        # Invitation équipe par rôle
    ├── invite_activation_screen.dart  # Activation des codes d'invitation
    ├── admin_summary_screen.dart      # Résumé avant création workspace
    ├── final_save_screen.dart         # Écran final onboarding
    ├── join_workspace_screen.dart     # Rejoindre workspace par code
    ├── trial_activation_screen.dart   # Activation période d'essai
    ├── trial_expired_screen.dart      # Essai expiré
    │
    ├── commercial_home_screen.dart    # Home commercial : TabBar 7 statuts, stats, recherche
    ├── metreur_home_screen.dart       # Home métreur : 6 onglets, streaming devis, cache local
    ├── poseurs_home_screen.dart       # Home poseur : 2 tabs (À faire / Historique), photos
    ├── admin_home_screen.dart         # Admin : TabBar 3 onglets (Dashboard, Équipe, Entreprise)
    ├── admin_dashboard_tab.dart       # KPIs, derniers chantiers, détail modal
    ├── admin_team_tab.dart            # Gestion équipe, provision comptes via Cloud Functions
    ├── admin_company_tab.dart         # Infos entreprise (édition)
    ├── settings_screen.dart           # Paramètres utilisateur
    ├── measurement_form_screen.dart   # Formulaire de métré
    ├── select_metier_screen.dart      # (duplicate logique onboarding)
    └── widgets/
        └── dynamic_dropdown_field.dart # Champ dropdown réutilisable
```

### 1.2 Modèle de données Firestore

```
Collections Firestore :
├── users/{uid}
│   ├── uid, email, firstName, lastName
│   ├── role: "admin" | "commercial" | "metreur" | "poseur"
│   ├── workspaceId, companyId
│   ├── tradeKey, fcmToken, fcmUpdatedAt
│   ├── status: "active" | "disabled" | "provisioned"
│   ├── tempPassword (provisionné)
│   ├── mustChangePassword (bool)
│   └── createdAt, updatedAt
│
├── workspaces/{workspaceId}
│   ├── companyName, siret, address, postalCode, city, phone, email
│   ├── adminUid, adminEmail
│   ├── tradeKey, journeyType
│   ├── plan: { id, name, priceDisplay, seatsByRole, features, isUnlimited }
│   ├── seatUsage: { commercial: N, metreur: N, poseur: N }
│   ├── joinCodes: { commercial: "COMMERCIAL", metreur: "METREUR", poseur: "POSEURS" }
│   ├── totalInvites
│   ├── creatorUsesWorkit, creatorRole, creatorRoles, creatorFirstName, creatorLastName
│   ├── status: "trial" | "expired" | "active"
│   ├── subscriptionStatus: "trial" | "active" | "expired"
│   ├── trialSessionId, trialStartAt, trialEndsAt
│   ├── createdAt, updatedAt
│   │
│   ├── devis/{devisId}
│   │   ├── client, clientName, clientFirstName, clientLastName
│   │   ├── address, phone
│   │   ├── status: "Nouvelle demande" | "Acceptée" | "En cours" | "À commander" | "Commande en cours" | "À planifier" | "En pose" | "À clôturer" | "Terminé" | "Clôturé" | "Problème chantier"
│   │   ├── metreurStatus (statut miroir depuis métreur)
│   │   ├── category, products/quantities
│   │   ├── assignedMetreurId, metreurId
│   │   ├── poseurIds: [uid1, uid2]
│   │   ├── poseDate, poseurNames
│   │   ├── uploadUrl / attachments
│   │   ├── measuredData (photos, dimensions)
│   │   ├── summary (éléments métrés)
│   │   ├── draft (brouillon poseur avec photos, rapports)
│   │   ├── infoRequest, rapportProbleme, rapportFin
│   │   ├── createdBy, createdByRole
│   │   └── createdAt, updatedAt
│   │
│   ├── notifications/{notifId}
│   │   ├── devisId, targetRole, type, title, body
│   │   ├── read: bool
│   │   └── createdAt
│   │
│   └── invites/{inviteId}
│       ├── email, role, tradeKey
│       ├── status: "pending" | "accepted" | "expired"
│       ├── workspaceId
│       └── createdAt, updatedAt
│
├── trial_sessions/{sessionId}
│   ├── status: "trial" | "expired" | "active"
│   └── startedAt, endsAt, createdAt, updatedAt
│
└── provisioned_accounts/{accountId}
    └── uid, email, status, tempPassword, createdAt, updatedAt
```

---

## 2. RÔLES ET FLUX MÉTIER

### 2.1 Les 4 rôles

| Rôle | Clé | Page d'accueil | Description |
|------|-----|----------------|-------------|
| **Commercial** | `commercial` | `CommercialHomeScreen` | Crée les devis, suit les affaires, gère les prospects |
| **Métreur / Chargé d'études** | `metreur` | `MetreurHomeScreen` | Reçoit les demandes de métré, chiffre, commande, planifie |
| **Poseur / Équipe de pose** | `poseur` | `PoseursHomeScreen` | Exécute les chantiers, prend des photos, remplit les rapports |
| **Administrateur** | `admin` | `AdminHomeScreen` | Tableau de bord KPIs, gestion équipe, paramètres entreprise |

**Rôle composite :** `commercial_metreur` (parcours B / artisan) → redirigé vers `CommercialHomeScreen`.

### 2.2 Flux complet d'une affaire (cycle de vie des statuts)

```
ÉTAPE 1 : Création du devis (Commercial)
  Statut → "Nouvelle demande"
  Action : Le commercial saisit les infos client, upload le PDF, enregistre
  Notif → Métreur : "Nouveau devis — action requise"

ÉTAPE 2 : Prise en charge (Métreur)
  Statut → "En cours" (acceptation)
  Action : Le métreur programme une visite, réalise le métré, chiffre
  Notif → Commercial : "Devis accepté — métré programmé"

ÉTAPE 3 : Commande matériaux (Métreur → Admin)
  Statut → "À commander" → "Commande en cours"
  Action : Le métreur ou l'admin passe commande des matériaux
  Notif → Admin : "Commande passée — suivi en cours"

ÉTAPE 4 : Planification pose (Métreur)
  Statut → "À planifier"
  Action : Le métreur assigne des poseurs, fixe une date
  Notif → Poseur : "Chantier à venir — intervention planifiée"

ÉTAPE 5 : Exécution pose (Poseur)
  Statut → "En pose"
  Action : L'équipe se rend sur place, pose, prend des photos, signale problèmes
  Notif → Commercial : "Pose démarrée — équipe sur place"

ÉTAPE 6 : Clôture (Poseur → Métreur)
  Statut → "À clôturer"
  Action : Le poseur remplit le rapport de fin, confirme règlement
  Notif → Métreur : "Validation de clôture requise"

ÉTAPE 7 : Finalisation
  Statut → "Terminé" → "Clôturé"
  Action : Le métreur valide la clôture, l'affaire est archivée

⚠️ État exceptionnel :
  Statut → "Problème chantier"
  Action : Le poseur signale un problème → Notif Métreur : "Intervention requise"
```

### 2.3 Schéma de navigation (AuthNavigationService)

```
StartupRouter (main.dart)
  ├─ Utilisateur Firebase connecté ?
  │   ├─ OUI → AuthNavigationService.navigateUser()
  │   │   ├─ Lecture document users/{uid}
  │   │   ├─ Extraction workspaceId, rôle
  │   │   ├─ Si mustChangePassword → CompleteProfileScreen
  │   │   ├─ Persistance SharedPreferences (workspace, prénom, rôle)
  │   │   ├─ Sauvegarde FCM token
  │   │   └─ Redirection selon rôle :
  │   │       ├─ commercial → CommercialHomeScreen
  │   │       ├─ metreur → MetreurHomeScreen
  │   │       ├─ poseur → PoseursHomeScreen
  │   │       ├─ commercial_metreur → CommercialHomeScreen
  │   │       └─ admin → AdminHomeScreen
  │   │
  │   └─ NON → Onboarding déjà fait ?
  │       ├─ NON → OnboardingScreen (splash → slides → entry → trades → company → role → account → success)
  │       └─ OUI → EntryScreen (écran "Bon retour 👋" avec connexion/FaceID)
```

---

## 3. SERVICES

### 3.1 AuthNavigationService (singleton)
- **Rôle :** Point central de routage post-authentification.
- **Mécanisme :** Lit `users/{uid}` → récupère `workspaceId` + `role` → lit workspace → persiste en SharedPreferences → navigate vers le bon home screen.
- **Gère :** Changement de mot de passe obligatoire (comptes provisionnés), FaceID, FCM token sync.

### 3.2 DevisService
- **Rôle :** CRUD des devis + système de notifications internes Firestore.
- **Mécanisme :** `createDevis()` écrit le devis + crée une notification dans `workspaces/{id}/notifications`. `updateStatus()` met à jour le statut + notifie le rôle cible selon la transition.
- **Transitions → Notifications :**
  - `En cours` → Commercial ("Métré programmé")
  - `Commande en cours` → Admin ("Matériaux commandés")
  - `À planifier` → Poseur ("Intervention planifiée")
  - `En pose` → Commercial ("Pose démarrée")
  - `À clôturer` → Métreur ("Validation clôture requise")
  - `Problème chantier` → Métreur ("Intervention requise")
- **Badge notifications :** `unreadCount(workspaceId, role)` stream le nombre de notifs non lues.
- **MarkRead :** Marque une notification comme lue.

### 3.3 TrialService
- **Rôle :** Gestion de la période d'essai (7 jours).
- **Mécanisme :** Crée un document `trial_sessions/{id}` avec `status: 'trial'`, `startedAt`, `endsAt`.

### 3.4 QuoteKeywordAnalyzer
- **Rôle :** Analyse sémantique des descriptions de devis.
- **Mécanisme :** Catalogue de ~150 mots-clés organisés par catégories (type_produit, materiaux, couleurs, dimensions, performances, accessoires). Extraction par regex pattern matching.

---

## 4. WORKSPACE (Espace de Travail)

### 4.1 Création d'un workspace (WorkspaceRepository)

Le parcours onboarding complet crée un workspace avec batch Firestore :
1. Création du document `workspaces/{workspaceId}` avec toutes les métadonnées (entreprise, plan, trial, codes d'invitation)
2. Création du document `users/{adminUid}` pour l'admin
3. Création des documents `workspaces/{id}/invites/{inviteId}` pour chaque invité (batch commit)

### 4.2 Codes d'invitation
- Actuellement **hardcodés** dans `OnboardingData.generatedCodes` :
  - commercial → `COMMERCIAL`
  - metreur → `METREUR`
  - poseur → `POSEURS`
- **⚠️ Point de vigilance :** L'Agent 3 doit remplacer ces codes statiques par des UUID rotatifs avec expiration 30 jours.

### 4.3 Jointure par code
- `JoinWorkspaceScreen` : L'utilisateur saisit un code → Firestore lookup → assignation au workspace + création document user.

### 4.4 Provision de comptes (AdminTeamTab)
- L'admin ajoute un membre via une bottom sheet.
- Appelle la **Cloud Function** `provisionAccounts` (europe-west1) qui crée un compte Firebase Auth + génère un mot de passe temporaire.
- L'utilisateur reçoit le tempPassword, et doit le changer à la première connexion (`mustChangePassword = true` → `CompleteProfileScreen`).

---

## 5. FIRESTORE

### 5.1 Règles de sécurité (`firestore.rules`)

```
Fonctions utilitaires :
- isAuth() : request.auth != null
- uid() : request.auth.uid
- me() : get(/users/{uid})
- myWorkspaceId() : me().workspaceId ou me().companyId
- myRole() : me().role

Règles par collection :

/users/{userId}
  - get : soi-même ou membre du même workspace
  - list : tout auth (sécurité par query workspaceId)
  - create : son propre doc uniquement (uid() == userId)
  - update : soi-même ou admin du même workspace
  - delete : false (interdit)

/workspaces/{workspaceId}
  - get : admin direct ou membre du workspace
  - list : admin ou membre
  - create : adminUid == uid()
  - update : admin ou membre
  - delete : false

/workspaces/{id}/devis/{devisId}
  - read, write : admin du workspace ou membre du workspace

/workspaces/{id}/invites/{inviteId}
  - read : tout auth
  - create, update : admin ou membre du workspace
  - delete : false

/trial_sessions/{id}, /provisioned_accounts/{id}
  - read, write : tout auth
```

### 5.2 Indexes (firestore.indexes.json)
- Défini dans la config Firebase, utilisé notamment pour les requêtes avec `orderBy` + `where`.

### 5.3 Points de vigilance Firestore
- Les `StreamBuilder` sur `workspaces/{id}/devis` sans filtre `where` sur le statut génèrent des lectures complètes à chaque snapshot → **Pagination nécessaire** (Agent 3).
- Les codes d'invitation hardcodés permettent un accès non sécurisé → **UUID rotatifs** (Agent 3).
- Les règles `allow list: if isAuth()` sur `/users` sont permissives mais mitigées par l'imprédictibilité des workspaceId.
- Le cache SharedPreferences pour les données métreur (`_meteurPrefsKey`) sert de fallback offline mais désynchronise les données.

---

## 6. NOTIFICATIONS

### 6.1 Notifications push (FCM)
- **Initialisation :** `FirebaseMessaging.instance.requestPermission()` dans `main()`.
- **Token sync :** Sauvegardé dans `users/{uid}.fcmToken` lors de la connexion via `AuthNavigationService._saveFcmToken()`.
- **État :** Le token est stocké mais les fonctions Cloud Functions pour envoyer des push via FCM ne sont **pas encore implémentées** (prévu Agent 1).

### 6.2 Notifications internes Firestore (DevisService)
- Les notifications sont stockées dans `workspaces/{id}/notifications/{notifId}`.
- Chaque notification a un `targetRole` (commercial | metreur | poseur | admin).
- Les écrans écoutent en stream les notifications non lues pour leur rôle.
- **Avantage :** Fonctionne même sans FCM push, en temps réel via Firestore streams.
- **Inconvénient :** Ne génère pas de notification hors-application.

---

## 7. DESIGN SYSTEM

### 7.1 Couleurs (AppColors)
- **Primaire :** Bleu `#2563EB`
- **Rôles :** Commercial = bleu, Métreur = violet `#7C3AED`, Poseur = vert `#059669`
- **Statuts :** 8 palettes distinctes (attente/warning, progression/purple, commande/amber, planification/blue, pose/green, terminé/grey, clôture/red, problème/danger)
- **Neutres :** Échelle complète grey50 → grey900

### 7.2 Thème Material 3 (AppTheme)
- AppBar, Card, ElevatedButton, OutlinedButton, Input, TabBar, BottomNav, Chip, Text — tous customisés avec les couleurs du DS.

### 7.3 Widgets réutilisables (core/widgets/)
| Widget | Usage |
|--------|-------|
| `WiDevisCard` | Carte devis avec statut, montant, client, actions |
| `WiStatusBadge` | Badge coloré (7 statuts métier) |
| `WiStatRow` | Ligne horizontale de 2-3 indicateurs |
| `WiFilterPills` | Pills de filtrage scrollables |
| `WiCtaButton` | Bouton CTA pleine largeur |
| `WiBottomNav` | Barre de navigation générique |

---

## 8. ÉTAT DU PROJET — POINTS DE VIGILANCE

### ✅ Ce qui fonctionne
- Architecture complète onboarding → workspace → connexion → home par rôle
- Cycle de vie des statuts de devis (7 étapes) avec notifications Firestore
- Gestions des rôles avec routage automatique
- Création workspace en batch, provision de comptes via Cloud Function
- Thème Material 3 et Design System cohérents
- FaceID / empreinte au login
- Cache local SharedPreferences pour fallback offline métreur

### ⚠️ Points à traiter (par Agent)
| Agent | Priorité | Sujet |
|-------|----------|-------|
| **Agent 3** | 🔴 P1-Critical | Codes d'invitation UUID rotatifs (remplacer hardcodés `COMMERCIAL`/`METREUR`/`POSEURS`) |
| **Agent 3** | 🔴 P1-Critical | Pagination Firestore (20 items/page) pour les streams devis |
| **Agent 3** | 🔴 P1-Critical | Rate limiting Cloud Functions anti-abuse |
| **Agent 1** | 🔴 P1 | Migration Riverpod (StatefulWidget+setState → Riverpod) |
| **Agent 1** | 🔴 P1 | FCM push notifications (fonctions expéditrices) |
| **Agent 1** | 🔴 P1 | AdminHomeScreen KPIs avancés + charts |
| **Agent 2** | 🟠 P2 | Tests unitaires, widget, E2E (≥70% coverage) |
| **Agent 2** | 🟠 P2 | Mode offline end-to-end + conflict resolution |
| **Agent 2** | 🟠 P2 | Firebase Security Rules déploiement + validation |
| **Agent 2** | 🟠 P2 | Photos terrain poseur + validation chantier |
| **Agent 4** | 🔴 P1-Blocking | Stripe Cloud Functions (checkout + webhooks) |
| **Agent 4** | 🔴 P1-Blocking | UI checkout + portal abonnement |

---

## 9. DIAGRAMME DE DÉPENDANCES

```
Agent 3 (Sécurité — UUID, Pagination, Rate Limiting)
  │  P1-Critical — Bloque go-live
  ▼
Agent 1 (UI — Poseurs, Admin, FCM, Riverpod)
  │  P1 — Dépend des UUID pour plan selection
  ▼
Agent 2 (Quality — Tests, Rules, Offline, Photos)
  │  P2 — Dépend des screens finalisées par Agent 1
  ▼
Agent 4 (Stripe — Cloud Functions, Checkout, Abonnements)
  │  P1-Blocking — Dépend du compte Stripe (admin), tests Agent 2
  ▼
🚀 PRODUCTION READY — Semaine 5 (1er juillet 2026)
```

---

## 10. MÉTRIQUES CLÉS

| Métrique | Valeur |
|----------|--------|
| Écrans (screens) | ~25 fichiers Dart |
| Services | 4 (AuthNavigation, DevisService, TrialService, QuoteKeywordAnalyzer) |
| Collections Firestore | 6 (users, workspaces/devis, workspaces/notifications, workspaces/invites, trial_sessions, provisioned_accounts) |
| Statuts de devis | 10 (Nouvelle demande, Acceptée, En cours, À commander, Commande en cours, À planifier, En pose, À clôturer, Terminé, Clôturé + Problème chantier) |
| Palettes de couleurs | ~40 constantes |
| Mots-clés catalogue | ~150 patterns sémantiques |
| Widgets DS | 6 réutilisables |
| Dépendances techniques | Firebase Auth, Firestore, Storage, Functions, Messaging ; Flutter packages : local_auth, image_picker, file_picker, shared_preferences, url_launcher, http, path |
| Branches git | team-work/equipe-1-analyse (branche d'analyse) |
| Cloud Functions | `provisionAccounts` (europe-west1) + Stripe (à créer) |

---

**Rapport généré le :** 08 juillet 2026
**Auteur :** Analyse automatisée — branche `team-work/equipe-1-analyse`
**Prochaine étape recommandée :** Démarrer Agent 3 (UUID + Pagination) car c'est le blocage P1-Critical.
