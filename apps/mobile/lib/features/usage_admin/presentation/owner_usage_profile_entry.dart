import 'package:flutter/material.dart';

import 'package:clarity/core/l10n/app_l10n.dart';
import 'package:clarity/features/usage_admin/application/owner_usage_controller.dart';
import 'package:clarity/features/usage_admin/presentation/owner_usage_hub_screen.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/widgets/clarity_card.dart';

final class OwnerUsageProfileEntry extends StatefulWidget {
  const OwnerUsageProfileEntry({super.key});

  @override
  State<OwnerUsageProfileEntry> createState() => _OwnerUsageProfileEntryState();
}

class _OwnerUsageProfileEntryState extends State<OwnerUsageProfileEntry> {
  late final OwnerAccessController _controller = OwnerAccessController();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading || !_controller.isOwner) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        final colors = context.clarityColors;
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.usageAdminOwnerSection,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.52),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.35,
                ),
              ),
              const SizedBox(height: 8),
              ClarityCard(
                padding: EdgeInsets.zero,
                highlighted: false,
                backgroundColor: colors.surface.withValues(alpha: 0.58),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const OwnerUsageHubScreen(),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings_outlined,
                            color: colors.accent,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.usageAdminTitle,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.usageAdminSubtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
