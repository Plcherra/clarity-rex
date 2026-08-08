import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account detail screen embeds shared FinancialDashboardView shell', () {
    final source = File(
      'lib/features/accounts/presentation/account_detail_screen.dart',
    ).readAsStringSync();

    expect(source, contains('FinancialDashboardView('));
    expect(source, contains('AccountDashboardScope(widget.accountId)'));
    expect(
      source,
      contains(
        'insights strip, collapsible charts',
      ),
    );
  });
}
