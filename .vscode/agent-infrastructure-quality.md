---
name: "Agent Infrastructure & Quality"
description: "Responsable Firestore Security, Tests, Mode Offline, Analytics, et features complètes Poseurs"
type: "infrastructure"
skills: ["firestore", "testing", "offline-first", "analytics", "backend"]
focusAreas:
  - "Firestore Security Rules (authentification, autorisation par rôle)"
  - "Unit Tests, Widget Tests, E2E Tests"
  - "Mode Offline (sync, conflict resolution)"
  - "Firebase Analytics & Event Tracking"
  - "Poseurs Features Complètes (planning realtime + photos + validation)"
  - "Gestion Abonnement Client (affichage trial/actif/expiré)"
priority: "P2"
estimatedEffort: "4-5 semaines"
dependencies:
  - "Agent 1 doit terminer Riverpod et PoseursHomeScreen avant"
---

# Agent 2: Infrastructure, Tests & Features Poseurs Avancées

## 🎯 Mission
Fortifier la plateforme avec sécurité, résilience, qualité et fonctionnalités métier complètes pour les poseurs.

## 📋 Tâches Prioritaires

### 1️⃣ **Firestore Security Rules** (Semaine 1)
Créer règles strictes par rôle + collection.

**À implémenter:**
- [ ] Authentification: `request.auth != null`
- [ ] **workspaces**: 
  - Lecture: admin OR (user.role IN creatorRoles)
  - Écriture: admin uniquement
- [ ] **workspaces/{id}/devis**:
  - Commercial: peut créer + lire propres devis + lire devis assignés métreur
  - Métreur: peut lire devis assignés + modifier status/measurements
  - Poseur: peut lire devis statut "À planifier"/"Posé"
- [ ] **workspaces/{id}/team**:
  - Lecture: tous les members
  - Écriture: admin uniquement
- [ ] **users/{uid}**:
  - Lecture: self + admins de workspace
  - Écriture: self (profile only) + admins (role)
- [ ] Rate limiting: max 5 writes/sec per user

**File to create:**
- Create `firestore.rules` (à la racine, à déployer avec `firebase deploy --only firestore:rules`)

**Exemple structure:**
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Auth check helper
    function isAuthenticated() { return request.auth != null; }
    function userRole(workspaceId) {
      return get(/databases/$(database)/documents/workspaces/$(workspaceId)).data.team[request.auth.uid].role;
    }
    function isAdmin(workspaceId) {
      return get(/databases/$(database)/documents/workspaces/$(workspaceId)).data.adminUid == request.auth.uid;
    }

    match /workspaces/{workspaceId} {
      allow read: if isAuthenticated() && userRole(workspaceId) != null;
      allow write: if isAdmin(workspaceId);
      
      match /devis/{devisId} {
        allow read: if isAuthenticated() && userRole(workspaceId) != null;
        allow create: if isAuthenticated() && userRole(workspaceId) == 'commercial';
        allow update: if isAuthenticated() && (userRole(workspaceId) in ['metreur', 'poseur']);
      }
    }

    match /users/{userId} {
      allow read: if request.auth.uid == userId || isAdmin(request.resource.data.workspaceId);
      allow write: if request.auth.uid == userId;
    }
  }
}
```

### 2️⃣ **Tests: Unit, Widget, E2E** (Semaine 2-3)
- [ ] **Unit Tests** (services):
  - `test/services/trial_service_test.dart` (TrialService.startTrial)
  - `test/services/auth_navigation_service_test.dart`
  - `test/services/pose_service_test.dart` (status transitions)
- [ ] **Widget Tests** (screens):
  - `test/screens/sign_in_screen_test.dart`
  - `test/screens/commercial_home_screen_test.dart`
  - `test/screens/metreur_home_screen_test.dart`
  - `test/screens/poseurs_home_screen_test.dart`
- [ ] **E2E Tests** (integration):
  - `integration_test/onboarding_flow_test.dart` (Welcome → Trial → Workspace)
  - `integration_test/commercial_devis_workflow_test.dart`
  - `integration_test/metreur_measurement_test.dart`
- [ ] Coverage goal: **≥ 70%** sur core flows

**Dependencies:**
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.0
  fake_cloud_firestore: ^3.0.0
```

**Setup:** Create `test/helpers/test_helpers.dart` avec mocks Firestore, Auth

