---
name: "Workit Development Status Tracker"
description: "Suivi de progression en temps réel (Option A - Parallèle 4 Devs)"
updated: "28 mai 2026 - 16:00"
---

# 📊 Status Tracker: Workit Option A

**Status:** 🟢 INITIALIZED | Sem 1 Day 1

---

## 👤 Agent 1: Poseurs UI, AdminHomeScreen & FCM
**Dev:** TBD  
**Repo Branch:** `feature/agent-1-poseurs-ui`

### Semaine 1 (Kickoff)
- [ ] Audit code (PoseursHomeScreen, AdminHomeScreen)
- [ ] Read agent documentation (100%)
- [ ] Add Riverpod to pubspec.yaml
- [ ] Create `lib/providers/` folder structure
- [ ] First provider: `workspaceProvider`
- [ ] First provider: `authProvider`

**Status:** ⏳ Not Started  
**Blockers:** None  
**Next:** Day 1 audit  

---

## 👤 Agent 2: Infrastructure, Tests & Security Rules
**Dev:** TBD  
**Repo Branch:** `feature/agent-2-security-rules`

### Semaine 1 (Kickoff)
- [ ] Audit Firestore current schema
- [ ] Read agent documentation (100%)
- [ ] Document current collections
- [ ] Create `firestore.rules` (template)
- [ ] Setup Firebase Emulator tests
- [ ] First security rule test

**Status:** ⏳ Not Started  
**Blockers:** Firebase Emulator must run  
**Next:** Day 1 audit

---

## 👤 Agent 3: Security & Performance (UUID, Pagination)
**Dev:** TBD  
**Repo Branch:** `feature/agent-3-invites-pagination`

### Semaine 1 (Kickoff)
- [ ] Audit hardcoded invitation codes
- [ ] Read agent documentation (100%)
- [ ] Grep codebase for COMMERCIAL/METREUR/POSEURS usage
- [ ] Add `uuid` to `functions/package.json`
- [ ] Create `functions/invitations.js` skeleton
- [ ] Write `generateInvitationCode()` draft

**Status:** ⏳ Not Started  
**Blockers:** None  
**Next:** Day 1 audit

---

## 👤 Agent 4: Commerce & Stripe
**Dev:** TBD  
**Repo Branch:** `feature/agent-4-stripe-commerce`

### Semaine 1 (Kickoff)
- [ ] Audit current monetization (plans in models)
- [ ] Read agent documentation (100%)
- [ ] List Stripe dependencies needed
- [ ] Add `stripe` to `functions/package.json`
- [ ] Create `functions/stripe.js` skeleton
- [ ] Document Firestore `stripePlans` schema

**Status:** ⏳ Not Started  
**Blockers:** None (Stripe account needed Week 5)  
**Next:** Day 1 audit

---

## 🔗 Blockers & Dependencies

### Critical Path
```
Agent 3: UUID codes → required for Agent 1 plan selection
   ↓ (Sem 2)
Agent 1: UI/Riverpod → required for Agent 2 testing
   ↓ (Sem 3)
Agent 2: Tests/Rules → blocks Agent 3 rate limiting
   ↓ (Sem 4)
Agent 4: Stripe account activation → final blocker
```

### Current Blockers
| Agent | Blocker | Impact | ETA |
|-------|---------|--------|-----|
| 1 | None | - | - |
| 2 | Firebase Emulator setup | Need to run locally | Day 2 |
| 3 | None | - | - |
| 4 | Stripe account not created | Can prepare all code, can't test live | Sem 5 |

---

## 📈 Weekly Progress (Updated Daily)

### Week 1 (28 mai - 1 juin)
**Goal:** Infrastructure setup, foundations ready

| Agent | Mon | Tue | Wed | Thu | Fri | Status |
|-------|-----|-----|-----|-----|-----|--------|
| 1 | Audit | Audit | Riverpod | Riverpod | Providers | 🟡 In Progress |
| 2 | Audit | Audit | Rules | Rules | Tests | 🟡 In Progress |
| 3 | Audit | Audit | Cloud Fn | Cloud Fn | Invites | 🟡 In Progress |
| 4 | Audit | Audit | Cloud Fn | Cloud Fn | Stripe | 🟡 In Progress |

**Week Output Goal:**
- [ ] All pubspec.yaml updated
- [ ] Cloud Functions foundation ready
- [ ] Firestore rules skeleton
- [ ] Daily standups established

---

### Week 2 (3 - 7 juin)
**Goal:** Implementation starting

| Agent | Mon | Tue | Wed | Thu | Fri | Status |
|-------|-----|-----|-----|-----|-----|--------|
| 1 | FCM | FCM | Poses | Poses | Riverpod | ⏳ Not Started |
| 2 | Rules | Rules | Offline | Offline | Tests | ⏳ Not Started |
| 3 | UUIDs | UUIDs | Pagination | Pagination | Deploy | ⏳ Not Started |
| 4 | Checkout | Checkout | Webhooks | Webhooks | Tests | ⏳ Not Started |

**Week Output Goal:**
- [ ] PoseursHomeScreen streams poses
- [ ] UUID codes fully functional
- [ ] Stripe Cloud Functions deployed (test mode)
- [ ] Security Rules core blocks working

---

### Week 3 (10 - 14 juin)
**Goal:** Integration & migration

**Week Output Goal:**
- [ ] Riverpod migration 50% complete
- [ ] AdminDashboard KPIs showing
- [ ] Pagination everywhere
- [ ] Stripe checkout UI ready

---

### Week 4 (17 - 21 juin)
**Goal:** Completion & testing

**Week Output Goal:**
- [ ] 100% Riverpod (zero setState)
- [ ] 70%+ test coverage
- [ ] Poseurs features complete
- [ ] All screens production-ready

---

### Week 5 (24 - 28 juin)
**Goal:** Production preparation & go-live

**Week Output Goal:**
- [ ] Stripe account activated & configured
- [ ] All QA tests passing
- [ ] Security audit complete
- [ ] 🚀 Production deployment ready

---

## 💬 Communication Log

**28 mai 16:00** - Project initialized, 4 agents created, Option A selected  
**28 mai 16:30** - KICKOFF-OPTION-A.md created  
**28 mai 17:00** - All agents ready to start  

---

## 🔔 Upcoming Milestones

- [ ] **1 June (Day 4):** First sync point (all agents demo fundations)
- [ ] **3 June (Start Week 2):** First feature branch merge → develop
- [ ] **7 June (End Week 2):** Sync point #2 (review progress)
- [ ] **14 June (End Week 3):** Feature branch re-sync from develop
- [ ] **21 June (End Week 4):** Final merge feature → develop
- [ ] **24 June (Week 5):** Stripe account activation by admin
- [ ] **28 June (End Week 5):** 🚀 Production ready

---

## 🎯 Success Criteria

✅ All agents start Monday 28 mai  
✅ Daily standups established  
✅ All feature branches created  
✅ Week 1 deliverables on track  

---

**Last Updated:** 28 mai 2026 - 16:30  
**Tracking:** `/memories/repo/workit_session_tracking.md`  
**Timeline:** 5 weeks to production  
**Team:** 4 parallel agents
