/// Values written to the iOS App Group for the home-screen widget.
///
/// Numbers only — never Plaid tokens, account IDs, or user email.
final class HomeScreenWidgetSnapshot {
  const HomeScreenWidgetSnapshot({
    required this.cashLabel,
    required this.cashValue,
    required this.leftLabel,
    required this.leftValue,
    required this.leftNegative,
    required this.hasAccounts,
    required this.emptyMessage,
  });

  final String cashLabel;
  final String cashValue;
  final String leftLabel;
  final String leftValue;
  final bool leftNegative;
  final bool hasAccounts;
  final String emptyMessage;

  static const channelName = 'clarity/home_screen_widget';
  static const kind = 'ClarityHomeWidget';
  static const appGroupId = 'group.app.goclarity.clarity';
  static const openScheme = 'io.goclarity.clarity';
  static const openHost = 'overview';

  static const keyCashLabel = 'clarity.widget.cashLabel';
  static const keyCashValue = 'clarity.widget.cashValue';
  static const keyLeftLabel = 'clarity.widget.leftLabel';
  static const keyLeftValue = 'clarity.widget.leftValue';
  static const keyLeftNegative = 'clarity.widget.leftNegative';
  static const keyHasAccounts = 'clarity.widget.hasAccounts';
  static const keyEmptyMessage = 'clarity.widget.emptyMessage';

  static const flagTrue = '1';
  static const flagFalse = '0';

  static Uri get openUri => Uri(scheme: openScheme, host: openHost);

  static bool isOverviewUri(Uri uri) {
    return uri.scheme == openScheme && uri.host == openHost;
  }

  Map<String, String> toAppGroupFields() {
    return {
      keyCashLabel: cashLabel,
      keyCashValue: cashValue,
      keyLeftLabel: leftLabel,
      keyLeftValue: leftValue,
      keyLeftNegative: leftNegative ? flagTrue : flagFalse,
      keyHasAccounts: hasAccounts ? flagTrue : flagFalse,
      keyEmptyMessage: emptyMessage,
    };
  }
}
