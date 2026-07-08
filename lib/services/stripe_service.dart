import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Résultat d'un paiement ou d'une souscription Stripe.
class StripeResult {
  final String? paymentIntentId;
  final String? clientSecret;
  final String? status;
  final String? error;

  const StripeResult({
    this.paymentIntentId,
    this.clientSecret,
    this.status,
    this.error,
  });

  factory StripeResult.fromMap(Map<String, dynamic> map) {
    return StripeResult(
      paymentIntentId: map['paymentIntentId'] as String?,
      clientSecret: map['clientSecret'] as String?,
      status: map['status'] as String?,
      error: map['error'] as String?,
    );
  }
}

/// Résultat d'une session checkout Stripe.
class CheckoutSessionResult {
  final String? sessionId;
  final String? url;
  final String? error;

  const CheckoutSessionResult({
    this.sessionId,
    this.url,
    this.error,
  });

  factory CheckoutSessionResult.fromMap(Map<String, dynamic> map) {
    return CheckoutSessionResult(
      sessionId: map['sessionId'] as String?,
      url: map['url'] as String?,
      error: map['error'] as String?,
    );
  }
}

/// Position de facturation Stripe.
class StripeSubscriptionInfo {
  final String? subscriptionId;
  final String? status;
  final DateTime? currentPeriodEnd;
  final String? planId;

  const StripeSubscriptionInfo({
    this.subscriptionId,
    this.status,
    this.currentPeriodEnd,
    this.planId,
  });

  factory StripeSubscriptionInfo.fromMap(Map<String, dynamic> map) {
    return StripeSubscriptionInfo(
      subscriptionId: map['subscriptionId'] as String?,
      status: map['status'] as String?,
      currentPeriodEnd: map['currentPeriodEnd'] != null
          ? (map['currentPeriodEnd'] as dynamic).toDate()
          : null,
      planId: map['planId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (subscriptionId != null) 'subscriptionId': subscriptionId,
      if (status != null) 'status': status,
      if (currentPeriodEnd != null)
        'currentPeriodEnd': currentPeriodEnd!.toIso8601String(),
      if (planId != null) 'planId': planId,
    };
  }

  bool get isActive =>
      status == 'active' || status == 'trialing' || status == 'complete';
}

/// Service Stripe — façade pour les Cloud Functions de paiement.
///
/// Toute la logique sensible (clés secrètes, création d'intents) est
/// exécutée côté serveur via les Callable Functions.
class StripeService {
  static final StripeService _instance = StripeService._();
  factory StripeService() => _instance;
  StripeService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Crée un PaymentIntent pour un paiement unique.
  Future<StripeResult> createPaymentIntent({
    required int amount,
    required String currency,
    String? customerId,
    String? description,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('stripeCreatePaymentIntent')
          .call({
        'amount': amount,
        'currency': currency,
        'customerId': customerId,
        'description': description,
      });
      return StripeResult.fromMap(
          Map<String, dynamic>.from(result.data as Map));
    } catch (e) {
      debugPrint('StripeService.createPaymentIntent error: $e');
      return StripeResult(error: e.toString());
    }
  }

  /// Crée une session Checkout pour souscription ou paiement.
  Future<CheckoutSessionResult> createCheckoutSession({
    required String successUrl,
    required String cancelUrl,
    String? priceId,
    String? customerId,
    String? mode,
    String? workspaceId,
    String? planId,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('stripeCreateCheckoutSession')
          .call({
        'successUrl': successUrl,
        'cancelUrl': cancelUrl,
        'priceId': priceId,
        'customerId': customerId,
        'mode': mode ?? 'subscription',
        'workspaceId': workspaceId,
        'planId': planId,
      });
      return CheckoutSessionResult.fromMap(
          Map<String, dynamic>.from(result.data as Map));
    } catch (e) {
      debugPrint('StripeService.createCheckoutSession error: $e');
      return CheckoutSessionResult(error: e.toString());
    }
  }

  /// Récupère les infos d'abonnement pour un workspace.
  Future<StripeSubscriptionInfo?> getSubscription({
    required String workspaceId,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('stripeGetSubscription')
          .call({'workspaceId': workspaceId});
      final data = result.data as Map<String, dynamic>?;
      if (data == null || data.isEmpty) return null;
      return StripeSubscriptionInfo.fromMap(data);
    } catch (e) {
      debugPrint('StripeService.getSubscription error: $e');
      return null;
    }
  }

  /// Annule l'abonnement d'un workspace.
  Future<StripeResult> cancelSubscription({
    required String workspaceId,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('stripeCancelSubscription')
          .call({'workspaceId': workspaceId});
      return StripeResult.fromMap(
          Map<String, dynamic>.from(result.data as Map));
    } catch (e) {
      debugPrint('StripeService.cancelSubscription error: $e');
      return StripeResult(error: e.toString());
    }
  }

  /// Récupère ou crée un Customer Stripe pour l'utilisateur courant.
  Future<String?> getOrCreateCustomer({
    required String email,
    required String workspaceId,
    String? name,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('stripeGetOrCreateCustomer')
          .call({
        'email': email,
        'workspaceId': workspaceId,
        'name': name,
      });
      return result.data['customerId'] as String?;
    } catch (e) {
      debugPrint('StripeService.getOrCreateCustomer error: $e');
      return null;
    }
  }

  /// Vérifie si un workspace a un abonnement actif.
  Future<bool> hasActiveSubscription(String workspaceId) async {
    final sub = await getSubscription(workspaceId: workspaceId);
    return sub?.isActive ?? false;
  }
}
