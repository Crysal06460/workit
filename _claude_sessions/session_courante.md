# Session courante — WorkIt

**Dernière mise à jour :** 2026-08-03 (soir, fin) — **Phase 0 terminée côté code**

## ✅ Session 2026-08-03 (soir, fin) — Phase 0 finalisée : lien d'activation, App Check, quota IA, logs d'audit

Christophe a demandé de terminer toute la Phase 0 pour ne pas y revenir. Les 4 points restants (voir
`roadmap_plateforme_multimetier.md`) sont maintenant faits et **déployés en production** (`workit-1daa1`,
commit `5bf4ae3`) :

1. **Mot de passe temporaire → lien d'activation** : `provisionAccounts` ne génère/stocke/renvoie plus aucun mot de
   passe — un vrai lien Firebase (`generatePasswordResetLink`) est généré et affiché à l'admin à la place. Testé en
   direct : le lien produit a bien la structure `workit-1daa1.firebaseapp.com/__/auth/action?mode=resetPassword...`
   et charge une vraie page Firebase fonctionnelle. `_showTempPassword` et l'affichage du mot de passe en liste
   d'attente ont été supprimés (plus rien à afficher).
2. **App Check** : package ajouté, activé en mode `.debug` (Android/iOS) + reCAPTCHA v3 (web) dans un try/catch —
   **rien n'est bloqué** pour l'instant (aucune Cloud Function n'impose `enforceAppCheck`). Confirmé que l'app
   démarre normalement avec cette activation.
   ⚠️ **Reste à faire par Christophe lui-même** (étapes externes, consoles web, hors de portée pour moi) avant de
   pouvoir activer le blocage réel :
   1. Firebase Console → App Check → enregistrer l'app Web avec une vraie clé reCAPTCHA v3 (Google Cloud Console →
      reCAPTCHA → créer une clé pour le domaine).
   2. Google Play Console → activer Play Integrity API pour l'app Android.
   3. Apple Developer Portal → activer DeviceCheck/App Attest pour l'app iOS.
   4. Une fois ces clés en main, remplacer les providers `.debug` dans `main.dart` et ajouter
      `enforceAppCheck: true` aux Cloud Functions — je peux faire cette dernière étape en 5 minutes le jour venu.
3. **Quota IA** : `analyzeDevis` limité à 100 analyses/mois/workspace (compteur dans
   `workspaces/{id}/usage/aiAnalysis`, plafond facilement ajustable plus tard).
4. **Logs d'audit** : nouvelle sous-collection immuable `workspaces/{id}/auditLogs`, alimentée à la création de
   compte (`provisionAccounts`), à la désactivation d'un membre et au changement de ses droits de délégation.
   Testé en direct : les 3 actions fonctionnent toujours normalement (pas d'erreur de permission introduite).

`flutter analyze` : 0 erreur, 135 issues. `npm run lint` (functions) : 0 erreur. **Committé et poussé.**

**→ Phase 0 de la roadmap terminée côté code.** Seules les 3 étapes de console listées ci-dessus (App Check)
restent à faire par Christophe quand il le souhaite — tout le reste (sécurité critique, isolation workspace,
mot de passe/lien d'activation, quota IA, logs d'audit) est en place et vérifié.

### Prochaine étape
Reprendre la roadmap à la **Phase 1 — Moteur de workflow générique + historique immuable** (voir
`roadmap_plateforme_multimetier.md`) lors d'une prochaine session.

---

## ✅ Session 2026-08-03 (soir, suite) — Phase 0 attaquée : faille critique de prise de contrôle de compte corrigée

Christophe a dit d'attaquer la Phase 0 de la roadmap (`roadmap_plateforme_multimetier.md`). Audit complet (règles
Firestore + 8 Cloud Functions + mécanisme du mot de passe temporaire) : a révélé une **vulnérabilité critique
active en production**, bien au-delà de ce qu'anticipait la roadmap — `createInvitation`/`consumeInvitation`
permettaient à tout utilisateur authentifié de réinitialiser le mot de passe de **n'importe quel autre compte**
(y compris un admin) et de lui attribuer le rôle/workspace de son choix, sans aucune vérification de rôle ni de
propriété du compte ciblé. L'écran client (`invite_activation_screen.dart`) avait déjà été supprimé ce matin comme
code mort, mais les fonctions serveur tournaient toujours. **Décision actée : suppression complète** de ces 4
fonctions plutôt que réécriture (aucun usage client actif).

Corrigé et **déployé en production** (`workit-1daa1`) :
- `functions/index.js` : suppression de `createInvitation`, `sendInvitationEmail`, `getInvitationByToken`,
  `consumeInvitation` (undeploy explicite via `firebase functions:delete`) + vérification `request.auth` ajoutée
  sur `analyzeDevis`.
