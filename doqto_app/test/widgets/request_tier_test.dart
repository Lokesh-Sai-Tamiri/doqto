import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doqto_app/core/constants/strings.dart';
import 'package:doqto_app/core/di/providers.dart';
import 'package:doqto_app/data/api/api_client.dart';
import 'package:doqto_app/data/models/network_profile.dart';
import 'package:doqto_app/data/repositories/network_repository.dart';
import 'package:doqto_app/ui/widgets/request_card.dart';
import 'package:doqto_app/ui/widgets/request_composer_bar.dart';

/// Minimal network repo returning a not-connected stranger (can_message
/// 'request', not 'open') so ConnectButton renders its "Connect" state —
/// an openly-messageable colleague would render "Message" instead.
class _FakeNetworkRepository extends NetworkRepository {
  _FakeNetworkRepository() : super(ApiClient());

  @override
  Future<NetworkProfile> getProfile(String userId) async =>
      NetworkProfile.fromJson({
        'id': userId,
        'full_name': 'Dr. Other',
        'connection_state': 'none',
        'degree': 'out',
        'can_message': 'request',
      });
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: Scaffold(body: child)),
    );

const _composerKey = Key('test-composer');
const _composer = SizedBox(key: _composerKey, height: 44);

RequestComposerBar _bar({
  bool isRecipientPending = false,
  bool isInitiatorBeforeFirst = false,
  bool composerLocked = false,
  bool isDeclined = false,
  bool showNotConnected = false,
  String? otherId,
}) =>
    RequestComposerBar(
      isRecipientPending: isRecipientPending,
      isInitiatorBeforeFirst: isInitiatorBeforeFirst,
      composerLocked: composerLocked,
      isDeclined: isDeclined,
      showNotConnected: showNotConnected,
      otherId: otherId,
      otherName: 'Dr. Other',
      busy: false,
      onAccept: () {},
      onDelete: () {},
      onBlock: (_) {},
      onDismissNotConnected: () {},
      composer: _composer,
    );

void main() {
  group('RequestCard', () {
    testWidgets('renders name + preview and fires accept', (tester) async {
      var accepted = false;
      await tester.pumpWidget(_wrap(RequestCard(
        name: 'Dr. Grey',
        initials: 'DG',
        messagePreview: 'Hi, quick question about a case.',
        onAccept: () => accepted = true,
        onDelete: () {},
        onBlock: () {},
      )));

      expect(find.text('Dr. Grey'), findsOneWidget);
      expect(find.text('Hi, quick question about a case.'), findsOneWidget);
      // Delete / Block / Accept action row.
      expect(find.text(Strings.netAccept), findsWidgets);
      expect(find.text(Strings.netDelete), findsWidgets);
      expect(find.text(Strings.netBlock), findsWidgets);

      // Second (visible) copy — AppButton keeps an invisible width-holder first.
      await tester.tap(find.text(Strings.netAccept).last);
      expect(accepted, isTrue);
    });
  });

  group('RequestComposerBar state matrix', () {
    testWidgets('recipient-pending → action bar + composer visible',
        (tester) async {
      await tester.pumpWidget(_wrap(
        _bar(isRecipientPending: true, otherId: 'u1'),
      ));
      expect(find.text(Strings.netRequestBannerRecipient), findsOneWidget);
      expect(find.text(Strings.netAccept), findsWidgets);
      expect(find.text(Strings.netBlock), findsWidgets);
      // Composer stays available — a reply auto-accepts.
      expect(find.byKey(_composerKey), findsOneWidget);
    });

    testWidgets('initiator-waiting → locked bar, composer hidden',
        (tester) async {
      await tester.pumpWidget(_wrap(
        _bar(composerLocked: true, isDeclined: false),
      ));
      expect(find.text(Strings.netRequestWaiting), findsOneWidget);
      expect(find.byKey(_composerKey), findsNothing);
    });

    testWidgets('declined → terminal locked bar, composer hidden',
        (tester) async {
      await tester.pumpWidget(_wrap(
        _bar(composerLocked: true, isDeclined: true),
      ));
      expect(find.text(Strings.netRequestDeclinedTerminal), findsOneWidget);
      expect(find.byKey(_composerKey), findsNothing);
    });

    testWidgets('non-connected open → Connect banner + composer visible',
        (tester) async {
      await tester.pumpWidget(_wrap(
        _bar(showNotConnected: true, otherId: 'u1'),
        overrides: [
          networkRepositoryProvider
              .overrideWithValue(_FakeNetworkRepository()),
        ],
      ));
      await tester.pumpAndSettle(); // relationshipProvider loads the profile

      expect(find.text(Strings.netNotConnectedWith('Dr. Other')),
          findsOneWidget);
      expect(find.text(Strings.netConnect), findsWidgets);
      expect(find.byKey(_composerKey), findsOneWidget);
    });
  });
}
