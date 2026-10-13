import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';

// ---------------------------------------------------------------------------
// Feedback helpers
// ---------------------------------------------------------------------------

void toast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Tone.danger : null,
        duration: Duration(seconds: error ? 5 : 3),
      ),
    );
}

/// Runs [action], reporting success or the server's error message. Returns true on success.
Future<bool> runAction(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) toast(context, success);
    return true;
  } on ApiException catch (error) {
    if (context.mounted) toast(context, error.message, error: true);
  } catch (error) {
    if (context.mounted) toast(context, 'Something went wrong: $error', error: true);
  }
  return false;
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Text(message)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: Tone.danger) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String label = '',
  String initial = '',
  String confirmLabel = 'Save',
  String? helper,
  bool obscure = false,
  int minLength = 0,
  int maxLines = 1,
}) {
  final controller = TextEditingController(text: initial);
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 400,
        child: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            obscureText: obscure,
            maxLines: obscure ? 1 : maxLines,
            decoration: InputDecoration(labelText: label, helperText: helper, helperMaxLines: 3),
            validator: (value) =>
                (value ?? '').trim().length < minLength ? 'Enter at least $minLength characters.' : null,
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(context, controller.text.trim());
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.onRefresh, this.maxWidth = 1280});

  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
        8,
        MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
        96,
      ),
      children: [
        for (final child in children)
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
      ],
    );
    return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              // Full-bleed sections (zero side padding) still need an inset title.
              Padding(
                padding: EdgeInsets.symmetric(horizontal: padding.left == 0 ? 16 : 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Lays children out in as many equal columns as fit [minItemWidth].
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.minItemWidth = 220, this.spacing = 12});

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / minItemWidth).floor().clamp(1, children.length.clamp(1, 6));
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = brand,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    if (caption != null)
                      Text(
                        caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small pieces
// ---------------------------------------------------------------------------

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color = Tone.neutral, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

Widget bookingStatusChip(Booking booking) {
  if (booking.isCancelled) {
    return StatusChip(
      booking.refunded ? 'Refunded' : 'Cancelled',
      color: booking.refunded ? Tone.warning : Tone.danger,
    );
  }
  if (booking.issuedByAdmin) return const StatusChip('Comp', color: Tone.info, icon: Icons.card_giftcard);
  return StatusChip(booking.status, color: booking.status == 'Free' ? Tone.info : Tone.success);
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.url = '', this.radius = 18});

  final String name;
  final String url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: url.isEmpty ? null : NetworkImage(url, webHtmlElementStrategy: WebHtmlElementStrategy.fallback),
      onForegroundImageError: url.isEmpty ? null : (_, _) {},
      child: Text(
        initials(name),
        style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer),
      ),
    );
  }
}

class EventThumb extends StatelessWidget {
  const EventThumb({super.key, required this.url, this.size = 48, this.radius = 10});

  final String url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      color: scheme.primaryContainer,
      child: Icon(Icons.event, color: scheme.onPrimaryContainer, size: size * 0.45),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? placeholder
            : Image.network(
                url,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                fit: BoxFit.cover,
                frameBuilder: (_, child, frame, loadedSync) => loadedSync || frame != null ? child : placeholder,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()),
  );
}

class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.icon, required this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            if (onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel ?? 'Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) =>
      MessageView(icon: Icons.cloud_off_outlined, message: message, actionLabel: 'Retry', onAction: onRetry);
}

class Pager extends StatelessWidget {
  const Pager({super.key, required this.page, required this.pages, required this.total, required this.onPage});

  final int page;
  final int pages;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$total result${total == 1 ? '' : 's'} · page $page of $pages',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Previous page',
            onPressed: page > 1 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: page < pages ? () => onPage(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class SearchField extends StatefulWidget {
  const SearchField({super.key, required this.hint, required this.onSubmitted, this.initial = ''});

  final String hint;
  final String initial;
  final ValueChanged<String> onSubmitted;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (value) => widget.onSubmitted(value.trim()),
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _controller.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _controller.clear();
                    widget.onSubmitted('');
                  },
                ),
        ),
      ),
    );
  }
}

/// A row of single-select filter chips.
class FilterBar<T> extends StatelessWidget {
  const FilterBar({super.key, required this.options, required this.value, required this.onChanged});

  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in options.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: entry.key == value,
                onSelected: (_) => onChanged(entry.key),
              ),
            ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '—' : value,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
