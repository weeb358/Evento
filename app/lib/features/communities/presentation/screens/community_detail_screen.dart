import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/users/user_profile_providers.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/community.dart';
import '../controllers/community_providers.dart';

class CommunityDetailScreen extends ConsumerStatefulWidget {
  const CommunityDetailScreen({super.key, required this.communityId});

  final String communityId;

  @override
  ConsumerState<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen> {
  final _postController = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    final content = _postController.text.trim();
    if (content.isEmpty) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _isPosting = true);
    await ref.read(communityRepositoryProvider).createPost(
          communityId: widget.communityId,
          authorId: userId,
          content: content,
        );
    ref.invalidate(communityPostsProvider(widget.communityId));
    _postController.clear();
    if (mounted) setState(() => _isPosting = false);
  }

  Future<void> _toggleMembership(bool isMember) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      context.push('/auth/email-login');
      return;
    }
    final repo = ref.read(communityRepositoryProvider);
    if (isMember) {
      await repo.leave(communityId: widget.communityId, userId: userId);
    } else {
      await repo.join(communityId: widget.communityId, userId: userId);
    }
    ref.invalidate(myMembershipProvider(widget.communityId));
    ref.invalidate(communityMembersProvider(widget.communityId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final communityAsync = ref.watch(communityProvider(widget.communityId));
    final membershipAsync = ref.watch(myMembershipProvider(widget.communityId));
    final postsAsync = ref.watch(communityPostsProvider(widget.communityId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      body: communityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load'),
        data: (community) {
          if (community == null) {
            return const EmptyState(icon: Icons.groups_outlined, title: 'Community not found');
          }
          final isMember = membershipAsync.valueOrNull != null;
          final isModerator = membershipAsync.valueOrNull?.isModerator ?? false;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 160,
                pinned: true,
                actions: [
                  if (isModerator)
                    IconButton(
                      icon: const Icon(Icons.people_outline_rounded),
                      onPressed: () => context.push('/communities/${community.id}/members'),
                    )
                  else if (currentUserId != null)
                    IconButton(
                      icon: const Icon(Icons.flag_outlined),
                      onPressed: () => context.push(
                        '/reports/new?targetType=user&targetId=${community.createdBy}',
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: community.coverImageUrl != null
                      ? CachedNetworkImage(imageUrl: community.coverImageUrl!, fit: BoxFit.cover)
                      : Container(color: theme.colorScheme.surfaceContainerHighest),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(child: Text(community.name, style: theme.textTheme.headlineSmall)),
                              if (community.isPrivate) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.lock_outline_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                              ],
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => _toggleMembership(isMember),
                          child: Text(isMember ? 'Leave' : 'Join'),
                        ),
                      ],
                    ),
                    if (community.description != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(community.description!, style: theme.textTheme.bodyMedium),
                    ],
                    if ((community.rules ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Community rules'),
                        children: [Text(community.rules!)],
                      ),
                    ],
                    const Divider(height: AppSpacing.xxl),
                    if (isMember) ...[
                      TextField(
                        controller: _postController,
                        decoration: const InputDecoration(hintText: 'Share something with the community...'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _isPosting ? null : _submitPost,
                          child: const Text('Post'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    postsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (posts) {
                        if (posts.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                            child: Text(
                              'No posts yet.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          );
                        }
                        return Column(
                          children: posts
                              .map((post) => _PostCard(post: post, isModerator: isModerator))
                              .toList(),
                        );
                      },
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post, required this.isModerator});

  final CommunityPost post;
  final bool isModerator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authorAsync = ref.watch(userProfileProvider(post.authorId));
    final likeCountAsync = ref.watch(postLikeCountProvider(post.id));
    final isLikedAsync = ref.watch(isPostLikedProvider(post.id));

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(photoUrl: authorAsync.valueOrNull?.photoUrl, name: authorAsync.valueOrNull?.name, radius: 16),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authorAsync.valueOrNull?.name ?? '...', style: theme.textTheme.labelLarge),
                      Text(
                        DateFormat('MMM d, h:mm a').format(post.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (post.isPinned) Icon(Icons.push_pin_rounded, size: 16, color: theme.colorScheme.primary),
                if (isModerator)
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      final repo = ref.read(communityRepositoryProvider);
                      if (value == 'pin') {
                        await repo.setPostPinned(postId: post.id, isPinned: !post.isPinned);
                      } else if (value == 'delete') {
                        await repo.deletePost(post.id);
                      }
                      ref.invalidate(communityPostsProvider(post.communityId));
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'pin', child: Text(post.isPinned ? 'Unpin' : 'Pin')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(post.content),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    isLikedAsync.valueOrNull == true ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 18,
                    color: isLikedAsync.valueOrNull == true ? theme.colorScheme.error : null,
                  ),
                  onPressed: () async {
                    final userId = ref.read(currentUserIdProvider);
                    if (userId == null) return;
                    await ref.read(communityRepositoryProvider).toggleLike(postId: post.id, userId: userId);
                    ref.invalidate(postLikeCountProvider(post.id));
                    ref.invalidate(isPostLikedProvider(post.id));
                  },
                ),
                Text('${likeCountAsync.valueOrNull ?? 0}'),
                const SizedBox(width: AppSpacing.md),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.mode_comment_outlined, size: 18),
                  onPressed: () => context.push('/communities/posts/${post.id}'),
                ),
                const Text('Comments'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
