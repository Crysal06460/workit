# Roadmap — WorkIt plateforme multi-métier professionnelle

**Créé le :** 2026-08-03
**Origine :** brief produit de Christophe (Lead Dev Flutter / Architecte Firebase / Product Engineer B2B) pour faire
évoluer WorkIt d'une app menuiserie-centrée vers une plateforme couvrant simultanément les 12 corps de métier déjà
présents dans le dictionnaire, sans duplication d'écrans/logique.

**Principe directeur retenu** : tout doit être piloté par de la configuration versionnée (workflow, formulaires,
documents), pas par des conditions codées en dur dispersées dans les widgets. Chaque phase ci-dessous construit
l'étage sur lequel la suivante s'appuie — ne pas paralléliser sans relire les dépendances indiquées.

---

## Phase 0 — Sécurité et comptes (fondation, avant tout le reste)

**Statut (2026-08-03 soir, fin)** : **✅ terminée côté code.** Un audit complet a révélé une vulnérabilité critique
active (prise de contrôle de compte via `createInvitation`/`consumeInvitation`) — corrigée et déployée en
production (commit `7d299ea`), avec le durcissement des règles `users`/`provisioned_accounts` contre
l'auto-élévation de privilèges et la lecture cross-workspace. Les 4 points restants ont ensuite tous été faits et
déployés dans la foulée (commit `5bf4ae3`) : lien d'activation à la place du mot de passe temporaire, App Check
(scaffolding non bloquant), quota IA, logs d'audit. Détail complet dans `session_courante.md`.

**Seul reste à faire, et uniquement par Christophe** (étapes dans des consoles web externes, hors de portée pour
Claude) : enregistrer les vrais providers App Check (reCAPTCHA v3 web, Play Integrity Android, DeviceCheck/App
Attest iOS) pour pouvoir un jour activer `enforceAppCheck: true` — checklist exacte dans `session_courante.md`.
Tant que ce n'est pas fait, App Check tourne en mode observation, rien n'est bloqué.

**Pourquoi en premier** : risques de sécurité réels et indépendants du reste (isolation cross-workspace, mot de
passe temporaire affiché en clair) ; construire des fonctionnalités avancées sur une base non auditée ferait courir
ces mêmes risques à chaque nouvelle brique.

- ✅ Audit complet `firestore.rules` + Cloud Functions : un poseur ne voit que ses chantiers assignés, un métreur ne
  modifie que les dossiers autorisés, un commercial n'a aucun droit admin/abonnement, un admin reste cantonné à son
  workspace — aucune lecture cross-workspace possible sur `users`/`provisioned_accounts`. Reste à étendre le
  même niveau de rigueur aux autres collections au fil des phases suivantes si de nouveaux angles apparaissent.
- ✅ Validation serveur systématique des rôles/permissions sur les points les plus critiques (`users` create/update,
  `analyzeDevis`). Les 4 fonctions d'invitation par lien, vulnérables et non utilisées, ont été supprimées plutôt
  que corrigées.
- ✅ Mot de passe temporaire supprimé → lien d'activation Firebase (`generatePasswordResetLink`), testé en direct.
- ✅ App Check codé et activé (mode observation, non bloquant) — reste l'enregistrement des vrais providers par
  Christophe (voir ci-dessus) pour passer en mode bloquant.
- ✅ Quota IA : 100 analyses/mois/workspace sur `analyzeDevis`, ajustable.
- ✅ Logs d'audit : sous-collection immuable `auditLogs`, alimentée à la création de compte, la désactivation d'un
  membre et le changement de ses droits de délégation.

**Taille relative :** M

---

## Phase 1 — Moteur de workflow générique + historique immuable

**Statut (2026-08-04)** : **✅ terminée côté code, déployée et testée en direct.** Nouvelle Cloud Function callable
`transitionDevisStatus` (config déclarative dans `functions/devisWorkflow.js`), sous-collection `statusHistory`
immuable, `firestore.rules` verrouillé sur le champ statut, notifications in-app+push fusionnées. Cycle complet
métreur testé de bout en bout (workspace "Ambiance Alu"). Un bug de sérialisation (`Timestamp` passé à une Cloud
Function callable) a été trouvé et corrigé en cours de test. Reste à tester : clôture poseur (`Terminé`/`À
clôturer`), faute de compte poseur assigné disponible pendant cette session — voir `session_courante.md`.

