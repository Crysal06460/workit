---
name: "Agent Commerce & Stripe"
description: "Préparer infrastructure Stripe complète (checkout, webhooks, billing). Compte Stripe à créer séparément."
type: "commerce"
skills: ["stripe", "payments", "backend", "webhooks"]
focusAreas:
  - "Infrastructure Stripe prête pour checkout"
  - "Webhooks Firestore sync"
  - "Gestion abonnements backend"
  - "UI prête pour Stripe integration"
  - "Environment variables & secrets management"
priority: "P1-Blocking"
estimatedEffort: "3 semaines"
dependencies:
  - "Compte Stripe workit à créer (Business account requis)"
  - "Agent 3 pour codes d'invitation (avant checkout)"
---

# Agent 4: Commerce & Infrastructure Stripe

## 🎯 Mission
Préparer tout ce qui est nécessaire pour Stripe SANS avoir besoin du compte encore créé. Infrastructure infrastructure-as-code, mocks pour dev, documenté et testé.

## ⚠️ PRÉ-REQUIS
**Avant de déployer vraiment:**
1. Créer compte Stripe Business (stripe.com/register)
2. Récupérer:
   - `STRIPE_SECRET_KEY` (commence par `sk_live_` ou `sk_test_`)
   - `STRIPE_PUBLISHABLE_KEY` (commence par `pk_live_` ou `pk_test_`)
   - `STRIPE_WEBHOOK_SECRET` (après setup webhooks)
3. Stocker dans Firebase Cloud Functions secrets (pas en code!)

**Créé par:** Administrator workit  
**Statut:** À faire

---

## 📋 Tâches Prioritaires

### 1️⃣ **Infrastructure Stripe Backend** (Semaine 1)

#### A) Dépendances Cloud Functions
```bash
cd functions
npm install stripe
npm install stripe-event-types
```

Update `functions/package.json`:
```json
{
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^4.0.0",
    "stripe": "^14.0.0"
  }
}
```

#### B) Cloud Functions pour Stripe
Créer `functions/stripe.js` avec:

