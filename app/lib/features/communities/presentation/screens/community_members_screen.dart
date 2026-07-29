import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/users/user_profile_providers.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/community.dart';
import '../controllers/community_providers.dart';

class CommunityMembersScreen extends ConsumerWidget {
  const CommunityMembersScreen({super.key, required this.communityId});

  final String communityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(communityMembersProvider(communityId));
    final myMembership = ref.watch(myMembershipProvider(communityId)).valueOrNull;
    final isOwner = myMembership?.role == CommunityMemberRole.owner;

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load'),
        data: (members) {
          if (members.isEmpty) {
            return const EmptyState(icon: Icons.people_outline_rounded, title: 'No members');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final profileAsync = ref.watch(userProfileProvider(member.userId));

              return ListTile(
                onTap: () => context.push('/profile/${member.userId}'),
                leading: AppAvatar(photoUrl: profileAsync.valueOrNull?.photoUrl, name: profileAsync.valueOrNull?.name),
                title: Text(profileAsync.valueOrNull?.name ?? '...'),
                subtitle: Text(member.role.name),
                trailing: isOwner && member.role != CommunityMemberRole.owner
                    ? PopupMenuButton<String>(
                        onSelected: (value) async {
                          final repo = ref.read(communityRepositoryProvider);
                          if (value == 'promote') {
                            await repo.setMemberRole(
                              communityId: communityId,
                              userId: member.userId,
                              role: CommunityMemberRole.moderator,
                            );
                          } else if (value == 'demote') {
                            await repo.setMemberRole(
                              communityId: communityId,
                              userId: member.userId,
                              role: CommunityMemberRole.member,
                            );
                          } else if (value == 'remove') {
                            await repo.leave(communityId: communityId, userId: member.userId);
                          }
                          ref.invalidate(communityMembersProvider(communityId));
                        },
                        itemBuilder: (context) => [
                          if (member.role == CommunityMemberRole.member)
                            const PopupMenuItem(value: 'promote', child: Text('Make moderator')),
                          if (member.role == CommunityMemberRole.moderator)
                            const PopupMenuItem(value: 'demote', child: Text('Remove moderator')),
                          const PopupMenuItem(value: 'remove', child: Text('Remove from community')),
                        ],
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
