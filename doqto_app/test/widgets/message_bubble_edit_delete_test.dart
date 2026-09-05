import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/core/constants/strings.dart';
import 'package:doqto_app/ui/widgets/message_bubble.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget w) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));

  testWidgets('deleted bubble shows the tombstone and no ticks', (tester) async {
    await pump(
      tester,
      MessageBubble(
        text: 'should not render',
        isMine: true,
        timestamp: DateTime(2026, 9, 5, 10),
        deleted: true,
        read: true,
      ),
    );
    expect(find.text(Strings.chatMessageDeleted), findsOneWidget);
    expect(find.text('should not render'), findsNothing);
    expect(find.byType(MessageStatusTick), findsNothing);
  });

  testWidgets('edited bubble shows a tappable Edited label', (tester) async {
    var taps = 0;
    await pump(
      tester,
      MessageBubble(
        text: 'hello',
        isMine: false,
        timestamp: DateTime(2026, 9, 5, 10),
        edited: true,
        onEditedTap: () => taps++,
      ),
    );
    expect(find.text('hello'), findsOneWidget);
    await tester.tap(find.text(Strings.chatEdited));
    expect(taps, 1);
  });

  testWidgets('plain bubble has neither label nor tombstone', (tester) async {
    await pump(
      tester,
      MessageBubble(text: 'plain', isMine: true, timestamp: DateTime(2026, 9, 5, 10)),
    );
    expect(find.text(Strings.chatEdited), findsNothing);
    expect(find.text(Strings.chatMessageDeleted), findsNothing);
  });
}
