import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/message.dart';

enum DdpStatus { connecting, connected, disconnected, error }

class DdpClient {
  WebSocket? _ws;
  String _url = '';
  String _userId = '';
  String _authToken = '';
  String _sessionId = '';
  bool _connected = false;
  bool get isConnected => _connected;
  String get lastError => _lastError;
  String _lastError = '';
  int _callId = 0;
  int _subIdCounter = 0;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 10;
  bool _loginRetried = false;

  final Map<String, _RoomSub> _roomSubs = {};
  final Map<String, Completer> _pending = {};
  final List<void Function(DdpStatus)> _statusCallbacks = [];

  void connect(String wsUrl, String userId, String authToken) {
    if (_ws != null && wsUrl == _url && userId == _userId) return;
    disconnect();
    _url = wsUrl; _userId = userId; _authToken = authToken;
    _reconnectAttempts = 0;
    _loginRetried = false;
    _lastError = '';
    _doConnect();
  }

  void disconnect() {
    _connected = false;
    _loginRetried = false;
    _clearTimers();
    _roomSubs.clear();
    _pending.clear();
    try { _ws?.close(); } catch (_) {}
    _ws = null;
    _notifyStatus(DdpStatus.disconnected);
  }

  void subscribeRoom(String roomId, void Function(RCMessage) onMessage) {
    unsubscribeRoom(roomId);
    final subId = 'sub_${++_subIdCounter}';
    _roomSubs[roomId] = _RoomSub(subId: subId, callback: onMessage);
    if (_connected) {
      stdout.writeln('[DDP] Subscribing to $roomId (connected), subId=$subId');
      _sendSubscribe(roomId, subId);
    } else {
      stdout.writeln('[DDP] Queued subscription for $roomId (not connected yet), subId=$subId');
    }
  }

  void unsubscribeRoom(String roomId) {
    final sub = _roomSubs.remove(roomId);
    if (sub != null && _connected) {
      _send({'msg': 'unsub', 'id': sub.subId});
    }
  }

  void onStatus(void Function(DdpStatus) cb) => _statusCallbacks.add(cb);

  // ---- 内部 ----

  void _notifyStatus(DdpStatus s) {
    for (final cb in _statusCallbacks) cb(s);
  }

  Future<void> _doConnect() async {
    _notifyStatus(DdpStatus.connecting);
    stdout.writeln('[DDP] Connecting to $_url ...');
    try {
      _ws = await WebSocket.connect(_url);
      stdout.writeln('[DDP] WebSocket connected! Sending DDP connect...');

      // 发送 DDP connect 消息
      _send({'msg': 'connect', 'version': '1', 'support': ['1', 'pre2', 'pre1']});

      // 监听消息
      _ws!.listen(
        (data) {
          if (data is String) {
            _onMessage(data);
          }
        },
        onError: (err) {
          stdout.writeln('[DDP] WebSocket error: $err');
          _onClose();
        },
        onDone: () {
          stdout.writeln('[DDP] WebSocket closed');
          _onClose();
        },
        cancelOnError: false,
      );
    } catch (e) {
      stdout.writeln('[DDP] WebSocket connect failed: $e');
      _lastError = e.toString();
      _notifyStatus(DdpStatus.error);
      _scheduleReconnect();
    }
  }

  void _onClose() {
    if (!_connected) {
      // 没成功连接过，尝试重连
      _ws = null;
      _scheduleReconnect();
      return;
    }
    _connected = false;
    _pending.clear();
    _clearTimers();
    _ws = null;
    _notifyStatus(DdpStatus.disconnected);
    _scheduleReconnect();
  }

