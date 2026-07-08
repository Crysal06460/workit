# RAPPORT DESIGN COMPLET — WorkIt

> **Date :** 8 juillet 2026  
> **Analyse réalisée sur :** branche `team-work/equipe-2-design`  
> **Finalité :** Audit complet de l'identité visuelle, du thème, des widgets, écrans, assets et références de design.

---

## TABLE DES MATIÈRES

1. [IDENTITÉ VISUELLE ET TON GÉNÉRAL](#1-identité-visuelle-et-ton-général)
2. [THÈME PRINCIPAL — `lib/core/theme/`](#2-thème-principal---libcoretheme)
3. [DESIGN SYSTEM — `lib/core/workit_design_system.dart`](#3-design-system---libcoreworkit_design_systemdart)
4. [WIDGETS RÉUTILISABLES](#4-widgets-réutilisables)
5. [ÉCRANS ET LEUR STYLE VISUEL](#5-écrans-et-leur-style-visuel)
6. [FICHIERS DE RÉFÉRENCE — DOSSIER `Ref/`](#6-fichiers-de-référence---dossier-ref)
7. [PROTOTYPE HTML ONBOARDING](#7-prototype-html-onboarding)
8. [POLICES, ICÔNES ET ASSETS](#8-polices-icônes-et-assets)
9. [DÉPENDANCES — `pubspec.yaml`](#9-dépendances---pubspecyaml)
10. [SYNTHÈSE ET RECOMMANDATIONS](#10-synthèse-et-recommandations)

---

## 1. IDENTITÉ VISUELLE ET TON GÉNÉRAL

### Ton
- **Professionnel et moderne** — l'application cible les artisans et PME du second œuvre (menuiserie, plomberie, électricité, etc.)
- **Sobre mais coloré** — le fond est majoritairement clair (`#F9FAFB`) avec des accents de couleur franche (bleu `#2563EB` dominant)
- **Francophone** — toute l'interface est en français, y compris les statuts, libellés et messages
- **Orienté données** — nombreuses cartes, statuts, indicateurs chiffrés (badges, stats rows, filtres)
- **Dark mode hérité** — certains écrans pré-onboarding (`WelcomeScreen`, `SelectMetierScreen`, `PlanSelectionScreen`, `SignInScreen`, `SettingsScreen`) utilisent encore un fond sombre `#07090D` avec un accent vert `#00E676`. Ce design sombre semble être un vestige d'une version antérieure, coexistant avec le nouveau design clair unifié.

### Impression générale
L'application a subi une **refonte récente** (cf. commit `7518e66` : "Onboarding clair complet + nettoyage thème sombre résiduel côté commercial"). Le design clair Material 3 est désormais le standard pour l'onboarding et les écrans métier (Commercial, Métreur, Poseur, Admin). Le design sombre persiste sur les écrans de pré-onboarding (welcome, sélection métier, plan, etc.).

---

## 2. THÈME PRINCIPAL — `lib/core/theme/`

### 2.1 `app_colors.dart` — Palette complète

#### Couleur primaire
| Rôle | Code Hex |
|------|----------|
| Primary (bleu) | `#2563EB` |
| Primary Dark | `#1D4ED8` |
| Primary Light | `#EFF6FF` |

#### Couleurs sémantiques
| Rôle | Couleur | Light |
|------|---------|-------|
| Success (vert) | `#059669` | `#ECFDF5` |
| Warning (orange/jaune) | `#D97706` | `#FFFBEB` |
| Danger (rouge) | `#DC2626` | `#FEF2F2` |
| Purple | `#7C3AED` | `#F5F3FF` |
| Amber | `#92400E` | `#FEF3C7` |

#### Échelle de gris (neutres)
| Nuance | Code |
|--------|------|
| grey50 | `#F9FAFB` |
| grey100 | `#F3F4F6` |
| grey200 | `#E5E7EB` |
| grey300 | `#D1D5DB` |
| grey400 | `#9CA3AF` |
| grey500 | `#6B7280` |
| grey600 | `#4B5563` |
| grey700 | `#374151` |
| grey800 | `#1F2937` |
| grey900 | `#111827` |

#### Surfaces
| Rôle | Code |
|------|------|
| Background | `#F9FAFB` (identique grey50) |
| Surface | `#FFFFFF` |
| Card Border | `#F3F4F6` (identique grey100) |

#### Couleurs par rôle métier
| Rôle | Couleur |
|------|---------|
| Commercial | `#2563EB` (primary) |
| Métreur / Études | `#7C3AED` (purple) |
| Poseur / Technicien | `#059669` (success/vert) |
| Admin/Gérant | `#6366F1` (indigo, défini dans le code des écrans) |

#### Couleurs de statuts (badges)
| Statut | Fond | Texte |
|--------|------|-------|
| En attente | `#FFFBEB` | `#D97706` |
| Métré programmé | `#F5F3FF` | `#7C3AED` |
| À commander | `#FEF3C7` | `#92400E` |
| À planifier | `#EFF6FF` | `#1D4ED8` |
| En pose | `#ECFDF5` | `#059669` |
| Terminé | `#F3F4F6` | `#6B7280` |
| Clôturé | `#FEE2E2` | `#991B1B` |
| Problème chantier | `#FEF2F2` | `#DC2626` |

### 2.2 `app_theme.dart` — Thème Material 3

| Paramètre | Valeur |
|-----------|--------|
| Version Material | **3** (`useMaterial3: true`) |
| Seed Color | `#2563EB` (primary) |
| Scaffold Background | `#F9FAFB` |

#### AppBar
- Background : `#FFFFFF` (surface)
- Foreground : `#111827` (grey900)
- **Elevation : 0** (flat design)
- `scrolledUnderElevation: 0`
- `centerTitle: false` (titre à gauche)
- Titre : `fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5`
- Status bar : icônes sombres sur fond clair

#### Cards
- Background : `#FFFFFF`
- **Elevation : 0**
- `margin: EdgeInsets.zero`
- **Border radius : 16** (arrondi généreux)
- Bordure : `#F3F4F6` (cardBorder)

#### Boutons
| Type | Background | Texte | Padding | Border Radius |
|------|-----------|-------|---------|---------------|
| Elevated (primary) | `#2563EB` | Blanc, w700, 15px | H:20, V:14 | **12** |
| Outlined | Transparent | `#374151`, w600, 13px | H:16, V:10 | **10** |

#### Input fields
- Fond : `#F9FAFB`
- Border radius : **12**
- Focus : bordure bleue 2px
- Padding interne : H:16, V:13
- Hint : `#9CA3AF`, 14px

#### TabBar
- Label actif : `#2563EB`, w700, 13px
- Label inactif : `#6B7280`, w500, 13px
- Indicator : `#2563EB`

#### BottomNavigationBar
- Background : `#FFFFFF`
- Selected : `#2563EB`
- Unselected : `#9CA3AF`
- Type : fixed
- Label : 10px

#### Chips
- Background : `#F3F4F6`
- Selected : `#EFF6FF`
- Label : 12px, w600
- Border radius : **20** (pills arrondies)
- Padding : H:10, V:4

#### TextTheme
| Style | Size | Weight | Spacing |
|-------|------|--------|---------|
| displayLarge (titres héro) | 28 | w900 | -1 |
| titleLarge | 20 | w800 | -0.5 |
| titleMedium | 16 | w700 | normal |
| titleSmall | 14 | w600 | normal |
| bodyLarge | 15 | w400 | normal |
| bodyMedium | 13 | w400 | normal |
| bodySmall | 12 | w400 | normal |
| labelSmall (caps) | 11 | w700 | +0.6 |

---

## 3. DESIGN SYSTEM — `lib/core/workit_design_system.dart`

Fichier **barrel** qui exporte l'ensemble du design system :

```dart
export 'theme/app_colors.dart';
export 'theme/app_theme.dart';
export 'widgets/wi_status_badge.dart';
export 'widgets/wi_devis_card.dart';
export 'widgets/wi_stat_row.dart';
export 'widgets/wi_filter_pills.dart';
export 'widgets/wi_cta_button.dart';
export 'widgets/wi_bottom_nav.dart';
```

**Convention de nommage** : préfixe `Wi` (WorkIt) pour tous les widgets du design system.

---

## 4. WIDGETS RÉUTILISABLES

### 4.1 `lib/core/widgets/` (Design System officiel)

#### `WiCtaButton` — Bouton CTA pleine largeur
- Pleine largeur
- Background : primary (`#2563EB`) par défaut, personnalisable via `color`
- Border radius : **14**
- Texte blanc, 15px, **w700**, `letterSpacing: -0.2`
- Icône optionnelle à gauche
- Padding vertical : 15px
- Utilise `Material` + `InkWell` pour le ripple

#### `WiDevisCard` — Carte de devis
- Background : `#FFFFFF`
- Border radius : **16**
- **Ombre subtile** : `black@4%`, blur 8, offset Y 2
- **Bordure gauche** optionnelle pour le rôle métier (accent color)
- Bordure complète bleue si `isActive`
- Titre : 15px, w700
- Sous-titre : 12px, grey400
- Montant : 16px, **w800**
- Badge de statut intégré (`WiStatusBadge`)
- **Step dots** pour progression (7px, ronds, succès/primary/gris)
- 2 boutons d'action optionnels (primary / danger / outlined)
- Divider entre contenu et actions
- Padding interne : 15px

#### `WiStatusBadge` — Badge de statut
- Border radius : **20** (pill)
- Couleur fond/texte selon statut (voir palette §2.1)
- Label en français : 'En attente', 'Métré prog.', 'À commander', 'À planifier', 'En pose', 'Terminé', 'Problème'
- Texte : 11px, **w700**
- Padding : H:10, V:4
- Enum `DevisStatus` avec factory `fromString()` pour conversion Firestore
- Fonction utilitaire `urgencyBorderColor()` pour couleur de bordure par statut

#### `WiStatRow` — Ligne de statistiques
- 2-3 cartes statistiques équitablement espacées (8px entre)
- Chaque carte :
  - Fond blanc, border radius **14**
  - Bordure cardBorder, ombre subtile (black@3%, blur 4, Y 1)
  - Valeur : 22px, **w800**, couleur selon stat
  - Label : 11px, w500, grey400, centré, max 1 ligne

#### `WiFilterPills` — Filtres horizontaux scrollables
- Scroll horizontal
- Hauteur : 36px
- Padding horizontal : 20px
- Espacement : 7px
- Pills : padding H:13 V:6
- Actif : fond couleur primary, texte blanc, border radius **20**
- Inactif : fond blanc, bordure grey200, texte grey600
- Animation `AnimatedContainer` (180ms)

#### `WiBottomNav` — Barre de navigation inférieure
- Fond blanc, bordure haut grey200
- Hauteur : 56px
- Icônes : 24px (active = filled, inactive = outlined)
- Badge de notification : cercle rouge `#DC2626` 16px, texte blanc 9px w800
- Labels : 10px, w600
- Couleur active personnalisable (défaut primary)

### 4.2 `lib/screens/widgets/` (Widgets spécifiques aux écrans)

#### `DynamicDropdownField`
- Style : fond sombre (`white@4%`), bordure `white12`, border radius **12**
- Label : blanc 70% d'opacité
- Navire dropdown : fond `#0F1422`, texte blanc
- Flèche : `keyboard_arrow_down` blanc 70%
- Padding bas : 10px

> **Note** : Ce widget semble conçu pour un contexte dark uniquement (pré-onboarding). Il n'est pas aligné avec le design system clair.

---

## 5. ÉCRANS ET LEUR STYLE VISUEL

### 5.1 `OnboardingScreen` (Nouveau design clair)
- **Background** : `#F9FAFB`
- **10 pages** dans une machine à états : Splash (0) → Slides (1) → Entry (2) → Trades (3) → Company (4) → Role (5) → Account (6) → Success (7) → Join (8) → JoinOk (9)
- **Splash** : fond `#2563EB` (bleu primaire), logo blanc sur fond `white24`, titre "WorkIt" 34px w800 letter-spacing -1
- **Slides** : 3 slides de valeur, icône 110x110 dans un container radius **30**, fond coloré (primaryLight/purpleLight/successLight), titre 22px w800, sous-titre 14px grey400
- **Entry** : cartes avec icône 54x54 radius **15**, texte 14px w700, chevron droit, border radius **20**
- **Trades** : grille 3 colonnes, cellules carrées radius **14**, sélection = fond `#EFF6FF` + bordure `#2563EB`
- **Company** : champs de formulaire, grille taille entreprise 2x2
- **Role** : cartes horizontales avec icône 46x46 radius **13**, check rond
- **Account** : formulaire inscription (prénom, nom, email, mot de passe, CGU)
- **Success** : cercle vert `#ECFDF5` avec icône check `#059669`, récapitulatif
- **Join** : code 6 chiffres, boîtes 46x58 radius **12**
- **Boutons** : `pri-btn` = primary, 14px border radius, 15px padding; `sec-btn` = blanc bordé

### 5.2 `EntryScreen` (Retour/sign-in rapide)
- Fond clair `#F9FAFB`
- Logo 64x64 radius **18**, fond `#2563EB`
- Titre accueil 28px w800
- Bouton connexion primary 14px radius, 16px padding vertical
- Lien création de compte en dessous

### 5.3 `WelcomeScreen` (Pré-onboarding — design sombre)
- **Background** : `#07090D` (très sombre)
- **Accent** : `#00E676` (vert néon)
- Header : gradient bleu foncé `#0E1726` → `#0A1A2F`, glow radial vert 18%
- Logo 84x84 radius **20**, glow vert 25px
- Titre blanc w900
- Avantages : cartes fond `#0E1220`, bordure blanc 5%
- CTA : `#00E676` sur fond vert, texte noir w800

### 5.4 `SignInScreen` (Design hybride)
- **Background** : `#07090D` (sombre)
- Barre supérieure transparente, icône retour blanche
- Formulaire sur fond sombre
- Bouton primary `#2563EB` avec texte blanc
- Checkbox "Se souvenir de moi"

### 5.5 `SelectMetierScreen` (Sombre)
- Fond `#07090D`
- Gradient header `#0E1726` → `#0A1A2F`
- Accent `#00E676`

### 5.6 `PlanSelectionScreen` (Sombre)
- Fond `#07090D`
- Accent `#00E676`
- Cartes d'abonnement avec sélection

### 5.7 `TrialActivationScreen` (Sombre)
- Fond `#07090D`
- Gradient card `#0E1726` → `#0A1A2F`
- Liste de puces, CTA vert `#00E676`

### 5.8 `SettingsScreen` (Sombre)
- Fond `#07090D`
- Switch FaceID, accent `#00E676`
- Cartes paramètres : fond `white@4%`, bordure `white12`, border radius **16**

### 5.9 `AdminHomeScreen` (Clair)
- Fond `#F9FAFB`
- AppBar surface blanche
- 3 tabs : Tableau de bord, Équipe, Entreprise
- TabBar standard (primary, w700, 13px)

### 5.10 `CommercialHomeScreen` (Clair)
- Fond `#F9FAFB`
- AppBar blanche
- Avatar cercle 40px fond `#2563EB`
- **7 filtres tabulaires** en pills scrollables (Tous, En attente, Devis prog., À commander, À planifier, En pose, Terminés)
- Stats row (3 cartes : En attente/En cours/Terminés)
- Barre de recherche
- Bouton "Ajouter un devis" (WiCtaButton)
- Bottom nav maison : Accueil, Devis, Agenda, Réglages

### 5.11 `MetreurHomeScreen` (Clair)
- Fond `#F9FAFB`
- AppBar blanche, titre "Gestion chantiers"
- Avatar cercle 40px fond `#7C3AED` (rôle métreur)
- **6 filtres** : Tous, En attente, En cours, À commander, À planifier, À clôturer
- Stats chips : Urgent (danger), À commander (warning), À planifier (purple)
- Bottom nav : Accueil, Chantiers, Agenda, Réglages
- Modals bottom sheet fond blanc radius **20** haut

### 5.12 `PoseursHomeScreen` (Clair)
- Fond `#F9FAFB`
- AppBar transparente, centrée, titre 24px
- 2 tabs : "À faire" et "Historique" dans un container arrondi radius **20**
- Bottom nav absente (pas d'actions complexes)
- Cartes chantier fond blanc border radius **16**

### 5.13 Autres écrans clairs
- `AdminDashboardTab`, `AdminTeamTab`, `AdminCompanyTab` : utilisent le thème clair standard
- `AccountSetupScreen`, `FinalSaveScreen`, `JourneySelectionScreen` : écrans de transition (design sombre ou clair selon contexte)
- `InviteTeamScreen`, `InviteActivationScreen`, `JoinWorkspaceScreen` : intégration onboarding/équipe

---

## 6. FICHIERS DE RÉFÉRENCE — DOSSIER `Ref/`

| Fichier | Type | Description |
|---------|------|-------------|
| `Capture d'écran 2026-06-29 à 16.07.09.png` | Image | Capture d'écran de référence (design clair) |
| `Capture d'écran 2026-06-29 à 16.07.16.png` | Image | Capture d'écran de référence |
| `Capture d'écran 2026-06-29 à 16.07.24.png` | Image | Capture d'écran de référence |
| `AdobeColor-Mon thème de couleurs (1).jpeg` | JPEG | **Palette Adobe Color** — 1600×2400px, export ICC sRGB |

Les captures d'écran serviront de références visuelles pour les maquettes. Le fichier Adobe Color contient la palette source de l'application, probablement harmonisée par le designer dans Adobe Color.

---

## 7. PROTOTYPE HTML ONBOARDING

**Fichier** : `workit_onboarding_prototype.html` (517 lignes, HTML/CSS/JS)

### Caractéristiques
- **Simulateur mobile** : téléphone 375×680px, border radius 44px, fond `#1a1a2e`
- **9 écrans** : Splash → Slides (3) → Entry → Trades → Company → Role → Account → Success → Join
- **Navigation** : dots + labels sous le téléphone
- **Icônes** : `@tabler/icons-webfont` v3.9 (Tabler Icons)

### Palette CSS (identique à `AppColors`)
- `--blue:#2563EB`, `--blue-l:#EFF6FF`
- `--purple:#7C3AED`, `--purple-l:#F5F3FF`
- `--green:#059669`, `--green-l:#ECFDF5`
- `--warn:#D97706`, `--warn-l:#FFFBEB`
- `--red:#DC2626`, `--red-l:#FEF2F2`
- Grille complète `g50` à `g900`

### Design des pages

**Splash** : fond `--blue`, logo white24, titre blanc 32px w800, sous-titre blanc 70%

**Slides** : 3 slides avec icône 100×100px radius 28, fond varié (blue-l/purple-l/green-l), titre 21px w800, pips animés

**Entry** : fond `--g50`, page-h1 26px w800, cartes radius 20, icône 54px radius 15, chevron droit

**Trades** : grille 3 colonnes, cellules carrées radius 14, check bleu, tags sélectionnés en `--blue-l`

**Company** : inputs radius 12, grille taille 2×2, chiffres 18px w800

**Role** : cartes avec icône 46px radius 13, check rond coloré

**Account** : inputs radius 12, checkbox CGU, bouton CTA

**Success** : cercle vert 84px, titre "Votre espace est prêt !", récap en carte blanche

**Join** : code 6 boîtes 46×58px, bordure bleue sur boîte active

### Boutons partagés
- `.pri-btn` : `--blue`, texte blanc, radius 14, 15px padding, w700
- `.sec-btn` : blanc, bordure `--g200`, radius 14

### Données du prototype (JSON-like dans le JS)
- 12 métiers du second œuvre
- 4 tailles d'entreprise
- 4 rôles (admin, commercial, métreur, poseur) avec couleurs dédiées
- 3 slides avec icônes, fonds, titres et sous-titres

---

## 8. POLICES, ICÔNES ET ASSETS

### Polices
- **Aucune police personnalisée déclarée** dans `pubspec.yaml`
- L'application utilise la police système par défaut : `-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif` (dans le prototype HTML)
- En Flutter, c'est la **police par défaut de Material Design** (`Roboto` sur Android, `San Francisco` sur iOS)

### Icônes
- **Material Icons** (via `Icons.*`) — utilisées dans tous les écrans Flutter
- **Tabler Icons** (`@tabler/icons-webfont` v3.9) — utilisées dans le prototype HTML uniquement
- **Cupertino Icons** — déclaré dans `pubspec.yaml` (`cupertino_icons: ^1.0.8`) pour les icônes iOS

### Assets
**Déclarés dans `pubspec.yaml`** :
```
assets:
  - assets/dictionnaire_workit/workit_dictionary.json
  - assets/dictionnaire_workit/metiers_workit.json
  - assets/icons/
```

**Dictionnaires** (dans `assets/dictionnaire_workit/`) :
- `workit_dictionary.json` — dictionnaire général WorkIt
- `metiers_workit.json` — dictionnaire des métiers

**Icônes** (dans `assets/icons/`) : 28 fichiers de type "sans extension" (fichiers binaires/noms sans extension) répartis en 3 dossiers :
- `menuiseries/` (14 fichiers) : PORTE, FIXE, OF1, OF2, OB1, OB2, SOUFL, COUL2SUR2, COUL3SUR3, COUL4SUR2, GAL1SUR1, GAL2SUR1, GAL2SUR2, FIXE2PART, 1F+2OF, 1F+2OF+1F
- `protections/` (6 fichiers) : MOUS1H, MOUS1V, MOUS2H, GARAGBAS, GARAGSEC, VRTRADI, VRRENO
- `exterieur/` (5 fichiers) : PORTILLON, VOLETBAT1, VOLETBAT2, PORTAILCOUL, PORTAILBATT

Ces fichiers semblent être des **SVG** ou des icons personnalisées pour les types de menuiseries, protections et extérieurs. Le dossier `assets/icons/` est déclaré complet via le pattern `assets/icons/`.

---

## 9. DÉPENDANCES — `pubspec.yaml`

### Versions
- SDK Dart : `^3.9.2`
- Version app : `1.0.0+1`
- `publish_to: 'none'` (projet privé)

### Dépendances principales
| Package | Version | Usage |
|---------|---------|-------|
| `flutter` | SDK | Framework |
| `cupertino_icons` | ^1.0.8 | Icônes iOS |
| `firebase_core` | ^3.15.2 | Initialisation Firebase |
| `cloud_firestore` | ^5.6.12 | Base de données Firestore |
| `firebase_auth` | ^5.7.0 | Authentification |
| `firebase_storage` | ^12.4.10 | Stockage fichiers |
| `cloud_functions` | ^5.0.4 | Cloud Functions |
| `file_picker` | ^6.1.1 | Sélection fichiers |
| `image_picker` | ^1.0.7 | Sélection photos |
| `path` | ^1.8.3 | Manipulation chemins |
| `http` | ^1.2.2 | Requêtes HTTP |
| `shared_preferences` | ^2.2.2 | Stockage local |
| `url_launcher` | ^6.3.2 | Liens externes |
| `local_auth` | ^3.0.0 | FaceID / Biométrie |
| `flutter_svg` | ^2.0.10 | Affichage SVG |
| `firebase_messaging` | ^15.0.0 | Notifications push |
| `pdf` | ^3.11.1 | Génération PDF |
| `printing` | ^5.13.1 | Impression PDF |

### Dev dependencies
| Package | Version |
|---------|---------|
| `flutter_test` | SDK |
| `flutter_lints` | ^5.0.0 |

### Assets déclarés
- `assets/dictionnaire_workit/workit_dictionary.json`
- `assets/dictionnaire_workit/metiers_workit.json`
- `assets/icons/` (dossier complet)

### Polices
- **Aucune section `fonts:`** dans `pubspec.yaml` — utilisation de la police système Material

---

## 10. SYNTHÈSE ET RECOMMANDATIONS

### Forces du design actuel
1. **Cohérence Material 3** : le thème clair est bien structuré avec `ColorScheme.fromSeed`
2. **Palette sémantique riche** : couleurs par statut et par rôle métier
3. **Design system modulaire** : widgets préfixés `Wi` bien séparés et documentés
4. **Éléments arrondis cohérents** : radius 12 (boutons/inputs), 14 (stats/chips), 16 (cartes), 20 (pills/badges)
5. **Typographie hiérarchisée** : du displayLarge (28px w900) au labelSmall (11px w700)

### Points d'attention
1. **Dualité clair/sombre** : 3 écrans de pré-onboarding (WelcomeScreen, SelectMetierScreen, TrialActivationScreen, PlanSelectionScreen, SettingsScreen, SignInScreen) utilisent un design sombre ancien (`#07090D` + `#00E676`) qui n'est pas aligné avec le nouveau design clair (`#F9FAFB` + `#2563EB`)
2. **Widget orphelin** : `DynamicDropdownField` dans `screens/widgets/` est conçu pour le mode sombre et n'utilise pas le design system clair
3. **Polices** : aucune police personnalisée — l'identité typographique repose entièrement sur la police système par défaut
4. **Icônes assets** : les fichiers dans `assets/icons/` n'ont pas d'extension claire — vérifier si `flutter_svg` peut les charger correctement
5. **Bottom navs** : Commercial et Métreur ont leur propre implémentation de bottom nav au lieu d'utiliser `WiBottomNav` (même structure mais code dupliqué)

### Recommandations
1. Uniformiser tous les écrans sous le thème clair (migrer les écrans sombres restants)
2. Ajouter des polices personnalisées (Google Fonts via plugin Flutter) pour renforcer l'identité
3. Centraliser les bottom navs dans `WiBottomNav` (remplacer les duplications dans Commercial et Métreur)
4. Nettoyer `DynamicDropdownField` ou l'adapter au design system clair
5. Vérifier le format des fichiers assets icons/ (SVG ?) et s'assurer que `flutter_svg` peut les charger
6. Ajouter la palette Adobe Color comme référence dans un fichier `.ase` ou `.json` exploitable
7. Considérer l'ajout d'un thème sombre optionnel (dark mode) pour les écrans métier

---

*Fin du rapport — 8 juillet 2026*
