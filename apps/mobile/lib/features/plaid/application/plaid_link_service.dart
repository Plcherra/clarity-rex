import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

import '../../../core/rex/rex_api_client.dart';
export 'plaid_connection_models.dart';
import 'plaid_connection_models.dart';

final class PlaidLinkService {
  PlaidLinkService({
    PlaidLinkTokenApi? tokenApi,
    PlaidPublicTokenExchangeApi? exchangeApi,
    PlaidLinkLauncher? launcher,
  }) : _tokenApi = tokenApi ?? RexPlaidApi(),
       _exchangeApi = exchangeApi ?? RexPlaidApi(),
       _launcher = launcher ?? const PlaidFlutterLinkLauncher();

  final PlaidLinkTokenApi _tokenApi;
  final PlaidPublicTokenExchangeApi _exchangeApi;
  final PlaidLinkLauncher _launcher;

  Future<PlaidConnectionResult> connectBank() async {
    final token = await _tokenApi.createLinkToken();
    final result = await _launcher.open(token);
    return switch (result) {
      PlaidLinkLaunchSuccess() => _exchangeApi.exchangePublicToken(result),
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
      const <String, dynamic>{},
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
}

final class PlaidFlutterLinkLauncher implements PlaidLinkLauncher {
  const PlaidFlutterLinkLauncher();

  @override
  Future<PlaidLinkLaunchResult> open(PlaidLinkToken token) async {
    final completer = Completer<PlaidLinkLaunchResult>();
    late final StreamSubscription<LinkSuccess> successSubscription;
    late final StreamSubscription<LinkExit> exitSubscription;
    late final StreamSubscription<LinkEvent> eventSubscription;

    void complete(PlaidLinkLaunchResult result) {
      if (!completer.isCompleted) completer.complete(result);
    }

    successSubscription = PlaidLink.onSuccess.listen((event) {
      final institution = event.metadata.institution;
      _debugPlaidLink(
        'success institution=${institution?.name ?? 'unknown'} '
        'accounts=${event.metadata.accounts.length} '
        'public_token_present=${event.publicToken.trim().isNotEmpty}',
      );
      complete(
        PlaidLinkLaunchSuccess(
          publicToken: event.publicToken,
          institutionId: institution?.id,
          institutionName: institution?.name,
          accountCount: event.metadata.accounts.length,
        ),
      );
    });
    exitSubscription = PlaidLink.onExit.listen((event) {
      _debugPlaidLink(
        'exit status=${event.metadata.status ?? 'unknown'} '
        'error_code=${event.error?.code ?? 'none'} '
        'error_type=${event.error?.type ?? 'none'} '
        'request_id=${event.metadata.requestId ?? 'none'}',
      );
      complete(
        PlaidLinkLaunchExit(
          status: event.metadata.status,
          errorCode: event.error?.code,
          errorType: event.error?.type,
          requestId: event.metadata.requestId,
        ),
      );
    });
    eventSubscription = PlaidLink.onEvent.listen((event) {
      final metadata = event.metadata;
      _debugPlaidLink(
        'event name=${event.name} '
        'view=${metadata.viewName ?? 'unknown'} '
        'exit_status=${metadata.exitStatus ?? 'none'} '
        'error_code=${metadata.errorCode ?? 'none'} '
        'institution=${metadata.institutionName ?? 'none'} '
        'request_id=${metadata.requestId ?? 'none'}',
      );
    });

    try {
      await PlaidLink.create(
        configuration: LinkTokenConfiguration(token: token.value),
      );
      await PlaidLink.open();
      return completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          _debugPlaidLink('timeout waiting for Link success/exit callback');
          return const PlaidLinkLaunchExit(status: 'timeout');
        },
      );
    } on PlaidLinkServiceException {
      rethrow;
    } on Object catch (error) {
      throw PlaidLinkServiceException(
        'Could not open bank connection.',
        cause: error,
      );
    } finally {
      await successSubscription.cancel();
      await exitSubscription.cancel();
      await eventSubscription.cancel();
    }
  }

  void _debugPlaidLink(String message) {
    debugPrint('PlaidLink: $message');
  }
}
