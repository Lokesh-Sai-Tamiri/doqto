// On-device check of message edit/delete against a live local backend.
//
// Run (backend on :8010, users/org/DM prepared, see scratchpad/setup_sim.py):
//   flutter test integration_test/message_edit_delete_test.dart -d <sim> \
//     --dart-define=API_BASE_URL=http://localhost:8010 \
//     --dart-define=WS_BASE_URL=ws://localhost:8010 \
//     --dart-define=CONV_ID=<conversation uuid>
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:doqto_app/core/constants/strings.dart';
import 'package:doqto_app/core/router/app_router.dart';
import 'package:doqto_app/main.dart' as app;
import 'package:doqto_app/state/auth_state.dart';
import 'package:doqto_app/ui/widgets/message_bubble.dart';

const _conv = String.fromEnvironment('CONV_ID');

Future<void> _settle(WidgetTester t, [int ms = 1500]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // A route pushed mid-press (the long-press sheet) makes Navigator cancel the
  // pointer as a *device* event; without this the live binding drops it and
  // the bubble's long-press recognizer never resets.
  binding.shouldPropagateDevicePointerEvents = true;

  testWidgets('edit shows history, delete shows tombstone', (tester) async {
    expect(_conv, isNotEmpty, reason: 'pass --dart-define=CONV_ID');
    await app.main();
    await _settle(tester);

    final container =
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    await container
        .read(authProvider.notifier)
        .verifyOtp(phone: '+15550000101', code: '777777');
    await _settle(tester);
    expect(container.read(authProvider).stage, AuthStage.signedIn);

    container.read(routerProvider).go(AppRoutes.chat(_conv));
    await _settle(tester, 2500);

    final unique = 'sim ${DateTime.now().millisecondsSinceEpoch}';
    final composer = find.widgetWithText(TextField, Strings.chatMessageHint);
    expect(composer, findsOneWidget);
    await tester.enterText(composer, unique);
    await _settle(tester, 300);
    await tester.tap(find.byKey(const ValueKey('composer-send')));
    await _settle(tester, 2500);
    expect(find.text(unique), findsOneWidget);

    // Edit
    await tester.longPress(find.text(unique));
    await _settle(tester);
    await tester.tap(find.text(Strings.chatEditMessage));
    await _settle(tester);
    expect(find.text(Strings.chatEditingMessage), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '$unique edited');
    await _settle(tester, 300);
    await tester.tap(find.byKey(const ValueKey('composer-send')));
    await _settle(tester, 2500);
    expect(find.text('$unique edited'), findsOneWidget);
    // Scope to THIS bubble: earlier runs leave edited messages in the thread.
    final editedLabel = find.descendant(
      of: find.ancestor(
          of: find.text('$unique edited'), matching: find.byType(MessageBubble)),
      matching: find.text(Strings.chatEdited),
    );
    expect(editedLabel, findsOneWidget);

    // History sheet lists the original
    await tester.tap(editedLabel);
    await _settle(tester, 2500);
    expect(find.text(Strings.chatEditHistory), findsOneWidget);
    expect(find.text(unique), findsOneWidget);
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.tapAt(Offset(size.width / 2, 120)); // barrier → dismiss
    await _settle(tester, 2000);
    expect(find.text(Strings.chatEditHistory), findsNothing);

    // Delete
    await tester.longPress(find.text('$unique edited'));
    await _settle(tester);
    await tester.tap(find.text(Strings.chatDeleteMessage));
    await _settle(tester, 2500);
    expect(find.text(Strings.chatMessageDeleted), findsWidgets);
    expect(find.text('$unique edited'), findsNothing);
    await _settle(tester, 4000); // hold for a screenshot from the shell
  });
}