- `firestore.rules` : `users/{userId}` — `create` restreint au seul cas légitime (auto-inscription admin lors de la
  création de son propre workspace) ; `update` (self) — impossible de changer soi-même `role`/`workspaceId`/
  `companyId`/`canManageTeam`/`manageableRoles`/`isAdmin`, ni de sortir de `status=='disabled'` (comparaison
  avant/après plutôt que blocage de champ, donc **aucun changement de code Flutter nécessaire** —
  `sign_in_screen.dart`/`admin_team_tab.dart` continuent de fonctionner à l'identique) ; `list` — restreint au même
  workspace (avant : n'importe qui pouvait lister tous les users de tous les workspaces). `provisioned_accounts` —
  lecture/mise à jour restreintes au même workspace (avant : mots de passe temporaires en clair lisibles par tout
  utilisateur, toutes entreprises confondues), création/suppression refusées aux clients.

**Testé manuellement dans Chrome** (workspace "Ambiance Alu") : connexion persistante OK, Planner (requêtes `list`
sur `users`) OK, création d'équipe OK, et surtout **onboarding complet neuf** (création workspace + compte admin) —
le test le plus critique de la nouvelle règle `create` — réussi de bout en bout. `flutter analyze` : 0 erreur, 136
issues (inchangé, aucun fichier Dart modifié). **Committé (`7d299ea`), pas encore poussé.**

⚠️ Compte de test créé pendant la vérification (`secutest.phase0.0803@workit-test.fr`) non nettoyé — même limite
que précédemment (pas de `serviceAccountKey.json` sur ce PC Windows).

### Reste à faire — Phase 0 (session suivante)
Reporté volontairement (chantiers à part entière) : remplacement du mot de passe temporaire par un lien
d'activation Firebase (le stockage en clair reste pour l'instant, mais n'est plus lisible cross-workspace), App
Check, logs d'audit. Voir `roadmap_plateforme_multimetier.md` pour le détail complet de la Phase 0 et des phases
suivantes (1 à 7).

---

## 📍 Session 2026-08-03 (soir) — Résumé PDF + roadmap plateforme multi-métier définie

### Résumé complet des fonctionnalités (PDF)
Christophe a demandé un PDF récapitulatif de toutes les fonctionnalités WorkIt à ce jour. Généré via un fichier
HTML stylé + conversion `msedge.exe --headless --print-to-pdf` (pas de dépendance ajoutée au projet — outil déjà
présent sur Windows). Livré à
`C:\Users\antoine.QUINTANE\Desktop\Local Quintane\WorkIt_Resume_Fonctionnalites.pdf` (9 pages, hors du dépôt git,
donc **pas synchronisé automatiquement entre Mac et Windows** — à régénérer si besoin sur l'autre poste, la méthode
est reproductible depuis n'importe quel Chrome/Edge installé).

### Roadmap "plateforme multi-métier professionnelle" — définie, pas encore commencée
Christophe a fourni un brief complet (rôle Lead Dev Flutter/Architecte Firebase/Product Engineer B2B) pour faire
évoluer WorkIt d'une app menuiserie-centrée vers une plateforme couvrant simultanément les 12 métiers déjà présents
dans le dictionnaire, avec un principe directeur clair : tout piloté par de la configuration versionnée (workflow,
formulaires, documents), pas par des conditions codées en dur dispersées.

**Roadmap détaillée sauvegardée dans `_claude_sessions/roadmap_plateforme_multimetier.md`** (committée,
`30c62e5`). Résumé des 8 phases, strictement séquentielles sauf 4/5 parallélisables :

0. **Sécurité et comptes** — audit règles Firestore/Cloud Functions (isolation stricte par workspace), suppression
   du mot de passe temporaire affiché en clair, App Check, logs d'audit. *À faire en premier, indépendant du reste.*
1. **Moteur de workflow générique + historique immuable** — remplace la logique de statut dispersée
   (`metreur_home_screen.dart`, `DevisService`) par un moteur configurable + sous-collection `statusHistory`
   immuable + transitions via Cloud Function serveur uniquement. *Socle dont tout le reste dépend.*
2. **Dictionnaire métier étendu + moteur de documents** — complète les 12 métiers (règles de validation,
   checklists, causes de non-conformité, indicateurs), versionne le dictionnaire, généralise le PDF unique actuel
   en plusieurs modèles versionnés (fiche métré, bon de préparation, rapport d'autocontrôle, PV de réception, SAV...).
3. **Chantiers multi-lots** — un chantier peut contenir plusieurs lots métier (responsable/équipe/dates/statut
   propres chacun) + dépendances entre lots (ex: carrelage après validation étanchéité).
4. **Planner v2** — écran de saisie des congés/indisponibilités (modèle de données déjà prêt depuis la session du
   03/08 après-midi), affichage des dépendances entre lots, conflits de ressources, historique des replanifications.
5. **Expérience terrain** — module de temps passé (départ/arrivée/pause/fin), causes de non-conformité structurées
   (remplace le champ "raison" libre actuel), circuit de validation poseur → responsable → clôture/SAV.
6. **Tableau de bord dirigeant** — KPIs (délais moyens entre transitions, surcharge, temps estimé vs réel, taux de
   SAV/paiement/non-conformité) via agrégats pré-calculés (Cloud Functions), pas des lectures Firestore coûteuses.
7. **Validation des 12 métiers & lancement** — matrice de maturité par métier, tests terrain avec 1 pro référent +
   3-5 dossiers réels par métier, gate de lancement (aucun contournement papier/Excel/WhatsApp).

### Prochaine étape
Christophe attaque la **Phase 0 (sécurité)** en premier lors d'une prochaine session — sur ce PC Windows ou sur le
Mac selon où il reprend. Lire `roadmap_plateforme_multimetier.md` en début de session pour le détail complet de
chaque phase avant de commencer.

---

## ✅ Session 2026-08-03 (après-midi) — Planner de planification (Admin + Métreur)

Christophe a demandé le chantier prioritaire : un vrai Planner web pro (colonnes équipes, lignes jour/semaine, drag-and-drop, capacité, surcharge), distinct de l'agenda mobile existant. Décisions actées : accès Admin + Métreur, "équipe" = nouveau concept nommé (pas juste un poseur), indisponibilités = modèle de données seulement pour l'instant (pas d'écran de saisie), capacité calculée automatiquement (poseurs actifs et disponibles ce jour-là).

Implémenté dans `lib/screens/planner_screen.dart` (nouveau, ~750 lignes) : backlog Prêt/Bloqué, grille équipes×jours avec drag-and-drop natif Flutter (`Draggable`/`DragTarget`, aucune dépendance ajoutée), mode Semaine en lecture seule, création/édition d'équipe, fiche d'édition des 4 nouveaux champs chantier (durée estimée, poseurs requis, livraison fournisseur, date souhaitée client), détection de surcharge automatique (bannière + case rouge + badge charge/capacité). Réutilise `DevisService.updateStatus` existant pour l'écriture (notifications incluses) et écrit `poseurIds` en parallèle de `teamId` pour ne rien casser côté `poseurs_home_screen.dart`.

Nouvelles sous-collections Firestore `planningTeams`/`unavailabilities` + règles associées **déployées en production** (`workit-1daa1`, confirmé explicitement par Christophe avant déploiement). Nouvel onglet "Planner" dans l'espace admin ; le bouton "Agenda" du métreur (mort jusqu'ici) ouvre maintenant le même Planner.

**Testé manuellement de bout en bout** dans Chrome avec le workspace de test "Ambiance Alu" (compte `metreur@workit-test.fr`) : création d'équipe réelle, backlog avec vrai chantier, drag-and-drop fonctionnel (écriture Firestore confirmée), édition des poseurs requis → surcharge détectée et affichée correctement, bascule Jour/Semaine. `flutter analyze` : 0 erreur, 136 issues (132 avant). **Committé, pas encore poussé.**

⚠️ Reste dans le workspace de test suite aux tests : équipe "Équipe 1" (Guillaume Hervé) et le chantier "Beylet Christophe" planifié le 05/08 avec `poseurCountRequired=2` — à ajuster/nettoyer via le Planner si besoin.

### Reste à faire (prochaine session)
- Écran de saisie des indisponibilités (le modèle de données est prêt, décidé de le reporter).
- Repasser sur le vrai modèle d'abonnement (site web + Stripe) une fois ces briques prêtes.
- Reprendre la vérification "carré, opérationnel" du process complet (coordonnées, corps de métier, ajout de membre, droits) — pas encore auditée en détail au-delà du parcours d'inscription.

---

## ✅ Session 2026-08-03 (matin, PC Windows) — Réconciliation Mac/Windows + nettoyage onboarding mort

### Réconciliation du travail Mac (02/08) et Windows (29-30/07, jamais poussé)
Les deux machines avaient divergé sans se synchroniser : Windows avait du code non commité (fix sécurité critique `provisionAccounts` — aucune vérification de rôle côté serveur, + délégation des droits d'équipe `canManageTeam`/`manageableRoles`), pendant que le Mac corrigeait 6 bugs bloquants sur le même workflow métreur→poseur et avait même **recodé indépendamment le même écran** "confirmer commande/programmer pose" que le Windows avait aussi construit. Résolution manuelle : fix sécurité + délégation d'équipe repris tels quels du Windows (aucun conflit), version Mac gardée pour metreur_home_screen.dart (testée bout en bout), ajouts Windows (attestation photo obligatoire, paiementEffectue, formulaire "chantier pas terminé" simplifié) réappliqués à la main par-dessus le fix Mac de poseurs_home_screen.dart. `flutter analyze` : 0 erreur après fusion. **Poussé sur origin/main.**
Leçon retenue : committer/pousser en fin de session des deux côtés pour éviter ces réconciliations tardives.

### Audit conformité App Store/Google Play (signup/login/abonnement)
Vérification demandée par Christophe (pas de mention d'abonnement sur les premiers écrans, sous peine de bannissement). Constat : le flux réellement affiché (`EntryScreen` → `OnboardingScreen`) ne mentionne déjà aucun prix nulle part — conforme. Mais un **second flux d'onboarding complet existait en code mort**, jamais routé depuis `main.dart` (`welcome_screen` → `trial_activation` → `journey_selection` → `account_setup` → `create_workspace` → `select_metier` → `plan_selection` → `final_save`), contenant les écrans à risque (choix de formule avant compte fonctionnel, `trial_expired_screen.dart` avec "Activez votre abonnement / Abonnement annuel/mensuel"). Vérifié que ce flux écrivait un schéma Firestore workspace incompatible avec celui du flux vivant et n'était dépendu par aucun écran live. **Supprimé** (15 fichiers : `welcome_screen.dart`, `trial_activation_screen.dart`, `trial_expired_screen.dart`, `journey_selection_screen.dart`, `account_setup_screen.dart`, `create_workspace_screen.dart`, `select_metier_screen.dart`, `plan_selection_screen.dart`, `final_save_screen.dart`, `admin_summary_screen.dart`, `invite_team_screen.dart`, `invite_activation_screen.dart`, `join_workspace_screen.dart`, `trial_service.dart`, `workspace_repository.dart`), en gardant dans `onboarding_models.dart` uniquement les helpers réellement utilisés par le code vivant (`onboardingRoles`, `roleDisplayName`, `roleDisplayNamePlural`). `flutter analyze` : 132 issues (208 avant), 0 erreur.

### Préparation du futur blocage abonnement (site web + Stripe pas encore prêts)
Ajouté `subscriptionStatus: 'pending'` à la création du workspace (`onboarding_screen.dart`) + point d'accroche `_isSubscriptionAllowed()` dans `auth_navigation_service.dart`, **toujours permissif pour l'instant** (personne n'est bloqué). Pas de compte Stripe créé, pas de site web construit — à brancher plus tard.

### Nouveau parcours d'inscription : abonnement sur le site avant configuration (implémenté et testé)
Christophe a demandé le vrai modèle métier : plus de choix de formule dans l'app, l'abonnement doit se faire sur le site web (fictif pour l'instant, pas de Stripe), l'app crée juste le compte puis débloque la suite après retour du site. Nouveau parcours dans `onboarding_screen.dart` (branche "créer une entreprise") :
`Entry → Subscribe (nouveau, message + lien externe workit.fr + "Continuer") → Account (email/mdp, compte Firebase créé seul) → Trades → Company → Role → Success (workspace + user doc finalisés ici)`.
`_createAccount()` scindée en `_createFirebaseAccountOnly()` (Auth seul, persiste prénom/nom/email dans `SharedPreferences` `workit_pending_*`) et `_finalizeWorkspace()` (crée workspace + user doc, relit le `SharedPreferences` pending si les contrôleurs sont vides). Ajouté `OnboardingScreen(resumeAtTrades: true)` + branché dans `AuthNavigationService.navigateUser` : si un compte Firebase existe mais qu'aucun workspace n'est finalisé (app fermée entre Account et la fin du parcours), reprise directe sur Trades au lieu du SnackBar bloquant "Compte introuvable" d'avant.
**Testé manuellement dans Chrome** (`flutter run -d web-server`) : parcours complet bout en bout + scénario de reprise (compte créé, page rafraîchie avant Trades → reprise correcte, prénom bien conservé, "Bonjour, Resume" au final). `flutter analyze` : 0 erreur, 132 issues (inchangé). **Committé, pas encore poussé.**
⚠️ 2 comptes de test créés pendant la vérification (`testeur.onboarding.0803@workit-test.fr`, `resume.test.0803@workit-test.fr`) non nettoyés — pas de `serviceAccountKey.json` sur ce PC Windows. À supprimer depuis le Mac si besoin.

### Reste à faire (prochaine session)
- Reprendre la vérification "carré, opérationnel" du process complet : coordonnées, choix du corps de métier, ajout de membre, droits — le flux vivant actuel n'a pas encore été audité en détail sur ces points précis au-delà du nouveau parcours d'inscription.
- Tester manuellement l'attestation photo + délégation d'équipe (Windows, jamais testées avant le merge).
- Nettoyer les 2 comptes de test ci-dessus depuis le Mac.
- Construire le vrai site web + Stripe, puis brancher `_isSubscriptionAllowed()` (actuellement toujours permissif) sur un vrai contrôle d'abonnement.

---

## ✅ Session 2026-08-02 — Tests bout en bout + 6 bugs critiques corrigés (workflow métreur→poseur débloqué)
Voir section détaillée tout en bas du fichier (« 📍 Session 2026-08-02 »). Résumé : le multi-métier/métré générique du 29/07 a été testé manuellement pour la première fois — 6 bugs trouvés et corrigés, dont **2 bloquants qui empêchaient tout chantier réel d'aller au-delà du métré** (workflow métreur cassé après la refonte de juillet, poseur ne voyait jamais aucun chantier). Le cycle complet devis→métreur→pose→poseur→clôture est maintenant validé de bout en bout manuellement. `flutter analyze` OK (0 erreur). **Commit fait, prêt à déployer si besoin.**

## ✅ Terminé (client uniquement, rien à déployer) : multi-métier — devis par élément + métré générique
Voir `_claude_sessions/plan_metier_generique.md`. Résumé : le dictionnaire (déjà riche de 12 métiers) est maintenant exploité en entier — un devis peut mélanger plusieurs corps de métier (un dropdown "Métier" par élément), l'onboarding propose les 12 métiers, et l'écran de métré du métreur s'adapte automatiquement à chaque élément (schéma visuel pour les ouvertures menuiserie, formulaire générique dynamique pour les 70 autres catégories — plomberie, électricité, peinture, carrelage, etc.). 451 champs de métré transcrits depuis des fiches professionnelles/DTU français. `flutter analyze` et `flutter build web` OK. **Reste à tester manuellement en conditions réelles.**

## ✅ Terminé et déployé : notifications complètes + agenda live + messagerie par chantier
Voir `_claude_sessions/plan_notifications_messagerie.md` pour le détail.
Résumé : les 8 étapes de code (persistance rôle, notifs manquantes, deep-link FCM, agenda temps réel, règles+écran+CF de messagerie interne par chantier) + le fix du bug `infoRequest`/`metreurNote` sont **codées, vérifiées et déployées en production** (`workit-1daa1`) — Cloud Functions et règles Firestore déployées avec succès le 2026-07-29. CLI Firebase installé sur ce PC (sans droits admin). Reste : tests manuels en conditions réelles + étape 0.5 optionnelle (push web).

## Ce qui a été fait cette session

### Système de mémoire créé
- `/Users/macbook/.claude/projects/-Users-macbook-workit/memory/` initialisé (MEMORY.md + fichiers mémoire)
- `_claude_sessions/session_courante.md` créé

### 4 phases implémentées (agents parallèles)

#### Phase 1 — Workflow métreur (`metreur_home_screen.dart`)
- `_loadRequests()` corrigé : toutes les listes alimentées depuis Firestore
  - `_newRequests` : status null / 'Nouvelle demande'
  - `_acceptedRequests` : 'Acceptée' / 'En cours'
  - `_toOrder` : 'À commander'
  - `_toPlan` : 'À planifier' / 'Commande en cours'
  - `_toClose` : 'À clôturer' / 'En pose'
- Bouton "Métré terminé — Commande à passer" → status 'À commander'
- Bottom sheet "Confirmer la commande" → status 'À planifier'
- Bottom sheet "Programmer la pose" : date/heure + sélection poseurs → status 'En pose', sauvegarde poseDate, poseurIds, poseurNames

#### Phase 2 — Écran Poseur (`poseurs_home_screen.dart`) — reconstruction complète
- 2 onglets : "À faire" (En pose) + "Historique" (Terminé/Clôturé)
- Fiche chantier : coordonnées client, accès devis PDF, détails métreur par produit
- Bottom sheet rapport fin de chantier : date, règlement, photos Firebase Storage → status 'Terminé'
- Bottom sheet rapport problème : soucis/manque/erreur → status 'À clôturer'

#### Phase 3 — Notifications FCM
- `pubspec.yaml` : `firebase_messaging: ^15.0.0`
- `main.dart` : `requestPermission()` au démarrage
- `auth_navigation_service.dart` : `_saveFcmToken()` — sauvegarde token dans `users/{uid}`
- `functions/index.js` : trigger `onDevisStatusChange` couvrant les 7 statuts

#### Phase 4 — PDF impression commande (`measurement_form_screen.dart`)
- `pubspec.yaml` : `pdf: ^3.11.1`, `printing: ^5.13.1`
- Bouton print AppBar → `_generateAndPrintPdf()`
- PDF professionnel : en-tête WorkIt, client, chantier, tableau éléments (dimensions prévues vs réelles, CJ, couleur, ref, note), pied de page signature

## État workflow complet

```
Commercial crée chantier → Métreur notifié (FCM) ✅
Métreur accepte + planifie RDV → Commercial notifié ✅
Métreur termine métré → "Métré terminé" → status 'À commander' + notif commercial ✅
Métreur passe commande → PDF impression + "Commande effectuée" → status 'À planifier' ✅
Métreur programme pose (date + équipe) → status 'En pose' + notif poseur + commercial ✅
Poseur voit son chantier + accès infos complètes ✅
Poseur termine → rapport OK/problème → status 'Terminé'/'À clôturer' + notif commercial ✅
```

## Statuts Firestore (référence)
- `'Nouvelle demande'` → commercial tab "En attente"
- `'Acceptée'` / `'En cours'` → commercial tab "En cours de métré"
- `'À commander'` / `'Commande en cours'` → commercial tab "En commande"
- `'À planifier'` / `'En pose'` → commercial tab "En pose"
- `'À clôturer'` / `'Terminé'` / `'Clôturé'` → commercial tab "Terminés"

## À faire (non implémenté)
- Déployer Cloud Functions (`firebase deploy --only functions`)
- Configurer FCM côté iOS (APNs certificates dans Firebase Console)
- Recherche commercial (TextField non câblé)
- Admin : notifications + vue détaillée chantiers
- Stripe / abonnements

## Notes techniques
- 0 erreur `flutter analyze` — 236 warnings/infos (dépréciations withOpacity, etc.) — préexistants
- Smart quotes corrigés dans auth_navigation_service.dart (bug introduit par agent FCM)
- Firestore writes toujours avec `SetOptions(merge: true)`
- Poseur charge devis via `poseurIds arrayContains uid` (nécessite index Firestore composite)

## ✅ Déploiements effectués (2026-06-11)

- **Cloud Functions** : `firebase deploy --only functions` → succès. `onDevisStatusChange` créé en europe-west1 (API v2 onDocumentWritten).
- **Index Firestore** : `firestore.indexes.json` créé + déployé. Index composite : `poseurIds` (ARRAY_CONTAINS) + `poseDate` (ASCENDING) sur collection `devis`.

## ⚠️ Reste à faire manuellement : APNs iOS

1. **Apple Developer Portal** → Keys → Créer clé APNs → télécharger `.p8` + noter Key ID
2. **Firebase Console** → projet workit-1daa1 → Paramètres → Cloud Messaging → Apple app → Upload APNs Authentication Key (`.p8` + Key ID + Team ID)
3. Rien à changer côté code Flutter — SDK gère APNs automatiquement

## ✅ Corrections 2026-06-11 (suite)
- **Admin routing** : ajout `case 'admin': return AdminHomeScreen()` dans `auth_navigation_service.dart` + import
- **Admin dashboard** : corrigé bug compteur "Chantiers en cours" (`poseurStatus` → `metreurStatus == 'En pose'`)
- **Recherche commercial** : `_SearchBar` câblée avec `onChanged` + `_matchesSearch()` filtre client/adresse dans les 2 StreamBuilders

## ✅ Audit + corrections 2026-06-11 (suite)
- **Bug tab métreur** : 'En pose' allait dans "À clôturer" au lieu de "Pose / Suivi". Corrigé dans `_loadRequests()`. Tab 3 renommé "Pose / Suivi". Tab 4 "À clôturer" = uniquement 'À clôturer' | 'Terminé'.
- **Navigation icon métreur** : bouton vide → ouvre Google Maps avec l'adresse du chantier.
- **"Envoyer au commercial"** : bottom sheet métreur câblé — écrit `infoRequest: {message, requestedAt, metreurId}` dans Firestore avec `SetOptions(merge: true)`.

## Transitions status vérifiées (audit complet)
| Action | Status écrit | Onglet commercial |
|--------|-------------|-------------------|
| Métreur accepte | 'Acceptée' | "En cours de métré" |
| Métreur termine métré | 'À commander' | "En commande" |
| Métreur confirme commande | 'À planifier' | "En pose" |
| Métreur programme pose | 'En pose' | "En pose" |
| Poseur rapport OK | 'Terminé' | "Terminés" |
| Poseur rapport problème | 'À clôturer' | "Terminés" |

## ✅ Vue détail commercial + FCM corrigés (2026-06-11)

### FCM
- 'Nouvelle demande' → notifie métreur ET admin ("Nouveau chantier à métrer")
- 'Acceptée' → inclut maintenant le nom du métreur ("va être métré par Prénom Nom")
- 'En pose' → poseur reçoit date+heure formatée, commercial/admin reçoit nom de l'équipe
- Redéployé avec succès

### Vue détail commercial (onTap sur toutes les cartes)
- `_QuoteItem` étendu : phone, email, clientFirstName, poseurNames, poseDate, rapportFin, rapportProbleme, infoRequest
- `_QuoteCard` : cliquable (Material + InkWell + onTap)
- Toutes les listes (NewQuotes, Measuring, Validated) câblées avec `_showChantierDetail()`
- `_ChantierDetailSheet` : bottom sheet draggable montrant :
  - Nom client, prénom, adresse, statut coloré
  - Téléphone cliquable (tel:) + email cliquable (mailto:)
  - Métreur assigné
  - Lien PDF devis (launch external)
  - Pose : date+heure + équipe
  - Message métreur (infoRequest)
  - Rapport problème : soucis / manque / erreur
  - Rapport fin : règlement ✓/✗ + photos scrollables cliquables (modal plein écran)

## ✅ Onboarding simplifié (2026-06-11)

### Nouveau flow : 3 étapes, plus d'écrans inutiles
**Avant :** Entry → Welcome → TrialActivation → JourneySelection → CreateWorkspace → SelectMetier → AccountSetup → PlanSelection → InviteTeam → AdminSummary (10 écrans)
**Après :** Entry → AccountSetup → CreateWorkspace → PlanSelection → FinalSave → AdminHomeScreen (5 étapes)

### Changements détaillés
- **AccountSetupScreen** : rewrite complet — plus de param `OnboardingData`, ajout prénom + nom + oeil MDP, barre progression step 1/3
- **CreateWorkspaceScreen** : nouveau constructor (firstName, lastName, email, uid), auto-set tradeKey='menuiserie_aluminium', skip SelectMetierScreen, step 2/3
- **PlanSelectionScreen** : navigation → FinalSaveScreen (pas InviteTeamScreen), step 3/3
- **FinalSaveScreen** (nouveau) : spinner auto-save → createWorkspace() + SharedPreferences → AdminHomeScreen, retry en cas d'erreur
- **EntryScreen** : "Découvrir WorkIt" → "Créer mon espace", navigue vers AccountSetupScreen
- **WorkspaceRepository** : batch inclut maintenant `users/{adminUid}` avec email/firstName/lastName/role='admin'/workspaceId
- **commercial_home_screen.dart** : ajout import url_launcher (launchUrl manquait)
- Orphelins compilables : journey_selection_screen, select_metier_screen mis à jour pour ne plus crasher

### Firebase sauvegardé lors de l'inscription
- `workspaces/{id}` : companyName, siret, address, postalCode, city, adminEmail, adminUid, creatorFirstName, creatorLastName, creatorRole='admin', tradeKey, plan, seatUsage, status='trial', trialStartAt/trialEndsAt
- `users/{adminUid}` : uid, email, firstName, lastName, role='admin', workspaceId, tradeKey

### SharedPreferences sauvegardés après inscription
- workit_workspace_id, workit_workspace_name, workit_user_first_name, workit_user_last_name, workit_is_admin=true, workit_trade_key

## ✅ Admin complet (2026-06-11)

### AdminDashboardTab (625 lignes)
- Greeting "Bonjour [prénom]" + titre "Tableau de bord"
- 4 stat cards avec compteurs corrects (field `status`, non `metreurStatus`) : En attente / Métré / Commande+Pose / Terminés
- Liste "Derniers chantiers" (20 max), tappable
- DraggableScrollableSheet 0.6→0.95 au tap : client, adresse, statut coloré, phone (tel:), email (mailto:), métreur, poseurs, date pose, infoRequest (amber), rapportProblème, rapportFin résumé
- Empty state avec icône inbox

### AdminTeamTab (750 lignes)
- Bottom sheet "Nouveau membre" (plus AlertDialog) : Prénom, Nom, Email + sélecteur de rôle en 3 cartes colorées (commercial=bleu, métreur=orange, poseur=violet)
- Appel `provisionAccounts` Cloud Function → retourne tempPassword
- Second bottom sheet "Compte créé ✓" : mdp en monospace sélectionnable, bouton Copier (email+mdp dans clipboard), instruction WhatsApp/SMS
- Liste membres : avatar coloré par rôle, chip rôle, icône mdp si status='provisioned', supprimer → status='disabled'

### AdminCompanyTab (253 lignes)
- Dark fields style uniforme (green focus, radius 14)
- SetOptions(merge: true) pour saves

### InviteActivationScreen (312 lignes)
- Routing corrigé : `AuthNavigationService().navigateUser(context, user)` (avant : pushReplacementNamed('/') cassé)
- Eye icon sur le champ mot de passe
- roleDisplayName() pour afficher le rôle lisiblement

## ✅ CommercialHomeScreen — bug status corrigé (2026-06-11)

### Bug critique résolu : `metreurStatus` → `status`
- **Problème** : toutes les tabs commerciales filtraient sur `data['metreurStatus']` au lieu de `data['status']`. Les chantiers acceptés/commandés/en pose n'apparaissaient jamais dans les bons onglets.
- **Fix** : 14 occurrences corrigées dans commercial_home_screen.dart
  - Tabs StreamBuilder x2 : `data['status'] ?? data['metreurStatus']` (rétro-compat docs existants)
  - `_saveQuoteToCloud()` : écrit `'status': 'Nouvelle demande'` (pas `metreurStatus`)
  - `_QuoteItem.toMap()` : clé `'status'` (pas `'metreurStatus'`)
  - `_QuoteItem.fromMap()` : lit `map['status'] ?? map['metreurStatus']`
- **Nettoyage** : supprimé `_TrailingPill`, `_MeasureItem`, `_WaitingForMeasureList` (classes inutilisées), constantes orphelines
- **Résultat** : 0 erreurs, 0 warnings sur le fichier et le projet complet

### Flux chantier maintenant cohérent bout en bout
| Acteur | Action | Status écrit | Onglet commercial |
|--------|--------|-------------|-------------------|
| Commercial | Crée devis | `'Nouvelle demande'` | "En attente" ✅ |
| Métreur | Accepte | `'Acceptée'` | "En cours de métré" ✅ |
| Métreur | Termine métré | `'À commander'` | "En commande" ✅ |
| Métreur | Commande confirmée | `'À planifier'` | "En pose" ✅ |
| Métreur | Programme pose | `'En pose'` | "En pose" ✅ |
| Poseur | Rapport OK | `'Terminé'` | "Terminés" ✅ |
| Poseur | Rapport problème | `'À clôturer'` | "Terminés" ✅ |

## Reste à faire
- Stripe / abonnements
- APNs iOS (manuel)

---

## 📍 Session 2026-07-29 — Reprise sur PC de travail (Windows, sans droits admin)

### Contexte
Antoine reprend le projet depuis un **PC professionnel Windows** (pas de droits admin), via **Claude Code** (assistant différent de la session Mac de juin). Objectif : avancer sur WorkIt pendant les creux de planning au travail. Travail limité au dossier `C:\Users\antoine.QUINTANE\Desktop\Local Quintane\Git\WorkIt`.

### Analyse du dépôt effectuée
- Branche `main` à jour, propre, 11 commits (historique juin 2025 → fév 2026)
- **3 branches distantes non fusionnées** : `team-work/equipe-1-analyse`, `team-work/equipe-2-design`, `team-work/equipe-3-code`
  - `equipe-3-code` contient du travail non présent sur `main` : intégration **Stripe** (7 Cloud Functions callable + `stripe_service.dart`), pagination Firestore (limite 50), persistance offline Firestore, corrections onboarding. **Jamais mergé.** → à trancher avec Antoine.

### Environnement de dev installé sur ce poste (aucun droit admin requis)
- **Flutter 3.44.8 (stable)** cloné via git (`git clone --depth 1 -b stable`) dans `C:\src\flutter`
- Ajouté au **PATH utilisateur** (persistant, pas besoin d'admin)
- `flutter config --enable-web` activé
- **Cible Windows Desktop désactivée** (`--no-enable-windows-desktop`) : nécessite le "Mode développeur" Windows (clé registre HKLM) → impossible sans droits admin sur ce PC. En la désactivant, `flutter pub get` ne tente plus de créer les symlinks de plugins et passe sans erreur.
- **Android SDK / Visual Studio (C++) non installés** — choix volontaire "léger" (pas de droits admin, pas besoin d'émulateur mobile pour l'instant)
- **Cibles fonctionnelles : Chrome et Edge (web)** — `flutter run -d chrome` testé avec succès, l'app se lance et tourne en hot-reload

### ⚠️ Limites connues sur ce poste
- Pas de test Android natif (émulateur) ni iOS
- Pas de test Face ID / notifications push mobiles réelles
- Pas de build Windows Desktop natif (bloqué par absence de droits admin)
- → Tout le développement logique métier / UI / Cloud Functions reste possible et testable via le web (Chrome)

### Prochaines étapes
En attente des étapes/tâches à donner par Antoine pour la suite du développement.

---

## 📍 Session 2026-08-02 — Tests manuels bout en bout + 6 bugs corrigés (Mac, Claude Code + extension Chrome)

### Contexte
Christophe a demandé de reprendre les tests de scénarios (création compte, ajout membre, devis, métré...) en pensant que c'était déjà fait avant l'expiration de son abonnement précédent. **Vérification faite : ça n'avait jamais été réellement exécuté** — seule l'infrastructure de test existait (`scripts/setup_test_accounts.js`, `scripts/test_flow.js`, `scripts/reset_devis.js`, créés le 17/06). Le `HANDOVER_COMPLET.md` du 30/06 notait déjà explicitement *"Flow poseur non encore testé bout en bout"*. Cette session a donc fait ces tests pour de vrai, pour la première fois.

### Méthode
1. `node scripts/setup_test_accounts.js` — recrée/rafraîchit les 3 comptes tests (commercial/métreur/poseur `@workit-test.fr`, mdp `Workit2026!`) dans le workspace **"Ambiance Alu"** (id `1Tz93YBgwnrd08ORABaZ`).
2. `node scripts/test_flow.js` — simulation Firestore directe du cycle complet (sans passer par l'UI) → a confirmé que les règles Firestore et la structure de données tiennent la route.
3. **App lancée en mode `flutter run -d web-server --web-port=8765 --web-hostname=localhost`** (PAS `-d chrome` — cette commande ouvre sa propre fenêtre Chrome isolée, invisible à l'extension Claude for Chrome utilisée pour piloter le navigateur ; le mode `web-server` sert juste l'app sur `http://localhost:8765`, à ouvrir ensuite depuis l'extension).
4. Tests manuels réels via l'extension Claude for Chrome : connexion successive aux 3 rôles, création d'un devis multi-métier, parcours métreur complet (accepter → RDV → métré → commander → planifier pose), parcours poseur (réception → clôture).

### 🐛 6 bugs trouvés et corrigés

| # | Bug | Fichier | Symptôme réel observé |
|---|-----|---------|------------------------|
| 1 | `data.draft!.toMap()` sans garde — crash total (écran rouge Flutter) | `metreur_home_screen.dart:1763` (`_openMeasurementForm`) | Clic sur "Démarrer le métré" sur un devis sans `draft` (ex: carte démo "Dupont Jean") → app plantée |
| 2 | Dropdowns "Type de chantier"/"Type d'habitation"/"Accessibilité" en `Colors.white70`/`Colors.white` sur fond clair — résidu de l'ancien thème sombre jamais migré | `lib/screens/widgets/dynamic_dropdown_field.dart` | Texte totalement invisible à l'étape "Chantier" du formulaire "Ajouter un devis" |
| 3 | `_ProductFormData.copyWith(categoryKey: null, ...)` n'appliquait jamais le `null` (pattern `param ?? this.param` classique) | `commercial_home_screen.dart` (`_ProductFormData.copyWith`, ~2643) | Changer le Métier d'un élément (ex: Menuiserie→Plomberie) affichait bien la bonne catégorie à l'écran, mais **la vraie donnée enregistrée en Firestore gardait l'ancienne catégorie** (`categoryKey: "menuiseries_exterieures"` pour un élément Plomberie) — silencieux, seulement visible en inspectant Firestore |
| 4 | **Aucun bouton dans l'UI pour confirmer une commande ou programmer une pose** — `_MeasureRequestSummary` n'avait que 2 états (`Acceptée` → métré ; tout le reste → "Accepter la demande", qui RÉÉCRIT `status: 'Acceptée'`, régressant le workflow) | `metreur_home_screen.dart` | Un devis "À commander" ou "À planifier" affichait toujours le bouton "Accepter la demande" au lieu d'un vrai CTA — impossible de faire avancer un chantier réel jusqu'à la pose via l'app. `_markPoseAProgrammer()` existait déjà mais n'était appelée nulle part (code mort) |
| 5 | `_ChantierData.fromMap` lisait `map['metreurStatus']` (champ qui n'existe plus depuis la correction de juin) au lieu de `map['status']` | `poseurs_home_screen.dart:1840` | **Le poseur ne voyait jamais aucun chantier assigné** ("Aucun chantier assigné"), même avec `poseurIds` correct — la query Firestore fonctionnait, mais le statut lu était toujours `null` donc filtré silencieusement |
| 6 | `_valider()` et `_signaler()` (rapport fin/problème poseur) écrivaient `'metreurStatus': ...` au lieu de `'status': ...` | `poseurs_home_screen.dart:1107,1400` | Même une fois le bug #5 corrigé, la clôture par le poseur serait restée invisible côté commercial/admin (qui lisent `status`) — le chantier serait resté bloqué "En pose" pour toujours |

**Bugs #4, #5, #6 = bloquants** : avant cette session, un vrai utilisateur pouvait créer un devis et faire le métré, mais **ne pouvait pas faire progresser un chantier jusqu'au poseur**, et même en forçant via Firestore, **le poseur ne voyait rien**. Le module poseur était cassé pour tout le monde depuis la correction `status`/`metreurStatus` de juin (jamais répercutée dans `poseurs_home_screen.dart`), et le workflow métreur post-métré a été perdu pendant la refonte visuelle de juillet (cf. l'avertissement que Christophe avait lui-même laissé dans le handover : *"certaines fonctionnalités ont été sacrifiées visuellement pendant la refonte et doivent être rebranchées"*).

### 🔧 Reconstruit (pas juste corrigé)
- `_confirmOrder()` et `_schedulePose()` dans `metreur_home_screen.dart` — deux nouvelles méthodes + les boutons correspondants dans `_MeasureRequestSummary`, avec un vrai `switch` sur `data.status` (Acceptée → métré / À commander → "Confirmer la commande" / À planifier → "Programmer la pose" / En pose → affichage lecture seule / défaut → "Accepter la demande").
- `_schedulePose()` : sélecteur date+heure (réutilise le pattern de `_scheduleMeeting`) + bottom sheet de sélection des poseurs (requête `users` filtrée `workspaceId` + `role == 'poseur'`) → écrit `status: 'En pose'`, `poseDate`, `poseurIds`, `poseurNames`.

### ✅ Validé manuellement de bout en bout (avec captures d'écran, pas juste du code lu)
- Connexion des 3 comptes test (commercial/métreur/poseur)
- Création devis multi-métier réel : élément 1 Plomberie/WC & Sanitaires (dropdown Métier change bien Catégorie/Sous-catégorie/Type avec les bonnes valeurs du dictionnaire)
- Métreur : accepter → prendre RDV (date/heure) → **métré générique dynamique spécifique WC** (type sortie évacuation, diamètre, position eau froide, etc. — confirme que le métré multi-métier du 29/07 fonctionne réellement) → confirmer commande → programmer pose (poseur sélectionné dans la vraie liste équipe)
- Poseur : réception dans "À faire" avec bonnes infos (client, adresse, catégorie, heure) → rapport de fin (règlement + date) → bascule en "Historique" avec statut "Terminé"
- Vérifié en base à chaque étape (`node -e "..."` avec `firebase-admin`) que `status` (jamais `metreurStatus`) est le champ écrit partout, cohérent de bout en bout

### ⚠️ Existant mais volontairement non touché (décision Christophe)
**Données de démo en dur mélangées en permanence aux vraies données** — `_kDemoDevis` (`commercial_home_screen.dart` ~3674) et `_kDemoNewRequests`/`_kDemoAccepted`/`_kDemoToOrder`/`_kDemoPlan`/`_kDemoToClose` (`metreur_home_screen.dart` ~2410-2429) sont fusionnées **inconditionnellement** avec le flux Firestore à chaque affichage (pas juste en fallback si vide). Concrètement : tout commercial et tout métreur, dans n'importe quel workspace réel, voit en permanence 6 faux clients ("Dupont Jean", "Rousseau Claire", "Martin Sophie", "Laurent Céline", "Bernard Marc", "Petit Thomas"/"Moreau Julie") mélangés aux vrais, et les compteurs de stats les comptent aussi. Les actions dessus (accepter, planifier) ne touchent que l'état local React — rien n'est persisté, d'où la confusion initiale de cette session (un "Accepter" semblait fonctionner puis "disparaissait" au reload). **À traiter dans une session future si Christophe veut du vrai contenu en prod.**

### 🧪 Environnement de test — à réutiliser telle quelle la prochaine fois
- **Comptes** : `commercial@workit-test.fr` / `metreur@workit-test.fr` / `poseur@workit-test.fr` — mdp `Workit2026!` (recréables via `node scripts/setup_test_accounts.js` depuis `/Users/macbook/workit/scripts`)
- **Workspace de test** : "Ambiance Alu" (id Firestore `1Tz93YBgwnrd08ORABaZ`)
- **Devis créés cette session** (Firestore, workspace ci-dessus) :
  - `9893` — "Claude Testeur", menuiserie, resté à `'Nouvelle demande'` (créé avant le fix du bug #3, catégorie potentiellement incohérente — à ignorer/nettoyer)
  - `4688` — "Claude TesteurV2", Plomberie/WC & Sanitaires — **cycle complet testé, `status: 'Terminé'`**, sert de preuve que tout fonctionne
  - `808uqCaU10U7MSQIiIRw` — "Marie Dupont", créé via `test_flow.js`, `status: 'Terminé'`
- **Lancer l'app pour tests browser-automation** : `cd /Users/macbook/workit && flutter run -d web-server --web-port=8765 --web-hostname=localhost`, puis naviguer vers `http://localhost:8765` depuis l'extension Claude for Chrome (PAS `-d chrome`, qui isole sa propre fenêtre non pilotable).
- **`scripts/serviceAccountKey.json`** présent et fonctionnel (gitignored, ne pas committer) — permet scripts Node.js d'admin direct sur Firestore/Auth.

### Reste non testé / non fait
- Notifications FCM (jamais vérifié qu'elles se déclenchent réellement pendant cette session — le code existe, déployé depuis le 29/07, mais pas observé en direct)
- Messagerie interne par chantier (code déployé le 29/07, jamais ouverte manuellement)
- Écrans Admin (dashboard, équipe, entreprise) — pas retestés cette session
- Rapport "problème" côté poseur (`_signaler()`, bug #6 corrigé dans le code mais le bouton "Problème rencontré" n'a pas été cliqué pour vérifier visuellement)
- Stripe / abonnements — toujours pas implémenté
- APNs iOS — toujours manuel (Christophe)
- Nettoyage des données démo en dur (voir ci-dessus)

### Prochaines étapes suggérées
1. Tester notifications FCM + messagerie en conditions réelles (2 comptes ouverts en parallèle)
2. Décider du sort des données démo (`_kDemoDevis` etc.)
3. Repasser sur Admin (jamais retesté depuis la refonte de juillet — probablement les mêmes types de régressions que métreur/poseur)
4. `git push` si Christophe veut sauvegarder sur le remote (dernier push état inconnu à vérifier avec `git status`/`git log origin/main..HEAD`)
