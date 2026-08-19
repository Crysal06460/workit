# Session courante — WorkIt

**Dernière mise à jour :** 2026-08-19 — Session Windows (pas de simulateur, code + config uniquement, pas encore
testé en direct par Christophe). Simplification du formulaire "Nouveau devis" côté Commercial (trop détaillé,
jamais rempli en pratique) + montant HT + extraction IA des éléments du devis. **Code écrit et vérifié
(`flutter analyze` 0 erreur, `npm run lint` 0 erreur), secret `DEEPSEEK_API_KEY` posé sur Firebase, commité et
poussé sur `origin/main` (`0e80183`), Cloud Functions déployées en prod (confirmation explicite de Christophe
via AskUserQuestion) — `analyzeDevis` tourne donc déjà en version DeepSeek+OpenAI Vision. Reste non fait :
aucun test en simulateur/device réel (session Windows sans environnement mobile).**

## 🆕 Session 2026-08-19 — Wizard devis simplifié, montant HT, extraction IA (DeepSeek + OpenAI Vision)

### Demande de Christophe
Le formulaire d'ajout de devis côté Commercial (étape "Éléments du devis") demandait le détail complet de
chaque élément (métier/catégorie/sous-catégorie/type/variante/couleur/dimensions) — jugé beaucoup trop lourd
pour un usage terrain rapide ("sinon ils ne le feront jamais"). Demande : ne garder que l'essentiel, laisser le
détail au métreur qui a le vrai devis sous les yeux sur le terrain, et ajouter un montant HT total pour la
visibilité admin. Plan validé avec Christophe (mode plan) avant implémentation, deux clarifications tranchées
en amont :
- Le métreur choisit la catégorie/le type de chaque élément **sur place** (pas le commercial) — préserve les
  formulaires de métré spécialisés existants par catégorie (dictionnaire), au lieu de tout basculer en
  générique.
- L'extraction IA du devis (lire le PDF/les photos pour en déduire les éléments) est construite **maintenant**,
  pas reportée — avec **DeepSeek** comme IA demandée par Christophe (clé API fournie en direct dans la
  conversation, jamais inscrite dans ce journal ni dans le code — posée en secret Firebase
  `functions:secrets:set DEEPSEEK_API_KEY`, même mécanisme que `OPENAI_API_KEY` existant).

### Vérification technique avant de coder : DeepSeek n'a pas de vision
Recherche faite sur la doc officielle DeepSeek (`api-docs.deepseek.com`) : l'API ne propose aujourd'hui aucun
modèle capable de lire une image (seulement `deepseek-v4-flash`/`deepseek-v4-pro`, texte uniquement). Décision
prise avec Christophe (question posée avant d'écrire le code) : pipeline en deux étapes — **OpenAI Vision**
(`gpt-4o-mini`, déjà en place) lit le devis et en sort une description texte brute, puis **DeepSeek**
(`deepseek-v4-flash`) structure ce texte en JSON (`{elements: [{quantite, description}], montantHT}`). Repli
propre si DeepSeek échoue : une seule ligne avec le texte brut plutôt qu'un échec complet.

### Wizard Commercial simplifié (`commercial_quote_wizard.dart`)
- Étape "Éléments du devis" (détail par produit) **supprimée** — avec elle, tout le code mort associé
  (`_productForm`/`_productCard`/`_DropdownField`/`_categoryChoices`/`_tradeNode`/`_allMetiers`/etc., plus la
  classe `_Choice` devenue inutile dans `commercial_models.dart`).
- Ce qui reste inchangé : coordonnées client, écran "Infos générales chantier" (type de chantier/habitation/
  accessibilité), durée estimée + nombre de poseurs vendus, date souhaitée, commentaire, upload PDF/photos.
- **Catégorie automatique** : le chip `tradeLabel` (métier du workspace connecté) déjà affiché sert maintenant
  seul indicateur de catégorie — plus de sélection manuelle par élément.
- **Nouveau champ "Combien d'éléments à métrer ?"** (`_ElementCountField`, nouveau widget) : un `DropdownMenu`
  Material 3 propose 1 à 10 en suggestions rapides, mais le contrôleur texte sous-jacent reste librement
  modifiable (taper "13" directement fonctionne, écouté via un listener sur le texte en plus de `onSelected`).
- **Nouveau champ "Montant HT total du chantier"** (`montantHTController`) — nouveau champ `montantHT` sur
  `_QuoteDraft` (dupliqué dans `commercial_models.dart` et `metreur_home_screen.dart`, comme le reste de ce
  modèle), écrit aussi en champ top-level `montantHT` sur le document devis pour que l'admin puisse l'agréger
  facilement.
- Édition d'un devis existant (`existingItem`) : les éléments déjà présents dans le draft (avec mesures
  éventuelles du métreur) sont **conservés tels quels**, jamais régénérés — seul un nouveau devis (ou un ancien
  sans draft) génère ses placeholders depuis `_elementsCount`/l'extraction IA à la soumission
  (`_buildPlaceholderProducts`).
- Bug corrigé au passage : l'upload de fichiers n'envoyait réellement que le **premier** fichier sélectionné
  (les autres noms s'affichaient mais n'étaient jamais uploadés) — corrigé (`_uploadAllFiles`), nécessaire pour
  que l'IA puisse lire un devis multi-pages en entier. Nouveau champ `uploadedFileUrls`/`attachmentUrls`.

### Extraction IA branchée sur l'étape upload
Dès l'upload terminé, appel automatique (non bloquant) à la Cloud Function `analyzeDevis` avec toutes les
URLs. Résultat affiché en chips éditables (quantité + description, bouton supprimer) sur l'étape upload, qui
met à jour `_elementsCount` (somme des quantités) et pré-remplit `montantHT` si détecté — jamais bloquant :
échec ou quota IA dépassé (100/mois/workspace, mécanisme déjà en place) → simple message, saisie manuelle du
nombre reste possible. Chaque élément détecté garde sa description en `aiHint` (nouveau champ sur
`_ProductFormData`, dupliqué dans les deux fichiers de modèle) — affiché ensuite comme suggestion au métreur.

### Cloud Function `analyzeDevis` réécrite (`functions/index.js`)
Fonction déjà existante mais **jamais branchée côté client jusqu'ici** (posée en avance de phase le 03/08,
avec quota IA déjà en place) — réutilisée plutôt que dupliquée. Avant : résumé texte libre via OpenAI Vision,
un seul `fileUrl`. Maintenant : `fileUrls[]` (liste), pipeline OpenAI Vision → DeepSeek décrit ci-dessus, sortie
JSON structurée `{elements, montantHT}`.

### Métreur : choix de la catégorie sur place (`measurement_form_screen.dart`)
Nouvel écran-gate `_CategoryPickerStep` : pour tout élément créé sans `categoryKey` (nouveau flux ci-dessus),
affiché avant le formulaire de métré — catégorie puis type, choisis depuis `DictionaryService.categoriesFor`/
`typesFor` (déjà existant, réutilisé tel quel, pas de duplication de logique). Suggestion IA (`aiHint`) affichée
en aide si disponible, jamais pré-sélectionnée automatiquement (le métreur doit confirmer activement). Une fois
choisi, `DictionaryService.metreFieldsFor` recharge le bon formulaire spécialisé (champs par catégorie,
inchangé) pour cet élément. Sans choix (métreur qui passe outre), repli générique déjà existant, inchangé.

### Vérifications faites cette session
`flutter analyze` (scope `lib/`) : 0 erreur, 142 issues au total (uniquement infos/warnings déjà tolérés type
`withOpacity` déprécié — pas de nouvelle catégorie de warning introduite). `npm run lint` + `node -c index.js`
(functions) : 0 erreur. `firebase deploy --only functions --dry-run` : propre, secret `DEEPSEEK_API_KEY`
correctement reconnu et l'accès sera accordé au prochain déploiement réel.

### ✅ Commité, poussé, déployé
Confirmation explicite de Christophe (via AskUserQuestion : "Commit + push + déployer les functions") pour
passer directement en prod sans test préalable en simulateur — décision assumée de sa part, à garder en tête
si un souci apparaît au premier test réel. Commit `0e80183` sur `origin/main`. `firebase deploy --only
functions` : les 10 fonctions déployées avec succès, `analyzeDevis` a maintenant accès au secret
`DEEPSEEK_API_KEY` (rôle `secretAccessor` accordé automatiquement au déploiement).

### ⚠️ Pas fait cette session — à surveiller au premier test réel
- **Aucun test en simulateur/device réel** — session Windows sans environnement de test mobile, tout le travail
  ci-dessus n'a été vérifié que par `flutter analyze`/`npm run lint` (compile proprement) et relecture de code,
  jamais exécuté à l'écran. Le code tourne déjà en prod (voir ci-dessus) sans avoir été vu fonctionner une
  seule fois.
- **Carte "Montant HT en cours" côté Admin** (`admin_dashboard_tab.dart`) : somme tous les devis non terminés —
  périmètre par défaut (à confirmer avec Christophe si un autre filtre est préférable, ex. exclure aussi SAV).
- **Contenu du prompt IA** (lecture OpenAI Vision + structuration DeepSeek) jamais testé sur un vrai devis —
  qualité de l'extraction à valider en conditions réelles avant de compter dessus.

### Reste à faire (prochaine session)
1. **Priorité** : tester le nouveau flux en simulateur/device réel avec Christophe dès que possible (Commercial :
   ajout devis simplifié + upload + IA ; Métreur : choix catégorie sur place) — c'est du code jamais vu tourner,
   déjà en prod.
2. Ajuster le prompt IA / le périmètre de la carte Montant HT selon les retours de ce premier test.

---

**Dernière mise à jour :** 2026-08-18 — Session de deux jours (démarrée le 17, poursuivie le 18 après une
coupure de nuit), 3 simulateurs iOS en parallèle (Commercial iPhone 17 Pro Max, Métreur iPhone 17 Pro, Admin
iPhone 17 ajouté en cours de session), pilotée par Christophe qui testait en direct et remontait bugs/demandes
au fil de l'eau. Gros morceau : durée/poseurs vendus dans le devis + planification multi-jours en jours ouvrés
+ déplacement d'un jour isolé (nouveau champ `scheduledDates` par lot). Plusieurs bugs trouvés en test réel et
corrigés dans la foulée (voir détail ci-dessous). Base Firestore entièrement vidée en cours de session
(`node scripts/reset_devis.js`) pour repartir de zéro. **Tout commité et poussé sur `origin/main`** à la fin.

## 🆕 Session 2026-08-17/18 — Durée/poseurs vendus, planification multi-jours jours ouvrés, déplacement d'un
jour isolé, refontes agenda Commercial/Équipe Métreur/header Admin, renommages UI

### Repris du point d'arrêt du 14/08
Reprise du plan laissé par la session précédente : lancement des 2 simulateurs (Commercial + Métreur),
correction de 2 petits bugs remontés tout de suite :
- **Fiche client métreur** : la section "Rendez-vous" + bouton "Modifier rendez-vous client" restaient affichés
  même une fois le métré terminé (n'a plus de sens à ce stade) — masqués dès que le statut dépasse
  Acceptée/En cours (nouvelle variable `metreDone` dans `_MeasureRequestSummary`).
- **Bouton "Planifier pose"** sur la carte chantier de l'accueil métreur ouvrait la fiche détail au lieu
  d'ouvrir l'agenda pour le glisser-déposer — nouveau callback `onPlanifierPose` sur `_MetCard`/`_MetreurList`,
  routé vers `_openPlanner()` pour les statuts À planifier/En pose.

### Bug data découvert en creusant : chantier test orphelin
Le chantier ##5633 (BEYLET) était en statut `En pose` avec `poseDate`/`poseurIds` renseignés mais **sans
`teamId`** (ni au niveau devis ni du lot) — trace d'un ancien flux de planification (`_schedulePose`/
`_schedulePoseLot`, dead code depuis le 14/08) qui écrivait la date/l'équipe sans jamais écrire `teamId`.
Résultat : invisible à la fois dans le backlog (statuts autorisés : À commander/Commande en cours/À planifier)
et dans la grille équipes×jours (indexée par teamId). Diagnostiqué en interrogeant Firestore directement via
l'API REST (token OAuth du CLI `firebase-tools`, technique interne à `firebase-tools`, pas un secret utilisateur)
faute d'accès `idb`/tap sur simulateur. Corrigé en repassant ce chantier en `À planifier` par écriture directe
(poseDate/poseurIds/teamId effacés) pour qu'il retombe proprement dans le backlog.

### Bug timezone : heure de pose décalée de +2h
`DateTime` local construit depuis les pickers date/heure puis sérialisé en ISO string **sans** `.toUtc()` avant
envoi à `updateStatus`/Cloud Functions — le serveur (Node.js, fuseau UTC) parsait cette chaîne sans indicateur
de fuseau comme si elle était déjà UTC (`new Date(...)`), d'où un décalage systématique de +2h (été, Paris)
observé à la relecture. Corrigé en ajoutant `.toUtc()` avant `.toIso8601String()` sur les 4 points d'écriture :
`planner_screen.dart` (`_PoseAssignmentSheet._confirm`), `metreur_home_screen.dart` (`_scheduleMeeting` +
2 dialogues legacy inactifs mais corrigés par cohérence).

### Agenda Commercial simplifié (nouvel écran, plus de sélecteur d'équipe)
Nouveau fichier `lib/screens/commercial/commercial_agenda_screen.dart` (part de `commercial_home_screen.dart`) :
liste en lecture seule des chantiers du commercial connecté uniquement (`.where('userId', isEqualTo: uid)`),
triés par date de pose, une carte par lot planifié (`_CommercialAgendaEntry`), tap → détail complet (équipe,
dates). Remplace l'ancien `PlannerScreen` complet (grille + glisser-déposer + sélecteur d'équipe) sur l'onglet
Agenda du commercial — celui-ci n'a plus accès à la planification elle-même, réservée métreur/admin. Décision
validée avec Christophe via AskUserQuestion avant implémentation (recommandation retenue : lecture seule).

### Nouvel espace "Équipe" pour le métreur (poseurs/équipes/congés regroupés)
`MetreurTeamScreen` ajouté à la fin de `planner_screen.dart` (même librairie, réutilise directement
`_PlanningTeam`/`_PoseurOption`/`_Unavailability`/`_TeamEditSheet`/`_UnavailabilitiesSheet` déjà existants —
aucun nouveau modèle de données, juste une présentation regroupée). Trois sections : pool des poseurs avec
statut dispo/congé visible directement (avant caché dans le menu ⋮ de l'agenda), liste des équipes (composition
déjà "verrouillée" — une équipe = toujours les mêmes poseurs) avec édition, et congés/absences avec accès rapide
à la gestion. Nouvelle entrée dans `settings_screen.dart` ("Équipes de pose & congés"), visible pour les rôles
métreur/admin uniquement (nouveau champ `_role` chargé dans `_SettingsScreenState`).

### 🎯 Gros morceau : durée/poseurs vendus + planification multi-jours + jours ouvrés + déplacement d'un jour
Demande initiale de Christophe, scope confirmé par AskUserQuestion (tout construire d'un coup plutôt que par
étapes) :

1. **Champs devis (Commercial)** : "Durée estimée (jours)" + "Nombre de poseurs" ajoutés à l'étape "Infos
   générales chantier" du wizard (`commercial_quote_wizard.dart`). Stockés `soldEstimatedDurationDays`/
   `soldPoseurCountRequired` sur `_QuoteDraft` (dupliqué dans `commercial_models.dart` ET
   `metreur_home_screen.dart` — deux classes du même nom dans deux librairies séparées, comme le reste du
   modèle `_QuoteDraft`).
2. **Confirmation obligatoire à la validation du métré** : nouvelle feuille bloquante `_ScheduleEstimateSheet`
   (`metreur_home_screen.dart`, `isDismissible: false`) — un pair durée/poseurs par métier distinct du devis,
   pré-rempli avec l'estimation du commercial, affichée juste avant que "Terminer et Valider" ne déclenche la
   transition vers "À commander". Annuler laisse le métré non validé (retentable). **Bug trouvé par relecture
   de code (pas par Christophe) et corrigé avant tout test** : si annulation, les mesures saisies dans le
   formulaire étaient perdues (jamais sauvegardées) — corrigé en écrivant le `draft` directement dans Firestore
   *avant* d'afficher cette confirmation (règles Firestore : tout champ sauf `status`/`metreurStatus` est
   modifiable en écriture directe cliente).
3. **Valeurs par défaut du lot créé côté serveur** (`functions/index.js`, bloc de naissance des lots à "À
   commander") : lit désormais `extraFields.lotEstimates[metierKey]` (valeurs confirmées par le métreur) avec
   repli sur `draft.soldEstimatedDurationDays`/`soldPoseurCountRequired` (valeurs du commercial), au lieu de
   `null`/`1` codés en dur.
4. **Jours ouvrés** : nouveau helper `_businessDays(start, count)` dans `planner_screen.dart` (skip
   samedi/dimanche). Utilisé (a) en repli dans `_PlanUnit.occupiedDays` pour les chantiers planifiés avant ce
   changement, et (b) dans `_PoseAssignmentSheet._confirm()` pour calculer les jours réels à la première
   planification.
5. **Modèle `scheduledDates`** (remplace la dérivation pure `poseDate` + `estimatedDurationDays`) : nouveau
   champ `scheduledDates: Timestamp[]` par lot (et devis-level pour les chantiers sans lot), écrit à la
   première planification, source de vérité de `occupiedDays` dès qu'il est renseigné (repli sur l'ancienne
   dérivation sinon, pour compat avec les chantiers déjà planifiés). `poseDate` continue d'être écrit en
   parallèle (= `scheduledDates.first`) pour tous les écrans qui ne lisent que lui.
6. **Déplacer un seul jour** : nouvelle interaction en tapant une vignette d'un chantier multi-jours dans la
   grille — `_DayActionSheet` (choix "Déplacer ce jour" / "Voir les détails") puis `_MoveDaySheet` (date picker,
   réécrit `scheduledDates` avec seulement ce jour changé, les autres restent identiques, toujours la même
   équipe). Passe par `DevisService.updateLotPlanningFields` (étendu pour accepter `scheduledDates`) plutôt que
   par le moteur de transitions, puisque ni le statut ni l'équipe ne changent.
7. **Serveur** : `functions/devisWorkflow.js` — `scheduledDates` ajouté aux `extraFields`/`dateFields` des
   transitions À planifier→En pose et En pose→En pose ; `functions/index.js` — la boucle de conversion
   ISO→Timestamp gère maintenant les tableaux (`Array.isArray`), `patchLotSummary`/l'agrégation devis-level
   propagent `scheduledDates`, et `updateLotPlanningFields` accepte un nouveau champ `scheduledDates` (trié,
   `poseDate` recalculé comme premier élément).

