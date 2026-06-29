---
name: "Workit Development Plan - Option A Kickoff"
description: "Plan d'exécution parallèle: 4 agents indépendants, Semaine 1-5 → Production Ready"
date: "28 mai 2026"
model: "Option A - Parallèle Complet (4 Devs)"
timeline: "5 semaines"
---

# 🚀 Workit Option A: Lancement Parallèle (4 Devs)

## 📋 Kickoff Semaine 1-2

### Configuration Préalable (À faire d'abord par TOUS)

```bash
# 1. Git setup
git clone https://github.com/workit-dev/workit.git
cd workit
git checkout -b feature/all-agents
git pull origin develop

# 2. Dependencies
flutter pub get
flutter pub upgrade
flutter clean && flutter pub get

# 3. Firebase Emulator (Agent 2 surtout)
firebase emulators:start

# 4. Flutter Riverpod generator (Agent 1)
flutter pub run build_runner watch
```

### Slack Channel Coordination
```
Channel: #workit-dev-agents
├─ Agent 1: @dev1 (poseurs-ui-fcm)
├─ Agent 2: @dev2 (infrastructure-quality)
├─ Agent 3: @dev3 (security-performance)
└─ Agent 4: @dev4 (stripe-commerce)

Daily standup: 09:00 (5 min, blocages only)
```

---

## 🎯 Semaine 1: KICKOFF PHASE

### Agent 1: Poseurs UI & FCM Setup
**Lead: Dev 1**

- [ ] **Day 1-2:** Audit code existant (PoseursHomeScreen, AdminHomeScreen)
  - Lire `.vscode/agent-poseurs-ui-fcm.md` (100%)
  - Lister dépendances manquantes (`flutter_riverpod`, `fl_charts`, `firebase_messaging`)
  
- [ ] **Day 3-5:** Setup infra Riverpod
  - Ajouter `pubspec.yaml`: `flutter_riverpod`, `riverpod_generator`
  - Créer `lib/providers/` folder structure
  - First provider: `workspaceProvider` + `authProvider`

**Output semaine 1:** pubspec.yaml updated, providers foundation ready

---

### Agent 2: Security Rules & Offline Foundation
**Lead: Dev 2**

- [ ] **Day 1-2:** Audit Firestore actuel
  - Lire `.vscode/agent-infrastructure-quality.md` (100%)
  - Document current collections + schema
  - List security gaps
  
- [ ] **Day 3-5:** Start Security Rules
  - Create `firestore.rules` (template à partir du fichier agent)
  - Setup test suite pour rules (Firebase Emulator)
  - Test 1 scenario: user peut lire workspace si member

**Output semaine 1:** firestore.rules created + emulator tests

---

### Agent 3: UUID Invites & Pagination Foundation
**Lead: Dev 3**

- [ ] **Day 1-2:** Audit codes d'invitation actuels
  - Lire `.vscode/agent-security-performance.md` (100%)
  - Grep: where 'COMMERCIAL', 'METREUR', 'POSEURS' used
  - Map dépendances de ces codes
  
- [ ] **Day 3-5:** Cloud Functions foundation
  - Add uuid package to `functions/package.json`
  - Create `functions/invitations.js` skeleton
  - Write `generateInvitationCode()` function draft (non-deployed)

**Output semaine 1:** invitations.js created, ready for testing

---

### Agent 4: Stripe Infrastructure Setup
**Lead: Dev 4**

- [ ] **Day 1-2:** Audit monétisation actuelle
  - Lire `.vscode/agent-stripe-commerce.md` (100%)
  - Check `lib/models/onboarding_models.dart` plans
  - List Stripe dependencies needed
  
- [ ] **Day 3-5:** Setup Stripe backend
  - Add `stripe` package to `functions/package.json`
  - Create `functions/stripe.js` skeleton
  - Write Cloud Functions stubs (createCheckoutSession, stripeWebhook, etc.)
  - Create `stripePlans` Firestore collection schema doc

