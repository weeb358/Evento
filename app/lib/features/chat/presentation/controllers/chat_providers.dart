import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/chat_models.dart';
import '../../data/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseClientProvider));
});

final myThreadsProvider = FutureProvider.autoDispose<List<ChatThread>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final result = await ref.watch(chatRepositoryProvider).getMyThreads(userId);
  return result.when(ok: (threads) => threads, err: (_) => []);
});

final threadParticipantsProvider = FutureProvider.autoDispose.family<List<ChatParticipant>, String>((ref, threadId) async {
  final result = await ref.watch(chatRepositoryProvider).getParticipants(threadId);
  return result.when(ok: (list) => list, err: (_) => []);
});

/// Live-updating message list for a thread via Supabase Realtime.
final threadMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, threadId) {
  return ref.watch(chatRepositoryProvider).watchMessages(threadId);
});
