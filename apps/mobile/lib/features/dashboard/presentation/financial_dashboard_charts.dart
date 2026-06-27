part of 'financial_dashboard_view.dart';

List<MonthlyBankGroup> _chronologicalMonthlyGroups(
  List<MonthlyBankGroup> groups,
) {
  return groups.reversed.toList(growable: false);
}

class _DashboardChartPanel extends StatelessWidget {
  const _DashboardChartPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: _dashboardPanel(context),
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _dashboardOutline(context)),
      ),
      child: child,
    );
  }
}
