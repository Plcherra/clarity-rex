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

class _DashboardCollapsibleChartGroup extends StatelessWidget {
  const _DashboardCollapsibleChartGroup({
    required this.title,
    this.subtitle,
    required this.initiallyExpanded,
    this.controller,
    required this.children,
    this.alwaysExpanded = false,
  });

  final String title;
  final String? subtitle;
  final bool initiallyExpanded;
  final ExpansionTileController? controller;
  final List<Widget> children;
  final bool alwaysExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (alwaysExpanded) {
      return ClarityCard(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        backgroundColor: _dashboardPanel(context),
        borderColor: _dashboardOutline(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.58),
                ),
              ),
            ],
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      );
    }

    return ClarityCard(
      padding: EdgeInsets.zero,
      backgroundColor: _dashboardPanel(context),
      borderColor: _dashboardOutline(context),
      child: Theme(
        data: theme.copyWith(
          dividerColor: Colors.transparent,
          splashColor: cs.primary.withValues(alpha: 0.08),
        ),
        child: ExpansionTile(
          controller: controller,
          tilePadding: const EdgeInsets.fromLTRB(20, 2, 12, 2),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          initiallyExpanded: initiallyExpanded,
          iconColor: cs.onSurface.withValues(alpha: 0.56),
          collapsedIconColor: cs.onSurface.withValues(alpha: 0.56),
          title: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.58),
                  ),
                ),
          children: children,
        ),
      ),
    );
  }
}

class _DashboardChartSection extends StatelessWidget {
  const _DashboardChartSection({
    required this.title,
    this.subtitle,
    this.sectionKey,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Key? sectionKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: sectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(theme: theme, title: title),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          _SectionSubtitle(theme: theme, subtitle: subtitle!),
        ],
        const SizedBox(height: 16),
        _DashboardChartPanel(child: child),
      ],
    );
  }
}

class _SectionSubtitle extends StatelessWidget {
  const _SectionSubtitle({required this.theme, required this.subtitle});

  final ThemeData theme;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Text(
      subtitle,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.52),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