**Pourquoi ensuite** : c'est le socle technique dont dépendent le multi-lot (Phase 3), le circuit de validation
terrain (Phase 5) et le dashboard de délais (Phase 6). Sans ça, chaque nouvelle fonctionnalité recréerait sa propre
logique de statut dispersée — exactement ce que le principe directeur veut éviter.

- Remplacer la logique de statut actuelle (dispersée entre `metreur_home_screen.dart`, `DevisService`, etc.) par un
  moteur configurable : statuts, transitions autorisées par rôle, effets de bord (notifications) déclarés en
  config plutôt qu'en `switch`/`if` répétés.
- Sous-collection `statusHistory` immuable par chantier (et bientôt par lot) : ancien statut, nouveau statut, uid,
  rôle, date, commentaire, données associées, origine (mobile / web / Function / automatisation).
- Toute transition passe par une seule Cloud Function callable qui vérifie les droits et écrit statut + historique
  de façon atomique (transaction) — fin des écritures Firestore de statut directes depuis le client.

**Taille relative :** L

---

## Phase 2 — Extension du dictionnaire métier + moteur de documents

**Pourquoi ensuite** : extension directe de l'infrastructure de métré déjà existante (12 métiers / 71 catégories /
451 champs) — logique de continuer sur cette base avant d'attaquer le multi-lot, qui aura lui-même besoin de ces
documents par lot.

- Pour chaque métier, compléter le dictionnaire au-delà des champs de métré : règles de validation par champ,
  étapes de préparation, checklists d'exécution, causes de non-conformité propres au métier, indicateurs métier.
