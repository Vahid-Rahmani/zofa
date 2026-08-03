import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/env_config.dart';
import '../../core/state/app_controller.dart';
import '../../core/state/ui_translation_controller.dart';
import '../../core/theme/zova_colors.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/tr_text.dart';
import '../../core/widgets/zova_logo.dart';
import '../../data/models/subscription_plan.dart';

/// Subscription paywall backed by Stripe.
///
/// Selecting a plan opens the native Stripe payment sheet. The secret API
/// key never enters the app; session creation happens in the
/// `stripe-checkout` Supabase Edge Function.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  SubscriptionPlan _selected = SubscriptionPlan.defaults[1];
  String? _error;
  bool _processing = false;

  Future<void> _subscribe() async {
    setState(() {
      _error = null;
      _processing = true;
    });
    final controller = context.read<AppController>();
    try {
      final ok = await controller.purchase(_selected);
      if (!mounted) return;
      if (ok) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.check_circle,
                color: ZovaColors.success, size: 40),
            title: Text(context.tr('Welcome to Premium!')),
            content: Text(context.tr('Every lesson and book is now unlocked.')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('Done')),
              ),
            ],
          ),
        );
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasStripe = EnvConfig.hasStripe;
    context.watch<UiTranslationController?>();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 8),
            const Center(child: ZovaLogo(size: 56)),
            const SizedBox(height: 24),
            const TrText(
              'Go Premium',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: ZovaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const TrText(
              'Unlock every lesson, book and game.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ZovaColors.textSecondary),
            ),
            const SizedBox(height: 28),
            for (final plan in SubscriptionPlan.defaults)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PlanTile(
                  plan: plan,
                  selected: plan.id == _selected.id,
                  onTap: () => setState(() => _selected = plan),
                ),
              ),
            const SizedBox(height: 12),
            if (!hasStripe) ...[
              const _DemoModeNotice(),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ZovaColors.error),
              ),
              const SizedBox(height: 12),
            ],
            GradientButton(
              label: context.trTempl('Start {0} plan', [
                _selected.name.toLowerCase(),
              ]),
              icon: Icons.lock_outline,
              loading: _processing,
              onPressed: _subscribe,
            ),
            const SizedBox(height: 16),
            const TrText(
              'Cancel anytime. Payments are processed securely by Stripe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: ZovaColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? ZovaColors.primary.withValues(alpha: 0.14)
              : ZovaColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? ZovaColors.primary : ZovaColors.surfaceRaised,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? ZovaColors.primary : ZovaColors.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: ZovaColors.textPrimary,
                        ),
                      ),
                      if (plan.mostPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: ZovaColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const TrText(
                            'Popular',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.billingPeriod,
                    style: const TextStyle(color: ZovaColors.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              plan.pricePerMonth,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: ZovaColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoModeNotice extends StatelessWidget {
  const _DemoModeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZovaColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZovaColors.warning.withValues(alpha: 0.4)),
      ),
      child: const TrText(
        'Demo mode: Stripe is not configured, so the purchase is simulated. '
        'Add your publishable key and the Edge Function URL to go live.',
        style: TextStyle(color: ZovaColors.textPrimary, fontSize: 13),
      ),
    );
  }
}
