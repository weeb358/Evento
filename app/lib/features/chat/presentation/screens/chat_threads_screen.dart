import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/users/user_profile_providers.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../data/chat_models.dart';
import '../controllers/chat_providers.dart';

class ChatThreadsScreen extends ConsumerWidget {
  const ChatThreadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(myThreadsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: threadsAsync.when(
        loading: () => const SkeletonList(),
        error: (_, _) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load chats'),
        data: (threads) {
          if (threads.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No conversations yet',
              message: 'Message a host, organizer, or community member to start chatting.',
            );
          }
          return ListView.builder(
            itemCount: threads.length,
            itemBuilder: (context, index) => _ThreadTile(thread: threads[index]),
          );
        },
      ),
    );
  }
}

class _ThreadTile extends ConsumerWidget {
  const _ThreadTile({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(currentUserIdProvider);
    final participantsAsync = ref.watch(threadParticipantsProvider(thread.id));
    final messagesAsync = ref.watch(threadMessagesProvider(thread.id));

    final lastMessage = messagesAsync.valueOrNull?.isNotEmpty == true
        ? messagesAsync.valueOrNull!.last
        : null;

    String? otherUserId;
    if (!thread.isGroup) {
      final participants = participantsAsync.valueOrNull ?? [];
      final other = participants.where((p) => p.userId != currentUserId).firstOrNull;
      otherUserId = other?.userId;
    }

    final otherProfileAsync = otherUserId != null ? ref.watch(userProfileProvider(otherUserId)) : null;
    final title = thread.isGroup ? (thread.title ?? 'Group chat') : (otherProfileAsync?.valueOrNull?.name ?? '...');
    final photoUrl = thread.isGroup ? null : otherProfileAsync?.valueOrNull?.photoUrl;

    return ListTile(
      onTap: () => context.push('/chat/${thread.id}'),
      leading: thread.isGroup
          ? CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(Icons.groups_rounded, color: theme.colorScheme.primary),
            )
          : AppAvatar(photoUrl: photoUrl, name: title),
      title: Text(title),
      subtitle: Text(
        lastMessage?.content ?? (lastMessage?.imageUrl != null ? '📷 Photo' : 'No messages yet'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: lastMessage != null
          ? Text(
              DateFormat('h:mm a').format(lastMessage.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          : null,
    );
  }
}
