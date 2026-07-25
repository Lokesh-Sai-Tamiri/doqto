import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/core/constants/strings.dart';
import 'package:doqto_app/data/models/group.dart';
import 'package:doqto_app/state/groups_state.dart';
import 'package:doqto_app/ui/screens/groups/groups_tab_screen.dart';
import 'package:doqto_app/ui/widgets/app_segmented.dart';
import 'package:doqto_app/ui/widgets/search_bar.dart';

Group _member(String id, String name) => Group.fromJson({
      'id': id,
      'name': name,
      'visibility': 'public',
      'join_policy': 'open',
      'member_count': 5,
      'my_role': 'member',
      'my_state': 'active',
    });

/// Fake that skips the WS/Hive path and returns fixed member groups.
class _FakeMyGroups extends MyGroupsNotifier {
  @override
  Future<MyGroupsData> build() async => MyGroupsData(
        member: [_member('g1', 'Cardiology Leads'), _member('g2', 'ICU Rounds')],
      );
}

Widget _app() => ProviderScope(
      overrides: [
        myGroupsProvider.overrideWith(_FakeMyGroups.new),
        groupDiscoverProvider.overrideWith((ref, q) async => <Group>[]),
      ],
      child: const MaterialApp(home: GroupsTabScreen()),
    );

void main() {
  testWidgets('renders [My groups | Discover] segmented + my group rows',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Segmented control with both labels.
    expect(find.byType(AppSegmented), findsOneWidget);
    expect(find.text(Strings.groupsMyGroups), findsWidgets);
    expect(find.text(Strings.groupsDiscover), findsWidgets);

    // My groups list shows both member rows.
    expect(find.text('Cardiology Leads'), findsOneWidget);
    expect(find.text('ICU Rounds'), findsOneWidget);

    // No search bar on the My-groups segment.
    expect(find.byType(AppSearchBar), findsNothing);
  });

  testWidgets('tapping Discover swaps to the search + browse segment',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text(Strings.groupsDiscover).first);
    await tester.pumpAndSettle();

    // Discover segment surfaces the search bar; member rows are gone.
    expect(find.byType(AppSearchBar), findsOneWidget);
    expect(find.text('Cardiology Leads'), findsNothing);
    expect(find.text(Strings.groupsNoDiscover), findsOneWidget);
  });
}
