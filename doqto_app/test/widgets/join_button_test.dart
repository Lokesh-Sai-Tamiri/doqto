import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/core/constants/strings.dart';
import 'package:doqto_app/core/enums/app_enums.dart';
import 'package:doqto_app/data/models/group.dart';
import 'package:doqto_app/ui/widgets/join_button.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('JoinButton per-policy matrix', () {
    testWidgets('member → Open chat', (tester) async {
      var opened = 0;
      await tester.pumpWidget(_wrap(JoinButton(
        joinPolicy: GroupJoinPolicy.open,
        membershipTag: GroupMembershipTag.member,
        onOpenChat: () => opened++,
      )));
      expect(find.text(Strings.groupsOpenChat), findsWidgets);
      await tester.tap(find.text(Strings.groupsOpenChat).first);
      expect(opened, 1);
    });

    testWidgets('requested → Requested (tap withdraws)', (tester) async {
      var withdrew = 0;
      await tester.pumpWidget(_wrap(JoinButton(
        joinPolicy: GroupJoinPolicy.request,
        membershipTag: GroupMembershipTag.requested,
        onWithdraw: () async => withdrew++,
      )));
      expect(find.text(Strings.groupRequested), findsWidgets);
      await tester.tap(find.text(Strings.groupRequested).first);
      await tester.pump();
      expect(withdrew, 1);
    });

    testWidgets('none + open → Join', (tester) async {
      var joined = 0;
      await tester.pumpWidget(_wrap(JoinButton(
        joinPolicy: GroupJoinPolicy.open,
        membershipTag: GroupMembershipTag.none,
        onJoin: () async => joined++,
      )));
      expect(find.text(Strings.groupJoin), findsWidgets);
      expect(find.text(Strings.groupRequestToJoin), findsNothing);
      await tester.tap(find.text(Strings.groupJoin).first);
      await tester.pump();
      expect(joined, 1);
    });

    testWidgets('none + request → Request to join', (tester) async {
      var requested = 0;
      await tester.pumpWidget(_wrap(JoinButton(
        joinPolicy: GroupJoinPolicy.request,
        membershipTag: GroupMembershipTag.none,
        onRequest: () async => requested++,
      )));
      expect(find.text(Strings.groupRequestToJoin), findsWidgets);
      expect(find.text(Strings.groupJoin), findsNothing);
      await tester.tap(find.text(Strings.groupRequestToJoin).first);
      await tester.pump();
      expect(requested, 1);
    });

    testWidgets('none + invite_only → no button, shows caption', (tester) async {
      await tester.pumpWidget(_wrap(const JoinButton(
        joinPolicy: GroupJoinPolicy.inviteOnly,
        membershipTag: GroupMembershipTag.none,
      )));
      expect(find.text(Strings.groupJoin), findsNothing);
      expect(find.text(Strings.groupRequestToJoin), findsNothing);
      expect(find.text(Strings.groupsInviteOnlyCaption), findsOneWidget);
    });

    testWidgets('null (redacted) policy → invite-only caption', (tester) async {
      await tester.pumpWidget(_wrap(const JoinButton(
        joinPolicy: null,
        membershipTag: GroupMembershipTag.none,
      )));
      expect(find.text(Strings.groupsInviteOnlyCaption), findsOneWidget);
    });
  });
}
