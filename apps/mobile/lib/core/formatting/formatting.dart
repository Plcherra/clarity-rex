import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Locale _defaultFormattingLocale = const Locale('en');

/// Updates the locale used by [formatMoney] / date helpers when no locale is passed.
void setDefaultFormattingLocale(Locale locale) {
  _defaultFormattingLocale = locale;
}

Locale get defaultFormattingLocale => _defaultFormattingLocale;

String _formatLocaleTag(Locale locale) {
  if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
    return '${locale.languageCode}_${locale.countryCode}';
  }
  return locale.languageCode;
}

String formatMoney(double? value, {Locale? locale}) {
  final activeLocale = locale ?? _defaultFormattingLocale;
  if (value == null || value.isNaN) return '—';
  final tag = _formatLocaleTag(activeLocale);
  final formatter = NumberFormat.simpleCurrency(
    locale: tag,
    name: 'USD',
  );
  final formatted = formatter.format(value.abs());
  if (value < 0) {
    return '−$formatted';
  }
  return formatted;
}

/// Calendar day only (`YYYY-MM-DD`) for Postgres `date` columns.
String dateOnlyIso(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Turns a fraction into a rounded percentage, e.g. `0.42` becomes `42%`.
String formatPercent(double fraction) => '${(fraction * 100).round()}%';

/// Turns `YYYY-MM` into a localized month label, e.g. `April 2026`.
String formatYearMonthLabel(String yearMonth, {Locale? locale}) {
  final parts = yearMonth.split('-');
  if (parts.length != 2) return yearMonth;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (y == null || m == null || m < 1 || m > 12) return yearMonth;
  final activeLocale = locale ?? _defaultFormattingLocale;
  final tag = _formatLocaleTag(activeLocale);
  return DateFormat.yMMMM(tag).format(DateTime(y, m));
}

String formatShortDate(DateTime date, {Locale? locale}) {
  final activeLocale = locale ?? _defaultFormattingLocale;
  final tag = _formatLocaleTag(activeLocale);
  return DateFormat.MMMd(tag).format(date);
}

/// Month name only, e.g. `August`.
String formatMonthLabel(DateTime date, {Locale? locale}) {
  final activeLocale = locale ?? _defaultFormattingLocale;
  final tag = _formatLocaleTag(activeLocale);
  return DateFormat.MMMM(tag).format(DateTime(date.year, date.month));
}
