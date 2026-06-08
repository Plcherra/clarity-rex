import 'package:flutter/material.dart';

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
    return AppBar(
      title: const Text('Accounts'),
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      actions: [
        IconButton(
          tooltip: 'Refresh accounts',
          onPressed: refreshingAccounts ? null : onRefreshAccounts,
          icon: refreshingAccounts
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded),
        ),
        IconButton(
          tooltip: 'Add account',
          onPressed: onAddAccount,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}
