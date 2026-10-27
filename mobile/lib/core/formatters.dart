import 'package:intl/intl.dart';

import '../domain/entities.dart';

String formatDay(DateTime date) {
  final today = dateOnly(DateTime.now());
  final day = dateOnly(date);
  if (day == today) return 'Hoy';
  if (day == today.subtract(const Duration(days: 1))) return 'Ayer';
  return DateFormat("EEE d 'de' MMMM", 'es').format(day);
}

String formatShortDay(DateTime date) => DateFormat('d MMM', 'es').format(date);

String formatNumber(double? value, {int decimals = 1}) =>
    value == null ? '—' : value.toStringAsFixed(decimals).replaceAll('.', ',');

String formatPercent(double probability) => '${(probability * 100).round()} %';
