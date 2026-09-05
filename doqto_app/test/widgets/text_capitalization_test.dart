import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/ui/widgets/app_text_field.dart';

void main() {
  TextField field(WidgetTester t) => t.widget<TextField>(find.byType(TextField));

  testWidgets('AppTextField capitalizes words by default, none for email', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AppTextField(label: 'Name'))));
    expect(field(tester).textCapitalization, TextCapitalization.words);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AppTextField(keyboardType: TextInputType.emailAddress)),
    ));
    expect(field(tester).textCapitalization, TextCapitalization.none);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AppTextField(textCapitalization: TextCapitalization.sentences)),
    ));
    expect(field(tester).textCapitalization, TextCapitalization.sentences);
  });
}
