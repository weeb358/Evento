import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../controllers/hosting_providers.dart';

class BookingRequestFormScreen extends ConsumerStatefulWidget {
  const BookingRequestFormScreen({super.key, required this.hostId});

  final String hostId;

  @override
  ConsumerState<BookingRequestFormScreen> createState() => _BookingRequestFormScreenState();
}

class _BookingRequestFormScreenState extends ConsumerState<BookingRequestFormScreen> {
  DateTimeRange? _range;
  int _guestsCount = 1;
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (range != null) setState(() => _range = range);
  }

  Future<void> _submit() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _range == null) return;

    setState(() => _isSubmitting = true);

    final result = await ref.read(bookingRepositoryProvider).createRequest(
          hostId: widget.hostId,
          guestId: userId,
          startDate: _range!.start,
          endDate: _range!.end,
          guestsCount: _guestsCount,
          message: _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.when(
      ok: (_) {
        ref.invalidate(myTripsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request sent! You\'ll be notified when the host responds.')),
        );
        context.go('/hosting/bookings');
      },
      err: (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Request to stay')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dates'),
                subtitle: Text(
                  _range == null
                      ? 'Select dates'
                      : '${DateFormat('MMM d').format(_range!.start)} – ${DateFormat('MMM d, y').format(_range!.end)}',
                ),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _pickDates,
              ),
              Row(
                children: [
                  Text('Guests', style: theme.textTheme.bodyLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _guestsCount > 1 ? () => setState(() => _guestsCount--) : null,
                  ),
                  Text('$_guestsCount'),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _guestsCount++),
                  ),
                ],
              ),
              TextField(
                controller: _messageController,
                decoration: const InputDecoration(labelText: 'Message to host (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_range == null || _isSubmitting) ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Send request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
