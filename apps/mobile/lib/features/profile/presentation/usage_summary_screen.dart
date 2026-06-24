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
    return Scaffold(
      appBar: AppBar(title: const Text('Voice usage')),
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$calls Grok calls',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatMinutes(minutes),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
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
