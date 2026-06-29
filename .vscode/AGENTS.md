---
name: "Workit Project Agents"
description: "Index centralisé des 4 agents de développement pour Workit"
---

# 📋 Agents de Développement Workit

Voici les 4 agents assignés au projet Workit pour paralléliser le development et couvrir tous les domaines critiques.

---

## 🤖 **Agent 1: Poseurs UI, AdminHomeScreen & FCM**
**Fichier:** `.vscode/agent-poseurs-ui-fcm.md`

### Responsabilités
- ✅ **PoseursHomeScreen** : UI complète (3 tabs Jour/Semaine/Liste) + données Firestore
- ✅ **AdminHomeScreen Dashboard** : KPIs, stats équipe, activité
- ✅ **FCM Notifications** : Implémentation notifications push
- ✅ **State Management** : Migration Riverpod (de StatefulWidget+setState)

### Timeline
**3-4 semaines** | **Priorité:** P1

### Dépendances
- Aucune dépendance (peut travailler en parallèle)

### Livrables Clés
1. PoseursHomeScreen 100% fonctionnel
2. AdminHomeScreen avec KPIs charts
3. Notifications push opérationnelles
4. Tous les screens migrés en Riverpod (zéro setState)

---

## 🔐 **Agent 2: Infrastructure, Tests & Features Poseurs Avancées**
**Fichier:** `.vscode/agent-infrastructure-quality.md`

### Responsabilités
- 🔐 **Firestore Security Rules** : Auth + autorisation par rôle
- 🧪 **Tests** : Unit, Widget, E2E (≥70% coverage)
- 📡 **Mode Offline** : Sync + conflict resolution
- 📊 **Firebase Analytics** : Event tracking
- 🎯 **Poseurs Features** : Planning realtime + photos + validation
- 💳 **Gestion Abonnement** : Affichage trial/actif/expiré

### Timeline
**4-5 semaines** | **Priorité:** P2

### Dépendances
- **Dépend de Agent 1** : Riverpod + screens finalisées
- **Bloque Agent 3 & 4** : Security Rules + tests requis

### Livrables Clés
1. Security Rules déployées et testées
2. 70%+ test coverage
3. Mode offline end-to-end
4. Poseurs: planning + photos + validation complètes
5. Abonnement status visible partout

---

## ⚡ **Agent 3: Sécurité & Performance**
**Fichier:** `.vscode/agent-security-performance.md`

### Responsabilités
- 🔒 **Codes d'Invitation Sécurisés** : UUID rotatifs vs hardcodés
- 📈 **Pagination Firestore** : Résoudre problème scalabilité stream devis
- 🚀 **Support Poseurs Batch 1** : Data + trigger automatique
- ⚙️ **Optimisations Firestore** : Indexes, caching, batching
- 🛡️ **Rate Limiting** : Anti-abuse Cloud Functions

### Timeline
**2-3 semaines** | **Priorité:** P1-Critical

### Dépendances
- Aucune dépendance (peut travailler en parallèle)
- **Bloque go-live** : Critiques de sécurité

### Livrables Clés
1. Codes d'invitation UUID + expiry 30j
2. Pagination implémentée (20 items/page)
3. Firestore indexes optimisés
4. Rate limiting actif
5. 0 vulnérabilités de sécurité

---

## 💳 **Agent 4: Commerce & Infrastructure Stripe**
**Fichier:** `.vscode/agent-stripe-commerce.md`

### Responsabilités
- 💰 **Infrastructure Stripe** : Cloud Functions pour checkout + webhooks
- 🧾 **Gestion Abonnements** : Sync Stripe → Firestore
- 🎫 **Checkout UI** : Screens prêtes pour Stripe integration
- 🔑 **Secrets Management** : Environment variables + security

### Timeline
**3 semaines** (infrastructure ready, déploiement après compte Stripe créé) | **Priorité:** P1-Blocking

### Dépendances
- ⚠️ **Pré-requis** : Compte Stripe Business à créer séparément (stripe.com)
- Peut préparer tout en amont (mocks, infrastructure as code)

### Livrables Clés
1. Cloud Functions Stripe implémentées
2. Firestore schema prêt pour subscription
3. Frontend checkout screens créés
4. Documentation complète
5. **À faire après compte Stripe :** 
   - Récupérer Secret Key
   - Créer 3 Price IDs
   - Configurer webhooks
   - Deploy + test

---

## 📊 Timeline Globale

```
Semaine 1-2
├─ Agent 1: PoseursHomeScreen UI + FCM basics
├─ Agent 2: Security Rules + mode offline setup
├─ Agent 3: UUID invites + pagination
└─ Agent 4: Cloud Functions + schema

Semaine 3-4
├─ Agent 1: AdminHomeScreen Dashboard + Riverpod migration
├─ Agent 2: Tests + analytics
├─ Agent 3: Optimisations Firestore
└─ Agent 4: Frontend checkout + portal

Semaine 5
├─ Agent 1: Polish UI + notifications
├─ Agent 2: Photos terrain + subscription UI
├─ Agent 3: Vérification sécurité finale
└─ Agent 4: Ready pour Stripe account activation

**PRODUCTION READY:** Fin Semaine 5 (après Stripe account + deployment)
```

---

## 🎯 Cascade de Dépendances

```
Agent 3 (Sécurité)
  ↓ (UUID invites pour Agent 1)
  ↓
Agent 1 (UI & Riverpod)
  ↓ (Screens finalisées)
  ↓
Agent 2 (Quality & Features)
  ↓ (Tests + features complètes)
  ↓
Agent 4 (Stripe)
  ↓ (Abonnement + facturation)
  ↓
🚀 PRODUCTION READY
```

---

## 🚀 Comment Ça Fonctionne

### Pour un agent:
1. Lire le fichier `.vscode/agent-X.md`
2. Commencer par la première tâche prioritaire (1️⃣)
3. Reporter progress en commentaires du fichier agent
4. Consulter dépendances avant d'avancer

### Communication entre agents:
- Tous les fichiers agents sont dans `.vscode/` (version contrôlée)
- Mettre à jour la mémoire repo `/memories/repo/workit_session_tracking.md` avec blocages
- Slack/Email si blocage critique

### Priorités GO/NO-GO:
- 🔴 **P1-Critical** (Agents 3, 4) : Bloquent production
- 🔴 **P1** (Agents 1, 3) : Doivent être 100% avant P2
- 🟠 **P2** (Agent 2) : Peut continuer si Agent 1 est prêt

---

## ✅ Checklist Lancement

- [ ] Agents 1-4 fichiers créés ✓
- [ ] AGENTS.md créé ✓
- [ ] Mémoire repository mise à jour
- [ ] Permissions agents assignées (collaborateurs)
- [ ] Compte Stripe créé (Administrator)
- [ ] Firestore Emulator setup pour Agent 2
- [ ] CI/CD pipeline pour tests Agent 2
- [ ] Slack channel `#workit-dev-agents` pour sync

---

## 📞 Escalade

| Problème | Escalade |
|----------|----------|
| Blocage dépendance | Agent 1 → Agent 3 |
| Bug Firestore | Agent 2 → Agent 3 |
| Question architecture | Team lead |
| Stripe pre-account | Administrator |
| Production issue | On-call engineer |

---

**Last Updated:** 28 mai 2026  
**Project ID:** workit-1daa1  
**Firebase:** workit-1daa1.firebaseapp.com
