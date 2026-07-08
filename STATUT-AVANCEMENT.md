# STATUT D'AVANCEMENT — WorkIt (Équipe 3)

**Date**: 08 juillet 2026
**Branche**: `team-work/equipe-3-code`

---

## 📋 DIAGNOSTIC COMPLET

### ✅ Ce qui fonctionne déjà
- **Onboarding principal** (splash → slides → trades → company → role → account → success) : 100% UI, Firestore workspace + user creation
- **Auth Flow**: Firebase Auth (email/password), sign-in, password reset, FaceID
- **Admin écrans**: Dashboard tab stream devis, Team tab CRUD membres, Company tab edit infos
- **Commercial**: Home avec tabs filtre, recherche, ajout devis, stats en temps réel
- **Métreur**: Abonnement Firestore devis, 5 statuts tabs, modal détails
- **Poseur**: 2 tabs (À faire / Historique), détail chantier avec photos + rapport fin
- **Design System**: AppColors, AppTheme, WiDevisCard, WiStatusBadge, WiStatRow, WiFilterPills, WiCtaButton, WiBottomNav
- **Services**: DevisService (création + transitions + notifications), AuthNavigationService, TrialService, WorkspaceRepository

### ❌ Ce qui manque / est cassé

#### P1 — Bloquant livraison
1. **Deux flows onboarding parallèles et incompatibles**
   - `onboarding_screen.dart` crée workspace + user directement dans Firestore (pas de Cloud Functions)
   - `TrialActivationScreen → JourneySelectionScreen → AccountSetupScreen → CreateWorkspaceScreen → PlanSelectionScreen → InviteTeamScreen → AdminSummaryScreen` crée user via Firebase Auth puis workspace via WorkspaceRepository
   - **Nettoyage**: Un seul flow doit être utilisé, et le flux de trial + compte admin est le bon

2. **Invitation codes hardcodés**
   - `OnboardingData.generatedCodes` : 'COMMERCIAL', 'METREUR', 'POSEURS' — sécurité nulle

3. **Import manquant** dans `admin_team_tab.dart` : `roleDisplayName()` utilisé sans import de `onboarding_models.dart`

4. **Flux Trial → final cassé** : JourneySelectionScreen navigue vers AccountSetupScreen mais ne passe pas trialSessionId ni journeyType. Le journeyType n'est pas transmis le long de la chaîne.

#### P2 — Important
5. **SelectMetierScreen** n'a qu'UN seul métier (`menuiserie_aluminium`) — besoin de tous les métiers
6. **CreateWorkspaceScreen** hardcode `tradeKey = 'menuiserie_aluminium'` — devrait prendre depuis selectMetierScreen
7. **InviteTeamScreen** montre des codes hardcodés mais n'appelle pas provisionAccounts — seul AdminSummaryScreen le fait

#### P3 — Améliorations
8. **EntryScreen** : FaceID échoue → ouvre SignInScreen alors que l'user est déjà auth
9. **Pagination** : Les streams Firestore n'ont pas de pagination (limite à ~20 items via `.take(20)`)
10. **Pas de Riverpod** : Tous les screens utilisent StatefulWidget+setState, comme indiqué par les agents docs

---

## 🔧 IMPLÉMENTATIONS RÉALISÉES (08 juillet 2026)

### 1. 🔥 Correction flux onboarding dual → unifié ✅ *Commit f042a5a*
- Ajout du champ `journeyType` dans `OnboardingData` pour tracker le parcours (structured/artisan)
- Ajout de `trialSessionId` propagation dans la chaîne AccountSetupScreen → CreateWorkspaceScreen → PlanSelectionScreen → InviteTeamScreen
- Ajout de l'import manquant de `onboarding_models.dart` dans `admin_team_tab.dart`
- Ajout de `SelectMetierScreen` dans le flux (CreateWorkspaceScreen → SelectMetierScreen → PlanSelectionScreen)

