import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/ticket_type.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_refresh_provider.dart';
import '../../services/event_service.dart';
import '../../services/supabase_service.dart';
import '../../services/ticket_service.dart';
import '../../theme/app_colors.dart';

class _TicketTypeDraft {
  /// Non-null when this draft represents an existing DB row being edited.
  /// Null means "new ticket type, not saved yet".
  final String? id;
  final int quantitySold;
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController qtyController;

  _TicketTypeDraft({this.id, this.quantitySold = 0})
      : nameController = TextEditingController(),
        priceController = TextEditingController(),
        qtyController = TextEditingController();

  factory _TicketTypeDraft.fromExisting(TicketType t) {
    final draft = _TicketTypeDraft(id: t.id, quantitySold: t.quantitySold);
    draft.nameController.text = t.name;
    draft.priceController.text = t.price == t.price.roundToDouble()
        ? t.price.toStringAsFixed(0)
        : t.price.toString();
    draft.qtyController.text = t.quantityAvailable.toString();
    return draft;
  }

  /// Tickets that already have sales can't be safely deleted — deleting a
  /// ticket_type row cascades to delete every registration tied to it
  /// (see eventhive_schema.sql), which would silently un-register real
  /// attendees. So the remove button is disabled once quantitySold > 0.
  bool get canRemove => quantitySold == 0;

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    qtyController.dispose();
  }
}

class CreateEditEventScreen extends StatefulWidget {
  /// Pass an eventId to edit an existing event. Null means create new.
  final String? eventId;
  const CreateEditEventScreen({super.key, this.eventId});

  bool get isEditing => eventId != null;

  @override
  State<CreateEditEventScreen> createState() => _CreateEditEventScreenState();
}

