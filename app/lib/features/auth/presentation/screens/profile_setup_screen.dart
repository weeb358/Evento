import 'dart:async';
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
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();

  Uint8List? _pickedBytes;
  String? _pickedExt;
  bool _isSaving = false;
  String? _errorMessage;
  bool _wantsToOrganize = false;
  bool _hasSyncedProfile = false;
  Timer? _usernameDebounce;
  bool? _usernameAvailable;
  bool _checkingUsername = false;
  String? _originalUsername;

  void _syncFromExisting(AppUserProfile? profile) {
    if (_hasSyncedProfile || profile == null) return;
    _hasSyncedProfile = true;
    _wantsToOrganize = profile.canOrganizeEvents;
    _originalUsername = profile.username;
    if (profile.username != null) _usernameController.text = profile.username!;
    if (profile.name != null) _nameController.text = profile.name!;
    if (profile.city != null) _cityController.text = profile.city!;
    if (profile.bio != null) _bioController.text = profile.bio!;
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    setState(() => _usernameAvailable = null);

    final normalized = value.trim().toLowerCase();
    if (normalized == _originalUsername || !_isValidUsernameFormat(normalized)) return;

    _usernameDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _checkingUsername = true);
      final result = await ref.read(userProfileRepositoryProvider).isUsernameAvailable(normalized);
      if (!mounted) return;
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = result.when(ok: (available) => available, err: (_) => null);
      });
    });
  }

  bool _isValidUsernameFormat(String value) => RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(value);

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

    final username = _usernameController.text.trim().toLowerCase();
    if (username != _originalUsername && _usernameAvailable == false) return;

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
      username: username,
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
    _syncFromExisting(existingProfile);
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
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixText: '@',
                    suffixIcon: _checkingUsername
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _usernameAvailable == true
                            ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                            : _usernameAvailable == false
                                ? Icon(Icons.cancel_rounded, color: theme.colorScheme.error)
                                : null,
                    helperText: 'Lowercase letters, numbers, underscore — 3 to 20 characters',
                  ),
                  onChanged: _onUsernameChanged,
                  validator: (value) {
                    final normalized = (value ?? '').trim().toLowerCase();
                    if (!_isValidUsernameFormat(normalized)) return 'Invalid username format';
                    if (normalized != _originalUsername && _usernameAvailable == false) {
                      return 'Username is taken';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
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
