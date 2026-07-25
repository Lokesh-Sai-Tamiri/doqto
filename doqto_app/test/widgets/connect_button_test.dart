import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/core/di/providers.dart';
import 'package:doqto_app/data/api/api_client.dart';
import 'package:doqto_app/data/models/network_profile.dart';
import 'package:doqto_app/data/repositories/network_repository.dart';
import 'package:doqto_app/ui/widgets/connect_button.dart';

/// A repo whose `sendInvitation` is controlled by a [Completer] so a test can
/// observe the optimistic flip while the future is in flight, then fail it.
class _FakeNetworkRepository extends NetworkRepository {
  final Completer<Invitation> inviteCompleter = Completer<Invitation>();

  _FakeNetworkRepository() : super(ApiClient());

  @override
  Future<NetworkProfile> getProfile(String userId) async =>
      NetworkProfile.fromJson({
        'id': userId,
        'full_name': 'Dr. Test Subject',
        'connection_state': 'none',
        'degree': 'out',
        'can_message': 'open',
      });

  @override
  Future<Invitation> sendInvitation(String recipientId, {String? message}) =>
      inviteCompleter.future;
}

Widget _app(_FakeNetworkRepository fake) => ProviderScope(
      overrides: [networkRepositoryProvider.overrideWithValue(fake)],
      child: const MaterialApp(
        home: Scaffold(body: ConnectButton(userId: 'u1')),
      ),
    );

void main() {
  testWidgets('optimistically flips Connect → Pending, rolls back on failure',
      (tester) async {
    final fake = _FakeNetworkRepository();
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle(); // relationshipProvider loads the profile

    // AppButton keeps an invisible width-holder copy of the label, so the text
    // appears twice when idle; use findsWidgets / .first accordingly.
    expect(find.text('Connect'), findsWidgets);

    // Tap → optimistic flip to the pending visual while the future is pending.
    await tester.tap(find.text('Connect').first);
    await tester.pump(); // start the crossfade
    await tester.pump(const Duration(milliseconds: 250)); // settle the switcher
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('Connect'), findsNothing);

    // Fail the in-flight invite → both the notifier state and the button's
    // local optimism roll back to Connect.
    fake.inviteCompleter.completeError(ApiException('boom'));
    await tester.pumpAndSettle();

    expect(find.text('Connect'), findsWidgets);
    expect(find.text('Pending'), findsNothing);
  });

  testWidgets('successful invite settles on Pending', (tester) async {
    final fake = _FakeNetworkRepository();
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect').first);
    await tester.pump();

    fake.inviteCompleter.complete(Invitation.fromJson({
      'id': 'i1',
      'recipient_id': 'u1',
      'status': 'pending',
    }));
    await tester.pumpAndSettle();

    // Notifier flipped connection_state to pending_outgoing → Pending sticks.
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('Connect'), findsNothing);
  });
}
