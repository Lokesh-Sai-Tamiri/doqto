import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/ui/widgets/phone_field.dart';

void main() {
  Future<GlobalKey<PhoneFieldState>> pump(WidgetTester tester,
      {bool optional = false}) async {
    final key = GlobalKey<PhoneFieldState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          PhoneField(key: key, onChanged: (_) {}, optional: optional),
          const SizedBox(height: 200, width: 200, child: Text('outside')),
        ]),
      ),
    ));
    return key;
  }

  testWidgets('keyboard drops once the number is complete', (tester) async {
    await pump(tester);
    final field = find.byType(TextField);

    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.enterText(field, '312533965'); // 9 digits — still short
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.enterText(field, '3125339656'); // valid US number
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('tapping outside dismisses the keyboard', (tester) async {
    await pump(tester);
    final field = find.byType(TextField);

    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, '312'); // incomplete, keyboard stays
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('outside'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
  });

  // Optional mode (the social sign-up phone on Your details): empty is valid.
  testWidgets('optional: leaving it empty is not an error', (tester) async {
    await pump(tester, optional: true);
    final field = find.byType(TextField);

    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text('outside'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your phone number.'), findsNothing);
  });

  testWidgets('optional: backspacing to empty keeps the keyboard',
      (tester) async {
    await pump(tester, optional: true);
    final field = find.byType(TextField);

    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, '31');
    await tester.pumpAndSettle();
    await tester.enterText(field, '');
    await tester.pumpAndSettle();

    // Empty is "valid" when optional, but that must not read as "complete".
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('optional: a complete number still drops the keypad',
      (tester) async {
    await pump(tester, optional: true);
    final field = find.byType(TextField);

    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(field, '3125339656');
    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, isFalse);
  });
}
