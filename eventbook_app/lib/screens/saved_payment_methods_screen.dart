import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';

class SavedPaymentMethodsScreen extends StatefulWidget {
  const SavedPaymentMethodsScreen({super.key});

  @override
  State<SavedPaymentMethodsScreen> createState() => _SavedPaymentMethodsScreenState();
}

class _SavedPaymentMethodsScreenState extends State<SavedPaymentMethodsScreen> with WidgetsBindingObserver {
  List<SavedCard> _methods = [];
  bool _loading = true;
  bool _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMethods();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the Stripe page in the browser: refresh the card list.
    if (state == AppLifecycleState.resumed) _loadMethods();
  }

  String? get _token => context.read<AppState>().authToken;

  Future<void> _loadMethods() async {
    final token = _token;
    if (token == null) return;
    setState(() => _loading = true);
    try {
      final methods = await ApiService.getPaymentMethods(token);
      if (mounted) {
        setState(() {
          _methods = methods;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addCard() async {
    final token = _token;
    if (token == null) return;
    setState(() => _opening = true);
    try {
      final url = await ApiService.createCardSetupUrl(token);
      final opened = await openExternalUrl(url);
      if (!mounted) return;
      if (!opened) {
        showMessage(context, 'Could not open the Stripe page.', error: true);
      } else {
        showMessage(context, 'Add your card on the Stripe page, then come back and tap refresh.');
      }
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _removeCard(SavedCard card) async {
    final token = _token;
    if (token == null) return;
    try {
      await ApiService.removePaymentMethod(token, card.id);
      if (mounted) {
        setState(() => _methods.removeWhere((method) => method.id == card.id));
        showMessage(context, 'Card removed.');
      }
    } catch (error) {
      if (mounted) showMessage(context, errorText(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Payment Methods'),
        actions: [IconButton(tooltip: 'Refresh', onPressed: _loadMethods, icon: const Icon(Icons.refresh))],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMethods,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
            ],
            if (!_loading && _methods.isEmpty && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No saved cards yet. Cards you choose to save during checkout, or add here, are stored securely by Stripe.',
                ),
              ),
            ..._methods.map((card) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.credit_card),
                    title: Text('${card.brand.toUpperCase()} •••• ${card.last4}'),
                    subtitle: Text('Expires ${card.expMonth.toString().padLeft(2, '0')}/${card.expYear}'),
                    trailing: IconButton(
                      tooltip: 'Remove card',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeCard(card),
                    ),
                  ),
                )),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _opening ? null : _addCard,
              icon: const Icon(Icons.add_card),
              label: Text(_opening ? 'Opening Stripe…' : 'Add a card securely'),
            ),
          ],
        ),
      ),
    );
  }
}
