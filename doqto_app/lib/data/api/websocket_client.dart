import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/constants/api_routes.dart';
import '../../core/constants/app_constants.dart';
import '../../core/enums/app_enums.dart';

class WsEvent {
  final WsEventServer type;
  final Map<String, dynamic> data;
  WsEvent(this.type, this.data);
}

/// Client-side socket lifecycle — drives the "Connecting…" banner and
/// reconnect gap recovery.
enum WsConnState { connecting, connected, disconnected }

class WebsocketClient {
  WebSocketChannel? _channel;
  Timer? _heartbeat;
  Timer? _reconnect;
  final _events = StreamController<WsEvent>.broadcast();
  final _states = StreamController<WsConnState>.broadcast();
  WsConnState _state = WsConnState.disconnected;
  bool _intentionallyClosed = false;
  int _attempts = 0;
  String? _orgId;
  Future<String?> Function()? _tokenProvider;

  Stream<WsEvent> get events => _events.stream;
  Stream<WsConnState> get states => _states.stream;
  WsConnState get state => _state;

  void _setState(WsConnState s) {
    if (s == _state) return;
    _state = s;
    _states.add(s);
  }

  /// [tokenProvider] is called on every (re)connect so a refreshed access
  /// token is picked up instead of looping on an expired one.
  Future<void> connect({
    required String orgId,
    required Future<String?> Function() tokenProvider,
  }) async {
    _intentionallyClosed = false;
    _orgId = orgId;
    _tokenProvider = tokenProvider;
    await _open();
  }

  Future<void> _open() async {
    final orgId = _orgId;
    final token = await _tokenProvider?.call();
    if (orgId == null || token == null || token.isEmpty) return;
    _setState(WsConnState.connecting);

    // Token goes in a first `auth` frame, not the URL (query strings get
    // logged by proxies).
    final uri = Uri.parse('${AppConstants.wsBaseUrl}${ApiRoutes.wsOrg(orgId)}');
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;

    try {
      await channel.ready;
      channel.sink.add(jsonEncode({'type': 'auth', 'token': token}));
    } catch (_) {
      if (!_intentionallyClosed) _scheduleReconnect();
      return;
    }
    _attempts = 0;
    _setState(WsConnState.connected);

    channel.stream.listen(
      (data) {
        try {
          final decoded = jsonDecode(data as String) as Map<String, dynamic>;
          final type = WsEventServer.fromWire(decoded['type'] as String);
          if (type != null) {
            _events.add(WsEvent(type, (decoded['data'] ?? {}) as Map<String, dynamic>));
          }
        } catch (_) {}
      },
      onDone: () {
        if (!_intentionallyClosed) _scheduleReconnect();
      },
      onError: (_) {
        if (!_intentionallyClosed) _scheduleReconnect();
      },
      cancelOnError: true,
    );

    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(AppConstants.wsHeartbeatInterval, (_) {
      try {
        channel.sink.add(jsonEncode({'type': WsEventClient.heartbeat.wire}));
      } catch (_) {}
    });
  }

  /// Fire-and-forget client → server message (typing, heartbeat, …).
  void send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (_orgId == null || _tokenProvider == null) return;
    _setState(WsConnState.disconnected);
    _heartbeat?.cancel();
    // Exponential backoff with jitter: 1s, 2s, 4s … capped at 30s.
    final capped = min(
      AppConstants.wsReconnectMaxBackoff.inMilliseconds,
      AppConstants.wsReconnectBaseBackoff.inMilliseconds * (1 << min(_attempts, 10)),
    );
    final delay = Duration(milliseconds: capped ~/ 2 + Random().nextInt(capped ~/ 2 + 1));
    _attempts++;
    _reconnect?.cancel();
    _reconnect = Timer(delay, () {
      if (_intentionallyClosed) return;
      _open();
    });
  }

  Future<void> close() async {
    _intentionallyClosed = true;
    _heartbeat?.cancel();
    _reconnect?.cancel();
    _setState(WsConnState.disconnected);
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await close();
    await _events.close();
    await _states.close();
  }
}
