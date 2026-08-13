import 'package:clarity/core/layout/clarity_native_layout.dart';
import 'package:clarity/features/budgets/presentation/budget_category_list.dart';
import 'package:clarity/features/budgets/presentation/budget_category_row.dart';
import 'package:clarity/theme/clarity_radius.dart';
import 'package:clarity/widgets/clarity_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void _noop(String _) {}

Widget _listAt(Size size) {
  return wrapWithL10n(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: const Scaffold(
        body: BudgetCategoryList(
          items: [],
          controllers: {},
          focusNodes: {},
          onTrackCategoryCount: 0,
          budgetedCategoryCount: 0,
          onCategoryValueChanged: _noop,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('compact budgets category list uses native card radius and tile pad', (
    tester,
  ) async {
    late EdgeInsets cardPad;
    late double radius;

    await tester.pumpWidget(
      wrapWithL10n(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              cardPad = ClarityNativeLayout.cardPadding(context);
              radius = ClarityNativeLayout.cardRadius(context);
              return const Scaffold(
                body: BudgetCategoryList(
                  items: [],
                  controllers: {},
                  focusNodes: {},
                  onTrackCategoryCount: 0,
                  budgetedCategoryCount: 0,
                  onCategoryValueChanged: _noop,
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(cardPad, const EdgeInsets.all(12));
    expect(radius, ClarityRadius.medium);

    final card = tester.widget<ClarityCard>(find.byType(ClarityCard));
    expect(card.borderRadius, BorderRadius.circular(ClarityRadius.medium));

    final tile = tester.widget<ExpansionTile>(find.byType(ExpansionTile));
    expect(tile.tilePadding, EdgeInsets.fromLTRB(cardPad.left, 2, 8, 2));
  });

  testWidgets('wide budgets category list keeps desktop tile pad and card radius', (
    tester,
  ) async {
    await tester.pumpWidget(_listAt(const Size(1280, 900)));

    final card = tester.widget<ClarityCard>(find.byType(ClarityCard));
    expect(card.borderRadius, isNull);

    final tile = tester.widget<ExpansionTile>(find.byType(ExpansionTile));
    expect(tile.tilePadding, const EdgeInsets.fromLTRB(16, 2, 8, 2));
  });

  testWidgets('budget amount field still accepts digits when keyboard inset is open', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      wrapWithL10n(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewInsets: EdgeInsets.only(bottom: 320),
          ),
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            body: BudgetCategoryRowTile(
              displayLabel: 'Groceries',
              controller: controller,
              focusNode: focusNode,
              indicatorColor: Colors.green,
              statusText: 'On track',
              statusColor: Colors.green,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '250');
    expect(controller.text, '250');
    expect(find.byType(TextField), findsOneWidget);
  });
}
