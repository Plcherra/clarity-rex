import 'package:flutter/material.dart';

import '../../../core/layout/clarity_native_layout.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/l10n/friendly_service_error.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../widgets/clarity_diamond_loader.dart';
import '../data/financial_audit_service.dart';
import 'financial_audit_display.dart';

typedef ActivityEventsLoader =
    Future<List<FinancialAuditEvent>> Function({
      required int limit,
      required DateTime since,
    });

/// Thin finance Activity feed: recent `financial_audit_events` for the user.
final class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, this.loadEvents});

  final ActivityEventsLoader? loadEvents;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

final class _ActivityScreenState extends State<ActivityScreen> {
  List<FinancialAuditEvent> _events = const [];
  var _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ActivityEventsLoader get _loader {
    final injected = widget.loadEvents;
    if (injected != null) return injected;
    final service = FinancialAuditService(
      supabaseService: const SupabaseService(),
    );
    return ({required int limit, required DateTime since}) {
      return service.fetchRecent(limit: limit, since: since);
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final since = DateTime.now().toUtc().subtract(const Duration(days: 30));
      final events = await _loader(limit: 50, since: since);
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(l10n.activityScreenTitle),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) {
      return Center(
        child: ClarityDiamondLoader(size: 56, label: l10n.activityLoading),
      );
    }
    if (_error != null) {
      return _ActivityError(
        message: friendlyServiceError(l10n, _error!),
        onRetry: _load,
      );
    }
    if (_events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            l10n.activityEmptyState,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.62),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: ClarityNativeLayout.active(context)
            ? ClarityNativeLayout.pagePadding(context, top: 12, bottom: 28)
            : const EdgeInsets.fromLTRB(20, 12, 20, 28),
        itemCount: _events.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return FinancialAuditEventRow(event: _events[index]);
        },
      ),
    );
  }
}

final class _ActivityError extends StatelessWidget {
  const _ActivityError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}
