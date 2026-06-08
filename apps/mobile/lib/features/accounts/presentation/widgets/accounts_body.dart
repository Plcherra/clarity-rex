import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../data/plaid_account_service.dart';
import 'account_notice_card.dart';
import 'accounts_data_notifier.dart';
import 'accounts_header.dart';
import 'empty_accounts_state.dart';
import 'manual_account_tile.dart';
import 'plaid_account_tile.dart';

class AccountsBody extends StatelessWidget {
  const AccountsBody({
    super.key,
    required this.dataNotifier,
    required this.accountNotice,
    required this.onDismissNotice,
    required this.onConnectBank,
    required this.onImportCsvInstead,
    required this.onAddManualAccount,
    required this.onRefreshAccounts,
    required this.onOpenAccountDetail,
    required this.onResyncPlaidItem,
    required this.statusFor,
    required this.lastSyncedAtFor,
  });

  final AccountsDataNotifier dataNotifier;
  final String? accountNotice;
  final VoidCallback onDismissNotice;
  final VoidCallback onConnectBank;
  final VoidCallback onImportCsvInstead;
  final VoidCallback onAddManualAccount;
  final Future<void> Function() onRefreshAccounts;
  final void Function(Account account) onOpenAccountDetail;
  final void Function(String itemId) onResyncPlaidItem;
  final PlaidAccountConnectionStatus Function(Account account) statusFor;
  final DateTime? Function(Account account) lastSyncedAtFor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: dataNotifier,
      builder: (context, _) {
        final accounts = dataNotifier.data;
        if (accounts == null) {
          if (dataNotifier.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load accounts.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }

        if (accounts.isEmpty) {
          return EmptyAccountsState(
            onConnectBank: onConnectBank,
            onImportCsvInstead: onImportCsvInstead,
            onAddManualAccount: onAddManualAccount,
          );
        }

        return RefreshIndicator(
          onRefresh: onRefreshAccounts,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              if (accountNotice != null) ...[
                AccountNoticeCard(
                  message: accountNotice!,
                  onDismiss: onDismissNotice,
                ),
                const SizedBox(height: 12),
              ],
              AccountsSummaryCard(accounts: accounts),
              const SizedBox(height: 16),
              for (final item in accounts) ...[
                if (item.account.isPlaidConnected)
                  PlaidAccountTile(
                    item: item,
                    status: statusFor(item.account),
                    lastSyncedAt: lastSyncedAtFor(item.account),
                    onResync: () =>
                        onResyncPlaidItem(item.account.plaidItemId!),
                    onTap: () => onOpenAccountDetail(item.account),
                  )
                else
                  ManualAccountTile(
                    item: item,
                    onTap: () => onOpenAccountDetail(item.account),
                  ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}
