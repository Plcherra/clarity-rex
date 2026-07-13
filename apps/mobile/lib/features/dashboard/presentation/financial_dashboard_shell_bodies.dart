part of 'financial_dashboard_view.dart';

class _FinancialDataStatusBanner extends StatelessWidget {
  const _FinancialDataStatusBanner({required this.loadIssues});

  final List<FinancialReadModelLoadIssue> loadIssues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final native = ClarityNativeLayout.active(context);
    final sources =
        loadIssues
            .map((issue) => issue.source.trim())
            .where((source) => source.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final sourceLabel = sources.isEmpty
        ? l10n.dashboardOverviewDataLoadBannerFallbackSource
        : sources.join(', ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ClarityColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(
          native ? ClarityNativeLayout.cardRadius(context) : 18,
        ),
      ),
      child: Padding(
        padding: native
            ? ClarityNativeLayout.cardPadding(context)
            : const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: ClarityColors.warning,
              size: 21,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dashboardOverviewDataLoadBannerTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.dashboardOverviewDataLoadBannerBody(sourceLabel),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.68),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardLoadingBody extends StatelessWidget {
  const _DashboardLoadingBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pagePad = ClarityNativeLayout.active(context)
        ? ClarityNativeLayout.pagePadding(context, top: 24, bottom: 40)
        : const EdgeInsets.fromLTRB(24, 24, 24, 40);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.surfaceContainerLow, cs.surface],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: pagePad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: Center(
                  child: ClarityDiamondLoader(
                    size: 64,
                    label: context.l10n.dashboardOverviewLoadingLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardEmptySetupBody extends StatelessWidget {
  const _DashboardEmptySetupBody({
    required this.title,
    required this.onConnectBank,
    required this.onImportCsvInstead,
  });

  final String title;
  final VoidCallback onConnectBank;
  final VoidCallback onImportCsvInstead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pagePad = ClarityNativeLayout.active(context)
        ? ClarityNativeLayout.pagePadding(context, top: 2, bottom: 40)
        : const EdgeInsets.fromLTRB(24, 2, 24, 40);
    return DecoratedBox(
      decoration: BoxDecoration(color: cs.surface),
      child: SafeArea(
        child: Padding(
          padding: pagePad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title.trim().isNotEmpty)
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 2.4,
                    color: cs.onSurface.withValues(alpha: 0.38),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const Spacer(),
              ConnectBankSetupCard(
                title: context.l10n.dashboardEmptyConnectFirstBankTitle,
                body: context.l10n.dashboardEmptyConnectFirstBankBody,
                onConnectBank: onConnectBank,
                onImportCsvInstead: onImportCsvInstead,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardResolvingDataBody extends StatelessWidget {
  const _DashboardResolvingDataBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final native = ClarityNativeLayout.active(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cs.surfaceContainerLow, cs.surface],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: native
                ? ClarityNativeLayout.pagePadding(context)
                : const EdgeInsets.all(28),
            child: ClarityCard(
              padding: native
                  ? ClarityNativeLayout.cardPadding(context)
                  : const EdgeInsets.all(22),
              borderRadius: native
                  ? BorderRadius.circular(
                      ClarityNativeLayout.cardRadius(context),
                    )
                  : null,
              backgroundColor: cs.surfaceContainerLow,
              borderColor: _dashboardOutline(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ClarityDiamondLoader(size: 52),
                  const SizedBox(height: 18),
                  Text(
                    context.l10n.dashboardResolvingTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.dashboardResolvingBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardLoadMessage extends StatelessWidget {
  const _DashboardLoadMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: ClarityNativeLayout.active(context)
            ? ClarityNativeLayout.pagePadding(context)
            : const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
