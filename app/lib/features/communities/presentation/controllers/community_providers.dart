import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/community.dart';
import '../../data/community_repository.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository(ref.watch(supabaseClientProvider));
});

final communitySearchProvider = StateProvider<String>((ref) => '');

final browseCommunitiesProvider = FutureProvider.autoDispose<List<Community>>((ref) async {
  final search = ref.watch(communitySearchProvider);
  final result = await ref.watch(communityRepositoryProvider).browseCommunities(search: search);
  return result.when(ok: (list) => list, err: (_) => []);
});

final myCommunitiesProvider = FutureProvider.autoDispose<List<Community>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final result = await ref.watch(communityRepositoryProvider).getMyCommunities(userId);
  return result.when(ok: (list) => list, err: (_) => []);
});

final communityProvider = FutureProvider.autoDispose.family<Community?, String>((ref, id) async {
  final result = await ref.watch(communityRepositoryProvider).getCommunity(id);
  return result.when(ok: (c) => c, err: (_) => null);
});

final myMembershipProvider = FutureProvider.autoDispose.family<CommunityMember?, String>((ref, communityId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final result = await ref.watch(communityRepositoryProvider).getMembership(communityId: communityId, userId: userId);
  return result.when(ok: (m) => m, err: (_) => null);
});

final communityMembersProvider = FutureProvider.autoDispose.family<List<CommunityMember>, String>((ref, communityId) async {
  final result = await ref.watch(communityRepositoryProvider).getMembers(communityId);
  return result.when(ok: (list) => list, err: (_) => []);
});

final communityPostsProvider = FutureProvider.autoDispose.family<List<CommunityPost>, String>((ref, communityId) async {
  final result = await ref.watch(communityRepositoryProvider).getPosts(communityId);
  return result.when(ok: (list) => list, err: (_) => []);
});

final postCommentsProvider = FutureProvider.autoDispose.family<List<PostComment>, String>((ref, postId) async {
  final result = await ref.watch(communityRepositoryProvider).getComments(postId);
  return result.when(ok: (list) => list, err: (_) => []);
});

final postLikeCountProvider = FutureProvider.autoDispose.family<int, String>((ref, postId) async {
  final result = await ref.watch(communityRepositoryProvider).getLikeCount(postId);
  return result.when(ok: (count) => count, err: (_) => 0);
});

final isPostLikedProvider = FutureProvider.autoDispose.family<bool, String>((ref, postId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;
  final result = await ref
      .watch(communityRepositoryProvider)
      .getLikedPostIds(postIds: [postId], userId: userId);
  return result.when(ok: (ids) => ids.contains(postId), err: (_) => false);
});
