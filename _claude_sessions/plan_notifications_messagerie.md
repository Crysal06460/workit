# Plan — Notifications complètes, agenda live, messagerie par chantier

**Créé le :** 2026-07-29
**Statut global :** Terminé et déployé. Toutes les étapes de code (0 à 7) + correction du bug `infoRequest`/`metreurNote` + CLI Firebase installé + Cloud Functions et règles Firestore déployées en production (workit-1daa1). Reste seulement l'étape 0.5 optionnelle (push web) et les tests manuels en conditions réelles.

Plan complet approuvé par Antoine. Ce fichier est la checklist persistante : à chaque étape terminée et validée, on coche ici. Si une nouvelle session Claude Code reprend ce projet, lire ce fichier en premier pour savoir où en est le travail.

## Contexte

Objectif : notification à chaque étape/action sur un chantier (avec nom du client), agenda commercial mis à jour en temps réel dès qu'une date de RDV/pose est posée, et une messagerie interne dédiée à chaque chantier (texte + photos) entre commercial/métreur/poseurs/admin, ouverte dès la création du dossier.

Contrainte : dev sur PC Windows sans droits admin, seule cible testable = `flutter run -d chrome`.

Détails complets de chaque étape : voir le plan original dans `C:\Users\antoine.QUINTANE\.claude\plans\misty-watching-flurry.md` (peut ne pas être accessible depuis un autre PC — la checklist ci-dessous est la source de vérité portable).

## Checklist

- [x] **Étape 0** — Persister `workit_user_role` dans SharedPreferences (`auth_navigation_service.dart`)
- [x] **Étape 1** — Notifs manquantes dans `onDevisStatusChange` : statut `En cours` (RDV métré) + changement de `metreurNote` (`functions/index.js`)
- [x] **Étape 2** — Payload `data` (workspaceId/devisId/type) sur `sendNotification` pour le deep-link (`functions/index.js`)
- [x] **Étape 3** — Tap sur notif → ouvre l'app au bon écran de rôle (`navigatorKey`, `onMessage`/`onMessageOpenedApp`/`getInitialMessage` dans `main.dart`)
- [x] **Étape 4** — Écran Agenda en direct (`agenda_screen.dart`, nouveau) + réparation des boutons "Agenda"/"Réglages" du menu du bas commercial
- [x] **Étape 5** — Règles Firestore + schéma pour `messages` (sous-collection de `devis`)
- [x] **Étape 6** — Écran de chat par chantier (`chantier_chat_screen.dart`, nouveau) + point d'entrée sur les 4 vues détail (commercial/métreur/poseur/admin)
- [x] **Étape 7** — Cloud Function `onChantierMessageCreated` (notif sur nouveau message de chat)
- [ ] **Étape 0.5 (optionnelle)** — Service worker web + clé VAPID pour activer le push en arrière-plan/app fermée sur Chrome (réglage ponctuel console Firebase, sans droits admin)

## Déploiement (une fois les étapes Cloud Functions/règles prêtes)
- `firebase deploy --only functions`
- `firebase deploy --only firestore:rules`

## Journal
- 2026-07-29 : Plan validé par Antoine, démarrage Étape 0.
- 2026-07-29 : Étapes 0 à 7 codées et vérifiées (`flutter analyze` 0 erreur sur tout le projet — 204 warnings/infos préexistants ; `flutter build web` réussi).
- 2026-07-29 : Corrigé le bug `infoRequest`/`metreurNote` dans `admin_dashboard_tab.dart` (l'admin lisait l'ancien champ mort au lieu de `metreurNote`, priorité donnée à `metreurNote` avec fallback `infoRequest` legacy).
- 2026-07-29 : CLI Firebase installé (`npm install -g firebase-tools`, v15.24.0, sans droits admin — prefix npm déjà sous AppData utilisateur). `npm install` fait dans `functions/` (node_modules absent jusque-là).
- 2026-07-29 : Corrigé un blocage de lint spécifique à ce poste Windows — `core.autocrlf=true` convertissait `functions/index.js` en CRLF, ce que le predeploy `npm run lint` refuse (règle `linebreak-style`, affecte TOUT le fichier, pas seulement mes ajouts). Fichier renormalisé en LF + ajout de `.gitattributes` (`functions/*.js text eol=lf`) pour que ça ne revienne pas au prochain checkout. Puis 3 vraies erreurs de lint sur mon code corrigées (JSDoc manquant, 2 lignes trop longues).
- 2026-07-29 : Antoine authentifié (`firebase login` depuis un vrai terminal, hors Claude Code — la connexion interactive ne peut pas passer par l'outil non-interactif). Compte `cbeylet06@gmail.com`, projet `workit-1daa1` confirmé courant.
- 2026-07-29 : **Déployé en production** : `firebase deploy --only functions` (onDevisStatusChange mis à jour, onChantierMessageCreated créée) puis `firebase deploy --only firestore:rules` (sous-collection `messages`). Les deux déploiements réussis sans erreur.

## Reste à faire
- Tester en conditions réelles (`flutter run -d chrome`) : envoi/réception de message, badge non-lu, agenda live, notifs "En cours"/`metreurNote`/chat.
- Étape 0.5 (optionnelle, non faite) : service worker web + clé VAPID pour activer le tap sur notif en arrière-plan/app fermée sur Chrome.
- Note : `firebase-functions` et le runtime Node 20 sont signalés comme datés par le CLI lors du déploiement (avertissements, pas des erreurs) — à mettre à jour un jour, hors périmètre de cette session.
