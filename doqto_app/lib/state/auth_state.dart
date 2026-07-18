import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/providers.dart';
import '../core/enums/app_enums.dart';
import '../data/models/user.dart';
import 'org_state.dart';

enum AuthStage {
  unknown,
  signedOut,
  needsRegistration,
  needsOrg,
  pendingVerification,
  signedIn,
}

class AuthState {
  final AuthStage stage;
  final User? user;
  const AuthState(this.stage, this.user);

  AuthState copyWith({AuthStage? stage, User? user}) =>
      AuthState(stage ?? this.stage, user ?? this.user);
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // When the API client detects the session is unrecoverable (refresh
    // token expired, revoked, or backend returns session_revoked), drop
    // straight to signedOut. The router redirect fires automatically.
    ref.read(apiClientProvider).onSessionEnded = _onSessionEnded;
    return const AuthState(AuthStage.unknown, null);
  }

  void _onSessionEnded() {
    // Runs on the interceptor's future — mutate state on the next tick to
    // avoid reassigning while a build may be in flight.
    Future.microtask(() {
      state = const AuthState(AuthStage.signedOut, null);
    });
  }

  Future<void> bootstrap() async {
    final tokens = ref.read(tokenStorageProvider);
    final access = await tokens.accessToken;
    final refresh = await tokens.refreshToken;
    if ((access == null || access.isEmpty) &&
        (refresh == null || refresh.isEmpty)) {
      state = const AuthState(AuthStage.signedOut, null);
      return;
    }
    try {
      // `/users/me` goes through the Dio interceptor: if `access` is expired
      // but `refresh` is still valid, the interceptor silently refreshes and
      // the call succeeds. If both are dead, we'll catch below.
      final me = await ref.read(authRepositoryProvider).me();
      final registered = me.fullName.isNotEmpty && !me.npiNumber.startsWith('PENDING');
      if (!registered) {
        state = AuthState(AuthStage.needsRegistration, me);
        return;
      }
      state = AuthState(await _resolveStageForRegisteredUser(), me);
    } catch (_) {
      await tokens.clear();
      state = const AuthState(AuthStage.signedOut, null);
    }
  }

  /// For a fully-registered user, decide if they need onboarding (no orgs)
  /// or can go straight to chats. Also hydrates [orgProvider] as a side effect
  /// so downstream screens have the active org available.
  Future<AuthStage> _resolveStageForRegisteredUser() async {
    try {
      final orgs = await ref.read(orgRepositoryProvider).listMine();
      if (orgs.isEmpty) return AuthStage.needsOrg;
      // Pick the most recently created org as "current". Users with multiple
      // orgs can switch in a later release.
      final org = orgs.first;
      ref.read(orgProvider.notifier).setCurrent(org);
      final stage = switch (org.status) {
        OrgStatus.active => AuthStage.signedIn,
        OrgStatus.pending || OrgStatus.suspended => AuthStage.pendingVerification,
      };
      if (stage == AuthStage.signedIn) await _connectWs(org.id);
      return stage;
    } catch (_) {
      // If we can't reach the backend right now, assume needs-org so the user
      // isn't stuck on a broken chats screen.
      return AuthStage.needsOrg;
    }
  }

  /// Re-fetches `/orgs/mine` and flips auth stage between `pendingVerification`
  /// and `signedIn` based on the freshest org status. Called by the pending
  /// screen on its timer tick and on the "Check verification" button.
  Future<void> refreshOrgStatus() async {
    final user = state.user;
    if (user == null) return;
    final nextStage = await _resolveStageForRegisteredUser();
    state = AuthState(nextStage, user);
  }

  /// Open the realtime socket for the signed-in user's org. Drives instant
  /// message delivery, read receipts, and typing indicators.
  Future<void> _connectWs(String orgId) async {
    // Token is read per reconnect attempt, so a token refreshed by the Dio
    // interceptor is picked up automatically instead of fail-looping.
    await ref.read(websocketClientProvider).connect(
          orgId: orgId,
          tokenProvider: () => ref.read(tokenStorageProvider).accessToken,
        );
  }

  Future<void> requestOtp(String phone) async {
    await ref.read(authRepositoryProvider).requestOtp(phone);
  }

  Future<void> verifyOtp({required String phone, required String code}) async {
    final pair = await ref.read(authRepositoryProvider).verifyOtp(phone: phone, code: code);
    final me = await ref.read(authRepositoryProvider).me();
    if (!pair.isRegistered) {
      state = AuthState(AuthStage.needsRegistration, me);
      return;
    }
    state = AuthState(await _resolveStageForRegisteredUser(), me);
  }

  Future<void> completeRegistration({
    required String fullName,
    String? specialty,
    required String npiNumber,
  }) async {
    final user = await ref.read(authRepositoryProvider).register(
          fullName: fullName,
          specialty: specialty,
          npiNumber: npiNumber,
        );
    // After registration the user has no org yet → send them to org selection.
    state = AuthState(AuthStage.needsOrg, user);
  }

  /// Replace the cached user (e.g. after a profile update). Keeps the current
  /// auth stage — callers can't change auth stage via this method.
  void setUser(User user) {
    state = state.copyWith(user: user);
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).logout();
    await ref.read(websocketClientProvider).close();
    ref.read(orgProvider.notifier).clear();
    state = const AuthState(AuthStage.signedOut, null);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
