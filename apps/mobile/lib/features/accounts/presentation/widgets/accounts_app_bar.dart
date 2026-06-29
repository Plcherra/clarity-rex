import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';
import '../../../../widgets/clarity_path_loader.dart';

class AccountsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AccountsAppBar({
    super.key,
    required this.refreshingAccounts,
    required this.onRefreshAccounts,
    required this.onAddAccount,
  });

  final bool refreshingAccounts;
  final VoidCallback onRefreshAccounts;
  final VoidCallback onAddAccount;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return AppBar(
      title: Text(l10n.navAccounts),
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(
          tooltip: l10n.accountsScreenRefreshTooltip,
          onPressed: refreshingAccounts ? null : onRefreshAccounts,
          icon: refreshingAccounts
              ? const ClarityInlineLoader(size: 20, strokeWidth: 2)
              : const Icon(Icons.sync_rounded),
        ),
        IconButton(
          tooltip: l10n.accountsScreenAddAccountTooltip,
          onPressed: onAddAccount,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}
