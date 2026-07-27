import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as latlng;

import '../../../../core/premium/premium_gate.dart';
import '../../../../core/premium/premium_providers.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/event.dart';
import '../controllers/event_providers.dart';

/// Create when [eventId] is null, edit otherwise.
class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.eventId});

  final String? eventId;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _venueController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  final _capacityController = TextEditingController();

  String _category = kEventCategories.first;
  DateTime _startTime = DateTime.now().add(const Duration(days: 1));
  DateTime? _endTime;
  latlng.LatLng? _location;
  Uint8List? _pickedCoverBytes;
  String? _pickedCoverExt;
  bool _isFeatured = false;
  DateTime? _premiumRsvpOpensAt;
  bool _isSaving = false;
  bool _hasLoadedExisting = false;

  bool get _isEdit => widget.eventId != null;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _venueController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  void _loadExisting(Event event) {
    if (_hasLoadedExisting) return;
    _hasLoadedExisting = true;
    _titleController.text = event.title;
    _descriptionController.text = event.description ?? '';
    _cityController.text = event.city;
    _venueController.text = event.venueName ?? '';
    _priceController.text = event.price.toStringAsFixed(0);
    _capacityController.text = event.capacity?.toString() ?? '';
    _category = event.category;
    _startTime = event.startTime;
    _endTime = event.endTime;
    _isFeatured = event.isFeatured;
    _premiumRsvpOpensAt = event.premiumRsvpOpensAt;
    if (event.hasLocation) _location = latlng.LatLng(event.lat!, event.lng!);
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _pickedCoverBytes = bytes;
      _pickedCoverExt = picked.name.split('.').last;
    });
  }

  Future<void> _pickStartTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_startTime));
    if (time == null) return;
    setState(() => _startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _isSaving = true);

    final repo = ref.read(eventRepositoryProvider);
    String? coverUrl;
    if (_pickedCoverBytes != null) {
      final uploadResult = await repo.uploadCoverImage(
        organizerId: userId,
        bytes: _pickedCoverBytes!,
        fileExt: _pickedCoverExt ?? 'jpg',
      );
      coverUrl = uploadResult.when(ok: (url) => url, err: (_) => null);
    }

    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final capacity = int.tryParse(_capacityController.text.trim());

    final result = _isEdit
        ? await repo.updateEvent(
            id: widget.eventId!,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            category: _category,
            city: _cityController.text.trim(),
            venueName: _venueController.text.trim(),
            lat: _location?.latitude,
            lng: _location?.longitude,
            startTime: _startTime,
            endTime: _endTime,
            price: price,
            capacity: capacity,
            coverImageUrl: coverUrl,
            isFeatured: _isFeatured,
          )
        : await repo.createEvent(
            organizerId: userId,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            category: _category,
            city: _cityController.text.trim(),
            venueName: _venueController.text.trim(),
            lat: _location?.latitude,
            lng: _location?.longitude,
            startTime: _startTime,
            endTime: _endTime,
            price: price,
            capacity: capacity,
            coverImageUrl: coverUrl,
            isFeatured: _isFeatured,
            premiumRsvpOpensAt: _premiumRsvpOpensAt,
          );

    if (!mounted) return;
    setState(() => _isSaving = false);

    result.when(
      ok: (event) {
        ref.invalidate(eventListProvider);
        if (_isEdit) ref.invalidate(eventDetailProvider(event.id));
        context.go('/events/${event.id}');
      },
      err: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isEdit) {
      final eventAsync = ref.watch(eventDetailProvider(widget.eventId!));
      final event = eventAsync.valueOrNull;
      if (event != null) _loadExisting(event);
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit event' : 'Create event')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _pickCover,
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      image: _pickedCoverBytes != null
                          ? DecorationImage(image: MemoryImage(_pickedCoverBytes!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _pickedCoverBytes == null
                        ? Icon(Icons.add_photo_alternate_outlined, color: theme.colorScheme.onSurfaceVariant)
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 4,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: kEventCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) => setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'City'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _venueController,
                  decoration: const InputDecoration(labelText: 'Venue name'),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Tap the map to set the venue location', style: theme.textTheme.labelMedium),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: SizedBox(
                    height: 180,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: _location ?? const latlng.LatLng(30.3753, 69.3451),
                        initialZoom: _location != null ? 13 : 4.5,
                        onTap: (tapPosition, point) => setState(() => _location = point),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.eventsplatform.app',
                        ),
                        if (_location != null)
                          MarkerLayer(markers: [
                            Marker(
                              point: _location!,
                              width: 32,
                              height: 32,
                              child: Icon(Icons.location_on_rounded, color: theme.colorScheme.primary, size: 32),
                            ),
                          ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start time'),
                  subtitle: Text(_startTime.toString()),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: _pickStartTime,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Price (Rs, 0 = free)'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _capacityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Capacity (optional)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                PremiumGate(
                  featureName: 'Boosted placement',
                  description: 'Feature this event at the top of listings.',
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Feature this event'),
                    value: _isFeatured,
                    onChanged: (value) => setState(() => _isFeatured = value),
                  ),
                ),
                if (!_isEdit && ref.watch(isPremiumProvider) && _capacityController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Early access RSVP window'),
                    subtitle: Text(
                      _premiumRsvpOpensAt == null
                          ? 'Off — everyone can RSVP immediately'
                          : 'Opens to everyone at $_premiumRsvpOpensAt',
                    ),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: _startTime,
                      );
                      if (date == null) return;
                      setState(() => _premiumRsvpOpensAt = date);
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
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
                        : Text(_isEdit ? 'Save changes' : 'Publish event'),
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
