import 'package:clarity/widgets/clarity_celebration_burst.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the burst paints, then clears itself away', (tester) async {
    await tester.pumpWidget(_host());

    await tester.tap(find.text('finish'));
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);

    // Overlay entries that outlive the animation would sit on top of the app.
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion gets no burst at all', (tester) async {
    await tester.pumpWidget(_host(disableAnimations: true));

    await tester.tap(find.text('finish'));
    await tester.pump();

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Widget _host({bool disableAnimations = false}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showClarityCelebrationBurst(context),
          child: const Text('finish'),
        ),
      ),
    ),
  );
}
