import '../../../app/ui_dependencies.dart';
import '../../../core/formatting/formatting.dart';
import '../../../l10n/app_localizations.dart';
import 'home_screen_widget_bridge.dart';
import '../domain/home_screen_widget_snapshot.dart';

HomeScreenWidgetSnapshot buildHomeScreenWidgetSnapshot({
  required DashboardViewData data,
  required AppLocalizations l10n,
}) {
  return HomeScreenWidgetSnapshot(
    cashLabel: l10n.dashboardOverviewCashTotal,
    cashValue: formatMoney(data.snapshot.cashTotal),
    leftLabel: l10n.dashboardOverviewLeftThisMonth,
    leftValue: formatMoney(data.snapshot.availableThisMonth),
    leftNegative: data.snapshot.availableThisMonth < 0,
    hasAccounts: data.accountCount > 0,
    emptyMessage: l10n.homeScreenWidgetEmpty,
  );
}

Future<void> publishHomeScreenWidget(
  DashboardViewData data,
  AppLocalizations l10n, {
  HomeScreenWidgetBridge? bridge,
}) {
  return (bridge ?? HomeScreenWidgetBridge.instance).publish(
    buildHomeScreenWidgetSnapshot(data: data, l10n: l10n),
  );
}

Future<void> clearHomeScreenWidget({HomeScreenWidgetBridge? bridge}) {
  return (bridge ?? HomeScreenWidgetBridge.instance).clear();
}
