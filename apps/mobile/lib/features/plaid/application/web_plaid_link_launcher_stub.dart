import 'plaid_connection_models.dart';

/// Non-web stub. [AppCapabilities.supportsWebPlaidLink] should prevent use.
final class WebPlaidLinkLauncher implements PlaidLinkLauncher {
  const WebPlaidLinkLauncher();

  @override
  Future<PlaidLinkLaunchResult> open(PlaidLinkToken token) async {
    return const PlaidLinkLaunchExit(
      status: 'unsupported_platform',
      errorCode: 'unsupported_platform',
      errorType: 'PLATFORM',
    );
  }
}
