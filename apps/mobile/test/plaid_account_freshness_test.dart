import 'package:clarity/features/accounts/data/plaid_account_service.dart';
import 'package:clarity/features/accounts/presentation/widgets/plaid_account_freshness.dart';
import 'package:clarity/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('login required never looks like a just-now sync', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final label = plaidAccountFreshnessLabel(
      l10n,
      PlaidAccountConnectionStatus.loginRequired,
      DateTime(2026, 8, 20, 6, 10),
      now: DateTime(2026, 8, 20, 6, 10, 20),
    );
    expect(label, isNot(l10n.plaidAccountLastSyncedJustNow));
    expect(label, contains('8/20/2026'));
    expect(
      PlaidAccountConnectionStatus.loginRequired.needsReconnect,
      isTrue,
    );
    expect(
      PlaidAccountConnectionStatus.connected.allowsResync,
      isTrue,
    );
    expect(
      PlaidAccountConnectionStatus.loginRequired.allowsResync,
      isFalse,
    );
  });
}
