import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/l10n/clarity_locale_catalog.dart';
import '../../../core/layout/clarity_native_layout.dart';
import '../../../theme/clarity_colors.dart';
import '../../../widgets/clarity_card.dart';
import '../application/locale_controller.dart';
import '../application/theme_mode_controller.dart';

final class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final colors = context.clarityColors;
    final initial = name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase();

    return ClarityCard(
      padding: ClarityNativeLayout.active(context)
          ? ClarityNativeLayout.cardPadding(context)
          : const EdgeInsets.all(20),
      backgroundColor: colors.surface.withValues(alpha: 0.72),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: SizedBox(
              width: 58,
              height: 58,
              child: Center(
                child: Text(
                  initial,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.profileHeaderLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.48),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class ProfileSectionLabel extends StatelessWidget {
  const ProfileSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: cs.onSurface.withValues(alpha: 0.52),
        fontWeight: FontWeight.w900,
        letterSpacing: 0.35,
      ),
    );
  }
}

final class ProfileActionGroup extends StatelessWidget {
  const ProfileActionGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.clarityColors;
    return ClarityCard(
      padding: EdgeInsets.zero,
      highlighted: false,
      backgroundColor: colors.surface.withValues(alpha: 0.58),
      child: Column(children: children),
    );
  }
}

final class ProfileActionTile extends StatelessWidget {
  const ProfileActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final colors = context.clarityColors;
    final color = destructive ? cs.error : colors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: ClarityNativeLayout.active(context)
              ? ClarityNativeLayout.listRowPadding(context)
              : const EdgeInsets.fromLTRB(14, 13, 10, 13),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: (destructive ? cs.error : colors.accent).withValues(
                    alpha: destructive ? 0.12 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Icon(
                    icon,
                    size: 20,
                    color: destructive ? cs.error : colors.accent,
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
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: destructive
                            ? cs.error.withValues(alpha: 0.76)
                            : cs.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (showChevron) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: destructive
                      ? cs.error.withValues(alpha: 0.72)
                      : cs.onSurface.withValues(alpha: 0.32),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String profileThemeModeLabel(BuildContext context, ThemeMode mode) {
  final l10n = context.l10n;
  return switch (mode) {
    ThemeMode.system => l10n.themeSystem,
    ThemeMode.dark => l10n.themeDark,
    ThemeMode.light => l10n.themeLight,
  };
}

/// Inline theme segmented control for desktop settings.
final class ProfileThemeInlineControl extends StatelessWidget {
  const ProfileThemeInlineControl({
    super.key,
    required this.controller,
  });

  final ThemeModeController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return ProfileActionGroup(
          children: [
            Padding(
              padding: ClarityNativeLayout.active(context)
                  ? ClarityNativeLayout.cardPadding(context)
                  : const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.contrast_rounded,
                        size: 20,
                        color: context.clarityColors.accent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.profileAppearance,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: [
                      for (final mode in ThemeMode.values)
                        ButtonSegment(
                          value: mode,
                          label: Text(profileThemeModeLabel(context, mode)),
                        ),
                    ],
                    selected: {controller.themeMode},
                    onSelectionChanged: (next) async {
                      if (next.isEmpty) return;
                      await controller.setThemeMode(next.first);
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Inline language dropdown for desktop settings.
final class ProfileLanguageInlineControl extends StatelessWidget {
  const ProfileLanguageInlineControl({
    super.key,
    required this.controller,
  });

  final LocaleController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return ProfileActionGroup(
          children: [
            Padding(
              padding: ClarityNativeLayout.active(context)
                  ? ClarityNativeLayout.cardPadding(context)
                  : const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.translate_rounded,
                        size: 20,
                        color: context.clarityColors.accent,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.profileLanguage,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Locale>(
                    initialValue: controller.enabledLocales.firstWhere(
                      (locale) =>
                          ClarityLocaleCatalog.localeTagFor(locale) ==
                          controller.localeTag,
                      orElse: () => controller.enabledLocales.first,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final locale in controller.enabledLocales)
                        DropdownMenuItem(
                          value: locale,
                          child: Text(controller.labelFor(locale)),
                        ),
                    ],
                    onChanged: (locale) async {
                      if (locale == null) return;
                      await controller.setLocale(locale);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.profileLanguageUpdated(
                              controller.labelFor(locale),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
