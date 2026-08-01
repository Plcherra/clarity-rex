import 'package:flutter/foundation.dart';

import 'plaid_connection_models.dart';

/// Parses Plaid Link web callback payloads into Clarity launch models.
PlaidLinkLaunchResult? launchResultFromWebSuccess(
  String publicToken,
  Map<dynamic, dynamic> metadata,
) {
  final normalizedToken = publicToken.trim();
  if (normalizedToken.isEmpty) return null;

  final institution = _mapOrEmpty(metadata['institution']);
  final accounts = metadata['accounts'];
  final accountCount = accounts is List ? accounts.length : 0;

  return PlaidLinkLaunchSuccess(
    publicToken: normalizedToken,
    institutionId: _nullableString(
      institution['institution_id'] ?? institution['id'],
    ),
    institutionName: _nullableString(institution['name']),
    accountCount: accountCount,
  );
}

PlaidLinkLaunchResult launchResultFromWebExit(
  Map<dynamic, dynamic>? error,
  Map<dynamic, dynamic> metadata,
) {
  return PlaidLinkLaunchExit(
    status: _nullableString(metadata['status']),
    errorCode: _nullableString(error?['error_code'] ?? error?['errorCode']),
    errorType: _nullableString(error?['error_type'] ?? error?['errorType']),
    requestId: _nullableString(metadata['request_id'] ?? metadata['requestId']),
  );
}

@visibleForTesting
String? readPlaidOAuthRedirectUriFromHref(String href) {
  final uri = Uri.tryParse(href);
  if (uri == null) return null;
  if (!uri.queryParameters.containsKey('oauth_state_id')) return null;
  return href;
}

@visibleForTesting
void clearPlaidOAuthRedirectFromHistoryForHref(String href) {
  // Browser history is unavailable off-web.
}

String? readPlaidOAuthRedirectUri() => null;

void clearPlaidOAuthRedirectFromHistory() {}

Map<dynamic, dynamic> _mapOrEmpty(Object? value) {
  return value is Map ? value : const {};
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}
