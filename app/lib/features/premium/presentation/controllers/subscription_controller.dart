import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/users/user_profile_providers.dart';
import '../../data/subscription_repository.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(supabaseClientProvider));
});

class UpgradeController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> upgrade() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return false;

    state = const AsyncLoading();
    final result = await ref.read(subscriptionRepositoryProvider).activateStubbed(userId: userId);
    return result.when(
      ok: (_) {
        state = const AsyncData(null);
        ref.invalidate(currentUserProfileProvider);
        return true;
      },
      err: (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
    );
  }
}

final upgradeControllerProvider = AsyncNotifierProvider<UpgradeController, void>(UpgradeController.new);
