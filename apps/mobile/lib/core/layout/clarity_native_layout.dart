import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/clarity_colors.dart';
import '../../theme/clarity_radius.dart';
import '../../theme/clarity_spacing.dart';
import 'clarity_breakpoints.dart';

/// Phone-only layout tokens for native compact chrome.
///
/// Active when [active] is true (`!kIsWeb && width < 800`).
/// Wide Flutter `/app/` and narrow web must not consume these as full-bleed.
///
/// Assistant chrome stays in `RexUiTokens`; gutters/list/type helpers live here
/// so finance can import without pulling rex concerns.
abstract final class ClarityNativeLayout {
  static const double _pageGutter = 10;
  static const double _moduleEdgeInset = 0;
  static const double _sectionGap = 14;
  static const double _cardPadding = 12;
  static const double _listRowPaddingH = 10;
  static const double _listRowPaddingV = 8;
  static const double _listRowGap = 0;
  static const int _listTitleMaxChars = 40;
  static const int _listPreviewMaxLines = 1;
  static const double _composerFieldMinHeight = 46;
  static const double _composerFieldPaddingV = 10;
  static const double _composerChromePadH = 8;

  /// Same gate as [RexUiTokens.isNativeCompactChrome] — single source in core.
  static bool active(BuildContext context) {
    return !kIsWeb && !isClarityDesktopLayout(context);
  }

  /// Outer page inset. Native: 10; wide/web: desktop shell gutter (24).
  static double pageGutter(BuildContext context) {
    return active(context) ? _pageGutter : clarityDesktopContentGutter;
  }

  /// [ShellContentConstraints] clamp gutter. Native: 0; wide/web: 24.
  static double shellContentGutter(BuildContext context) {
    return shellContentGutterFor(nativeCompact: active(context));
  }

  /// Pure gutter resolution for tests (simulates narrow web via `false`).
  static double shellContentGutterFor({required bool nativeCompact}) {
    return nativeCompact ? 0.0 : clarityDesktopContentGutter;
  }

  static EdgeInsets pagePadding(
    BuildContext context, {
    double top = 0,
    double bottom = 0,
  }) {
    final gutter = pageGutter(context);
    return EdgeInsets.fromLTRB(gutter, top, gutter, bottom);
  }

  /// Chart/section modules to screen edge on phone; unused on wide.
  static double moduleEdgeInset(BuildContext context) {
    return active(context) ? _moduleEdgeInset : 0;
  }

  static double sectionGap(BuildContext context) {
    return active(context) ? _sectionGap : ClaritySpacing.xl;
  }

  static EdgeInsets cardPadding(BuildContext context) {
    if (!active(context)) {
      return const EdgeInsets.all(ClaritySpacing.xxl);
    }
    return const EdgeInsets.all(_cardPadding);
  }

  static double cardRadius(BuildContext context) {
    return active(context) ? ClarityRadius.medium : ClarityRadius.card;
  }

  static EdgeInsets listRowPadding(BuildContext context) {
    if (!active(context)) {
      return const EdgeInsets.symmetric(
        horizontal: ClaritySpacing.lg,
        vertical: ClaritySpacing.md,
      );
    }
    return const EdgeInsets.symmetric(
      horizontal: _listRowPaddingH,
      vertical: _listRowPaddingV,
    );
  }

  static double listRowGap(BuildContext context) {
    return active(context) ? _listRowGap : ClaritySpacing.sm;
  }

  static int listTitleMaxChars(BuildContext context) {
    return active(context) ? _listTitleMaxChars : 48;
  }

  static int listPreviewMaxLines(BuildContext context) {
    return active(context) ? _listPreviewMaxLines : 2;
  }

  static TextStyle? listTitle(BuildContext context, {bool selected = false}) {
    final base = Theme.of(context).textTheme.bodyMedium;
    if (!active(context)) {
      return Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      );
    }
    return base?.copyWith(
      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      color: ClarityColors.textPrimary,
    );
  }

  static TextStyle? listPreview(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall;
    if (!active(context)) {
      return Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: ClarityColors.textSecondary,
      );
    }
    return base?.copyWith(color: ClarityColors.textSecondary);
  }

  static TextStyle? sectionLabel(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: ClarityColors.textSecondary,
    );
  }

  /// Phase D will flip composer fill off; token is false for native already.
  static bool composerFieldFill(BuildContext context) {
    return false;
  }

  static double composerFieldMinHeight(BuildContext context) {
    return active(context) ? _composerFieldMinHeight : 40;
  }

  static double composerFieldPaddingV(BuildContext context) {
    return active(context) ? _composerFieldPaddingV : ClaritySpacing.sm;
  }

  static double composerChromePadH(BuildContext context) {
    return active(context) ? _composerChromePadH : ClaritySpacing.sm;
  }
}
