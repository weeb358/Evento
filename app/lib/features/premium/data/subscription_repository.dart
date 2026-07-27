import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/result.dart';

/// Payment is stubbed — see docs/ARCHITECTURE.md and
/// 0002_premium_hosting.sql. `activateStubbed` simulates a successful
/// checkout by inserting a subscription row directly; swap this method's
/// body for a real payment-gateway call + webhook-driven insert before
/// launch, the rest of the app (isPremiumProvider, PremiumGate, RLS) won't
/// need to change.
class SubscriptionRepository {
  SubscriptionRepository(this._client);

  final SupabaseClient _client;

  Future<Result<void>> activateStubbed({required String userId}) {
    return guard(() async {
      await _client.from('subscriptions').insert({
        'user_id': userId,
        'status': 'active',
        'current_period_end': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'payment_reference': 'stub-${DateTime.now().millisecondsSinceEpoch}',
      });
    });
  }

  Future<Result<void>> cancel({required String subscriptionId}) {
    return guard(() async {
      await _client.from('subscriptions').update({'status': 'canceled'}).eq('id', subscriptionId);
    });
  }
}
