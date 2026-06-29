---
name: "Agent Poseurs & UI/FCM"
description: "Responsable de la UI des Poseurs, AdminHomeScreen Dashboard, FCM Notifications, et migration Riverpod"
type: "implementation"
skills: ["flutter", "state-management", "notifications", "ui-ux"]
focusAreas:
  - "PoseursHomeScreen: UI complète (3 tabs Jour/Semaine/Liste) + données Firestore"
  - "AdminHomeScreen Dashboard: KPIs, stats équipe, activité"
  - "FCM: implémentation notifications push"
  - "State Management: Migration de StatefulWidget+setState → Riverpod"
priority: "P1"
estimatedEffort: "3-4 semaines"
dependencies: []
---

# Agent 1: Poseurs UI, AdminHomeScreen & FCM

## 🎯 Mission
Transformer les UI shells vides en écrans fonctionnels et mettre en place un state management moderne avec notifications push.

## 📋 Tâches Prioritaires

### 1️⃣ **PoseursHomeScreen** (Semaine 1)
- [ ] Lire les demandes de pose depuis Firestore (`workspaces/{id}/devis` + `status === 'À planifier'|'Posé'`)
- [ ] Implémenter tab **Jour**: planning daily (aujourd'hui) avec draggable tasks
- [ ] Implémenter tab **Semaine**: week view avec statut pose
- [ ] Implémenter tab **Liste**: list view filtrable par statut (À faire, En cours, Terminée)
- [ ] Ajouter bouton **Démarrer pose** + **Terminer pose** (validation avec date/heure)
- [ ] Photo terrain: intégrer camera + upload Storage

**Files to modify:**
- `lib/screens/poseurs_home_screen.dart` (réécriture 80%)
- Create `lib/models/pose_models.dart` (PoseTask, PoseDay, etc.)
- Create `lib/services/pose_service.dart`

### 2️⃣ **AdminHomeScreen Dashboard** (Semaine 2)
- [ ] Tab **Dashboard**: afficher KPIs
  - Nombre devis total / en cours / complétés
  - Nombre métreurs actifs / tâches assignées
  - Nombre poses complétées cette semaine
  - Chiffre généré (estimation vs réalisé)
- [ ] Charts: utiliser `fl_charts` (pie chart statuts, line chart trend)
- [ ] Tri/filtres: par period (jour, semaine, mois, custom)
- [ ] Réaltime: stream Firestore sur metrics

**Files to modify:**
- `lib/screens/admin_home_screen.dart`
- `lib/screens/admin_dashboard_tab.dart` (compléter)
- Create `lib/models/admin_models.dart`
- Create `lib/services/admin_service.dart`

### 3️⃣ **FCM Notifications** (Semaine 2)
- [ ] Ajouter `firebase_messaging` à `pubspec.yaml`
- [ ] Initialiser FCM dans `main.dart`
- [ ] Créer service `NotificationService` pour écouter messages entrants
- [ ] Afficher local notifications quand:
  - Commercial envoie nouvelle demande → Métreur notifié
  - Métreur accepte → Commercial notifié
  - Statut devis change → Poseur notifié
- [ ] Setup Cloud Functions triggers pour envoyer FCM tokens

**Files to create:**
- `lib/services/notification_service.dart`
- Update `functions/index.js` avec FCM send

### 4️⃣ **State Management: Riverpod Migration** (Semaine 3-4)
- [ ] Ajouter `flutter_riverpod` + `riverpod_generator` à pubspec.yaml
- [ ] Créer providers pour:
  - `workspaceProvider` (workspace actuel)
  - `userProvider` (user connecté)
  - `devisListProvider` (stream devis par statut)
  - `poseListProvider` (stream poses)
  - `authProvider` (auth state)
- [ ] Migrer CommercialHomeScreen → ConsumerWidget
- [ ] Migrer MetreurHomeScreen → ConsumerWidget
- [ ] Migrer PoseursHomeScreen → ConsumerWidget
- [ ] Migrer AdminHomeScreen → ConsumerWidget
- [ ] Supprimer useState / setState legacy

**Files to create:**
- `lib/providers/workspace_provider.dart`
- `lib/providers/auth_provider.dart`
- `lib/providers/devis_provider.dart`
- `lib/providers/pose_provider.dart`
- `lib/providers/notification_provider.dart`

## 🛠️ Stack & Dépendances
```yaml
dependencies:
  flutter_riverpod: ^2.4.0
  riverpod_generator: ^2.3.0
  firebase_messaging: ^14.6.0
  fl_charts: ^0.60.0
  camera: ^0.10.5
  image_picker: ^1.0.7
```

## 📝 Notes Techniques
- Préférer `StreamProvider` pour les données Firestore realtime
- Utiliser `StateNotifier` pour actions utilisateur (changement statut, etc.)
- FCM tokens à stocker dans `users/{uid}/fcmTokens` (array)
- Riverpod: garder `main.dart` simple avec `ProviderScope` wrapper

## ✅ Définition "Fait"
- UI fonctionnelle sur les 3 screens
- Notifications push testées
- Riverpod utilisé partout (zéro setState)
- KPIs affichés et à jour en realtime
