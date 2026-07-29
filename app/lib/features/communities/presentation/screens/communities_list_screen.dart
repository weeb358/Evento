import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../data/community.dart';
import '../controllers/community_providers.dart';

class CommunitiesListScreen extends ConsumerStatefulWidget {
  const CommunitiesListScreen({super.key});

  @override
  ConsumerState<CommunitiesListScreen> createState() => _CommunitiesListScreenState();
}

class _CommunitiesListScreenState extends ConsumerState<CommunitiesListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Communities'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Discover'), Tab(text: 'My communities')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/communities/create'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search communities',
                  ),
                  onSubmitted: (value) => ref.read(communitySearchProvider.notifier).state = value,
                ),
              ),
              Expanded(child: _CommunityGrid(provider: browseCommunitiesProvider)),
            ],
          ),
          _CommunityGrid(provider: myCommunitiesProvider),
        ],
      ),
    );
  }
}

class _CommunityGrid extends ConsumerWidget {
  const _CommunityGrid({required this.provider});

  final ProviderListenable<AsyncValue<List<Community>>> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communitiesAsync = ref.watch(provider);

    return communitiesAsync.when(
      loading: () => const SkeletonList(),
      error: (_, _) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load communities'),
      data: (communities) {
        if (communities.isEmpty) {
          return const EmptyState(icon: Icons.groups_outlined, title: 'No communities yet');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          itemCount: communities.length,
          itemBuilder: (context, index) => _CommunityTile(community: communities[index]),
        );
      },
    );
  }
}

class _CommunityTile extends StatelessWidget {
  const _CommunityTile({required this.community});

  final Community community;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        onTap: () => context.push('/communities/${community.id}'),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          backgroundImage: community.coverImageUrl != null
              ? CachedNetworkImageProvider(community.coverImageUrl!)
              : null,
          child: community.coverImageUrl == null
              ? Icon(Icons.groups_rounded, color: theme.colorScheme.onSurfaceVariant)
              : null,
        ),
        title: Row(
          children: [
            Flexible(child: Text(community.name, overflow: TextOverflow.ellipsis)),
            if (community.isPrivate) ...[
              const SizedBox(width: 6),
              Icon(Icons.lock_outline_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
            ],
          ],
        ),
        subtitle: community.description != null
            ? Text(community.description!, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
