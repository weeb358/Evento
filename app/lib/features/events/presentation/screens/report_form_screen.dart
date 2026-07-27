import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/reports/report_providers.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_spacing.dart';

const _kReportReasons = [
  'Spam or misleading',
  'Inappropriate content',
  'Harassment or abuse',
  'Scam or fraud',
  'Safety concern',
  'Other',
];

/// Reused for both event and user reports — [targetType] is `'event'` or
/// `'user'` (reporting a host is reporting their user id).
class ReportFormScreen extends ConsumerStatefulWidget {
  const ReportFormScreen({super.key, required this.targetType, required this.targetId});

  final String targetType;
  final String targetId;

  @override
  ConsumerState<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends ConsumerState<ReportFormScreen> {
  String _reason = _kReportReasons.first;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _isSubmitting = true);
    final details = _detailsController.text.trim();
    final reason = details.isEmpty ? _reason : '$_reason: $details';

    final result = await ref.read(reportRepositoryProvider).submitReport(
          reporterId: userId,
          targetType: widget.targetType,
          targetId: widget.targetId,
          reason: reason,
        );

    if (!mounted) return;
    result.when(
      ok: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thanks for letting us know.')),
        );
        context.pop();
      },
      err: (failure) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Why are you reporting this?', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              RadioGroup<String>(
                groupValue: _reason,
                onChanged: (value) => setState(() => _reason = value ?? _reason),
                child: Column(
                  children: _kReportReasons
                      .map(
                        (reason) => RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(reason),
                          value: reason,
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _detailsController,
                decoration: const InputDecoration(labelText: 'Additional details (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
