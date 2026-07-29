# Plan — Multi-métier : devis par élément + métré générique

**Créé le :** 2026-07-29
**Statut global :** Toutes les étapes de code terminées et vérifiées (`flutter analyze` 0 erreur, `flutter build web` OK). Reste le test manuel en conditions réelles (Chrome) par Christophe.

Checklist persistante. Détails complets dans le plan approuvé (peut ne pas être accessible depuis un autre poste — voir aussi `_claude_sessions/session_courante.md`). Si une nouvelle session reprend ce projet, lire ce fichier en premier.

## Contexte
Le dictionnaire (`assets/dictionnaire_workit/workit_dictionary.json`) contient déjà 12 métiers complets (menuiserie, plâtrerie/cloisons, électricité, chauffage/clim/VMC, plomberie, peinture, carrelage, cuisine, salle de bain/étanchéité, sols extérieurs, vitrerie, automatismes/portails), mais l'app ne permet de choisir qu'un seul métier (menuiserie) pour toute l'entreprise, et l'écran de métré est câblé en dur pour la menuiserie uniquement.

**Décision validée par Christophe** : le métier se choisit **par élément du devis** (chaque produit a son propre métier), pas pour tout le devis ni toute l'entreprise. Un même chantier peut mélanger fenêtre (menuiserie) + WC (plomberie).

## Checklist

### Étape 1 — Fondations partagées
- [x] `lib/core/dictionary_service.dart` (nouveau) : charge/parse le dictionnaire une fois, expose métiers/catégories/champs de métré
- [x] Champ `metierKey` ajouté à `_ProductFormData` (commercial_home_screen.dart) + miroir métreur (metreur_home_screen.dart)
- [ ] Widgets de champ générique (nombre/texte/dropdown/case à cocher) — reporté à l'étape 5, construits directement dans leur contexte d'usage

### Étape 2 — Commercial : métier par élément
- [x] Dropdown "Métier" en tête de chaque carte produit (`_productCard`), 12 choix, cascade catégorie/type/variante par ligne

### Étape 3 — Onboarding
- [x] `select_metier_screen.dart` réactivé avec les 12 métiers dynamiques (métier "principal" = valeur par défaut)
- [x] Réinséré dans le flux `create_workspace_screen.dart` (CreateWorkspace → SelectMetier → PlanSelection)

### Étape 4 — Contenu dictionnaire (métré), un métier à la fois
- [x] 1. menuiserie_aluminium (11 catégories)
- [x] 2. platrerie_isolation_cloisons (4 catégories)
- [x] 3. electricite_courants_faibles (5 catégories)
- [x] 4. chauffage_climatisation_ventilation (5 catégories)
- [x] 5. plomberie_sanitaire (7 catégories)
- [x] 6. peinture_revetements (5 catégories)
- [x] 7. carrelage_maconnerie_fine (5 catégories)
- [x] 8. cuisine_amenagement_interieur (5 catégories)
- [x] 9. salle_de_bain_etancheite (7 catégories)
- [x] 10. sols_exterieurs_amenagements (5 catégories)
- [x] 11. vitrerie_miroiterie (6 catégories)
- [x] 12. automatismes_portails (6 catégories)

**Vérification croisée automatique** : 12/12 métiers, 71 catégories, 451 champs de métré définis, 0 catégorie manquante, 0 clé en trop (script Node de contrôle exécuté).

### Étape 5 — Écran de métré générique
- [x] `measurement_form_screen.dart` : rendu dynamique par (métier, catégorie) — schéma visuel pour les ouvertures menuiserie (menuiseries_exterieures, portes_garage), liste générique (nombre/texte/dropdown/switch) pour toutes les autres catégories
- [x] Export PDF généralisé (les champs de métré s'affichent dynamiquement avec leur libellé + unité, plus de colonnes fixes)

### Étape 6 — Vérification
- [x] `flutter analyze` 0 erreur sur tout le projet (warnings/infos restants tous préexistants)
- [x] `flutter build web` réussi
- [ ] Test manuel Chrome non fait dans cette session (nécessite des identifiants/données de test réelles) — à faire par Christophe : créer un devis avec un élément menuiserie + un élément plomberie, vérifier les 2 fiches de métré côté métreur et le PDF généré

## Journal
- 2026-07-29 : Plan validé par Christophe (métier par élément, confirmé via question posée). Recherche des champs de métré effectuée pour les 12 métiers (fiches pro françaises, DTU, guides de pose) — résultats en mémoire de session, prêts à transcrire en étape 4.
