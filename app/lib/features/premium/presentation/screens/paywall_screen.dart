import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/premium/premium_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../controllers/subscription_controller.dart';

const _kBenefits = [
  (Icons.tune_rounded, 'Advanced filters', 'Price range, distance radius, and "next 2 hours" search'),
  (Icons.folder_special_outlined, 'Unlimited saved folders', 'Organize saved events into your own collections'),
  (Icons.bolt_rounded, 'Early RSVP access', 'Grab a spot before capacity-limited events open to everyone'),
  (Icons.block_flipped, 'Ad-free browsing', 'A cleaner experience as ads roll out for free users'),
  (Icons.visibility_outlined, 'See who\'s going', 'View the full attendee list on events you\'ve RSVP\'d to'),
  (Icons.campaign_outlined, 'Organizer tools', 'Boosted placement, analytics, and recurring event templates'),
];

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPremium = ref.watch(isPremiumProvider);
    final upgradeState = ref.watch(upgradeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Icon(Icons.workspace_premium_rounded, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              isPremium ? 'You\'re Premium' : 'Get more out of every event',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            ..._kBenefits.map(
              (benefit) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(benefit.$1, color: theme.colorScheme.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(benefit.$2, style: theme.textTheme.titleSmall),
                          Text(
                            benefit.$3,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!isPremium)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: upgradeState.isLoading
                      ? null
                      : () async {
                          final ok = await ref.read(upgradeControllerProvider.notifier).upgrade();
                          if (ok && context.mounted) context.pop();
                        },
                  child: upgradeState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Upgrade — Rs 999/mo'),
                ),
              ),
            if (!isPremium) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Payment is a placeholder for now — this activates a 30-day Premium period directly.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