  void _onMessage(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final msgType = data['msg'] as String? ?? '?';
      switch (msgType) {
        case 'connected':
          _sessionId = data['session'] ?? '';
          stdout.writeln('[DDP] Server connected, session=$_sessionId, logging in...');
          _login();
          break;
        case 'result':
          _handleResult(data);
          break;
        case 'ready':
          stdout.writeln('[DDP] Subscription ready: ${data['subs']}');
          break;
        case 'changed':
          _handleChanged(data);
          break;
        case 'ping':
          _send({'msg': 'pong'});
          break;
        case 'pong':
          // heartbeat ack
          break;
        case 'nosub':
          stdout.writeln('[DDP] No subscription for: ${data['id']}');
          break;
        default:
          stdout.writeln('[DDP] Unknown msg type: $msgType');
      }
    } catch (e) {
      stdout.writeln('[DDP] Parse error: $e');
    }
  }

  void _login() {
    stdout.writeln('[DDP] Sending login with resume token (len=${_authToken.length})...');
    _send({
      'msg': 'method',
      'method': 'login',
      'params': [
        {'resume': _authToken}
      ],
      'id': _nextCallId(),
    });
  }

  void _handleResult(Map<String, dynamic> data) {
    final id = data['id'] as String?;
    if (id != null && _pending.containsKey(id)) {
      final c = _pending.remove(id)!;
      if (data['error'] != null) c.completeError(data['error']);
      else c.complete(data['result']);
      return;
    }
    // login result
    final result = data['result'];
    if (result is Map && result['id'] != null) {
      stdout.writeln('[DDP] Login success, userId=${result['id']}, connected!');
      _connected = true;
      _loginRetried = false;
      _lastError = '';
      _notifyStatus(DdpStatus.connected);
      _resubscribeAll();
      _startPing();
    } else if (data['error'] != null) {
      stdout.writeln('[DDP] Login failed: ${data['error']}');
      if (!_loginRetried) {
        _loginRetried = true;
        stdout.writeln('[DDP] Retrying login with accessToken...');
        _send({
          'msg': 'method',
          'method': 'login',
          'params': [
            {'accessToken': _authToken}
          ],
          'id': _nextCallId(),
        });
      } else {
        _lastError = 'DDP login failed: ${data['error']}';
        stdout.writeln('[DDP] Both login attempts failed: $_lastError');
        _notifyStatus(DdpStatus.error);
        _ws?.close();
      }
    } else {
      stdout.writeln('[DDP] Unhandled result: $data');
      _lastError = 'Unexpected login response';
    }
  }

  void _handleChanged(Map<String, dynamic> data) {
    if (data['collection'] != 'stream-room-messages') {
      if (data['collection'] != null) stdout.writeln('[DDP] Changed: ${data['collection']}');
      return;
    }
    final fields = data['fields'];
    if (fields == null || fields['args'] == null) return;
    final args = fields['args'] as List;
    stdout.writeln('[DDP] Received ${args.length} message(s)');
    for (final msgPayload in args) {
      if (msgPayload is! Map) continue;
      final roomId = msgPayload['rid'] as String?;
      if (roomId == null) continue;
      final sub = _roomSubs[roomId];
      if (sub == null) {
        stdout.writeln('[DDP] No sub for $roomId, have: ${_roomSubs.keys.join(",")}');
        continue;
      }

      final rcMsg = RCMessage(
        id: msgPayload['_id'] ?? '',
        rid: msgPayload['rid'] ?? '',
        msg: msgPayload['msg'] ?? '',
        ts: _parseTs(msgPayload['ts']),
        u: MsgSender(
          id: msgPayload['u']?['_id'] ?? '',
          username: msgPayload['u']?['username'] ?? 'unknown',
          name: msgPayload['u']?['name'],
        ),
        type: msgPayload['t'],
        attachments: (msgPayload['attachments'] as List?)
                ?.map((e) => RCAttachment.fromJson(e as Map<String, dynamic>))
                ?.toList() ??
            [],
      );
      sub.callback(rcMsg);
    }
  }

  void _sendSubscribe(String roomId, String subId) {
    stdout.writeln('[DDP] Sending subscribe: room=$roomId');
    _send({
      'msg': 'sub',
      'id': subId,
      'name': 'stream-room-messages',
      'params': [roomId, false]
    });
  }

  void _resubscribeAll() {
    stdout.writeln('[DDP] Resubscribing ${_roomSubs.length} rooms: ${_roomSubs.keys.join(",")}');
    for (final entry in _roomSubs.entries) {
      _sendSubscribe(entry.key, entry.value.subId);
    }
  }

  void _send(Map<String, dynamic> data) {
    try {
      _ws?.add(jsonEncode(data));
    } catch (e) {
      stdout.writeln('[DDP] Send error: $e');
    }
  }

  /// 解析 Rocket.Chat DDP 消息中的 ts 字段，支持多种格式：
  /// - int: 毫秒时间戳
  /// - String: ISO 8601 或毫秒数字符串
  /// - Map: {"$date": int/String}
  String _parseTs(dynamic ts) {
    if (ts == null) return DateTime.now().toIso8601String();
    if (ts is int) {
      return DateTime.fromMillisecondsSinceEpoch(ts).toIso8601String();
    }
    if (ts is String) {
      final dt = DateTime.tryParse(ts);
      if (dt != null) return dt.toIso8601String();
      // 可能是纯数字毫秒戳字符串
      final ms = int.tryParse(ts);
      if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String();
      return DateTime.now().toIso8601String();
    }
    if (ts is Map) {
      final date = ts['\$date'];
      if (date is int) return DateTime.fromMillisecondsSinceEpoch(date).toIso8601String();
      if (date is String) {
        final dt = DateTime.tryParse(date);
        if (dt != null) return dt.toIso8601String();
        final ms = int.tryParse(date);
        if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String();
      }
    }
    return DateTime.now().toIso8601String();
  }

  String _nextCallId() => '${++_callId}';

  void _startPing() {
    _pingTimer?.cancel();
    // 每 20 秒发送一次心跳，低于 Rocket.Chat 默认 25s 超时
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _send({'msg': 'ping'});
    });
  }

  void _clearTimers() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _lastError = 'DDP reconnect max attempts reached';
      return;
    }
    final base = 1000;
    final shift = 1 << _reconnectAttempts;
    final ms = (base * shift).clamp(1000, 30000);
    _reconnectAttempts++;
    stdout.writeln('[DDP] Scheduling reconnect in ${ms}ms (attempt $_reconnectAttempts)');
    _reconnectTimer = Timer(Duration(milliseconds: ms), _doConnect);
  }
}

class _RoomSub {
  final String subId;
  final void Function(RCMessage) callback;
  _RoomSub({required this.subId, required this.callback});
}
