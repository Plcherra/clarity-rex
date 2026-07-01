import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'plaid_connection_models.dart';
import 'plaid_link_js.dart';
import 'web_plaid_link_parsing.dart';

/// Opens Plaid Link in the browser using the official Link JS SDK.
final class WebPlaidLinkLauncher implements PlaidLinkLauncher {
  const WebPlaidLinkLauncher();

  @override
  Future<PlaidLinkLaunchResult> open(PlaidLinkToken token) async {
    if (token.value.trim().isEmpty) {
      throw const PlaidLinkServiceException('Could not start bank connection.');
    }

    PlaidHandler? handler;
    try {
      final completer = Completer<PlaidLinkLaunchResult>();
      final receivedRedirectUri = readPlaidOAuthRedirectUri();

      _debugPlaidLink(
        'web open token_present=true oauth_return=${receivedRedirectUri != null}',
      );

      handler = Plaid.create(
        WebConfiguration(
          token: token.value.trim(),
          receivedRedirectUri: receivedRedirectUri,
          onLoad: () {}.toJS,
          onEvent: ((JSString event, JSAny metadata) {
            _debugPlaidLink('web event=${event.toDart}');
          }).toJS,
          onSuccess: ((JSAny publicToken, JSAny metadata) {
            final result = launchResultFromWebSuccess(
              jsString(publicToken.dartify()),
              jsObjectToMap(metadata),
            );
            if (result == null) {
              if (!completer.isCompleted) {
                completer.completeError(
                  const PlaidLinkServiceException(
                    'Received an invalid bank connection result.',
                  ),
                );
              }
            } else if (!completer.isCompleted) {
              completer.complete(result);
            }
            handler?.destroy();
            clearPlaidOAuthRedirectFromHistory();
          }).toJS,
          onExit: ((JSAny? error, JSAny metadata) {
            if (!completer.isCompleted) {
              completer.complete(
                launchResultFromWebExit(
                  error == null ? null : jsObjectToMap(error),
                  jsObjectToMap(metadata),
                ),
              );
            }
            handler?.destroy();
            clearPlaidOAuthRedirectFromHistory();
          }).toJS,
        ),
      );

      handler.open();

      return completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          handler?.destroy();
          return const PlaidLinkLaunchExit(status: 'timeout');
        },
      );
    } on PlaidLinkServiceException {
      rethrow;
    } on Object catch (error) {
      handler?.destroy();
      throw PlaidLinkServiceException(
        'Could not open bank connection.',
        cause: error,
      );
    }
  }

  static void _debugPlaidLink(String message) {
    debugPrint('PlaidLink: $message');
  }
}
