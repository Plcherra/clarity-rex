import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../../widgets/clarity_card.dart';
import '../../../widgets/clarity_diamond_loader.dart';
import '../application/usage_summary_controller.dart';
import '../application/usage_summary_service.dart';

final class UsageSummaryScreen extends StatefulWidget {
  const UsageSummaryScreen({super.key, UsageSummaryController? controller})
    : _controller = controller;

  final UsageSummaryController? _controller;

  @override
  State<UsageSummaryScreen> createState() => _UsageSummaryScreenState();
}

final class _UsageSummaryScreenState extends State<UsageSummaryScreen> {
  late final UsageSummaryController _controller =
      widget._controller ??
      UsageSummaryController(
        usageSummaryService: UsageSummaryService(
          supabaseService: const SupabaseService(),
        ),
      );
  late final bool _ownsController = widget._controller == null;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Voice usage'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(
              child: ClarityDiamondLoader(size: 56, label: 'Loading usage'),
            );
          }
          final error = _controller.errorMessage;
          if (error != null) {
            return _UsageError(message: error, onRetry: _controller.load);
          }
          final totals = _controller.totals;
          return RefreshIndicator(
            onRefresh: _controller.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _UsageHeader(
                  totalMinutes: _minutes(totals.monthVoiceSeconds),
                  totalCalls: totals.monthLlmCalls,
                ),
                const SizedBox(height: 16),
                _UsageStatTile(
                  title: 'Today',
                  minutes: _minutes(totals.todayVoiceSeconds),
                  calls: totals.todayLlmCalls,
                ),
                const SizedBox(height: 10),
                _UsageStatTile(
                  title: 'This week',
                  minutes: _minutes(totals.weekVoiceSeconds),
                  calls: totals.weekLlmCalls,
                ),
                const SizedBox(height: 10),
                _UsageStatTile(
                  title: 'This month',
                  minutes: _minutes(totals.monthVoiceSeconds),
                  calls: totals.monthLlmCalls,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

final class _UsageStatTile extends StatelessWidget {
  const _UsageStatTile({
    required this.title,
    required this.minutes,
    required this.calls,
  });

  final String title;
  final double minutes;
  final int calls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ClarityCard(
      padding: const EdgeInsets.all(18),
      backgroundColor: cs.surfaceContainerLow.withValues(alpha: 0.56),
      borderColor: cs.outlineVariant.withValues(alpha: 0.56),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.graphic_eq_rounded,
                color: cs.primary,
                size: 21,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$calls Grok calls',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatMinutes(minutes),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

final class _UsageHeader extends StatelessWidget {
  const _UsageHeader({required this.totalMinutes, required this.totalCalls});

  final double totalMinutes;
  final int totalCalls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ClarityCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: cs.surfaceContainerLow.withValues(alpha: 0.74),
      borderColor: cs.outlineVariant.withValues(alpha: 0.64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rex voice activity',
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.52),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatMinutes(totalMinutes),
            style: theme.textTheme.displaySmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w900,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$totalCalls Grok calls this month',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

final class _UsageError extends StatelessWidget {
  const _UsageError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

double _minutes(double seconds) => seconds / 60;

String _formatMinutes(double minutes) {
  if (minutes < 1 && minutes > 0) return '<1 min';
  return '${minutes.round()} min';
}
