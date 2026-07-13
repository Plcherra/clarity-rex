import 'package:flutter/material.dart';

import '../../../../app/ui_dependencies.dart';
import '../../../../core/layout/clarity_breakpoints.dart';
import '../../../../core/layout/clarity_native_layout.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/models/models.dart';
import '../../../../widgets/clarity_diamond_loader.dart';
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
    required this.onDisconnectPlaidItem,
    required this.statusFor,
    required this.lastSyncedAtFor,
    required this.webhookLastReceivedAtFor,
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
  final void Function(Account account) onDisconnectPlaidItem;
  final PlaidAccountConnectionStatus Function(Account account) statusFor;
  final DateTime? Function(Account account) lastSyncedAtFor;
  final DateTime? Function(Account account) webhookLastReceivedAtFor;

  Widget _accountTile(BuildContext context, AccountOverviewItem item) {
    if (item.account.isPlaidConnected) {
      return PlaidAccountTile(
        item: item,
        status: statusFor(item.account),
        lastSyncedAt: lastSyncedAtFor(item.account),
        webhookLastReceivedAt: webhookLastReceivedAtFor(item.account),
        onResync: () => onResyncPlaidItem(item.account.plaidItemId!),
        onDisconnect: () => onDisconnectPlaidItem(item.account),
        onTap: () => onOpenAccountDetail(item.account),
      );
    }
    return ManualAccountTile(
      item: item,
      onTap: () => onOpenAccountDetail(item.account),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = isClarityDesktopLayout(context);
    return ListenableBuilder(
      listenable: dataNotifier,
      builder: (context, _) {
        final accounts = dataNotifier.data;
        final l10n = context.l10n;
        if (accounts == null) {
          if (dataNotifier.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.accountsScreenLoadError,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Center(
            child: ClarityDiamondLoader(
              size: 56,
              label: l10n.accountsScreenLoadingLabel,
            ),
          );
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
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: ClarityNativeLayout.active(context)
                    ? ClarityNativeLayout.pagePadding(
                        context,
                        top: 12,
                        bottom: 28,
                      )
                    : const EdgeInsets.fromLTRB(20, 12, 20, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (accountNotice != null) ...[
                      AccountNoticeCard(
                        message: accountNotice!,
                        onDismiss: onDismissNotice,
                      ),
                      const SizedBox(height: 12),
                    ],
                    AccountsSummaryCard(accounts: accounts),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
              if (desktop)
                SliverPadding(
                  padding: ClarityNativeLayout.active(context)
                      ? ClarityNativeLayout.pagePadding(context, bottom: 28)
                      : const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 420,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.55,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _accountTile(context, accounts[index]),
                      childCount: accounts.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: ClarityNativeLayout.active(context)
                      ? ClarityNativeLayout.pagePadding(context, bottom: 28)
                      : const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return Column(
                          children: [
                            _accountTile(context, accounts[index]),
                            if (index < accounts.length - 1)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                child: Divider(
                                  height: 1,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: 0.48),
                                ),
                              ),
                          ],
                        );
                      },
                      childCount: accounts.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
