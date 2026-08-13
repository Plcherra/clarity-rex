import 'package:clarity/core/layout/clarity_native_layout.dart';
import 'package:clarity/rex/presentation/assistant_overview_widgets.dart';
import 'package:clarity/rex/presentation/pages/companion_settings_sections.dart';
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
  testWidgets('compact overview section card uses native card padding', (
    tester,
  ) async {
    late EdgeInsets cardPad;

    await tester.pumpWidget(
      _wrap(
        const Size(390, 844),
        Builder(
          builder: (context) {
            cardPad = ClarityNativeLayout.cardPadding(context);
            return const OverviewSectionCard(
              title: 'Goals',
              icon: Icons.flag_outlined,
              child: SizedBox(height: 8),
            );
          },
        ),
      ),
    );

    expect(cardPad, const EdgeInsets.all(12));
    final card = tester.widget<ClarityCard>(find.byType(ClarityCard));
    expect(card.padding, cardPad);
  });

  testWidgets('wide overview section card keeps desktop padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const Size(1280, 900),
        const OverviewSectionCard(
          title: 'Goals',
          icon: Icons.flag_outlined,
          child: SizedBox(height: 8),
        ),
      ),
    );

    final card = tester.widget<ClarityCard>(find.byType(ClarityCard));
    expect(card.padding, const EdgeInsets.fromLTRB(16, 14, 12, 14));
  });

  testWidgets('compact companion settings rows use native list padding', (
    tester,
  ) async {
    late EdgeInsets listPad;

    await tester.pumpWidget(
      _wrap(
        const Size(390, 844),
        Builder(
          builder: (context) {
            listPad = ClarityNativeLayout.listRowPadding(context);
            return CompanionSwitchRow(
              icon: Icons.memory_outlined,
              title: 'Facts',
              value: true,
              onChanged: (_) {},
            );
          },
        ),
      ),
    );

    expect(listPad, const EdgeInsets.symmetric(horizontal: 10, vertical: 8));
    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.contentPadding, listPad);
  });

  testWidgets('wide companion settings rows keep desktop padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const Size(1280, 900),
        CompanionSwitchRow(
          icon: Icons.memory_outlined,
          title: 'Facts',
          value: true,
          onChanged: (_) {},
        ),
      ),
    );

    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(
      tile.contentPadding,
      const EdgeInsets.symmetric(horizontal: 14),
    );
  });
}
