import 'package:clarity/rex/chat/presentation/widgets/attachment_source_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('attachment source sheet exposes gallery camera and files', (
    tester,
  ) async {
    ChatAttachmentSource? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  selected = await showModalBottomSheet<ChatAttachmentSource>(
                    context: context,
                    builder: (_) => const AttachmentSourceSheet(),
                  );
                },
                child: const Text('Attach'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Attach'));
    await tester.pumpAndSettle();

    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(
      find.text('Choose PDF, text, CSV, markdown, or image files.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();

    expect(selected, ChatAttachmentSource.files);
  });
}
