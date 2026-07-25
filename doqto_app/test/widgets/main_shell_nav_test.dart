import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:doqto_app/core/constants/strings.dart';
import 'package:doqto_app/data/models/conversation.dart';
import 'package:doqto_app/data/models/network_profile.dart';
import 'package:doqto_app/state/chat_state.dart';
import 'package:doqto_app/state/network_state.dart';
import 'package:doqto_app/ui/screens/home/main_shell.dart';

/// Empty-data fakes so the nav bar's badge providers never touch IO in tests.
class _FakeConvs extends ConversationsNotifier {
  @override
  Future<List<Conversation>> build() async => const [];
}

class _FakeInvites extends InvitationsNotifier {
  @override
  Future<List<Invitation>> build() async => const [];
}

GoRouter _router() => GoRouter(
      initialLocation: '/chats',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, s, shell) => MainShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/chats', builder: (_, s) => const Text('chats')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/network', builder: (_, s) => const Text('net')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/groups', builder: (_, s) => const Text('grp')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/my-org', builder: (_, s) => const Text('org')),
            ]),
          ],
        ),
      ],
    );

Widget _app() => ProviderScope(
      overrides: [
        conversationsProvider.overrideWith(_FakeConvs.new),
        invitationsProvider.overrideWith(_FakeInvites.new),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    );

Future<void> _pumpAt(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app());
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('4-tab bar renders without overflow at 360dp', (tester) async {
    await _pumpAt(tester, 360);
    // No RenderFlex overflow (or any other) surfaced during layout.
    expect(tester.takeException(), isNull);
    // All four tab labels present.
    expect(find.text(Strings.tabChats), findsOneWidget);
    expect(find.text(Strings.netTabNetwork), findsOneWidget);
    expect(find.text(Strings.netTabGroups), findsOneWidget);
    expect(find.text(Strings.tabMyOrg), findsOneWidget);
  });

  testWidgets('nav bar survives the 320dp safety-valve width', (tester) async {
    await _pumpAt(tester, 320);
    expect(tester.takeException(), isNull);
    expect(find.text(Strings.netTabNetwork), findsOneWidget);
  });

  testWidgets('tapping Network switches the active branch', (tester) async {
    await _pumpAt(tester, 390);
    expect(find.text('chats'), findsOneWidget);
    await tester.tap(find.text(Strings.netTabNetwork));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('net'), findsOneWidget);
  });
}
