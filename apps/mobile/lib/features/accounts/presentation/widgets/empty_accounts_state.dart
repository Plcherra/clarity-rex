import 'package:flutter/material.dart';

import 'connect_bank_setup_card.dart';

class EmptyAccountsState extends StatelessWidget {
  const EmptyAccountsState({
    super.key,
    required this.onConnectBank,
    required this.onImportCsvInstead,
    required this.onAddManualAccount,
  });

  final VoidCallback onConnectBank;
  final VoidCallback onImportCsvInstead;
  final VoidCallback onAddManualAccount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConnectBankSetupCard(
          title: 'Connect your accounts',
          body:
              'Start with connected bank accounts so Clarity can keep balances and transactions current.',
          compact: true,
          onConnectBank: onConnectBank,
          onImportCsvInstead: onImportCsvInstead,
          onAddManualAccount: onAddManualAccount,
        ),
      ),
    );
  }
}
