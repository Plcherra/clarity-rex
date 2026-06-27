import 'package:flutter/material.dart';

import 'package:clarity/features/usage_admin/application/owner_usage_controller.dart';
import 'package:clarity/features/usage_admin/data/usage_admin_models.dart';
import 'package:clarity/features/usage_admin/presentation/owner_user_detail_screen.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/widgets/clarity_card.dart';
import 'package:clarity/widgets/clarity_diamond_loader.dart';

final class OwnerUsageHubScreen extends StatefulWidget {
  const OwnerUsageHubScreen({super.key, OwnerUsageController? controller})
    : _controller = controller;

  final OwnerUsageController? _controller;

  @override
  State<OwnerUsageHubScreen> createState() => _OwnerUsageHubScreenState();
}

class _OwnerUsageHubScreenState extends State<OwnerUsageHubScreen> {
  late final OwnerUsageController _controller =
      widget._controller ?? OwnerUsageController();
  late final bool _ownsController = widget._controller == null;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Usage administration'),
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
          if (_controller.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_controller.errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _controller.load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final summary = _controller.summary;
          return RefreshIndicator(
            onRefresh: _controller.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                if (summary != null) ...[
                  ClarityCard(
                    padding: const EdgeInsets.all(18),
                    backgroundColor: colors.surface.withValues(alpha: 0.72),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Platform this month',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatUsageCost(
                            summary.monthEstimatedCostCents,
                            hasUsageWithoutCost: summary.monthLlmCalls > 0 ||
                                summary.monthVoiceSeconds > 0,
                          ),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${summary.activeUserCount} active users · '
                          '${formatUsageMinutes(summary.monthVoiceSeconds)} voice · '
                          '${summary.monthLlmCalls} AI calls',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Users',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                if (_controller.users.isEmpty)
                  Text(
                    'No usage recorded this month yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textMuted,
                    ),
                  )
                else
                  for (final user in _controller.users) ...[
                    _OwnerUserTile(
                      user: user,
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => OwnerUserDetailScreen(user: user),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OwnerUserTile extends StatelessWidget {
  const _OwnerUserTile({required this.user, required this.onTap});

  final OwnerUserUsage user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;

    return Material(
      color: colors.surfaceSoft.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatUsageMinutes(user.monthVoiceSeconds)} voice · '
                      '${user.monthChatLlmCalls} chat · '
                      '${user.monthVoiceLlmCalls} voice calls',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatUsageCost(
                  user.monthEstimatedCostCents,
                  hasUsageWithoutCost: user.monthLlmCalls > 0 ||
                      user.monthVoiceSeconds > 0,
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
