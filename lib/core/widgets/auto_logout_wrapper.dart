import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../router/app_router.dart';

/// Wraps the entire application to detect user inactivity.
/// Under HIPAA requirements, users must be automatically logged out after
/// a period of inactivity (typically 15 minutes).
class AutoLogoutWrapper extends ConsumerStatefulWidget {
  final Widget child;
  /// Duration of inactivity before force logout. Default is 15 minutes (900 seconds).
  final Duration timeoutDuration;

  const AutoLogoutWrapper({
    super.key,
    required this.child,
    this.timeoutDuration = const Duration(minutes: 15),
  });

  @override
  ConsumerState<AutoLogoutWrapper> createState() => _AutoLogoutWrapperState();
}

class _AutoLogoutWrapperState extends ConsumerState<AutoLogoutWrapper> {
  Timer? _authTimer;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  void _resetTimer() {
    // Cancel the existing timer if there is one
    if (_authTimer != null) {
      _authTimer!.cancel();
    }

    // Only run the timer if the user is authenticated
    if (SupabaseService.isAuthenticated) {
      _authTimer = Timer(widget.timeoutDuration, _logOutUser);
    }
  }

  Future<void> _logOutUser() async {
    // User has been idle for the timeout duration. Force logout.
    if (SupabaseService.isAuthenticated) {
      await SupabaseService.signOut();
      
      // We rely on the auth state listener in the app to naturally 
      // navigate the user back to the login screen, but we can also
      // force navigation if needed via the router.
      ref.read(routerProvider).go('/login');
    }
  }

  /// Handles any pointer/touch event on the screen to reset the activity timer
  void _handleUserInteraction([_]) {
    _resetTimer();
  }

  @override
  void dispose() {
    _authTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listener wraps the child to detect any touch event on the screen 
    // without consuming the event (behavior: HitTestBehavior.translucent)
    return Listener(
      onPointerDown: _handleUserInteraction,
      onPointerMove: _handleUserInteraction,
      onPointerUp: _handleUserInteraction,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
