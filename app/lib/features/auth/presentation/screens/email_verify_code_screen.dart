import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';

import '../controllers/auth_controller.dart';

/// Completes signup with the 6-digit code from the confirmation email —
/// see docs/ARCHITECTURE.md for the custom-SMTP requirement that makes the
/// email actually contain a code instead of the default magic link.
class EmailVerifyCodeScreen extends ConsumerStatefulWidget {
  const EmailVerifyCodeScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<EmailVerifyCodeScreen> createState() => _EmailVerifyCodeScreenState();
}

class _EmailVerifyCodeScreenState extends ConsumerState<EmailVerifyCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  String? _resendMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(emailAuthControllerProvider.notifier).verifySignUpCode(
          email: widget.email,
          token: _codeController.text.trim(),
        );

    if (!mounted || !ok) return;
    context.go('/auth/profile-setup');
  }

  Future<void> _resend() async {
    final ok = await ref.read(emailAuthControllerProvider.notifier).resendSignUpCode(widget.email);
    if (!mounted) return;
    setState(() => _resendMessage = ok ? 'Sent a new code.' : 'Couldn\'t resend right now.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(emailAuthControllerProvider);
    final isLoading = state.isLoading;
    final errorMessage = ref.read(emailAuthControllerProvider.notifier).errorMessage;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Check your email', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Enter the 6-digit code we sent to ${widget.email}.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'Verification code'),
                  validator: (value) =>
                      (value ?? '').trim().length == 6 ? null : 'Enter the 6-digit code',
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(errorMessage, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Verify'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: isLoading ? null : _resend,
                  child: const Text('Resend code'),
                ),
                if (_resendMessage != null)
                  Text(
                    _resendMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
