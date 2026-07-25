import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/ui/widgets/mutuals_line.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('MutualsLine', () {
    testWidgets('shows +N overflow bubble past maxAvatars', (tester) async {
      final specs = [
        for (var i = 0; i < 5; i++) MutualAvatarSpec(initials: 'M$i'),
      ];
      await tester.pumpWidget(_wrap(
        MutualsLine(avatars: specs, mutualCount: 5, maxAvatars: 3),
      ));
      await tester.pumpAndSettle();
      // 5 total − 3 shown = +2 overflow bubble.
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('5 mutual connections'), findsOneWidget);
    });

    testWidgets('prefers server contextLabel over derived count', (tester) async {
      await tester.pumpWidget(_wrap(
        const MutualsLine(mutualCount: 3, contextLabel: 'Both at Mercy General'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Both at Mercy General'), findsOneWidget);
      expect(find.text('3 mutual connections'), findsNothing);
    });

    testWidgets('singular label for one mutual', (tester) async {
      await tester.pumpWidget(_wrap(const MutualsLine(mutualCount: 1)));
      await tester.pumpAndSettle();
      expect(find.text('1 mutual connection'), findsOneWidget);
    });

    testWidgets('renders nothing with no label and no mutuals', (tester) async {
      await tester.pumpWidget(_wrap(const MutualsLine()));
      await tester.pumpAndSettle();
      expect(find.byType(SizedBox), findsWidgets); // the shrink placeholder
      expect(find.textContaining('mutual'), findsNothing);
    });
  });
}
