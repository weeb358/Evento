import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/users/app_user_profile.dart';
import '../../../../core/users/user_profile_providers.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();

  Uint8List? _pickedBytes;
  String? _pickedExt;
  bool _isSaving = false;
  String? _errorMessage;
  bool _wantsToOrganize = false;
  bool _hasSyncedRole = false;

  void _syncRoleCheckbox(AppUserProfile? profile) {
    if (_hasSyncedRole || profile == null) return;
    _hasSyncedRole = true;
    _wantsToOrganize = profile.canOrganizeEvents;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _pickedBytes = bytes;
      _pickedExt = picked.name.split('.').last;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final repo = ref.read(userProfileRepositoryProvider);

    String? photoUrl;
    if (_pickedBytes != null) {
      final uploadResult = await repo.uploadAvatar(
        userId: userId,
        bytes: _pickedBytes!,
        fileExt: _pickedExt ?? 'jpg',
      );
      final failure = uploadResult.when(ok: (_) => null, err: (f) => f);
      if (failure != null) {
        setState(() {
          _isSaving = false;
          _errorMessage = failure.message;
        });
        return;
      }
      photoUrl = uploadResult.when(ok: (url) => url, err: (_) => null);
    }

    final result = await repo.updateProfile(
      userId: userId,
      name: _nameController.text.trim(),
      city: _cityController.text.trim(),
      bio: _bioController.text.trim(),
      photoUrl: photoUrl,
    );

    if (_wantsToOrganize) {
      await repo.requestEventPlannerRole();
    }

    if (!mounted) return;

    result.when(
      ok: (_) {
        ref.invalidate(currentUserProfileProvider);
        context.go('/events');
      },
      err: (failure) {
        setState(() {
          _isSaving = false;
          _errorMessage = failure.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existingProfile = ref.watch(currentUserProfileProvider).valueOrNull;
    _syncRoleCheckbox(existingProfile);
    final alreadyOrganizer = existingProfile?.canOrganizeEvents ?? false;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set up your profile', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'This is what organizers and other attendees will see.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      backgroundImage: _pickedBytes != null ? MemoryImage(_pickedBytes!) : null,
                      child: _pickedBytes == null
                          ? Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.onSurfaceVariant)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'City'),
                  validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _bioController,
                  decoration: const InputDecoration(labelText: 'Bio (optional)'),
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.sm),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('I want to organize events'),
                  subtitle: Text(
                    alreadyOrganizer ? 'You can already create events' : 'Makes you an Event Planner',
                  ),
                  value: _wantsToOrganize,
                  onChanged: alreadyOrganizer
                      ? null
                      : (value) => setState(() => _wantsToOrganize = value ?? false),
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
                        : const Text('Continue'),
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
