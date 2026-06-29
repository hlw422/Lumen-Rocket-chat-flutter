import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/ddp_client.dart';
import '../services/file_service.dart';
import '../utils/auth_storage.dart';
import '../utils/constants.dart';
import '../models/room.dart';
import '../models/message.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final DdpClient _ddp = DdpClient();
  final FileService _fileService = FileService();
  bool _ddpStatusRegistered = false;

  List<Conversation> conversations = [];
  String? currentRoomId;
  ConversationType? _currentRoomType;
  List<ChatMessage> messages = [];
  bool loading = false;
  bool messagesLoading = false;
  bool ddpConnected = false;
  bool conversationsError = false;
  String? error;

  // 搜索
  List<ChatMessage> searchResults = [];
  bool searchLoading = false;
  String? searchQuery;

  Conversation? get currentConversation =>
      conversations.cast<Conversation?>().firstWhere(
          (c) => c?.id == currentRoomId, orElse: () => null);

  /// 建立 DDP WebSocket 连接
  Future<void> connectDdp() async {
    final auth = await AuthStorage.getAuthData();
    if (auth == null) return;
    _ddp.connect(wsUrl, auth.userId, auth.authToken);
    if (!_ddpStatusRegistered) {
      _ddpStatusRegistered = true;
      _ddp.onStatus((status) {
        ddpConnected = status == DdpStatus.connected;
        notifyListeners();
      });
    }
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

    // 确保 DDP 已连接（等待最多 5 秒）
    if (!_ddp.isConnected) {
      stdout.writeln('[CHAT] DDP not connected, waiting...');
      // 如果之前没连接，重新触发连接
      await connectDdp();
      // 等待连接完成
      for (int i = 0; i < 25 && !_ddp.isConnected; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (_ddp.isConnected) break;
      }
      stdout.writeln('[CHAT] After wait: ddpConnected=${_ddp.isConnected}');
    }

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
    debugPrint('[CHAT_ERROR] $s');
    if (e is DioException) {
      final path = e.requestOptions.path;
      if (e.response != null) {
        final statusCode = e.response!.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          return '登录已失效，请重新登录\nAPI: $path';
        }
        final responseData = e.response!.data;
        String detail = '';
        if (responseData is Map) {
          if (responseData.containsKey('error')) detail = '\n${responseData['error']}';
          else if (responseData.containsKey('message')) detail = '\n${responseData['message']}';
        }
        return '服务器返回错误 (${statusCode ?? '未知'})\nAPI: $path$detail';
      }
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        return '服务器连接超时，请确认 $rcHost 已启动\nAPI: $path';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Rocket.Chat 服务未启动($rcHost)\nAPI: $path';
      }
      if (e.type == DioExceptionType.badResponse) {
        return '服务器返回错误\nAPI: $path';
      }
      final errType = s.contains('type=')
          ? s.split('type=')[1].split(',')[0].split('>')[0].trim()
          : '未知';
      return '网络连接失败($errType)\nAPI: $path\n请确认服务器地址 $rcHost 可访问';
    }
    if (s.contains('SocketException')) {
      return '网络连接失败，请检查网络';
    }
    if (s.length > 100) return '${s.substring(0, 100)}…';
    return s;
  }

  void _onDdpMessage(RCMessage rcMsg) {
    if (rcMsg.rid != currentRoomId) return;
    final chatMsg = rcMsg.toChatMessage();
    stdout.writeln('[CHAT] DDP message received: room=${rcMsg.rid}, from=${chatMsg.senderName}, content=${chatMsg.content.length > 50 ? chatMsg.content.substring(0, 50) : chatMsg.content}');
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
      stdout.writeln('[CHAT] Uploading file: $filePath to room: $roomId');
      final res = await _api.uploadFile(roomId, filePath, description: description);
      stdout.writeln('[CHAT] Upload success: msgId=${res.message.id}');
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

  /// 搜索当前会话中的消息（加载 200 条历史后本地过滤，确保不漏搜）
  Future<void> searchMessages(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      searchResults = [];
      searchQuery = null;
      notifyListeners();
      return;
    }
    if (currentRoomId == null) return;
    searchLoading = true;
    searchQuery = q;
    notifyListeners();

    try {
      final roomId = currentRoomId!;
      final type = _currentRoomType;
      // 先从线上拉取一大批消息
      RCMessagesResponse res;
      switch (type) {
        case ConversationType.channel:
          res = await _api.getChannelMessages(roomId, count: 200);
          break;
        case ConversationType.group:
          res = await _api.getGroupMessages(roomId, count: 200);
          break;
        case ConversationType.direct:
        default:
          res = await _api.getImMessages(roomId, count: 200);
          break;
      }
      final all = res.messages.map((m) => m.toChatMessage()).toList();

      // 本地过滤：不区分大小写，同时搜索正文和附件名
      final lower = q.toLowerCase();
      searchResults = all.where((m) {
        if (m.content.toLowerCase().contains(lower)) return true;
        for (final a in m.attachments) {
          final name = (a.name ?? a.title ?? '').toLowerCase();
          if (name.contains(lower)) return true;
        }
        return false;
      }).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('searchMessages error: $e');
      error = _formatErr(e);
    } finally {
      searchLoading = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    searchResults = [];
    searchQuery = null;
    notifyListeners();
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