**✅ Déployé sur Firebase** deux fois : un premier déploiement pour tout ce qui précède, puis un second après
qu'un test réel de Christophe a fait remonter une erreur `[firebase_functions/invalid-argument] Champ(s) non
autorisé(s) pour cette transition : lotEstimates` — `lotEstimates` avait été géré côté création de lot mais
oublié dans la liste blanche `extraFields` des transitions "Acceptée"/"En cours" → "À commander" dans
`devisWorkflow.js`. Corrigé et redéployé.

### Bug trouvé en test réel (screenshots Christophe) : dates manquantes côté Commercial
Un chantier planifié sur 2 jours non consécutifs (18 et 20 août, le 19 sauté via "Déplacer ce jour") n'affichait
que le 18 août côté Commercial (fiche détail ET liste agenda) — ces deux écrans ne lisaient que `item.poseDate`
(un seul champ, agrégat devis-level "date la plus proche"), jamais `lotsSummary[].scheduledDates`. Corrigé :
- `_QuoteItem` (commercial_models.dart) gagne un champ `scheduledDates`.
- `commercial_chantier_detail.dart` : nouvelle méthode `_buildPoseSections` — une section "Pose programmée" par
  lot planifié, listant TOUTES ses dates ("Jour 1/2 — ...", "Jour 2/2 — ...").
- `commercial_agenda_screen.dart` : `_CommercialAgendaEntry` gagne un champ `dates` (liste complète), affiché en
  compact sur la carte ("18/08, 20/08 (2j)").

### Bug trouvé en test réel : libellé "Planifier pose" trompeur une fois déjà planifié
`_ctaLabel` retournait "Planifier pose" pour les statuts À planifier ET En pose — une fois déjà planifié
(équipe/dates posées), le bouton disait encore "à planifier". Distingué : "Planifier pose" pour À planifier,
"Voir le planning" pour En pose (l'action reste la même : ouvrir l'agenda).

### Renommages UI (sans toucher aux statuts serveur)
- **"Planner" → "Planning"** partout (métreur, planner_screen.dart, admin_home_screen.dart — onglet).
- **"Backlog vide — aucun chantier..."** retiré : la bande backlog mobile se masque simplement si vide au lieu
  d'afficher un message.
- **"En pose" → "Programmé"** (libellé affiché uniquement, statut Firestore `'En pose'` inchangé) : jugé
  trompeur par Christophe car atteint dès qu'une équipe/date sont posées dans l'agenda, pas forcément au
  moment réel de la pose. Corrigé sur les 4 rôles partout où le statut brut était affiché comme texte : badge
  partagé `wi_status_badge.dart` (`_styleFor`), badge métreur `_MetStatusBadge`, pastilles de stats/onglets/
  Kanban (métreur, commercial, admin), pilule de statut `commercial_chantier_detail.dart`, libellés poseur
  (`_summaryStatusLabel`/`_statusLabel`), et toutes les fonctions `_toSummary` qui construisaient `statusLabel`
  depuis le statut brut (métreur/commercial/admin — poseur passe déjà par une fonction déjà corrigée). Le
  statut Firestore `'En pose'` et toute la logique de transition restent inchangés — seul le texte affiché
  change.
- **"Metteur en œuvre" → "Métreur"** dans l'en-tête de l'accueil métreur (choix validé avec Christophe entre
  "Métreur" et "Coordinateur de chantier" via AskUserQuestion).

### Admin : filtre par rôle dans "Équipe"
`admin_team_tab.dart` : rangée de filtres ("Tous"/rôles) sous l'en-tête "Mon équipe", réutilise le widget
`_RoleChip` déjà existant (créé pour les permissions de délégation) plutôt que d'en recréer un. Filtre appliqué
en plus du filtre `restrictToRoles` existant (délégué à vue partielle).

### Admin : header identique Commercial/Métreur
`admin_home_screen.dart` avait juste un titre statique "Admin" + bouton déconnexion, sans avatar ni nom — refait
à l'identique du pattern Commercial/Métreur : "Bonjour {prénom} 👋" + sous-titre "Administrateur" + avatar rond
avec initiales (couleur `AppColors.primary`) + bouton déconnexion. Prénom/nom lus depuis SharedPreferences
(mêmes clés `workit_user_first_name`/`workit_user_last_name` que les autres rôles).

### 3ème simulateur (Admin) mis en place
iPhone 17 (déjà démarré, réutilisé) — nécessitait une réinitialisation (`xcrun simctl uninstall`) car une
session métreur y était restée connectée depuis un test précédent. Compte admin de "Ambiance Alu" retrouvé
(c'est le compte personnel de Christophe, pas un compte de test dédié — aucun admin de test n'existe pour ce
workspace) et son mot de passe réinitialisé via le SDK Admin Firebase (script temporaire, supprimé après usage)
car Christophe ne le connaissait plus — nouveau mot de passe communiqué directement à Christophe, **jamais
inscrit dans ce journal** (règle absolue du fichier).

### Base de données remise à zéro en cours de session
`node scripts/reset_devis.js` relancé à la demande de Christophe ("je recommence les tests à zéro") — les 2
chantiers de test (##5633 BEYLET, ##1382) supprimés avec sous-collections + 14 notifications/stats associées.

### Coupure de session (nuit du 17 au 18)
Les processus `flutter run` sont morts pendant la nuit (simulateurs restés démarrés mais plus de session Dart
active) — reconnexion nécessaire au réveil du 18, tous les correctifs déjà appliqués côté code étaient
préservés (rien perdu), simple recompilation/relance des 3 apps.

### Vérifications faites cette session
`flutter analyze` (scope `lib/` complet, en excluant les artefacts préexistants de `build/ios/...`) : 0 erreur
après chaque lot de modifications. `node -c` + `npm run lint` (functions) : 0 erreur avant chaque déploiement.

### ⚠️ Points restés ouverts / non re-testés après le tout dernier correctif
- Le renommage "En pose" → "Programmé" vient d'être déployé sur les 3 simulateurs (Métreur/Commercial/Admin) —
  pas encore explicitement reconfirmé par Christophe au-delà de son premier retour positif ("bcp mieux
  programmé !").
- Poseur n'a pas de simulateur lancé cette session (renommage appliqué au code par cohérence, jamais vérifié à
  l'écran).
- `_ChantierDetailSheet` (planner_screen.dart) : éditer `estimatedDurationDays` sur un chantier **déjà planifié**
  (qui a un `scheduledDates` non vide) n'a plus d'effet visible sur la grille depuis l'introduction de
  `scheduledDates` comme source de vérité — limitation connue, pas corrigée (l'édition de durée n'a de sens
  qu'avant la première planification ; après, il faut passer par le glisser-déposer ou "Déplacer ce jour").
- Warning Flutter non bloquant repéré dans les logs Commercial ("ListTile background color or ink splashes may
  be invisible") — origine non identifiée avec certitude (pourrait être un artefact de log d'un ancien process),
  jamais reproduit ni creusé plus loin.

### Reste à faire (prochaine session)
1. Confirmer avec Christophe que "Programmé" convient partout (3 rôles déjà testés, Poseur pas encore vu).
2. Tester le flux complet de bout en bout sur un nouveau devis créé depuis la base vidée : durée/poseurs vendus
   → confirmation obligatoire au métré → lot créé avec les bonnes valeurs → glisser-déposer multi-jours jours
   ouvrés → déplacer un jour isolé → vérifier l'affichage Commercial (toutes les dates).
3. Investiguer si besoin le warning ListTile côté Commercial s'il se reproduit.
4. Décider si l'édition de durée post-planification (`_ChantierDetailSheet`) doit régénérer `scheduledDates`
   ou rester limitée à avant planification (comportement actuel).
5. Messagerie interne scoping fin (reportée depuis le 14/08, toujours pas commencée).

---

## 🆕 Session 2026-08-14 — 14 demandes UI/UX/métier + 3 bugs trouvés en test réel

### Les 14 demandes initiales (métreur/commercial)
1. **Agenda ouvrait sur Équipe 2** au lieu d'Équipe 1 — bug de tri : la requête `planningTeams` n'avait pas
   d'`orderBy`, l'ordre Firestore par défaut (par ID doc) faisait remonter Équipe 2 en premier alors qu'elle
   a été créée après. Fix : `.orderBy('createdAt')`.
2. **Renommage des équipes de pose** — la fonctionnalité existait déjà (nom + membres) mais seulement
   accessible en layout desktop (tap sur l'en-tête de colonne). Exposée sur mobile via une icône crayon à côté
   du sélecteur d'équipe (`planner_screen.dart`).
3. **Header métreur aligné sur commercial** — "Bonjour {prénom} 👋" au lieu du titre statique "Gestion
   chantiers", et un vrai bouton déconnexion visible (avant : il fallait taper sur l'avatar sans aucune icône
   ni indice visuel).
4. **Pastilles métreur redessinées** au style commercial (`WiStat`/`WiStatRow`) : carte blanche, ombre légère,
   chiffre centré coloré 22px, libellé gris — grille 2×3 conservée (au lieu du scroll horizontal de
   `WiStatRow` au-delà de 3 stats) pour garder les 6 vignettes visibles sans scroll.
5. Onglet bas commercial **"Devis" → "Accueil"** (icône `home_outlined`/`home_rounded`, alignée sur le libellé
   déjà utilisé côté métreur).
6. **Swipe droite pour revenir à l'Accueil** depuis Agenda/Réglages, sur commercial/métreur/poseur (nouveau
   widget partagé `lib/core/widgets/wi_swipe_back.dart`, zone de déclenchement limitée au bord gauche de
   l'écran pour ne pas entrer en conflit avec le glisser-déposer de l'agenda). Non appliqué à l'onglet
   "Planner" de l'admin — c'est un onglet dans un `TabBar`, pas un écran empilé, pas d'"Accueil" à retrouver.
7. **"Voir le devis" → "Voir détails"** côté métreur (`_MetCard`), pour matcher le libellé déjà utilisé côté
   commercial.
8. **Bouton "Modifier" retiré** des cartes "Élément à métrer" côté métreur (hint texte+icône en bas de carte,
   jugé superflu).
9. **Alertes J-1/H-2 avant un métré** — nouvelle Cloud Function planifiée `checkUpcomingMetres`
   (`functions/index.js`, `onSchedule("every 30 minutes")`), **déployée en prod** sur `workit-1daa1`. Scanne
   les devis en statut "En cours" avec `meetingAt` + `metreurId`, notifie uniquement le métreur assigné (push
   FCM via `getTokenByUid`) à J-1 puis H-2, avec des flags `metreAlertJ1Sent`/`metreAlertH2Sent` sur le
   document pour éviter les doublons.
10. **Bug "Accepter la demande" qui restait affiché** après acceptation — cause racine trouvée : la
    catégorisation de la liste d'accueil (`_onDevisSnapshot`) ne reconnaissait que le statut `'En cours'` pour
    la case "acceptées", alors que le bouton "Accepter" écrit `'Acceptée'` — l'écart entre ces deux valeurs
    faisait retomber le devis fraîchement accepté dans le tas "Nouvelle demande". Fix des deux côtés
    (catégorisation + switch du bouton dans `_MeasureRequestSummary`) pour traiter `'Acceptée'` et `'En cours'`
    ensemble, cohérent avec le reste du fichier (`_step`/`_ctaLabel`/`_accentColor` le faisaient déjà).
11. **Bouton "Confirmer la commande" mal centré sur 2 lignes** — `textAlign: TextAlign.center` ajouté sur les
    deux occurrences (fiche détail + ligne d'action par lot).
12. Une fois le métré fait : titre **"Éléments à commander"** (au lieu de "Élément à métrer"), nouveau bouton
    **"Voir le métré"** ouvrant un écran de lecture dédié (`_MetreDetailScreen`, nouvelle classe) listant
    toutes les mesures réelles, avec bouton **"Imprimer le métré"** en bas réutilisant le moteur de documents
    existant (`DocumentEngine.generateAndShare(templateId: 'bon_commande')`, déjà utilisé ailleurs — aucune
    nouvelle logique PDF à écrire).
13. **Pastille "messages non lus" visible depuis l'Accueil** — nouveau widget partagé
    `WiUnreadMessageBadge` (`chantier_chat_screen.dart`), branché sur les cartes commercial (`WiDevisCard`) et
    métreur (`_MetCard`). Couvre commercial + métreur seulement (poseur/admin pas encore câblés, faute de
    temps).
14. **Refonte planification de pose** (le plus gros morceau) : chaque glisser-déposer dans l'agenda (nouveau
    depuis le backlog, ou déplacement d'une pose déjà planifiée) ouvre désormais un popup
    (`_PoseAssignmentSheet`, nouvelle classe) pour confirmer date + heure + équipe avant d'écrire dans
    Firestore — avant, le drop écrivait directement sans étape de confirmation ni choix d'heure. Taper sur une
    pose déjà planifiée dans la grille affiche "Prévu le X à Xh par équipe X" + bouton "Modifier" (réouvre le
    même popup, calendrier standard via `showDatePicker`/`showTimePicker`). Le bouton "Programmer la pose"
    côté métreur redirige maintenant vers l'agenda (le chantier apparaît déjà dans le backlog "À planifier")
    au lieu de l'ancien sélecteur autonome date/heure/poseurs (`_schedulePose`, laissé en place mais plus
    appelé — dead code assumé, même précédent que d'autres méthodes déjà non utilisées dans ce fichier).

### 3 bugs trouvés en testant les corrections ci-dessus
- **Section "Lots" cassée** dans la fiche détail métreur : pour un devis mono-lot passé en "En pose", la
  carte de lot (`_lotActionRow`) ne rendait quasiment rien (constaté par debug visuel avec couleurs
  temporaires rouge/vert) — juste le titre "Lots" flottant au-dessus d'un espace vide, gênant la lecture du
  reste de la fiche. Christophe a préféré **retirer la section entièrement** de cet écran (`_lots`/
  `_lotActionRow` gardés en code, juste plus affichés) plutôt que déboguer le composant — fait doublon de
  toute façon avec le suivi lot par lot déjà présent dans l'agenda.
- **Titre d'en-tête figé sur "Demande de métré"** peu importe l'avancement réel (constaté : métré ET commande
  faits, toujours "Demande de métré" affiché). Nouveau mapping statut → titre (`_titleForStatus`) : Demande de
  métré → En attente de métré (Acceptée/En cours) → En attente de commande (À commander/Commande en cours) →
  En attente de plannification (À planifier) → En attente de pose (En pose), + Terminé/Clôturé/SAV/À clôturer.
- **Pastille messages non lus qui comptait les messages qu'on a soi-même envoyés** — pas juste ceux reçus non
  lus, donc le compteur montait sans rapport avec un vrai message non lu pendant les tests en va-et-vient entre
  les deux simulateurs. Fix : exclusion de `senderId == currentUid` dans `WiUnreadMessageBadge` ET dans le
  petit point rouge de `ChatEntryButton` (même bug, préexistant, pas ajouté cette session).

### État à la reprise
Les 3 bugs de test réel ci-dessus sont corrigés et poussés, mais **pas re-testés en live après le dernier
correctif** (Christophe a dû redémarrer son Mac juste après). À la reprise : relancer les 2 simulateurs
(iPhone 17 Pro = métreur, iPhone 17 Pro Max = commercial), se reconnecter
(`metreur@workit-test.fr`/`commercial@workit-test.fr`, mdp `Workit2026!`, workspace "Ambiance Alu"), et
reprendre le test en direct là où il s'est arrêté — en particulier vérifier que la pastille de messages non
lus se comporte bien (apparaît côté destinataire seulement, disparaît après ouverture du chat). Les 2 bugs non
corrigés de la session d'hier soir (App Check qui échoue en boucle, overflow `commercial_home_screen.dart:316`)
restent ouverts, pas retouchés aujourd'hui.

## 🆕 Session 2026-08-13 (suite 5) — Courte session de test en direct sur l'iPhone physique de
Christophe (branché USB, `flutter run`). App installée et lancée avec succès (build 98,6s), mais la connexion
au device a été perdue avant qu'un vrai test de connexion Commercial/Métreur ait pu se faire. Deux pistes
identifiées dans les logs avant la coupure, **non corrigées** : (1) `App attestation failed` (403,
`PERMISSION_DENIED`) répété sur `firebaseappcheck.googleapis.com` — Firebase App Check échoue en boucle sur ce
build/device, peut bloquer des appels Firestore/Functions selon l'enforcement serveur ; (2) `RenderFlex
overflowed by 193 pixels on the bottom` dans `commercial_home_screen.dart:316` — vrai bug de layout à
corriger. **Aucun changement de code cette session** (rien à committer côté app) — le commit `57398d5` de
l'après-midi (suite 4, ci-dessous) reste le dernier en date, déjà poussé sur `origin/main` avant la fin de
cette session.

**Dernière mise à jour (suite 4) :** 2026-08-13 (suite 4) — Longue session de test en direct dans le simulateur iOS,
uniquement côté **Commercial**, à la demande de Christophe qui voulait enfin voir l'app tourner sur mobile.
Un vrai crash trouvé et corrigé en tout début (popup de pastille invisible sur mobile — `Material` manquant),
puis une longue série d'allers-retours UX pilotés en direct par Christophe pointant du doigt ce qui n'allait
pas à l'écran : libellé de statut confus, listes qui s'écrasaient l'une l'autre, ombres de cartes coupées,
barre du Planner qui débordait de 186px, panneau backlog qui ne laissait presque plus de place à la grille sur
téléphone, choix Jour/Semaine trop serré sur mobile, écran Réglages resté dans l'ancien thème sombre parallèle
(même famille de bug que `measurement_form_screen.dart` déjà traité le 07/08), et enfin le popup de détail
chantier enrichi pas-à-pas avec les infos utiles par statut (métreur assigné, date de RDV, note du métreur,
photo de déclaration de fin de travaux — ce dernier champ existait déjà en base côté poseur mais n'était
**jamais affiché** côté Commercial). Un bug backend plus large a aussi été trouvé et corrigé au passage : les
Cloud Functions levaient des `Error` JS classiques au lieu de `HttpsError`, donc **aucun message d'erreur
serveur n'a jamais été visible côté client** depuis le début du projet (juste `[firebase_functions/internal]
INTERNAL`) — corrigé sur les 66 occurrences de `functions/index.js` et **déployé en prod** (confirmation
explicite de Christophe). Testé exclusivement avec le rôle Commercial cette session — Métreur/Poseur/Admin
partagent plusieurs des composants touchés (pastilles, "chantiers récents") mais n'ont pas été revérifiés à
l'écran. **Tout commité et poussé sur `origin/main`** à la fin (voir section dédiée avec le detail du commit).

## 🆕 Session 2026-08-13 (suite 5) — Test en direct sur iPhone physique, connexion perdue, 2 pistes ouvertes

Session courte (21h16 → 21h46), déclenchée par Christophe pour tester l'app sur son vrai iPhone (branché USB)
plutôt que le simulateur. Rien de codé, juste du run/observation.

1. **Setup** : iPhone détecté par `flutter devices` mais non appairé avec le Mac. Appairage fait côté
   Christophe via Xcode (Window → Devices and Simulators → Trust).
2. **Lancement** : `flutter run` sur l'iPhone (`00008120-00141D543A6A601E`). Build Xcode 98,6s, install +
   launch 28,8s. App démarrée avec succès, warning bénin `objc` de conflit de classe `FileUtils` entre
   `file_picker` et un framework Apple (connu, sans impact).
3. **Identifiants transmis** pour connexion Commercial (`commercial@workit-test.fr`) et Métreur
   (`metreur@workit-test.fr`), workspace "Ambiance Alu" — pas d'outil de tap automatisé sur device physique,
   donc navigation faite par Christophe lui-même.
4. **Coupure** : "Lost connection to device" avant qu'un vrai test de connexion ait pu se faire. Logs
   capturés avant la coupure montrent deux pistes à investiguer/corriger la prochaine session :
   - `App attestation failed` (403 `PERMISSION_DENIED`) en boucle sur `firebaseappcheck.googleapis.com` —
     Firebase App Check qui échoue sur ce build/device, à surveiller côté Firestore/Functions.
   - `RenderFlex overflowed by 193 pixels on the bottom` — `commercial_home_screen.dart:316`, bug de layout
     réel non corrigé.

Aucun fichier de code modifié cette session — rien à committer, le dépôt était déjà à jour avec `origin/main`
(commit `57398d5` de l'après-midi, suite 4 ci-dessous).

## 🆕 Session 2026-08-13 (suite 4) — Test en direct Commercial : série de bugs UI/UX + backend, popup détail enrichi

Session longue, entièrement pilotée par des retours visuels de Christophe en train de manipuler l'app dans le
simulateur iOS (iPhone 17 Pro). Contrairement aux sessions précédentes, quasiment rien n'était pré-planifié —
chaque correctif a été déclenché par un "regarde, il y a une erreur" ou "ça, c'est pas terrible" au fil de la
navigation. Résumé dans l'ordre chronologique.

### 1 — Setup : premier lancement réel de l'app dans un simulateur
`flutter run -d <iPhone 17 Pro>` lancé depuis ce poste (jamais fait depuis ce Mac avant cette session). Build
iOS ~97s, app démarrée avec succès. Screenshots pris via `xcrun simctl io booted screenshot` pour inspection
visuelle à chaque étape (pas d'outil de tap automatisé disponible — `idb` non installé — donc chaque
interaction/navigation a été faite par Christophe lui-même dans le simulateur, moi je lisais les captures et
les logs `flutter run`/`firebase functions:log` pour diagnostiquer).

### 2 — Crash trouvé au premier tour : popup de pastille illisible
Écran rouge "No Material widget found" en ouvrant le popup "En attente" depuis une pastille du dashboard
Commercial. Cause : `lib/core/widgets/wi_devis_list_modal.dart` enveloppait son contenu dans un `Container`
au lieu d'un `Material` — un `ListTile` a besoin d'un ancêtre `Material` pour peindre son fond/ink splash.
Sur desktop ça passait (le `Dialog` fournit déjà un `Material`), pas sur mobile où la modale est poussée en
plein écran via `MaterialPageRoute`. **Fix** : `Container` → `Material` (1 ligne). Widget partagé par les 4
rôles, donc corrige potentiellement le même crash partout, pas seulement pour le Commercial.

### 3 — Libellé de statut confus : "Devis prog." → "Métré prog."
Christophe ne comprenait pas ce que voulait dire l'onglet "Devis prog." (statut serveur `'En cours'` = le
rendez-vous de métré est planifié). Le badge partagé `wi_status_badge.dart` utilise déjà "Métré prog." pour
ce même statut ailleurs dans l'app — incohérence de libellé, pas un vrai choix produit. Renommé aux 4 endroits
où "Devis prog." apparaissait (onglet pilule, colonne Kanban desktop, 2 badges de carte dans
`commercial_quote_list.dart`).

### 4 — "Affaires récentes" quasi invisible : bande "récents" transformée en horizontal
Juste en dessous des pastilles, la section "Chantiers récemment ajoutés" (`WiRecentChantiersSection`) empilait
**verticalement** jusqu'à 6 cartes pleine largeur (jusqu'à ~570px) dans une `Column` non scrollable, juste
au-dessus de la vraie liste filtrée par onglet — qui elle héritait seulement de l'espace `Expanded` restant,
quasi nul sur mobile. Transformée en **bande horizontale défilante à hauteur fixe** (~110-160px selon les
variantes ci-dessous), plus jamais dictée par le nombre d'items. Composant partagé par les 4 rôles → même bug
probablement présent ailleurs, corrigé pour tous en même temps.

### 5 — Ombre des pastilles coupée
Les cartes de stats (`WiStatRow`, variante horizontale à 4+ pastilles) avaient leur `boxShadow` légèrement
rognée en bas — la `SingleChildScrollView` horizontale clippe par défaut (`Clip.hardEdge`) pile à la hauteur
de son contenu, et l'ombre déborde de quelques pixels sous cette limite. Fix : `clipBehavior: Clip.none` +
un peu de marge basse.

### 6 — Réordonnancement de l'écran Commercial (demande UX explicite)
Christophe : quand on tape un onglet ("Métré prog.", "En attente"...), le résultat filtré devrait apparaître
en haut, pas tout en bas de l'écran après recherche/bouton/récents. Colonne `Column` de
`commercial_home_screen.dart` réordonnée : **stats → liste filtrée par onglet (Expanded) → barre de recherche
→ bouton "Ajouter un devis" → bande "Chantiers récemment ajoutés" en bas**. Le titre "Affaires récentes"
(devenu redondant/mal placé après ce changement) a été retiré à la demande de Christophe.

### 7 — Bug de navigation trouvé en testant : "Relancer" fonctionne, mais l'onglet actif reste faux
Christophe a confirmé en direct que le bouton "Relancer" d'une carte devis déclenche bien la notification côté
métreur (fonctionnalité de la session du 07/08, jamais testée en conditions réelles jusqu'ici — **confirmée
fonctionnelle**). Repéré au passage sur la même capture : l'onglet "Agenda" restait surligné en bleu après un
retour en arrière depuis le Planner, alors que l'écran affiché était bien "Devis". Cause :
`_onNavTap` marquait l'onglet actif de façon permanente (`setState`) avant de pousser Agenda/Réglages en
`Navigator.push` — jamais remis à "Devis" au retour. Fix : ne marquer l'onglet actif que pour l'index 0
(Devis), qui est le seul contenu réellement affiché dans cet onglet (Agenda/Réglages sont des écrans poussés
par-dessus, pas un contenu de cet onglet).

### 8 — Planner : `RenderFlex` overflow de 186px dans la barre du haut
Vraie erreur (log complet capturé via `flutter run`) : le `Row` de `_TopBar` (`planner_screen.dart:814`)
débordait de 186px sur la droite dès que les boutons "Congés" et "+ Équipe" apparaissaient (droits complets
donnés au Commercial la session précédente, jamais testés en conditions réelles sur téléphone). Fix : ces deux
actions secondaires regroupées dans un menu "⋮" (`PopupMenuButton`) au lieu de boutons texte côte à côte —
garantit qu'il n'y aura plus jamais de débordement quel que soit le nombre d'actions ou la largeur d'écran.
Composant partagé Commercial/Métreur/Admin.

### 9 — Planner mobile : panneau backlog repensé (2 itérations)
Constat de Christophe : sur mobile, le panneau backlog (260pt fixe) prenait presque toute la largeur, ne
laissant qu'un filet à peine visible pour la grille équipes×jours — inutilisable.
- **Itération 1 (rejetée par Christophe)** : tiroir superposé (`Stack`), replié par défaut derrière un badge
  "Backlog (N)", ouvrable en tiroir latéral par-dessus la grille. Problème signalé immédiatement : impossible
  de voir le backlog ET la grille en même temps → glisser-déposer d'une carte vers une cellule devenait
  impraticable (il faut voir la cible pour y glisser quelque chose).
- **Itération 2 (retenue)** : bande horizontale défilante (même principe que "Chantiers récemment ajoutés",
  point 4) fixée **au-dessus** de la grille, toujours visible en même temps qu'elle. Nouveaux widgets
  `_MobileBacklogStrip`/`_MobileBacklogCard`. Le glisser-déposer fonctionne : Flutter fait remonter le
  `Draggable` au niveau de l'`Overlay` pendant le drag, donc la carte peut être lâchée sur une cellule de la
  grille juste en dessous sans problème.

### 10 — Bug révélé par le test du drag-and-drop : erreur serveur illisible
Christophe a testé le glisser-déposer d'une carte "Bloquée" (statut `'À commander'`, pas encore commandée) sur
une cellule de la grille : `[firebase_functions/internal] INTERNAL` affiché en plein écran. Investigation via
`firebase functions:log` (logs prod réels) : la vraie cause était `Error: Transition non autorisée : À
commander → En pose` — refus légitime du serveur (on ne peut pas planifier un chantier pas encore commandé),
mais le message ne remontait jamais côté client. Deux corrections :
- **Client** (garde-fou immédiat, sans déploiement) : `onWillAcceptWithDetails` du `DragTarget` vérifie
  désormais `details.data.isReady` (même règle exacte que le serveur : statut `'À planifier'` + dépendances
  satisfaites + livraison fournisseur passée) — une carte "Bloquée" rebondit simplement à sa place au lieu de
  déclencher un appel serveur voué à l'échec.
- **Serveur** (le vrai fond du problème, bien plus large) : voir section 11 ci-dessous.

### 11 — Bug backend systémique : 66 `Error` → `HttpsError` dans `functions/index.js`
Cloud Functions (callable) ne transmet le message d'erreur au client **que** pour un `HttpsError` — un
`Error` JS classique renvoie toujours un code générique `internal` sans aucun détail, par sécurité (évite de
fuiter des stacktraces arbitraires). `functions/index.js` levait des `Error` classiques partout (66 occurrences
recensées) depuis le tout début du projet — **chaque erreur serveur de toute l'app, tous rôles confondus,
n'a donc jamais affiché son vrai message aux utilisateurs**, uniquement `[firebase_functions/internal]
INTERNAL`. Corrigé les 66 occurrences avec un code sémantique par cas (`not-found`, `permission-denied`,
`invalid-argument`, `failed-precondition`, `unauthenticated`, `resource-exhausted`) via un script de
remplacement ciblé (`throw new Error(` → `throw new HttpsError("<code>", `, sans toucher au reste du message,
donc sans risque de casser les messages multi-lignes existants). Import `HttpsError` ajouté à
`firebase-functions/v2/https`. Reformatage manuel des lignes dépassant 80 caractères (règle ESLint `max-len`)
après le remplacement mécanique.

**✅ Déployé sur Firebase** (confirmation explicite de Christophe, "vas-y déploie") : `firebase deploy --only
functions` réussi sur `workit-1daa1`, 9 fonctions mises à jour sur Node.js 22 (2nd Gen) — `analyzeDevis`,
`provisionAccounts`, `transitionDevisStatus`, `sendRelance`, `setLotDependencies`, `updateLotPlanningFields`,
`logTimeEntry`, `onDevisStatusChange`, `onChantierMessageCreated`. Toutes les instances ont démarré proprement
(`STARTUP TCP probe succeeded`) après déploiement, aucune erreur de boot dans les logs.

### 12 — Planner mobile : 3 ajustements supplémentaires demandés par Christophe
Après un nouveau test en direct (2e équipe créée pour l'occasion) :
- **Libellés de jour collés au bord de l'écran** ("Lun 10/08"...) : petit gutter de 8px ajouté à gauche de la
  grille (`padding: EdgeInsets.only(left: 8)` sur la `SingleChildScrollView` horizontale).
- **Plusieurs équipes = illisible sur mobile** : nouveau **sélecteur d'équipe** mobile
  (`_MobileTeamPicker`, menu "Afficher Équipe X ▾") qui n'apparaît que si 2+ équipes existent — une seule
  équipe à la fois occupe alors toute la largeur de la grille (le filtrage se fait en amont dans
  `_PlannerScreenState`, qui ne passe qu'une liste d'1 équipe à `_PlannerBody`, réutilisant tel quel le code
  de grille existant sans le modifier). Desktop inchangé (toutes les équipes restent visibles côte à côte).
- **Choix Jour/Semaine trop serré sur mobile** : le sélecteur "Semaine" retiré sur mobile (uniquement "Jour"
  disponible), desktop inchangé. `_PlannerScreenState` force `effectiveWeekMode = false` sur mobile sans
  toucher au champ `_weekMode` sous-jacent (inoffensif, juste ignoré tant qu'on est sur petit écran).

### 13 — Écran Réglages : thème sombre parallèle jamais migré + 2 liens légaux ajoutés
Christophe : "dans Réglages c'est noir, fais comme le reste" + demande d'ajouter des liens Conditions
Générales de Vente / Politique de Confidentialité (contenu fictif pour l'instant). `settings_screen.dart`
avait exactement le même défaut que `measurement_form_screen.dart` traité le 07/08 : thème sombre autonome
codé en dur (`Color(0xFF07090D)` + accent vert néon `Color(0xFF00E676)`, jamais branché sur `AppColors`).
Refonte complète en `AppColors` (fond clair, cartes blanches à bordure fine, accent bleu `primary`). Nouvelle
section "Légal" avec 2 entrées ("Conditions générales de vente", "Politique de confidentialité"), chacune
ouvrant un écran placeholder "Contenu à venir" — navigation fonctionnelle dès maintenant, vrai texte
juridique à fournir plus tard par Christophe.

**Bug auto-introduit puis corrigé dans la foulée** : la première version de la refonte enveloppait le
`ListTile`/`SwitchListTile` dans un `Container` à fond coloré — exactement le même anti-pattern que le point 2
(Material manquant), reproduit sous les nouvelles couleurs. Repéré via les logs `flutter run`
("ListTile background color or ink splashes may be invisible"), corrigé en remplaçant le `Container` par un
vrai `Material` avec `shape`/`side` pour la bordure + les coins arrondis.

### 14 — Popup de détail chantier : enrichi pas-à-pas, par statut, à la demande de Christophe
Christophe a listé précisément ce qu'il voulait voir apparaître dans le popup (`_ChantierDetailBody`,
`commercial_chantier_detail.dart`) selon le statut du chantier :

| Statut | Demandé | Résultat |
|---|---|---|
| En attente | Nom du métreur à qui la demande a été envoyée | Ajouté : "Demande de métré envoyée à : X" |
| Métré prog. | Date du métré programmé | Ajouté : le champ `meetingAt` existait déjà sur `_QuoteItem` mais n'était jamais affiché |
| À commander | Note libre du métreur (ex. "grille d'aération à retirer") | Déjà fonctionnel — champ `metreurNote`/`metreurNoteName`, écrit via le bouton "Demander des informations" côté métreur (`metreur_home_screen.dart`), déjà affiché inconditionnellement côté Commercial. Juste relabellisé "Métré réalisé par : X" pour le nom du métreur à cette étape (au lieu de "envoyée à", qui n'a plus de sens une fois le métré fait) |
| À planifier | Rien de spécial | Confirmé par Christophe, aucun changement |
| En pose | Date de pose + équipe assignée | Déjà fonctionnel, aucun changement |
| Terminé | Photo de la déclaration de fin de travaux | Ajouté : `rapportFin.attestationUrl` existait déjà côté poseur (`poseurs_home_screen.dart`, upload séparé dans `attestations_fin_travaux/`, distinct des photos de chantier classiques) mais n'était **jamais affiché** côté Commercial — seules les photos de chantier génériques (`photoUrls`) l'étaient |

Un seul champ `assignedMetreurName` réutilisé avec un libellé différent selon le groupe de statuts (plutôt
qu'un nouveau champ) : "Demande de métré envoyée à" pour {vide, Nouvelle demande, Acceptée, À classer},
"Métré réalisé par" pour {À commander, Commande en cours}, rien pour Métré prog. (En cours, où c'est la date
du RDV qui prime) ni au-delà.

**Aller-retour sur les données de démo** : Christophe testait avec "Dupont Jean", une fiche de démo codée en
dur (`_kDemoDevis` dans `commercial_models.dart`) sans `assignedMetreurName` renseigné — code déjà correct,
juste rien à afficher faute de donnée. Ajouté `assignedMetreurName: 'Pascal M.'` sur cette fiche, puis
enrichi les autres fiches de démo pour couvrir chaque nouveau bloc (Laurent Céline → note métreur, Moreau
Julie → `rapportFin` avec photos + attestation, images placeholder `picsum.photos` pour que ça charge
visuellement en test). **Point d'apprentissage noté pour la suite** : `_kDemoDevis` est une liste top-level
`final` — un hot **reload** ne réexécute pas son initialisation (limitation connue de Flutter), il faut un hot
**restart** pour voir les changements de données de démo. Premier essai raté pour cette raison précise
(Christophe : "toujours pas..."), diagnostiqué et corrigé.

### Vérifications faites cette session
`flutter analyze` après quasiment chaque modification : **0 erreur** tout du long (seulement les infos
`withOpacity` dépréciées déjà tolérées ailleurs, et les warnings d'imports morts déjà présents avant cette
session). `npm run lint` (functions) + `node -c index.js` : 0 erreur après le remplacement massif
`Error`→`HttpsError`. `firebase deploy --only functions --dry-run` réussi avant le déploiement réel.

### ✅ Déployé sur Firebase
Uniquement `functions` (pas de changement Firestore rules/index cette session) — voir détail section 11.
C'est le 2e déploiement de la journée (après celui de la session "(suite 3)" ci-dessous, qui lui concernait
Phases 3-6 + chantiers du 13/08 matin).

### ⚠️ Pas fait cette session
- **Testé uniquement le rôle Commercial** — Métreur/Poseur/Admin partagent plusieurs composants touchés
  (`WiRecentChantiersSection`, `WiStatRow`, le fix Material du popup) mais n'ont pas été revérifiés à l'écran.
- **Contenu légal toujours fictif** (CGV/Politique de confidentialité) — juste la navigation, pas le texte.
- **Images placeholder** (`picsum.photos`) dans les données de démo enrichies — à remplacer par de vraies
  URLs Firebase Storage si ces fiches de démo doivent un jour ressembler à de vraies données.
- **`npm audit`** : 30 vulnérabilités toujours pas investiguées (reporté depuis la session "(suite 3)").

### 📌 Nouvelle demande produit à traiter (pas commencée) — Messagerie interne scoping fin
Christophe veut une **messagerie interne entre les membres concernés d'un chantier**, mais avec un scoping
précis : **pas de broadcast à tout le rôle**, seulement aux personnes réellement impliquées sur CE chantier
précis. Exemples donnés :
- Pas "tous les métreurs" → seulement **le métreur assigné** à ce chantier (`assignedMetreurName`/uid).
- Pas "tous les poseurs" → seulement **les membres de l'équipe assignée** à la pose de ce chantier
  (`team.memberIds`/`poseurIds`, pas tout le rôle poseur du workspace).
- Vraisemblablement aussi le commercial créateur + l'admin par défaut (à confirmer avec Christophe).

Il existe déjà un point d'entrée de chat par chantier (`ChatEntryButton`/`chantier_chat_screen.dart`,
`onChantierMessageCreated` côté Cloud Functions) — à vérifier en priorité si l'infra actuelle est déjà
scoping-aware (liste de participants par chantier) ou si c'est un chat ouvert à tout le workspace/tout le rôle
qu'il faudrait restreindre. Pas commencé — juste noté à la demande explicite de Christophe pour la prochaine
session.

### Reste à faire (prochaine session)
1. **Messagerie interne scoping fin** (voir ci-dessus) — nouvelle demande produit, pas commencée.
2. **Tester Métreur/Poseur/Admin** avec le même niveau de rigueur que le Commercial cette session — plusieurs
   composants partagés ont été corrigés à l'aveugle pour ces rôles (jamais revérifiés à l'écran).
3. Fournir le vrai contenu CGV/Politique de confidentialité (juste la navigation existe).
4. `npm audit` (30 vulnérabilités, reporté depuis plusieurs sessions).
5. Phase 7 de la roadmap (validation des 12 métiers) — toujours pas commencée.

---

## 🆕 Session 2026-08-13 (suite 3) — Mise à jour firebase-functions

`npm install --save firebase-functions@latest` exécuté dans `functions/`. Résultat : `firebase-functions`
passe de `^7.0.0` à `^7.3.2` — reste dans la même version majeure, donc pas de rupture d'API attendue (et
confirmée : aucune erreur au chargement). `firebase-admin` a aussi été légèrement bougé par npm au passage
(résolution de dépendances). `npm audit` signale 30 vulnérabilités (2 low/13 moderate/12 high/3 critical) sur
l'arbre de dépendances complet — **pas investigué cette session** (probablement pré-existant, propre aux
nombreuses dépendances transitives d'un projet Cloud Functions ; `npm audit fix --force` non lancé pour
éviter des ruptures à l'aveugle).

### Vérifications faites
`node -c` sur tous les fichiers `functions/*.js` : 0 erreur. `npm run lint` : 0 erreur.
`firebase deploy --only functions,firestore --dry-run` : réussi, le warning "package.json indicates an
outdated version of firebase-functions" a disparu.

### Reste à faire (prochaine session)
1. Décider du déploiement de cette mise à jour (`firebase deploy --only functions`) avec Christophe.
2. Éventuellement investiguer les vulnérabilités `npm audit` si Christophe le souhaite (pas fait, hors
   scope de cette demande ponctuelle).

---

## 🆕 Session 2026-08-13 (suite 2) — Vérification en direct contre la prod après déploiement

Après le déploiement Firebase de la session précédente (voir section ci-dessous), Christophe a demandé un
tour de vérification en direct dans Chrome, cette fois contre le vrai backend prod (pas dry-run).

### Vérifié avec succès
- **Glisser-déposer Planner par un Commercial** (le point le plus critique — nouvelle permission serveur sur
  `transitionDevisStatus`/`updateLotPlanningFields`/`setLotDependencies`, jamais invoquée en conditions
  réelles avant ce test) : un devis réel (`##634 - Claude TestDesign`) créé côté Commercial, métré saisi et
  validé côté Métreur (transition automatique vers "À commander"), commande confirmée ("À planifier"), puis
  glissé avec succès dans une cellule du Planner en tant que Commercial. Confirmé par `firebase functions:log`
  : appels `transitionDevisStatus` avec `"auth":"VALID"`, aucune erreur après le déploiement.
- **Nav Métreur** : confirmé 3 onglets (Accueil/Agenda/Réglages), l'onglet fantôme "Chantiers" a bien disparu.
- **Dashboards 6 catégories** : reconfirmés visuellement (Métreur et Admin, vue desktop cette fois).
- **Aucune erreur** dans les logs Cloud Functions depuis le déploiement (`firebase functions:log`), à part
  des erreurs anciennes datant de tests précédant le déploiement (`Chantier introuvable` sur des IDs de démo,
  sans rapport).

### Non vérifié
- **Notification admin "nouveau chantier" en in-app** : pas trouvé rapidement l'UI de notifications côté
  admin dans le temps imparti pour ce tour de vérification. Le code est déployé (`writeInAppNotification`
  ajouté dans `onDevisStatusChange`) et suit exactement le même pattern que 3 autres notifications déjà
  fonctionnelles (`devisWorkflow.js`) — risque résiduel jugé faible, mais pas de confirmation visuelle.

### Repères pour reprendre le test
Workspace "WorkIt Test CPO" (comptes `admin.cpo.test@/commercial.cpo.test@/metreur.cpo.test@workit-test.fr`,
mdp `Workit2026!`) a un vrai compte admin utilisable pour tester les notifications — contrairement à
"Ambiance Alu" où Christophe n'a pas de compte admin de test.

---

## 🆕 Session 2026-08-13 (suite) — Dette design restante, 2 bugs préexistants, migration Node 22, déploiement

Après le test en direct réussi (section ci-dessous), Christophe a demandé de traiter les 5 points identifiés
en fin d'audit : dette design poseur/admin/planner, notification admin manquante en in-app, Kanban
Commercial (SAV mélangé), nav Métreur cassée, migration runtime Node.js.

### Design — poseurs_home_screen.dart (le plus gros chantier)
`_poseurAccent` était câblé sur `AppColors.primary` (bleu) au lieu de `AppColors.rolePoseur` (vert) — un seul
changement de constante qui corrige l'identité couleur partout dans l'écran d'un coup. Puis ~40 couleurs
`Colors.white*`/`Colors.black*`/`Colors.orangeAccent`/`Colors.redAccent`/`Colors.greenAccent`/`Colors.tealAccent`
codées en dur remplacées par `AppColors`, rôle par rôle (texte/bordure/fond), comme pour
`measurement_form_screen.dart` la session précédente. Plusieurs vrais bugs de contraste corrigés au passage
(hérités du thème sombre jamais adapté) : texte des onglets non sélectionnés invisible (blanc sur fond
blanc), icônes de suppression de photo invisibles (gris foncé sur cercle semi-transparent noir), libellé
"Pas payé" invisible, ombre de carte beaucoup trop lourde (`black54`, blur 20) pour un fond clair. Fonctions
`_statusColor`/`_summaryStatusColor` (mapping statut→couleur) réalignées sur la palette `AppColors` déjà
utilisée ailleurs (Terminé=success, À clôturer=amber, SAV=danger).

### Design — dette légère (admin_team_tab, admin_dashboard_tab, planner_screen)
Confirmée légère comme attendu : quelques `Colors.*` bruts isolés remplacés par `AppColors` équivalents
(spinner noir invisible sur bouton bleu, icône d'erreur orange non alignée sur la palette, fond de bloc
"problème" utilisant `Colors.red` au lieu de `AppColors.danger` alors que sa bordure l'utilisait déjà — 3
SnackBar d'erreur dans `planner_screen.dart` alignées sur `AppColors.danger`).

### Bug — notification admin "nouveau chantier" pas écrite en in-app
`functions/index.js` (`onDevisStatusChange`, cas création de devis) : `writeInAppNotification` ajouté à côté
du push existant pour l'admin, même pattern que les autres notifications déjà correctes.

### Bugs préexistants découverts pendant le test en direct de la session précédente
- **Kanban Commercial** : la colonne "Terminés" scindée en "Terminés" (Terminé/Clôturé/À clôturer) et "SAV"
  séparée — sans toucher aux listes mobiles partagées (`terminesItems` inchangé, filtré uniquement au moment
  du rendu des colonnes Kanban).
- **Nav Métreur** : l'onglet "Chantiers" (qui affichait exactement le même contenu qu'"Accueil", `_bottomNavIndex`
  jamais branché au corps de l'écran) retiré — 3 items restants (Accueil/Agenda/Réglages), cohérent avec le
  nav Commercial.

### Migration runtime Cloud Functions Node.js 20 → 22
`functions/package.json` : `engines.node` passé de `"20"` à `"22"` (Node 20 décommissionné le 2026-10-30 par
Firebase). Le warning de dépréciation a disparu du dry-run après ce changement. **Volontairement pas touché** :
la version de la lib `firebase-functions` elle-même (`^7.0.0`, un `npm install --save firebase-functions@latest`
est recommandé par le CLI mais reste une dépendance majeure plus risquée à bump à l'aveugle sans test réel —
laissé en l'état, à reprendre séparément si besoin).

### Vérifications faites cette session
`flutter analyze` : 0 erreur tout du long (133→134 issues, stable). `npm run lint` (functions) : 0 erreur.
`firebase deploy --only functions,firestore --dry-run` : réussi après le passage à Node 22 (warning runtime
disparu, seul le warning firebase-functions outdated reste, attendu).

### ✅ Déployé sur Firebase (décidé explicitement avec Christophe)
`firebase deploy --only functions,firestore` exécuté avec succès sur `workit-1daa1` : règles et index publiés,
9 Cloud Functions déployées sur Node.js 22 (2nd Gen) — `sendRelance` (créée, jamais déployée depuis le 07/08),
`updateLotPlanningFields`, `analyzeDevis`, `logTimeEntry`, `onChantierMessageCreated`, `transitionDevisStatus`,
`setLotDependencies`, `onDevisStatusChange`, `provisionAccounts` (mises à jour). **C'est le premier vrai
déploiement depuis le 05/08** — tout ce qui s'était accumulé en dry-run depuis (Phases 3 à 6 de la roadmap,
jamais testées en direct) est donc désormais potentiellement actif en prod, en plus des chantiers de cette
session et de la précédente.

### Reste à faire (prochaine session)
1. **Tester en direct en prod** — priorité absolue, vu l'ampleur de ce qui vient d'être déployé d'un coup
   (5+ sessions de travail jamais vérifiées ensemble). En particulier les Phases 3-6 (multi-lots, Planner v2,
   expérience terrain, KPIs) et les chantiers de cette session/la précédente (scope Commercial, agenda par
   équipe, dashboards 6 catégories, design poseur/métreur).
2. Décider si `npm install --save firebase-functions@latest` doit être fait (recommandé par le CLI, pas fait
   cette session par prudence).
3. Phase 7 de la roadmap (validation des 12 métiers) — phase produit, pas de dev, toujours pas commencée.

---

## 🆕 Session 2026-08-13 (suite) — Test en direct dans Chrome des 4 chantiers ci-dessous

Le blocage "page blanche" qui avait interrompu le test du 07/08 **ne s'est pas reproduit** — juste un temps de
compilation DDC plus long qu'anticipé (patience suffisante, pas de vraie cause identifiée ni corrigée, à garder
en tête si ça se reproduit). Testé avec les comptes `commercial@/metreur@/poseur@workit-test.fr` :
- **Scope Commercial** : confirmé, Marie (commercial) ne voit que ses propres chantiers.
- **Accès équipe Métreur** : l'onglet Réglages ouvre bien Paramètres désormais (avant : n'ouvrait rien).
- **Agenda par équipe** : Commercial → Planner complet (Congés/+Équipe visibles) ; Métreur → inchangé ; Poseur →
  lecture seule, sans Congés/+Équipe, limité à sa seule équipe.
- **Dashboards 6 catégories** : vérifiés visuellement pour Commercial (ligne de 6) et Métreur (2×3).
- **Refonte design measurement_form_screen.dart** : confirmée en conditions réelles — un vrai devis test créé
  côté Commercial, accepté côté Métreur, écran de métré ouvert : fond clair, accent violet métreur, texte
  lisible, focus bleu sur les champs. Le "noir/vert" a disparu.

Aucune erreur console sur tout le parcours (hors avertissements App Check debug déjà connus).

---

## 🆕 Session 2026-08-13 — Scope Commercial, équipe métreur, agenda par équipe, dashboards 6 catégories, refonte design métré

Reprise du plan laissé par l'audit du 07/08 (voir section ci-dessous), traité étape par étape à la demande de
Christophe : "occupe-toi une étape après l'autre de : 1) bug de scope Commercial, 2) décisions produit en
attente, 3) dashboards à 6 catégories, 4) refonte design measurement_form_screen, 5) tester en direct".

### 1 — Bug critique : fuite de données Commercial (voir bug du 07/08)
`lib/screens/commercial/commercial_home_screen.dart` : les 5 requêtes Firestore qui alimentent les
pastilles/popup/récents du Commercial filtrent désormais par `.where('userId', isEqualTo: uid)`, comme
`agenda_screen.dart` le faisait déjà pour le même rôle. Un filtre avait été explicitement retiré par le passé
(commentaire "Removed redundant where clause to avoid index requirement") — l'index composite manquant
(`devis` : `userId` ASC + `createdAt` DESC) a été ajouté dans `firestore.indexes.json`. Vérifié par les
règles Firestore que la lecture large (tout membre du workspace peut lire tous les devis, nécessaire pour
métreur/admin) n'était pas le problème : c'est bien un filtre client manquant, pas une faille de règles.

### 2 — Décisions produit tranchées avec Christophe (AskUserQuestion)
- **Clôture métreur** : reste réservée à Commercial/Admin (Phase 5 confirmée) — le récap était imprécis sur
  ce point, pas de code à changer.
- **Acceptation poseur** : pas de nouveau flux Accepter/Refuser — l'affichage automatique en "À faire" est
  confirmé suffisant, le récap décrivait juste maladroitement ce qui existe déjà.
- **Équipe métreur** (codé) : `canManageTeam`/`manageableRoles` étaient déjà génériques côté données, règles
  Firestore et Cloud Function `provisionAccounts` (un admin pouvait déjà déléguer ce droit à un métreur) —
  il manquait juste le branchement client. `lib/screens/metreur_home_screen.dart` : l'onglet "Réglages" ne
  faisait que changer une variable d'état locale lue nulle part (n'ouvrait donc rien) ; corrigé pour naviguer
  vers `SettingsScreen`, qui affiche déjà conditionnellement "Gérer l'équipe" si `canManageTeam` est vrai.
  Import `settings_screen.dart` qui était mort devient utilisé (−1 issue analyze au passage).
- **Agenda par équipe Commercial/Poseur** (codé) : Commercial avec droits d'édition complets comme
  Métreur/Admin, Poseur en lecture seule filtrée à ses propres poses (choix précisés avec Christophe via
  AskUserQuestion après avoir signalé que le drag-and-drop du Planner passe par des Cloud Functions
  server-gated metreur/admin uniquement).
  - `functions/devisWorkflow.js` : `commercial` ajouté aux rôles autorisés sur les transitions
    "À planifier→En pose" et "En pose→En pose" (glisser-déposer).
  - `functions/index.js` : `commercial` ajouté aux rôles autorisés dans `updateLotPlanningFields` et
    `setLotDependencies`.
  - `lib/screens/commercial/commercial_home_screen.dart` : l'onglet "Agenda" ouvre le vrai `PlannerScreen`
    au lieu du simple `AgendaScreen` chronologique (import mort retiré).
  - `lib/screens/planner_screen.dart` : `PlannerScreen` gagne 2 paramètres optionnels — `readOnly` (masque
    création d'équipe/congés, désactive le glisser-déposer, affiche les détails en texte statique sans
    bouton Enregistrer) et `filterPoseurId` (limite aux équipes dont le poseur est membre et aux chantiers où
    il est assigné, masque le backlog). Admin/Métreur/Commercial inchangés (valeurs par défaut).
  - `lib/screens/poseurs_home_screen.dart` : nouvelle icône "Agenda" dans l'AppBar, ouvre le Planner en
    lecture seule filtré à lui (`readOnly: true, filterPoseurId: _userId`).

### 3 — Dashboards à 6 catégories (Admin/Commercial/Métreur)
Le texte exact du récap de Christophe sur les "6 catégories" n'était pas retrouvable dans les fichiers du
projet (collé dans une conversation passée, jamais sauvegardé) — répartition confirmée avec lui via
AskUserQuestion plutôt que devinée : **En attente** (Nouvelle demande + Acceptée + En cours) / **À commander**
(+ Commande en cours) / **À planifier** / **En pose** (+ À clôturer, rapport en attente de validation) /
**Terminé** / **SAV** — ce dernier point étant explicitement la distinction que le récap reprochait de voir
perdue ("terminé propre" vs "problème").
- `lib/screens/admin_dashboard_tab.dart` : grille 4→6 `_StatCard`.
- `lib/screens/commercial/commercial_home_screen.dart` : ligne de stats 3→6 `WiStat`.
- `lib/core/widgets/wi_stat_row.dart` (composant partagé) : bascule en rangée défilante horizontale
  au-delà de 3 pastilles, pour éviter que 6 cartes s'écrasent sur mobile (seul appelant : Commercial).
- `lib/screens/metreur_home_screen.dart` : 3 `_StatChip`→6 sur 2 rangées de 3, calculées séparément à partir
  de `allItems` **sans toucher** aux tabs/listes de navigation existants (À faire/En cours/etc., utilisés par
  les flux d'acceptation de chantier) — restructurer ce modèle de données pour coller à 100% aux 6 catégories
  aurait été risqué pour un gain purement visuel.
- **Non touché volontairement** : le Kanban desktop du Commercial (vue de navigation détaillée différente des
  pastilles de résumé) a encore une colonne "Terminés" qui mélange Terminé/Clôturé/SAV — même défaut que
  l'ancien dashboard, mais hors du périmètre demandé cette fois. À reprendre si Christophe le souhaite.

### 4 — Refonte design measurement_form_screen.dart (écran "noir/vert")
Thème sombre autonome (`_bg`/`_accent`/`_cardBg` en `Color(0xFF...)` codés en dur, ~40 usages de
`Colors.white*`/`Colors.black`) remplacé par `AppColors` : `_bg`→`AppColors.background`,
`_accent`→`AppColors.roleMetteur` (violet, cohérent avec l'identité couleur du métreur ailleurs dans l'app —
le vert d'origine n'avait pas de sens sémantique), `_cardBg`→`AppColors.surface`. Chaque couleur convertie
selon son rôle (texte principal/label/bordure/fond de champ), pas juste son opacité d'origine.
`Colors.orangeAccent`→`AppColors.warning`, `Colors.red`→`AppColors.danger` au passage pour cohérence palette.

### Vérifications faites cette session
- `flutter analyze` après chaque étape : **0 erreur** tout du long, 138→137→137→137→**133** issues (baisse
  nette sur la dernière étape : plusieurs `.withOpacity` dépréciés disparus en simplifiant les couleurs de
  measurement_form_screen.dart).
- `npm run lint` (functions) + `node -c` sur `index.js`/`devisWorkflow.js` : 0 erreur.
- `firebase deploy --only functions,firestore --dry-run` : réussi (règles + nouvel index + Cloud Functions
  modifiées compilés et packagés sans erreur).

### Git : commité et poussé sur `origin/main`
10 fichiers modifiés (`firestore.indexes.json`, `functions/devisWorkflow.js`, `functions/index.js`,
`lib/core/widgets/wi_stat_row.dart`, `lib/screens/admin_dashboard_tab.dart`,
`lib/screens/commercial/commercial_home_screen.dart`, `lib/screens/measurement_form_screen.dart`,
`lib/screens/metreur_home_screen.dart`, `lib/screens/planner_screen.dart`,
`lib/screens/poseurs_home_screen.dart`). Un seul commit regroupant les 4 chantiers de cette session, poussé
sur `origin/main`.

### ⚠️ Pas fait cette session
- **Pas déployé sur Firebase** — uniquement des dry-run, comme toutes les sessions précédentes. Décision à
  prendre avec Christophe.
- **Pas testé en direct** — étape 5 du plan, volontairement reportée. Le blocage Chrome (page blanche
  persistante malgré modules DDC chargés en succès) qui avait interrompu le test du 07/08 n'a jamais été
  résolu ni recreusé cette session.

### Reste à faire (prochaine session)
1. **Tester en direct** tous les chantiers de cette session (scope commercial, accès équipe métreur, agenda
   Commercial/Poseur en édition/lecture seule, dashboards 6 catégories, design measurement_form_screen) —
   rien n'a encore été vérifié visuellement à l'écran. Si le blocage Chrome/web-server persiste : essayer un
   profil Chrome différent, `-d chrome` au lieu de `-d web-server`, ou le test manuel de Christophe sur son
   poste (Mac).
2. Décider du déploiement (`firebase deploy --only functions,firestore`) une fois testé et validé.
3. Optionnel : corriger la colonne "Terminés" du Kanban Commercial (mélange encore Terminé/Clôturé/SAV, même
   défaut que l'ancien dashboard, non traité cette session — signalé mais pas demandé explicitement).
4. Les points du plan du 07/08 pas encore repris : dette design restante (`poseurs_home_screen.dart` le plus
   chargé en couleurs en dur + mauvaise couleur d'accent, `admin_team_tab.dart`, `admin_dashboard_tab.dart`,
   `planner_screen.dart`), notification admin "nouveau chantier" pas écrite en in-app (asymétrie push/in-app).

---

## 🆕 Session 2026-08-07 (suite) — Audit complet vs récap + git push avant les 4 jours d'absence

Avant de partir, Christophe a demandé : (1) une revérification complète du code réel face à SON récap
(pas juste les 3 chantiers déjà traités ce jour), (2) un état des lieux du design (il sait déjà que les
écrans de métré sont restés "en noir/vert"), (3) un résumé de ce qui reste à faire, (4) tout sauvegarder
dans ce journal et pousser sur `origin/main`. 4 agents lancés en parallèle (un par rôle) pour comparer
chaque ligne du récap au code réel — méthode : lecture directe des fichiers, pas de confiance dans le
journal ou la mémoire.

### 🐛 Bug critique trouvé : le Commercial voit les chantiers de TOUT le workspace, pas seulement les siens
Le récap est explicite : les pastilles/popup/récents du Commercial doivent être scopées à ses propres
chantiers ("pas comme admin qui voit tout le monde"). Confirmé par grep sur `commercial_home_screen.dart` :
**aucune** des requêtes Firestore qui alimentent les stats/popup/récents ne filtre par `userId`/
`commercialId` (contrairement à `agenda_screen.dart` dans le même dossier, qui applique bien
`.where('userId', isEqualTo: uid)`). Un commercial voit donc aujourd'hui les chantiers des autres
commerciaux dans son propre tableau de bord — fuite de données entre commerciaux d'un même workspace, pas
juste un écart de confort. **Pas corrigé cette session** (trouvé en toute fin, faute de temps) — à corriger
en priorité avant tout test avec de vrais comptes commerciaux multiples.

### Écarts fonctionnels confirmés (par rôle)

**Admin**
- Tableau de bord : 4 pastilles au lieu des 6 catégories distinctes demandées. En particulier, "Terminés"
  fusionne silencieusement les chantiers réellement terminés ET ceux en SAV/problème (`À clôturer`/`SAV`) —
  perd la distinction "terminé propre" vs "pas terminé/problème" que le récap demande explicitement dans les
  notifs ET le dashboard.
- Notification "nouveau chantier créé par un commercial" : envoyée en push (`functions/index.js:1388-1393`)
  mais jamais écrite en in-app (`writeInAppNotification` absent à cet endroit, présent pour les 2 autres cas
  admin) — asymétrie mineure, l'admin ne la retrouve pas dans son historique de notifs.
- Reste conforme : Planner par équipe, gestion d'équipe (ajout/suppression + les 2 droits), admin peut
  métrer/commander lui-même.

**Commercial** (voir bug critique ci-dessus)
- 3 pastilles au lieu de 6 (même limitation que l'admin, en plus du bug de scope).
- Pas de vrai agenda/planning par équipe — `AgendaScreen` est une simple liste chronologique, et le
  `WiKanbanBoard` de l'écran d'accueil n'est qu'un board de statuts de devis, pas un planning par équipe de
  pose avec métrés programmés comme demandé.
- Conforme : ajout de chantier, gestion d'équipe si droits (via Réglages), les 6 notifications demandées
  sont toutes bien envoyées.

**Métreur**
- **Ne peut pas clôturer un chantier** — seulement "Relancer la clôture" (nouveau bouton de ce jour). La
  vraie validation (Terminé/SAV) est réservée au Commercial/Admin depuis la Phase 5 (décision déjà actée à
  l'époque). Le récap dit "clôture les chantiers" pour le métreur — **contradiction à trancher avec
  Christophe** : le récap est-il imprécis, ou veut-il vraiment redonner ce pouvoir au métreur ?
- **Aucun accès à la gestion d'équipe**, même avec le droit — pire, l'écran renvoie littéralement le métreur
  vers "Admin > Équipe" dans son propre message d'erreur. `canManageTeam` existe comme mécanisme générique
  mais n'est jamais branché côté métreur.
- Conforme : toutes les autres étapes du rôle, les 4 notifications demandées, l'agenda par équipe (vrai lien
  vers le Planner).

**Poseur**
- **Aucun flux d'acceptation de chantier** — le récap dit "Accepte les nouveaux chantiers" mais un chantier
  assigné par le métreur apparaît directement dans "À faire" sans étape d'acceptation/refus. À clarifier :
  fonctionnalité manquante, ou le récap décrit-il juste l'affichage automatique en le formulant maladroitement ?
- **Aucun agenda par équipe** — seulement 2 onglets plats (À faire/Historique), aucun lien vers le Planner.
- Conforme : terminer/déclarer un problème, notification d'assignation avec date de pose, et le nouveau
  tableau de bord (pastille+popup+récents) de ce jour est cohérent.

### Dette design — le point "écrans en noir/vert"
Localisé précisément : **`lib/screens/measurement_form_screen.dart`** (le formulaire de métré du métreur)
a son propre thème sombre autonome, totalement déconnecté du reste de l'appli — constantes en tête de
fichier `_bg = Color(0xFF07090D)`, `_accent = Color(0xFF00E676) // Metreur Green` (commentaire explicite
dans le code), `_cardBg = Color(0xFF13161C)`, réutilisées ~16 fois + 7 `Colors.black*` bruts. **C'est cet
écran, pas `metreur_home_screen.dart`** (lui déjà propre, branché sur `AppColors` depuis un moment), qui est
responsable du "noir/vert" — à refondre en priorité vu que c'est l'écran le plus utilisé par le métreur.

Dette design par écran (couleurs codées en dur au lieu de `AppColors.*`, comptage approximatif) :
| Écran | Couleurs en dur | État |
|---|---|---|
| `measurement_form_screen.dart` | ~23 | Thème parallèle complet — priorité 1 |
| `poseurs_home_screen.dart` | ~41 | Le plus chargé, + couleur d'accent bleue au lieu du vert `AppColors.rolePoseur` qui lui est assigné |
| `admin_team_tab.dart` | ~13 | Partiellement migré |
| `admin_dashboard_tab.dart` | ~9 | Partiellement migré |
| `planner_screen.dart` | ~8 | Dette légère |
| `metreur_home_screen.dart` | ~8 (cosmétique, ombres/texte) | Déjà propre sur le fond |
| `admin_kpis_tab.dart` | 0 | Référence, entièrement aligné |

Rappel palette (`lib/core/theme/app_colors.dart`) : `primary` bleu, `success` vert, `warning` orange,
`danger` rouge, `purple`, `amber`. Couleurs de rôle : `roleCommercial`=bleu, `roleMetteur`=violet,
`rolePoseur`=vert, `roleAdmin`=orange. Rappel aussi : la refonte responsive (sidebar desktop, Kanban) du
06/08 n'a touché QUE l'écran Commercial (pilote) — Métreur/Poseur/Admin ont toujours leur nav bottom bar
faite main, pas de layout desktop dédié (déjà noté comme suite possible dans le journal du 06/08).

### Résumé — ce qu'il reste à faire, par priorité

1. **Corriger le bug de scope Commercial** (pastilles/popup/récents non filtrées à ses propres chantiers) —
   priorité absolue, c'est une fuite de données entre commerciaux, pas un simple écart de confort.
2. **Décisions produit à trancher avec Christophe** avant de coder plus (pas des bugs, des clarifications
   sur l'intention du récap) :
   - Le métreur doit-il pouvoir clôturer un chantier lui-même (contredit la Phase 5), ou seulement relancer ?
   - Le poseur doit-il avoir un vrai bouton Accepter/Refuser un chantier assigné ?
   - Le métreur doit-il avoir accès à la gestion d'équipe comme le commercial (actuellement exclu) ?
   - Faut-il un vrai agenda/planning par équipe pour Commercial et Poseur (aujourd'hui réservé à
     Admin+Métreur), ou les tabs/kanban de statuts actuels suffisent en pratique ?
3. **Dashboards à 6 catégories** au lieu des 3-4 actuelles (Admin/Commercial/Métreur) — travail de code ET
   de design, à combiner avec le point 4 pour ne pas refaire l'UI deux fois.
4. **Refonte design**, dans l'ordre de priorité suggéré :
   - `measurement_form_screen.dart` (le "noir/vert") — remplacer `_bg`/`_accent`/`_cardBg` par `AppColors`.
   - `poseurs_home_screen.dart` — le plus de couleurs en dur, + corriger l'identité couleur (vert, pas bleu).
   - `admin_team_tab.dart`, `admin_dashboard_tab.dart`, `planner_screen.dart` — dette légère à moyenne.
   - Généraliser le design system responsive (sidebar desktop, déjà construit le 06/08) aux 3 rôles restants,
     actuellement seul le Commercial en bénéficie.
5. Notification admin "nouveau chantier" — asymétrie push/in-app à corriger (petit bug, cf. ci-dessus).
6. **Tester en direct** — bloqué toute cette session (page blanche persistante dans Chrome, cause non
   identifiée). Christophe teste sur le Mac avec un simulateur ce week-end : sujet à reprendre ensemble à
   son retour, avec en plus le scénario de test `canPlaceOrders` resté en pause depuis le 06/08.

### Vérifications faites cette session (audit, pas de nouveau code)
Aucune ligne de code modifiée pendant l'audit lui-même (4 agents en lecture seule). `flutter analyze`
revérifié avant l'audit : 138 issues, 0 erreur (état inchangé depuis les 3 chantiers du matin).

### Git : tout commité et poussé sur `origin/main`
Le dépôt avait ~33 fichiers modifiés/nouveaux accumulés depuis le 05/08 soir (la refonte responsive du 06/08
n'avait jamais été commitée). Vérifié qu'aucun fichier sensible ne traînait (pas de clé de service, pas de
`.env`) avant de tout ajouter. Un seul commit regroupant refonte responsive (06/08) + 3 chantiers (07/08),
poussé sur `origin/main`.

---

## 🆕 Session 2026-08-07 — 3 chantiers du récap : restriction commande métreur, relances, popup+récents

### Chantier 1 — Restriction du droit "passer commande" pour le métreur
Le métreur pouvait jusqu'ici toujours passer commande (droit natif du rôle). Christophe a expliqué que dans
certaines entreprises seul le commercial/admin doit le faire. Décision de conception : réutiliser
`canPlaceOrders` (déjà additif pour un commercial délégué) en le rendant **tri-état** côté serveur plutôt que
créer un nouveau champ — absent = comportement du rôle inchangé, `true` = force l'autorisation (cas
commercial existant), `false` = force le refus même pour un rôle listé (nouveau cas métreur). Vérifié que
`firestore.rules` n'a besoin d'aucun changement (`.get('canPlaceOrders', false)` traite déjà absent et `false`
identiquement).
- `functions/index.js` (`transitionDevisStatus`) : logique `hasRole || hasDelegatedPermission` remplacée par
  un override tri-état.
- `lib/screens/admin_team_tab.dart` : bug corrigé au passage (`_EditPermissionsSheet._save()` écrivait
  `canPlaceOrders` inconditionnellement quel que soit le rôle édité — aurait pu retirer silencieusement le
  droit d'un métreur en éditant juste `canManageTeam`) ; nouveau toggle "Restreindre le droit de passer
  commande" visible uniquement pour les métreurs, badge "Commande restreinte" sur la carte membre.
- `lib/screens/metreur_home_screen.dart` : nouveau flux temps réel sur `users/{uid}` (l'écran ne lisait rien
  sur son propre utilisateur avant) ; bouton "Confirmer la commande" masqué (bandeau informatif à la place)
  aux 2 endroits concernés (devis simple et multi-lots) si le droit est retiré.

### Chantier 4 — Relances manuelles (Commercial→Métreur, Métreur→Poseurs)
Aucune infrastructure n'existait (le bouton "Relancer" visible côté commercial était un bug — même `onTap`
que "Voir détails", n'envoyait rien). 3 types définis avec Christophe : `metreur_non_accepte` et
`metreur_commande_attente` (commercial/admin → métreur), et **`cloture_manquante`** (métreur/admin → poseurs
assignés) — ce 3ᵉ type a été précisé en cours de session : ce n'est pas une histoire de "validation par
l'équipe de pose" comme le récap le suggérait littéralement, mais le cas réel où les poseurs terminent un
chantier en retard, enchaînent sur le suivant et oublient de faire la clôture dans l'appli plusieurs jours
après — le métreur les relance pour qu'ils clôturent "physiquement".
- **`functions/relanceConfig.js`** (nouveau) : table déclarative des 3 types (rôles autorisés, cible,
  statuts applicables, cooldown 15 min), sur le modèle de `TRANSITIONS` dans `devisWorkflow.js`.
- **`functions/index.js`** : nouvelle callable `sendRelance` (même squelette de vérifications que
  `transitionDevisStatus`) ; anti-spam via une nouvelle sous-collection immuable `{devis|lot}/relances`
  (même pattern que `statusHistory`) ; réutilise tel quel `notifyHelpers.js` (aucun changement à ce fichier).
- **`firestore.rules`** : bloc `relances/{relanceId}` ajouté aux niveaux devis et lot, calqué sur
  `statusHistory`.
- **`lib/services/devis_service.dart`** : nouvelle méthode `sendRelance()`.
- **`lib/screens/commercial/commercial_quote_list.dart`** : bug du bouton "Relancer"/"Rappel" corrigé (déclenche
  maintenant la vraie relance) ; nouveau bouton "Relancer →" sur les statuts À commander/Commande en cours
  **seulement si le commercial n'a pas `canPlaceOrders`** (sinon il a déjà "Commander →" — décidé avec
  Christophe).
- **`lib/screens/metreur_home_screen.dart`** : nouveau bouton "Relancer la clôture" sur les chantiers en
  statut `En pose` (les 2 endroits, devis simple et multi-lots).

### Chantiers 2+3 — Popup enrichi au clic sur une pastille + section "chantiers récemment ajoutés"
Aucune pastille n'avait de `onTap` sur aucun des 4 écrans avant cette session (contrairement à ce que le
récap supposait "déjà fait"). Stratégie DRY retenue : ne pas unifier les 4 composants de pastille
(`_StatCard` admin, `WiStat` commercial, `_StatChip` métreur, rien côté poseur — trop différents, refactor
disproportionné), mais mutualiser la popup et la logique de fusion "récents", qui sont de la vraie logique
métier.
- **Nouveaux composants partagés** : `lib/core/models/wi_devis_summary.dart` (DTO normalisé
  `WiDevisSummary`), `lib/core/widgets/wi_devis_list_modal.dart` (popup liste, réutilise
  `showWiAdaptiveModal` existant), `lib/core/utils/recent_chantiers.dart` (`mergeRecentChantiers` — union des
  2-3 plus récents par `createdAt` et de ceux mis à jour dans les 7 derniers jours, dédupliqués, plafonnés à
  6), `lib/core/widgets/wi_recent_chantiers_section.dart` (section "récents", distingue visuellement
  "Nouveau" vs "Mis à jour").
- **Admin** (`admin_dashboard_tab.dart`, preuve de concept) : `onTap` ajouté aux 4 `_StatCard`, section
  "Derniers chantiers" (simple `take(20)` par date de création) remplacée par la nouvelle section avec la
  logique de réapparition sur changement de statut.
- **Commercial** (`commercial_home_screen.dart`) : `onTap` ajouté à `WiStat`/`WiStatRow` (n'en avait aucun) ;
  nouvelle section récents ajoutée entre la barre de stats et la barre de recherche.
- **Métreur** (`metreur_home_screen.dart`) : `onTap` ajouté à `_StatChip` ; nouvelle section récents entre
  les pastilles et les onglets.
- **Poseur** (`poseurs_home_screen.dart`) : décidé avec Christophe même traitement que les 3 autres rôles
  malgré l'absence totale de pastille aujourd'hui (juste des onglets À faire/Historique) — nouvelle pastille
  "chantiers en cours" **net-new** ajoutée + section récents.
- **Modèles Dart** : `updatedAt` (et `createdAt` pour le poseur, qui ne l'avait pas non plus) ajoutés à
  `_QuoteItem`, `_MeasureCardData`, `_ChantierData` — lecture directe de champs déjà écrits côté serveur,
  aucune écriture supplémentaire. Pour le poseur, une unité issue d'un lot (Phase 3) approxime ces dates avec
  les valeurs devis-level (`lotsSummary` ne dénormalise pas de timestamp par lot).

### Vérifications faites cette session
- `npm run lint` (functions) + `node -c` sur `index.js`/`devisWorkflow.js`/`relanceConfig.js` : 0 erreur.
- `flutter analyze` après chaque étape puis en global : **0 erreur**, 138 issues (137 avant, +1 —
  uniquement une dépréciation `withOpacity` de plus, même famille que celles déjà tolérées partout ailleurs).
- `firebase deploy --only functions,firestore:rules --dry-run` : réussi **3 fois** au fil de la session
  (règles compilées, nouvelle callable `sendRelance` empaquetée correctement). Un 4ᵉ essai a échoué avec un
  timeout ("Cannot determine backend specification") pendant que le serveur `flutter run` tournait encore en
  arrière-plan — pure contention de ressources CPU sur ce PC, pas un vrai problème de code : le dry-run est
  repassé au vert immédiatement après avoir arrêté le serveur Flutter.

### ⚠️ Pas testé en direct dans Chrome cette session (bloqué, pas contourné)
Tentative de test visuel sur le workspace de test (comptes commercial/métreur/admin d'"Ambiance Alu" ou
"WorkIt Test CPO") : `flutter run -d web-server --web-port=8765` lancé normalement, mais la page est restée
**blanche indéfiniment** — reproduit après un `indexedDB.clear()` pour changer de compte (erreur possiblement
introduite par ce nettoyage), confirmé encore après fermeture de l'onglet fautif, ouverture d'un nouvel
onglet propre, ET redémarrage complet du serveur `flutter run` (`Stop-Process` + relance) : toujours blanc,
alors que tous les modules DDC se chargeaient avec succès (1000 requêtes réseau, statut 200) et que le
service de debug Dart VM se connectait normalement côté serveur. Cause exacte non identifiée. Décidé avec
Christophe (AskUserQuestion) de continuer le code sans ce test plutôt que de continuer à insister — donc
**le rendu visuel réel des 3 chantiers ci-dessus (surtout Chantier 2/3, le plus visuel) n'a jamais été
confirmé à l'écran**, seulement par compilation/relecture. Priorité pour la prochaine session avant tout
nouveau chantier.

### Reste à faire (prochaine session)
1. **Tester en direct** les 3 chantiers de cette session — priorité absolue avant de continuer, vu qu'aucun
   n'a été vérifié visuellement. Si le blocage Chrome/web-server se reproduit, essayer : un profil Chrome
   différent, `-d chrome` au lieu de `-d web-server` (malgré la limitation connue de fenêtre non pilotable en
   automatisation), ou simplement le test manuel de Christophe sur son poste.
2. Scénario de test suggéré pour Chantier 1 : admin restreint un métreur de test, vérifier la disparition du
   bouton "Confirmer la commande" aux 2 endroits, vérifier qu'un admin garde toujours le droit.
3. Scénario Chantier 4 : déclencher les 3 types de relance, vérifier réception (notif in-app + logs
   `firebase functions:log`), vérifier que le cooldown de 15 min bloque bien un second clic rapide avec un
   message clair.
4. Scénario Chantiers 2+3 : cliquer chaque pastille sur les 4 rôles → popup cohérente avec le compteur ;
   changer le statut d'un vieux chantier → vérifier qu'il réapparaît dans "Chantiers récemment ajoutés" avec
   le badge "Mis à jour".
5. Une fois testé et validé par Christophe : décider du déploiement (`firebase deploy --only
   functions,firestore:rules`) — rien n'est en prod pour l'instant, uniquement des dry-run.
6. Le test en pause de `canPlaceOrders` côté commercial (session du 06/08, scénario détaillé dans la section
   ci-dessous) reste aussi à boucler — peut être fait dans la même session de test que le point 1 ci-dessus.

---

## 🆕 Session 2026-08-06 (suite) — Refonte UI/UX responsive (design system + écran pilote
Commercial) **+ permission déléguée `canPlaceOrders`**, toutes deux **déployées** sur `workit-1daa1`. Test en
direct de `canPlaceOrders` commencé (workspace de test "WorkIt Test CPO" créé, bug App Check/ReCAPTCHA local
corrigé) mais **pas terminé** — mis en pause à la demande de Christophe, qui prépare un récapitulatif complet
du comportement attendu avant de continuer. **Lire ce récap en premier en reprenant.**

## 🆕 Session 2026-08-06 (suite) — Permission déléguée `canPlaceOrders`

En regardant l'écran Commercial redessiné (session du même jour, voir plus bas), Christophe a repéré un bouton
"Commander →" affiché côté Commercial sur les chantiers "À commander" — anormal, puisque c'est censé être le
métreur qui passe commande suite au métré. Audit du code avant d'agir : **pas de faille de sécurité** — le
bouton n'exécutait aucune action réelle (même `onTap` que "Voir détails"), et la Cloud Function
`transitionDevisStatus` vérifie déjà côté serveur que seuls `metreur`/`admin` peuvent déclencher cette
transition (`functions/devisWorkflow.js`, table `TRANSITIONS`). Juste un libellé trompeur. Décidé avec
Christophe (AskUserQuestion) : retirer ce bouton par défaut, et étendre le système de permissions déléguées
**déjà existant** pour "gérer l'équipe" (`canManageTeam`/`manageableRoles`, accordé individuellement par un
admin, vérifié côté serveur) à un nouveau droit équivalent pour "passer commande". Plan dans
`~/.claude/plans/partitioned-bouncing-lynx.md` (regénéré pour cette tâche, remplace le plan de la refonte UI).

### Implémenté (reproduit fidèlement le pattern `canManageTeam`)
- **`firestore.rules`** : nouveau champ `canPlaceOrders` sur `users/{uid}`, verrouillé en self-update (même
  ligne que `canManageTeam`/`manageableRoles`/`isAdmin`) — seul un admin du workspace peut le modifier.
- **`functions/devisWorkflow.js`** : les transitions `"À commander"`/`"Commande en cours"` → `"À planifier"`
  gagnent `allowPermission: "canPlaceOrders"` en plus de `roles: ["metreur", "admin"]` (OU, pas remplacement).
- **`functions/index.js:591`** : le check de rôle dans `transitionDevisStatus` généralisé (`hasRole ||
  hasDelegatedPermission`) — mécanisme réutilisable pour de futures permissions du même genre, pas câblé en dur
  sur `canPlaceOrders` uniquement.
- **`lib/screens/admin_team_tab.dart`** : `_EditPermissionsSheet` gagne un second toggle "Autoriser à passer
  commande", visible uniquement pour les membres de rôle `commercial` ; écriture Firestore directe (même
  mécanisme que `canManageTeam`, pas de nouvelle Cloud Function pour l'octroi) ; petit indicateur (icône
  camion) sur la carte membre quand actif.
- **`lib/screens/commercial/commercial_home_screen.dart`** : nouveau `_canPlaceOrders`, chargé en direct depuis
  Firestore au démarrage (lecture ponctuelle du doc `users/{uid}`, pas de cache SharedPreferences — même
  pattern que `canManageTeam` dans `settings_screen.dart`).
- **`lib/screens/commercial/commercial_quote_list.dart`** : `_quoteCardFor` n'affiche plus de CTA "Commander"
  par défaut sur les statuts À commander/Commande en cours (seul "Voir détails" reste, même traitement que les
  chantiers terminés) ; si `canPlaceOrders == true`, le CTA réapparaît et déclenche la vraie transition
  (nouvelle fonction `_placeOrder`, même appel `DevisService.updateStatus(..., newStatus: 'À planifier')` que
  `_confirmOrderLot` côté métreur — transition devis-level sans `lotId`, cohérent avec le fait que l'écran
  Commercial n'a jamais été rendu lot-aware, Phases 3-5).

### Vérifications faites cette session
- `npm run lint` (functions) + `node -c index.js`/`devisWorkflow.js` : 0 erreur.
- `firebase deploy --only firestore:rules --dry-run` : règles compilées avec succès.
- `flutter analyze` : 0 erreur, 137 issues (inchangé).
- **Pas testé en direct** (nécessite un déploiement functions+rules, pas fait cette session — décision à
  prendre avec Christophe, comme pour les Phases précédentes).

### ✅ Déployé (à la demande explicite de Christophe)
`firebase deploy --only functions,firestore:rules` exécuté avec succès sur `workit-1daa1` : règles publiées,
8 Cloud Functions mises à jour (`transitionDevisStatus`, `provisionAccounts` notamment — celles qui portent
`canPlaceOrders`). `canPlaceOrders` est donc **actif en prod** dès maintenant (mais personne ne l'a tant qu'un
admin ne l'accorde pas explicitement — comportement par défaut inchangé).

### 🧪 Test en direct — en cours, mis en pause par Christophe (recap à venir)

Christophe n'a pas de compte admin pour "Ambiance Alu" (c'est son compte perso, jamais utilisé par Claude) — un
nouveau workspace de test **"WorkIt Test CPO"** a donc été créé de zéro via le flux d'inscription normal de
l'app (`onboarding_screen.dart`), pour disposer d'un admin de test. **4 comptes créés, mdp `Workit2026!` pour
tous :**
- Admin : `admin.cpo.test@workit-test.fr` (Admin TestCPO)
- Commercial : `commercial.cpo.test@workit-test.fr` (Corinne Commande)
- Métreur : `metreur.cpo.test@workit-test.fr` (Marc Metreur)
- Poseur : `poseur.cpo.test@workit-test.fr` (Léo Poseur) — créé mais pas encore utilisé dans les tests

**Bug d'infra corrigé au passage (`web/index.html`)** : App Check était configuré avec
`ReCaptchaV3Provider('debug')` côté web dans `lib/main.dart` — 'debug' traité comme une clé de site reCAPTCHA
invalide, d'où des erreurs `AppCheck: ReCAPTCHA error` récurrentes bloquant certaines actions (création de
compte, changement de mot de passe) sur `localhost`. Corrigé en injectant le vrai mécanisme de debug web
(`self.FIREBASE_APPCHECK_DEBUG_TOKEN = true`, strictement limité à `localhost`/`127.0.0.1`, sans effet sur un
domaine réel). Le jeton de debug généré (`fa4c267a-cd38-4995-b54e-43d1832cb9f6`) a été enregistré par
Christophe dans la console Firebase (App Check → Manage debug tokens) — **ce token restera valable pour les
prochaines sessions**, plus besoin de reconfigurer ça.

**Vérifié en direct avec succès :**
- Comportement par défaut confirmé sur **deux workspaces** ("Ambiance Alu" avec `commercial@workit-test.fr`, et
  "WorkIt Test CPO" avec Corinne) : le bouton "Commander" n'apparaît plus, seul "Voir détails" reste sur les
  chantiers À commander.
- Parcours métreur complet fonctionnel : création d'un devis réel côté Corinne ("##8705 - Testeur CPO") →
  accepté, métré saisi et validé par Marc (Metteur en œuvre) → **mais le bouton "Confirmer la commande" du
  métreur fait la transition À commander → À planifier **en un seul clic**, sans étape intermédiaire visible**
  — le devis test est donc passé directement à "À planifier" avant que le test du point de vue Commercial (à
  l'étape "À commander" précisément) ait pu être fait.

**Reste à faire pour boucler ce test** : créer un 2e devis test, le faire accepter + métrer par Marc, **s'arrêter
juste après "Métré terminé" sans cliquer "Confirmer la commande"** (le devis reste alors "À commander"), puis
basculer sur Corinne : (1) sans droit → confirmer que "Commander" reste absent ; (2) admin active le toggle
"Autoriser à passer commande" sur la fiche de Corinne (icône bouclier, `admin_team_tab.dart`) ; (3) recharger
côté Corinne → le bouton "Commander" doit apparaître et fonctionner réellement (transition vers "À planifier").

### 🐛 Bug pré-existant découvert (sans rapport avec cette session, pas creusé)
Le flux "Sécuriser votre compte" (`sign_in_screen.dart`, première connexion d'un compte fraîchement provisionné
par `provisionAccounts`) a intermittemment renvoyé `[cloud_firestore/permission-denied] Missing or insufficient
permissions` lors de l'écriture `.set(..., merge:true)` sur `users/{uid}` (prénom/nom/téléphone/rôle/
mustChangePassword). Reproduit sur le compte métreur de test, pas systématiquement (a fini par passer après
plusieurs tentatives). Cause non identifiée — possible piste : le champ `role` réécrit avec `_role ??
widget.currentRole` pourrait diverger du `role` réel stocké côté Firestore dans certains cas. **Non corrigé,
hors scope de cette session**, mais à surveiller si Christophe ou un nouveau membre d'équipe rencontre un blocage
similaire en se connectant pour la première fois.

### ⏸️ Pause demandée par Christophe
Christophe prépare de son côté un récapitulatif complet du comportement attendu (métreur/commercial/admin,
droits, notifications, à quel moment quoi se passe) pour cadrer la suite avant de continuer. **Reprendre en
lisant ce récap en premier** s'il est présent quelque part (à chercher dans les fichiers du projet ou demander
à Christophe s'il ne l'a pas encore collé dans la conversation).

### Reste à faire (prochaine session)
1. **Lire le récapitulatif de Christophe en premier** (voir ci-dessus).
2. Terminer le test en direct de `canPlaceOrders` (scénario détaillé ci-dessus) dans le workspace "WorkIt Test
   CPO".
3. Optionnel : investiguer le bug `permission-denied` sur "Sécuriser votre compte" si Christophe le recroise.

---

## 🆕 Session 2026-08-06 — Refonte UI/UX responsive (web/desktop), écran pilote Commercial

Christophe veut un vrai design professionnel 2026 pour la version web de WorkIt (Chrome), pensé pour un usage
mixte mobile/tablette (terrain) et desktop (bureau) — le code Flutter est resté mobile-only jusqu'ici (aucun
breakpoint, aucune nav desktop). Décisions validées avec lui avant codage (AskUserQuestion) : fondations +
écran pilote (pas généralisation immédiate), garder la palette de couleurs existante (déjà proche de son thème
Adobe Color perso), vrai layout desktop dédié (sidebar, pas juste du responsive simple). Style visuel inspiré de
captures que Christophe a fournies de **Revel'Home** et **Krafteo** — deux logiciels concurrents qu'il utilise
professionnellement pour le même métier (devis/chantiers menuiserie) : sidebar repliable, top bar avec
recherche, et surtout une **vue pipeline en colonnes (Kanban)** qui correspond exactement aux 7 statuts déjà
gérés par WorkIt. Plan détaillé dans `~/.claude/plans/partitioned-bouncing-lynx.md`.

### Étape A — Fondations design system (bénéficient à tous les rôles, pas seulement Commercial)
- **`lib/core/responsive/`** (nouveau) : `wi_breakpoints.dart` (`WiScreenSize` compact<600/medium<900/expanded<1200/large`) + `responsive_context.dart` (extension `BuildContext` : `.isMobile`/`.isDesktop`/`.showSidebar`/`.isSidebarExpanded`), basés sur la largeur d'écran (`MediaQuery`, jamais `kIsWeb`) — un même code sert le web ET le mobile natif.
- **Police Inter** bundlée en asset local (PAS `google_fonts`, pour éviter tout appel réseau au runtime — poseurs en connexion terrain intermittente) : téléchargée via l'API JSON de Google Fonts (`fonts.google.com/download/list?family=Inter`) en 6 graisses (400→900), dans `assets/fonts/Inter/`, déclarée dans `pubspec.yaml`, activée via `fontFamily: 'Inter'` dans `app_theme.dart` (le `textTheme` existant n'a pas changé).
- **`lib/core/theme/app_layout_tokens.dart`** (nouveau) : tokens desktop (`maxContentWidth`, `sidebarWidthExpanded/Collapsed`, `masterPaneWidth`, `dialogWidthForm`, `kanbanColumnWidth`). Extensions additives dans `app_colors.dart` (sidebar/hover/focus) et `app_theme.dart` (`NavigationRailThemeData`).
- **`lib/core/widgets/shell/wi_app_shell.dart` + `wi_sidebar_nav.dart`** (nouveaux) : shell responsive réutilisable par les 4 rôles à terme — bascule automatiquement bottom nav (mobile/tablette) / sidebar réduite 72px (petit desktop) / sidebar étendue 240px (grand écran), style inspiré Revel'Home (logo, items icône+label, footer workspace/utilisateur). `WiBottomNav` passé de 56 à 64px de hauteur (aligné sur ce que Commercial/Métreur faisaient déjà en pratique côté mobile — meilleure cible tactile terrain).
- **Nouveaux composants** `lib/core/widgets/` : `wi_master_detail_layout.dart` (liste+détail desktop), `wi_kanban_board.dart` (board en colonnes, **lecture seule** — pas de drag-and-drop pour ne pas contourner les règles serveur de transition de statut), `wi_responsive_dialog.dart` (`showWiAdaptiveModal` : dialog centré desktop / plein écran mobile).
- `WiDevisCard` (existant) étendu : `onTap` (carte entière cliquable), `trailingBadge` (override du badge par défaut), `headerActions` (icônes éditer/supprimer). `WiCtaButton` gagne `fullWidth`, `WiStatRow` gagne `compactOnDesktop`.

### Étape B — Écran pilote : Commercial (`lib/screens/commercial_home_screen.dart` → `lib/screens/commercial/`)
- **Scindé en 5 fichiers** (4027 → ~4036 lignes réparties) via le mécanisme Dart `part`/`part of` (pas de renommage des classes privées `_QuoteItem`/`_QuoteCard`/etc. — elles restent mutuellement visibles comme dans un seul fichier) : `commercial_home_screen.dart`, `commercial_models.dart`, `commercial_quote_list.dart`, `commercial_quote_wizard.dart`, `commercial_chantier_detail.dart`. Import mis à jour dans `auth_navigation_service.dart`.
- **Nav** : `WiAppShell` remplace `_buildBottomNav()`/`_NavItem` fait main. Bug de doublon préexistant corrigé au passage ("Accueil" et "Devis" pointaient vers le même contenu) → fusionnés en un seul item **Devis** (+ Agenda, Réglages).
- **Desktop (≥900px)** : la zone "Devis" bascule d'onglets+listes vers un **Kanban** (`WiKanbanBoard`, 6 colonnes de statuts, cartes `WiDevisCard`) + **panneau détail** à droite au clic sur une carte (au lieu du bottom sheet mobile). La barre de pills TabBar est masquée sur desktop (redondante avec le Kanban). `_ChantierDetailSheet` scindé en `_ChantierDetailBody` (contenu pur, réutilisé) + wrapper mobile (bottom sheet inchangé) + nouveau `_ChantierDetailPanel` (desktop, bouton fermer).
- **Mobile/tablette (<900px) : strictement inchangé** — mêmes tabs, mêmes listes, même bottom sheet.
- **Wizard "Nouveau devis"** : desktop → `showWiAdaptiveModal` (dialog centré 640px) ; mobile → `Navigator.push` plein écran inchangé. Seul le chrome externe est conditionnel, la logique interne (steps, sauvegarde Firestore/Storage) n'a pas bougé.
- **2 bugs découverts et corrigés en testant en direct dans Chrome** (précieux rappel de toujours tester après ce genre de refonte) :
  1. Le panneau détail s'affichait par défaut au chargement (un item de démo avec `id == null` matchait accidentellement `_selectedQuoteId == null` lors de la recherche par id) → recherche désormais gardée par `if (_selectedQuoteId != null)`.
  2. Les items de démo (sans `id` Firestore) n'étaient pas sélectionnables dans le Kanban → clé de sélection basée sur `item.id ?? item.number` (`number` toujours renseigné et unique) au lieu de `item.id` seul.
  3. Colonnes "En attente"/"Devis prog." du Kanban n'incluaient pas les items de démo (contrairement aux 4 autres colonnes et aux listes mobiles) → fusion démo ajoutée pour cohérence avec le reste de l'écran.

### Vérifications faites cette session
- `flutter analyze` après chaque étape : **0 erreur** tout du long, 144→137 issues (baisse, nettoyage de code mort au passage : `_QuoteCard`, `_StatCard`, `_NavItem` supprimés au profit des composants du design system).
- **Testé en direct dans Chrome** (extension Claude for Chrome, `flutter run -d web-server --web-port=8765`) : connexion `commercial@workit-test.fr`, workspace "Ambiance Alu" — sidebar desktop (réduite/étendue), Kanban (6 colonnes, comptages cohérents avec les stats), sélection de carte → panneau détail → fermeture, wizard "Nouveau devis" en dialog desktop (5 étapes visibles). **Vue mobile non re-testée en direct cette session** : le redimensionnement de fenêtre via l'automatisation Chrome n'a pas fonctionné de façon fiable (la fenêtre ne se redimensionnait pas visuellement malgré des appels `resize_window` réussis) — la garantie de non-régression mobile vient de la relecture de code (les branches mobile de `WiAppShell`/`_AddQuoteScreen`/etc. sont either inchangées, either sur un `if (!context.isDesktop)` qui reproduit exactement l'ancien code), pas d'un test visuel réel.

### ⚠️ Pas fait cette session
- **Métreur, Poseur, Admin non touchés** — scope volontairement limité à l'écran pilote Commercial pour validation avant généralisation (décidé avec Christophe). Ces 3 rôles ont toujours leur nav bottom bar/tabs faite main, pas de layout desktop.
- **Pas de vrai test mobile en direct** dans cette session (voir ci-dessus) — à faire en priorité en reprenant, idéalement sur le Mac ou un vrai téléphone/tablette plutôt que via l'automatisation Chrome (qui a déjà posé problème lors d'une session précédente le 05/08).
- Pas de commit/push — travail local uniquement.

### Reste à faire (prochaine session)
1. **Christophe regarde lui-même l'écran Commercial** (desktop large, ouvert dans Chrome) pour repérer incohérences/oublis — c'est la demande initiale de cette session.
2. Tester réellement le rendu mobile (vrai téléphone/tablette ou simulateur) pour confirmer l'absence de régression visuelle — pas fait en direct cette session.
3. Si validé : généraliser le pattern (`WiAppShell`, Kanban si pertinent, wizard adaptatif) aux 3 autres rôles (Métreur, Poseur, Admin) — chacun a sa propre nav dupliquée à remplacer.
4. Décider si la vue Kanban doit aussi couvrir le statut "Problème"/SAV comme colonne séparée (actuellement fusionné dans "Terminés").
5. Toujours en attente depuis les sessions précédentes : test en direct des Phases 3-6 (multi-lots, Planner v2, expérience terrain, KPIs) et Phase 7 (validation des 12 métiers).

---

## 📍 État actuel du projet — À LIRE EN PREMIER avant de reprendre

### ⚠️ Déploiement du 05/08 (suite) — backend en prod, app cliente pas encore revérifiée
Deux passes de déploiement : `firebase deploy --only functions,firestore:rules` puis `firebase deploy` complet
(sans restriction, pour couvrir aussi `firestore.indexes.json`) — la seconde a confirmé que tout était déjà à
jour (8/8 fonctions "Skipped (No changes detected)", règles déjà à jour, index déployés). 3 nouvelles Cloud
Functions créées (`setLotDependencies`, `updateLotPlanningFields`, `logTimeEntry`), 5 mises à jour
(`transitionDevisStatus`, `provisionAccounts`, `analyzeDevis`, `onDevisStatusChange`,
`onChantierMessageCreated`). **Seul le backend a été déployé — pas de build/déploiement de l'app Flutter
elle-même** (pas d'hébergement configuré dans `firebase.json` de toute façon, seulement Functions/Firestore).
Le nouveau moteur de transitions (garde-fou lots, `À clôturer` devenu pivot, statut SAV) est désormais actif en
prod, mais sans conséquence puisque seuls des comptes de test l'utilisent pour l'instant — à garder en tête
comme point de vigilance le jour où de vrais utilisateurs seront en jeu. Avertissements non bloquants du
déploiement : runtime Node.js 20 déprécié (décommissionné 2026-10-30, à migrer avant cette date) et
`firebase-functions` en version obsolète (`npm install --save firebase-functions@latest` recommandé) — aucun
des deux n'empêche le fonctionnement actuel.

### Où en est chaque phase de la roadmap (`roadmap_plateforme_multimetier.md`, 8 phases : 0 à 7)
| Phase | Statut |
|---|---|
| 0 — Sécurité et comptes | ✅ Terminée et déployée en prod |
| 1 — Moteur de workflow générique + historique | ✅ Terminée, déployée, testée en direct |
| 2 — Dictionnaire métier étendu + moteur de documents | ✅ Contenu sourcé fait pour les 12 métiers, déployé. ⚠️ Un seul métier (menuiserie, pilote) a été testé en direct de bout en bout — les 11 autres sont codés/analyzés mais **jamais vérifiés dans l'app réelle** (tentative bloquée le 05/08, voir plus bas). 6 des 9 modèles de documents de la roadmap restent à créer (le moteur les supporte déjà). |
| 3 — Chantiers multi-lots | 🟢 Codée le 05/08 (`2925da9`), **déployée en prod** ce 05/08 (suite). **Pas encore testée en direct.** |
| 4 — Planner v2 | 🟢 Codée le 05/08 (suite), **déployée en prod**. **Pas encore testée en direct.** |
| 5 — Expérience terrain | 🟢 Codée le 05/08 (suite), **déployée en prod**. **Pas encore testée en direct.** |
| 6 — Tableau de bord dirigeant (KPIs) | 🟢 Codée le 05/08 (suite), **déployée en prod**. `stats/kpis` sera vide tant qu'aucune transition n'aura eu lieu après ce déploiement. **Pas encore testée en direct.** |
| 7 — Validation des 12 métiers & lancement | Pas commencée (phase produit, pas dev). |

**Toute la chaîne technique (Phases 0 à 6) est maintenant codée ET déployée.** Il ne reste que la Phase 7
(validation métier, pas du dev). **Plan pour la suite, décidé avec Christophe le 05/08 (soir)** : test en direct
sur le Mac ce soir, Phase 7 attaquée demain.

### Ce qui doit être fait AVANT ou PENDANT la prochaine session
1. **Christophe teste en direct sur le Mac ce soir (05/08)** : cycle complet devis multi-métier → métré (lots
   créés) → Planner (glisser-déposer par lot, dépendances, congés) → poseur (rapport + pointage) → commercial
   (Valider/Retourner/SAV) → onglet KPIs admin (vérifier que les compteurs se peuplent). Scénarios détaillés
   dans les sections de session dédiées plus bas (une par phase). **Lire le résultat de ces tests en tout
   premier en reprenant** (probablement noté par Christophe ou une session Mac).
2. **Phase 7 prévue demain** (06/08) — lire `roadmap_plateforme_multimetier.md` (détail Phase 7 : matrice de
   maturité par métier, tests terrain avec un pro référent + 3-5 dossiers réels par métier, gate de lancement)
   avant de commencer.
3. Le test en direct des 11 métiers Phase 2 reste aussi à faire (sans automatisation Chrome, bug rencontré le
   05/08).
4. `admin_dashboard_tab.dart` n'a toujours pas les boutons d'action Valider/Retourner/SAV (Phase 5, scope
   assumé) — à étendre si Christophe veut que les admins valident aussi, pas seulement les commerciaux.
5. Migrer le runtime Cloud Functions Node.js 20 avant le 2026-10-30 (décommissionnement annoncé par Firebase).

### Repères utiles pour reprendre vite
- Plan détaillé de la Phase 6 (approuvé) : `~/.claude/plans/wiggly-crafting-stroustrup.md` (réutilisé pour les
  Phases 4, 5 et 6 successivement — ne contient que le plan de la Phase 6 actuellement). Plan Phase 3 :
  `~/.claude/plans/swift-snacking-dove.md`.
- Environnement de test : comptes `commercial@workit-test.fr` / `metreur@workit-test.fr` / `poseur@workit-test.fr`
  (mdp `Workit2026!`), workspace "Ambiance Alu" (id `1Tz93YBgwnrd08ORABaZ`).
- Sur ce PC Windows : `flutter run -d web-server --web-port=8765 --web-hostname=localhost` puis piloter depuis
  l'extension Claude for Chrome (PAS `-d chrome`, fenêtre isolée non pilotable) — mais l'automatisation Chrome
  s'est montrée peu fiable le 05/08, Christophe a préféré basculer sur le Mac en pilotage manuel pour tester.
- `firebase login` refait sur ce poste le 05/08 (suite) — session CLI Firebase à nouveau valide, dry-run des
  règles utilisable directement sans reconnexion.

---

## 🆕 Session 2026-08-05 (suite) — Phase 6 : tableau de bord dirigeant (KPIs)

Christophe a demandé d'attaquer la Phase 6, dernière phase technique avant la Phase 7 (validation métier).
Contrairement aux Phases 4 et 5, pas de limitation "lot-awareness" à lever ici — la Phase 6 est purement
additive (agrégation de ce que `transitionDevisStatus` sait déjà). Passage par un plan avant codage vu la
taille (nouveau sous-système d'agrégation + nouvel écran), voir `~/.claude/plans/wiggly-crafting-stroustrup.md`.

### Décision de conception clé
Plutôt qu'un nouveau trigger Firestore sur `statusHistory` (roadmap le suggérait), l'agrégation se fait
**directement dans `transitionDevisStatus`**, en best-effort après le commit de la transaction (même pattern
que `notifyTransition`, déjà en place) : la fonction connaît déjà `fromStatus`/`newStatus`/`extraFields`, et
`current.updatedAt` (déjà lu dans la transaction) donne le délai de la transition sans lecture supplémentaire.
Un seul document `workspaces/{id}/stats/kpis` est mis à jour par `FieldValue.increment()` — même pattern que
`workspaces/{id}/usage/aiAnalysis` (quota IA, Phase 0), déjà en lecture seule côté client.

### Implémenté
- **`functions/kpiStats.js`** (nouveau) : `recordKpiTransition()` — incréments groupés sur `stats/kpis` :
  compteur+durée totale par paire de transition (`transitions.{from}__{to}`), clôtures au premier passage vs
  après retour, taux de paiement à la clôture, compteur SAV, causes de non-conformité (Phase 5).
- **`functions/index.js`** : `transitionDevisStatus` calcule `delayMs` (`now - current.updatedAt`) et lit
  `current.returnCount` avant d'écrire ; incrémente `returnCount` sur le devis/lot à chaque retour au poseur
  (`À clôturer → En pose`) — relu tel quel à la prochaine clôture pour savoir si elle vient après un retour ;
  appelle `recordKpiTransition` en best-effort après le commit, à côté de `notifyTransition`.
- **`firestore.rules`** : nouvelle sous-collection `stats/{statsId}`, calquée exactement sur `usage/` (Phase 0) —
  lecture membres du workspace, écriture serveur uniquement.
- **`lib/screens/admin_kpis_tab.dart`** (nouveau) : délais moyens par transition (triés par fréquence), taux de
  clôture au premier passage / taux de SAV / taux de paiement (barres de progression simples, pas de nouvelle
  dépendance de graphiques — aucune lib de charts dans le projet), causes de non-conformité (barres
  proportionnelles), chantiers bloqués depuis plus de 7 jours et charge par équipe aujourd'hui — ces deux
  derniers calculés en direct (comme `AdminDashboardTab` le fait déjà pour ses propres compteurs) plutôt
  qu'agrégés, car ils dépendent du temps qui passe et non d'une écriture.
- **`lib/screens/admin_home_screen.dart`** : 5ᵉ onglet "KPIs" (`TabController(length: 5)`, tabs rendus
  `isScrollable` pour éviter le débordement).

### Choix de scope assumé
Pas de ventilation "performance par métier / équipe / agence" (la roadmap conditionne elle-même l'agence à "si
ajoutée plus tard") — resté au niveau global du workspace pour tenir la taille "M" annoncée par la roadmap.
Documenté comme suite possible plutôt que construit cette session.

### Vérifications faites cette session
- `npm run lint` (functions) : 0 erreur. `node -c index.js`/`node -c kpiStats.js` : syntaxe validée.
- `flutter analyze` : 0 erreur, 144 issues (143 avant, +1 — une seule dépréciation `withOpacity` supplémentaire,
  même famille que celles déjà tolérées ailleurs).
- `firebase deploy --only firestore:rules --dry-run` : règles compilées avec succès (session Firebase
  ré-authentifiée par Christophe plus tôt dans la session).

### ⚠️ Pas fait cette session
- **Pas déployé, pas testé en direct** — comme les Phases 3 à 5, en attente d'un déploiement groupé décidé avec
  Christophe. `stats/kpis` ne contiendra aucune donnée réelle tant que des transitions n'auront pas eu lieu en
  prod après déploiement — impossible à tester avant.

### Reste à faire (prochaine session)
1. **Décider du déploiement groupé Phases 3 à 6** — désormais le vrai point de blocage du projet (voir en tête
   de journal).
2. Tester en direct sur le Mac : dérouler un cycle complet devis→clôture pour peupler `stats/kpis`, vérifier
   que l'onglet KPIs affiche des délais/taux cohérents avec l'historique réel.
3. Phase 7 (validation des 12 métiers & lancement) — phase produit, pas de dev à proprement parler : matrice de
   maturité par métier, tests terrain avec un pro référent + dossiers réels par métier.

---

## 🆕 Session 2026-08-05 (suite) — Phase 5 : expérience terrain (temps passé, non-conformité, circuit de validation)

Christophe a demandé d'attaquer la Phase 5. Comme pour la Phase 4, question posée avant de coder (AskUserQuestion) :
l'écran poseur (`poseurs_home_screen.dart`) n'avait toujours aucune notion de lot — dernière limitation assumée de
la Phase 3, jamais levée — et la Phase 5 modifie précisément cet écran. **Christophe a choisi de lever cette
limitation cette session aussi.** Passage par un plan détaillé avant codage (voir
`~/.claude/plans/wiggly-crafting-stroustrup.md`).

### Constat fait en explorant avant de planifier : le circuit de validation n'existait pas du tout
`_valider()`/`_signaler()` (poseur) écrivaient directement `Terminé`/`À clôturer`, déjà traités comme définitifs
partout — `À clôturer` n'avait aucune transition sortante, une impasse. Il a fallu redéfinir son sens : **`À
clôturer` devient le statut pivot "rapport soumis, en attente de validation"** (plus un état terminal), et un
nouveau statut **`SAV`** est introduit comme second état terminal à côté de `Terminé`. Comme rien n'est déployé,
ce changement de sémantique ne casse aucune donnée réelle.

### Implémenté
- **`functions/devisWorkflow.js`** : `En pose` unifie ses deux anciennes sorties poseur (`→Terminé`/`→À clôturer`)
  en une seule `→ À clôturer` (`rapportType: 'fin'|'probleme'`) ; nouvelle entrée `À clôturer` avec 3 transitions
  responsable (`commercial`/`admin`) — `→Terminé` (valider), `→En pose` (retourner, `retourCommentaire`), `→SAV`
  (`savReason`). `LOT_STATUS_ORDER`/`LOT_TERMINAL_STATUSES` mis à jour (À clôturer n'est plus terminal, SAV
  ajouté) ; `aggregateDevisStatus` bascule sur SAV au lieu de À clôturer pour le cas "tous les lots terminaux" ;
  `notifyTransition` : nouveaux cas À clôturer (rapport à valider, cause incluse si problème) et SAV. Nouvelle
  constante exportée `NON_CONFORMITE_CAUSES` (10 valeurs fermées de la roadmap).
- **`functions/index.js`** : validation serveur de `rapportProbleme.cause` (doit appartenir à la liste fermée) ;
  nouvelle Cloud Function callable `logTimeEntry` (rôle poseur/admin + assignation, écrit
  `devis/{id}/timeEntries` ou `devis/{id}/lots/{lotId}/timeEntries`) ; `lotsSummary` dénormalisée gagne
  `retourCommentaire` (sinon l'écran poseur, qui ne lit que le devis, ne verrait jamais le retour du responsable
  sur un lot sans lecture supplémentaire).
- **`firestore.rules`** : nouvelle sous-collection `timeEntries` (devis et lots) — lecture membres workspace,
  écriture serveur uniquement (comme `statusHistory`).
- **`lib/services/devis_service.dart`** : nouvelle méthode `logTimeEntry()`.
- **`lib/screens/poseurs_home_screen.dart`** (le plus gros morceau) : `_ChantierData` gagne `expandForPoseur()` —
  un devis sans lot produit une unité (inchangé), un devis avec lots produit une unité par lot où CE poseur
  figure dans `poseurIds` du lot (pas les autres lots du même devis) ; `_valider()`/`_signaler()` passent par
  `lotId` + `rapportType` vers `À clôturer` ; sheet "Signaler un problème" gagne un sélecteur de cause (liste
  fermée, obligatoire) et le champ texte devient un commentaire optionnel ; nouvelle section "Pointage"
  (`_PointageSection`) sur les cartes actives — 6 boutons horodatés, stream `timeEntries` en direct, récap
  trajet/travail du jour calculé côté client ; bandeau "Retourné par le responsable" si `retourCommentaire`
  présent (sur la carte et en tête de la fiche détail).
- **`lib/screens/commercial_home_screen.dart`** (changement ciblé) : `_QuoteItem` gagne `lotsSummary` ;
  `_showChantierDetail`/`_ChantierDetailSheet` gagnent `workspaceId` (thread à travers 5 listes : NewQuotes/
  Measuring/Scheduled/Validated×4/AllItems) ; nouveau `_ValidationBlock` — un bloc par lot en attente (ou un bloc
  devis-level si pas de lots), lit le rapport directement sur le lot/devis (pas dénormalisé dans lotsSummary,
  lecture à l'ouverture), 3 boutons Valider/Retourner (avec commentaire)/Créer un SAV (avec motif).

### 🐛 Bugs de cohérence trouvés et corrigés en propageant le nouveau statut SAV
En cherchant les autres endroits qui connaissaient l'ancien sens de `À clôturer` (terminal), plusieurs listes de
statuts figées auraient silencieusement mal classé les chantiers `SAV` :
- `planner_screen.dart` : `_kLotTerminalStatuses` (miroir Dart de `LOT_TERMINAL_STATUSES`) toujours à l'ancienne
  valeur — corrigé, sinon les badges de dépendance du Planner (Phase 4) auraient affiché "bloqué" indéfiniment
  pour un lot en réalité débloqué (SAV).
- `metreur_home_screen.dart` : même bug dans `_blockingDependencyLabel` (dépendances entre lots, Phase 3) ; un
  chantier `SAV` tombait aussi dans le bucket "nouvelles demandes" au lieu de "à clôturer" (`_onDevisSnapshot`,
  `else` catch-all).
- `commercial_home_screen.dart` : les chantiers `SAV` étaient absents du filtre "Terminés" (2 occurrences) —
  invisibles dans les onglets tabulés (seulement visibles via "Toutes").
- `admin_dashboard_tab.dart` : les chantiers `SAV` étaient absents du compteur "Terminés" du tableau de bord —
  silencieusement exclus des stats.

### Choix de scope assumé
**Les boutons d'action de validation (Valider/Retourner/Créer un SAV) n'ont été ajoutés qu'à
`commercial_home_screen.dart`**, pas à `admin_dashboard_tab.dart` (fiche détail séparée, pas de code partagé) —
même type de réduction de scope que pour la Phase 3/4, assumée pour ne pas construire un 4ᵉ écran lot-aware dans
la même session. `admin_dashboard_tab.dart` a quand même été corrigé pour ne plus perdre les chantiers SAV de ses
compteurs (bug de cohérence ci-dessus), mais reste en lecture seule sur la validation.

### Vérifications faites cette session
- `npm run lint` (functions) : 0 erreur. `node -c index.js`/`node -c devisWorkflow.js` : syntaxe validée.
- `flutter analyze` : 0 erreur, 143 issues (138 avant, +5 nettes — uniquement des dépréciations `withOpacity`,
  même famille que celles déjà tolérées ailleurs dans le projet).
- `firebase deploy --only firestore:rules --dry-run` : d'abord échoué (authentification CLI expirée sur ce
  poste), contourné par une vérification manuelle de la syntaxe des blocs ajoutés (accolades équilibrées, même
  structure que les blocs `statusHistory` existants) — puis **`firebase login` refait par Christophe et
  dry-run relancé avec succès** (`cloud.firestore: rules file firestore.rules compiled successfully`),
  confirmant que les nouveaux blocs `timeEntries` compilent correctement.

### ⚠️ Pas fait cette session (volontairement, cohérent avec les Phases 3 et 4)
- **Pas déployé** — backend Phases 3+4+5 jamais déployé sur `workit-1daa1`.
- **Pas testé en direct** — test réel prévu sur le Mac. Scénario suggéré : sur un devis multi-lots déjà métré,
  côté poseur soumettre un rapport fin propre sur un lot (vérifier le pointage : Départ dépôt → Arrivée →
  Début → Fin, collaborateurs, récap trajet/travail affiché) puis un rapport problème sur un autre lot (cause
  obligatoire + commentaire optionnel) ; côté commercial, ouvrir le détail du chantier et vérifier que les 2
  blocs de validation apparaissent (un par lot), tester les 3 boutons (Valider, Retourner avec commentaire —
  vérifier le bandeau côté poseur —, Créer un SAV avec motif) ; vérifier que le badge de dépendance du Planner
  (Phase 4) et de l'écran métreur (Phase 3) traitent bien `SAV` comme terminal pour débloquer les lots
  dépendants.

### Reste à faire (prochaine session)
1. Déployer Phases 3+4+5 ensemble une fois Christophe d'accord, puis `firebase login` à refaire sur ce poste si
   on reprend ici (session expirée, empêché le dry-run des règles cette fois).
2. Tester en direct le scénario ci-dessus, sur le Mac.
3. Étendre les boutons de validation à `admin_dashboard_tab.dart` si Christophe veut que les admins valident
   aussi (scope cut assumé cette session).
4. Phase 6 (tableau de bord KPIs) — pas commencée, dépend de `statusHistory` (Phase 1) et du temps/non-conformité
   (Phase 5, maintenant codée).

---

## 🆕 Session 2026-08-05 (suite) — Phase 4 : Planner v2 (lot-aware, dépendances, congés, ressources, matériel)

Christophe a demandé d'attaquer la Phase 4. Avant de coder, question posée (AskUserQuestion) sur la dépendance
non résolue entre Phase 4 et Phase 3 : la roadmap dit que la Phase 4 a besoin des lots multi-métier pour afficher
leurs dépendances, mais le Planner (`planner_screen.dart`) n'avait encore aucune notion de lot (scope réduit de
la Phase 3). **Christophe a choisi de lever cette limitation en premier** plutôt que de construire les nouvelles
fonctionnalités sur une base qui ignore les lots. Passage par un plan détaillé avant codage (taille comparable à
la Phase 3), voir `~/.claude/plans/wiggly-crafting-stroustrup.md` pour le plan complet approuvé.

### Décision de conception clé
Le Planner a besoin, pour chaque devis affiché, du détail temps réel de chacun de ses lots (statut, équipe,
dépendances...). Plutôt qu'une requête `collectionGroup('lots')` (aurait nécessité d'ajouter `workspaceId` sur
chaque lot, un nouvel index Firestore, une nouvelle règle), le choix a été d'étendre la dénormalisation déjà en
place depuis la Phase 3 (`devis.lotsSummary`, écrite par `transitionDevisStatus`) avec les champs manquants —
`teamId`, `dependsOn`, `estimatedDurationDays`, `poseurCountRequired`, `materielRequis`, `poseurNames`. Le
Planner continue de fonctionner avec le seul flux qu'il connaissait déjà (`devis.snapshots()`), sans nouvelle
règle ni nouvel index.

### Implémenté
- **`functions/index.js`** : lots seedés avec `poseurCountRequired: 1`/`materielRequis: ''` en plus de
  `estimatedDurationDays: null` déjà existant ; `lotsSummary` (aux deux endroits où elle est générée — seeding et
  agrégat après transition d'un lot) étendue avec les nouveaux champs ; `setLotDependencies` répercute désormais
  `dependsOn` sur `lotsSummary` (sinon le Planner aurait affiché une dépendance obsolète jusqu'à la prochaine
  transition de statut du lot) via un nouveau helper `patchLotSummary` ; nouvelle Cloud Function callable
  `updateLotPlanningFields` (calquée sur `setLotDependencies`) pour éditer durée/poseurs/matériel d'un lot —
  nécessaire car `lots/{lotId}` reste en écriture serveur uniquement côté règles Firestore, et ces champs ne sont
  pas des transitions de statut donc ne passent pas par `transitionDevisStatus`. Aucun changement dans
  `devisWorkflow.js` : les transitions existantes (`À planifier → En pose`, `En pose → En pose`) acceptaient déjà
  `teamId`/`poseDate`/`poseurIds`/`poseurNames` par lot depuis la Phase 3.
- **`lib/services/devis_service.dart`** : nouvelle méthode `updateLotPlanningFields()`.
- **`lib/screens/planner_screen.dart`** (réécriture complète, 1113 → 1652 lignes) :
  - Nouveau modèle `_PlanUnit` remplace `_ChantierPlan` comme unité planifiable : un devis sans lot produit une
    seule unité (comportement inchangé) ; un devis avec lots (`lotsSummary` non vide) produit une unité par lot.
    Backlog et grille filtrent désormais sur le statut de l'unité (pas le statut agrégé du devis) — un devis avec
    un lot prêt et un lot encore en attente affiche maintenant deux cartes distinctes avec le bon statut chacune,
    au lieu d'un statut agrégé qui masquait celui qui est prêt. C'est le cœur du déblocage de la limitation
    Phase 3.
  - Glisser-déposer : le payload `Draggable`/`DragTarget` porte directement un `_PlanUnit` (devisId + lotId
    optionnel) au lieu d'un simple id de devis ; `_assignToCell` transmet `lotId` à `DevisService.updateStatus`.
  - Conflits de ressources : `_teamLoad`/`_teamCapacity`/`overloadCount` opèrent sur `_PlanUnit` avec la même
    forme qu'avant — couvrent désormais automatiquement le cas "deux lots du même devis sur la même équipe le
    même jour" sans logique supplémentaire.
  - Badge de dépendance (`_DependencyChip`, réutilisé backlog/grille/fiche détail) : affiche les lots amonts
    d'un lot avec `dependsOn`, distingue visuellement satisfait/bloqué (miroir Dart de `LOT_TERMINAL_STATUSES` :
    `_kLotTerminalStatuses`) ; `isReady` étend sa condition existante (livraison fournisseur) avec la
    satisfaction des dépendances. Comme pour la date de livraison, c'est une aide visuelle côté client — le
    serveur reste la seule autorité réelle (`requiresDependenciesValidated`, déjà en place depuis la Phase 3) :
    un lot encore bloqué reste techniquement draggable mais le serveur refuserait la transition avec un message
    clair, exactement comme le pattern déjà existant pour la date de livraison.
  - "Chantiers non affectés" (item roadmap) : couvert nativement par le panneau backlog une fois lot-aware, pas
    de liste séparée construite.
  - Nouveau bouton "Historique" dans la fiche détail (`_HistorySheet`) : lit `statusHistory` (sous-collection du
    lot si applicable, sinon du devis), déjà immuable et alimentée par `transitionDevisStatus` — pur ajout de
    lecture, aucune écriture.
  - Champ "Matériel requis" ajouté à la fiche détail, sauvegardé via `updateLotPlanningFields` si l'unité est un
    lot, ou écriture directe Firestore (comme durée/poseurs le sont déjà) si c'est un devis sans lot.
  - Nouvel écran de saisie des congés (`_UnavailabilitiesSheet` + `_UnavailabilityFormSheet`), ouvert depuis un
    bouton "Congés" dans la barre supérieure à côté du bouton "Équipe" existant : liste/ajout/modification/
    suppression des `unavailabilities` du workspace (poseur, dates, motif parmi congé/maladie/formation/absence
    partielle) — écriture directe côté client, règle déjà ouverte depuis la Phase v1 du Planner (aucun
    changement de règles Firestore nécessaire).

### Vérifications faites cette session
- `npm run lint` (functions) : 0 erreur.
- `node -c functions/index.js` : syntaxe validée.
- `flutter analyze` : 0 erreur, 138 issues (136 avant + 2 nettes, uniquement des `withOpacity` dépréciés — même
  famille que les dépréciations déjà tolérées ailleurs dans le projet, pas de nouvelle vraie erreur).

### ⚠️ Pas fait cette session (volontairement, cohérent avec la Phase 3)
- **Pas déployé** — backend Phase 3 + Phase 4 jamais déployé sur `workit-1daa1`, décision de déploiement groupé à
  prendre avec Christophe.
- **Pas testé en direct** — même décision que pour la Phase 3 : test réel prévu sur le Mac, en pilotage manuel
  (pas d'automatisation Chrome, instable lors de la session précédente). Scénario de test suggéré pour la
  prochaine session : créer/reprendre un devis multi-métier, le faire passer par le métré pour générer ses lots,
  ouvrir le Planner, vérifier que chaque lot apparaît comme une carte backlog distincte avec son propre statut,
  glisser-déposer un lot prêt vers une équipe/jour, déclarer une dépendance entre deux lots (via l'écran
  métreur) et vérifier le badge "Bloqué par..." dans le Planner, forcer un conflit de ressources (deux lots,
  même équipe, même jour), ajouter une absence via le nouveau bouton "Congés", éditer le matériel requis d'un
  lot et vérifier sa persistance, consulter l'historique d'un lot.

### Reste à faire (prochaine session)
1. Déployer Phase 3 + Phase 4 ensemble (`firebase deploy --only functions,firestore:rules`) une fois Christophe
   d'accord.
2. Tester en direct le scénario ci-dessus, sur le Mac.
3. Adapter `poseurs_home_screen.dart` (clôture par lot) — dernière limitation Phase 3 encore non levée, en
   dehors du périmètre du Planner.
4. Éventuellement : petite UI de statut par lot sur `commercial_home_screen.dart`/`admin_dashboard_tab.dart`
   (mentionné comme optionnel depuis la Phase 3).

---

## 🆕 Session 2026-08-05 (suite) — Phase 3 : chantiers multi-lots (socle + écran métreur), codée mais non déployée

Christophe a demandé d'attaquer la Phase 3 de la roadmap (`roadmap_plateforme_multimetier.md`). Vu la taille XL
(gros changement de modèle de données sur une app en prod), passage par un plan détaillé avant codage (voir
`~/.claude/plans/swift-snacking-dove.md` pour le plan complet approuvé) — deux décisions actées avec Christophe
avant de coder : **lots dérivés automatiquement par métier** (un lot = tous les produits d'un devis partageant
le même `metierKey`, aucune nouvelle UI de saisie commerciale) et **scope réduit à cette session** : le socle
(modèle de données, Cloud Function multi-lot, règles Firestore) + l'écran métreur uniquement — Planner, écran
poseur, écran commercial et dashboard admin restent intentionnellement non modifiés.

### Décisions de conception clés (issues d'un second passage de relecture avant codage)
- **Les lots naissent au passage `Acceptée/En cours → À commander`** (pas à l'acceptation) — le métré reste une
  opération globale au chantier (un seul RDV), et ça évite des lots orphelins si le métreur supprime des
  produits pendant le métré (pas d'UI d'ajout après coup). `lotId` = le `metierKey` lui-même.
- **Statut/`poseurIds`/`poseDate` agrégés sur le devis parent** après chaque écriture de lot (le moins avancé
  parmi les lots, union des poseurs, date la plus proche) — pour que Planner/poseur/commercial/dashboard, non
  modifiés cette session, continuent de lire des champs devis-level cohérents sans rien savoir des lots.
- **Garde-fou explicite assumé** : une fois qu'un devis a des lots, toute transition envoyée SANS `lotId` est
  refusée côté serveur (erreur propre, pas de corruption). Conséquence concrète : **un chantier avec des lots ne
  peut plus être programmé via le Planner (glisser-déposer) ni clôturé via l'écran poseur** tant que ces deux
  écrans n'auront pas été adaptés à la notion de lot (session suivante) — à programmer/clôturer uniquement
  depuis l'écran métreur pour l'instant. Les chantiers déjà en cours avant ce déploiement, et tout chantier tant
  que son métré n'est pas fini, ne sont pas concernés.
- **Dépendances entre lots déclarées manuellement** (pas d'inférence automatique par paire de métiers, jugé trop
  fragile) via une petite feuille dans l'écran métreur + nouvelle Cloud Function `setLotDependencies` (valide
  que les IDs sont bien des lots du même chantier, détecte les cycles). Le blocage ne s'applique qu'au démarrage
  de pose (`À planifier → En pose`), pas à l'acceptation/au métré/à la commande. **Effet pratique inerte cette
  session** : aucun lot ne peut atteindre `Terminé` (ça passe par l'écran poseur, hors scope) donc la validation
  de dépendance ne peut jamais être satisfaite pour l'instant — prêt côté données/serveur, pas testable de bout
  en bout avant la session poseur.

### Implémenté
- **`functions/devisWorkflow.js`** : flag `requiresDependenciesValidated` sur `À planifier → En pose`,
  `notifyTransition` accepte un `lotContext` optionnel (nom du lot injecté dans les notifications, sinon un
  métreur avec 3 lots reçoit 3 notifications indiscernables), helpers `aggregateDevisStatus`/`aggregateUnion`/
  `aggregateEarliest` exportés, whitelist `extraFields` des transitions `→ À commander` étendue à
  `metierLabels`.
- **`functions/index.js`** : `transitionDevisStatus` accepte un `lotId` optionnel, transaction restructurée
  (lectures — devis, lot ciblé, lots amonts pour les dépendances, lots frères pour l'agrégat — strictement avant
  toute écriture, contrainte Firestore), garde-fou devis-level décrit plus haut, seeding des lots au premier
  `À commander` avec écriture simultanée de `lotIds`/`lotsSummary` dénormalisés sur le devis. Nouvelle Cloud
  Function callable `setLotDependencies`.
- **`firestore.rules`** : bloc `devis/{id}/lots/{lotId}` (+ sa propre `statusHistory`) calqué exactement sur le
  pattern `statusHistory` existant — lecture ouverte aux membres du workspace, écriture `if false` (tout passe
  par les Cloud Functions). Compilation validée (`firebase deploy --only firestore:rules --dry-run`).
- **`lib/services/devis_service.dart`** : `updateStatus()` gagne un paramètre `lotId` optionnel ; nouvelle
  méthode `setLotDependencies()`.
- **`lib/screens/metreur_home_screen.dart`** : nouveau modèle `_LotSummary` ; `_MeasureCardData` gagne
  `lotIds`/`lotsSummary` (lus depuis les champs dénormalisés) ; `_acceptRequest`/`_scheduleMeeting` **inchangés**
  (restent devis-level, cohérent avec le moment de naissance des lots) ; `_openMeasurementForm` calcule et
  transmet `metierLabels` uniquement au tout premier passage en `À commander` ; l'écran de détail
  (`_MeasureRequestSummary`) souscrit en direct à la sous-collection `lots` (pour avoir `dependsOn`, pas
  dénormalisé) et affiche un bloc "Lots" avec un bouton d'action indépendant par lot
  (`_confirmOrderLot`/`_schedulePoseLot`, calqués sur les méthodes devis-level existantes mais scopés par
  `lotId`) + un bouton "Dépendances" par lot ; le bouton de statut unique existant se masque proprement
  (`SizedBox.shrink()`) dès qu'un devis a des lots, sans toucher au cas `Acceptée`/défaut (démarrage du métré).

### Vérifications faites cette session
- `npm run lint` (functions) : 0 erreur.
- `flutter analyze` : 0 erreur, 136 issues (133 avant + 3 infos `unnecessary_this` mineures dans le nouveau
  code, cosmétiques, même famille que 3 occurrences déjà préexistantes dans ce fichier — pas corrigées, pas
  bloquantes).
- `firebase deploy --only firestore:rules --dry-run` : règles compilées avec succès.
- Relecture manuelle attentive de l'ordre lectures/écritures de la transaction Firestore restructurée (point le
  plus sensible identifié par la relecture de conception) — cohérent : toutes les lectures (devis, lot ciblé,
  dépendances, lots frères) précèdent toute écriture.

### ⚠️ Pas fait cette session (volontairement)
- **Pas déployé** (`firebase deploy --only functions,firestore:rules`) — en attente du feu vert de Christophe,
  vu l'impact potentiel sur les chantiers réels en cours dans "Ambiance Alu" et le fait que rien n'a pu être
  testé en direct cette fois.
- **Pas testé en direct** — décidé avec Christophe de tester sur son Mac ce soir/demain, en pilotage manuel
  direct (pas d'automatisation Chrome, qui avait posé problème lors de la session précédente sur les 11
  métiers). Scénario de test prévu : créer un devis multi-métier, l'accepter, faire le métré, vérifier que les
  lots apparaissent avec le bon libellé, confirmer la commande d'un lot indépendamment d'un autre, programmer la
  pose d'un lot, vérifier qu'une dépendance non satisfaite bloque bien le bouton avec le bon message.
- Planner, écran poseur, écran commercial, dashboard admin : non touchés, comme prévu par le scope.

### Reste à faire (prochaine session, sur le Mac ou ici)
1. Déployer (`firebase deploy --only functions,firestore:rules`) une fois Christophe d'accord.
2. Tester en direct le scénario ci-dessus.
3. Adapter `poseurs_home_screen.dart` (clôture par lot) et `planner_screen.dart` (programmation par lot) pour
   lever la limitation assumée — c'est ce qui débloquera l'effet pratique des dépendances entre lots.
4. Éventuellement : petite UI de statut par lot sur `commercial_home_screen.dart`/`admin_dashboard_tab.dart`.

---

## ⚠️ Session 2026-08-05 (suite) — Tentative de test en direct d'un des 11 nouveaux métiers, bloquée

Christophe a demandé de tester en direct un des nouveaux métiers (plomberie/chauffe-eau choisi). `flutter run
-d web-server --web-port=8765 --web-hostname=localhost` lancé, connexion réussie (`commercial@workit-test.fr`,
workspace "Ambiance Alu"), remplissage du formulaire "Nouveau devis" étape Client OK.

**Bloqué à l'étape "Chantier" → "Éléments"** : le bouton "Suivant" a cessé de répondre de façon reproductible
après plusieurs clics, sur 3 tentatives fraîches (page rechargée à chaque fois). Cause identifiée dans les logs
console : une vraie exception du framework Flutter, pas liée à nos changements Phase 2 —
`Assertion failed: file:///.../material/dropdown.dart:1480:12 — _dropdownRoute == null is not true`, déclenchée
par une touche Espace atteignant un `DropdownButton` pendant l'ouverture de sa route (probablement provoqué par
l'automatisation navigateur elle-même — un clic de "flush" utilisé pour contourner un lag de rendu a fini par
atterrir sur un dropdown). Après ce crash, la navigation du stepper reste bloquée pour le reste de la session
même après rechargement.

Repéré aussi un bug d'affichage bénin sans rapport : le champ "Nom" du formulaire client n'affiche pas toujours
le texte tapé à l'écran alors qu'il est bien enregistré (confirmé par la validation qui laisse passer à l'étape
suivante) — pur problème de rendu canvas, pas de perte de données.

**Décision avec Christophe** : on arrête le test en direct pour cette session plutôt que de continuer à
insister. Le serveur `localhost:8765` a été laissé tournant en arrière-plan sur ce poste au cas où il voudrait
reprendre la main lui-même dans Chrome.

### Reste à faire (prochaine session)
- **Décidé avec Christophe : le test en direct des 11 nouveaux métiers se fera sur le Mac (ce soir ou demain),
  sans passer par l'automatisation Chrome** — pilotage manuel direct, pour éviter le bug d'automatisation
  rencontré ici. Lire cette section en priorité en reprenant sur le Mac.
- Si le bug `dropdown.dart:1480` se reproduit en usage normal (pas juste via automatisation), le signaler comme
  bug Flutter à surveiller — mais pas de preuve à ce stade que ça arrive en usage humain normal.

---

## ✅ Session 2026-08-05 — Phase 2 : contenu métier étendu aux 11 métiers restants

Christophe a demandé de continuer la Phase 2 (interrompue à `menuiserie_aluminium` seul le 04/08) sur les 11
autres métiers du dictionnaire, avec la même exigence de contenu professionnel réel et sourcé (pas générique).

### Méthode
Vu le volume (11 métiers × recherche normative réelle), 11 agents de recherche ont tourné en parallèle en
arrière-plan, chacun chargé de : lire les catégories/champs de métré existants de son métier, vérifier par
vraie recherche web les normes NF DTU/référentiels professionnels applicables (interdiction de citer un
numéro non vérifié), choisir une catégorie « pilote » et proposer des contraintes `required`/`min`/`max`
sourcées, rédiger les 4 blocs `preparation_steps`/`execution_checklist`/`non_conformite_causes`/`indicateurs`.
Chaque rendu a été relu et intégré à la main dans `workit_dictionary.json` (pas de copier-coller aveugle),
avec `"metierVersion": 1` ajouté sur chacun des 11 métiers.

### Sourcing retenu par métier (catégorie pilote → normes/références vérifiées)
- **Plâtrerie-isolation-cloisons** (`cloisons`) : NF DTU 25.41 (plaques de plâtre), NF DTU 25.42 (doublages),
  NF DTU 58.1 (plafonds suspendus), guides Placo/Siniat, AQC.
- **Électricité-courants faibles** (`tableaux_electriques`) : NF C15-100, Promotelec, Legrand/Nexans pour
  sections de câble. ⚠️ Les bornes numériques (nb rangées, distance compteur) sont des bornes de
  vraisemblance métier, pas des valeurs tirées du texte normatif lui-même — précisé pour ne pas laisser croire
  à une citation NF C15-100 inventée.
- **Chauffage-clim-ventilation** (`pompes_a_chaleur`) : pas un « NF DTU 65 » unique (famille éclatée en
  65.10/65.11/65.14/65.16), NF DTU 68.3 (VMC), QualiPAC/RGE, arrêté du 24/03/1982 (débits VMC réglementaires).
- **Plomberie-sanitaire** (`chauffe_eau`) : NF DTU 60.1/60.11, NF EN 1487 (groupe de sécurité), volumes
  électriques NF C15-100. ⚠️ Le label existant `distanceBaignoire` mentionne « volume 3 », terminologie
  obsolète de l'ancienne NF C15-100 (fusionné avec le volume 2 depuis 2015) — pas corrigé cette session
  (scope = required/min/max uniquement), à corriger un jour.
- **Peinture-revêtements** (`peinture_interieure`) : NF DTU 59.1 (peinture), NF DTU 59.4 (papier peint),
  classement UPEC. Correction au passage : le DTU sols souples n'est plus le 59.3 mais le **NF DTU 53.12**
  (fusion 2020 des anciens 53.1/53.2).
- **Carrelage-maçonnerie fine** (`carrelage_sols`) : NF DTU 52.1/52.2, NF DTU 26.2 (joints de fractionnement
  chape, 40m²/8ml max), tolérances de planéité/désaffleurement sourcées FFB.
- **Cuisine-aménagement intérieur** (`plans_de_travail`) : ⚠️ sourcing structurellement plus faible — **il
  n'existe aucun NF DTU pour l'agencement de cuisine**. Retenu : NF EN 1116 (cotes électroménager), NF EN
  14749 (sécurité mobilier), NF C15-100 (prises cuisine, bien documentée). Les règles de type « triangle
  d'activité » et hauteur de plan de travail ergonomique sont un consensus de métier, pas une norme opposable.
  L'agent a aussi corrigé une fausse piste du prompt initial : « UFME » n'est pas l'organisme cuisine
  (c'est celui des menuiseries), et une « norme DTU 52.1 pour le débord de plan de travail » trouvée sur un
  site tiers est une fausse attribution (le DTU 52.1 concerne le carrelage) — non reprise.
- **Salle de bain-étanchéité** (`etancheite`) : fiches pathologie AQC (douches à l'italienne = un des tout
  premiers postes de sinistres bâtiment documentés), Cahier CSTB 3567/3756 (SPEC/SEL), NF DTU 52.2 (carrelage
  collé zone humide, pas 52.1 qui est la pose scellée), volumes électriques NF C15-100.
- **Sols extérieurs-aménagements** (`dallage_exterieur`) : NF DTU 52.1, NF DTU 13.3 (dallages), NF P98-335
  (pavés/dalles béton), règles pro UNEP/FFB terrasses collées (pente mini 1,5%).
- **Vitrerie-miroiterie** (`remplacement_vitrage`) : NF DTU 39 (parties P1 à P5), NF EN 12600/NF EN 356
  (classement sécurité/anti-effraction), NF P01-012/013 (garde-corps). Le PDF du DTU 39 P5 n'a pas pu être lu
  intégralement par l'agent — seules les affirmations recoupées par ≥2 sources indépendantes ont été retenues.
- **Automatismes-portails** (`motorisations`) : NF EN 13241-1 (norme produit), NF EN 12453/12445 (sécurité,
  seuils de force 400N dynamique/150N statique), art. R134-55 du Code de la construction. Le « décret 2013 »
  évoqué dans la consigne initiale n'a pas été retrouvé tel quel — non cité, base légale réelle utilisée à la
  place.

### Choix méthodologique assumé
Comme pour le pilote, `required`/`min`/`max` n'a été ajouté que sur **une catégorie pilote par métier** (celle
qui porte le plus d'enjeux bloquants/réglementaires), pas sur toutes les catégories — cohérent avec la
décision prise avec Christophe le 04/08 de limiter le scope. Les clés des 4 blocs sont en **snake_case**
(`verif_xxx`, `xxx_conforme`...) pour rester cohérentes avec le pilote réel dans le fichier, malgré une
consigne de prompt qui mentionnait du camelCase — plusieurs agents l'ont noté et corrigé d'eux-mêmes.

### Vérifications faites cette session
- JSON validé syntaxiquement (`ConvertFrom-Json` sans erreur).
- `flutter analyze` : 0 erreur, 133 issues (inchangé, toutes préexistantes).
- Confirmé que `_validateProduct()` (`measurement_form_screen.dart`) est déjà 100% générique (itère sur les
  `fields` du dictionnaire) — **aucun changement de code Dart nécessaire**, les nouvelles contraintes
  `required`/`min`/`max` des 11 métiers sont automatiquement appliquées par l'écran de métré existant.
- 12/12 métiers ont maintenant `"metierVersion": 1` et les 4 blocs Phase 2.

### ⚠️ Pas testé en direct dans l'app cette session
Contrairement à la session pilote du 04/08 (testée de bout en bout dans Chrome), ce travail est purement
contenu/données — **aucun test manuel dans l'app** n'a été fait pour les 11 nouveaux métiers cette fois
(pas de devis créé sur un métier autre que menuiserie pour vérifier l'affichage réel du formulaire de métré
avec les nouvelles contraintes). À faire à l'occasion : créer un devis sur au moins un des 11 métiers (ex.
plomberie/chauffe-eau) et vérifier que les messages `required`/`min`/`max` s'affichent bien comme pour le
pilote.

### Reste à faire (prochaine session)
- Tester en direct au moins un des 11 nouveaux métiers dans l'app (formulaire de métré + validation).
- Étendre `required`/`min`/`max` aux autres catégories de chaque métier (actuellement 1 seule catégorie pilote
  par métier, comme pour `menuiserie_aluminium`) si Christophe veut aller plus loin.
- Corriger la terminologie obsolète « volume 3 » dans le label `distanceBaignoire` (plomberie).
- Committer et pousser ce travail (fait en fin de session, voir commit).

## ✅ Session 2026-08-04 (soir, suite) — Bug corrigé : "Modifier le métré" n'affichait pas les valeurs déjà saisies

Repéré à la fin de la session Phase 2 précédente (voir plus bas) : rouvrir "Modifier le métré" sur un devis dont le
métré venait d'être enregistré affichait un formulaire vide au lieu des valeurs saisies. La donnée elle-même était
bien persistée (confirmé alors via la vue poseur) — c'était un bug d'affichage pur.

**Cause** : `_MeasureRequestSummary` (dans `metreur_home_screen.dart`) est un `StatefulWidget` dont le champ `data`
(`_MeasureCardData`, contenant le `draft` avec les mesures) est capturé une seule fois à l'ouverture de l'écran et
ne change jamais — `widget.data` reste figé même après un aller-retour réussi vers `MeasurementFormScreen` qui
renvoie les mesures à jour. `_openMeasurementForm` écrivait bien la donnée dans Firestore, mais ne mettait à jour
que l'écran *parent* (`widget.onRefresh!()`), jamais l'écran de détail actuellement ouvert. Rouvrir "Modifier"
depuis ce même écran repassait donc systématiquement l'ancien `widget.data.draft` (sans les mesures) à
`MeasurementFormScreen`.

**Correctif** : ajout d'une copie locale mutable `_data` dans `_MeasureRequestSummaryState` (initialisée depuis
`widget.data`), utilisée partout à la place de `widget.data` dans cette classe. Après un enregistrement réussi du
métré, `_data` est mise à jour via `setState` avec le nouveau `draft`/statut — cohérent avec ce qui est écrit en
base (même `updatedDraft`, même statut `'À commander'`).

**Testé en direct** (workspace "Ambiance Alu", `metreur@workit-test.fr`, devis "##9893 - Claude Testeur") : rempli
le champ "Note" avec une valeur test unique ("TESTFIXBUG123") → "Terminer et Valider" → "Métré enregistré avec
succès" → réouverture immédiate de "Modifier le métré" sur le même écran → le champ "Note" affiche bien
"TESTFIXBUG123" (confirmé par capture zoomée). `flutter analyze` : 0 erreur, 26 issues sur le fichier (133 sur le
projet, inchangé, toutes préexistantes).

---

## ✅ Session 2026-08-04 (soir) — Phase 2 : dictionnaire métier étendu + moteur de documents

Christophe a explicitement demandé un contenu **professionnel réel, sourcé sur internet**, pas générique — priorité
absolue tenue tout du long (vocabulaire NF DTU 36.5 vérifié via FFB, Würth, Agence Qualité Construction, France
Menuisiers).

### Scope retenu avec Christophe (via AskUserQuestion)
- 1 métier pilote (`menuiserie_aluminium`, catégorie `menuiseries_exterieures`) plutôt que les 12 métiers d'un coup.
- Moteur de documents + 2-3 modèles clés plutôt que les 9 modèles de la roadmap.

### Implémenté
- **`workit_dictionary.json`** (`menuiserie_aluminium` uniquement cette session) : `metierVersion: 1` ; `required`/
  `min`/`max` ajoutés sur les champs de métré existants (`largeurReelle`, `hauteurReelle`, `cjHaut/Bas/Gauche/Droite`,
  `modePose`, `profondeurTableau`, `natureSupport`) ; 4 nouveaux blocs sourcés NF DTU 36.5 : `preparation_steps` (8),
  `execution_checklist` (10), `non_conformite_causes` (10), `indicateurs` (4).
- **`DictionaryService`** : `MetreFieldDef` gagne `required`/`min`/`max` (nullable, rétrocompatible) ; nouvelles
  classes `PreparationStep`/`ChecklistItem`/`NonConformiteCause`/`MetierIndicateur` + méthodes associées, toutes
  renvoient une liste vide (jamais d'exception) si le métier n'a pas encore ce contenu.
- **`measurement_form_screen.dart`** : `_validateProduct()` bloque la navigation (SnackBar rouge) si un champ
  `required` est vide ou hors bornes `min`/`max` ; migré vers `DocumentEngine.generateAndShare` (suppression
  d'~340 lignes de génération PDF dupliquée).
- **`document_templates.json`** + **`lib/services/document_engine.dart`** (nouveaux) : moteur générique — un builder
  par *type* de section (header/client/chantier/elements/checklist/signature), jamais par document. 3 modèles :
  `bon_commande` (migration de l'existant), `bon_preparation` (checklist `preparation_steps`), `rapport_autocontrole`
  (checklist `execution_checklist`). Upload Storage + trace Firestore (`devis/{id}/documents`) en best-effort (ne
  bloque jamais l'impression si ça échoue).
- **`firestore.rules`** : règle `documents/{documentId}` sous `devis/{devisId}`, calquée sur `auditLogs` (lecture +
  création ouvertes aux membres du workspace, update/delete `if false`) — **déployée**.
- **Boutons ajoutés** : "Bon de préparation" dans `metreur_home_screen.dart` (visible si statut À planifier/En pose),
  "Rapport d'autocontrôle" dans `poseurs_home_screen.dart` (visible avant clôture). `_ProductData`/`_DraftData`
  (poseur) ont gagné `metierKey` + `toMap()`, absents jusqu'ici.

### ✅ Testé en direct de bout en bout (workspace "Ambiance Alu", 3 comptes de test)
Créé un devis neuf ("Phase2Test", menuiserie_aluminium/menuiseries_exterieures) pour avoir un `metierKey` propre (les
anciens devis de test type "##9893 Claude Testeur" n'en portent pas → `_fieldDefs` vide, écran de métré générique de
repli, sans crash — confirme au passage le comportement gracieux attendu pour un métier/produit sans contenu Phase 2).

Cycle complet mené jusqu'au bout sur ce devis :
- **Validation `required`** : soumission vide → SnackBar *"Largeur tableau réelle (3 points, plus petite) est
  obligatoire."* (vocabulaire sourcé, pas générique).
- **Validation `min`** : largeur=100 → *"...doit être supérieur ou égal à 300."*
- Plusieurs champs `required` distincts enforced (`modePose`, `natureSupport` bloquent aussi) ; dropdowns
  `modePose`/`natureSupport` vérifiés à l'écran avec les vraies valeurs sourcées ("Applique intérieure/extérieure,
  Tunnel, Rénovation sur dormant conservé" / "Maçonnerie, Béton, Ossature bois, Ossature métallique").
- Métré complété avec des valeurs valides → **transition automatique confirmée** : Acceptée → À commander ("Métré
  terminé") → (commercial) Commander → À planifier → (métreur) Programmer la pose → En pose, poseur notifié.
- **Persistance des données vérifiée côté poseur** : la fiche "Détails métreur" affiche bien "Dimensions réelles :
  1200 x 1400" — les valeurs saisies au métré sont correctement enregistrées et relues (un écran intermédiaire,
  "Modifier le métré" côté métreur, n'affiche pas les valeurs déjà saisies au réouverture — bug d'affichage
  pré-existant du formulaire, pas lié au Phase 2, la donnée elle-même est bien persistée comme le confirme la vue
  poseur).
- **Bouton "Bon de préparation"** (métreur, visible en statut À planifier) : génère le PDF sans crash (logs
  navigateur confirmant `pdf.save()` + résolution de la checklist `preparation_steps`), ouvre le dialogue
  d'impression natif du navigateur.
- **Bouton "Rapport d'autocontrôle"** (poseur, visible en statut En pose avant clôture) : idem, génère le PDF sans
  crash avec le `metierKey` réel transmis par `_ProductData`/`_DraftData.toMap()`.
- Bon de commande (bouton imprimante dans l'AppBar de l'écran de métré) : présent dans le code
  (`Icons.print_outlined`, `_generateAndPrintPdf` → `DocumentEngine`), non cliqué en direct cette session (icône
  positionnée sous la bannière "DEBUG" de Flutter, difficile à atteindre en automatisation navigateur) — mais son
  code est strictement identique au chemin déjà vérifié pour les deux autres documents (même `DocumentEngine`,
  même moteur), donc couvert par la même preuve de fonctionnement.

`flutter analyze` : 0 erreur sur l'ensemble du projet (133 issues, toutes préexistantes/dépréciations).

### ⚠️ Limite restante (honnête, pas glissée sous le tapis)
**App Check bloque probablement l'écriture Storage/Firestore de traçabilité en local** (`FirebaseError: AppCheck:
ReCAPTCHA error`, visible dans la console à chaque génération de document) — comportement attendu de
l'environnement de dev (pas de vraie clé reCAPTCHA configurée, cf. Phase 0), pas une régression Phase 2 : le
`try/catch` best-effort du `DocumentEngine` absorbe l'échec et laisse quand même l'impression fonctionner, exactement
comme prévu. **Non vérifiable en local que le document Firestore + fichier Storage sont bien créés** — à confirmer
par Christophe une fois une vraie clé App Check en place (ou en testant sur un environnement où l'enforcement
App Check n'est pas actif). 11 des 12 métiers (et les autres catégories de menuiserie : volets, portails,
pergolas...) n'ont toujours aucun contenu Phase 2 — attendu et scopé ainsi avec Christophe, pas un oubli.

⚠️ Devis de test laissé dans "Ambiance Alu" : "##8091 - Phase2Test" (statut En pose, poseur Lucas Martin assigné,
métré et 2 documents générés) — à nettoyer ou réutiliser.

### Reste à faire (prochaine session)
- Vérifier la trace Firestore/Storage (`devis/{id}/documents`) une fois App Check non-bloquant.
- Cliquer réellement le bouton "imprimante" du bon de commande (bloqué par la bannière DEBUG cette session) pour
  une dernière confirmation visuelle, ou simplement retirer la bannière DEBUG en testant un build release.
- Étendre le contenu Phase 2 (règles/checklists/causes/indicateurs) aux 11 autres métiers, même rigueur de sourcing.
- Les 6 autres modèles de documents de la roadmap (fiche d'intervention, rapport de pose, PV de réception, fiche de
  réserves, rapport SAV, fiche de métré séparée) — le moteur générique les supporte déjà sans nouveau chantier
  technique, juste ajouter leur config dans `document_templates.json`.
- (Optionnel, hors Phase 2) le formulaire de métré ne recharge pas les valeurs déjà saisies quand on rouvre
  "Modifier le métré" — bug d'affichage pré-existant, la donnée est bien persistée (vérifié via la vue poseur).

---

## ✅ Session 2026-08-04 — Phase 1 : moteur de workflow générique + historique immuable des statuts

Christophe a demandé d'attaquer la Phase 1 de la roadmap (`roadmap_plateforme_multimetier.md`) : remplacer les
écritures directes de statut dispersées entre `metreur_home_screen.dart`/`poseurs_home_screen.dart` par un moteur
centralisé, avec historique immuable et vérification de droits.

### Implémenté et déployé (workit-1daa1)
- **Nouvelle Cloud Function callable `transitionDevisStatus`** (`functions/index.js`) : point d'entrée unique pour
  toute transition de statut d'un devis. Vérifie rôle/appartenance workspace/assignation poseur
  (`requirePoseurAssigned` — ferme le trou où un poseur pouvait clôturer un chantier qui n'était pas le sien),
  valide les champs additionnels autorisés (whitelist stricte par transition), écrit statut + une entrée dans la
  nouvelle sous-collection immuable `statusHistory` de façon atomique (transaction), puis notifie.
- **`functions/devisWorkflow.js`** (nouveau) : config déclarative des transitions (statuts → statuts autorisés,
  rôles, champs additionnels whitelistés, champs de type date) — remplace les switch/if répétés.
- **`functions/notifyHelpers.js`** (nouveau) : helpers FCM/in-app extraits de `index.js`, partagés avec
  `devisWorkflow.js`. Les deux systèmes de notification (in-app + push), auparavant dupliqués et désynchronisés,
  sont désormais fusionnés et pilotés depuis le même point.
- **`onDevisStatusChange`** perd ses 8 blocs `if` de notification par statut (garde uniquement création,
  `metreurNote`, `paiementEffectue` — champs indépendants du statut).
- **`firestore.rules`** : le champ `status`/`metreurStatus` d'un devis ne peut plus être modifié par écriture
  client directe (seule la Cloud Function, Admin SDK, le peut) ; création limitée à `status=='Nouvelle demande'` ;
  nouvelle sous-collection `statusHistory` en lecture seule côté client.
- **`DevisService.updateStatus`** (Dart) appelle désormais la Cloud Function au lieu d'écrire Firestore
  directement. Les 7 sites d'écriture directe du statut dans `metreur_home_screen.dart`/`poseurs_home_screen.dart`
  migrés ; `planner_screen.dart` l'utilisait déjà (migré automatiquement, zéro changement de code nécessaire).
- **Bug latent corrigé au passage** : `admin_dashboard_tab.dart` était le seul écran sans le fallback
  `status ?? metreurStatus` (un vieux devis n'ayant que `metreurStatus` y était invisible).

### 🐛 Bug trouvé et corrigé en testant en direct
Le SDK `cloud_functions` valide les paramètres côté client et **rejette silencieusement** tout objet non
JSON-sérialisable (assertion `_debugIsValidParameterType`) **avant même d'émettre la requête HTTP** — passer un
`Timestamp` Firestore directement dans `extraFields` (pour `meetingAt`/`poseDate`) faisait donc échouer la
transition sans aucune trace côté serveur, alors que l'UI optimiste du client donnait l'impression que ça avait
fonctionné. Repéré uniquement parce que le Planner (qui affiche l'erreur, contrairement aux `catch (_) {}` silencieux
du métreur) a fini par montrer `Assertion failed: _debugIsValidParameterType(parameters) is not true`. Corrigé :
les dates transitent désormais en chaîne ISO côté client, reconverties en `Timestamp` par la Cloud Function avant
écriture (aucun changement nécessaire côté lecture, tous les écrans continuent de lire un vrai `Timestamp`).
**Leçon à retenir pour la suite** : ne jamais passer un `Timestamp`/`GeoPoint`/objet Firestore directement à un
appel `httpsCallable` — toujours le sérialiser en primitif (string/num) et le reconvertir côté serveur.

### ✅ Testé en direct (workspace "Ambiance Alu", comptes `metreur@workit-test.fr` puis `poseur@workit-test.fr`)
Cycle complet créé de bout en bout sur un devis de test ("Claude Phase1Test") : accepter → prendre RDV → démarrer/
terminer le métré → confirmer la commande → programmer la pose (testé à la fois via le bouton dédié du métreur ET
via le drag-and-drop du Planner, qui utilise le même point d'entrée) — chaque transition confirmée via les logs
Cloud Functions (`firebase functions:log`) et le déclenchement du trigger `onDevisStatusChange`, données (date de
pose, équipe assignée) correctement affichées ensuite côté commercial.

Le chantier avait été assigné à "Guillaume Hervé" (membre réel de l'équipe, pas un compte de test) — Christophe a
demandé de le réaffecter à `poseur@workit-test.fr` (Lucas Martin) pour pouvoir tester la clôture. Ça a révélé un
**deuxième trou dans la config des transitions** : les cartes déjà planifiées restent glissables dans le Planner
pour être réaffectées à une autre équipe/jour (comportement libre déjà présent avant la Phase 1), mais `En pose →
En pose` n'était pas dans `TRANSITIONS` → le drag de réaffectation échouait silencieusement. Ajouté et déployé.
Réaffectation testée avec succès (ajout de Lucas Martin à "Équipe 1", re-drag), puis clôture testée avec ce compte :
bouton "Chantier pas terminé" (`_signaler` → `À clôturer`) confirmé de bout en bout, y compris la vérification de
sécurité `requirePoseurAssigned` (le compte est bien dans `poseurIds`, sinon la Cloud Function aurait rejeté).
Confirmé via les logs serveur et l'affichage côté commercial (équipe "Guillaume Hervé, Lucas Martin", statut
`À clôturer`, "Problème signalé").

⚠️ **Bouton "Chantier terminé" (`_valider` → `Terminé`) non testé** : la pièce jointe obligatoire (photo
d'attestation) ouvre un sélecteur de fichier natif inaccessible depuis l'automatisation navigateur. Cette tentative
a néanmoins révélé un **bug pré-existant hors Phase 1** : l'écran utilise `Image.file()` pour prévisualiser la
photo choisie, qui n'est pas supporté par Flutter Web (`Assertion failed: ... "Image.file is not supported on
Flutter Web. Consider using either Image.asset or Image.network instead."`) — le rapport de fin de chantier plante
donc systématiquement côté web. Ce chemin n'ajoute/ne modifie aucun `Timestamp` en paramètre Cloud Function, donc
n'est pas concerné par le bug de sérialisation trouvé plus haut ; la logique serveur de la transition elle-même a
été vérifiée par relecture de code uniquement. **À corriger dans une session dédiée** (remplacer `Image.file` par
un affichage conditionnel web/mobile, ou `Image.memory` avec les bytes du fichier) — non traité ici, hors périmètre
Phase 1, et probablement un problème seulement visible en test web (l'app mobile réelle n'est pas affectée).

`flutter analyze` : 0 erreur, 135 issues (inchangé). `npm run lint` (functions) : 0 erreur. **Committé et poussé**
(`fb176cf`, `12847eb`, `bb032e9`, `77735c4`).

⚠️ Chantier de test laissé dans le workspace "Ambiance Alu" : devis "Claude Phase1Test" (statut `À clôturer`,
équipe "Guillaume Hervé, Lucas Martin", pose le 04/08/2026) — à nettoyer ou réutiliser.

### 🐛 Corrigé dans la foulée : `Image.file` + `putFile` non supportés sur Flutter Web
Le rapport de fin de chantier poseur (`_RapportFinChantierState` dans `poseurs_home_screen.dart`) utilisait
`dart:io File` de bout en bout, avec deux appels qui plantent systématiquement sur web : `Image.file()` pour
prévisualiser la photo (assertion explicite `!kIsWeb` dans le framework Flutter — c'est ce qui avait fait planter
le test de tout à l'heure) et `Reference.putFile(File)` pour l'upload vers Firebase Storage (`dart:io.File` n'a pas
d'implémentation web). Remplacé par une petite classe `_PickedPhoto` (bytes + nom), les bytes étant lus
immédiatement via `XFile.readAsBytes()` (fonctionne pareil sur web et mobile) : `Image.file` → `Image.memory`,
`ref.putFile` → `ref.putData`. `dart:io` n'est plus importé dans ce fichier.

`flutter analyze` : 0 erreur, 135 issues (inchangé). Revérifié en direct avec `poseur@workit-test.fr` : le clic sur
"Photographier l'attestation signée" ne fait plus planter l'app (avant le correctif, une tentative similaire
plantait avec `Image.file is not supported on Flutter Web`). **La sélection de fichier réelle passe par un
dialogue natif du système, hors de portée de l'automatisation navigateur — l'upload + la prévisualisation avec une
vraie photo n'ont donc pas pu être testés de bout en bout.** À valider manuellement par Christophe (web ou mobile)
dès l'occasion. Committé et poussé (`0169890`).

### Reste à faire (prochaine session)
- Valider manuellement "Chantier terminé" avec une vraie photo (upload + prévisualisation), web ou mobile.
- Passer à la Phase 2 (dictionnaire métier étendu + moteur de documents) une fois la Phase 1 validée en usage réel.

---

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
**Christophe attaque la Phase 1 depuis le Mac ce soir.** Lire ce journal + `roadmap_plateforme_multimetier.md` en
tout début de session là-bas avant de commencer — tout est committé et poussé sur `origin/main` (`51f2458`), rien
en attente côté Windows, `git pull` suffit pour repartir exactement d'ici.

⚠️ Note mineure : un compte de test `testactivation.lien.0803@workit-test.fr` a été créé puis retiré de l'équipe
(désactivé) pendant les tests de cette session, dans le même workspace test que ci-dessous — sans conséquence,
mentionné pour mémoire.

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
