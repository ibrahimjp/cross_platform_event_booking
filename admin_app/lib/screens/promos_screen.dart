import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'shell.dart';

class PromosScreen extends StatefulWidget {
  const PromosScreen({super.key});

  @override
  State<PromosScreen> createState() => _PromosScreenState();
}

class _PromosScreenState extends State<PromosScreen> {
  List<Promo>? _promos;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await AdminApi.instance.get('/api/admin/promos');
      if (mounted) {
        setState(() {
          _promos = (data['promos'] as List).map((p) => Promo.fromJson(p as Json)).toList();
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _edit([Promo? promo]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PromoDialog(promo: promo),
    );
    if (saved == true) _load();
  }

  Future<void> _toggle(Promo promo, bool active) async {
    final ok = await runAction(
      context,
      () => AdminApi.instance.patch('/api/admin/promos/${promo.id}', {...promo.toJson(), 'active': active}),
      success: active ? '${promo.code} is active.' : '${promo.code} paused.',
    );
    if (ok) _load();
  }

  Future<void> _delete(Promo promo) async {
    if (!await confirmAction(
      context,
      title: 'Delete ${promo.code}?',
      message: 'Customers can no longer apply it. Past bookings keep their discount.',
      confirmLabel: 'Delete',
      destructive: true,
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await runAction(
      context,
      () => AdminApi.instance.delete('/api/admin/promos/${promo.id}'),
      success: 'Promo deleted.',
    );
    if (ok) _load();
  }

  String _describe(Promo promo) {
    final parts = [
      promo.isPercent
          ? '${promo.value.toStringAsFixed(promo.value % 1 == 0 ? 0 : 1)}% off'
          : '${money(promo.value)} off',
      if (promo.maxDiscount > 0) 'up to ${money(promo.maxDiscount)}',
      if (promo.minSubtotal > 0) 'min order ${money(promo.minSubtotal)}',
      if (promo.expiresAt != null) 'expires ${dateShort(promo.expiresAt)}',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final promos = _promos;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: sectionAppBar(
        context,
        'Promo codes',
        actions: [IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('New code'),
      ),
      body: promos == null
          ? (_error == null ? const LoadingView() : ErrorView(message: _error!, onRetry: _load))
          : PageBody(
              onRefresh: _load,
              children: [
                Text(
                  'Codes apply at checkout in the customer app. GST is charged on the discounted amount.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (promos.isEmpty)
                  const MessageView(icon: Icons.local_offer_outlined, message: 'No promo codes yet.')
                else
                  Card(
                    child: Column(
                      children: [
                        for (final promo in promos) ...[
                          ListTile(
                            onTap: () => _edit(promo),
                            leading: CircleAvatar(
                              backgroundColor: (promo.isLive ? Tone.success : Tone.neutral).withValues(alpha: 0.15),
                              child: Icon(Icons.local_offer, color: promo.isLive ? Tone.success : Tone.neutral),
                            ),
                            title: Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  promo.code,
                                  style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                ),
                                if (promo.isExpired) const StatusChip('Expired', color: Tone.danger),
                                if (promo.isExhausted) const StatusChip('Used up', color: Tone.warning),
                                if (!promo.active) const StatusChip('Paused'),
                              ],
                            ),
                            subtitle: Text(
                              [
                                _describe(promo),
                                if (promo.description.isNotEmpty) promo.description,
                                'used ${promo.uses}${promo.maxUses > 0 ? '/${promo.maxUses}' : ''} · '
                                    '${money(promo.totalDiscount)} discounted · ${money(promo.revenue)} revenue',
                              ].join('\n'),
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(value: promo.active, onChanged: (value) => _toggle(promo, value)),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(promo),
                                ),
                              ],
                            ),
                          ),
                          if (promo != promos.last) const Divider(),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PromoDialog extends StatefulWidget {
  const _PromoDialog({this.promo});

  final Promo? promo;

  @override
  State<_PromoDialog> createState() => _PromoDialogState();
}

class _PromoDialogState extends State<_PromoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Promo? _promo = widget.promo;
  late final _code = TextEditingController(text: _promo?.code);
  late final _description = TextEditingController(text: _promo?.description);
  late final _value = TextEditingController(text: _promo == null ? '' : _plain(_promo.value));
  late final _maxDiscount = TextEditingController(text: _plain(_promo?.maxDiscount ?? 0));
  late final _minSubtotal = TextEditingController(text: _plain(_promo?.minSubtotal ?? 0));
  late final _maxUses = TextEditingController(text: '${_promo?.maxUses ?? 0}');
  late String _type = _promo?.type ?? 'flat';
  late bool _active = _promo?.active ?? true;
  late DateTime? _expiresAt = _promo?.expiresAt;
  bool _busy = false;

  static String _plain(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  @override
  void dispose() {
    for (final controller in [_code, _description, _value, _maxDiscount, _minSubtotal, _maxUses]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final body = {
      'code': _code.text.trim().toUpperCase(),
      'description': _description.text.trim(),
      'type': _type,
      'value': double.parse(_value.text.trim()),
      'maxDiscount': double.tryParse(_maxDiscount.text.trim()) ?? 0,
      'minSubtotal': double.tryParse(_minSubtotal.text.trim()) ?? 0,
      'maxUses': int.tryParse(_maxUses.text.trim()) ?? 0,
      'active': _active,
      'expiresAt': _expiresAt?.toUtc().toIso8601String(),
    };
    final ok = await runAction(
      context,
      () => _promo == null
          ? AdminApi.instance.post('/api/admin/promos', body)
          : AdminApi.instance.patch('/api/admin/promos/${_promo.id}', body),
      success: _promo == null ? 'Promo code created.' : 'Promo code saved.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final decimal = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    return AlertDialog(
      title: Text(_promo == null ? 'New promo code' : 'Edit ${_promo.code}'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]'))],
                  decoration: const InputDecoration(labelText: 'Code', hintText: 'DIWALI25'),
                  validator: (value) => (value ?? '').trim().length < 3 ? 'At least 3 characters.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description (internal)'),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'flat', label: Text('Flat ₹ off')),
                    ButtonSegment(value: 'percent', label: Text('% off')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (value) => setState(() => _type = value.first),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _value,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: decimal,
                  decoration: InputDecoration(
                    labelText: _type == 'flat' ? 'Discount amount (₹)' : 'Discount percentage',
                  ),
                  validator: (value) {
                    final number = double.tryParse((value ?? '').trim());
                    if (number == null || number <= 0) return 'Enter a positive number.';
                    if (_type == 'percent' && number > 100) return 'At most 100%.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _maxDiscount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: decimal,
                        decoration: const InputDecoration(labelText: 'Max discount ₹', helperText: '0 = no cap'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _minSubtotal,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: decimal,
                        decoration: const InputDecoration(labelText: 'Min order ₹', helperText: '0 = any order'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _maxUses,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Usage limit', helperText: '0 = unlimited'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Expires'),
                  subtitle: Text(_expiresAt == null ? 'Never' : dateShort(_expiresAt)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_expiresAt != null)
                        IconButton(
                          tooltip: 'No expiry',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _expiresAt = null),
                        ),
                      IconButton(
                        tooltip: 'Pick date',
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final now = DateTime.now();
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _expiresAt ?? now.add(const Duration(days: 30)),
                            firstDate: now.subtract(const Duration(days: 1)),
                            lastDate: DateTime(now.year + 5),
                          );
                          if (date != null) {
                            setState(() => _expiresAt = DateTime(date.year, date.month, date.day, 23, 59, 59));
                          }
                        },
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
      ],
    );
  }
}
