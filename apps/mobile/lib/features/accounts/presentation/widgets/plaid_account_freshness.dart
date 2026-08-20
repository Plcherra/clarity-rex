import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/clarity_colors.dart';
import '../../data/plaid_account_service.dart';

String plaidAccountFreshnessLabel(
  AppLocalizations l10n,
  PlaidAccountConnectionStatus status,
  DateTime? lastSyncedAt, {
  DateTime? now,
}) {
  if (status.needsReconnect) {
    if (lastSyncedAt == null) return l10n.plaidAccountLastSyncedUnavailable;
    final value = lastSyncedAt;
    return l10n.plaidAccountLastSyncedDate(
      '${value.month}/${value.day}/${value.year}',
    );
  }
  if (lastSyncedAt == null) return l10n.plaidAccountLastSyncedUnavailable;
  final diff = (now ?? DateTime.now()).difference(lastSyncedAt);
  if (diff.inMinutes < 1) return l10n.plaidAccountLastSyncedJustNow;
  if (diff.inMinutes < 60) {
    return l10n.plaidAccountLastSyncedMinutesAgo(diff.inMinutes);
  }
  if (diff.inHours < 24) {
    return l10n.plaidAccountLastSyncedHoursAgo(diff.inHours);
  }
  return l10n.plaidAccountLastSyncedDate(
    '${lastSyncedAt.month}/${lastSyncedAt.day}/${lastSyncedAt.year}',
  );
}

String? plaidAccountStatusRecoveryMessage(
  AppLocalizations l10n,
  PlaidAccountConnectionStatus status,
) {
  return switch (status) {
    PlaidAccountConnectionStatus.connected => null,
    PlaidAccountConnectionStatus.syncing => l10n.plaidAccountStatusRefreshing,
    PlaidAccountConnectionStatus.degraded =>
      l10n.plaidAccountStatusDegradedMessage,
    PlaidAccountConnectionStatus.loginRequired =>
      l10n.plaidAccountStatusLoginRequiredMessage,
    PlaidAccountConnectionStatus.pendingExpiration =>
      l10n.plaidAccountStatusExpiringSoonMessage,
    PlaidAccountConnectionStatus.disconnected =>
      l10n.plaidAccountStatusDisconnectedMessage,
  };
}

Color plaidAccountStatusRecoveryColor(
  ColorScheme colorScheme,
  PlaidAccountConnectionStatus status,
) {
  return switch (status) {
    PlaidAccountConnectionStatus.connected =>
      colorScheme.onSurface.withValues(alpha: 0.52),
    PlaidAccountConnectionStatus.syncing => colorScheme.secondary,
    PlaidAccountConnectionStatus.degraded => ClarityColors.warning,
    PlaidAccountConnectionStatus.loginRequired => colorScheme.error,
    PlaidAccountConnectionStatus.pendingExpiration => ClarityColors.warning,
    PlaidAccountConnectionStatus.disconnected =>
      colorScheme.onSurface.withValues(alpha: 0.58),
  };
}

String? plaidAccountWebhookFreshnessMessage(
  AppLocalizations l10n,
  PlaidAccountConnectionStatus status,
  DateTime? webhookLastReceivedAt, {
  DateTime? now,
}) {
  if (status == PlaidAccountConnectionStatus.disconnected ||
      status == PlaidAccountConnectionStatus.syncing) {
    return null;
  }
  if (webhookLastReceivedAt == null) {
    return status == PlaidAccountConnectionStatus.connected
        ? null
        : l10n.plaidAccountNoWebhookYet;
  }
  final clock = now ?? DateTime.now();
  final diff = clock.difference(webhookLastReceivedAt);
  if (diff.inHours < 24) {
    return null;
  }
  return l10n.plaidAccountNoRecentWebhook(
    _relativeWebhookLabel(l10n, webhookLastReceivedAt, clock),
  );
}

String _relativeWebhookLabel(
  AppLocalizations l10n,
  DateTime value,
  DateTime now,
) {
  final diff = now.difference(value);
  if (diff.inDays >= 1) {
    return l10n.plaidAccountWebhookDaysAgo(diff.inDays);
  }
  if (diff.inHours >= 1) {
    return l10n.plaidAccountWebhookHoursAgo(diff.inHours);
  }
  if (diff.inMinutes >= 1) {
    return l10n.plaidAccountWebhookMinutesAgo(diff.inMinutes);
  }
  return l10n.plaidAccountWebhookJustNow;
}
