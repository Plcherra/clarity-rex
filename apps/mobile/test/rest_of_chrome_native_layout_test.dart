import 'package:clarity/core/layout/clarity_native_layout.dart';
import 'package:clarity/core/layout/clarity_snackbar.dart';
import 'package:clarity/features/accounts/presentation/widgets/accounts_header.dart';
import 'package:clarity/features/accounts/presentation/widgets/empty_accounts_state.dart';
import 'package:clarity/theme/clarity_radius.dart';
import 'package:clarity/theme/clarity_theme.dart';
import 'package:clarity/widgets/clarity_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

Widget _wrap(Size size, Widget child) {
  return wrapWithL10n(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: Theme(
        data: ClarityTheme.dark(),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  testWidgets('compact snackbar clears the bottom dock, not a top-end toast', (
    tester,
  ) async {
    late bool wide;
    late EdgeInsets margin;

    await tester.pumpWidget(
      _wrap(
        const Size(390, 844),
        Builder(
          builder: (context) {
            wide = claritySnackBarUsesWideChrome(context);
            margin = claritySnackBarMargin(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(wide, isFalse);
    expect(margin, const EdgeInsets.fromLTRB(16, 16, 16, 88));
  });

  testWidgets('desktop snackbar stays a top-end toast', (tester) async {
    late bool wide;
    late EdgeInsets margin;

    await tester.pumpWidget(
      _wrap(
        const Size(1280, 900),
        Builder(
          builder: (context) {
            wide = claritySnackBarUsesWideChrome(context);
            margin = claritySnackBarMargin(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(wide, isTrue);
    expect(margin.top, 20);
    expect(margin.right, 20);
    expect(margin.left, 1280 - 420);
  });

  testWidgets('compact accounts summary uses native card pad and radius', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const Size(390, 844),
        const AccountsSummaryCard(accounts: []),
      ),
    );

    final card = tester.widget<ClarityCard>(find.byType(ClarityCard));
    expect(card.padding, const EdgeInsets.all(12));
    expect(card.borderRadius, BorderRadius.circular(ClarityRadius.medium));
  });

  testWidgets('wide accounts summary keeps desktop card chrome', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Size(1280, 900),
        const AccountsSummaryCard(accounts: []),
      ),
    );

    final card = tester.widget<ClarityCard>(find.byType(ClarityCard));
    expect(card.padding, const EdgeInsets.fromLTRB(16, 14, 16, 14));
    expect(card.borderRadius, isNull);
  });

  testWidgets('compact empty accounts state uses native page gutter', (
    tester,
  ) async {
    late double gutter;

    await tester.pumpWidget(
      _wrap(
        const Size(390, 844),
        Builder(
          builder: (context) {
            gutter = ClarityNativeLayout.pageGutter(context);
            return EmptyAccountsState(
              onConnectBank: () {},
              onImportCsvInstead: () {},
              onAddManualAccount: () {},
            );
          },
        ),
      ),
    );

    expect(gutter, 10);
    final paddings = tester.widgetList<Padding>(
      find.descendant(
        of: find.byType(EmptyAccountsState),
        matching: find.byType(Padding),
      ),
    );
    expect(
      paddings.map((padding) => padding.padding),
      contains(const EdgeInsets.symmetric(horizontal: 10)),
    );
  });
}
