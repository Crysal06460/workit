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

---

## 🔧 Corrections récentes (commits 08 juillet)

| Commit | Changement |
|--------|-----------|
| `f042a5a` | Unified onboarding flow (journeyType + trialSessionId propagation), secure invite codes (Random.secure hex), SelectMetierScreen with 12 métiers, EntryScreen FaceID fallback, admin_team_tab import fix |
| `8e17cf1` | Redirection du flow onboarding : EntryScreen "S'inscrire" → WelcomeScreen (exit OnboardingScreen obsolète), main.dart _StartupRouter → WelcomeScreen |
| `ed1ad82` | Pagination Firestore (limit 50) sur tous les streams devis : commercial, métreur, admin, poseur |

---

## ❌ Problèmes restants

### P1 — Non bloquant pour démo fonctionnelle
1. **OnboardingScreen.dart** (1865 lignes) — fichier vestige du flow parallèle direct-Firestore. Plus importé nulle part. À supprimer après vérification.
2. **Cloud Functions** — `provisionAccounts`, `getInvitationByToken`, `consumeInvitation` non déployées. Les codes d'invitation sont générés côté client.
3. **firestore.indexes.json** — existe mais peut nécessiter des index composites supplémentaires selon les requêtes.

### P2 — Améliorations souhaitables
4. **Riverpod** — Aucun screen migré. Tous en StatefulWidget+setState. Migration prévue Sem 3-4 du plan agent.
5. **Mode offline Firestore** — `FirebaseFirestore.instance.settings.persistenceEnabled` non configuré.
6. **Tests** — Aucun test unitaire/widget/E2E. Coverage 0%.

### P3 — Fonctionnalités manquantes
7. **Stripe** — Cloud Functions Stripe non implémentées (dépend d'un compte Stripe Business externe).
8. **Notifications push FCM** — FirebaseMessaging configuré dans main.dart mais pas intégré dans les écrans.
9. **Pagination complète** — Limit 50 ajoutée mais pas de pagination "load more" (nécessite un cursor).
10. **Rate limiting** — Pas de Cloud Functions anti-abuse.

---

## 📊 Indicateurs clés

| Métrique | Valeur |
|----------|--------|
| Fichiers Dart | ~42 |
| Lignes de code | ~18 000 |
| Écrans | ~25 |
| Services | 4 |
| Modèles | 1 (onboarding_models) |
| Tests | 0 |
| Riverpod migration | 0% |
| Pagination Firestore | ✅ limit(50) sur tous les streams |
| Flow onboarding unifié | ✅ |
| Codes invitation sécurisés | ✅ (Random.secure hex) |

---

## 📝 Décisions d'architecture

1. **Flow unifié**: `WelcomeScreen → TrialActivationScreen → JourneySelectionScreen → AccountSetupScreen → CreateWorkspaceScreen → SelectMetierScreen → PlanSelectionScreen → InviteTeamScreen → AdminSummaryScreen`. OnboardingScreen.dart déprécié.
2. **Design clair** (light theme) prime sur sombre. AppTheme.light est le thème par défaut.
3. **Pas de Riverpod pour MVP** — StatefulWidget+setState suffit pour la version livrable.
4. **Codes invitation côté client** en attendant Cloud Functions.
5. **Pagination limit(50)** sur tous les streams — suffisant pour le volume actuel.

---

## 🔜 Prochaines étapes (ordre de priorité)

1. 🧹 Supprimer le fichier `onboarding_screen.dart` vestige (après vérification des imports)
2. 🧪 Ajouter `FirebaseFirestore.instance.settings = Settings(persistenceEnabled: true)` pour offline
3. 📦 Déployer Cloud Functions d'invitation (provisionAccounts)
4. 📊 Ajouter les index composites manquants
5. 🔔 Intégrer FCM notifications push
6. 🧪 Tests unitaires (au moins sur DevisService et TrialService)

---

**Prochaine revue**: 09 juillet 2026
