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

/// "Hoy, 14:32" o "lun 16 de marzo, 08:05".
String formatDateTime(DateTime value) =>
    '${formatDay(value)}, ${DateFormat.Hm('es').format(value)}';

String formatElapsedSince(DateTime? value, {DateTime? now}) {
  if (value == null) return 'Sin sincronizar aún';
  final elapsed = (now ?? DateTime.now()).difference(value);
  if (elapsed.isNegative || elapsed.inMinutes == 0) return 'hace un momento';
  if (elapsed.inMinutes < 60) return 'hace ${elapsed.inMinutes} min';
  if (elapsed.inHours < 24) {
    final hours = elapsed.inHours;
    return 'hace $hours ${hours == 1 ? 'hora' : 'horas'}';
  }
  final days = elapsed.inDays;
  return 'hace $days ${days == 1 ? 'día' : 'días'}';
}

String formatNumber(double? value, {int decimals = 1}) =>
    value == null ? '—' : value.toStringAsFixed(decimals).replaceAll('.', ',');

String formatPercent(double probability) => '${(probability * 100).round()} %';
