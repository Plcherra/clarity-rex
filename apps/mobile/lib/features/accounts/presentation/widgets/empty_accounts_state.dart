import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';
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
          title: context.l10n.accountsEmptyTitle,
          body: context.l10n.accountsEmptyBody,
          compact: true,
          onConnectBank: onConnectBank,
          onImportCsvInstead: onImportCsvInstead,
          onAddManualAccount: onAddManualAccount,
        ),
      ),
    );
  }
}
