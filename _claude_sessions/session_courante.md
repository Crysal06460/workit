# Session courante — WorkIt

**Dernière mise à jour :** 2026-06-11

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