class _CreateEditEventScreenState extends State<CreateEditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();

  // Cover image: either a freshly picked image (not yet uploaded) or,
  // when editing, the event's existing cover URL. _newCoverBytes takes
  // priority for preview and for what gets uploaded on save.
  Uint8List? _newCoverBytes;
  String? _newCoverExt;
  String? _existingCoverUrl;

  String? _category;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  List<_TicketTypeDraft> _ticketDrafts = [_TicketTypeDraft()];
  List<String> _originalTicketTypeIds = [];
  String _currentStatus = 'draft'; // only meaningful once loaded when editing

  bool _isLoadingExisting = false;
  bool _isSaving = false;
  String? _error;

  static const _categories = [
    'Technology',
    'Business',
    'Music & Arts',
    'Education',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadExistingEvent();
    }
  }

  Future<void> _loadExistingEvent() async {
    setState(() => _isLoadingExisting = true);
    try {
      final event = await EventService.instance.fetchEventById(widget.eventId!);
      final ticketTypes = await TicketService.instance
          .fetchTicketTypesForEvent(widget.eventId!);

      _titleController.text = event.title;
      _descriptionController.text = event.description ?? '';
      _venueController.text = event.venue ?? '';
      _existingCoverUrl = event.coverImageUrl;
      _category = _categories.contains(event.category) ? event.category : null;
      _selectedDate = event.startDate;
      _selectedTime = TimeOfDay.fromDateTime(event.startDate);
      _currentStatus = event.status;

      for (final d in _ticketDrafts) {
        d.dispose();
      }
      _ticketDrafts = ticketTypes.isEmpty
          ? [_TicketTypeDraft()]
          : ticketTypes.map((t) => _TicketTypeDraft.fromExisting(t)).toList();
      _originalTicketTypeIds = ticketTypes.map((t) => t.id).toList();

      setState(() => _isLoadingExisting = false);
    } catch (e) {
      setState(() {
        _isLoadingExisting = false;
        _error = 'Could not load this event for editing.';
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    for (final d in _ticketDrafts) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';
    setState(() {
      _newCoverBytes = bytes;
      _newCoverExt = ext;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _addTicketType() {
    setState(() => _ticketDrafts.add(_TicketTypeDraft()));
  }

  void _removeTicketType(int index) {
    setState(() {
      _ticketDrafts[index].dispose();
      _ticketDrafts.removeAt(index);
    });
  }

  Future<void> _save({required String targetStatus}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      setState(() => _error = 'Please pick a date.');
      return;
    }
    final validDrafts = _ticketDrafts
        .where((d) => d.nameController.text.trim().isNotEmpty)
        .toList();
    if (validDrafts.isEmpty) {
      setState(() => _error = 'Add at least one ticket type.');
      return;
    }

    final userId = context.read<AuthProvider>().profile?.id;
    if (userId == null) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final startDate = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime?.hour ?? 9,
        _selectedTime?.minute ?? 0,
      );

      final client = Supabase.instance.client;

      // If a new image was picked, upload it now and use the resulting
      // URL. If editing and nothing new was picked, keep whatever cover
      // was already there. If creating fresh with no image picked,
      // cover stays null — EventCard/EventDetails already render a
      // placeholder gracefully for events with no cover.
      String? coverUrl = _existingCoverUrl;
      if (_newCoverBytes != null) {
        coverUrl = await SupabaseService.instance.uploadEventCover(
          _newCoverBytes!,
          fileExt: _newCoverExt ?? 'jpg',
        );
      }

      final eventPayload = {
        'organizer_id': userId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _category,
        'venue': _venueController.text.trim(),
        'cover_image_url': coverUrl,
        'start_date': startDate.toIso8601String(),
        'status': targetStatus,
      };

      String eventId;
      if (widget.isEditing) {
        eventId = widget.eventId!;
        await client.from('events').update(eventPayload).eq('id', eventId);
      } else {
        final row =
        await client.from('events').insert(eventPayload).select().single();
        eventId = row['id'] as String;
      }

      // Reconcile ticket types: update existing rows in place, insert new
      // ones, and only delete rows the user removed AND that never had a
      // sale (canRemove already enforces this in the UI, checked again
      // here as a safety net).
      final currentIds = <String>{};
      for (final draft in validDrafts) {
        final payload = {
          'event_id': eventId,
          'name': draft.nameController.text.trim(),
          'price': double.tryParse(draft.priceController.text.trim()) ?? 0,
          'quantity_available':
          int.tryParse(draft.qtyController.text.trim()) ?? 0,
        };
        if (draft.id != null) {
          currentIds.add(draft.id!);
          await client.from('ticket_types').update(payload).eq('id', draft.id!);
        } else {
          await client.from('ticket_types').insert(payload);
        }
      }

      final removedIds = _originalTicketTypeIds
          .where((id) => !currentIds.contains(id))
          .toList();
      for (final id in removedIds) {
        await client.from('ticket_types').delete().eq('id', id);
      }

      if (!mounted) return;
      context.read<DataRefreshProvider>().bump();
      final message = switch (targetStatus) {
        'published' when widget.isEditing => 'Event published!',
        'published' => 'Event published!',
        'draft' => 'Draft saved',
        _ => 'Event updated',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop(true); // true = "something changed, refresh"
    } catch (e) {
      setState(() {
        _error = 'Could not save event. Please try again.';
        _isSaving = false;
      });
    }
  }

  /// Cancels the event — distinct from Delete. Cancelling keeps the event
  /// (and its registrant history) intact and visible to the organizer,
  /// just blocks new registrations and marks it clearly for attendees,
  /// whereas Delete removes it entirely along with its registrations.
  /// The database automatically notifies every existing registrant when
  /// this happens (see notify_event_cancelled() in stage4c_migration.sql).
  Future<void> _cancelEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancel this event?'),
        content: const Text(
          'This blocks new registrations and notifies everyone already '
              'registered that the event was cancelled. The event and its '
              'registrant history stay visible to you — this is different '
              'from deleting it. You can still edit the event afterward, but '
              'there\'s no "un-cancel" button, so be sure before confirming.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Never mind'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel event',
                style: TextStyle(color: AppColors.statusDanger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('events')
          .update({'status': 'cancelled'}).eq('id', widget.eventId!);
      if (!mounted) return;
      context.read<DataRefreshProvider>().bump();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event cancelled. Registrants have been notified.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _isSaving = false;
        _error = 'Could not cancel event. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingExisting) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit event')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final dateLabel = _selectedDate == null
        ? 'mm/dd/yyyy'
        : DateFormat('MM/dd/yyyy').format(_selectedDate!);
    final timeLabel =
    _selectedTime == null ? '--:-- --' : _selectedTime!.format(context);

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.isEditing ? 'Edit event' : 'Create event')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GestureDetector(
              onTap: _pickCoverImage,
              child: Container(
                width: double.infinity,
                height: 180,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _newCoverBytes != null
                    ? Image.memory(_newCoverBytes!, fit: BoxFit.cover, width: double.infinity)
                    : (_existingCoverUrl != null
                    ? Image.network(_existingCoverUrl!,
                    fit: BoxFit.cover, width: double.infinity)
                    : const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          color: AppColors.textSecondary, size: 32),
                      SizedBox(height: 8),
                      Text('Tap to add photo',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text('High-res JPG or PNG',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                )),
              ),
            ),
            if (_newCoverBytes != null || _existingCoverUrl != null) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Change photo'),
                  onPressed: _pickCoverImage,
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text('Event Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., Tech Innovators Conference 2024',
              ),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe the purpose, agenda, and key takeaways...',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(dateLabel),
                    onPressed: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text(timeLabel),
                    onPressed: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _venueController,
              decoration: const InputDecoration(
                labelText: 'Venue / Address',
                hintText: 'Search for a location...',
              ),
            ),
            const SizedBox(height: 28),
            const Text('Ticket types',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._ticketDrafts.asMap().entries.map((entry) {
              final i = entry.key;
              final draft = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: draft.nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              hintText: 'General Admission',
                            ),
                          ),
                        ),
                        if (_ticketDrafts.length > 1)
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: draft.canRemove
                                  ? AppColors.statusDanger
                                  : AppColors.textMuted,
                            ),
                            onPressed: draft.canRemove
                                ? () => _removeTicketType(i)
                                : null,
                            tooltip: draft.canRemove
                                ? null
                                : 'Already has ${draft.quantitySold} sold — can\'t remove',
                          ),
                      ],
                    ),
                    if (!draft.canRemove)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 6),
                        child: Text(
                          '${draft.quantitySold} already sold — name, price, and quantity can still be edited',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: draft.priceController,
                            keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Price (\$)',
                              hintText: '0.00',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: draft.qtyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Qty',
                              hintText: '100',
                            ),
                            validator: (value) {
                              final qty = int.tryParse(value?.trim() ?? '');
                              if (qty == null) return null; // required-ness handled at save time
                              if (qty < draft.quantitySold) {
                                return 'Can\'t be less than ${draft.quantitySold} already sold';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              icon: const Icon(Icons.add, color: AppColors.accent),
              label: const Text('Add ticket type',
                  style: TextStyle(color: AppColors.accent)),
              onPressed: _addTicketType,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.statusDanger)),
            ],
            const SizedBox(height: 24),
            if (!widget.isEditing) ...[
              // CREATE mode: choose draft or publish outright.
              OutlinedButton(
                onPressed:
                _isSaving ? null : () => _save(targetStatus: 'draft'),
                child: const Text('Save draft'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed:
                _isSaving ? null : () => _save(targetStatus: 'published'),
                child: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Text('Publish event'),
              ),
            ] else if (_currentStatus == 'draft') ...[
              // EDITING A DRAFT: this is the case that was broken — editing
              // used to force-publish on every save with no way to just
              // update fields and stay a draft. Now there are two explicit
              // actions.
              OutlinedButton(
                onPressed:
                _isSaving ? null : () => _save(targetStatus: 'draft'),
                child: const Text('Save as draft'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed:
                _isSaving ? null : () => _save(targetStatus: 'published'),
                child: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Text('Publish event'),
              ),
            ] else ...[
              // EDITING an already-published (or cancelled) event: saving
              // preserves whatever its current status is — it should not
              // silently flip a published event back to some other state.
              ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () => _save(targetStatus: _currentStatus),
                child: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Text('Save changes'),
              ),
            ],
            // Cancel event — available while editing any event that isn't
            // already cancelled (draft or published). Kept visually
            // separate (a plain text link, not a button) so it doesn't
            // compete with Save/Publish for attention, but it's still
            // clearly reachable — this was previously missing entirely,
            // there was no way to cancel an event, only delete it.
            if (widget.isEditing && _currentStatus != 'cancelled') ...[
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: _isSaving ? null : _cancelEvent,
                  child: const Text('Cancel event',
                      style: TextStyle(color: AppColors.statusDanger)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}