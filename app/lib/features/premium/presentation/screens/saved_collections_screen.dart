import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/premium/premium_providers.dart';
import '../../../../core/saved/saved_event_providers.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';

class SavedCollectionsScreen extends ConsumerWidget {
  const SavedCollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(currentUserIdProvider) != null;
    final collectionsAsync = ref.watch(myCollectionsProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _createFolder(context, ref, isPremium),
          ),
        ],
      ),
      body: !isSignedIn
          ? const EmptyState(icon: Icons.bookmark_outline_rounded, title: 'Sign in to save events')
          : collectionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load'),
              data: (collections) {
                if (collections.isEmpty) {
                  return const EmptyState(icon: Icons.bookmark_outline_rounded, title: 'No saved events yet');
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: collections.length,
                  itemBuilder: (context, index) {
                    final collection = collections[index];
                    return ListTile(
                      leading: Icon(collection.isDefault ? Icons.bookmark_rounded : Icons.folder_rounded),
                      title: Text(collection.name),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/saved/${collection.id}'),
                    );
                  },
                );
              },
            ),
    );
  }

  void _createFolder(BuildContext context, WidgetRef ref, bool isPremium) {
    if (!isPremium) {
      context.push('/premium/paywall');
      return;
    }
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Folder name')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final userId = ref.read(currentUserIdProvider);
              final name = controller.text.trim();
              if (userId == null || name.isEmpty) return;
              await ref.read(savedEventRepositoryProvider).createCollection(
                    userId: userId,
                    name: name,
                    isPremium: isPremium,
                  );
              ref.invalidate(myCollectionsProvider);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