### 3️⃣ **Mode Offline (Sync & Conflict Resolution)** (Semaine 3)
- [ ] Détecter connectivité: `connectivity_plus` package
- [ ] Créer `OfflineService` qui:
  - Sauvegarde les mutations localement (Hive ou SQLite)
  - Écoute reconnexion réseau
  - Rejoue mutations lors reconnexion
  - Gère conflits (last-write-wins par défaut)
- [ ] Ajouter UI indicator "Mode Offline" en top AppBar
- [ ] Cas d'usage: métreur change status devis offline → sync à la reconnexion

**Files to create:**
- `lib/services/offline_service.dart`
- `lib/services/sync_queue.dart`
- `pubspec.yaml`: add `connectivity_plus`, `hive`, `hive_flutter`

### 4️⃣ **Firebase Analytics** (Semaine 3)
- [ ] Ajouter `firebase_analytics` à pubspec.yaml
- [ ] Tracker les events clés:
  - `app_opened`
  - `onboarding_started`, `onboarding_completed`
  - `devis_created`, `devis_assigned`, `devis_completed`
  - `measurement_submitted`
  - `pose_started`, `pose_completed`
- [ ] Créer service `AnalyticsService` centralisé
- [ ] Dashboard Firebase Console pour voir metrics

### 5️⃣ **Poseurs: Planning Realtime + Photos + Validation** (Semaine 4)
Compléter la UI avec data + actions.

- [ ] **Planning realtime**:
  - Stream poses du jour depuis Firestore
  - Afficher adresse chantier, horaires prévisionnels, statut
  - Draggable re-assignation à autre poseur (si admin)
  
- [ ] **Photos terrain**:
  - Bouton "Prendre photo" dans pose actuelle
  - Upload vers Storage: `gs://workit-1daa1.firebasestorage.app/workspaces/{id}/poses/{poseId}/photos/`
  - Galerie photos dans détail pose
  - Signature client optional (signature_pad package)

- [ ] **Validation pose**:
  - Checklist avant "Terminer pose": photos min 3, dimensions confirmées, signature client
  - Button "Valider pose" → status "Posé" → Commercial notifié

**Model à créer:**
```dart
class Pose {
  final String id;
  final String devisId;
  final DateTime dateStart;
  final DateTime dateEnd;
  final String adresse;
  final String status; // 'À faire', 'En cours', 'Terminée'
  final List<String> photoUrls;
  final String? signatureUrl;
  final DateTime? completedAt;
}
```

### 6️⃣ **Gestion Abonnement Client** (Semaine 4)
Afficher trial/actif/expiré côté app.

- [ ] **TrialScreen widget**: affiche "7 jours restants" / "X jours" 
- [ ] **Abonnement actif**: afficher plan actuel + renouvellement date
- [ ] **Abonnement expiré**: afficher CTA "Renouveler" → route vers Stripe portal
- [ ] Stocker dans `workspaces/{id}`:
  ```
  subscription: {
    status: 'trial' | 'active' | 'expired' | 'cancelled',
    plan: 'abonnement_1' | 'abonnement_2' | 'abonnement_3',
    trialEndsAt: Timestamp,
    renewalDate: Timestamp,
    stripeCustomerId: 'cus_...'
  }
  ```
- [ ] Créer service `SubscriptionService` (read + check expiry)

**Files to create:**
- `lib/widgets/subscription_status_badge.dart`
- `lib/screens/subscription_screen.dart`
- `lib/services/subscription_service.dart`

## 🧪 Testing Strategy
```
test/
  ├─ helpers/
  │  └─ test_helpers.dart (mocks, fixtures)
  ├─ services/
  │  ├─ trial_service_test.dart
  │  ├─ offline_service_test.dart
  │  └─ pose_service_test.dart
  └─ screens/
     ├─ sign_in_screen_test.dart
     └─ poseurs_home_screen_test.dart

integration_test/
  ├─ onboarding_flow_test.dart
  └─ commercial_workflow_test.dart
```

Run: `flutter test` ou `flutter drive --target=integration_test/onboarding_flow_test.dart`

## 📝 Notes Techniques
- Firestore Rules: tester dans Firebase Emulator avant deployer
- Offline: queue limite à 1000 mutations (sinon supprimer les plus anciennes)
- Analytics: batch events à chaque minute (pas flux continu)
- Photos: compresser avant upload (max 5MB par photo)

## ✅ Définition "Fait"
- Security Rules déployées et testées
- ≥70% test coverage
- Mode offline fonctionne end-to-end
- Analytics tracking actif
- Poseurs planning + photos + validation complètes
- Subscription status affiché partout nécessaire
