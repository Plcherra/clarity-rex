import 'package:clarity/l10n/app_localizations.dart';
import 'package:clarity/rex/chat/application/chat_action_result_formatter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('a move that matched nothing does not report itself as done', () {
    // Merchant-scoped moves can match no rows at all; claiming success there
    // would be a save the user cannot see.
    final message = actionResultMessage(
      l10n,
      'bulk_update_transaction_category',
      const [],
    );

    expect(message, contains('Nothing matched'));
    expect(message.toLowerCase(), isNot(contains('done')));
  });

  test('a single moved row is named in the confirmation', () {
    final message = actionResultMessage(
      l10n,
      'bulk_update_transaction_category',
      const [
        {'id': 'tx-1', 'merchant': 'Wingstop'},
      ],
    );

    expect(message, contains('Wingstop'));
  });

  test('a bulk move reports how many rows changed', () {
    final message = actionResultMessage(
      l10n,
      'bulk_update_transaction_category',
      const [
        {'id': 'tx-1'},
        {'id': 'tx-2'},
        {'id': 'tx-3'},
      ],
    );

    expect(message, contains('3'));
  });
}
