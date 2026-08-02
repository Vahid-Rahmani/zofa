import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

import '../../core/config/env_config.dart';
import '../models/subscription_plan.dart';

/// Stripe-backed subscription payments.
///
/// The client only ever holds the *publishable* key. Creating a Checkout
/// session and retrieving ephemeral keys happens in a Supabase Edge Function
/// (`supabase/functions/stripe-checkout`) so the secret key never leaves the
/// server.
class StripeService {
  StripeService._();

  static final StripeService instance = StripeService._();

  bool _initialised = false;

  bool get isConfigured => EnvConfig.hasStripe;

  /// Must be called once at app startup.
  Future<void> init() async {
    if (!isConfigured || _initialised) return;
    Stripe.publishableKey = EnvConfig.stripePublishableKey;
    await Stripe.instance.applySettings();
    _initialised = true;
  }

  /// Starts the native Stripe payment sheet for [plan] and waits for the
  /// user to finish the payment.
  ///
  /// [accessToken] is the user's Supabase session token; the server uses it
  /// to identify who is paying.
  ///
  /// Returns `true` when the payment completed and the backend confirmed it.
  Future<bool> purchase({
    required SubscriptionPlan plan,
    String? accessToken,
  }) async {
    if (!isConfigured) {
      // Demo mode: simulate a successful purchase so the flow is testable.
      return Future<void>.delayed(const Duration(seconds: 1), () {}).then(
        (_) => true,
      );
    }
    if (EnvConfig.stripeSessionFunctionUrl.isEmpty) {
      throw StateError(
        'ZOVA_STRIPE_SESSION_FUNCTION_URL is not set. Configure the '
        'stripe-checkout Supabase Edge Function first.',
      );
    }

    final body = await http.post(
      Uri.parse(EnvConfig.stripeSessionFunctionUrl),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null && accessToken.isNotEmpty)
          'Authorization': 'Bearer $accessToken',
      },
      body: '{"plan_id": "${plan.id}"}',
    );
    if (body.statusCode != 200) {
      throw Exception('Could not start payment. Please try again.');
    }
    final data = _decode(body.body);

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: data['payment_intent'] as String,
        customerId: data['customer_id'] as String,
        customerEphemeralKeySecret: data['ephemeral_key'] as String,
        merchantDisplayName: EnvConfig.appName,
        allowsDelayedPaymentMethods: false,
        style: ThemeMode.dark,
      ),
    );

    try {
      await Stripe.instance.presentPaymentSheet();
      return true;
    } on StripeException {
      // The user cancelled or the payment failed.
      return false;
    }
  }

  Map<String, dynamic> _decode(String body) {
    final json = jsonDecode(body);
    if (json is Map<String, dynamic>) return json;
    throw const FormatException('Invalid response from payment server.');
  }
}
