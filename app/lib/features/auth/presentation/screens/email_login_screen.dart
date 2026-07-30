import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/widgets/google_sign_in_button.dart';
import '../controllers/auth_controller.dart';

class EmailLoginScreen extends ConsumerStatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  ConsumerState<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends ConsumerState<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Clears any error left over from another auth screen (e.g. signup) —
    // without this, an unrelated failure banner (or a stale Google-picker
    // result) could show up here even though nothing has been submitted on
    // this screen yet, since the notifier's state is shared app-wide.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(emailAuthControllerProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final controller = ref.read(emailAuthControllerProvider.notifier);
    final ok = await controller.signIn(email: email, password: _passwordController.text);

    if (!mounted) return;
    if (!ok) {
      if (controller.failure is EmailNotConfirmedFailure) {
        context.push('/auth/email-verify', extra: email);
      } else {
        _showSignUpFirstDialog();
      }
    }
    // On success, the router's redirect picks up the new session and
    // navigates away — nothing else to do here.
  }

  Future<void> _submitGoogle() async {
    final controller = ref.read(emailAuthControllerProvider.notifier);
    final ok = await controller.signInWithGoogle(allowSignUp: false);

    if (!mounted || ok) return;
    // Cancellation and other real failures just leave the error banner up
    // via emailAuthControllerProvider's AsyncError state; only the "no
    // account yet" case gets the same prompt as the email flow.
    if (controller.failure is GoogleAccountNotRegisteredFailure) {
      _showSignUpFirstDialog(
        'No Evento account is linked to that Google account yet. Sign up first.',
      );
    }
  }

  void _showSignUpFirstDialog([
    String message = 'That email/password combination isn\'t recognized. If you don\'t have an '
        'account yet, sign up first.',
  ]) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Couldn\'t sign you in'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Try again')),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/auth/email-signup');
            },
            child: const Text('Sign up'),
          ),
        ],
      ),
    );
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sign in', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xl),
                GoogleSignInButton(onPressed: _submitGoogle, isLoading: isLoading),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: Text('or', style: theme.textTheme.bodySmall),
                    ),
                    Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) =>
                      (value ?? '').contains('@') ? null : 'Enter a valid email',
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (value) => (value ?? '').isEmpty ? 'Required' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/auth/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(errorMessage, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: AppSpacing.md),
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
                        : const Text('Sign in'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/auth/email-signup'),
                    child: const Text('Don\'t have an account? Sign up'),
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
