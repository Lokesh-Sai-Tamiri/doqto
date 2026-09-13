import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:doqto_app/core/constants/strings.dart';
import 'package:doqto_app/core/router/app_router.dart';
import 'package:doqto_app/ui/screens/my_org/my_org_screen.dart';
import 'package:doqto_app/ui/widgets/primary_button.dart';

// Onboarding no longer forces an org, so "no org" is the normal state of the
// My Org tab for a new user. It must offer a way in, not a dead end.
void main() {
  late List<String> pushed;

  Future<void> pump(WidgetTester tester) async {
    pushed = [];
    final router = GoRouter(
      initialLocation: '/my-org',
      routes: [
        GoRoute(path: '/my-org', builder: (_, _) => const MyOrgScreen()),
        GoRoute(
          path: AppRoutes.createOrg,
          builder: (_, _) {
            pushed.add(AppRoutes.createOrg);
            return const SizedBox.shrink();
          },
        ),
        GoRoute(
          path: AppRoutes.joinOrg,
          builder: (_, _) {
            pushed.add(AppRoutes.joinOrg);
            return const SizedBox.shrink();
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('with no org, the tab explains and offers both doors',
      (tester) async {
    await pump(tester);

    expect(find.text(Strings.orgNoneTitle), findsOneWidget);
    expect(find.text(Strings.orgNoneBody), findsOneWidget);
    expect(find.byType(AppButton), findsNWidgets(2));
    // AppButton renders its label twice — an invisible copy holds the width —
    // so both labels legitimately match more than one widget.
    expect(find.widgetWithText(AppButton, Strings.orgNoneCreate), findsWidgets);
    expect(find.widgetWithText(AppButton, Strings.orgNoneJoin), findsWidgets);
    // The old dead end is gone.
    expect(find.text('No organization selected'), findsNothing);
  });

  testWidgets('create and join both lead somewhere', (tester) async {
    await pump(tester);

    await tester.tap(find.widgetWithText(AppButton, Strings.orgNoneCreate).first);
    await tester.pumpAndSettle();
    expect(pushed, [AppRoutes.createOrg]);

    await pump(tester);
    await tester.tap(find.widgetWithText(AppButton, Strings.orgNoneJoin).first);
    await tester.pumpAndSettle();
    expect(pushed, [AppRoutes.joinOrg]);
  });
}
