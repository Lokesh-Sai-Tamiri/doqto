import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/core/tokens/colors.dart';
import 'package:doqto_app/ui/widgets/app_chip.dart';
import 'package:doqto_app/ui/widgets/app_pill.dart';
import 'package:doqto_app/ui/widgets/app_segmented.dart';
import 'package:doqto_app/ui/widgets/inline_banner.dart';
import 'package:doqto_app/ui/widgets/member_row.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('AppPill', () {
    testWidgets('tone maps to token color pair', (tester) async {
      for (final tone in PillTone.values) {
        await tester.pumpWidget(_wrap(AppPill(label: 'pill', tone: tone)));
        final container = tester.widget<Container>(
          find.ancestor(
            of: find.text('pill'),
            matching: find.byType(Container),
          ),
        );
        final deco = container.decoration! as BoxDecoration;
        expect(deco.color, AppPill.backgroundFor(tone), reason: '$tone bg');
        final text = tester.widget<Text>(find.text('pill'));
        expect(text.style!.color, AppPill.foregroundFor(tone),
            reason: '$tone fg');
      }
    });

    testWidgets('DegreeBadge is a brand-toned pill', (tester) async {
      await tester.pumpWidget(_wrap(const DegreeBadge('1st')));
      final pill = tester.widget<AppPill>(find.byType(AppPill));
      expect(pill.tone, PillTone.brand);
      expect(find.text('1st'), findsOneWidget);
    });
  });

  group('InlineBanner', () {
    testWidgets('expands when visible, collapses when not', (tester) async {
      await tester.pumpWidget(_wrap(
        const InlineBanner(tone: BannerTone.warn, text: 'heads up'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('heads up'), findsOneWidget);
      expect(tester.getSize(find.byType(InlineBanner)).height, 26);

      await tester.pumpWidget(_wrap(
        const InlineBanner(
            tone: BannerTone.warn, text: 'heads up', visible: false),
      ));
      await tester.pumpAndSettle();
      expect(find.text('heads up'), findsNothing);
      expect(tester.getSize(find.byType(InlineBanner)).height, 0);
    });

    testWidgets('renders action slot', (tester) async {
      await tester.pumpWidget(_wrap(
        const InlineBanner(
          tone: BannerTone.info,
          text: 'not connected',
          action: Text('Connect'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Connect'), findsOneWidget);
    });
  });

  group('AppSegmented', () {
    testWidgets('thumb moves to the active segment', (tester) async {
      var index = 0;
      await tester.pumpWidget(_wrap(
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 300,
            child: AppSegmented(
              tabs: const ['Focused', 'Requests'],
              index: index,
              onChanged: (i) => setState(() => index = i),
              badges: const [null, 3],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final left0 = tester
          .widget<AnimatedPositioned>(find.byType(AnimatedPositioned))
          .left;
      expect(left0, 0);
      expect(find.text('3'), findsOneWidget); // badge

      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      expect(index, 1);
      final left1 = tester
          .widget<AnimatedPositioned>(find.byType(AnimatedPositioned))
          .left;
      expect(left1, greaterThan(0));
    });

    testWidgets('reduced motion gives zero-duration thumb', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: AppSegmented(
              tabs: const ['A', 'B'],
              index: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      ));
      final thumb = tester
          .widget<AnimatedPositioned>(find.byType(AnimatedPositioned));
      expect(thumb.duration, Duration.zero);
    });
  });

  group('AppChip', () {
    testWidgets('onDelete fires and onTap fires', (tester) async {
      var deleted = 0;
      var tapped = 0;
      await tester.pumpWidget(_wrap(
        AppChip(
          label: 'Cardiology',
          onTap: () => tapped++,
          onDelete: () => deleted++,
        ),
      ));
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(deleted, 1);
      await tester.tap(find.text('Cardiology'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });

    testWidgets('selected state tints background', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppChip(label: 'tag', selected: true),
      ));
      final container = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text('tag'),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final deco = container.decoration! as BoxDecoration;
      expect(deco.color, AppColors.medBlueLight);
    });
  });

  group('MemberRow', () {
    testWidgets('renders slots and fires onTap', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(
        MemberRow(
          avatar: const CircleAvatar(radius: 16, child: Text('SB')),
          title: 'Dr. Strange Bedfellow',
          subtitle: 'Neurosurgery',
          trailing: const Text('1st'),
          onTap: () => tapped++,
        ),
      ));
      expect(find.text('Dr. Strange Bedfellow'), findsOneWidget);
      expect(find.text('Neurosurgery'), findsOneWidget);
      expect(find.text('1st'), findsOneWidget); // trailing slot
      expect(tester.getSize(find.byType(MemberRow)).height, 64);
      await tester.tap(find.byType(MemberRow));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });
  });
}
