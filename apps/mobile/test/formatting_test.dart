import 'package:clarity/core/formatting/formatting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  test('formatMoney uses en_US currency formatting', () {
    setDefaultFormattingLocale(const Locale('en'));
    expect(formatMoney(1234.5), r'$1,234.50');
  });

  test('formatMoney uses es locale grouping', () {
    setDefaultFormattingLocale(const Locale('es'));
    final formatted = formatMoney(1234.5, locale: const Locale('es'));
    expect(formatted, contains('1'));
    expect(formatted, contains('234'));
    expect(formatted.contains(r'$') || formatted.contains('USD'), isTrue);
  });

  test('formatYearMonthLabel localizes month names', () {
    setDefaultFormattingLocale(const Locale('en'));
    expect(formatYearMonthLabel('2026-04'), 'April 2026');

    final spanish = formatYearMonthLabel(
      '2026-04',
      locale: const Locale('es'),
    );
    expect(spanish.toLowerCase(), contains('2026'));
    expect(spanish.toLowerCase(), isNot(contains('april')));
  });

  test('formatShortDate localizes month abbreviations', () {
    setDefaultFormattingLocale(const Locale('en'));
    expect(formatShortDate(DateTime(2026, 4, 8)), 'Apr 8');

    final spanish = formatShortDate(
      DateTime(2026, 4, 8),
      locale: const Locale('es'),
    );
    expect(spanish.toLowerCase(), isNot(contains('apr')));
  });
}
