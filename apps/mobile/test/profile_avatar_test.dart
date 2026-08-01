import 'package:clarity/features/profile/presentation/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

void main() {
  testWidgets('falls back to the first letter when there is no photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithL10nScaffold(
        ProfileAvatar(name: 'Pedro Martins', imageUrl: null, onTap: () {}),
      ),
    );

    expect(find.text('P'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('an account with no name still has something to show', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithL10nScaffold(
        ProfileAvatar(name: '   ', imageUrl: null, onTap: () {}),
      ),
    );

    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('tapping asks to change the photo', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrapWithL10nScaffold(
        ProfileAvatar(name: 'Pedro', imageUrl: null, onTap: () => taps++),
      ),
    );

    await tester.tap(find.byType(ProfileAvatar));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('an upload in flight shows progress and refuses a second tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      wrapWithL10nScaffold(
        ProfileAvatar(
          name: 'Pedro',
          imageUrl: null,
          isBusy: true,
          onTap: () => taps++,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('P'), findsNothing);

    await tester.tap(find.byType(ProfileAvatar));
    await tester.pump();

    expect(taps, 0);
  });
}
