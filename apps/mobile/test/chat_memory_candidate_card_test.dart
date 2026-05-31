import 'package:clarity/features/assistant/chat/domain/chat_message.dart';
import 'package:clarity/features/assistant/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Chat memory card shows high-risk pending review context', (
    tester,
  ) async {
    final candidate = MemoryCandidateCard.fromJson({
      'id': 'candidate-high-risk',
      'candidate_type': 'correction',
      'status': 'pending',
      'risk_level': 'high',
      'preview': 'correction: pending memory change',
      'reason': 'The user corrected a saved fact.',
      'expected_action': 'replace saved memory after confirmation',
      'source_conversation_id': 'conversation-1',
      'requires_explicit_confirmation': true,
      'payload_preview': {
        'intent': {'old_value': 'Flowfirst', 'new_value': 'FlowForce'},
      },
    });

    await _pumpBubble(tester, [candidate]);

    expect(find.text('Correction'), findsOneWidget);
    expect(find.text('High risk'), findsOneWidget);
    expect(find.text('Needs review'), findsOneWidget);
    expect(find.text('Proposed memory'), findsOneWidget);
    expect(
      find.text('Correction: replace "Flowfirst" with "FlowForce"'),
      findsOneWidget,
    );
    expect(find.text('May change: Flowfirst'), findsOneWidget);
    expect(find.text('Replace with: FlowForce'), findsOneWidget);
    expect(find.text('Why Rex suggested it'), findsOneWidget);
    expect(find.text('The user corrected a saved fact.'), findsOneWidget);
    expect(
      find.text('Replace Saved Memory After Confirmation'),
      findsOneWidget,
    );
    expect(find.text('From recent chat'), findsOneWidget);
    expect(
      find.text(
        'Rex will wait for your approval before changing saved memory.',
      ),
      findsOneWidget,
    );
    expect(find.text('Confirm save'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Edit first'), findsOneWidget);
  });

  testWidgets('Chat memory cards show distinct completed states', (
    tester,
  ) async {
    final candidates = [
      MemoryCandidateCard.fromJson({
        'id': 'candidate-applied',
        'candidate_type': 'long_term_memory',
        'status': 'applied',
        'risk_level': 'medium',
        'preview': 'long_term_memory: Pedro prefers email',
      }),
      MemoryCandidateCard.fromJson({
        'id': 'candidate-rejected',
        'candidate_type': 'entity_event',
        'status': 'rejected',
        'risk_level': 'low',
        'preview': 'entity_event: Met Sofia',
      }),
      MemoryCandidateCard.fromJson({
        'id': 'candidate-failed',
        'candidate_type': 'plan',
        'status': 'failed',
        'risk_level': 'high',
        'preview': 'plan: Move to Portugal',
        'verification': {
          'passed': false,
          'message':
              'Candidate approval failed before durable write completed.',
        },
      }),
    ];

    await _pumpBubble(tester, candidates);

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Saved to Rex Memory.'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    expect(
      find.text('Rejected. Rex will not save this memory.'),
      findsOneWidget,
    );
    expect(find.text('Needs attention'), findsOneWidget);
    expect(
      find.text('Could not save this memory. Review it before trying again.'),
      findsOneWidget,
    );
    expect(
      find.text('Candidate approval failed before durable write completed.'),
      findsOneWidget,
    );
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Confirm save'), findsNothing);
    expect(find.text('Reject'), findsNothing);
    expect(find.text('Edit first'), findsNothing);
  });
}

Future<void> _pumpBubble(
  WidgetTester tester,
  List<MemoryCandidateCard> candidates,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: ChatMessageBubble(
              text: 'I found memory updates.',
              memoryCandidates: candidates,
              onApproveCandidate: (_) {},
              onRejectCandidate: (_) {},
              onEditCandidate: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
