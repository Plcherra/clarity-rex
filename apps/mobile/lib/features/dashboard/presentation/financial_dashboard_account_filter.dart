part of 'financial_dashboard_view.dart';

class _AccountMultiFilterChip extends StatelessWidget {
  const _AccountMultiFilterChip({
    required this.accounts,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<Account> accounts;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  String _label(AppLocalizations l10n) {
    if (selectedIds.isEmpty) {
      return l10n.dashboardTransactionsFilterAllAccounts;
    }
    if (selectedIds.length == 1) {
      final id = selectedIds.first;
      for (final account in accounts) {
        if (account.id == id) return account.displayName;
      }
      return l10n.dashboardTransactionsAccountsSelectedCount(1);
    }
    return l10n.dashboardTransactionsAccountsSelectedCount(selectedIds.length);
  }

  Future<void> _openSheet(BuildContext context) async {
    final l10n = context.l10n;
    var draft = Set<String>.from(selectedIds);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final cs = Theme.of(ctx).colorScheme;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.dashboardTransactionsSelectAccountsTitle,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: draft.isEmpty,
                      title: Text(l10n.dashboardTransactionsFilterAllAccounts),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (_) {
                        setModalState(() => draft = {});
                      },
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final account in accounts)
                            CheckboxListTile(
                              value: draft.contains(account.id),
                              title: Text(account.displayName),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (checked) {
                                setModalState(() {
                                  draft = Set<String>.from(draft);
                                  if (checked == true) {
                                    draft.add(account.id);
                                  } else {
                                    draft.remove(account.id);
                                  }
                                  if (draft.length == accounts.length) {
                                    draft = {};
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(draft),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                      ),
                      child: Text(l10n.dashboardTransactionsAccountsDone),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final active = selectedIds.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _openSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: active ? _dashboardSelected(context) : cs.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _dashboardOutline(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_outlined,
                size: 17,
                color: cs.onSurface.withValues(alpha: 0.72),
              ),
              const SizedBox(width: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  _label(context.l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
