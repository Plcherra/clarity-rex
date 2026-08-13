import 'package:flutter/material.dart';

import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/layout/web_centered_dialog.dart';
import '../../../../core/platform/app_capabilities.dart';

enum AddAccountOption { connectBank, importCsv, manual }

Future<AddAccountOption?> showAddAccountOptionsDialog(BuildContext context) {
  return showDialog<AddAccountOption>(
    context: context,
    builder: (dialogContext) {
      return wrapWebCenteredDialog(
        dialogContext,
        const AddAccountOptionsDialog(),
        maxWidth: 420,
        maxHeight: 560,
      );
    },
  );
}

class AddAccountOptionsDialog extends StatelessWidget {
  const AddAccountOptionsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final caps = AppCapabilities.instance;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Text(
        l10n.accountsSheetAddAccountTitle,
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.accountsSheetAddAccountSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (caps.supportsAnyPlaidLink)
              _AddAccountOptionTile(
                icon: Icons.account_balance_rounded,
                title: l10n.accountsSheetConnectBankTitle,
                subtitle: l10n.accountsSheetConnectBankSubtitle,
                onTap: () =>
                    Navigator.of(context).pop(AddAccountOption.connectBank),
              )
            else
              _AddAccountOptionTile(
                icon: Icons.account_balance_rounded,
                title: l10n.accountsSheetConnectBankTitle,
                subtitle: l10n.plaidConnectWebUnavailableMessage,
                enabled: false,
              ),
            if (caps.supportsCsvImport)
              _AddAccountOptionTile(
                icon: Icons.upload_file_rounded,
                title: l10n.accountsSheetImportCsvTitle,
                subtitle: l10n.accountsSheetImportCsvSubtitle,
                onTap: () =>
                    Navigator.of(context).pop(AddAccountOption.importCsv),
              )
            else
              _AddAccountOptionTile(
                icon: Icons.upload_file_rounded,
                title: l10n.accountsSheetImportCsvTitle,
                subtitle: l10n.csvImportMobileOnlyMessage,
                enabled: false,
              ),
            _AddAccountOptionTile(
              icon: Icons.add_rounded,
              title: l10n.accountsSheetAddManualTitle,
              subtitle: l10n.accountsSheetAddManualSubtitle,
              onTap: () => Navigator.of(context).pop(AddAccountOption.manual),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}

class _AddAccountOptionTile extends StatelessWidget {
  const _AddAccountOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconColor = enabled
        ? colorScheme.onSurface.withValues(alpha: 0.78)
        : colorScheme.onSurface.withValues(alpha: 0.38);

    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(subtitle),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: enabled ? onTap : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      titleTextStyle: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      subtitleTextStyle: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
