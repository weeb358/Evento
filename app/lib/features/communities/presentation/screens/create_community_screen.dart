import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../controllers/community_providers.dart';

class CreateCommunityScreen extends ConsumerStatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  ConsumerState<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends ConsumerState<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPrivate = false;
  bool _isSaving = false;
  String? _errorMessage;
  bool _slugManuallyEdited = false;

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    if (_slugManuallyEdited) return;
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    _slugController.text = slug;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final result = await ref.read(communityRepositoryProvider).createCommunity(
          name: _nameController.text.trim(),
          slug: _slugController.text.trim(),
          createdBy: userId,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          isPrivate: _isPrivate,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    result.when(
      ok: (community) {
        ref.invalidate(browseCommunitiesProvider);
        ref.invalidate(myCommunitiesProvider);
        context.go('/communities/${community.id}');
      },
      err: (failure) => setState(() => _errorMessage = failure.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New community')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Community name'),
                  onChanged: _onNameChanged,
                  validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _slugController,
                  decoration: const InputDecoration(labelText: 'URL slug', prefixText: '/'),
                  onChanged: (_) => _slugManuallyEdited = true,
                  validator: (value) {
                    final slug = (value ?? '').trim();
                    if (!RegExp(r'^[a-z0-9-]{3,50}$').hasMatch(slug)) {
                      return 'Lowercase letters, numbers, hyphens — 3 to 50 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Private community'),
                  subtitle: const Text('Only members can see posts; joining requires an invite'),
                  value: _isPrivate,
                  onChanged: (value) => setState(() => _isPrivate = value),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Create community'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
