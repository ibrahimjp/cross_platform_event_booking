import 'package:intl/intl.dart';

final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _moneyExact = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _compact = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 1);
final _count = NumberFormat.decimalPattern('en_IN');

String money(num value) => value == value.roundToDouble() ? _money.format(value) : _moneyExact.format(value);
String moneyCompact(num value) => value.abs() < 100000 ? _money.format(value) : _compact.format(value);
String count(num value) => _count.format(value);

String dateShort(DateTime? date) => date == null ? '—' : DateFormat('d MMM yyyy').format(date);
String dateTime(DateTime? date) => date == null ? '—' : DateFormat('d MMM yyyy, h:mm a').format(date);
String dayMonth(DateTime date) => DateFormat('d MMM').format(date);

String timeAgo(DateTime? date) {
  if (date == null) return 'never';
  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return dateShort(date);
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
