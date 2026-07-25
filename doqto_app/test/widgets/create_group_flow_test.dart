import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/core/constants/strings.dart';
import 'package:doqto_app/data/models/network_profile.dart';
import 'package:doqto_app/state/network_state.dart';
import 'package:doqto_app/ui/screens/groups/create_group_flow_screen.dart';

/// Empty connections so the Invite step never touches IO.
class _FakeConnections extends ConnectionsNotifier {
  @override
  Future<List<PersonCard>> build() async => const [];
}

Widget _app() => ProviderScope(
      overrides: [connectionsProvider.overrideWith(_FakeConnections.new)],
      child: const MaterialApp(home: CreateGroupFlowScreen()),
    );

void main() {
  testWidgets('advances Identity → Access → Invite once a name is entered',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Step 1: Identity. Access-step content not yet shown.
    expect(find.text(Strings.groupsNameLabel), findsWidgets);
    expect(find.text(Strings.groupsVisibilityLabel), findsNothing);

    // "Next" is disabled with an empty name — tapping does nothing. (.last is
    // the visible label copy; .first is AppButton's invisible width-holder.)
    await tester.tap(find.text(Strings.groupsNext).last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text(Strings.groupsVisibilityLabel), findsNothing);

    // Enter a name → Next enabled → advance to Access.
    await tester.enterText(find.byType(TextField).first, 'Cardiology Leads');
    await tester.pumpAndSettle();
    await tester.tap(find.text(Strings.groupsNext).last);
    await tester.pumpAndSettle();
    expect(find.text(Strings.groupsVisibilityLabel), findsOneWidget);
    expect(find.text(Strings.groupsJoinPolicyLabel), findsOneWidget);

    // Advance to Invite (final step → CTA label flips to "Create group").
    await tester.tap(find.text(Strings.groupsNext).last);
    await tester.pumpAndSettle();
    expect(find.text(Strings.groupsInviteStepTitle), findsOneWidget);
    expect(find.text(Strings.groupsCreateCta), findsWidgets);
  });
}
