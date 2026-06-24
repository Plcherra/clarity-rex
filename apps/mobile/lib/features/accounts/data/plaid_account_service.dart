import 'dart:convert';

import '../../../core/rex/rex_api_client.dart';
import '../../plaid/application/plaid_connection_models.dart';

enum PlaidAccountConnectionStatus {
  connected,
  syncing,
  degraded,
  loginRequired,
  pendingExpiration,
  disconnected,
}

extension PlaidAccountConnectionStatusLabel on PlaidAccountConnectionStatus {
  String get label => switch (this) {
    PlaidAccountConnectionStatus.connected => 'Connected',
    PlaidAccountConnectionStatus.syncing => 'Syncing',
    PlaidAccountConnectionStatus.degraded => 'Degraded',
    PlaidAccountConnectionStatus.loginRequired => 'Needs login',
    PlaidAccountConnectionStatus.pendingExpiration => 'Expiring soon',
    PlaidAccountConnectionStatus.disconnected => 'Disconnected',
  };
}

PlaidAccountConnectionStatus plaidConnectionStatusFromBackend(Object? value) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return switch (normalized) {
    'active' || 'connected' => PlaidAccountConnectionStatus.connected,
    'syncing' => PlaidAccountConnectionStatus.syncing,
    'disconnected' || 'removed' => PlaidAccountConnectionStatus.disconnected,
    'login_required' => PlaidAccountConnectionStatus.loginRequired,
    'pending_expiration' => PlaidAccountConnectionStatus.pendingExpiration,
    'degraded' || 'error' => PlaidAccountConnectionStatus.degraded,
    _ => PlaidAccountConnectionStatus.degraded,
  };
}

final class PlaidAccountServiceException implements Exception {
  const PlaidAccountServiceException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

final class PlaidItemStatus {
  const PlaidItemStatus({
    required this.itemId,
    required this.status,
    this.institutionName,
    this.lastSyncedAt,
    this.webhookLastReceivedAt,
  });

  final String itemId;
  final PlaidAccountConnectionStatus status;
  final String? institutionName;
  final DateTime? lastSyncedAt;
  final DateTime? webhookLastReceivedAt;
}

final class PlaidDisconnectSummary {
  const PlaidDisconnectSummary({
    required this.itemId,
    required this.status,
    this.institutionName,
  });

  final String itemId;
  final PlaidAccountConnectionStatus status;
  final String? institutionName;
}

final class PlaidAccountService {
  PlaidAccountService({RexApiClient? apiClient})
    : _apiClient = apiClient ?? RexApiClient();

  final RexApiClient _apiClient;

  Future<PlaidItemStatus> fetchItemStatus(String itemId) async {
    final normalizedItemId = itemId.trim();
    if (normalizedItemId.isEmpty) {
      throw const PlaidAccountServiceException('No connected bank to check.');
    }
    final response = await _apiClient.get(
      '/plaid/item-status/$normalizedItemId',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PlaidAccountServiceException(_safeErrorMessage(response.body));
    }

    final decoded = _safeJsonMap(response.body);
    final responseItemId = decoded['plaid_item_record_id'];
    return PlaidItemStatus(
      itemId: responseItemId is String && responseItemId.trim().isNotEmpty
          ? responseItemId.trim()
          : normalizedItemId,
      status: plaidConnectionStatusFromBackend(decoded['status']),
      institutionName: _stringOrNull(decoded['institution_name']),
      lastSyncedAt: _dateTimeOrNull(decoded['last_synced_at']),
      webhookLastReceivedAt: _dateTimeOrNull(
        decoded['webhook_last_received_at'],
      ),
    );
  }

  Future<PlaidSyncSummary> syncItem(String itemId) async {
    final normalizedItemId = itemId.trim();
    if (normalizedItemId.isEmpty) {
      throw const PlaidAccountServiceException('No connected bank to refresh.');
    }
    final response = await _apiClient.post(
      '/plaid/sync-item/$normalizedItemId',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PlaidAccountServiceException(_safeErrorMessage(response.body));
    }

    final decoded = _safeJsonMap(response.body);
    final responseItemId = decoded['plaid_item_record_id'];
    return PlaidSyncSummary(
      itemId: responseItemId is String && responseItemId.trim().isNotEmpty
          ? responseItemId.trim()
          : normalizedItemId,
      accountsSynced: _intOrZero(decoded['accounts_synced']),
      transactionsAdded: _intOrZero(decoded['transactions_added']),
      transactionsModified: _intOrZero(decoded['transactions_modified']),
      transactionsRemoved: _intOrZero(decoded['transactions_removed']),
    );
  }

  Future<PlaidDisconnectSummary> disconnectItem(String itemId) async {
    final normalizedItemId = itemId.trim();
    if (normalizedItemId.isEmpty) {
      throw const PlaidAccountServiceException(
        'No connected bank to disconnect.',
      );
    }
    final response = await _apiClient.post(
      '/plaid/disconnect-item/$normalizedItemId',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PlaidAccountServiceException(_safeErrorMessage(response.body));
    }

    final decoded = _safeJsonMap(response.body);
    final responseItemId = decoded['plaid_item_record_id'];
    return PlaidDisconnectSummary(
      itemId: responseItemId is String && responseItemId.trim().isNotEmpty
          ? responseItemId.trim()
          : normalizedItemId,
      status: plaidConnectionStatusFromBackend(decoded['status']),
      institutionName: _stringOrNull(decoded['institution_name']),
    );
  }

  Map<String, dynamic> _safeJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on Object {
      // Fall through to a safe generic message.
    }
    throw const PlaidAccountServiceException('Could not parse bank status.');
  }

  String _safeErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }
      }
    } on Object {
      // Fall through to a safe generic message.
    }
    return 'Could not refresh connected accounts.';
  }

  String? _stringOrNull(Object? value) {
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  DateTime? _dateTimeOrNull(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim())?.toLocal();
  }

  int _intOrZero(Object? value) {
    return value is int ? value : 0;
  }
}
