import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/ui_dependencies.dart';
import '../../../core/formatting/formatting.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/layout/clarity_native_layout.dart';
import '../../../core/models/models.dart';
import '../../../widgets/clarity_diamond_loader.dart';
import '../../../widgets/clarity_path_loader.dart';
import '../../transactions/data/csv_import_service.dart';
import '../../shell/presentation/import_job_progress_banner.dart';
import 'csv_plaid_duplicate_warning.dart';
import 'accounts_plaid_status_helpers.dart';
import 'widgets/source_label_chip.dart';

part 'account_selection_dialogs.dart';

/// Shown after the user picks a CSV; they must pick or create a manual account
/// before the fallback import runs.
class AccountSelectionScreen extends StatefulWidget {
  const AccountSelectionScreen({
    super.key,
    required this.controller,
    required this.importJobStatusController,
    required this.homeBuilder,
    required this.pendingCsvText,
  });

  final AccountUiController controller;
  final ImportJobStatusController importJobStatusController;
  final WidgetBuilder homeBuilder;
  final String pendingCsvText;

  @override
  State<AccountSelectionScreen> createState() => _AccountSelectionScreenState();
}

class _AccountSelectionScreenState extends State<AccountSelectionScreen> {
  late final _AccountSelectionDataNotifier _dataNotifier;
  String? _importingAccountId;

  @override
  void initState() {
    super.initState();
    _dataNotifier = _AccountSelectionDataNotifier();
    widget.controller.addListener(_handleControllerChanged);
    _loadData();
  }

  @override
  void didUpdateWidget(covariant AccountSelectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _loadData();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _dataNotifier.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    _loadData();
  }

  Future<void> _loadData() async {
    _dataNotifier.setLoading();
    try {
      final accounts = await widget.controller.accounts;
      if (!mounted) return;
      _dataNotifier.setData(accounts);
    } on Object catch (error) {
      if (!mounted) return;
      _dataNotifier.setError(error);
    }
  }

  Future<void> _showAddAccountDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddAccountDialog(
        onCreate: (name, type, balance) async {
          final account = Account(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: name,
            type: type,
            currentBalance: balance,
          );
          final created = await widget.controller.addAccount(account);
          if (!dialogContext.mounted) return;
          if (created == null) {
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(
                content: Text(
                  dialogContext.l10n.accountsNavigationCouldNotSaveAccount,
                ),
              ),
            );
            return;
          }
          Navigator.of(dialogContext).pop();
        },
      ),
    );
  }

  Future<void> _importForAccount(BuildContext context, Account account) async {
    if (_importingAccountId != null) return;
    if (account.isPlaidConnected) {
      final proceed = await confirmCsvImportForPlaidAccount(context, account);
      if (proceed != true) return;
      if (!context.mounted) return;
    }
    setState(() => _importingAccountId = account.id);
    try {
      widget.controller.showImportPreparationProgress(
        context.l10n.accountSelectionPreviewingCsv,
      );
      final preview = await widget.controller.previewCsvImport(
        widget.pendingCsvText,
        accountId: account.id,
      );
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) =>
            _CsvImportPreviewDialog(account: account, preview: preview),
      );
      if (confirmed != true) {
        widget.controller.clearImportJobStatus();
        return;
      }
      await widget.controller.loadFromCsv(
        widget.pendingCsvText,
        accountId: account.id,
      );
      if (!context.mounted) return;
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(builder: widget.homeBuilder),
      );
    } on FormatException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.accountSelectionCouldNotImport)),
      );
    } finally {
      if (mounted) {
        setState(() => _importingAccountId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final native = ClarityNativeLayout.active(context);
    final cardRadius = native
        ? ClarityNativeLayout.cardRadius(context)
        : 16.0;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.accountSelectionAppBarTitle),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ImportJobStatusHost(
        controller: widget.importJobStatusController,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
              ],
            ),
          ),
          child: ListenableBuilder(
            listenable: _dataNotifier,
            builder: (context, _) {
              final accounts = _dataNotifier.data;
              if (accounts == null) {
                if (_dataNotifier.error != null) {
                  return Center(
                    child: Text(context.l10n.accountsScreenLoadError),
                  );
                }
                return Center(
                  child: ClarityDiamondLoader(
                    size: 56,
                    label: context.l10n.accountsScreenLoadingLabel,
                  ),
                );
              }
              if (accounts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: native
                        ? EdgeInsets.symmetric(
                            horizontal: ClarityNativeLayout.pageGutter(context),
                          )
                        : const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.l10n.accountSelectionManualAccountForCsv,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => _showAddAccountDialog(context),
                          icon: const Icon(Icons.add_rounded, size: 22),
                          label: Text(context.l10n.accountSelectionAddManualButton),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: native
                        ? ClarityNativeLayout.pagePadding(
                            context,
                            top: 8,
                            bottom: 4,
                          )
                        : const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Text(
                      context.l10n.accountSelectionInstructions,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: native
                          ? ClarityNativeLayout.pagePadding(
                              context,
                              top: 8,
                              bottom: 24,
                            )
                          : const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: accounts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final a = accounts[i];
                        final importingThisAccount =
                            _importingAccountId == a.id;
                        return Material(
                          color: theme.colorScheme.surfaceContainerLowest,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(cardRadius),
                            side: BorderSide(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: native
                                ? ClarityNativeLayout.listRowPadding(context)
                                : const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: theme
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.65),
                              child: Icon(
                                switch (a.type) {
                                  AccountType.checking =>
                                    Icons.account_balance_wallet_outlined,
                                  AccountType.savings => Icons.savings_outlined,
                                  AccountType.creditCard =>
                                    Icons.credit_card_rounded,
                                },
                                size: 22,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                            ),
                            title: Text(
                              a.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SourceLabelChip(label: a.sourceLabel),
                                Text(a.type.displayLabel),
                                if (a.isPlaidConnected)
                                  Text(
                                    context.l10n.accountSelectionCsvMayDuplicate,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.52),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: importingThisAccount
                                ? const ClarityInlineLoader(
                                    size: 22,
                                    strokeWidth: 2,
                                  )
                                : Icon(
                                    Icons.chevron_right_rounded,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.35),
                                  ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(cardRadius),
                            ),
                            onTap: _importingAccountId == null
                                ? () => _importForAccount(context, a)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: native
                        ? ClarityNativeLayout.pagePadding(context, bottom: 24)
                        : const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddAccountDialog(context),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(context.l10n.accountSelectionAddManualButton),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
