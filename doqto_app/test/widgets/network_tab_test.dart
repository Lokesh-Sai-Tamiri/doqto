import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:doqto_app/core/router/app_router.dart';
import 'package:doqto_app/data/models/network_profile.dart';
import 'package:doqto_app/state/network_state.dart';
import 'package:doqto_app/ui/screens/network/network_tab_screen.dart';

/// No received invitations and no connections — the state a doctor is in right
/// after sending their first request.
class _NoInvitations extends InvitationsNotifier {
  @override
  Future<List<Invitation>> build() async => const [];
}

class _NoConnections extends ConnectionsNotifier {
  @override
  Future<List<PersonCard>> build() async => const [];
}

String? lastRoute;

Widget _app() => ProviderScope(
      overrides: [
        invitationsProvider.overrideWith(_NoInvitations.new),
        connectionsProvider.overrideWith(_NoConnections.new),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/network',
          routes: [
            GoRoute(
              path: '/network',
              builder: (_, _) => const NetworkTabScreen(),
            ),
            GoRoute(
              path: AppRoutes.networkInvitations,
              builder: (_, _) {
                lastRoute = AppRoutes.networkInvitations;
                return const Scaffold(body: Text('INBOX'));
              },
            ),
            GoRoute(
              path: AppRoutes.peopleSearch,
              builder: (_, _) => const Scaffold(body: Text('SEARCH')),
            ),
          ],
        ),
      ),
    );

void main() {
  testWidgets('the invitations inbox is reachable with zero received requests',
      (tester) async {
    lastRoute = null;
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Sent requests live in that inbox; without this entry they were
    // unreachable and could never be withdrawn.
    final action = find.byIcon(Icons.person_add_alt_1_outlined);
    expect(action, findsOneWidget);

    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('INBOX'), findsOneWidget);
    expect(lastRoute, AppRoutes.networkInvitations);
  });
}
