import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/platform/app_capabilities.dart';
import '../../../core/rex/rex_api_client.dart';
export 'plaid_connection_models.dart';
import 'plaid_connection_models.dart';
import 'web_plaid_link_launcher_stub.dart'
    if (dart.library.html) 'web_plaid_link_launcher_web.dart';

final class PlaidLinkService {
  PlaidLinkService({
    PlaidLinkTokenApi? tokenApi,
    PlaidPublicTokenExchangeApi? exchangeApi,
    PlaidLinkLauncher? launcher,
  }) : _tokenApi = tokenApi ?? RexPlaidApi(),
       _exchangeApi = exchangeApi ?? RexPlaidApi(),
       _launcher = launcher ?? _defaultPlaidLinkLauncher();

  final PlaidLinkTokenApi _tokenApi;
  final PlaidPublicTokenExchangeApi _exchangeApi;
  final PlaidLinkLauncher _launcher;

  Future<PlaidConnectionResult> connectBank() async {
    final token = await _tokenApi.createLinkToken();
    final result = await _launcher.open(token);
    return switch (result) {
      PlaidLinkLaunchSuccess() => _exchangePublicToken(result),
      PlaidLinkLaunchExit(
        :final status,
        :final errorCode,
        :final errorType,
        :final requestId,
      ) =>
        PlaidConnectionExit(
          status: status,
          errorCode: errorCode,
          errorType: errorType,
          requestId: requestId,
        ),
    };
  }

  Future<PlaidConnectionSuccess> _exchangePublicToken(
    PlaidLinkLaunchSuccess result,
  ) async {
    if (result.publicToken.trim().isEmpty) {
      throw const PlaidLinkServiceException(
        'Bank connected, but Plaid did not return the token Clarity needs.',
      );
    }
    debugPrint(
      'PlaidLink: exchange started institution=${result.institutionName ?? 'unknown'} '
      'accounts=${result.accountCount}',
    );
    final success = await _exchangeApi.exchangePublicToken(result);
    debugPrint(
      'PlaidLink: exchange completed item=${success.itemId} '
      'accounts_synced=${success.accountsSynced}',
    );
    return success;
  }
}

final class RexPlaidApi
    implements PlaidLinkTokenApi, PlaidPublicTokenExchangeApi {
  RexPlaidApi({RexApiClient? apiClient})
    : _apiClient = apiClient ?? RexApiClient();

  final RexApiClient _apiClient;

  @override
  Future<PlaidLinkToken> createLinkToken() async {
    final response = await _apiClient.postJson(
      '/plaid/link-token',
      <String, dynamic>{'platform': _plaidLinkPlatform()},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PlaidLinkServiceException(_safeErrorMessage(response.body));
    }

    final decoded = _safeJsonMap(response.body);
    final linkToken = decoded['link_token'];
    if (linkToken is! String || linkToken.trim().isEmpty) {
      throw const PlaidLinkServiceException('Could not start bank connection.');
    }

    final expiration = decoded['expiration'];
    return PlaidLinkToken(
      value: linkToken.trim(),
      expiration: expiration is String ? expiration : null,
    );
  }

  @override
  Future<PlaidConnectionSuccess> exchangePublicToken(
    PlaidLinkLaunchSuccess success,
  ) async {
    final response = await _apiClient.postJson('/plaid/exchange-token', {
      'public_token': success.publicToken,
      if (success.institutionId != null)
        'institution_id': success.institutionId,
      if (success.institutionName != null)
        'institution_name': success.institutionName,
    });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PlaidLinkServiceException(_safeErrorMessage(response.body));
    }

    final decoded = _safeJsonMap(response.body);
    final itemId = decoded['plaid_item_record_id'];
    final status = decoded['status'];
    if (itemId is! String || itemId.trim().isEmpty) {
      throw const PlaidLinkServiceException('Could not save bank connection.');
    }
    return PlaidConnectionSuccess(
      itemId: itemId.trim(),
      status: status is String && status.trim().isNotEmpty
          ? status.trim()
          : 'active',
      institutionName: _stringOrNull(decoded['institution_name']),
      accounts: _accountSummaries(decoded['accounts']),
      accountsSynced: _intOrZero(decoded['accounts_synced']),
      transactionsAdded: _intOrZero(decoded['transactions_added']),
      transactionsModified: _intOrZero(decoded['transactions_modified']),
      transactionsRemoved: _intOrZero(decoded['transactions_removed']),
    );
  }

  Map<String, dynamic> _safeJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on Object {
      // Fall through to a safe generic message.
    }
    throw const PlaidLinkServiceException('Could not parse bank connection.');
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
    return 'Could not connect bank.';
  }

  String? _stringOrNull(Object? value) {
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  int _intOrZero(Object? value) {
    return value is int ? value : 0;
  }

  List<PlaidConnectedAccountSummary> _accountSummaries(Object? value) {
    if (value is! List) return const [];
    return [
      for (final account in value)
        if (account is Map<String, dynamic>) ?_accountSummary(account),
    ];
  }

  PlaidConnectedAccountSummary? _accountSummary(Map<String, dynamic> json) {
    final linkedAccountId = _stringOrNull(json['linked_account_id']);
    final itemId = _stringOrNull(json['plaid_item_record_id']);
    if (linkedAccountId == null || itemId == null) return null;

    final officialName = _stringOrNull(json['official_name']);
    final name = _stringOrNull(json['name']) ?? officialName ?? 'Plaid account';
    return PlaidConnectedAccountSummary(
      linkedAccountId: linkedAccountId,
      itemId: itemId,
      institutionName: _stringOrNull(json['institution_name']),
      name: name,
      officialName: officialName,
      mask: _stringOrNull(json['mask']),
      accountType: _stringOrNull(json['account_type']),
      accountSubtype: _stringOrNull(json['account_subtype']),
      status: _stringOrNull(json['status']) ?? 'active',
      currentBalance: _doubleOrNull(json['current_balance']),
      availableBalance: _doubleOrNull(json['available_balance']),
      isoCurrencyCode: _stringOrNull(json['iso_currency_code']),
    );
  }

  double? _doubleOrNull(Object? value) {
    if (value is num) return value.toDouble();
    return null;
  }

  String _plaidLinkPlatform() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'unknown',
    };
  }
}