**Output semaine 1:** stripe.js stubs created, schema documented

---

## 🎯 Semaine 2: IMPLEMENTATION PHASE

### Agent 1: PoseursHomeScreen Data + FCM Init
**Lead: Dev 1**

- [ ] Ajouter `firebase_messaging` à pubspec
- [ ] Create `PoseTask` model (lib/models/)
- [ ] Create `PoseService` (lib/services/pose_service.dart)
- [ ] Stream poses from Firestore (test data)
- [ ] Rewrite PoseursHomeScreen avec Riverpod ConsumerWidget
- [ ] First tab: **Jour** view (render poses today)
- [ ] FCM: Initialize messaging in main.dart

**Output semaine 2:** PoseursHomeScreen affiche poses du jour (realtime)

---

### Agent 2: Security Rules Complet + Tests
**Lead: Dev 2**

- [ ] Firestore Rules: all 6 match blocks complets (workspaces, devis, users, team, etc.)
- [ ] Security Rules testing suite (≥80% scenarios)
- [ ] Create offline service skeleton (`lib/services/offline_service.dart`)
- [ ] Offline: setup local storage (Hive or SQLite choice)
- [ ] Start Analytics service

**Output semaine 2:** Security Rules complet + testées + offline foundation

---

### Agent 3: Invitation Codes Implementation
**Lead: Dev 3**

- [ ] Deploy `generateInvitationCode()` to Cloud Functions (test mode)
- [ ] Deploy `validateInvitationCode()` function
- [ ] Update `OnboardingData` model (remove hardcoded codes)
- [ ] Update `InviteTeamScreen` to use generateInvitationCode
- [ ] Update `JoinWorkspaceScreen` to validate code
- [ ] Test end-to-end: generate → validate → use

**Output semaine 2:** UUID codes fully operational

---

### Agent 4: Stripe Cloud Functions Complete
**Lead: Dev 4**

- [ ] Complete `createCheckoutSession()` implementation (test mode)
- [ ] Complete `stripeWebhook()` handler
- [ ] Populate `stripePlans` collection with 3 plans
- [ ] Add subscription schema to workspace Firestore doc
- [ ] Deploy all Cloud Functions (test stripe keys)
- [ ] Test webhook signature verification

**Output semaine 2:** Stripe backend 100% ready (waiting for account)

---

## 🎯 Semaine 3: INTEGRATION PHASE

### Agent 1: AdminDashboard + Riverpod Migration (Part 1)
**Lead: Dev 1**

- [ ] Migrate CommercialHomeScreen → Riverpod (remove setState)
- [ ] Create `devisProvider` (stream devis)
- [ ] AdminDashboard skeleton: 3 tabs structure
- [ ] Dashboard tab: Show KPIs placeholders
- [ ] Add `fl_charts` package
- [ ] First chart: pie chart devis by status

**Output semaine 3:** AdminDashboard affiche KPIs (mock data), CommercialScreen migré Riverpod

---

### Agent 2: Tests Setup + Analytics
**Lead: Dev 2**

- [ ] Create `test/` folder structure + test_helpers.dart
- [ ] Write 5 unit tests (TrialService, OfflineService, etc.)
- [ ] Write 2 widget tests (SignInScreen, CommercialHomeScreen)
- [ ] Setup Firebase Analytics service
- [ ] Add analytics events tracking (app_opened, devis_created, etc.)
- [ ] Integrate analytics in Agent 1's new providers

**Output semaine 3:** Tests foundation + Analytics tracking active

---

### Agent 3: Firestore Pagination + Rate Limiting
**Lead: Dev 3**

- [ ] Implement pagination in CommercialHomeScreen (20 devis/page)
- [ ] Implement pagination in MetreurHomeScreen (20 demandes/page)
- [ ] Create `DevisService` (centralize queries)
- [ ] Firestore indexes: add to firebase.json
- [ ] Cloud Functions: add rate limiting on key functions
- [ ] Test pagination end-to-end

