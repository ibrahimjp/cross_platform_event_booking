import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

/// Creates a new event, or edits [event] when given. Pops with the saved event.
class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.event});

  final AdminEvent? event;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _TicketDraft {
  _TicketDraft([TicketCategory? ticket])
    : id = ticket?.id ?? '',
      name = TextEditingController(text: ticket?.name ?? ''),
      price = TextEditingController(text: ticket == null ? '' : _plain(ticket.price)),
      remaining = TextEditingController(text: ticket == null ? '' : '${ticket.remaining}'),
      description = TextEditingController(text: ticket?.description ?? '');

  final String id;
  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController remaining;
  final TextEditingController description;

  static String _plain(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  Json toJson() => {
    if (id.isNotEmpty) 'id': id,
    'name': name.text.trim(),
    'price': double.parse(price.text.trim()),
    'remaining': int.parse(remaining.text.trim()),
    'description': description.text.trim(),
  };

  void dispose() {
    name.dispose();
    price.dispose();
    remaining.dispose();
    description.dispose();
  }
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AdminEvent? _source = widget.event;
  late final _title = TextEditingController(text: _source?.title);
  late final _time = TextEditingController(text: _source?.time);
  late final _location = TextEditingController(text: _source?.location);
  late final _venue = TextEditingController(text: _source?.venue);
  late final _description = TextEditingController(text: _source?.description);
  late final _lineup = TextEditingController(text: _source?.lineup.join(', '));
  late final _imageUrl = TextEditingController(text: _source?.imageUrl);
  late final _aiReason = TextEditingController(text: _source?.aiReason);
  late final _attendees = TextEditingController(text: '${_source?.attendeeCount ?? 0}');
  late final List<_TicketDraft> _tickets = _source == null
      ? [_TicketDraft()]
      : _source.ticketCategories.map(_TicketDraft.new).toList();

  late String _category = _source?.category ?? '';
  late DateTime _startsAt = _source?.startsAt ?? _defaultStart();
  late DateTime _endsAt = _source?.endsAt ?? _defaultStart().add(const Duration(hours: 3));
  late bool _hidden = _source?.isHidden ?? false;
  late bool _trending = _source?.isTrending ?? false;
  late bool _garba = _source?.isGarbaSpecial ?? false;
  late double _match = (_source?.matchPercentage ?? 90).toDouble();
  late String? _hostId = _source?.hostId;
  late String _hostName = _source?.hostName ?? 'You (signed-in admin)';
  List<String> _categories = const [];
  UploadFile? _image;
  bool _saving = false;

  bool get _isEdit => _source != null;

  static DateTime _defaultStart() {
    final now = DateTime.now().add(const Duration(days: 7));
    return DateTime(now.year, now.month, now.day, 19);
  }

  @override
  void initState() {
    super.initState();
    AdminApi.instance
        .get('/api/admin/settings')
        .then((data) {
          if (!mounted) return;
          setState(() {
            _categories = PlatformSettings.fromJson(data['settings'] as Json?).categories;
            if (_category.isEmpty && _categories.isNotEmpty) _category = _categories.first;
          });
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _time,
      _location,
      _venue,
      _description,
      _lineup,
      _imageUrl,
      _aiReason,
      _attendees,
    ]) {
      controller.dispose();
    }
    for (final ticket in _tickets) {
      ticket.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _suggestTimeLabel() {
    final format = DateFormat('h:mm a');
    _time.text = '${format.format(_startsAt)} - ${format.format(_endsAt)}';
  }

  Future<void> _chooseImage() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      if (mounted) toast(context, 'Images must be 8 MB or smaller.', error: true);
      return;
    }
    setState(() => _image = UploadFile(file.name, bytes));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_endsAt.isBefore(_startsAt)) {
      toast(context, 'The end time must be after the start time.', error: true);
      return;
    }
    if (_category.isEmpty) {
      toast(context, 'Choose a category.', error: true);
      return;
    }
    final imageUrl = _imageUrl.text.trim();
    final data = <String, dynamic>{
      'title': _title.text.trim(),
      'category': _category,
      'startsAt': _startsAt.toUtc().toIso8601String(),
      'endsAt': _endsAt.toUtc().toIso8601String(),
      'time': _time.text.trim(),
      'location': _location.text.trim(),
      'venue': _venue.text.trim(),
      'description': _description.text.trim(),
      'lineup': _lineup.text.split(',').map((name) => name.trim()).where((name) => name.isNotEmpty).toList(),
      'ticketCategories': _tickets.map((ticket) => ticket.toJson()).toList(),
      'isHidden': _hidden,
      'isTrending': _trending,
      'isGarbaSpecial': _garba,
      'matchPercentage': _match.round(),
      'aiReason': _aiReason.text.trim(),
      'attendeeCount': int.tryParse(_attendees.text.trim()) ?? 0,
      if (_hostId != null && _hostId!.isNotEmpty) 'hostId': _hostId,
      if (_image == null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      if (_isEdit && _image == null && imageUrl.isEmpty && _source!.imageUrl.isNotEmpty) 'removeImage': true,
    };
    setState(() => _saving = true);
    try {
      final response = await AdminApi.instance.multipart(
        _isEdit ? 'PATCH' : 'POST',
        _isEdit ? '/api/admin/events/${_source!.id}' : '/api/admin/events',
        data,
        image: _image,
      );
      if (!mounted) return;
      toast(context, _isEdit ? 'Event saved.' : 'Event created.');
      Navigator.of(context).pop(AdminEvent.fromJson(response['event'] as Json));
    } on ApiException catch (error) {
      if (mounted) toast(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value, {int min = 2}) =>
      (value ?? '').trim().length < min ? 'Enter at least $min characters.' : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = {..._categories, if (_category.isNotEmpty) _category}.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit event' : 'New event'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: PageBody(
          maxWidth: 860,
          children: [
            SectionCard(
              title: 'Basics',
              child: Column(
                children: [
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) => _required(value, min: 3),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category.isEmpty ? null : _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final category in categories) DropdownMenuItem(value: category, child: Text(category)),
                    ],
                    onChanged: (value) => setState(() => _category = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
                    validator: (value) => _required(value, min: 10),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lineup,
                    decoration: const InputDecoration(labelText: 'Lineup', helperText: 'Separate names with commas.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'When & where',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          label: 'Starts',
                          value: _startsAt,
                          onTap: () async {
                            final picked = await _pickDateTime(_startsAt);
                            if (picked == null) return;
                            setState(() {
                              final duration = _endsAt.difference(_startsAt);
                              _startsAt = picked;
                              if (!_endsAt.isAfter(_startsAt)) {
                                _endsAt = _startsAt.add(duration.isNegative ? const Duration(hours: 3) : duration);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateField(
                          label: 'Ends',
                          value: _endsAt,
                          onTap: () async {
                            final picked = await _pickDateTime(_endsAt);
                            if (picked != null) setState(() => _endsAt = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _time,
                    decoration: InputDecoration(
                      labelText: 'Time label shown to customers',
                      suffixIcon: IconButton(
                        tooltip: 'Fill from dates',
                        icon: const Icon(Icons.auto_fix_high),
                        onPressed: _suggestTimeLabel,
                      ),
                    ),
                    validator: (value) => _required(value, min: 1),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _location,
                    decoration: const InputDecoration(labelText: 'City'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _venue,
                    decoration: const InputDecoration(labelText: 'Venue / address'),
                    validator: _required,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Tickets & inventory',
              trailing: TextButton.icon(
                onPressed: _tickets.length >= 20 ? null : () => setState(() => _tickets.add(_TicketDraft())),
                icon: const Icon(Icons.add),
                label: const Text('Add tier'),
              ),
              child: Column(
                children: [
                  for (final ticket in _tickets) ...[
                    _TicketEditor(
                      key: ObjectKey(ticket),
                      draft: ticket,
                      onRemove: _tickets.length == 1
                          ? null
                          : () => setState(() {
                              _tickets.remove(ticket);
                              ticket.dispose();
                            }),
                    ),
                    if (ticket != _tickets.last) const Divider(height: 28),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Image',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 7,
                      child: _image != null
                          ? Image.memory(_image!.bytes, fit: BoxFit.cover)
                          : ListenableBuilder(
                              listenable: _imageUrl,
                              builder: (context, _) => _imageUrl.text.trim().isEmpty
                                  ? Container(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      child: const Icon(Icons.image_outlined, size: 48),
                                    )
                                  : Image.network(
                                      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                                      _imageUrl.text.trim(),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        color: theme.colorScheme.surfaceContainerHighest,
                                        child: const Center(child: Text('Image could not be loaded')),
                                      ),
                                    ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _chooseImage,
                        icon: const Icon(Icons.upload),
                        label: Text(_image == null ? 'Upload image' : 'Replace upload'),
                      ),
                      if (_image != null || _imageUrl.text.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _image = null;
                            _imageUrl.clear();
                          }),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove image'),
                        ),
                    ],
                  ),
                  if (_image == null) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _imageUrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Or image URL',
                        helperText: 'Uploads need Cloudinary keys on the server; a public URL always works.',
                      ),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${_image!.name} · ${(_image!.bytes.length / 1024).round()} KB selected'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Admin controls',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Host account'),
                    subtitle: Text(_hostName),
                    trailing: const Icon(Icons.swap_horiz),
                    onTap: () async {
                      final user = await pickUser(context, title: 'Assign host');
                      if (user != null) {
                        setState(() {
                          _hostId = user.id;
                          _hostName = '${user.name} (${user.email})';
                        });
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hidden from customers'),
                    subtitle: const Text('Hidden events cannot be found or booked in the app.'),
                    value: _hidden,
                    onChanged: (value) => setState(() => _hidden = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Trending'),
                    value: _trending,
                    onChanged: (value) => setState(() => _trending = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Garba special'),
                    value: _garba,
                    onChanged: (value) => setState(() => _garba = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('AI match'),
                      Expanded(
                        child: Slider(
                          value: _match,
                          max: 100,
                          divisions: 100,
                          label: '${_match.round()}%',
                          onChanged: (value) => setState(() => _match = value),
                        ),
                      ),
                      SizedBox(width: 44, child: Text('${_match.round()}%')),
                    ],
                  ),
                  TextFormField(
                    controller: _aiReason,
                    maxLength: 300,
                    decoration: const InputDecoration(labelText: 'AI recommendation reason'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _attendees,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Displayed attendee count'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today, size: 18)),
        child: Text(dateTime(value)),
      ),
    );
  }
}

class _TicketEditor extends StatelessWidget {
  const _TicketEditor({super.key, required this.draft, this.onRemove});

  final _TicketDraft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final numberField = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: draft.name,
                decoration: const InputDecoration(labelText: 'Tier name'),
                validator: (value) => (value ?? '').trim().length < 2 ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: draft.price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: numberField,
                decoration: const InputDecoration(labelText: 'Price ₹'),
                validator: (value) => double.tryParse((value ?? '').trim()) == null ? 'Number' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: draft.remaining,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Left'),
                validator: (value) => int.tryParse((value ?? '').trim()) == null ? 'Number' : null,
              ),
            ),
            IconButton(tooltip: 'Remove tier', onPressed: onRemove, icon: const Icon(Icons.remove_circle_outline)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: draft.description,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'Tier description', counterText: ''),
        ),
      ],
    );
  }
}