- Versionner ce dictionnaire (chaque métier a un numéro de version de config, pour faire évoluer sans casser les
  chantiers déjà en cours avec l'ancienne version).
- Moteur de documents généralisé : au lieu du seul PDF de commande actuel, plusieurs modèles pilotés par config
  versionnée (pas du code Dart par template) — fiche de métré, bon de préparation, bon de commande, fiche
  d'intervention, rapport de pose, rapport d'autocontrôle, PV de réception, fiche de réserves, rapport SAV. Chaque
  document porte entreprise/client/chantier/lot/intervenants/dates/données métier/photos/signatures/statut/version.

**Taille relative :** L

---

## Phase 3 — Chantiers multi-lots

**Pourquoi ensuite** : gros changement de modèle de données ; n'a de sens qu'une fois le moteur de workflow
générique (Phase 1) posé, pour que chaque lot suive le même mécanisme de statut/historique sans dupliquer de
logique.

- Un chantier peut contenir plusieurs lots (ex. rénovation salle de bain = plomberie + électricité + étanchéité +
  carrelage + peinture + pose mobilier), chacun avec son métier, son responsable, son équipe, ses dates, son statut
  propre (moteur de la Phase 1).
- Dépendances entre lots (le carrelage ne démarre pas avant validation de l'étanchéité, etc.) : graphe de
  dépendances simple par lot, blocage automatique tant que la dépendance amont n'est pas validée.
- Adapter les écrans existants pour naviguer par lot là où c'est pertinent, sans dupliquer d'écrans — réutilisation
  du moteur de workflow générique.

**Taille relative :** XL

---

## Phase 4 — Planner v2 (dépendances, ressources, congés)

**Pourquoi ensuite** : a besoin des lots multi-métier (Phase 3) pour afficher les dépendances et détecter les
incohérences de planning.

- Écran de saisie des indisponibilités (congés, maladie, formation, absences partielles, journées non travaillées)
  — le modèle de données existe déjà côté Planner v1, il ne manque que l'écran de saisie.
- Affichage des dépendances entre lots dans la grille + signalement des incohérences (pose planifiée avant la fin
  d'une dépendance amont).
- Détection des conflits de ressources (équipe engagée sur deux lots en même temps), liste des chantiers non
  affectés, historique des replanifications (s'appuie sur `statusHistory`).
- Champ matériel requis par chantier/lot (donnée + affichage dans le Planner, sans construire un module de stock
  complet à ce stade).

**Taille relative :** M

---

## Phase 5 — Expérience terrain (temps passé, non-conformité, circuit de validation)

**Pourquoi ensuite** : le circuit de validation dépend du moteur de workflow (Phase 1) ; le rapport
d'autocontrôle/PV de réception s'appuie sur le moteur de documents (Phase 2).

- Module de temps passé côté poseur : départ dépôt, arrivée chantier, début intervention, pause, reprise, fin,
  temps de trajet vs temps de travail, nombre de collaborateurs, commentaire.
- Causes de non-conformité structurées (liste fermée obligatoire + texte libre optionnel) : erreur de métré,
  erreur de commande, produit manquant/endommagé, défaut fournisseur, erreur de pose, support non conforme, oubli
  matériel, absence client, intempéries, autre. Remplace/complète le champ "raison" libre actuel.
- Circuit de validation : poseur soumet le rapport → responsable vérifie → valide (clôture) ou retourne au poseur
  → clôture ou création de SAV. Nouveau sous-workflow branché sur le moteur de la Phase 1.

**Taille relative :** L

---

## Phase 6 — Tableau de bord dirigeant (KPIs)

**Pourquoi en fin de chaîne technique** : dépend fortement de `statusHistory` (Phase 1) pour les délais moyens, et
du temps réel/non-conformité (Phase 5) pour plusieurs indicateurs — c'est la synthèse de tout ce que les phases
précédentes produisent.

- Délais moyens entre chaque transition (création→prise en charge, prise en charge→métré, métré→préparation,
  préparation→planification, planification→clôture).
- Chantiers bloqués depuis plus de X jours, taux de surcharge, charge par équipe, temps estimé vs réel, taux de
  clôture au premier passage, taux de non-conformité, causes principales de blocage, taux de SAV, taux de paiement
  à la clôture.
- Performance par métier / par équipe / par agence (si la notion d'agence est ajoutée plus tard).
- Implémentation : agrégats pré-calculés (documents de stats mis à jour par Cloud Function déclenchée sur
  écriture) plutôt que des requêtes Firestore coûteuses recalculées à chaque affichage.

**Taille relative :** M

---

## Phase 7 — Validation des 12 métiers & lancement

**Pourquoi en dernier** : phase de validation produit, pas de développement — n'a de sens qu'une fois les briques
techniques (Phases 1 à 6) posées pour chaque métier.

- Matrice de maturité par métier : dictionnaire complet, champs validés, règles de validation, préparation,
  checklist, causes, documents, indicateurs, tests automatisés, tests terrain, validation par un professionnel.
- Campagne de test terrain par métier : 1 professionnel référent, 3 à 5 dossiers réels, couvrant chantier simple /
  complexe / multi-lots / avec problème / clôture complète / SAV éventuel.
- Gate de lancement : aucun blocage critique, aucun contournement papier/Excel/WhatsApp nécessaire pour terminer un
  dossier de bout en bout.

**Taille relative :** M (mais étalée dans le temps — dépend de la disponibilité des professionnels référents)

---

## Vue synthétique des dépendances

```
Phase 0 (sécurité)
   ↓
Phase 1 (moteur workflow + historique)
   ↓
Phase 2 (dictionnaire étendu + moteur documents)
   ↓
Phase 3 (multi-lots)
   ↓
Phase 4 (Planner v2)          Phase 5 (terrain : temps, non-conf., validation)
        ↘                              ↙
              Phase 6 (dashboard KPIs)
                       ↓
              Phase 7 (validation 12 métiers + lancement)
```

Phases 4 et 5 peuvent être menées en parallèle (sessions distinctes) une fois la Phase 3 posée, puisqu'elles ne
dépendent pas l'une de l'autre — mais toutes deux alimentent le dashboard de la Phase 6.