```javascript
const { onCall, onRequest } = require('firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const Stripe = require("stripe").default;

initializeApp();
const db = getFirestore();
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

/**
 * Créer Checkout Session pour nouveau workspace
 * POST /createCheckoutSession
 * { workspaceId, planId, successUrl, cancelUrl }
 */
exports.createCheckoutSession = onCall(
  { region: "europe-west1", secrets: ["STRIPE_SECRET_KEY", "STRIPE_PUBLISHABLE_KEY"] },
  async (request) => {
    const { workspaceId, planId, successUrl, cancelUrl } = request.data;
    const uid = request.auth.uid;

    // Validation
    if (!workspaceId || !planId) {
      throw new Error("workspaceId and planId required");
    }

    // 1) Fetch workspace
    const wsDoc = await db.collection('workspaces').doc(workspaceId).get();
    if (!wsDoc.exists) throw new Error("Workspace not found");
    const ws = wsDoc.data();
    if (ws.adminUid !== uid) throw new Error("Unauthorized");

    // 2) Fetch plan pricing (à créer dans Firestore)
    const planDoc = await db.collection('stripePlans').doc(planId).get();
    if (!planDoc.exists) throw new Error("Plan not found");
    const plan = planDoc.data();

    // 3) Créer ou récupérer Customer Stripe
    let customerId = ws.subscription?.stripeCustomerId;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email: ws.adminEmail,
        metadata: { workspaceId },
      });
      customerId = customer.id;
      // Sauver customerId dans workspace
      await db.collection('workspaces').doc(workspaceId).update({
        'subscription.stripeCustomerId': customerId,
      });
    }

    // 4) Créer Checkout Session
    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: 'eur',
            product_data: {
              name: plan.name,
              description: plan.features.join(', '),
            },
            unit_amount: plan.priceInCents, // ex: 2900 = 29€
            recurring: {
              interval: 'month',
              interval_count: 1,
            },
          },
          quantity: 1,
        },
      ],
      mode: 'subscription',
      success_url: successUrl,
      cancel_url: cancelUrl,
      metadata: { workspaceId, planId },
    });

    return { sessionId: session.id, sessionUrl: session.url };
  }
);

/**
 * Webhook Stripe pour synchroniser subscription status
 * POST /stripeWebhook
 * Header: Stripe-Signature
 */
exports.stripeWebhook = onRequest(
  { region: "europe-west1", secrets: ["STRIPE_WEBHOOK_SECRET"] },
  async (req, res) => {
    const sig = req.headers['stripe-signature'];
    let event;

    try {
      event = stripe.webhooks.constructEvent(
        req.rawBody,
        sig,
        process.env.STRIPE_WEBHOOK_SECRET
      );
    } catch (err) {
      console.error('Webhook signature verification failed:', err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    // Handle events
    try {
      switch (event.type) {
        case 'customer.subscription.created':
        case 'customer.subscription.updated':
          await handleSubscriptionUpdate(event.data.object);
          break;

        case 'customer.subscription.deleted':
          await handleSubscriptionCancellation(event.data.object);
          break;

        case 'invoice.paid':
          await handleInvoicePaid(event.data.object);
          break;

        case 'invoice.payment_failed':
          await handleInvoicePaymentFailed(event.data.object);
          break;

        default:
          console.log(`Unhandled event type: ${event.type}`);
      }
    } catch (err) {
      console.error('Webhook handler error:', err);
      return res.status(500).send('Internal Server Error');
    }

    res.json({ received: true });
  }
);

/**
 * Sync subscription data to Firestore
 */
async function handleSubscriptionUpdate(subscription) {
  const customerId = subscription.customer;
  const customer = await stripe.customers.retrieve(customerId);
  const workspaceId = customer.metadata.workspaceId;

  const planId = subscription.items.data[0].price.id; // Stripe Price ID
  const currentPeriodEnd = new Date(subscription.current_period_end * 1000);

  await db.collection('workspaces').doc(workspaceId).update({
    subscription: {
      status: subscription.status === 'active' ? 'active' : 'inactive',
      stripeSubscriptionId: subscription.id,
      stripeCustomerId: customerId,
      stripePriceId: planId,
      renewalDate: FieldValue.serverTimestamp(),
      periodEnd: currentPeriodEnd,
      canceledAt: subscription.canceled_at ? new Date(subscription.canceled_at * 1000) : null,
    },
  });

  console.log(`Subscription updated for workspace ${workspaceId}: ${subscription.status}`);
}

async function handleSubscriptionCancellation(subscription) {
  const customerId = subscription.customer;
  const customer = await stripe.customers.retrieve(customerId);
  const workspaceId = customer.metadata.workspaceId;

  await db.collection('workspaces').doc(workspaceId).update({
    'subscription.status': 'cancelled',
    'subscription.canceledAt': FieldValue.serverTimestamp(),
  });

  console.log(`Subscription cancelled for workspace ${workspaceId}`);
}

async function handleInvoicePaid(invoice) {
  const customerId = invoice.customer;
  const customer = await stripe.customers.retrieve(customerId);
  const workspaceId = customer.metadata.workspaceId;

  // Log invoice
  await db.collection('workspaces').doc(workspaceId).collection('invoices').add({
    stripeInvoiceId: invoice.id,
    amount: invoice.amount_paid,
    currency: invoice.currency,
    paidAt: new Date(invoice.paid_date * 1000),
    number: invoice.number,
  });

  console.log(`Invoice paid for workspace ${workspaceId}: €${invoice.amount_paid / 100}`);
}

async function handleInvoicePaymentFailed(invoice) {
  const customerId = invoice.customer;
  const customer = await stripe.customers.retrieve(customerId);
  const workspaceId = customer.metadata.workspaceId;

  // Alerter admin via FCM notification
  await db.collection('workspaces').doc(workspaceId).update({
    'subscription.paymentFailedAt': FieldValue.serverTimestamp(),
  });

  console.log(`Invoice payment failed for workspace ${workspaceId}`);
}

/**
 * Récupérer Stripe plans (liste disponible)
 */
exports.getStripePlans = onCall(
  { region: "europe-west1" },
  async (request) => {
    const plans = await db.collection('stripePlans').orderBy('order').get();
    return plans.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  }
);

/**
 * Récupérer customer portal link
 */
exports.getCustomerPortalLink = onCall(
  { region: "europe-west1", secrets: ["STRIPE_SECRET_KEY"] },
  async (request) => {
    const { workspaceId } = request.data;
    const uid = request.auth.uid;

    const ws = await db.collection('workspaces').doc(workspaceId).get();
    if (!ws.exists || ws.data().adminUid !== uid) {
      throw new Error("Unauthorized");
    }

    const customerId = ws.data().subscription?.stripeCustomerId;
    if (!customerId) throw new Error("No Stripe customer found");

    const session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: 'https://app.workit.fr/settings', // À adapter
    });

    return { url: session.url };
  }
);
```

