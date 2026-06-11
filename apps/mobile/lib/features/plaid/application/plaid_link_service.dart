import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

  String _plaidLinkPlatform() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'unknown',
    };
  }
}

final class PlaidFlutterLinkLauncher implements PlaidLinkLauncher {
  const PlaidFlutterLinkLauncher();

  static final Uri _plaidOauthBaseUri = Uri.parse(
    'https://api.goclarity.app/plaid/oauth',
  );
  static const EventChannel _nativeOauthLinks = EventChannel(
    'clarity/plaid_oauth_links',
  );

  @override
  Future<PlaidLinkLaunchResult> open(PlaidLinkToken token) async {
    final completer = Completer<PlaidLinkLaunchResult>();
    final appLinks = AppLinks();
    final handoff = _PlaidLinkHandoffState();
    final resumedOauthRedirects = <String>{};
    late final StreamSubscription<LinkSuccess> successSubscription;
    late final StreamSubscription<LinkExit> exitSubscription;
    late final StreamSubscription<LinkEvent> eventSubscription;
    late final StreamSubscription<Uri> oauthRedirectSubscription;
    late final StreamSubscription<Uri> nativeOauthRedirectSubscription;
    late final AppLifecycleListener lifecycleListener;
    Timer? pendingExitTimer;

    void complete(PlaidLinkLaunchResult result) {
      if (!completer.isCompleted) completer.complete(result);
    }

    Future<void> resumePlaidOauth(Uri uri) async {
      if (!_isPlaidOauthRedirect(uri)) return;
      if (!resumedOauthRedirects.add(uri.toString())) {
        _debugPlaidLink(
          'oauth redirect duplicate ignored host=${uri.host} path=${uri.path}',
        );
        return;
      }
      _debugPlaidLink(
        'oauth redirect received host=${uri.host} path=${uri.path}',
      );
      handoff.markOauthRedirectReceived();
      pendingExitTimer?.cancel();
      try {
        _debugPlaidLink('oauth resume attempted');
        await PlaidLink.resumeAfterTermination(uri.toString());
        _debugPlaidLink('oauth resume completed');
      } on Object catch (error) {
        _debugPlaidLink('oauth redirect resume failed=$error');
      }
    }

    Future<void> resumeLatestPlaidOauth(String source) async {
      try {
        final latestUri = await appLinks.getLatestLink();
        if (latestUri == null) return;
        _debugPlaidLink(
          'latest link check source=$source uri=${latestUri.path}',
        );
        await resumePlaidOauth(latestUri);
      } on Object catch (error) {
        _debugPlaidLink('latest link check failed source=$source error=$error');
      }
    }

    successSubscription = PlaidLink.onSuccess.listen((event) {
      pendingExitTimer?.cancel();
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
      handoff.markExitSeen(event);
      final exit = PlaidLinkLaunchExit(
        status: event.metadata.status,
        errorCode: event.error?.code,
        errorType: event.error?.type,
        requestId: event.metadata.requestId,
      );
      pendingExitTimer?.cancel();
      final exitDelay = handoff.exitDelay;
      _debugPlaidLink('exit completion delayed ${exitDelay.inSeconds}s');
      pendingExitTimer = Timer(exitDelay, () {
        complete(exit);
      });
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
      if (handoff.markEventSeen(event.name)) {
        pendingExitTimer?.cancel();
        _debugPlaidLink('oauth/handoff pending from event=${event.name}');
      }
    });
    oauthRedirectSubscription = appLinks.uriLinkStream.listen(
      (uri) {
        _debugPlaidLink('app_links redirect stream uri=${uri.host}${uri.path}');
        unawaited(resumePlaidOauth(uri));
      },
      onError: (Object error) {
        _debugPlaidLink('oauth redirect listener error=$error');
      },
    );
    nativeOauthRedirectSubscription = _nativeOauthRedirects().listen(
      (uri) {
        _debugPlaidLink('native redirect stream uri=${uri.host}${uri.path}');
        unawaited(resumePlaidOauth(uri));
      },
      onError: (Object error) {
        _debugPlaidLink('native redirect listener error=$error');
      },
    );
    lifecycleListener = AppLifecycleListener(
      onResume: () {
        unawaited(resumeLatestPlaidOauth('app_resume'));
      },
    );

    try {
      _debugPlaidLink(
        'create link token_present=${token.value.trim().isNotEmpty}',
      );
      await PlaidLink.create(
        configuration: LinkTokenConfiguration(token: token.value),
      );
      await resumeLatestPlaidOauth('after_create');
      _debugPlaidLink('open started');
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
      pendingExitTimer?.cancel();
      lifecycleListener.dispose();
      await successSubscription.cancel();
      await exitSubscription.cancel();
      await eventSubscription.cancel();
      await oauthRedirectSubscription.cancel();
      await nativeOauthRedirectSubscription.cancel();
    }
  }

  void _debugPlaidLink(String message) {
    debugPrint('PlaidLink: $message');
  }

  bool _isPlaidOauthRedirect(Uri uri) {
    return uri.scheme == _plaidOauthBaseUri.scheme &&
        uri.host == _plaidOauthBaseUri.host &&
        (uri.path == _plaidOauthBaseUri.path ||
            uri.path.startsWith('${_plaidOauthBaseUri.path}/'));
  }

  Stream<Uri> _nativeOauthRedirects() {
    return _nativeOauthLinks.receiveBroadcastStream().map((event) {
      final raw = event?.toString().trim() ?? '';
      if (raw.isEmpty) {
        throw const PlaidLinkServiceException(
          'Received an empty bank redirect.',
        );
      }
      return Uri.parse(raw);
    });
  }
}

final class _PlaidLinkHandoffState {
  static const _normalExitDelay = Duration(seconds: 4);
  static const _handoffExitDelay = Duration(seconds: 90);

  bool _handoffPending = false;

  Duration get exitDelay =>
      _handoffPending ? _handoffExitDelay : _normalExitDelay;

  bool markEventSeen(String rawName) {
    final name = _normalize(rawName);
    final isOauthOrHandoff =
        name.contains('oauth') || name == 'handoff' || name == 'openoauth';
    if (isOauthOrHandoff) {
      _handoffPending = true;
    }
    return isOauthOrHandoff;
  }

  void markOauthRedirectReceived() {
    _handoffPending = true;
  }

  void markExitSeen(LinkExit event) {
    final status = _normalize(event.metadata.status ?? '');
    final errorCode = _normalize(event.error?.code ?? '');
    if (status.contains('oauth') ||
        errorCode.contains('oauth') ||
        event.metadata.institution != null) {
      _handoffPending = true;
    }
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll('_', '').replaceAll('-', '');
  }
}