PlaidLinkLauncher _defaultPlaidLinkLauncher() {
  if (AppCapabilities.instance.supportsNativePlaidLink) {
    return const NativePlaidLinkLauncher();
  }
  if (AppCapabilities.instance.supportsWebPlaidLink) {
    return const WebPlaidLinkLauncher();
  }
  return const UnsupportedPlaidLinkLauncher();
}

/// Returns a user-visible exit when Plaid Link is unavailable on this platform.
final class UnsupportedPlaidLinkLauncher implements PlaidLinkLauncher {
  const UnsupportedPlaidLinkLauncher();

  @override
  Future<PlaidLinkLaunchResult> open(PlaidLinkToken token) async {
    return const PlaidLinkLaunchExit(
      status: 'unsupported_platform',
      errorCode: 'unsupported_platform',
      errorType: 'PLATFORM',
    );
  }
}

final class NativePlaidLinkLauncher implements PlaidLinkLauncher {
  const NativePlaidLinkLauncher({
    MethodChannel channel = const MethodChannel('clarity/plaid_link'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<PlaidLinkLaunchResult> open(PlaidLinkToken token) async {
    try {
      _debugPlaidLink(
        'native open token_present=${token.value.trim().isNotEmpty}',
      );
      final event = await _channel
          .invokeMethod<Object?>('open', <String, Object?>{
            'linkToken': token.value,
          })
          .timeout(
            const Duration(minutes: 5),
            onTimeout: () {
              _debugPlaidLink('timeout waiting for native Link callback');
              return <String, Object?>{'type': 'exit', 'linkStatus': 'timeout'};
            },
          );
      final result = launchResultFromNative(event);
      if (result == null) {
        throw const PlaidLinkServiceException(
          'Received an invalid bank connection result.',
        );
      }
      return result;
    } on PlaidLinkServiceException {
      rethrow;
    } on PlatformException catch (error) {
      throw PlaidLinkServiceException(
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Could not open bank connection.',
        cause: error,
      );
    } on MissingPluginException catch (error) {
      throw PlaidLinkServiceException(
        'Bank connection is not available in this app build.',
        cause: error,
      );
    } on Object catch (error) {
      throw PlaidLinkServiceException(
        'Could not open bank connection.',
        cause: error,
      );
    }
  }

  void _debugPlaidLink(String message) {
    debugPrint('PlaidLink: $message');
  }

  @visibleForTesting
  static PlaidLinkLaunchResult? launchResultFromNative(Object? event) {
    if (event is! Map) return null;

    final type = _stringFromNativeMap(event['type']);
    if (type == 'exit') {
      return PlaidLinkLaunchExit(
        status: _stringFromNativeMap(event['linkStatus']),
        errorCode: _stringFromNativeMap(event['errorCode']),
        errorType: _stringFromNativeMap(event['errorType']),
        requestId: _stringFromNativeMap(event['requestId']),
      );
    }

    if (type != 'success') return null;

    final rawPublicToken = event['publicToken'];
    if (rawPublicToken is! String || rawPublicToken.trim().isEmpty) {
      return null;
    }

    return PlaidLinkLaunchSuccess(
      publicToken: rawPublicToken.trim(),
      institutionId: _stringFromNativeMap(event['institutionId']),
      institutionName: _stringFromNativeMap(event['institutionName']),
      accountCount: _intFromNativeMap(event['accountCount']),
    );
  }

  static String? _stringFromNativeMap(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static int _intFromNativeMap(Object? value) {
    return value is int ? value : 0;
  }
}
