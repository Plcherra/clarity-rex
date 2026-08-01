import 'package:clarity/app/app_composition.dart';
import 'package:clarity/features/profile/presentation/profile_email_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  testWidgets('an address that is not an address never reaches the network', (
    tester,
  ) async {
    final app = AppComposition(initialAuthenticated: true);
    addTearDown(app.dispose);

    late BuildContext ctx;
    await tester.pumpWidget(
      wrapWithL10nScaffold(
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    showProfileEmailChange(
      ctx,
      authController: app.authController,
      currentEmail: 'test@example.com',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('New email'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'not-an-address');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      find.text('That does not look like an email address.'),
      findsOneWidget,
    );
  });
}
