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
  List<ChatMessage> messages = [];
  bool loading = false;
  bool messagesLoading = false;
  bool ddpConnected = false;

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
    loading = true; notifyListeners();
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
    } finally {
      loading = false; notifyListeners();
    }
  }

  /// 选择会话
  Future<void> selectConversation(String roomId) async {
    if (currentRoomId != null) _ddp.unsubscribeRoom(currentRoomId!);
    currentRoomId = roomId;
    await _loadMessages(roomId);
    _ddp.subscribeRoom(roomId, _onDdpMessage);
    notifyListeners();
  }

  Future<void> _loadMessages(String roomId, {int count=50, int offset=0}) async {
    messagesLoading = true; notifyListeners();
    try {
      final conv = currentConversation;
      RCMessagesResponse res;
      switch (conv?.type) {
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
    } finally {
      messagesLoading = false; notifyListeners();
    }
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
    notifyListeners();
  }
}
