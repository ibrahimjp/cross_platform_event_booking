import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Create a new event, or edit one the user hosts when [event] is given.
class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.event});

  final Event? event;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _TicketFields {
  _TicketFields({this.id = '', String name = '', String price = '', String count = '', String description = ''})
      : name = TextEditingController(text: name),
        price = TextEditingController(text: price),
        count = TextEditingController(text: count),
        description = TextEditingController(text: description);

  final String id;
  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController count;
  final TextEditingController description;

  void dispose() {
    name.dispose();
    price.dispose();
    count.dispose();
    description.dispose();
  }
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _venue;
  late final TextEditingController _city;
  late final TextEditingController _description;
  late final TextEditingController _lineup;
  late String _category;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final List<_TicketFields> _tickets = [];
  ImageUpload? _newImage;
  bool _removeImage = false;
  bool _saving = false;

  bool get _editing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _title = TextEditingController(text: event?.title ?? '');
    _venue = TextEditingController(text: event?.venue ?? '');
    _city = TextEditingController(text: event?.location ?? '');
    _description = TextEditingController(text: event?.description ?? '');
    _lineup = TextEditingController(text: event?.lineup.join(', ') ?? '');
    _category = event?.category ?? 'Music';
    if (event != null) {
      _startDate = DateTime(event.startsAt.year, event.startsAt.month, event.startsAt.day);
      _startTime = TimeOfDay.fromDateTime(event.startsAt);
      if (event.isMultiDay) _endDate = DateTime(event.endsAt.year, event.endsAt.month, event.endsAt.day);
      _endTime = TimeOfDay.fromDateTime(event.endsAt);
      for (final ticket in event.ticketCategories) {
        _tickets.add(_TicketFields(
          id: ticket.id,
          name: ticket.name,
          price: ticket.price == ticket.price.roundToDouble() ? ticket.price.toInt().toString() : ticket.price.toString(),
          count: ticket.remaining.toString(),
          description: ticket.description,
        ));
      }
    } else {
      _tickets.add(_TicketFields(name: 'General Admission', price: '499', count: '100'));
    }
  }

  @override
  void dispose() {
    for (final controller in [_title, _venue, _city, _description, _lineup]) {
      controller.dispose();
    }
    for (final ticket in _tickets) {
      ticket.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({required bool end}) async {
    final now = DateTime.now();
    final first = end ? (_startDate ?? now) : DateTime(now.year, now.month, now.day);
    final current = end ? _endDate : _startDate;
    final value = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(first) ? current : first,
      firstDate: first,
      lastDate: DateTime(now.year + 3),
    );
    if (value == null) return;
    setState(() {
      if (end) {
        _endDate = value;
      } else {
        _startDate = value;
        if (_endDate != null && _endDate!.isBefore(value)) _endDate = null;
      }
    });
  }

  Future<void> _pickTime({required bool end}) async {
    final value = await showTimePicker(
      context: context,
      initialTime: (end ? _endTime : _startTime) ?? (end ? const TimeOfDay(hour: 22, minute: 0) : const TimeOfDay(hour: 18, minute: 0)),
    );
    if (value != null) setState(() => end ? _endTime = value : _startTime = value);
  }

  Future<void> _chooseImage() async {
    final image = await pickImage(context);
    if (image != null) {
      setState(() {
        _newImage = image;
        _removeImage = false;
      });
    }
  }

  DateTime _combine(DateTime date, TimeOfDay time) => DateTime(date.year, date.month, date.day, time.hour, time.minute);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _startTime == null) {
      showMessage(context, 'Choose the event date and start time.', error: true);
      return;
    }
    final startsAt = _combine(_startDate!, _startTime!);
    DateTime? endsAt;
    if (_endTime != null || _endDate != null) {
      endsAt = _combine(_endDate ?? _startDate!, _endTime ?? const TimeOfDay(hour: 23, minute: 59));
      // An end time earlier than the start on the same day means it runs past midnight.
      if (!endsAt.isAfter(startsAt)) endsAt = endsAt.add(const Duration(days: 1));
    }
    if (!_editing && startsAt.isBefore(DateTime.now())) {
      showMessage(context, 'The start time must be in the future.', error: true);
      return;
    }
    final timeLabel = _endTime == null
        ? _startTime!.format(context)
        : '${_startTime!.format(context)} - ${_endTime!.format(context)}';
    final draft = EventDraft(
      title: _title.text.trim(),
      category: _category,
      startsAt: startsAt,
      endsAt: endsAt,
      time: timeLabel,
      location: _city.text.trim(),
      venue: _venue.text.trim(),
      description: _description.text.trim(),
      lineup: _lineup.text.split(',').map((item) => item.trim()).where((item) => item.isNotEmpty).toList(),
      ticketCategories: _tickets
          .map((ticket) => TicketCategory(
                id: ticket.id,
                name: ticket.name.text.trim(),
                price: double.parse(ticket.price.text.trim()),
                description: ticket.description.text.trim(),
                remaining: int.parse(ticket.count.text.trim()),
              ))
          .toList(),
      removeImage: _removeImage,
    );

    setState(() => _saving = true);
    final appState = context.read<AppState>();
    try {
      if (_editing) {
        await appState.updateEvent(widget.event!.id, draft, _newImage);
      } else {
        await appState.createEvent(draft, _newImage);
      }
      if (!mounted) return;
      showMessage(context, _editing ? 'Event updated.' : 'Your event is live! People can now book tickets.');
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value, String label, {int min = 2}) =>
      value == null || value.trim().length < min ? '$label needs at least $min characters.' : null;

  @override
  Widget build(BuildContext context) {
    final existingImage = widget.event?.imageUrl ?? '';
    final showExisting = _newImage == null && !_removeImage && existingImage.isNotEmpty;
    final categories = {...eventCategories, _category}.toList();

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Event' : 'Host an Event')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Cover image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Material(
                  color: AppTheme.subtle(context),
                  child: InkWell(
                    onTap: _saving ? null : _chooseImage,
                    child: _newImage != null
                        ? Image.memory(Uint8List.fromList(_newImage!.bytes), fit: BoxFit.cover)
                        : showExisting
                            ? EventImage(existingImage)
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, size: 48, color: AppTheme.primary),
                                  SizedBox(height: 8),
                                  Text('Add a cover image', style: TextStyle(fontWeight: FontWeight.w600)),
                                  Text('Uploaded to Cloudinary · up to 8 MB', style: TextStyle(fontSize: 12, color: AppTheme.outline)),
                                ],
                              ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _saving ? null : _chooseImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_newImage != null || showExisting ? 'Change image' : 'Choose image'),
                ),
                if (_newImage != null || showExisting)
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _newImage = null;
                              _removeImage = existingImage.isNotEmpty;
                            }),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Remove', style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Event details', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Event name', border: OutlineInputBorder()),
              validator: (value) => _required(value, 'Event name', min: 3),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: categories.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
              onChanged: (value) => setState(() => _category = value!),
            ),
            const SizedBox(height: 16),
            const Text('When', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(end: false),
                    icon: const Icon(Icons.calendar_month),
                    label: Text(_startDate == null ? 'Start date' : DateFormat('EEE, MMM d, y').format(_startDate!)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(end: false),
                    icon: const Icon(Icons.schedule),
                    label: Text(_startTime?.format(context) ?? 'Start time'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(end: true),
                    icon: const Icon(Icons.event_available),
                    label: Text(_endDate == null ? 'End date (optional)' : DateFormat('EEE, MMM d, y').format(_endDate!)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(end: true),
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(_endTime?.format(context) ?? 'End time (optional)'),
                  ),
                ),
              ],
            ),
            if (_endDate != null || _endTime != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() {
                    _endDate = null;
                    _endTime = null;
                  }),
                  child: const Text('Clear end'),
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _venue,
              decoration: const InputDecoration(labelText: 'Venue', border: OutlineInputBorder()),
              validator: (value) => _required(value, 'Venue'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
              validator: (value) => _required(value, 'City'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), alignLabelWithHint: true),
              validator: (value) => _required(value, 'Description', min: 10),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lineup,
              decoration: const InputDecoration(
                labelText: 'Lineup / speakers (optional)',
                helperText: 'Separate names with commas',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Text('Ticket types', style: Theme.of(context).textTheme.headlineSmall)),
                TextButton.icon(
                  onPressed: _tickets.length >= 20 ? null : () => setState(() => _tickets.add(_TicketFields(count: '50'))),
                  icon: const Icon(Icons.add),
                  label: const Text('Add type'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < _tickets.length; index++) _buildTicket(index),
            const SizedBox(height: 20),
            GradientButton(
              loading: _saving,
              icon: _editing ? Icons.save_outlined : Icons.publish,
              label: _editing ? 'Save Changes' : 'Publish Event',
              onPressed: _submit,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTicket(int index) {
    final ticket = _tickets[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: ticket.name,
                  decoration: InputDecoration(labelText: 'Ticket ${index + 1} name'),
                  validator: (value) => _required(value, 'Ticket name'),
                ),
              ),
              if (_tickets.length > 1)
                IconButton(
                  tooltip: 'Remove ticket type',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => setState(() => _tickets.removeAt(index).dispose()),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: ticket.price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price (₹, 0 = free)', prefixText: '₹ '),
                  validator: (value) {
                    final price = double.tryParse(value?.trim() ?? '');
                    return price == null || price < 0 || price > 10000000 ? 'Enter a valid price.' : null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: ticket.count,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: _editing ? 'Tickets remaining' : 'Tickets available'),
                  validator: (value) {
                    final count = int.tryParse(value?.trim() ?? '');
                    return count == null || count < 0 || count > 1000000 ? 'Enter a valid quantity.' : null;
                  },
                ),
              ),
            ],
          ),
          TextFormField(
            controller: ticket.description,
            decoration: const InputDecoration(labelText: 'What\'s included (optional)'),
          ),
        ],
      ),
    );
  }
}
