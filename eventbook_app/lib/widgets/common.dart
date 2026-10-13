import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.redAccent : null,
      behavior: SnackBarBehavior.floating,
    ));
}

String errorText(Object error) => error is ApiException ? error.message : 'Something went wrong: $error';

Future<bool> openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}

/// Lets the user pick a photo from the gallery / file system.
Future<ImageUpload?> pickImage(BuildContext context) async {
  try {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 88);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      if (context.mounted) showMessage(context, 'Images must be 8 MB or smaller.', error: true);
      return null;
    }
    final name = file.name.isNotEmpty ? file.name : 'photo.jpg';
    return ImageUpload(bytes: bytes, filename: name.contains('.') ? name : '$name.jpg');
  } catch (error) {
    if (context.mounted) showMessage(context, 'Could not open the photo picker: $error', error: true);
    return null;
  }
}

/// Event image with a branded placeholder when the event has no picture.
class EventImage extends StatelessWidget {
  const EventImage(this.url, {super.key, this.fit = BoxFit.cover, this.iconSize = 36});

  final String url;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
      child: Center(child: Icon(Icons.celebration_outlined, color: Colors.white70, size: iconSize)),
    );
    if (url.isEmpty) return placeholder;
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(color: AppTheme.subtle(context)),
    );
  }
}

/// Profile picture; shows the first letter of the name when there is no photo.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, required this.url, this.radius = 24});

  final String name;
  final String url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final letter = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.9),
      ),
    );
    if (url.isEmpty) return letter;
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => letter),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.icon, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: enabled ? AppTheme.primaryGradient : null,
        color: enabled ? null : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: enabled ? onPressed : null,
        child: loading
            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppTheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.outline)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Lets the user point the app at the backend (e.g. http://192.168.1.9:3000 on a phone).
Future<void> showServerSettingsDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const _ServerSettingsDialog());
}

class _ServerSettingsDialog extends StatefulWidget {
  const _ServerSettingsDialog();

  @override
  State<_ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<_ServerSettingsDialog> {
  late final TextEditingController _controller = TextEditingController(text: ApiService.baseUrl);
  String? _status;
  bool _ok = false;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    final error = await ApiService.testConnection(_controller.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _ok = error == null;
      _status = error ?? 'Connected successfully.';
    });
  }

  Future<void> _save() async {
    await ApiService.setBaseUrl(_controller.text);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Server address'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter the address of the computer running the EventBook backend. On a phone, use the computer\'s Wi-Fi IP, e.g. http://192.168.1.9:3000',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'API URL', border: OutlineInputBorder()),
          ),
          if (_status != null) ...[
            const SizedBox(height: 10),
            Text(_status!, style: TextStyle(color: _ok ? Colors.green : Colors.redAccent, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _controller.text = ApiService.defaultBaseUrl),
          child: const Text('Default'),
        ),
        TextButton(onPressed: _busy ? null : _test, child: Text(_busy ? 'Testing…' : 'Test')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
