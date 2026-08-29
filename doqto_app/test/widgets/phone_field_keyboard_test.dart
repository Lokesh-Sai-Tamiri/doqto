import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/ui/widgets/phone_field.dart';

void main() {
  Future<GlobalKey<PhoneFieldState>> pump(WidgetTester tester) async {
    final key = GlobalKey<PhoneFieldState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          PhoneField(key: key, onChanged: (_) {}),
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
}
