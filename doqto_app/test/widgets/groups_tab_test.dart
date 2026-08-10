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
      overrides: [myGroupsProvider.overrideWith(_FakeMyGroups.new)],
      child: const MaterialApp(home: GroupsTabScreen()),
    );

void main() {
  testWidgets('renders my group rows with no discovery affordances',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Cardiology Leads'), findsOneWidget);
    expect(find.text('ICU Rounds'), findsOneWidget);

    // Groups are not browsable: no segmented control, no search.
    expect(find.byType(AppSegmented), findsNothing);
    expect(find.byType(AppSearchBar), findsNothing);
    expect(find.text(Strings.groupsDiscover), findsNothing);
  });
}
