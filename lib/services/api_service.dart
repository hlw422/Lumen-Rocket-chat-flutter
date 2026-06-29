import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import '../models/user.dart';
import '../models/room.dart';
import '../models/message.dart';

class ApiService {
  final Dio _dio = ApiClient().dio;

  // ==================== 认证 ====================

  /// POST /api/v1/login
  Future<RCLoginResponse> login(String user, String password) async {
    final resp = await _dio.post('/login',
        data: {'user': user, 'password': password});
    return RCLoginResponse.fromJson(resp.data);
  }

  /// POST /api/v1/users.register
  Future<RCRegisterResponse> register({
    required String username, required String email,
    required String pass, required String name,
  }) async {
    final resp = await _dio.post('/users.register',
        data: {'username': username, 'email': email, 'pass': pass, 'name': name});
    return RCRegisterResponse.fromJson(resp.data);
  }

  /// POST /api/v1/logout
  Future<void> logout() async {
    await _dio.post('/logout');
  }

  /// GET /api/v1/me
  Future<RCMeResponse> getMe() async {
    final resp = await _dio.get('/me');
    return RCMeResponse.fromJson(resp.data);
  }

  // ==================== 用户 ====================

  /// GET /api/v1/users.list
  Future<List<RCUser>> getUsers({int count=50, int offset=0}) async {
    final resp = await _dio.get('/users.list',
        queryParameters: {'count': count, 'offset': offset});
    final users = (resp.data['users'] as List?)?.map((e)=>RCUser.fromJson(e)).toList()??[];
    return users;
  }

  /// GET /api/v1/users.info
  Future<RCUser?> getUserInfo({String? userId, String? username}) async {
    final params = <String, dynamic>{};
    if (userId != null) params['userId'] = userId;
    if (username != null) params['username'] = username;
    final resp = await _dio.get('/users.info', queryParameters: params);
    final userData = resp.data['user'];
    if (userData == null) return null;
    return RCUser.fromJson(userData);
  }

  // ==================== 频道 ====================

  Future<RCChannelsListResponse> getChannels({int count=50,int offset=0}) async {
    final resp = await _dio.get('/channels.list', queryParameters: {'count':count,'offset':offset});
    return RCChannelsListResponse.fromJson(resp.data);
  }

  Future<RCMessagesResponse> getChannelMessages(String roomId, {int count=50,int offset=0}) async {
    final resp = await _dio.get('/channels.messages',
        queryParameters: {'roomId':roomId,'count':count,'offset':offset});
    return RCMessagesResponse.fromJson(resp.data);
  }

  Future<RCRoom> createChannel(String name, {List<String>? members}) async {
    final resp = await _dio.post('/channels.create',
        data: {'name':name, if(members!=null)'members':members});
    return RCRoom.fromJson(resp.data['channel']);
  }

  // ==================== 私密群组 ====================

  Future<RCGroupsListResponse> getGroups({int count=50,int offset=0}) async {
    // 优先使用 groups.list（Rocket.Chat 标准端点）
    // 某些 5.x 版本可能只有 groups.listAll（需管理员权限）
    // 为避免登录后崩溃，逐级回退：list → listAll → 空列表
    try {
      final resp = await _dio.get('/groups.list', queryParameters: {'count':count,'offset':offset});
      return RCGroupsListResponse.fromJson(resp.data);
    } catch (e) {
      debugPrint('[API] groups.list failed ($e), trying groups.listAll');
      try {
        final resp = await _dio.get('/groups.listAll', queryParameters: {'count':count,'offset':offset});
        return RCGroupsListResponse.fromJson(resp.data);
      } catch (e2) {
        debugPrint('[API] groups.listAll also failed ($e2), returning empty');
        return RCGroupsListResponse(groups: []);
      }
    }
  }

  Future<RCMessagesResponse> getGroupMessages(String roomId, {int count=50,int offset=0}) async {
    final resp = await _dio.get('/groups.messages',
        queryParameters: {'roomId':roomId,'count':count,'offset':offset});
    return RCMessagesResponse.fromJson(resp.data);
  }

  // ==================== 私聊 ====================

  Future<RCImListResponse> getImList({int count=50,int offset=0}) async {
    final resp = await _dio.get('/im.list', queryParameters: {'count':count,'offset':offset});
    return RCImListResponse.fromJson(resp.data);
  }

  Future<RCMessagesResponse> getImMessages(String roomId, {int count=50,int offset=0}) async {
    final resp = await _dio.get('/im.messages',
        queryParameters: {'roomId':roomId,'count':count,'offset':offset});
    return RCMessagesResponse.fromJson(resp.data);
  }

  Future<RCRoom> createIm(String username) async {
    final resp = await _dio.post('/im.create', data: {'username':username});
    return RCRoom.fromJson(resp.data['room']);
  }

  // ==================== 消息 ====================

  Future<RCPostMessageResponse> postMessage(String roomId, String text) async {
    final resp = await _dio.post('/chat.postMessage',
        data: {'roomId':roomId,'text':text});
    return RCPostMessageResponse.fromJson(resp.data);
  }

  Future<void> deleteMessage(String roomId, String msgId) async {
    await _dio.post('/chat.delete', data: {'roomId':roomId,'msgId':msgId});
  }

  // ==================== 文件上传 ====================

  Future<RCPostMessageResponse> uploadFile(
      String roomId, String filePath,
      {String? description}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      if (description != null) 'description': description,
    });
    final resp = await _dio.post('/rooms.upload/$roomId', data: formData,
        options: Options(sendTimeout: const Duration(minutes: 5)));
    return RCPostMessageResponse.fromJson(resp.data);
  }
}
