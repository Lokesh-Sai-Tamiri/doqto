import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/ui/widgets/app_pressable.dart';
import 'package:doqto_app/ui/widgets/app_skeleton.dart';
import 'package:doqto_app/ui/widgets/fade_slide_in.dart';
import 'package:doqto_app/ui/widgets/primary_button.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('AppPressable', () {
    testWidgets('tap fires onTap', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(
        AppPressable(onTap: () => tapped++, child: const Text('press')),
      ));
      await tester.tap(find.text('press'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });

    testWidgets('disabled does not fire onTap and dims', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(
        AppPressable(
          enabled: false,
          onTap: () => tapped++,
          child: const Text('press'),
        ),
      ));
      await tester.tap(find.text('press'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tapped, 0);
      final opacity = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.text('press'),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacity.opacity, 0.4);
    });
  });

  group('FadeSlideIn', () {
    testWidgets('child appears after animation', (tester) async {
      await tester.pumpWidget(_wrap(
        const FadeSlideIn(child: Text('hello')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('staggered helper builds', (tester) async {
      await tester.pumpWidget(_wrap(
        Column(
          children: [
            FadeSlideIn.staggered(0, const Text('row0')),
            FadeSlideIn.staggered(1, const Text('row1')),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('row0'), findsOneWidget);
      expect(find.text('row1'), findsOneWidget);
    });
  });

  group('AppSkeleton', () {
    testWidgets('line, circle, block and SkeletonList build', (tester) async {
      await tester.pumpWidget(_wrap(
        Column(
          children: [
            AppSkeleton.line(width: 120),
            AppSkeleton.circle(size: 40),
            AppSkeleton.block(height: 60),
            const Expanded(child: SkeletonList(rows: 3)),
          ],
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AppSkeleton), findsWidgets);
      expect(find.byType(SkeletonList), findsOneWidget);
    });
  });

  group('AppButton', () {
    testWidgets('loading swaps label for spinner without firing tap',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(
        AppButton(label: 'Save', onPressed: () => tapped++),
      ));
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpWidget(_wrap(
        AppButton(label: 'Save', onPressed: () => tapped++, loading: true),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tapped, 0);
    });
  });
}
