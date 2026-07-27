import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../events/data/event.dart';
import '../../../events/presentation/controllers/event_providers.dart';
import '../../data/event_template.dart';
import '../../data/event_template_repository.dart';

final eventTemplateRepositoryProvider = Provider<EventTemplateRepository>((ref) {
  return EventTemplateRepository(ref.watch(supabaseClientProvider), ref.watch(eventRepositoryProvider));
});

final myTemplatesProvider = FutureProvider.autoDispose<List<EventTemplate>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  final result = await ref.watch(eventTemplateRepositoryProvider).getMyTemplates(userId);
  return result.when(ok: (templates) => templates, err: (_) => []);
});

class EventTemplatesScreen extends ConsumerWidget {
  const EventTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(myTemplatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring templates'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => _showCreateSheet(context, ref)),
        ],
      ),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load'),
        data: (templates) {
          if (templates.isEmpty) {
            return const EmptyState(
              icon: Icons.event_repeat_rounded,
              title: 'No recurring templates yet',
              message: 'Create one to generate a weekly series of events in one go.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return Card(
                child: ListTile(
                  title: Text(template.title),
                  subtitle: Text(
                    'Every ${template.intervalWeeks} week(s) · ${template.occurrenceCount} occurrences',
                  ),
                  trailing: FilledButton(
                    onPressed: () async {
                      final events = await ref
                          .read(eventTemplateRepositoryProvider)
                          .generateEvents(template);
                      ref.invalidate(eventListProvider);
                      final count = events.when(ok: (list) => list.length, err: (_) => 0);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Generated $count events')),
                        );
                      }
                    },
                    child: const Text('Generate'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final cityController = TextEditingController();
    final venueController = TextEditingController();
    final priceController = TextEditingController(text: '0');
    var category = kEventCategories.first;
    var intervalWeeks = 1;
    var count = 4;
    var timeOfDay = '18:00';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New recurring template', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: kEventCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (value) => setState(() => category = value ?? category),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(controller: cityController, decoration: const InputDecoration(labelText: 'City')),
                    const SizedBox(height: AppSpacing.md),
                    TextField(controller: venueController, decoration: const InputDecoration(labelText: 'Venue')),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Price (Rs)'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: intervalWeeks,
                            decoration: const InputDecoration(labelText: 'Every N weeks'),
                            items: [1, 2, 4]
                                .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                                .toList(),
                            onChanged: (value) => setState(() => intervalWeeks = value ?? intervalWeeks),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: count,
                            decoration: const InputDecoration(labelText: 'Occurrences'),
                            items: [4, 8, 12]
                                .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                                .toList(),
                            onChanged: (value) => setState(() => count = value ?? count),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final userId = ref.read(currentUserIdProvider);
                          if (userId == null || titleController.text.trim().isEmpty) return;
                          await ref.read(eventTemplateRepositoryProvider).createTemplate(
                                organizerId: userId,
                                title: titleController.text.trim(),
                                category: category,
                                city: cityController.text.trim(),
                                venueName: venueController.text.trim(),
                                durationMinutes: 90,
                                price: double.tryParse(priceController.text.trim()) ?? 0,
                                intervalWeeks: intervalWeeks,
                                count: count,
                                timeOfDay: timeOfDay,
                              );
                          ref.invalidate(myTemplatesProvider);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: const Text('Create template'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