**Output semaine 3:** Pagination everywhere, rate limiting active

---

### Agent 4: Checkout UI + Subscription Display
**Lead: Dev 4**

- [ ] Create `lib/screens/stripe_checkout_screen.dart`
- [ ] Add Stripe Flutter SDK to pubspec
- [ ] Update plan_selection_screen to show pricing (from stripePlans)
- [ ] Create `SubscriptionService` + `SubscriptionStatusBadge` widget
- [ ] Update AdminSummaryScreen to show subscription status
- [ ] Create settings portal link button

**Output semaine 3:** Checkout screens ready (not connected to live Stripe yet)

---

## 🎯 Semaine 4: COMPLETION PHASE

### Agent 1: Riverpod Migration (Part 2) + FCM Complete
**Lead: Dev 1**

- [ ] Migrate MetreurHomeScreen → Riverpod
- [ ] Migrate PoseursHomeScreen → Riverpod (all 3 tabs complete)
- [ ] Migrate AdminHomeScreen → Riverpod
- [ ] Complete PoseursHomeScreen tabs (Jour/Semaine/Liste)
- [ ] FCM: local notifications when devis status changes
- [ ] Polish all UI/UX

**Output semaine 4:** Zero `setState` in app, 100% Riverpod, FCM notifications working

---

### Agent 2: Poseurs Features Complete + Full Tests
**Lead: Dev 2**

- [ ] Poseurs planning realtime (from Firestore)
- [ ] Photo upload/camera integration
- [ ] Pose validation checklist (photos min 3, signature, etc.)
- [ ] Write 3 integration tests (onboarding, devis workflow)
- [ ] Full offline sync testing
- [ ] Coverage report: aim for 70%+

**Output semaine 4:** Poseurs 100% functional, 70%+ tests passing

---

### Agent 3: Performance Optimizations + Security Audit
**Lead: Dev 3**

- [ ] Firestore indexes deployed (monitor usage)
- [ ] Debounce/throttle on high-frequency queries
- [ ] Rate limiting stress tests (10x normal load)
- [ ] Security audit: check for hardcoded secrets, SQL injection, etc.
- [ ] Poseur batch 1 support: validate data flows

**Output semaine 4:** Performance ✓, Security ✓, Scalability ✓

---

### Agent 4: Stripe Testing (Mock) + Documentation
**Lead: Dev 4**

- [ ] Mock Stripe tests (checkout flow end-to-end)
- [ ] Webhook testing (with test signatures)
- [ ] Create `docs/STRIPE_INTEGRATION.md` guide
- [ ] Document required Stripe setup steps (for admin)
- [ ] Payment failure scenario testing
- [ ] Portal link validation

**Output semaine 4:** Stripe infrastructure 100% tested, documentation complete

---

## 🎯 Semaine 5: PRODUCTION PREP PHASE

### Agent 1: Final UI Polish + QA
**Lead: Dev 1**

- [ ] All screens responsive (test on multiple devices)
- [ ] Dark mode consistency check
- [ ] Accessibility audit (A11y)
- [ ] Performance profiling (< 60fps)
- [ ] No console warnings/errors

**Output semaine 5:** Production-ready UI

---

### Agent 2: Quality Assurance Complete
**Lead: Dev 2**

- [ ] Run full test suite (coverage ≥70%)
- [ ] E2E test: onboarding → devis → measurement → pose
- [ ] Offline mode stress test (airplane mode toggle)
- [ ] Analytics events verification
- [ ] Security Rules final validation

**Output semaine 5:** 0 failures, QA sign-off ✓

---

### Agent 3: Security & Performance Sign-Off
**Lead: Dev 3**

