import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:doqto_app/core/router/app_router.dart';

/// Mirrors the real router's shape: a tab shell with a visible footer, and
/// `/chat/:id` on the ROOT navigator above it — so a thread covers the tab
/// bar and can be opened from any tab or full-screen page.
final _rootKey = GlobalKey<NavigatorState>();
final _chatsKey = GlobalKey<NavigatorState>();
final _otherKey = GlobalKey<NavigatorState>();

const _footer = Text('FOOTER');

GoRouter _router() => GoRouter(
      navigatorKey: _rootKey,
      initialLocation: '/chats',
      routes: [
        GoRoute(
          path: '/groups/create',
          parentNavigatorKey: _rootKey,
          builder: (_, _) => Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  final r = GoRouter.of(context);
                  r.pop();
                  r.push('/groups/g1');
                },
                child: const Text('Create'),
              ),
            ),
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => Scaffold(
            body: shell,
            bottomNavigationBar: _footer,
          ),
          branches: [
            StatefulShellBranch(navigatorKey: _chatsKey, routes: [
              GoRoute(path: '/chats', builder: (_, _) => const Text('CHATS')),
            ]),
            StatefulShellBranch(navigatorKey: _otherKey, routes: [
              GoRoute(path: '/my-org', builder: (_, _) => const Text('MYORG')),
              GoRoute(path: '/groups', builder: (_, _) => const Text('GROUPS')),
              GoRoute(
                path: '/groups/:id',
                builder: (_, s) => Text('GROUP ${s.pathParameters['id']}'),
              ),
            ]),
          ],
        ),
        GoRoute(
          path: '/chat/:id',
          parentNavigatorKey: _rootKey,
          builder: (_, s) => Scaffold(body: Text('THREAD ${s.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/people/:id',
          parentNavigatorKey: _rootKey,
          builder: (_, _) => Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openConversation(context, 'c1'),
                child: const Text('Message'),
              ),
            ),
          ),
        ),
      ],
    );

void main() {
  testWidgets('an open thread covers the tab bar', (tester) async {
    final r = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    await tester.pumpAndSettle();
    expect(find.text('FOOTER'), findsOneWidget);

    openConversation(_chatsKey.currentContext!, 'c9');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('THREAD c9'), findsOneWidget);
    expect(find.text('FOOTER'), findsNothing);
  });

  testWidgets('opens the thread from a root-level page above the shell',
      (tester) async {
    final r = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    await tester.pumpAndSettle();

    r.push('/people/u1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Message'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('THREAD c1'), findsOneWidget);
  });

  testWidgets('opens the thread from another shell branch', (tester) async {
    final r = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    await tester.pumpAndSettle();

    r.go('/my-org');
    await tester.pumpAndSettle();
    openConversation(_otherKey.currentContext!, 'c2');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('THREAD c2'), findsOneWidget);
    expect(find.text('FOOTER'), findsNothing);
  });

  testWidgets('the create-group flow hides the tab bar and hands off to the '
      'branch detail', (tester) async {
    final r = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    await tester.pumpAndSettle();
    r.go('/groups');
    await tester.pumpAndSettle();

    r.push('/groups/create');
    await tester.pumpAndSettle();
    expect(find.text('FOOTER'), findsNothing);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('GROUP g1'), findsOneWidget);
    // The detail lives in the shell, so the tab bar comes back with it.
    expect(find.text('FOOTER'), findsOneWidget);
  });
}
