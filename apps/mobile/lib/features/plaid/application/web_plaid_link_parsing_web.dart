import 'package:flutter/foundation.dart';

import 'plaid_connection_models.dart';
import 'plaid_link_js.dart';

/// Parses Plaid Link web callback payloads into Clarity launch models.
@visibleForTesting
PlaidLinkLaunchResult? launchResultFromWebSuccess(
  String publicToken,
  Map<dynamic, dynamic> metadata,
) {
  final normalizedToken = publicToken.trim();
  if (normalizedToken.isEmpty) return null;

  final institution = jsObjectToMap(metadata['institution']);
  final accounts = jsList(metadata['accounts']);

  return PlaidLinkLaunchSuccess(
    publicToken: normalizedToken,
    institutionId: jsNullableString(
      institution['institution_id'] ?? institution['id'],
    ),
    institutionName: jsNullableString(institution['name']),
    accountCount: accounts.length,
  );
}

@visibleForTesting
PlaidLinkLaunchResult launchResultFromWebExit(
  Map<dynamic, dynamic>? error,
  Map<dynamic, dynamic> metadata,
) {
  return PlaidLinkLaunchExit(
    status: jsNullableString(metadata['status']),
    errorCode: jsNullableString(error?['error_code'] ?? error?['errorCode']),
    errorType: jsNullableString(error?['error_type'] ?? error?['errorType']),
    requestId: jsNullableString(metadata['request_id'] ?? metadata['requestId']),
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
  final uri = Uri.tryParse(href);
  if (uri == null) return;
  if (!uri.queryParameters.containsKey('oauth_state_id')) return;

  final cleaned = uri.replace(queryParameters: {});
  historyReplaceState(null, '', cleaned.toString());
}

String? readPlaidOAuthRedirectUri() {
  return readPlaidOAuthRedirectUriFromHref(windowLocationHref);
}

void clearPlaidOAuthRedirectFromHistory() {
  clearPlaidOAuthRedirectFromHistoryForHref(windowLocationHref);
}
