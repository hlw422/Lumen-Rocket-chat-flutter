import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/ddp_client.dart';
import '../services/file_service.dart';
import '../utils/auth_storage.dart';
import '../models/room.dart';
import '../models/message.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final DdpClient _ddp = DdpClient();
  final FileService _fileService = FileService();

  List<Conversation> conversations = [];
  String? currentRoomId;
  ConversationType? _currentRoomType;
  List<ChatMessage> messages = [];
  bool loading = false;
  bool messagesLoading = false;
  bool ddpConnected = false;
  bool conversationsError = false;
  String? error;

  Conversation? get currentConversation =>
      conversations.cast<Conversation?>().firstWhere(
          (c) => c?.id == currentRoomId, orElse: () => null);

  /// 建立 DDP WebSocket 连接
  Future<void> connectDdp() async {
    final auth = await AuthStorage.getAuthData();
    if (auth == null) return;
    _ddp.connect('ws://192.168.1.189:3000/websocket', auth.userId, auth.authToken);
    _ddp.onStatus((status) {
      ddpConnected = status == DdpStatus.connected;
      notifyListeners();
    });
  }

  void disconnectDdp() {
    _ddp.disconnect();
    ddpConnected = false;
    notifyListeners();
  }

  /// 加载合并后的会话列表
  Future<void> loadConversations() async {
    loading = true; conversationsError = false; notifyListeners();
    try {
      final merged = <Conversation>[];
      final results = await Future.wait([
        _api.getChannels().then((r) => r.channels),
        _api.getGroups().then((r) => r.groups),
        _api.getImList().then((r) => r.ims),
      ]);
      for (final ch in results[0]) merged.add(ch.toConversation(ConversationType.channel));
      for (final gr in results[1]) merged.add(gr.toConversation(ConversationType.group));
      for (final im in results[2]) merged.add(im.toConversation(ConversationType.direct));
      conversations = merged;
    } catch (e) {
      debugPrint('loadConversations error: $e');
      conversationsError = true;
      error = _formatErr(e);
    } finally {
      loading = false; notifyListeners();
    }
  }

  /// 选择会话
  Future<void> selectConversation(String roomId, {ConversationType? type}) async {
    if (currentRoomId != null) _ddp.unsubscribeRoom(currentRoomId!);
    currentRoomId = roomId;
    _currentRoomType = type ?? currentConversation?.type;
    await _loadMessages(roomId, type: _currentRoomType);
    _ddp.subscribeRoom(roomId, _onDdpMessage);
    notifyListeners();
  }

  Future<void> _loadMessages(String roomId, {int count=50, int offset=0, ConversationType? type}) async {
    messagesLoading = true; error = null; notifyListeners();
    try {
      final convType = type ?? currentConversation?.type;
      RCMessagesResponse res;
      switch (convType) {
        case ConversationType.channel: res = await _api.getChannelMessages(roomId, count: count, offset: offset); break;
        case ConversationType.group: res = await _api.getGroupMessages(roomId, count: count, offset: offset); break;
        case ConversationType.direct:
        default: res = await _api.getImMessages(roomId, count: count, offset: offset); break;
      }
      messages = res.messages.map((m)=>m.toChatMessage())
          .toList()
          ..sort((a,b)=>a.timestamp.compareTo(b.timestamp));
    } catch (e) {
      debugPrint('loadMessages error: $e');
      error = _formatErr(e);
    } finally {
      messagesLoading = false; notifyListeners();
    }
  }

  String _formatErr(Object e) {
    final s = e.toString();
    if (s.contains('DioException') || s.contains('SocketException')) {
      if (s.contains('Connection timed out') || s.contains('TimeoutException')) {
        return '服务器连接超时，请确认 192.168.1.189:3000 已启动';
      }
      if (s.contains('Connection refused')) {
        return 'Rocket.Chat 服务未启动(192.168.1.189:3000)';
      }
      if (s.contains('No address associated') || s.contains('Failed host lookup')) {
        return '无法解析服务器地址，请检查网络配置';
      }
      final errType = s.contains('type=') ? s.split('type=')[1].split(',')[0].split('>')[0].trim() : '未知';
      return '网络连接失败($errType)';
    }
    if (s.length > 80) return '${s.substring(0, 80)}…';
    return s;
  }

  void _onDdpMessage(RCMessage rcMsg) {
    if (rcMsg.rid != currentRoomId) return;
    final chatMsg = rcMsg.toChatMessage();
    if (!messages.any((m)=>m.id==chatMsg.id)) {
      messages = [...messages, chatMsg]..sort((a,b)=>a.timestamp.compareTo(b.timestamp));
      notifyListeners();
    }
  }

  /// 发送文本消息
  Future<ChatMessage?> sendMessage(String roomId, String text) async {
    try {
      final res = await _api.postMessage(roomId, text);
      final chatMsg = res.message.toChatMessage();
      if (!messages.any((m)=>m.id==chatMsg.id)) {
        messages = [...messages, chatMsg];
        notifyListeners();
      }
      return chatMsg;
    } catch (e) {
      debugPrint('sendMessage error: $e');
      return null;
    }
  }

  /// 上传文件
  Future<ChatMessage?> uploadFile(String roomId, String filePath, {String? description}) async {
    try {
      final res = await _api.uploadFile(roomId, filePath, description: description);
      final chatMsg = res.message.toChatMessage();
      if (!messages.any((m)=>m.id==chatMsg.id)) {
        messages = [...messages, chatMsg];
        notifyListeners();
      }
      return chatMsg;
    } catch (e) {
      debugPrint('uploadFile error: $e');
      return null;
    }
  }

  /// 上传图片/文件 (从 picker 选择后)
  Future<ChatMessage?> pickAndUpload(String roomId, {bool image=false}) async {
    try {
      String? path;
      if (image) {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery);
        path = picked?.path;
      } else {
        final result = await FilePicker.platform.pickFiles();
        path = result?.files.single.path;
      }
      if (path == null) return null;
      return await uploadFile(roomId, path);
    } catch (e) {
      debugPrint('pickAndUpload error: $e');
      return null;
    }
  }

  /// 删除消息
  Future<bool> deleteMessage(String roomId, String msgId) async {
    try {
      await _api.deleteMessage(roomId, msgId);
      messages = messages.where((m)=>m.id!=msgId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('deleteMessage error: $e');
      return false;
    }
  }

  /// 下载文件（带认证头）
  Future<void> downloadFile(String url, String fileName) async {
    await _fileService.downloadFile(url, fileName);
  }

  /// 加载图片 bytes（带认证头，用于 Image.memory）
  Future<Uint8List> loadImageBytes(String url) async {
    return _fileService.loadImage(url);
  }

  /// 清理
  void disposeResources() {
    if (currentRoomId != null) _ddp.unsubscribeRoom(currentRoomId!);
    disconnectDdp();
    conversations = [];
    messages = [];
    currentRoomId = null;
    _currentRoomType = null;
    conversationsError = false;
    error = null;
    notifyListeners();
  }
}
