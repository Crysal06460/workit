# STATUT D'AVANCEMENT — WorkIt (Équipe 3)

**Date**: 08 juillet 2026
**Branche**: `team-work/equipe-3-code`

---

## ✅ Ce qui fonctionne

### 🔐 Authentification & Onboarding
- **WelcomeScreen** → **TrialActivationScreen** → **JourneySelectionScreen** → **AccountSetupScreen** → **CreateWorkspaceScreen** → **SelectMetierScreen** → **PlanSelectionScreen** → **InviteTeamScreen** → **AdminSummaryScreen** : parcours complet unifié
- Firebase Auth (email/password) : inscription, connexion, password reset
- FaceID sur EntryScreen (fallback correct si user déjà connecté)

### 👤 Écrans métier
- **Commercial**: Home avec tabs filtre (À faire/Validé métreur/Validé commercial/En cours/Archivés), recherche, ajout devis, stats temps réel
- **Métreur**: 5 statuts tabs (Nouveaux/Acceptés/À commander/À planifier/À clôturer), détails devis fluides
- **Poseur**: 2 tabs (À faire / Historique), détails chantier avec photos + rapport fin
- **Admin**: Dashboard (stream devis + KPIs), Team (CRUD membres), Company (infos workspace)

### 🎨 Design System
- AppColors, AppTheme (light theme dominant), WiDevisCard, WiStatusBadge, WiStatRow, WiFilterPills, WiCtaButton, WiBottomNav

### 🔧 Services
- DevisService (création + 4 transitions statut + notifications), AuthNavigationService, TrialService, WorkspaceRepository
- **Nouveau**: StripeService (lib/services/stripe_service.dart)

---

## 🔧 Corrections récentes (commits 08 juillet)

| Commit | Changement |
|--------|-----------|
| `f042a5a` | Unified onboarding flow, secure invite codes, SelectMetierScreen 12 métiers, EntryScreen FaceID fix |
| `8e17cf1` | Redirection onboarding → WelcomeScreen, _StartupRouter fix |
| `ed1ad82` | Pagination Firestore (limit 50) sur tous les streams devis |
| *(ce commit)* | Ajout fonctions Stripe (7x callable), StripeService Dart, correction import FieldValue |

---

## 📊 Priorités d'avancement

### Priorité 1 : Cloud Functions ✅ (tout existant)
| Fonction | Statut | Fichier |
|---|---|---|
| `analyzeDevis` | ✅ Existe | functions/index.js (l.34-86) |
| `createInvitation` | ✅ Existe | functions/index.js (l.111-143) |
| `sendInvitationEmail` | ✅ Existe | functions/index.js (l.208-257) |
| `provisionAccounts` | ✅ Existe | functions/index.js (l.263-404) |
| `onDevisStatusChange` | ✅ Existe | functions/index.js (l.481-643) |
| `getInvitationByToken` | ✅ Existe | functions/index.js (l.648-664) |
| `consumeInvitation` | ✅ Existe | functions/index.js (l.670-742) |
| **Stripe (7 nouvelles)** | ✅ Créées | functions/index.js (l.743+) |

### Priorité 2 : Index Firestore Composites ✅
| Collection | Champs | Statut |
|---|---|---|
| devis | `poseurIds` (ARRAY_CONTAINS) + `poseDate` (ASC) | ✅ Existe dans firestore.indexes.json |

**Analyse** : Aucune autre requête `where` + `orderBy` combinée trouvée dans le code.
- Tous les streams devis utilisent `orderBy('createdAt')` seul (pas de where combiné)
- Queries users avec `where('companyId')+where('role')` sans orderBy — index implicite suffit

### Priorité 3 : Stripe ✅
| Action | Statut | Fichier |
|---|---|---|
| Service Dart `StripeService` | ✅ Créé | lib/services/stripe_service.dart |
| `stripeCreatePaymentIntent` | ✅ Créée | functions/index.js |
| `stripeCreateCheckoutSession` | ✅ Créée | functions/index.js |
| `stripeGetSubscription` | ✅ Créée | functions/index.js |
| `stripeCancelSubscription` | ✅ Créée | functions/index.js |
| `stripeGetOrCreateCustomer` | ✅ Créée | functions/index.js |
| `stripeWebhook` | ✅ Créée | functions/index.js |
| Dépendance `stripe` npm | ✅ Ajoutée | functions/package.json |
| Dépendance `flutter_stripe` | ✅ Ajoutée | pubspec.yaml |
| Import `FieldValue` | ✅ Corrigé | functions/index.js |

### Priorité 4 : Corrections de bugs 🔍
- [ ] Revue des écrans existants

### Priorité 5 : Améliorations UX/UI 🔍
- [ ] Navigation, transitions, états vides

---

## ❌ Problèmes restants

### P2 — Améliorations souhaitables
1. **Offline persistence** — `FirebaseFirestore.instance.settings.persistenceEnabled` non configuré dans main.dart
2. **Tests** — Aucun test unitaire/widget/E2E. Coverage 0%.
3. **OnboardingScreen.dart** (1865 lignes) — fichier vestige du flow direct-Firestore. Plus importé nulle part.
4. **Stripe** — Dépend d'un compte Stripe Business ; nécessite clés API dans Firebase Secrets
5. **Notifications push FCM** — FirebaseMessaging configuré mais pas intégré dans les écrans (callback `onMessage`)
6. **Pagination complète** — limit(50) ajoutée mais pas de pagination "load more" (cursor-based)

---

## 📊 Indicateurs clés

| Métrique | Valeur |
|---|---|
| Fichiers Dart | ~43 |
| Cloud Functions | 14 exports |
| Écrans | ~25 |
| Services | 5 |
| Flux onboarding unifié | ✅ |
| Codes invitation sécurisés | ✅ (Random.secure hex) |
| Offline persistence | ❌ |
| Tests | 0 |

---

## 🔜 Prochaines étapes

1. 🔔 Intégrer FCM notifications push dans les écrans (callbacks `onMessage`, `onResume`)
2. 🧹 Supprimer `onboarding_screen.dart` vestige
3. 🧪 Ajouter offline persistence dans main.dart
4. 📦 Déployer Cloud Functions (npm ci + firebase deploy --only functions)
5. 🧪 Tests unitaires sur DevisService et StripeService
