import 'package:clarity/rex/chat/domain/chat_message.dart';
import 'package:clarity/rex/chat/presentation/widgets/clarity_generic_action_card.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/l10n_test_wrapper.dart';

ClarityActionCard _openThreadCard({
  String? targetLabel,
  String confirmationText =
      'Track as an open thread in Goals?\nWake at 6am\nThis is companion follow-up — not saved memory.',
}) {
  return ClarityActionCard(
    id: 'write-1',
    action: 'save_open_thread',
    payload: const {},
    confirmationText: confirmationText,
    status: 'pending',
    riskLevel: 'medium',
    title: 'Wake at 6am',
    body: 'Follow up on waking at 6am',
    writeKind: 'open_thread',
    targetLabel: targetLabel,
    editableFields: const ['title'],
  );
}

void main() {
  testWidgets('open thread pending card hides Details field', (tester) async {
    await tester.pumpWidget(
      wrapWithL10nScaffold(
        ClarityGenericActionCard(action: _openThreadCard()),
      ),
    );

    expect(find.text('Track in Goals'), findsOneWidget);
    expect(find.text('Thread title'), findsOneWidget);
    expect(find.text('Details (optional)'), findsNothing);
  });

  testWidgets('open thread update card uses Update in Goals headline', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithL10nScaffold(
        ClarityGenericActionCard(
          action: _openThreadCard(
            targetLabel: 'Sleep Schedule and Wake Up Everyday At 3am',
            confirmationText:
                'Update open thread "Sleep Schedule…3am" to:\nWake at 6am\nThis stays companion follow-up — not saved memory.',
          ),
        ),
      ),
    );

    expect(find.text('Update in Goals'), findsOneWidget);
    expect(find.text('Details (optional)'), findsNothing);
  });
}