#### C) Déployer Cloud Functions
```bash
cd functions
firebase deploy --only functions
```

### 2️⃣ **Firestore Collections pour Stripe** (Semaine 1)

#### A) Collection `stripePlans`
```javascript
// Créer via Firebase Console ou script
db.collection('stripePlans').doc('abonnement_1').set({
  name: 'Configuration 1',
  features: [
    '3 commerciaux inclus',
    '1 métreur inclus',
    '3 équipes de pose incluses',
  ],
  seatsByRole: {
    commercial: 3,
    metreur: 1,
    poseur: 3,
  },
  priceInCents: 2900, // 29€/mois
  stripePriceId: 'price_1O...' // À remplir après création Stripe
  order: 1,
  recommended: false,
});

// Config 2
db.collection('stripePlans').doc('abonnement_2').set({
  name: 'Configuration 2',
  features: [
    '5 commerciaux inclus',
    '2 métreurs inclus',
    '5 équipes de pose incluses',
  ],
  seatsByRole: {
    commercial: 5,
    metreur: 2,
    poseur: 5,
  },
  priceInCents: 4900, // 49€/mois
  stripePriceId: 'price_1P...',
  order: 2,
  recommended: true,
});

// Config 3 (Unlimited)
db.collection('stripePlans').doc('abonnement_3').set({
  name: 'Configuration Illimitée',
  features: [
    'Commerciaux illimités',
    'Mètreurs illimités',
    'Équipes de pose illimitées',
  ],
  seatsByRole: {
    commercial: null,
    metreur: null,
    poseur: null,
  },
  priceInCents: 7900, // 79€/mois
  stripePriceId: 'price_1Q...',
  order: 3,
  recommended: false,
});
```

#### B) Collection `workspaces` - Update schema
Ajouter field subscription (structure):
```javascript
{
  ...existing fields,
  subscription: {
    status: 'trial' | 'active' | 'expired' | 'cancelled', // État actuel
    plan: 'abonnement_1' | 'abonnement_2' | 'abonnement_3',
    trialStartedAt: Timestamp,
    trialEndsAt: Timestamp, // Expire après 7 jours
    stripeCustomerId: 'cus_...', // Stripe ID
    stripeSubscriptionId: 'sub_...', // Active subscription ID
    stripePriceId: 'price_...', // Current price
    renewalDate: Timestamp, // Prochain renouvellement
    periodEnd: Timestamp, // Fin période actuelle
    paymentFailedAt: Timestamp | null, // Dernier paiement échoué
    canceledAt: Timestamp | null, // Si annulée
  }
}
```

### 3️⃣ **Frontend: UI Checkout** (Semaine 2)

#### A) Plan Selection Screen
Modifier `lib/screens/plan_selection_screen.dart`:
- Afficher 3 plans avec pricing réel (depuis `stripePlans`)
- Button "Continuer avec ce plan" → `StripeCheckoutScreen`
- Badge "Recommandé" sur Config 2

#### B) Stripe Checkout Screen
Create `lib/screens/stripe_checkout_screen.dart`:
```dart
import 'package:flutter_stripe/flutter_stripe.dart'; // À ajouter pubspec.yaml

class StripeCheckoutScreen extends StatefulWidget {
  final String workspaceId;
  final String planId;

  const StripeCheckoutScreen({
    required this.workspaceId,
    required this.planId,
  });

  @override
  State<StripeCheckoutScreen> createState() => _StripeCheckoutScreenState();
}

class _StripeCheckoutScreenState extends State<StripeCheckoutScreen> {
  bool _loading = false;

  Future<void> _launchCheckout() async {
    setState(() => _loading = true);

    try {
      // 1) Appeler Cloud Function
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('createCheckoutSession').call({
        'workspaceId': widget.workspaceId,
        'planId': widget.planId,
        'successUrl': 'https://app.workit.fr/success',
        'cancelUrl': 'https://app.workit.fr/cancel',
      });

      final sessionId = result.data['sessionId'];

      // 2) Lancer Stripe Checkout
      await Stripe.instance.presentPaymentSheet(
        clientSecret: sessionId, // Ou passé via Flutter SDK Stripe
      );

      // 3) Success - retourner à AdminSummaryScreen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Abonnement activé!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passer au paiement')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _launchCheckout,
                child: const Text('Lancer paiement Stripe'),
              ),
      ),
    );
  }
}
```

**Update pubspec.yaml:**
```yaml
dependencies:
  flutter_stripe: ^9.0.0
  cloud_functions: ^5.0.4
```

