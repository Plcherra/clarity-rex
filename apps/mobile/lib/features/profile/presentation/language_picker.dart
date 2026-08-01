import 'package:flutter/material.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/l10n/clarity_locale_catalog.dart';
import '../../../core/layout/clarity_adaptive_overlay.dart';
import '../../../core/layout/clarity_native_layout.dart';
import '../application/locale_controller.dart';

/// The app language chooser, reachable from Profile and from Companion.
///
/// Language sits in both places because it changes the interface and what Rex
/// speaks, and neither caller is the obvious one to look in first.
Future<void> showClarityLanguagePicker(
  BuildContext context,
  LocaleController controller,
) {
  return showClarityAdaptiveOverlay<void>(
    context: context,
    dialogMaxWidth: 420,
    dialogMaxHeight: 420,
    builder: (sheetContext) {
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return Padding(
            padding: ClarityNativeLayout.active(context)
                ? ClarityNativeLayout.pagePadding(context, top: 16, bottom: 20)
                : const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.profileLanguage,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                for (final supported in controller.enabledLocales)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(controller.labelFor(supported)),
                    trailing:
                        controller.localeTag ==
                            ClarityLocaleCatalog.localeTagFor(supported)
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () async {
                      await controller.setLocale(supported);
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n.profileLanguageUpdated(
                                controller.labelFor(supported),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}