### 2. 🔐 Secure invitation codes (UUID-like generation) ✅ *Commit f042a5a*
- Remplacé les codes hardcodés (COMMERCIAL/METREUR/POSEURS) par `_generateSecureCode()` qui produit des codes hexadécimaux aléatoires à 8 caractères via `Random.secure()`
- Mise à jour de `OnboardingData.generatedCodes` pour utiliser la génération sécurisée

### 3. 🧭 Unified navigation flow fix ✅ *Commit f042a5a*
- `JourneySelectionScreen` passe `journeyType` + `trialSessionId` à `AccountSetupScreen`
- `AccountSetupScreen` reçoit et transmet ces données à `CreateWorkspaceScreen`
- `CreateWorkspaceScreen` reçoit `trialSessionId` et `journeyType` et les intègre dans `OnboardingData`

### 4. 🏗️ Complete `SelectMetierScreen` avec tous les métiers ✅ *Commit f042a5a*
- Ajout de 12 corps de métier du second œuvre (était limité à 1)
- Navigation correcte vers `PlanSelectionScreen` au lieu de `AccountSetupScreen`

### 5. 🐛 Bug fixes ✅ *Commit f042a5a*
- Correction de l'import manquant `onboarding_models.dart` dans `admin_team_tab.dart`
- `roleDisplayName` et `roleDisplayNamePlural` maintenant disponibles dans `admin_team_tab`
- `EntryScreen` : FaceID échoue mais user auth → navigue quand même vers home (évite boucle)
- `CreateWorkspaceScreen` : ne hardcode plus `tradeKey`, passe par `SelectMetierScreen`

### 6. 📄 Statut document ✅ *Commit c85d4d8*
- Fichier `STATUT-AVANCEMENT.md` créé avec diagnostic complet et plan

---

## 📊 CE QU'IL RESTE À FAIRE

| Priorité | Tâche | Impact |
|----------|-------|--------|
| P1 | Déployer Cloud Functions (provisionAccounts, getInvitationByToken, consumeInvitation) | Les screens d'invitation ne fonctionneront pas sans |
| P1 | Créer les index Firestore composites nécessaires | Index errors sur les streams avec +1 filtre |
| P1 | Ajouter les `firestore.indexes.json` | Requis pour les queries combinées |
| P2 | Migration Riverpod (4 semaines selon planning) | Scalabilité état |
| P2 | Pagination Firestore (20 items/page) | Performance sur volume |
| P2 | Mode offline Firestore (Persistence) | Expérience hors-ligne |
| P2 | Tests unitaires/widget/E2E ≥70% | Qualité |
| P3 | `TrialExpiredScreen` → abonnement Stripe | Monétisation |
| P3 | Gestion abonnement (trial/actif/expiré) | État workspace |
| P3 | Notifications push FCM complètes | Engagement |
| P3 | Rate limiting Cloud Functions | Sécurité |

---

## 📝 DÉCISIONS PRISES

1. **Flow unifié onboarding** : On garde le workflow `AccountSetupScreen → CreateWorkspaceScreen → PlanSelectionScreen → InviteTeamScreen → AdminSummaryScreen` comme flow principal. Le vieux flow dans `onboarding_screen.dart` (création directe workspace dans Firestore) sera deprecié.

2. **Génération de codes d'invitation côté client** : En attendant Cloud Functions, on génère des codes hexadécimaux côté client.

3. **Le design clair (light theme)** prime sur le thème sombre. Les nouveaux écrans utilisent le thème clair `AppTheme.light`.

4. **Pas de Riverpod pour le MVP** : On garde StatefulWidget pour la version livrable, la migration se fera après.

---

## 🔜 PROCHAINS COMMITS

1. Fix navigation chain (journeyType propagation)
2. Secure invite codes
3. Complete SelectMetierScreen
4. AdminTeamTab import fix
5. EntryScreen FaceID fallback
