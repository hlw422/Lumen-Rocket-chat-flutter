import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/message.dart';

enum DdpStatus { connecting, connected, disconnected, error }

class DdpClient {
  WebSocketChannel? _channel;
  String _url = '';
  String _userId = '';
  String _authToken = '';
  String _sessionId = '';
  bool _connected = false;
  bool get isConnected => _connected;
  int _callId = 0;
  int _subIdCounter = 0;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 10;
  final int _initialReconnectDelay = 1000;

  final Map<String, _RoomSub> _roomSubs = {};
  final Map<String, Completer> _pending = {};
  final List<void Function(DdpStatus)> _statusCallbacks = [];

  void connect(String wsUrl, String userId, String authToken) {
    if (wsUrl == _url && userId == _userId && _channel != null) return;
    disconnect();
    _url = wsUrl; _userId = userId; _authToken = authToken;
    _reconnectAttempts = 0;
    _doConnect();
  }

  void disconnect() {
    _connected = false;
    _loginRetried = false;
    _clearTimers();
    _roomSubs.clear();
    _pending.clear();
    _channel?.sink.close();
    _channel = null;
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
      _send({'msg':'unsub','id':sub.subId});
    }
  }

  void onStatus(void Function(DdpStatus) cb) => _statusCallbacks.add(cb);

  // ---- 内部 ----

  void _notifyStatus(DdpStatus s) {
    for (final cb in _statusCallbacks) cb(s);
  }

  void _doConnect() {
    _notifyStatus(DdpStatus.connecting);
    stdout.writeln('[DDP] Connecting to $_url ...');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_url));
      stdout.writeln('[DDP] WebSocket connected, sending DDP connect...');
      _channel!.stream.listen(
        (data) => _onMessage(data as String),
        onError: (err) {
          stdout.writeln('[DDP] WebSocket stream error: reconnecting...');
          _notifyStatus(DdpStatus.error);
          _scheduleReconnect();
        },
        onDone: () => _onClose(),
      );
    } catch (e) {
      stdout.writeln('[DDP] WebSocket connect failed: $e, reconnecting...');
      _notifyStatus(DdpStatus.error);
      _scheduleReconnect();
    }
    // 等待连接建立后握手
    // WebSocketChannel.connect 返回的是已连接的流，直接发送 connect
    Future.delayed(const Duration(milliseconds: 100), () {
      _send({'msg':'connect','version':'1','support':['1','pre2','pre1']});
    });
  }

  void _onClose() {
    _connected = false;
    _pending.clear();
    _clearTimers();
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _notifyStatus(DdpStatus.disconnected);
      _scheduleReconnect();
    } else {
      _notifyStatus(DdpStatus.disconnected);
    }
  }

  void _onMessage(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final msgType = data['msg'] as String? ?? '?';
      switch (msgType) {
        case 'connected':
          _sessionId = data['session']??'';
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
          _send({'msg':'pong'});
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

  bool _loginRetried = false;

  void _login() {
    stdout.writeln('[DDP] Sending login with resume token (length=${_authToken.length})...');
    _send({'msg':'method','method':'login','params':[{'resume':_authToken}],'id':_nextCallId()});
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
      _notifyStatus(DdpStatus.connected);
      _resubscribeAll();
      _startPing();
    } else if (data['error'] != null) {
      stdout.writeln('[DDP] Login failed: ${data['error']}');
      // 尝试用 accessToken 格式重试一次
      if (!_loginRetried) {
        _loginRetried = true;
        stdout.writeln('[DDP] Retrying login with accessToken format...');
        _send({'msg':'method','method':'login','params':[{'accessToken':_authToken}],'id':_nextCallId()});
      } else {
        stdout.writeln('[DDP] Both login attempts failed');
        _notifyStatus(DdpStatus.error);
      }
    } else {
      stdout.writeln('[DDP] Unhandled result: $data');
    }
  }

  void _handleChanged(Map<String, dynamic> data) {
    if (data['collection'] != 'stream-room-messages') {
      if (data['collection'] != null) stdout.writeln('[DDP] Changed for ${data['collection']}, ignoring');
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
        stdout.writeln('[DDP] No subscriber for room $roomId (current subs: ${_roomSubs.keys.join(",")})');
        continue;
      }

      final rcMsg = RCMessage(
        id: msgPayload['_id']??'',
        rid: msgPayload['rid']??'',
        msg: msgPayload['msg']??'',
        ts: msgPayload['ts'] is Map
          ? DateTime.tryParse(msgPayload['ts']['\$date'] as String? ?? '')?.toIso8601String() ?? DateTime.now().toIso8601String()
          : (msgPayload['ts'] as String? ?? DateTime.now().toIso8601String()),
        u: MsgSender(
          id: msgPayload['u']?['_id']??'',
          username: msgPayload['u']?['username']??'unknown',
          name: msgPayload['u']?['name'],
        ),
        type: msgPayload['t'],
        attachments: (msgPayload['attachments'] as List?)
          ?.map((e)=>RCAttachment.fromJson(e as Map<String,dynamic>))?.toList()??[],
      );
      sub.callback(rcMsg);
    }
  }

  void _sendSubscribe(String roomId, String subId) {
    stdout.writeln('[DDP] Sending subscribe: roomId=$roomId, subId=$subId');
    _send({'msg':'sub','id':subId,'name':'stream-room-messages','params':[roomId,false]});
  }

  void _resubscribeAll() {
    stdout.writeln('[DDP] Resubscribing to ${_roomSubs.length} rooms: ${_roomSubs.keys.join(",")}');
    for (final entry in _roomSubs.entries) {
      _sendSubscribe(entry.key, entry.value.subId);
    }
  }

  void _send(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
  }

  String _nextCallId() => '${++_callId}';

  void _startPing() {
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _send({'msg':'pong'});
    });
  }

  void _clearTimers() {
    _pingTimer?.cancel(); _pingTimer = null;
    _reconnectTimer?.cancel(); _reconnectTimer = null;
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) return;
    final delay = (_initialReconnectDelay * (1 << _reconnectAttempts)).clamp(1000, 30000);
    _reconnectAttempts++;
    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      if (_connected) return;
      _doConnect();
    });
  }
}

class _RoomSub {
  final String subId;
  final void Function(RCMessage) callback;
  _RoomSub({required this.subId, required this.callback});
}
