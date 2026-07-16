import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/constants/api_routes.dart';
import '../../core/constants/app_constants.dart';
import '../../core/enums/app_enums.dart';

class WsEvent {
  final WsEventServer type;
  final Map<String, dynamic> data;
  WsEvent(this.type, this.data);
}

class WebsocketClient {
  WebSocketChannel? _channel;
  Timer? _heartbeat;
  final _events = StreamController<WsEvent>.broadcast();
  bool _intentionallyClosed = false;
  String? _orgId;
  String? _token;

  Stream<WsEvent> get events => _events.stream;

  void connect({required String orgId, required String token}) {
    _intentionallyClosed = false;
    _orgId = orgId;
    _token = token;
    final uri = Uri.parse('${AppConstants.wsBaseUrl}${ApiRoutes.wsOrg(orgId)}?token=$token');
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;

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
    if (_orgId == null || _token == null) return;
    Timer(AppConstants.wsReconnectBackoff, () {
      if (_intentionallyClosed) return;
      connect(orgId: _orgId!, token: _token!);
    });
  }

  Future<void> close() async {
    _intentionallyClosed = true;
    _heartbeat?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await close();
    await _events.close();
  }
}