#### C) Subscription Portal Link
Create `SettingsScreen` button:
```dart
Future<void> _openCustomerPortal() async {
  try {
    final functions = FirebaseFunctions.instance;
    final result = await functions.httpsCallable('getCustomerPortalLink').call({
      'workspaceId': _workspaceId,
    });
    
    final url = result.data['url'];
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur: ${e.toString()}')),
    );
  }
}
```

### 4️⃣ **Environment Variables & Secrets** (Semaine 2)

#### A) Firebase Cloud Functions Secrets
Setup via Firebase CLI:
```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_PUBLISHABLE_KEY
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET

# Verify
firebase functions:secrets:get STRIPE_SECRET_KEY
```

`.env.local` (local dev, JAMAIS en git):
```
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_test_...
```

#### B) Frontend Initialization
Update `main.dart`:
```dart
import 'package:flutter_stripe/flutter_stripe.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Stripe initialization
  Stripe.publishableKey = 'pk_live_...'; // À récupérer de Firebase Remote Config
  await Stripe.instance.applySettings();

  runApp(const WorkItApp());
}
```

### 5️⃣ **Testing & Documentation** (Semaine 3)

#### A) Test Cases
- [ ] Test checkout flow end-to-end (mock)
- [ ] Test webhook events (invoice.paid, subscription.updated)
- [ ] Test subscription cancellation
- [ ] Test payment failure handling

Create `test/services/stripe_service_test.dart`

#### B) Stripe Webhook Setup
**À faire après compte créé:**
1. Aller dans Stripe Dashboard → Webhooks
2. Ajouter endpoint: `https://your-region-workit.cloudfunctions.net/stripeWebhook`
3. Select events: 
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.paid`
   - `invoice.payment_failed`
4. Copier webhook secret → `firebase functions:secrets:set STRIPE_WEBHOOK_SECRET`

#### C) Documentation
Create `docs/STRIPE_INTEGRATION.md`:
```markdown
# Stripe Integration Guide

## Checklist Pré-Production
- [ ] Compte Stripe créé (Business)
- [ ] Plans créés dans Stripe Dashboard
- [ ] Price IDs récupérés → Firestore stripePlans
- [ ] STRIPE_SECRET_KEY stocké dans Cloud Functions
- [ ] STRIPE_PUBLISHABLE_KEY dans Firebase Remote Config
- [ ] Webhooks configurés + secret setté
- [ ] Test mode: vérifier checkout mock
- [ ] Live mode: vérifier avec vraie carte (4242 4242 4242 4242)

## URLs Importantes
- Stripe Dashboard: https://dashboard.stripe.com
- Webhooks: https://dashboard.stripe.com/webhooks
- API Keys: https://dashboard.stripe.com/apikeys
```

## 🔄 Workflow Complet (Avec Compte Stripe)

```
Admin Workspace
  ↓
Plan Selection Screen (affiche 3 plans + pricing)
  ↓
"Passer au paiement" button
  ↓
Cloud Function: createCheckoutSession()
  ↓ (crée Customer Stripe + Checkout Session)
  ↓
Flutter Stripe SDK: presentPaymentSheet()
  ↓ (user entre carte)
  ↓
Stripe: charge carte
  ↓
Webhook: customer.subscription.created
  ↓ (sync Firestore: subscription.status = 'active')
  ↓
AdminSummaryScreen: "Abonnement activé ✓"
  ↓
Renouvellement auto mensuel
```

## 💾 Firestore Billing Collection (Optionnel, Future)
```javascript
workspaces/{id}/billing/
  ├─ invoices/{invoiceId}
  │  ├─ stripeInvoiceId: 'in_...'
  │  ├─ amount: 2900 (cents)
  │  ├─ currency: 'eur'
  │  ├─ paidAt: Timestamp
  │  └─ number: 'INV-001'
  │
  └─ usage/{year}/{month}
     ├─ commercialsActive: 3
     ├─ metreurActive: 1
     ├─ poseurActive: 3
     └─ totalCost: 2900 (cents)
```

## ✅ Définition "Fait"
- Cloud Functions Stripe implémentées (non deployed)
- Firestore schema prêt
- Frontend checkout screens créés (non connectés)
- Secrets management setup
- Documentation complète
- **À ajouter:** Après compte Stripe créé (stripe.com)
  1. Récupérer Secret Key → Cloud Functions secrets
  2. Créer 3 Price IDs → Firestore stripePlans
  3. Configurer webhooks → récupérer signature secret
  4. Deploy Cloud Functions
  5. Test avec cartes Stripe sandbox