- [ ] Final penetration test (rate limiting, auth, invites)
- [ ] Firestore cost analysis (est. monthly reads/writes)
- [ ] Performance benchmarks (devis load time < 2s)
- [ ] Create SECURITY.md (vulnerabilities addressed)
- [ ] Deployment checklist completed

**Output semaine 5:** Security & Performance sign-off ✓

---

### Agent 4: Stripe Account Activation + Go-Live
**Lead: Dev 4**

- [ ] **Admin creates Stripe account** (stripe.com/register)
- [ ] Provide STRIPE_SECRET_KEY → Agent 4
- [ ] Create 3 Price IDs → Firestore stripePlans
- [ ] Deploy Cloud Functions with live keys
- [ ] Configure webhooks in Stripe Dashboard
- [ ] Live payment test (with test card 4242...)
- [ ] Go-live authorization

**Output semaine 5:** 🚀 **PRODUCTION READY**

---

## 🗂️ Git Workflow

### Branches per Agent
```
main (production)
├─ develop (integration branch)
├─ feature/agent-1-poseurs-ui (Dev 1)
├─ feature/agent-2-security-rules (Dev 2)
├─ feature/agent-3-invites-pagination (Dev 3)
└─ feature/agent-4-stripe-commerce (Dev 4)
```

### Merging Schedule
- **End Sem 2:** Merge all feature branches → develop (sync point)
- **End Sem 3:** Re-sync feature branches from develop
- **End Sem 4:** Final merge feature branches → develop
- **Sem 5:** Merge develop → main (production release)

### Code Review Rule
- Agents review each other's PRs (quick turnaround)
- No merge without Agent 3 sign-off (security)
- No production deploy without Agent 2 sign-off (tests)

---

## 📊 Daily Standup Format

**Time:** 09:00 (5 min max)  
**Format:**
```
Agent 1: [Completed] PoseursHomeScreen tab 1 [Blocked by] nothing [Next] tab 2
Agent 2: [Completed] Security Rules draft [Blocked by] nothing [Next] testing
Agent 3: [Completed] UUID function [Blocked by] nothing [Next] integration
Agent 4: [Completed] Stripe Cloud Functions [Blocked by] nothing [Next] UI
```

**Escalation:** If blocked → ping relevant agent immediately

---

## ✅ Go-Live Checklist (Week 5)

- [ ] All 4 agents sign-off: "Ready for production"
- [ ] Test coverage ≥70%
- [ ] 0 critical security issues
- [ ] Stripe account live + webhooks configured
- [ ] Firebase Security Rules deployed
- [ ] Firebase Emulator tests passing
- [ ] Production APK/AAB built & signed
- [ ] iOS TestFlight build ready
- [ ] Monitoring/alerting setup (Sentry, Firebase Crashlytics)
- [ ] Rollback plan documented

---

## 🚨 Critical Path

```
Agent 3: UUID codes (blocks Agent 1 plan selection)
   ↓
Agent 1: UI/Riverpod (blocks Agent 2 testing)
   ↓
Agent 2: Tests + Rules (blocks production)
   ↓
Agent 4: Stripe account activation (final blocker)
   ↓
🚀 PRODUCTION DEPLOY
```

---

## 📱 Success Metrics (End Week 5)

| Metric | Target | Status |
|--------|--------|--------|
| All screens migrated to Riverpod | 100% | [ ] |
| Firestore Security Rules deployed | ✓ | [ ] |
| Test coverage | ≥70% | [ ] |
| Devis load time | < 2s | [ ] |
| FCM notifications | Working | [ ] |
| UUID invitation codes | Live | [ ] |
| Stripe checkout | Ready | [ ] |
| PoseursHomeScreen functional | ✓ | [ ] |
| Zero critical security issues | ✓ | [ ] |

---

**Project:** workit-1daa1  
**Timeline:** 28 mai - 1 juillet 2026 (5 weeks)  
**Team:** 4 senior engineers (parallel)  
**Target:** Production Ready by 1 July 2026

🚀 **LET'S GO!**
